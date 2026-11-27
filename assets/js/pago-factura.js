/* Pago de factura y emisión de DTE – jQuery + AJAX contra WebMethods de Facturacion/frm_OpenFactura.aspx */
(function ($) {
    'use strict';

    var URL = 'Facturacion/frm_OpenFactura.aspx/';

    var DEPARTAMENTOS = window.DteCatalogos.departamentos;   // assets/js/dte-catalogos.js
    var NOMBRE_DTE = { '01': 'Factura', '03': 'Comprobante de crédito fiscal' };

    var state = {
        factura: 0,
        datos: null,          // FacturaPagoDto
        tipo: '01',
        pagos: [{ forma: '01', buffer: '', ref: '', auto: false }],   // pago combinado: una línea por forma de pago
        sel: 0,                                                       // línea en la que escribe el teclado
        receptor: null,
        servicios: null,
        pagando: false
    };

    /* ---------- utilidades ---------- */
    function usuario() { return $.trim($('#idUser').val() || ''); }   // usuario de la sesión (campo oculto de default.aspx)
    function api(metodo, datos) {
        return $.ajax({
            type: 'POST',
            url: URL + metodo,
            data: JSON.stringify(datos || {}),
            contentType: 'application/json; charset=utf-8',
            dataType: 'json'
        }).then(function (r) { return r.d; });
    }
    function falla(xhr) { showNotification(1, 'error', 'Error de conexión (HTTP ' + xhr.status + ').'); }
    function dinero(n) { return Number(n || 0).toFixed(2); }
    function soloDigitos(s) { return String(s || '').replace(/[^0-9]/g, ''); }
    function totales() { return state.datos && state.datos.Totales ? state.datos.Totales[state.tipo] : { Gravado: 0, Iva: 0, Total: 0 }; }
    var NOMBRE_FORMA = { '01': 'Efectivo', '03': 'Tarjeta crédito/débito', '05': 'Transferencias' };
    function r2(n) { return Math.round((Number(n) || 0) * 100) / 100; }
    function montoLinea(l) { return parseFloat(l.buffer) || 0; }
    function linea() { return state.pagos[state.sel] || state.pagos[0]; }
    function pagado() { return r2(state.pagos.reduce(function (s, l) { return s + montoLinea(l); }, 0)); }
    function sinEfectivo() { return r2(state.pagos.reduce(function (s, l) { return s + (l.forma === '01' ? 0 : montoLinea(l)); }, 0)); }
    function efectivo() { return r2(state.pagos.reduce(function (s, l) { return s + (l.forma === '01' ? montoLinea(l) : 0); }, 0)); }
    // forma principal (la de mayor monto): la que se envía como FormaPago para compatibilidad
    function formaPrincipal() { return state.pagos.slice().sort(function (a, b) { return montoLinea(b) - montoLinea(a); })[0].forma; }
    function pagada() { return !!(state.datos && state.datos.Factura && state.datos.Factura.Pagada); }
    // Todos los servicios valen $0.00: no se emite DTE sino un ticket POS (DteService.EmitirTicket)
    function sinCosto() {
        var d = state.datos;
        if (!d || !d.Items.length) return false;
        return d.Items.reduce(function (s, it) { return s + Number(it.Valor || 0); }, 0) === 0;
    }

    /* ---------- render ---------- */
    function render() {
        var d = state.datos;
        if (!d) return;
        $('#cliente').val(d.Factura.Cliente + (d.Factura.Documento ? ' · ' + d.Factura.Documento : ''));

        var $tb = $('#tbItems').empty();
        if (!d.Items.length)
            $tb.append($('<tr>').append($('<td colspan="3" class="text-center text-muted">').text('Sin servicios. Use “Agregar servicio”.')));
        var libre = !!d.Factura.MontoLibre;      // pago adelantado sin cita: monto fijo, sin servicios ni cupón
        $('#btnServicios').toggleClass('d-none', libre || pagada());
        $.each(d.Items, function (_, it) {
            var $btn = pagada() || libre ? '' : $('<button type="button" class="btn btn-sm btn-outline-danger btn-quitar">')
                .attr({ 'data-id': it.Id, title: 'Quitar', 'aria-label': 'Quitar ' + it.Descripcion })
                .append('<i class="bx bx-trash"></i>');
            // Tratamiento con descuento: precio original tachado, % y precio con descuento; sin descuento, solo el precio
            var $valor = $('<td class="text-end">');
            if (it.Descuento > 0 && it.MontoDescuento > 0)
                $valor.append($('<span class="text-muted text-decoration-line-through small me-1">').text(dinero(it.Valor)),
                    $('<span>').text(dinero(it.Valor - it.MontoDescuento)),
                    $('<div class="small text-success">').text('-' + Number(it.Descuento) + ' % (-' + dinero(it.MontoDescuento) + ')'));
            else $valor.text(dinero(it.Valor));
            $tb.append($('<tr>').append(
                $('<td>').text(it.Descripcion),
                $valor,
                $('<td class="text-center">').append($btn)));
        });

        var t = totales(), ccf = state.tipo === '03';
        $('#lblGravado').text(ccf ? 'Total gravado:' : 'Total gravado (IVA incluido):');
        $('#lblIva').text(ccf ? 'IVA 13%:' : 'IVA 13% incluido:');
        $('#totGravado').text(dinero(t.Gravado));
        $('#totIva').text(dinero(t.Iva));
        $('#totPagar').text(dinero(t.Total));
        $('#filaDescuento').toggleClass('d-none', !(t.Descuento > 0));
        $('#totDescuento').text('-' + dinero(t.Descuento));
        renderCupon();

        $('#pagoFactura').toggleClass('pagada', pagada());
        $('#lblPagada').toggleClass('d-none', !pagada());
        renderFiscal();
        renderMonto();
        renderDte(d.Dte);
        renderTicket(d.Ticket);

        // Cobro de una cita por adelantado: se factura ahora; al atenderla solo se cobra lo que se agregue
        $('#avisoAnticipo').toggleClass('d-none', !d.Factura.Anticipo).html(d.Factura.MontoLibre
            ? '<i class="bx bx-wallet"></i> <strong>Pago adelantado sin cita</strong>. ' + (pagada()
                ? 'Queda pendiente de agendar: al crear su cita use <strong>Usar pago adelantado</strong> y al atenderla solo se cobrará la diferencia.'
                : 'La cita queda pendiente de agendar; al atenderla se descuenta este pago y solo se cobra la diferencia.')
            : d.Factura.Anticipo
            ? '<i class="bx bx-calendar-check"></i> <strong>Cobro por adelantado</strong> de la cita' + (d.Factura.CitaInicio ? ' del ' + $('<div>').text(d.Factura.CitaInicio).html() : '')
              + '. ' + (pagada() ? 'Pagada: al atender la cita solo se cobrará lo que se agregue.' : 'Al atender la cita solo se cobrará lo que se agregue; si se cancela, queda a favor del paciente.')
            : '');

        var ticket = sinCosto() && !pagada();
        $('#avisoSinCosto').toggleClass('d-none', !ticket);
        $('#btnPagar').html(ticket ? '<i class="bx bx-receipt"></i> Emitir ticket' : '<i class="bx bx-check"></i> Pagar');
    }

    function renderTicket(t) {
        $('#cardTicket').toggleClass('d-none', !t);
        if (!t) return;
        $('#ticketNumero').text(t.Numero);
        $('#ticketDetalle').text(t.Fecha + ' · ' + t.Cajero + ' · No se generó DTE (total $0.00).');
    }

    /* ---------- pago combinado: líneas de pago ---------- */
    function textoMonto(l) { return l.buffer === '' ? '0.00' : (l.buffer.indexOf('.') >= 0 ? l.buffer : l.buffer + '.00'); }

    // Motivo por el que no se puede pagar todavía (null = listo). Mismas reglas que DteService.AplicarPagos.
    function errorPagos() {
        var total = totales().Total, otros = sinEfectivo(), ef = efectivo();
        if (state.pagos.some(function (l) { return montoLinea(l) <= 0; }))
            return state.pagos.length > 1 ? 'Cada forma de pago debe tener un monto mayor a cero.' : 'Ingrese el monto recibido.';
        if (otros > total) return 'Tarjeta y transferencia no pueden pasar del total a pagar ($' + dinero(total) + ').';
        if (pagado() < total) return state.pagos.length === 1 && ef > 0
            ? 'El monto recibido es menor al total a pagar ($' + dinero(total) + ').'
            : 'Falta $' + dinero(total - pagado()) + ' por cubrir.';
        if (ef > 0 && total - otros <= 0) return 'El total ya está cubierto con tarjeta o transferencia: quite el efectivo.';
        return null;
    }

    function renderMonto() {
        var $l = $('#pagoLineas').empty(), varias = state.pagos.length > 1;
        $.each(state.pagos, function (i, l) {
            var $fila = $('<div class="pago-linea" role="button" tabindex="0">').attr('data-i', i)
                .toggleClass('ef', l.forma === '01').toggleClass('sel', i === state.sel && !pagada())
                .attr('aria-label', NOMBRE_FORMA[l.forma] + ' ' + textoMonto(l) + (i === state.sel ? ' (el teclado escribe aquí)' : ''));
            $fila.append($('<span class="nombre">').text(NOMBRE_FORMA[l.forma] || l.forma));
            if (l.forma !== '01')
                $fila.append($('<input type="text" class="form-control form-control-sm ref" maxlength="50" placeholder="Referencia (opcional)">')
                    .attr('aria-label', 'Referencia de ' + NOMBRE_FORMA[l.forma]).val(l.ref || '').prop('disabled', pagada()));
            $fila.append($('<span class="monto">').toggleClass('vacio', l.buffer === '').text('$' + textoMonto(l)));
            if (varias && !pagada())
                $fila.append($('<button type="button" class="quitar">').attr('aria-label', 'Quitar ' + NOMBRE_FORMA[l.forma]).html('&times;'));
            $l.append($fila);
        });
        $('#lblPagado').text(dinero(pagado()));

        var $c = $('#lblCambio').removeClass('ok falta').text('');
        if (pagada() || (!varias && linea().buffer === '')) return;
        var total = totales().Total, err = errorPagos();
        if (err) $c.addClass('falta').text(err.replace(/^Falta/, 'Falta:').replace(' por cubrir.', ''));
        else if (pagado() > total) $c.addClass('ok').text('Cambio: $' + dinero(pagado() - total));
        else $c.addClass('ok').text('Pago completo');
    }

    // Cada clic en una forma agrega lo que falta por cubrir (si ya está, se lo suma a esa línea)
    function agregarForma(forma) {
        var falta = r2(totales().Total - pagado());
        // las líneas vacías no sirven: se quitan antes de agregar otra forma
        state.pagos = state.pagos.filter(function (l) { return l.forma === forma || montoLinea(l) > 0; });
        var i = -1;
        $.each(state.pagos, function (k, l) { if (l.forma === forma) i = k; });
        if (i >= 0) {
            var l = state.pagos[i];
            if (falta > 0) { l.buffer = String(r2(montoLinea(l) + falta)); l.auto = true; }
        } else {
            state.pagos.push({ forma: forma, buffer: falta > 0 ? String(falta) : '', ref: '', auto: true });
            i = state.pagos.length - 1;
        }
        state.sel = i;
        renderMonto();
    }

    function quitarLinea(i) {
        state.pagos.splice(i, 1);
        if (!state.pagos.length) state.pagos.push({ forma: '01', buffer: '', ref: '', auto: false });
        state.sel = Math.min(state.sel, state.pagos.length - 1);
        renderMonto();
    }

    // Cambió el total (cupón, servicios, tipo de documento): con una sola forma que no es efectivo, se cobra el total exacto
    function ajustarAlTotal() {
        if (state.pagos.length === 1 && state.pagos[0].forma !== '01') { state.pagos[0].buffer = String(r2(totales().Total)); state.pagos[0].auto = true; }
        renderMonto();
    }

    function renderFiscal() {
        var ccf = state.tipo === '03', r = state.receptor;
        $('#resumenFiscal').toggleClass('d-none', !ccf);
        $('#txtFiscal').text(r ? r.Nombre + ' · NIT ' + r.Nit + ' · NRC ' + r.Nrc : 'Sin datos fiscales.');
    }

    function renderDte(dte) {
        $('#cardDte').toggleClass('d-none', !dte);
        if (!dte) return;
        $('#dteNumero').text(dte.NumeroControl);
        $('#dteCodigo').text(dte.CodigoGeneracion);
        $('#lnkPdf').toggleClass('d-none', !dte.UrlPdf).attr('href', dte.UrlPdf || '#');
        $('#lnkJson').toggleClass('d-none', !dte.UrlJson).attr('href', dte.UrlJson || '#');
        $('#dteCorreo').text(dte.CorreoDestino ? 'Enviado a ' + dte.CorreoDestino + ' (' + dte.FechaCorreo + ')' : 'Aún no se ha enviado por correo.');
        if (!$('#txtCorreoDte').val()) {
            var r = state.receptor, f = state.datos && state.datos.Factura;
            $('#txtCorreoDte').val(dte.CorreoDestino || (dte.TipoDte === '03' && r ? r.Correo : (f && f.Email) || ''));
        }
    }

    function enviarCorreo() {
        var correo = $.trim($('#txtCorreoDte').val());
        if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(correo)) { showNotification(1, 'warning', 'Ingrese un correo electrónico válido.'); return; }
        var $btn = $('#btnEnviarCorreo').prop('disabled', true).html('<span class="spinner-border spinner-border-sm"></span> Enviando…');
        api('EnviarCorreo', { factura: state.factura, correo: correo, user: usuario() }).done(function (r) {
            if (!r.Ok) { showNotification(1, 'error', r.Mensaje); return; }
            showNotification(1, 'success', r.Mensaje);
            state.datos.Dte = r.Dte;
            renderDte(r.Dte);
        }).fail(falla).always(function () {
            $btn.prop('disabled', false).html('<i class="bx bx-envelope"></i> Enviar');
        });
    }

    /* ---------- carga ---------- */
    function aplicarDatos(r) {
        if (!r.Ok) { showNotification(1, 'error', r.Mensaje); return false; }
        state.datos = r;
        if (!state.receptor && r.Receptor) state.receptor = r.Receptor;
        if (r.Factura.Pagada && r.Dte) {                  // factura ya emitida: se muestra con su tipo de documento
            state.tipo = r.Dte.TipoDte;
            $('input[name=tipoDte][value="' + r.Dte.TipoDte + '"]').prop('checked', true);
        }
        $('input[name=tipoDte]').prop('disabled', r.Factura.Pagada);
        render();
        return true;
    }

    function cargar() {
        api('ObtenerFactura', { factura: state.factura, user: usuario() }).done(aplicarDatos).fail(falla);
    }

    /* ---------- cupón de descuento (QR) ---------- */
    var RE_CUPON = /^DPC-[A-Z]{8}$/;

    function renderCupon() {
        var c = state.datos && state.datos.Cupon, esc = function (s) { return $('<div>').text(s || '').html(); };
        var libre = !!(state.datos && state.datos.Factura && state.datos.Factura.MontoLibre);
        $('#cardCupon').toggleClass('d-none', pagada() || libre).toggleClass('aplicado', !!(c && !c.NoValido));
        $('#cuponEntrada').toggleClass('d-none', !!c);
        if (!c) { $('#cuponAplicado').addClass('d-none').empty(); return; }
        $('#cuponAplicado').removeClass('d-none').html(
            '<div class="d-flex align-items-center gap-2"><i class="bx ' + (c.NoValido ? 'bx-error text-danger' : 'bx-purchase-tag-alt text-success') + ' fs-4"></i>'
            + '<div class="flex-fill small"><strong>' + esc(c.Codigo) + '</strong> · ' + Number(c.Porcentaje) + ' % de descuento'
            + (c.Tratamiento ? ' en ' + esc(c.Tratamiento) : ' en toda la factura')
            + (c.NoValido ? '<div class="text-danger">' + esc(c.NoValido) + '</div>' : '') + '</div>'
            + '<button type="button" class="btn btn-sm btn-outline-danger" id="btnQuitarCupon" title="Quitar cupón"><i class="bx bx-x"></i></button></div>');
    }

    function aplicarCupon(codigo) {
        codigo = String(codigo || '').trim().toUpperCase();
        if (!RE_CUPON.test(codigo)) { showNotification(1, 'warning', 'El código no es un cupón válido.'); return; }
        if (pagada()) return;
        $('#btnAplicarCupon').prop('disabled', true);
        api('AplicarCupon', { factura: state.factura, codigo: codigo, user: usuario() }).done(function (r) {
            if (!r.Ok) { showNotification(1, 'warning', r.Mensaje); $('#txtCupon').trigger('select'); return; }
            $('#txtCupon').val('');
            aplicarDatos(r);
            ajustarAlTotal();
            showNotification(1, 'success', 'Cupón aplicado: ' + Number(r.Cupon.Porcentaje) + ' % de descuento ($' + dinero(totales().Descuento) + ').');
        }).fail(falla).always(function () { $('#btnAplicarCupon').prop('disabled', false); });
    }

    function quitarCupon() {
        api('QuitarCupon', { factura: state.factura, user: usuario() }).done(function (r) {
            if (aplicarDatos(r)) { ajustarAlTotal(); showNotification(1, 'info', 'Cupón quitado.'); }
        }).fail(falla);
    }

    // Lector de QR/código de barras USB: escribe el código muy rápido y termina con Enter, aunque el cursor no esté en el campo
    var lector = { texto: '', ultima: 0 };
    function capturarLector(e) {
        if (!$('#pagoFactura').length || pagada() || $('.modal.show, .sweet-alert:visible').length) return;
        if ($(e.target).is('#txtCupon')) return;              // en el campo del cupón lo maneja su propio Enter
        var ahora = Date.now();
        if (ahora - lector.ultima > 80) lector.texto = '';    // más lento que un lector: es una persona escribiendo
        lector.ultima = ahora;
        if (e.key === 'Enter') {
            if (RE_CUPON.test(lector.texto.toUpperCase())) { e.preventDefault(); aplicarCupon(lector.texto); }
            lector.texto = '';
        } else if (e.key.length === 1) lector.texto += e.key;
    }

    // Cámara (Chrome / Edge con BarcodeDetector)
    var camara = { stream: null, timer: null };
    function detenerCamara() {
        if (camara.timer) clearInterval(camara.timer);
        if (camara.stream) camara.stream.getTracks().forEach(function (t) { t.stop(); });
        camara.stream = camara.timer = null;
        $('#videoCupon').addClass('d-none');
    }
    function escanearConCamara() {
        if (camara.stream) { detenerCamara(); return; }
        var detector = new window.BarcodeDetector({ formats: ['qr_code'] }), video = document.getElementById('videoCupon');
        navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' } }).then(function (stream) {
            camara.stream = stream;
            video.srcObject = stream;
            $(video).removeClass('d-none');
            video.play();
            camara.timer = setInterval(function () {
                if (!$('#pagoFactura').length) { detenerCamara(); return; }
                detector.detect(video).then(function (codigos) {
                    var c = (codigos || []).map(function (x) { return x.rawValue; }).filter(function (v) { return RE_CUPON.test(String(v).toUpperCase()); })[0];
                    if (c) { detenerCamara(); aplicarCupon(c); }
                }).catch(function () { });
            }, 400);
        }).catch(function () { showNotification(1, 'warning', 'No se pudo usar la cámara. Revise el permiso del navegador.'); });
    }

    /* ---------- teclado ---------- */
    function tecla(t) {
        if (pagada()) return;
        var l = linea();
        if (l.auto) { l.buffer = ''; l.auto = false; }    // el monto que puso el botón se reemplaza al escribir
        var b = l.buffer;
        if (t === '.') { if (b.indexOf('.') < 0) b = (b === '' ? '0' : b) + '.'; }
        else {
            var p = b.indexOf('.');
            if (p >= 0 && b.length - p > 2) return;               // máximo 2 decimales
            if (p < 0 && b.replace('.', '').length >= 7) return;  // hasta 9,999,999
            b = (b === '0' ? '' : b) + t;
        }
        l.buffer = b;
        renderMonto();
    }

    function fijarMonto(v) { var l = linea(); l.buffer = v > 0 ? String(r2(v)) : ''; l.auto = false; renderMonto(); }

    function accionTeclado(a) {
        if (pagada()) return;
        var l = linea();
        if (a === 'borrar') { l.buffer = l.auto ? '' : l.buffer.slice(0, -1); l.auto = false; }
        else if (a === 'limpiar') { l.buffer = ''; l.auto = false; }
        else if (a === 'exacto') { fijarMonto(totales().Total - (pagado() - montoLinea(l))); return; }   // lo que falta con esta línea
        renderMonto();
    }

    /* ---------- documento ---------- */
    function seleccionarTipo(tipo) {
        state.tipo = tipo;
        render();
        ajustarAlTotal();
        if (tipo === '03' && !state.receptor && !pagada()) abrirReceptor();
    }

    /* ---------- servicios ---------- */
    function abrirServicios() {
        $('#txtBuscarServicio').val('');
        mtd_OpenModal('modalServicios');
        if (state.servicios) { pintarServicios(); return; }
        $('#listaServicios').html('<div class="text-center p-3"><div class="spinner-border" role="status"></div></div>');
        api('ObtenerServicios', { user: usuario() }).done(function (r) {
            if (!r.Ok) { $('#listaServicios').empty(); showNotification(1, 'error', r.Mensaje); return; }
            state.servicios = r.Servicios;
            pintarServicios();
        }).fail(falla);
    }

    function pintarServicios() {
        var filtro = $.trim($('#txtBuscarServicio').val()).toLowerCase();
        var $l = $('#listaServicios').empty();
        $.each(state.servicios || [], function (_, s) {
            if (filtro && s.Descripcion.toLowerCase().indexOf(filtro) < 0) return;
            $l.append($('<button type="button" class="list-group-item list-group-item-action">').attr('data-id', s.Id)
                .append($('<span>').text(s.Descripcion), s.Descuento > 0
                    ? $('<span class="precio">').append($('<span class="badge bg-success me-1">').text('-' + Number(s.Descuento) + ' %'),
                        $('<span class="text-muted text-decoration-line-through small me-1">').text('$' + dinero(s.Precio)),
                        document.createTextNode('$' + dinero(s.Precio - Math.round(s.Precio * s.Descuento) / 100)))
                    : $('<span class="precio">').text('$' + dinero(s.Precio))));
        });
        if (!$l.children().length) $l.append($('<div class="text-muted p-2">').text('No hay servicios que coincidan.'));
    }

    function agregarServicio(id, $btn) {
        $btn.prop('disabled', true);
        api('AgregarServicio', { factura: state.factura, servicio: id, user: usuario() }).done(function (r) {
            if (aplicarDatos(r)) showNotification(1, 'success', 'Servicio agregado.');
        }).fail(falla).always(function () { $btn.prop('disabled', false); });
    }

    function quitarServicio(id) {
        var it = $.grep(state.datos.Items, function (x) { return x.Id === id; })[0];
        var esc = function (s) { return $('<div>').text(s || '').html(); };
        swal({
            title: '¿Quitar el servicio?',
            text: it ? '<b>' + esc(it.Descripcion) + '</b> · $' + dinero(it.Valor) + '<br>Se quitará de la factura.' : 'Se quitará de la factura.',
            html: true,
            type: 'warning',
            showCancelButton: true,
            confirmButtonText: 'Sí, quitar',
            cancelButtonText: 'Cancelar',
            confirmButtonColor: '#d33'
        }, function (isConfirm) {
            if (!isConfirm) return;
            api('QuitarServicio', { factura: state.factura, detalle: id, user: usuario() }).done(function (r) {
                if (aplicarDatos(r)) showNotification(1, 'success', 'Servicio quitado.');
            }).fail(falla);
        });
    }

    /* ---------- datos fiscales ---------- */
    function llenarMunicipios(depto, muni) {
        var $m = $('#recMuni').empty().append($('<option>').val('').text('Seleccione…'));
        $.each(DEPARTAMENTOS, function (_, d) {
            if (d[0] !== depto) return;
            $.each(d[2], function (_, m) { $m.append($('<option>').val(m[0]).text(m[1])); });
        });
        $m.val(muni || '');
    }

    // DTE 2.0: distritos del municipio (assets/js/dte-catalogos.js)
    function llenarDistritos(depto, muni, distrito) {
        var $d = $('#recDistrito').empty().append($('<option>').val('').text('Seleccione…'));
        $.each(window.DteCatalogos.distritosDe(depto, muni), function (_, x) { $d.append($('<option>').val(x[0]).text(x[1])); });
        $d.val(distrito || '');
    }

    function pintarReceptor(r) {
        r = r || {};
        $('#recNit').val(r.Nit || '');
        $('#recNrc').val(r.Nrc || '');
        $('#recNombre').val(r.Nombre || (state.datos ? state.datos.Factura.Cliente : ''));
        $('#recComercial').val(r.NombreComercial || '');
        $('#recCodAct').val(r.CodActividad || '');
        $('#recDescAct').val(r.DescActividad || '');
        $('#recDepto').val(r.CodDepartamento || '');
        llenarMunicipios(r.CodDepartamento || '', r.CodMunicipio);
        llenarDistritos(r.CodDepartamento || '', r.CodMunicipio || '', r.CodDistrito);
        $('#recDireccion').val(r.Complemento || (state.datos ? state.datos.Factura.Direccion : ''));
        $('#recTelefono').val(r.Telefono || (state.datos ? state.datos.Factura.Celular : ''));
        $('#recCorreo').val(r.Correo || (state.datos ? state.datos.Factura.Email : ''));
    }

    function abrirReceptor() {
        $('#recMsg').text('');
        pintarReceptor(state.receptor);
        mtd_OpenModal('modalReceptor');   // antes solo quitaba el atributo hidden y el modal de Bootstrap nunca se mostraba
    }

    function leerReceptor() {
        return {
            Nit: soloDigitos($('#recNit').val()),
            Nrc: soloDigitos($('#recNrc').val()),
            Nombre: $.trim($('#recNombre').val()),
            NombreComercial: $.trim($('#recComercial').val()),
            CodActividad: soloDigitos($('#recCodAct').val()),
            DescActividad: $.trim($('#recDescAct').val()),
            CodDepartamento: $('#recDepto').val(),
            CodMunicipio: $('#recMuni').val(),
            CodDistrito: $('#recDistrito').val(),
            Complemento: $.trim($('#recDireccion').val()),
            Telefono: soloDigitos($('#recTelefono').val()),
            Correo: $.trim($('#recCorreo').val())
        };
    }

    // Validación rápida en el navegador; el servidor vuelve a validar todo
    function validarReceptor(r) {
        if (!/^([0-9]{14}|[0-9]{9})$/.test(r.Nit)) return 'El NIT debe tener 14 dígitos (o 9 si es DUI).';
        if (!/^[0-9]{1,8}$/.test(r.Nrc)) return 'El NRC debe tener de 1 a 8 dígitos.';
        if (!r.Nombre) return 'Ingrese el nombre o razón social.';
        if (!/^[0-9]{2,6}$/.test(r.CodActividad)) return 'Ingrese el código de actividad económica.';
        if (!r.DescActividad) return 'Ingrese la actividad económica.';
        if (!r.CodDepartamento) return 'Seleccione el departamento.';
        if (!r.CodMunicipio) return 'Seleccione el municipio.';
        if (!r.CodDistrito) return 'Seleccione el distrito.';
        if (!r.Complemento) return 'Ingrese la dirección.';
        if (r.Telefono && r.Telefono.length < 8) return 'El teléfono debe tener al menos 8 dígitos.';
        if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(r.Correo)) return 'Ingrese un correo electrónico válido.';
        return null;
    }

    function aceptarReceptor() {
        var r = leerReceptor(), err = validarReceptor(r);
        if (err) { $('#recMsg').text(err); return; }
        state.receptor = r;
        renderFiscal();
        mtd_CloseModal('modalReceptor');
    }

    function buscarNit() {
        var nit = soloDigitos($('#recNit').val());
        $('#recMsg').text('');
        api('BuscarReceptor', { nit: nit, user: usuario() }).done(function (r) {
            if (r.Ok) pintarReceptor(r.Receptor); else $('#recMsg').text(r.Mensaje);
        }).fail(falla);
    }

    /* ---------- pago ---------- */
    function pagar() {
        if (state.pagando || pagada()) return;
        var t = totales();
        if (!state.datos || !state.datos.Items.length) { showNotification(1, 'warning', 'Agregue al menos un servicio.'); return; }
        if (sinCosto()) { confirmarTicket(); return; }
        if (state.tipo === '03' && (!state.receptor || validarReceptor(state.receptor))) {
            showNotification(1, 'info', 'Complete los datos fiscales del cliente para emitir el crédito fiscal.');
            abrirReceptor();
            return;
        }
        var errPago = errorPagos();
        if (errPago) { showNotification(1, 'warning', errPago); return; }

        var esc = function (s) { return $('<div>').text(s || '').html(); };
        var cliente = state.tipo === '03' ? state.receptor.Nombre : state.datos.Factura.Cliente;
        var detalle = '<b>' + esc(NOMBRE_DTE[state.tipo]) + '</b> para ' + esc(cliente) +
            (t.Descuento > 0 ? '<br>' + 'Descuento' + ': <b>-$' + dinero(t.Descuento) + '</b>' : '') +
            '<br>Total a pagar: <b>$' + dinero(t.Total) + '</b>' +
            '<br>' + (state.pagos.length > 1 ? 'Formas de pago:' : 'Forma de pago:') + ' ' + state.pagos.map(function (l) {
                return esc(NOMBRE_FORMA[l.forma]) + (state.pagos.length > 1 || l.forma === '01' ? ' $' + dinero(montoLinea(l)) : '');
            }).join(' + ') +
            (efectivo() > 0 ? '<br>Cambio: <b>$' + dinero(pagado() - t.Total) + '</b>' : '');

        state.pagando = true;   // evita doble clic mientras el diálogo está abierto
        swal({
            title: 'Confirmar pago',
            text: detalle,
            html: true,
            type: 'warning',
            showCancelButton: true,
            confirmButtonText: 'Pagar',
            cancelButtonText: 'Cancelar',
            confirmButtonColor: '#1A9608',
            cancelButtonClass: 'btn btn-block btn-default',
            buttonsStyling: false,
            closeOnConfirm: false       // el diálogo se reemplaza por "Espere un momento…"
        }, function (isConfirm) {
            // el ticket de venta se imprime siempre: la ventana se abre con el clic para que el navegador no la bloquee
            if (isConfirm) enviarPago(t, window.TicketVenta ? window.TicketVenta.ventana() : null);
            else state.pagando = false;
        });
    }

    /* ---------- espera y regreso a la lista ---------- */
    function esperando(texto) {
        swal({
            title: 'Espere un momento…',
            text: '<div class="spinner-border text-success my-2" role="status"></div><div>' + $('<div>').text(texto).html() + '</div>',
            html: true, showConfirmButton: false, showCancelButton: false, allowEscapeKey: false
        });
    }

    function volverPendientes() {
        if (typeof AjaxLink === 'function') AjaxLink('Facturacion/frm_Facturas.aspx');
    }

    function pagoTerminado(titulo, html) {
        swal({
            title: titulo, text: html, html: true, type: 'success',
            confirmButtonText: 'Volver a pendientes', confirmButtonColor: '#1A9608', allowEscapeKey: false
        }, volverPendientes);
    }

    function enviarPago(t, wTicket) {
        var esc = function (s) { return $('<div>').text(s == null ? '' : String(s)).html(); };
        esperando('Registrando el pago y emitiendo ' + (state.tipo === '03' ? 'el comprobante de crédito fiscal' : 'la factura') + ' en Hacienda. No cierre esta ventana.');
        var $btn = $('#btnPagar').prop('disabled', true).html('<span class="spinner-border spinner-border-sm"></span> Procesando…');
        api('PagarFactura', {
            req: {
                Factura: state.factura,
                TipoDte: state.tipo,
                FormaPago: formaPrincipal(),
                MontoRecibido: pagado(),
                // pago combinado: en efectivo va lo recibido; el servidor aplica el cambio (DteService.AplicarPagos)
                Pagos: state.pagos.map(function (l) { return { FormaPago: l.forma, Monto: r2(montoLinea(l)), Referencia: $.trim(l.ref || '') }; }),
                Receptor: state.tipo === '03' ? state.receptor : null,
                Usuario: usuario()
            }
        }).done(function (r) {
            if (!r.Ok) {
                if (wTicket) wTicket.close();
                swal({ title: 'No se completó el pago', text: r.Mensaje, type: 'error', confirmButtonText: 'Aceptar' });
                return;
            }
            state.datos.Factura.Pagada = true;
            state.datos.Dte = r.Dte;
            $('input[name=tipoDte]').prop('disabled', true);
            render();
            if (wTicket) window.TicketVenta.imprimir(state.factura, wTicket);
            if (r.Cambio > 0) $('#lblCambio').addClass('ok').text('Cambio: $' + dinero(r.Cambio));
            pagoTerminado('Pago registrado',
                esc(r.Mensaje)
                + (r.Cambio > 0 ? '<div style="font-size:1.6em;margin:10px 0"><b>Cambio: $' + dinero(r.Cambio) + '</b></div>' : '')
                + (r.Dte && r.Dte.NumeroControl ? '<div class="small text-muted">No. control: ' + esc(r.Dte.NumeroControl) + '</div>' : '')
                + (r.Dte && r.Dte.UrlPdf ? '<div class="mt-2"><a href="' + esc(r.Dte.UrlPdf) + '" target="_blank" rel="noopener"><i class="bx bxs-file-pdf"></i> Ver PDF</a></div>' : '')
                + '<div class="small text-muted mt-2">' + (wTicket ? 'Se abrió el ticket de venta para imprimir. ' : 'Permita las ventanas emergentes para imprimir el ticket. ')
                + 'Puede reimprimirlo con <b>Imprimir ticket</b> aquí o en Caja › Emitidos en esta caja.</div>');
        }).fail(function (xhr) { if (wTicket) wTicket.close(); swal.close(); falla(xhr); }).always(function () {
            state.pagando = false;
            $btn.prop('disabled', false).html('<i class="bx bx-check"></i> Pagar');
        });
    }

    /* ---------- ticket POS (servicio sin costo) ---------- */
    function confirmarTicket() {
        var esc = function (s) { return $('<div>').text(s || '').html(); };
        state.pagando = true;
        swal({
            title: 'Servicio sin costo',
            text: 'Para <b>' + esc(state.datos.Factura.Cliente) + '</b>, total <b>$0.00</b>.<br>No se genera DTE: se emitirá un <b>ticket POS</b> y la factura quedará cerrada.',
            html: true,
            type: 'info',
            showCancelButton: true,
            confirmButtonText: 'Emitir ticket',
            cancelButtonText: 'Cancelar',
            confirmButtonColor: '#1A9608',
            closeOnConfirm: false
        }, function (isConfirm) {
            if (isConfirm) emitirTicket(ventanaTicket());   // la ventana se abre con el clic para que el navegador no la bloquee
            else state.pagando = false;
        });
    }

    function emitirTicket(w) {
        esperando('Emitiendo el ticket POS. No cierre esta ventana.');
        var $btn = $('#btnPagar').prop('disabled', true).html('<span class="spinner-border spinner-border-sm"></span> Emitiendo…');
        api('EmitirTicket', { factura: state.factura, user: usuario() }).done(function (r) {
            if (!r.Ok) { if (w) w.close(); swal({ title: 'No se emitió el ticket', text: r.Mensaje, type: 'error', confirmButtonText: 'Aceptar' }); return; }
            state.datos.Factura.Pagada = true;
            state.datos.Ticket = r.Ticket;
            $('input[name=tipoDte]').prop('disabled', true);
            imprimirTicket(r.Ticket, w);
            pagoTerminado('Ticket emitido', $('<div>').text(r.Mensaje).html()
                + '<div class="small text-muted mt-2">Si no se imprimió, puede reimprimirlo desde Caja › Emitidos en esta caja.</div>');
        }).fail(function (xhr) { if (w) w.close(); swal.close(); falla(xhr); }).always(function () {
            state.pagando = false;
            $btn.prop('disabled', false);
            render();
        });
    }

    function ventanaTicket() {
        var w = window.open('', '_blank', 'width=420,height=720');
        if (!w) { showNotification(1, 'warning', 'Permita las ventanas emergentes para imprimir el ticket.'); return null; }
        w.document.write('<p style="font-family:sans-serif;text-align:center;margin-top:40px">Preparando ticket…</p>');
        return w;
    }

    function imprimirTicket(t, w) {
        w = w || ventanaTicket();
        if (!w || !t) return;
        var base = location.href.replace(/[#?].*$/, '').replace(/[^\/]*$/, '');
        w.document.open();
        w.document.write(htmlTicket(t, base));
        w.document.close();
    }

    // Ticket de 80 mm (mismo formato que el cupón de Registros/frm_ListaCupones.aspx)
    function htmlTicket(t, base) {
        var esc = function (s) { return $('<div>').text(s == null ? '' : String(s)).html(); };
        var filas = (t.Items || []).map(function (it) {
            return '<tr><td>' + esc(it.Descripcion) + '</td><td class="v">' + dinero(it.Valor) + '</td></tr>';
        }).join('');
        return '<!doctype html><html lang="es"><head><meta charset="utf-8"><title>Ticket ' + esc(t.Numero) + '</title><style>'
            + '@page{size:80mm auto;margin:0}'
            + '*{box-sizing:border-box}html,body{margin:0;padding:0;background:#fff;color:#000}'
            + 'body{width:80mm;font-family:Arial,Helvetica,sans-serif;font-size:10.5pt;line-height:1.25}'
            + '.t{width:72mm;margin:0 auto;padding:3mm 0 6mm}'
            + '.c{text-align:center}.logo{width:44mm;margin:0 auto 1mm;display:block}'
            + '.raya{border-top:1px dashed #000;margin:2.5mm 0}'
            + '.tit{font-size:12pt;font-weight:bold;letter-spacing:.5mm}'
            + '.num{font-family:"Courier New",monospace;font-size:14pt;font-weight:bold}'
            + '.emp{font-size:9pt}.dato{font-size:9.5pt;margin:.5mm 0}.dato b{display:inline-block;min-width:19mm}'
            + 'table{width:100%;border-collapse:collapse;font-size:9.5pt}td{padding:.6mm 0;vertical-align:top}.v{text-align:right;white-space:nowrap;padding-left:2mm}'
            + '.tot{font-size:13pt;font-weight:bold;display:flex;justify-content:space-between}'
            + '.pie{font-size:8.5pt;text-align:center}'
            + '@media screen{body{margin:10px auto;box-shadow:0 0 6px rgba(0,0,0,.25)}}'
            + '</style></head><body><div class="t">'
            + '<div class="c"><img class="logo" src="' + base + 'assets/images/logo-dpiecenter-clinica.png" alt="D\' Pie Center">'
            + (t.Empresa ? '<div class="emp"><b>' + esc(t.Empresa) + '</b></div>' : '')
            + (t.EmpresaNit ? '<div class="emp">NIT ' + esc(t.EmpresaNit) + (t.EmpresaNrc ? ' · NRC ' + esc(t.EmpresaNrc) : '') + '</div>' : '')
            + (t.EmpresaDireccion ? '<div class="emp">' + esc(t.EmpresaDireccion) + '</div>' : '')
            + (t.EmpresaTelefono ? '<div class="emp">Tel. ' + esc(t.EmpresaTelefono) + '</div>' : '')
            + '<div class="raya"></div><div class="tit">TICKET DE SERVICIO</div><div class="num">' + esc(t.Numero) + '</div></div>'
            + '<div class="raya"></div>'
            + '<div class="dato"><b>Fecha:</b> ' + esc(t.Fecha) + '</div>'
            + '<div class="dato"><b>Paciente:</b> ' + esc(t.Paciente) + '</div>'
            + (t.Documento ? '<div class="dato"><b>Documento:</b> ' + esc(t.Documento) + '</div>' : '')
            + '<div class="dato"><b>Atendió:</b> ' + esc(t.Cajero) + '</div>'
            + '<div class="raya"></div><table>' + filas + '</table><div class="raya"></div>'
            + '<div class="tot"><span>TOTAL</span><span>$' + dinero(t.Total) + '</span></div>'
            + '<div class="dato">' + esc(t.Motivo) + '</div>'
            + '<div class="raya"></div>'
            + '<div class="pie">Comprobante interno sin valor fiscal.<br>No es un documento tributario electrónico (DTE).<br>¡Gracias por su visita!</div>'
            + '</div><script>'
            + 'function listo(){var i=[].slice.call(document.images);return i.every(function(x){return x.complete;});}'
            + 'function imprimir(){if(!listo()){setTimeout(imprimir,150);return;}setTimeout(function(){window.focus();window.print();},150);}'
            + 'window.onafterprint=function(){window.close();};imprimir();'
            + '<\/script></body></html>';
    }

    /* ---------- eventos ---------- */
    $(function () {
        var $root = $('#pagoFactura');
        if (!$root.length) return;
        mtd_ValidateSession();
        state.factura = parseInt($root.data('factura'), 10) || 0;
        if (!state.factura) { showNotification(1, 'error', 'No se indicó la factura.'); return; }

        var $d = $('#recDepto').append($('<option>').val('').text('Seleccione…'));
        $.each(DEPARTAMENTOS, function (_, d) { $d.append($('<option>').val(d[0]).text(d[1])); });

        $('input[name=tipoDte]').on('change', function () { seleccionarTipo(this.value); });
        $('.pago-metodo').on('click', function () { if (!pagada()) agregarForma(String($(this).data('forma'))); });
        $('#pagoLineas').on('click', '.pago-linea', function (e) {
            if (pagada() || $(e.target).is('input')) return;
            var i = +$(this).data('i');
            if ($(e.target).closest('.quitar').length) { quitarLinea(i); return; }
            if (state.sel !== i) { state.sel = i; renderMonto(); }
        }).on('input', '.ref', function () {
            state.pagos[+$(this).closest('.pago-linea').data('i')].ref = $(this).val();
        });

        $('.pago-teclado').on('click', '[data-tecla]', function () { tecla(String($(this).data('tecla'))); })
            .on('click', '[data-suma]', function () { if (!pagada()) { var l = linea(); fijarMonto((l.auto ? 0 : montoLinea(l)) + Number($(this).data('suma'))); } })
            .on('click', '[data-accion]', function () { accionTeclado($(this).data('accion')); });

        $('#btnServicios').on('click', abrirServicios);
        $('#txtBuscarServicio').on('input', pintarServicios);
        $('#listaServicios').on('click', '.list-group-item', function () { agregarServicio(+$(this).data('id'), $(this)); });
        $('#tbItems').on('click', '.btn-quitar', function () { quitarServicio(+$(this).data('id')); });

        $('#btnDatosFiscales').on('click', abrirReceptor);
        $('#recDepto').on('change', function () { llenarMunicipios(this.value, ''); llenarDistritos(this.value, '', ''); });
        $('#recMuni').on('change', function () { llenarDistritos($('#recDepto').val(), this.value, ''); });
        $('#btnBuscarNit').on('click', buscarNit);
        $('#btnAceptarReceptor').on('click', aceptarReceptor);

        $('#btnAplicarCupon').on('click', function () { aplicarCupon($('#txtCupon').val()); });
        $('#txtCupon').on('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); aplicarCupon($(this).val()); } });
        $('#cardCupon').on('click', '#btnQuitarCupon', quitarCupon);        if ('BarcodeDetector' in window && navigator.mediaDevices) $('#btnCamaraCupon').removeClass('d-none').on('click', escanearConCamara);
        $(document).off('keydown.lectorCupon').on('keydown.lectorCupon', function (e) {
            if (!$('#pagoFactura').length) { $(document).off('keydown.lectorCupon'); detenerCamara(); return; }
            capturarLector(e);
        });

        $('#btnPagar').on('click', pagar);
        $('#btnTicketVenta').on('click', function () { if (window.TicketVenta) window.TicketVenta.imprimir(state.factura); });
        $('#btnEnviarCorreo').on('click', enviarCorreo);
        $('#btnImprimirTicket').on('click', function () { if (state.datos) imprimirTicket(state.datos.Ticket); });
        $('#btnRegresar').on('click', function () { AjaxLink('Facturacion/frm_Facturas.aspx'); });

        // Teclado físico: números, punto y retroceso (solo en esta pantalla y sin modales abiertos)
        $(document).off('keydown.pagoFactura').on('keydown.pagoFactura', function (e) {
            if (!$('#pagoFactura').length) { $(document).off('keydown.pagoFactura'); return; }
            if ($(e.target).is('input, textarea, select') || $('.modal.show, .sweet-alert:visible').length) return;
            if (/^[0-9]$/.test(e.key)) { tecla(e.key); e.preventDefault(); }
            else if (e.key === '.' || e.key === ',') { tecla('.'); e.preventDefault(); }
            else if (e.key === 'Backspace') { accionTeclado('borrar'); e.preventDefault(); }
        });

        cargar();
    });

})(jQuery);
