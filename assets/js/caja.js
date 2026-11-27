/* Caja del día por usuario – Facturacion/frm_Facturas.aspx
   Sin caja abierta hoy no se puede cobrar: primero se abre con el fondo, luego se cobran los procesos finalizados
   (el DTE se emite en frm_OpenFactura.aspx) y al final se cierra con el arqueo del efectivo. */
(function ($) {
    'use strict';

    var URL = 'Facturacion/frm_Facturas.aspx/';
    var POR_PAGINA = 50, CLAVE_RANGO = 'dpie.caja.rango';
    var state = { estado: null, pendientes: [], emitidos: [], salidas: [], pagina: 1, texto: '', rango: leer() || '7', timer: null };

    /* ---------- utilidades ---------- */
    function api(metodo, datos) {
        return $.ajax({ type: 'POST', url: URL + metodo, data: JSON.stringify(datos || {}), contentType: 'application/json; charset=utf-8', dataType: 'json' })
            .then(function (r) { return r.d; });
    }
    function falla(xhr) { if (xhr && xhr.statusText !== 'abort') showNotification(1, 'error', 'Error de conexión (HTTP ' + xhr.status + ').'); }
    function error(r) {
        var m = (r && r.Mensaje) || 'No fue posible completar la acción.';
        if (/sesi[oó]n/i.test(m) && typeof mtd_ValidateSession === 'function') { mtd_ValidateSession(); return; }
        showNotification(1, 'warning', m);
    }
    function esc(s) { return $('<div/>').text(s == null ? '' : String(s)).html(); }
    function dinero(n) { return '$ ' + Number(n || 0).toLocaleString('es-SV', { minimumFractionDigits: 2, maximumFractionDigits: 2 }); }
    function titulo(s) { return String(s || '').toLowerCase().replace(/(^|\s)(\S)/g, function (m, a, b) { return a + b.toUpperCase(); }); }
    function dos(n) { return (n < 10 ? '0' : '') + n; }
    function iso(d) { return d.getFullYear() + '-' + dos(d.getMonth() + 1) + '-' + dos(d.getDate()); }
    function fecha(s) { if (!s) return ''; var p = s.split('-'); return p[2] + '/' + p[1] + '/' + p[0]; }
    function leer() { try { return localStorage.getItem(CLAVE_RANGO); } catch (e) { return null; } }
    function guardar(v) { try { localStorage.setItem(CLAVE_RANGO, v); } catch (e) { } }
    function puedeCobrar() { var c = state.estado && state.estado.Caja; return !!(c && c.Abierta && !c.Anterior); }

    /* ---------- estado de la caja ---------- */
    function cargarEstado() {
        return api('Estado').done(function (r) {
            if (!r.Ok) { error(r); return; }
            state.estado = r;
            pintarEstado();
            $('#cjListas').removeClass('d-none');
            pintarPendientes();
            if (r.Caja) { cargarEmitidos(); cargarSalidas(); }
            else { state.emitidos = []; state.salidas = []; pintarEmitidos(); pintarSalidas(); }
        }).fail(falla);
    }

    function kpi(etiqueta, valor, sub, clase) {
        return '<div class="col"><div class="card radius-10 mb-0 cj-kpi ' + (clase || '') + '"><div class="card-body"><span>' + etiqueta + '</span><strong>' + valor + '</strong>'
            + (sub ? '<small>' + sub + '</small>' : '') + '</div></div></div>';
    }

    function pintarEstado() {
        var r = state.estado, c = r.Caja, s = r.Resumen, html;
        if (!c) {
            // Fondo propuesto: lo contado al cerrar la caja anterior (se puede cambiar; si es distinto se avisa)
            var u = r.UltimoCierre, propuesto = u ? Number(u.EfectivoContado).toFixed(2) : '0.00';
            $('#cjEstadoChip').html('<span class="ad-chip ad-chip-no"><i class="bx bx-lock-alt"></i> Caja sin abrir</span>');
            html = '<div class="card radius-10 cj-apertura"><div class="card-body d-flex flex-wrap align-items-center gap-4">'
                + '<div class="cj-apertura-icono"><i class="bx bx-wallet"></i></div>'
                + '<div class="flex-fill"><h5 class="mb-1">Abra su caja del día</h5><p class="text-muted mb-0">Para cobrar y emitir documentos tributarios electrónicos hoy, ' + fecha(r.Hoy) + ', primero abra su caja con el fondo inicial de efectivo.</p></div>'
                + '<form id="cjFormApertura" class="d-flex flex-wrap align-items-end gap-2" novalidate>'
                + '<div><label for="cjFondo" class="form-label small mb-1">Fondo de caja</label><div class="input-group"><span class="input-group-text">$</span>'
                + '<input type="number" class="form-control text-end" id="cjFondo" min="0" max="10000" step="0.01" value="' + propuesto + '" style="max-width:140px" /></div></div>'
                + '<button type="submit" class="btn btn-primary" id="cjAbrir"><i class="bx bx-lock-open-alt"></i> Abrir caja</button></form>'
                + '<div class="w-100 small" id="cjFondoAviso"></div>'
                + '</div></div>';
        } else if (c.Anterior) {
            $('#cjEstadoChip').html('<span class="ad-chip ad-chip-no"><i class="bx bx-error"></i> Caja pendiente de cierre</span>');
            html = '<div class="alert alert-warning d-flex flex-wrap align-items-center gap-3"><i class="bx bx-error fs-3"></i>'
                + '<div class="flex-fill"><strong>Su caja del ' + fecha(c.Fecha) + ' sigue abierta.</strong><br>Ciérrela con el arqueo del efectivo para poder abrir la de hoy.</div>'
                + '<button type="button" class="btn btn-danger" id="cjCerrar"><i class="bx bx-lock-alt"></i> Cerrar caja del ' + fecha(c.Fecha) + '</button></div>'
                + resumenHtml(c, s);
        } else if (c.Abierta) {
            $('#cjEstadoChip').html('<span class="ad-chip ad-chip-ok"><i class="bx bx-lock-open-alt"></i> Caja abierta desde las ' + esc(c.HoraApertura) + '</span>'
                + '<button type="button" class="btn btn-sm btn-outline-secondary cj-sacar" data-tipo="S"><i class="bx bx-transfer-alt"></i> Manejo de efectivo</button>'
                + '<button type="button" class="btn btn-sm btn-outline-danger" id="cjCerrar"><i class="bx bx-lock-alt"></i> Cerrar caja</button>');
            html = resumenHtml(c, s);
        } else {
            var dif = (c.Sobrante || 0) - (c.Faltante || 0);
            $('#cjEstadoChip').html('<span class="ad-chip"><i class="bx bx-lock-alt"></i> Caja cerrada a las ' + esc(c.HoraCierre) + '</span>'
                + (r.EsAdministrador ? '<button type="button" class="btn btn-sm btn-outline-secondary" id="cjReabrir"><i class="bx bx-revision"></i> Reabrir</button>' : ''));
            html = '<div class="alert alert-secondary d-flex flex-wrap align-items-center gap-3"><i class="bx bx-lock-alt fs-3"></i><div class="flex-fill">'
                + '<strong>Su caja de hoy está cerrada.</strong> Ya no se pueden emitir documentos hoy.'
                + '<div class="small mt-1">Efectivo esperado ' + dinero(c.EfectivoEsperado) + ' · contado ' + dinero(c.EfectivoContado) + ' · '
                + (dif === 0 ? '<span class="text-success">sin diferencia</span>' : dif > 0 ? '<span class="text-primary">sobrante ' + dinero(dif) + '</span>' : '<span class="text-danger">faltante ' + dinero(-dif) + '</span>')
                + (c.Observaciones ? ' · ' + esc(c.Observaciones) : '') + '</div></div></div>'
                + resumenHtml(c, s);
        }
        $('#cjPanel').html(html);
        if (!c) avisoFondo();
    }

    function resumenHtml(c, s) {
        s = s || { Total: 0, Documentos: 0, Anulados: 0, Efectivo: 0, Salidas: 0, CantidadSalidas: 0, Tickets: 0, Fondo: c.Fondo, EfectivoEsperado: c.Fondo };
        var pend = state.pendientes, total = pend.reduce(function (a, p) { return a + p.Total; }, 0);
        return '<div class="row row-cols-2 row-cols-lg-5 g-3 mb-3">'
            + kpi('Cobrado', dinero(s.Total), s.Documentos + (s.Documentos === 1 ? ' documento' : ' documentos') + (s.Anulados ? ' · ' + s.Anulados + ' anulados' : '') + (s.Tickets ? ' · ' + s.Tickets + (s.Tickets === 1 ? ' ticket' : ' tickets') + ' sin costo' : ''), 'cj-kpi-ok')
            + kpi('Efectivo en caja', dinero(s.EfectivoEsperado), 'fondo ' + dinero(s.Fondo) + ' + cobros ' + dinero(s.Efectivo)
                + (s.Entradas ? ' + entradas ' + dinero(s.Entradas) : '') + (s.Salidas ? ' − salidas ' + dinero(s.Salidas) : ''))
            + kpi('Otras formas de pago', dinero(s.Total - s.Efectivo), 'tarjeta, transferencia…')
            + kpi('Pendientes de cobro', '<span id="cjKpiPend">' + pend.length + '</span>', '<span id="cjKpiPendTotal">' + dinero(total) + '</span> en la lista', 'cj-kpi-pend')
            + kpi('Caja del', fecha(c.Fecha), 'abierta a las ' + esc(c.HoraApertura))
            + '</div>';
    }

    /* ---------- pendientes de cobro ---------- */
    function rango() {
        var hoy = new Date(), d = new Date(hoy);
        if (state.rango === 'todo') return { desde: '', hasta: '' };
        if (state.rango === '7') d.setDate(hoy.getDate() - 6);
        else if (state.rango === '30') d.setDate(hoy.getDate() - 29);
        return { desde: iso(d), hasta: iso(hoy) };
    }

    function cargarPendientes() {
        $('#cjPendientes').html('<tr><td colspan="6" class="text-center py-4"><div class="spinner-border spinner-border-sm text-primary"></div> Cargando…</td></tr>');
        var r = rango();
        return api('Pendientes', { desde: r.desde, hasta: r.hasta, texto: state.texto }).done(function (x) {
            if (!x.Ok) { error(x); return; }
            state.pendientes = x.Items || [];
            pintarPendientes();
        }).fail(falla);
    }

    function pintarPendientes() {
        var lista = state.pendientes, total = lista.reduce(function (a, p) { return a + p.Total; }, 0);
        var paginas = Math.max(1, Math.ceil(lista.length / POR_PAGINA));
        if (state.pagina > paginas) state.pagina = paginas;
        var ini = (state.pagina - 1) * POR_PAGINA, filas = lista.slice(ini, ini + POR_PAGINA), cobrar = puedeCobrar();
        $('#cjPendCont').text(lista.length);
        $('#cjKpiPend').text(lista.length);
        $('#cjKpiPendTotal').text(dinero(total));
        $('#cjPendResumen').text(lista.length ? lista.length + ' por cobrar · ' + dinero(total) : '');
        $('#cjRangos [data-rango]').removeClass('active btn-primary').addClass('btn-light').filter('[data-rango="' + state.rango + '"]').removeClass('btn-light').addClass('active btn-primary');

        $('#cjPendientes').html(filas.length ? filas.map(function (p) {
            return '<tr data-factura="' + p.IdFactura + '">'
                + '<td class="text-nowrap">' + fecha(p.Fecha) + (p.Hora && p.Hora !== '12:00 AM' ? '<div class="ad-ayuda">' + esc(p.Hora) + '</div>' : '') + '<div class="ad-ayuda">N.º ' + p.IdFactura + '</div></td>'
                + '<td><div class="fw-medium">' + esc(titulo(p.Paciente)) + '</div><div class="ad-ayuda">' + esc(p.Documento) + (p.Celular ? ' · ' + esc(p.Celular) : '') + '</div>'
                + (p.Reemplazo ? '<span class="ad-chip ad-chip-no" title="Su DTE anterior se anuló: emita el que lo reemplaza">Reemplaza DTE anulado</span>' : '') + '</td>'
                + '<td class="d-none d-lg-table-cell small"><span class="cj-servicios" title="' + esc(p.Servicios) + '">' + esc(p.Servicios) + '</span></td>'
                + '<td class="d-none d-md-table-cell small">' + esc(p.Especialista) + '</td>'
                + '<td class="text-end fw-medium">' + dinero(p.Total) + '</td>'
                + '<td class="text-end"><button type="button" class="btn btn-sm btn-primary cj-cobrar"' + (cobrar ? '' : ' disabled title="Abra su caja para cobrar"') + '><i class="bx bx-receipt"></i> Cobrar</button></td>'
                + '</tr>';
        }).join('') : '<tr><td colspan="6" class="text-center text-muted py-5"><i class="bx bx-check-circle fs-3 d-block mb-1 text-success"></i>No hay procesos finalizados pendientes de cobro en este periodo.</td></tr>');

        $('#cjPaginaTexto').text(lista.length > POR_PAGINA ? 'Mostrando ' + (ini + 1) + '–' + Math.min(ini + POR_PAGINA, lista.length) + ' de ' + lista.length : '');
        var $p = $('#cjPaginas').empty();
        if (paginas > 1) {
            var d = Math.max(1, state.pagina - 2), h = Math.min(paginas, d + 4);
            var item = function (n, t, act, des) { return '<li class="page-item' + (act ? ' active' : '') + (des ? ' disabled' : '') + '"><a class="page-link" href="javascript:;" data-pagina="' + n + '">' + t + '</a></li>'; };
            $p.append(item(state.pagina - 1, '‹', false, state.pagina === 1));
            for (var n = d; n <= h; n++) $p.append(item(n, n, n === state.pagina, false));
            $p.append(item(state.pagina + 1, '›', false, state.pagina === paginas));
        }
    }

    /* ---------- emitidos ---------- */
    function cargarEmitidos() {
        var c = state.estado.Caja;
        return api('Emitidos', { id: c.Id }).done(function (r) {
            if (!r.Ok) { error(r); return; }
            state.emitidos = r.Items || [];
            pintarEmitidos();
        }).fail(falla);
    }

    function pintarEmitidos() {
        var lista = state.emitidos;
        $('#cjEmiCont').text(lista.length);
        var estados = { G: ['Generado', 'ad-chip-info'], T: ['Transmitido', 'ad-chip-ok'], R: ['Rechazado', 'ad-chip-no'], A: ['Anulado', 'ad-chip-no'], K: ['Sin costo', 'ad-chip-info'] };
        var tipos = { '01': 'Factura', '03': 'Crédito fiscal', TK: 'Ticket POS' };
        $('#cjEmitidos').html(lista.length ? lista.map(function (d) {
            var e = estados[d.Estado] || [d.Estado, ''];
            return '<tr class="' + (d.Estado === 'A' ? 'ad-inactivo' : '') + '">'
                + '<td>' + esc(d.Hora) + '</td>'
                + '<td><div class="fw-medium">' + (tipos[d.TipoDte] || d.TipoDte) + '</div><div class="ad-url">' + esc(d.NumeroControl) + '</div></td>'
                + '<td>' + esc(titulo(d.Receptor)) + '</td>'
                + '<td class="d-none d-md-table-cell small">' + esc(d.FormaPago) + '</td>'
                + '<td class="text-end fw-medium">' + dinero(d.Total) + '</td>'
                + '<td class="text-center"><span class="ad-chip ' + e[1] + '">' + e[0] + '</span></td>'
                + '<td class="text-end text-nowrap">' + (d.RutaPdf ? '<a class="btn btn-sm btn-outline-secondary" target="_blank" rel="noopener" href="' + esc(d.RutaPdf) + '" title="Ver PDF"><i class="bx bxs-file-pdf"></i></a> ' : '')
                + (d.TipoDte !== 'TK' ? '<button type="button" class="btn btn-sm btn-outline-dark cj-ticket" data-factura="' + d.IdFactura + '" title="Imprimir ticket de venta"><i class="bx bx-printer"></i></button> ' : '')
                + '<button type="button" class="btn btn-sm btn-outline-primary cj-ver" data-factura="' + d.IdFactura + '" title="Abrir"><i class="bx bx-show"></i></button></td></tr>';
        }).join('') : '<tr><td colspan="7" class="text-center text-muted py-4">Aún no hay documentos emitidos en esta caja.</td></tr>');
    }

    /* ---------- manejo de efectivo: entradas y salidas ---------- */
    var MOVIMIENTO = {
        E: { nombre: 'Entrada', titulo: 'Entrada de efectivo', tipos: ['Reposición de fondo', 'Cambio (sencillo)', 'Préstamo', 'Otro'],
             ejemplo: 'Ejemplo: reposición del fondo de caja entregada por administración', referencia: 'N.º de vale, nombre de quien entrega…',
             boton: '<i class="bx bx-log-in-circle"></i> Registrar entrada', clase: 'btn-success' },
        S: { nombre: 'Salida', titulo: 'Salida de efectivo', tipos: ['Gasto', 'Pago a proveedor', 'Depósito bancario', 'Retiro', 'Otro'],
             ejemplo: 'Ejemplo: compra de agua y café para la sala de espera', referencia: 'N.º de factura del proveedor, boleta de depósito…',
             boton: '<i class="bx bx-log-out-circle"></i> Registrar salida', clase: 'btn-warning' }
    };

    function cargarSalidas() {
        return api('Salidas', { id: state.estado.Caja.Id }).done(function (r) {
            if (!r.Ok) { error(r); return; }
            state.salidas = r.Items || [];
            pintarSalidas();
        }).fail(falla);
    }

    function pintarSalidas() {
        var lista = state.salidas, activas = $.grep(lista, function (x) { return x.Estado === 'A'; }), abierta = puedeCobrar();
        var ent = activas.filter(function (x) { return x.Tipo === 'E'; }), sal = activas.filter(function (x) { return x.Tipo !== 'E'; });
        var suma = function (l) { return l.reduce(function (a, x) { return a + x.Monto; }, 0); };
        $('#cjSalCont').text(activas.length);
        $('#cjSalResumen').html(activas.length
            ? '<span class="text-success">' + ent.length + (ent.length === 1 ? ' entrada' : ' entradas') + ' · + ' + dinero(suma(ent)) + '</span>'
              + ' &nbsp;|&nbsp; <span class="text-danger">' + sal.length + (sal.length === 1 ? ' salida' : ' salidas') + ' · − ' + dinero(suma(sal)) + '</span>' : '');
        $('.cj-sacar, .cj-entrada').prop('disabled', !abierta).attr('title', abierta ? '' : 'Solo con la caja abierta de hoy');
        $('#cjSalidas').html(lista.length ? lista.map(function (x) {
            var anulada = x.Estado !== 'A', entrada = x.Tipo === 'E';
            return '<tr class="' + (anulada ? 'ad-inactivo' : '') + '" data-id="' + x.Id + '">'
                + '<td>' + esc(x.Hora) + '<div class="ad-ayuda">' + esc(x.Usuario) + '</div></td>'
                + '<td><div class="small fw-semibold ' + (entrada ? 'text-success' : 'text-danger') + '"><i class="bx ' + (entrada ? 'bx-log-in-circle' : 'bx-log-out-circle') + '"></i> ' + (entrada ? 'Entrada' : 'Salida') + '</div>'
                + '<span class="ad-chip ' + (anulada ? '' : 'ad-chip-lila') + '">' + esc(x.Categoria) + '</span></td>'
                + '<td>' + esc(x.Motivo) + (anulada ? '<div class="ad-ayuda text-danger">Anulada a las ' + esc(x.HoraAnulacion) + ': ' + esc(x.MotivoAnulacion) + '</div>' : '') + '</td>'
                + '<td class="d-none d-md-table-cell small">' + esc(x.Referencia) + '</td>'
                + '<td class="text-end fw-medium ' + (anulada ? '' : entrada ? 'text-success' : 'text-danger') + '">' + (anulada ? '<s>' + dinero(x.Monto) + '</s>' : (entrada ? '+ ' : '− ') + dinero(x.Monto)) + '</td>'
                + '<td class="text-end">' + (!anulada && abierta ? '<button type="button" class="btn btn-sm btn-outline-danger cj-anular-salida" title="Anular movimiento registrado por error"><i class="bx bx-undo"></i></button>' : '') + '</td></tr>';
        }).join('') : '<tr><td colspan="6" class="text-center text-muted py-4">No hay entradas ni salidas de efectivo en esta caja.</td></tr>');
    }

    function tipoMovimiento(tipo) {
        var m = MOVIMIENTO[tipo];
        $('#cjMovEntrada').prop('checked', tipo === 'E');
        $('#cjMovSalida').prop('checked', tipo === 'S');
        $('#cjSalidaTitulo').text(m.titulo);
        $('#cjSalCategoriaLbl').html('Tipo de ' + m.nombre.toLowerCase() + ' <span class="text-danger">*</span>');
        $('#cjSalCategoria').html('<option value="">Seleccione…</option>' + m.tipos.map(function (t) { return '<option>' + esc(t) + '</option>'; }).join(''));
        $('#cjSalMotivo').attr('placeholder', m.ejemplo);
        $('#cjSalReferencia').attr('placeholder', m.referencia);
        $('#cjSalGuardar').removeClass('btn-success btn-warning').addClass(m.clase).html(m.boton);
        $('#cjFormSalida .is-invalid').removeClass('is-invalid');
    }

    function abrirSalida() {
        var s = state.estado.Resumen || {}, disponible = (s.EfectivoEsperado != null ? s.EfectivoEsperado : state.estado.Caja.Fondo);
        $('#cjSalDisponible').text(dinero(disponible)).data('valor', disponible);
        $('#cjFormSalida')[0].reset();
        $('#cjSalMotivoCont').text('0');
        tipoMovimiento($(this).data('tipo') === 'E' ? 'E' : 'S');
        bootstrap.Modal.getOrCreateInstance(document.getElementById('cjModalSalida')).show();
        setTimeout(function () { $('#cjSalMonto').trigger('focus'); }, 300);
    }

    function registrarSalida() {
        $('#cjFormSalida .is-invalid').removeClass('is-invalid');
        var tipo = $('#cjMovEntrada').is(':checked') ? 'E' : 'S', m = MOVIMIENTO[tipo];
        var monto = Math.round(parseFloat($('#cjSalMonto').val()) * 100) / 100, disponible = +$('#cjSalDisponible').data('valor') || 0;
        var categoria = $('#cjSalCategoria').val(), motivo = $.trim($('#cjSalMotivo').val());
        if (isNaN(monto) || monto <= 0) { $('#cjSalMonto').addClass('is-invalid').trigger('focus'); showNotification(1, 'warning', 'Ingrese el monto.'); return; }
        if (tipo === 'S' && monto > disponible) { $('#cjSalMonto').addClass('is-invalid').trigger('focus'); showNotification(1, 'warning', 'No hay suficiente efectivo: disponible ' + dinero(disponible) + '.'); return; }
        if (!categoria) { $('#cjSalCategoria').addClass('is-invalid').trigger('focus'); showNotification(1, 'warning', 'Seleccione el tipo de ' + m.nombre.toLowerCase() + '.'); return; }
        if (motivo.length < 5) { $('#cjSalMotivo').addClass('is-invalid').trigger('focus'); showNotification(1, 'warning', 'Describa el motivo de la ' + m.nombre.toLowerCase() + '.'); return; }
        var $b = $('#cjSalGuardar').prop('disabled', true);
        api('MovimientoEfectivo', { id: state.estado.Caja.Id, tipo: tipo, monto: monto, categoria: categoria, motivo: motivo, referencia: $.trim($('#cjSalReferencia').val()) }).done(function (r) {
            if (!r.Ok) { error(r); return; }
            bootstrap.Modal.getInstance(document.getElementById('cjModalSalida')).hide();
            showNotification(1, 'success', r.Mensaje);
            cargarEstado();
        }).fail(falla).always(function () { $b.prop('disabled', false); });
    }

    function anularSalida(id) {
        var x = $.grep(state.salidas, function (s) { return s.Id === id; })[0];
        swal({
            title: 'Anular ' + (x.Tipo === 'E' ? 'entrada' : 'salida'), text: (x.Tipo === 'E' ? 'Entrada' : 'Salida') + ' de ' + dinero(x.Monto) + ': ' + x.Motivo + '\n\n¿Por qué la anula?', type: 'input', inputPlaceholder: 'Ejemplo: se registró un monto equivocado',
            showCancelButton: true, confirmButtonText: 'Anular ' + (x.Tipo === 'E' ? 'entrada' : 'salida'), cancelButtonText: 'Cancelar', closeOnConfirm: false
        }, function (motivo) {
            if (motivo === false) return;
            motivo = $.trim(motivo || '');
            if (motivo.length < 5) { swal.showInputError('Indique el motivo (al menos 5 caracteres).'); return false; }
            api('AnularSalida', { salida: id, motivo: motivo }).done(function (r) {
                if (!r.Ok) { swal.showInputError(r.Mensaje); return; }
                swal.close();
                showNotification(1, 'success', r.Mensaje);
                cargarEstado();
            }).fail(function (xhr) { swal.close(); falla(xhr); });
        });
    }

    /* ---------- abrir, cerrar, reabrir ---------- */
    // Diferencia entre el fondo escrito y lo contado al cerrar la caja anterior (null si no hay cierre anterior)
    function difFondo() {
        var u = state.estado && state.estado.UltimoCierre, f = parseFloat($('#cjFondo').val());
        if (!u || isNaN(f)) return null;
        return Math.round((f - Number(u.EfectivoContado)) * 100) / 100;
    }

    function avisoFondo() {
        var u = state.estado && state.estado.UltimoCierre, d = difFondo(), $a = $('#cjFondoAviso');
        if (!u) { $a.html(''); return; }
        var base = 'Al cerrar su caja del ' + fecha(u.Fecha) + ' contó <strong>' + dinero(u.EfectivoContado) + '</strong>.';
        $a.html(d === null || d === 0
            ? '<span class="text-muted"><i class="bx bx-info-circle"></i> ' + base + ' Se propone como fondo.</span>'
            : '<span class="text-danger"><i class="bx bx-error"></i> ' + base + ' El fondo escrito tiene ' + (d > 0 ? dinero(d) + ' de más' : dinero(-d) + ' de menos')
                + ': esa diferencia aparecerá como ' + (d > 0 ? 'faltante' : 'sobrante') + ' al cerrar si no la corrige.</span>');
    }

    function abrir() {
        var fondo = parseFloat($('#cjFondo').val());
        if (isNaN(fondo) || fondo < 0 || fondo > 10000) { $('#cjFondo').addClass('is-invalid').trigger('focus'); showNotification(1, 'warning', 'El fondo debe estar entre 0 y 10,000.'); return; }
        var d = difFondo(), u = state.estado.UltimoCierre;
        if (d && !abrir.confirmado) {
            swal({
                title: 'El fondo no coincide', type: 'warning', html: true, showCancelButton: true,
                text: 'Al cerrar su caja del ' + fecha(u.Fecha) + ' contó <b>' + dinero(u.EfectivoContado) + '</b> y ahora escribió <b>' + dinero(fondo) + '</b> '
                    + '(' + (d > 0 ? dinero(d) + ' de más' : dinero(-d) + ' de menos') + ').<br><br>Si no corresponde, esa diferencia saldrá como '
                    + (d > 0 ? 'faltante' : 'sobrante') + ' en el cierre de hoy. ¿Abrir la caja con ' + dinero(fondo) + '?',
                confirmButtonText: 'Sí, abrir con ' + dinero(fondo), cancelButtonText: 'Corregir el fondo'
            }, function (ok) {
                if (!ok) { setTimeout(function () { $('#cjFondo').trigger('focus').trigger('select'); }, 200); return; }
                abrir.confirmado = true; abrir(); abrir.confirmado = false;
            });
            return;
        }
        var $b = $('#cjAbrir').prop('disabled', true);
        api('Abrir', { fondo: Math.round(fondo * 100) / 100 }).done(function (r) {
            if (!r.Ok) { error(r); return; }
            showNotification(1, 'success', r.Mensaje);
            cargarEstado();
        }).fail(falla).always(function () { $b.prop('disabled', false); });
    }

    function abrirCierre() {
        var c = state.estado.Caja, s = state.estado.Resumen || { PorForma: [], Fondo: c.Fondo, Efectivo: 0, EfectivoEsperado: c.Fondo };
        $('#cjCierreTitulo').text('Cerrar caja del ' + fecha(c.Fecha));
        $('#cjCierreFormas').html(s.PorForma.length ? s.PorForma.map(function (f) {
            return '<div class="d-flex justify-content-between small"><span>' + esc(f.FormaPago) + ' <span class="text-muted">(' + f.Documentos + ')</span></span><strong>' + dinero(f.Total) + '</strong></div>';
        }).join('') : '<div class="small text-muted">Sin cobros.</div>');
        $('#cjCierreFondo').text(dinero(s.Fondo));
        $('#cjCierreEfectivo').text(dinero(s.Efectivo));
        $('#cjCierreEntradas').text('+ ' + dinero(s.Entradas || 0)).closest('div').toggleClass('d-none', !s.Entradas);
        $('#cjCierreSalidas').text('− ' + dinero(s.Salidas || 0)).closest('div').toggleClass('d-none', !s.Salidas);
        $('#cjCierreEsperado').text(dinero(s.EfectivoEsperado)).data('valor', s.EfectivoEsperado);
        $('#cjContado').val('').removeClass('is-invalid');
        $('#cjObservaciones').val('');
        $('#cjDiferencia').html('');
        cargarCuadre(c.Id);
        bootstrap.Modal.getOrCreateInstance(document.getElementById('cjModalCierre')).show();
        setTimeout(function () { $('#cjContado').trigger('focus'); }, 300);
    }

    /* Datos del cierre: cobros de la caja del usuario y aviso de procedimientos del día pendientes de facturar */
    function cargarCuadre(id) {
        state.cuadre = null;
        $('#cjCuadre').html('<div class="small text-muted"><span class="spinner-border spinner-border-sm text-primary"></span> Calculando…</div>');
        api('Cuadre', { id: id }).done(function (r) {
            if (!r.Ok) { $('#cjCuadre').html('<div class="small text-danger">' + esc(r.Mensaje) + '</div>'); return; }
            state.cuadre = r.Cuadre;
            pintarCuadre(r.Cuadre);
        }).fail(function (xhr) { $('#cjCuadre').html('<div class="small text-danger">No se pudo calcular el cuadre (HTTP ' + xhr.status + ').</div>'); });
    }

    function pintarCuadre(q) {
        function fila(etiqueta, valor, clase, sub) {
            return '<div class="d-flex justify-content-between small' + (clase ? ' ' + clase : '') + '"><span>' + etiqueta + (sub ? ' <span class="text-muted">' + sub + '</span>' : '') + '</span><strong>' + valor + '</strong></div>';
        }
        function cant(n, uno, varios) { return '(' + n + ' ' + (n === 1 ? uno : varios) + ')'; }
        // Solo los cobros de esta caja (de este usuario); no se mezclan otras cajas
        // Cuadre: valor de los servicios − descuentos por tratamiento − descuentos por cupón = cobrado en esta caja
        var conDesc = q.Descuentos > 0.004;
        var html = (conDesc ? fila('Valor de los servicios', dinero(q.ValorServicios), '', cant(q.Documentos, 'documento', 'documentos')) : '')
            + (q.DescuentoTratamientos > 0.004 ? fila('Descuentos por tratamientos', '− ' + dinero(q.DescuentoTratamientos), 'text-success') : '')
            + (q.DescuentoCupones > 0.004 ? fila('Descuentos por cupones', '− ' + dinero(q.DescuentoCupones), 'text-success', cant(q.Cupones, 'cupón', 'cupones')) : '')
            + (conDesc ? '<div class="border-top mt-1 pt-1"></div>' : '')
            + fila('Cobrado en esta caja', dinero(q.CajaTotal), conDesc ? 'fw-semibold' : '', conDesc ? '' : cant(q.Documentos, 'documento', 'documentos'));

        // Pendientes de facturar: solo alerta (no impide cerrar ni pide observación)
        if (q.Pendientes) {
            html += '<div class="alert alert-warning small py-2 mt-2 mb-0"><i class="bx bx-info-circle"></i> <strong>Aviso:</strong> '
                + (q.Pendientes === 1 ? 'hay 1 procedimiento finalizado hoy pendiente de facturar' : 'hay ' + q.Pendientes + ' procedimientos finalizados hoy pendientes de facturar')
                + ' (' + dinero(q.ValorPendientes) + '). Puede cerrar su caja de todas formas.'
                + '<ul class="mb-0 mt-1 ps-3">' + q.ListaPendientes.map(function (p) {
                    return '<li>' + esc(titulo(p.Paciente)) + ' · ' + dinero(p.Valor)
                        + '<span class="text-muted">' + (p.Hora ? ' · ' + esc(p.Hora) : '') + (p.Especialista ? ' · ' + esc(p.Especialista) : '') + (p.IdFactura ? ' · N.º ' + p.IdFactura : '') + '</span></li>';
                }).join('') + '</ul></div>';
        }
        $('#cjCuadre').html(html);
    }

    function diferencia() {
        var v = parseFloat($('#cjContado').val()), esperado = +$('#cjCierreEsperado').data('valor') || 0;
        if (isNaN(v)) { $('#cjDiferencia').html(''); return; }
        var d = Math.round((v - esperado) * 100) / 100;
        $('#cjDiferencia').html(d === 0 ? '<span class="text-success"><i class="bx bx-check-circle"></i> El efectivo cuadra.</span>'
            : d > 0 ? '<span class="text-primary"><i class="bx bx-plus-circle"></i> Sobrante de ' + dinero(d) + '</span>'
                : '<span class="text-danger"><i class="bx bx-minus-circle"></i> Faltante de ' + dinero(-d) + '</span>');
    }

    function cerrar() {
        var v = parseFloat($('#cjContado').val());
        if (isNaN(v) || v < 0) { $('#cjContado').addClass('is-invalid').trigger('focus'); return; }
        var esperado = +$('#cjCierreEsperado').data('valor') || 0, obs = $.trim($('#cjObservaciones').val());
        if (Math.abs(v - esperado) >= 0.01 && !obs) { $('#cjObservaciones').addClass('is-invalid').trigger('focus'); showNotification(1, 'warning', 'Explique la diferencia en observaciones.'); return; }
        // Los pendientes de facturar solo se avisan en el modal: no bloquean el cierre
        enviarCierre(v, obs);
    }

    function enviarCierre(v, obs) {
        var $b = $('#cjCerrarConfirmar').prop('disabled', true);
        api('Cerrar', { id: state.estado.Caja.Id, efectivoContado: Math.round(v * 100) / 100, observaciones: obs }).done(function (r) {
            if (!r.Ok) { error(r); return; }
            bootstrap.Modal.getInstance(document.getElementById('cjModalCierre')).hide();
            showNotification(1, 'success', r.Mensaje);
            cargarEstado();
        }).fail(falla).always(function () { $b.prop('disabled', false); });
    }

    function reabrir() {
        swal({ title: 'Reabrir caja', text: '¿Reabrir su caja de hoy? Se borrará el arqueo registrado.', type: 'warning', showCancelButton: true, confirmButtonText: 'Reabrir', cancelButtonText: 'Cancelar', closeOnConfirm: true },
            function (ok) {
                if (!ok) return;
                api('Reabrir', { id: state.estado.Caja.Id }).done(function (r) {
                    if (!r.Ok) { error(r); return; }
                    showNotification(1, 'success', r.Mensaje);
                    cargarEstado();
                }).fail(falla);
            });
    }

    /* ---------- eventos ---------- */
    $('#caja')
        .on('submit', '#cjFormApertura', function (ev) { ev.preventDefault(); abrir(); })
        .on('input', '#cjFondo', function () { $(this).removeClass('is-invalid'); avisoFondo(); });
    $(document).off('.caja')
        .on('click.caja', '#cjCerrar', abrirCierre)
        .on('click.caja', '#cjReabrir', reabrir)
        .on('click.caja', '.cj-sacar, .cj-entrada', abrirSalida);
    $('#cjFormSalida').on('change', 'input[name="cjMovTipo"]', function () { tipoMovimiento(this.value); });
    $('#cjFormSalida').on('submit', function (ev) { ev.preventDefault(); registrarSalida(); });
    $('#cjFormSalida').on('input change', 'input, select, textarea', function () { $(this).removeClass('is-invalid'); });
    $('#cjSalMotivo').on('input', function () { $('#cjSalMotivoCont').text($(this).val().length); });
    $('#cjSalidas').on('click', '.cj-anular-salida', function () { anularSalida(+$(this).closest('tr').data('id')); });
    $('#cjFormCierre').on('submit', function (ev) { ev.preventDefault(); cerrar(); });
    $('#cjContado').on('input', function () { $(this).removeClass('is-invalid'); diferencia(); });
    $('#cjObservaciones').on('input', function () { $(this).removeClass('is-invalid'); });
    $('#cjRangos').on('click', '[data-rango]', function () { state.rango = String($(this).data('rango')); guardar(state.rango); state.pagina = 1; cargarPendientes().done(pintarResumenPend); });
    $('#cjBuscar').on('input', function () {
        clearTimeout(state.timer);
        var v = $.trim($(this).val());
        state.timer = setTimeout(function () { state.texto = v; state.pagina = 1; cargarPendientes(); }, 350);
    });
    $('#cjPaginas').on('click', '[data-pagina]', function () {
        var n = +$(this).data('pagina');
        if (n >= 1 && !$(this).parent().hasClass('disabled')) { state.pagina = n; pintarPendientes(); }
    });
    $('#cjPendientes').on('click', '.cj-cobrar', function () { AjaxLink('Facturacion/frm_OpenFactura.aspx?id=' + $(this).closest('tr').data('factura')); });
    $('#cjEmitidos').on('click', '.cj-ver', function () { AjaxLink('Facturacion/frm_OpenFactura.aspx?id=' + $(this).data('factura')); })
        .on('click', '.cj-ticket', function () { if (window.TicketVenta) window.TicketVenta.imprimir(+$(this).data('factura')); });

    function pintarResumenPend() { if (state.estado && state.estado.Caja) pintarEstado(); }

    /* ---------- citas por adelantado ----------
       Se cobra el total de la cita con su factura (DTE). Al atenderla, solo queda por cobrar lo que se agregue.
       Si la cita se cancela, lo pagado queda a favor del paciente y se aplica a su próxima cita o procedimiento. */
    var citas = { lista: [], saldos: [], texto: '', timer: null, pagos: [], verPagos: false };

    // No se listan citas hasta que se busca al paciente (mínimo 2 caracteres)
    var CITAS_MIN = 2;
    function sinAcentos(s) { return String(s || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, ''); }

    /* ---------- pagos adelantados sin cita (pendientes de agendar) ---------- */
    function cargarPagos() {
        return api('PagosAdelantados', { texto: '' }).done(function (r) {
            citas.pagos = r && r.Ok ? r.Items || [] : [];
            pintarPagos();
        });
    }

    function pintarPagos() {
        var pend = $.grep(citas.pagos, function (p) { return !p.IdCita; });
        var total = pend.reduce(function (a, p) { return a + p.Disponible; }, 0);
        $('#cjPagosResumen').toggleClass('d-none', !pend.length).html(pend.length
            ? '<i class="bx bx-wallet text-primary"></i> <span><strong>' + pend.length + '</strong> ' + (pend.length === 1 ? 'pago adelantado pendiente' : 'pagos adelantados pendientes')
              + ' de agendar · <strong>' + dinero(total) + '</strong></span>'
              + ' <button type="button" class="btn btn-link btn-sm p-0" id="cjVerPagos">' + (citas.verPagos ? 'Ocultar' : 'Ver lista') + '</button>'
            : '');
        // la lista: completa con "Ver lista", o solo la de los pacientes buscados
        var t = sinAcentos(citas.texto), buscando = citas.texto.length >= CITAS_MIN;
        var lista = citas.verPagos ? citas.pagos : buscando ? $.grep(citas.pagos, function (p) {
            return sinAcentos(p.Paciente).indexOf(t) >= 0 || String(p.Documento).indexOf(citas.texto) >= 0 || String(p.Celular).indexOf(citas.texto) >= 0;
        }) : [];
        $('#cjPagos').toggleClass('d-none', !lista.length).html(lista.length
            ? '<i class="bx bx-wallet"></i> <strong>Pagos adelantados sin cita</strong> (al atender la cita se descuentan y solo se cobra la diferencia):'
              + '<ul class="mb-0 mt-1 ps-3">' + lista.map(function (p) {
                  return '<li>' + esc(titulo(p.Paciente)) + ' · <strong>' + dinero(p.Disponible) + '</strong>'
                      + (p.Usado > 0 ? ' <span class="text-muted">(pagó ' + dinero(p.Pagado) + ', usado ' + dinero(p.Usado) + ')</span>' : '')
                      + ' <span class="text-muted">· pagado el ' + esc(p.FechaPago) + ' · N.º ' + p.IdFactura + '</span> · '
                      + (p.IdCita ? '<span class="text-success">se usará en la cita del ' + esc(p.Cita) + '</span>' : '<span class="text-warning-emphasis fw-medium">pendiente de agendar</span>')
                      + ' <a href="javascript:;" class="cj-ver-anticipo" data-factura="' + p.IdFactura + '" title="Ver factura"><i class="bx bx-show"></i></a></li>';
              }).join('') + '</ul>'
            : '');
    }

    function cargarCitas() {
        if (citas.texto.length < CITAS_MIN) {
            citas.lista = []; citas.saldos = [];
            pintarCitas();
            pintarPagos();
            return $.Deferred().resolve().promise();
        }
        $('#cjCitas').html('<tr><td colspan="6" class="text-center py-4"><div class="spinner-border spinner-border-sm text-primary"></div> Buscando…</td></tr>');
        return $.when(api('CitasPorCobrar', { texto: citas.texto }), api('SaldosFavor'), cargarPagos()).done(function (r, s) {
            if (!r.Ok) { error(r); return; }
            citas.lista = r.Items || [];
            // saldos a favor solo de los pacientes buscados
            var t = sinAcentos(citas.texto), ids = $.map(citas.lista, function (c) { return sinAcentos(c.Paciente); });
            citas.saldos = $.grep(s && s.Ok ? s.Items || [] : [], function (x) {
                var p = sinAcentos(x.Paciente); return p.indexOf(t) >= 0 || ids.indexOf(p) >= 0;
            });
            pintarCitas();
        }).fail(falla);
    }

    function pintarCitas() {
        var lista = citas.lista, cobrar = puedeCobrar(), porCobrar = $.grep(lista, function (c) { return !c.Pagada; });
        var buscando = citas.texto.length >= CITAS_MIN;
        $('#cjCitasCont').text(porCobrar.length).toggleClass('d-none', !buscando);
        if (!buscando) {
            $('#cjSaldos').addClass('d-none').empty();
            $('#cjCitas').html('<tr><td colspan="6" class="text-center text-muted py-5"><i class="bx bx-search fs-3 d-block mb-1"></i>'
                + 'Busque al paciente por nombre, documento o celular para ver sus citas y cobrarlas por adelantado.</td></tr>');
            return;
        }

        var saldos = citas.saldos, totalSaldos = saldos.reduce(function (a, x) { return a + x.Total; }, 0);
        $('#cjSaldos').toggleClass('d-none', !saldos.length).html(saldos.length
            ? '<i class="bx bx-wallet"></i> <strong>Saldos a favor:</strong> ' + saldos.length + (saldos.length === 1 ? ' pago' : ' pagos') + ' · ' + dinero(totalSaldos)
              + ' de citas canceladas. Se aplican solos al finalizar su próximo procedimiento, o use <strong>Aplicar saldo</strong> en su nueva cita.'
              + '<ul class="mb-0 mt-1 ps-3">' + saldos.map(function (x) {
                  return '<li>' + esc(titulo(x.Paciente)) + ' · ' + dinero(x.Total) + ' <span class="text-muted">· cita del ' + fecha(String(x.Cita).substr(0, 10)) + ' ' + esc(String(x.Cita).substr(11))
                      + ' (' + esc(x.EstadoCita) + ') · N.º ' + x.IdFactura + '</span></li>';
              }).join('') + '</ul>'
            : '');

        $('#cjCitas').html(lista.length ? lista.map(function (c) {
            var accion;
            if (c.Pagada) accion = '<span class="ad-chip ad-chip-ok"><i class="bx bx-check"></i> Pagada</span> '
                + '<button type="button" class="btn btn-sm btn-outline-primary cj-ver-anticipo" data-factura="' + c.IdFactura + '" title="Ver factura"><i class="bx bx-show"></i></button>';
            else if (c.PagoAdelantado > 0) accion = '<span class="ad-chip ad-chip-ok" title="Al atenderla se descuenta y solo se cobra la diferencia"><i class="bx bx-wallet"></i> Usará pago adelantado ' + dinero(c.PagoAdelantado) + '</span> '
                + '<button type="button" class="btn btn-sm btn-outline-secondary cj-quitar-pago" title="La cita ya no usará el pago adelantado"><i class="bx bx-x"></i></button>';
            else if (c.PagosPendientes > 0) accion = '<button type="button" class="btn btn-sm btn-success cj-usar-pago me-1" title="Descontar el pago adelantado del paciente al atender esta cita">'
                + '<i class="bx bx-wallet"></i> Usar pago adelantado ' + dinero(c.PagosPendientes) + '</button>'
                + (c.Total > 0 ? '<button type="button" class="btn btn-sm btn-outline-primary cj-cobrar-cita"' + (cobrar ? '' : ' disabled title="Abra su caja para cobrar"') + '><i class="bx bx-receipt"></i> Cobrar</button>' : '');
            else if (!(c.Total > 0)) accion = '<span class="small text-muted">Sin tratamientos</span>';
            else accion = (c.SaldoFavor > 0 ? '<button type="button" class="btn btn-sm btn-outline-success cj-aplicar-saldo me-1" title="Usar el saldo a favor del paciente">'
                    + '<i class="bx bx-wallet"></i> Aplicar saldo ' + dinero(c.SaldoFavor) + '</button>' : '')
                + '<button type="button" class="btn btn-sm btn-primary cj-cobrar-cita"' + (cobrar ? '' : ' disabled title="Abra su caja para cobrar"') + '><i class="bx bx-receipt"></i> Cobrar</button>';
            return '<tr data-cita="' + c.IdCita + '">'
                + '<td class="text-nowrap">' + fecha(c.Fecha) + '<div class="ad-ayuda">' + esc(c.Hora) + '</div><div class="ad-ayuda">' + esc(c.Estado) + '</div></td>'
                + '<td><div class="fw-medium">' + esc(titulo(c.Paciente)) + '</div><div class="ad-ayuda">' + esc(c.Documento) + (c.Celular ? ' · ' + esc(c.Celular) : '') + '</div></td>'
                + '<td class="d-none d-lg-table-cell small"><span class="cj-servicios" title="' + esc(c.Servicios) + '">' + esc(c.Servicios || '—') + '</span></td>'
                + '<td class="d-none d-md-table-cell small">' + esc(c.Especialista) + '</td>'
                + '<td class="text-end fw-medium">' + dinero(c.Total) + '</td>'
                + '<td class="text-end text-nowrap">' + accion + '</td></tr>';
        }).join('') : '<tr><td colspan="6" class="text-center text-muted py-5">No se encontraron citas activas en los próximos 30 días para "' + esc(citas.texto) + '".</td></tr>');
    }

    function cobrarCita($b) {
        var c = $.grep(citas.lista, function (x) { return x.IdCita === +$b.closest('tr').data('cita'); })[0];
        if (!c) return;
        swal({
            title: 'Cobrar cita por adelantado', html: true, type: 'info', showCancelButton: true, confirmButtonText: 'Ir a cobrar', cancelButtonText: 'Cancelar', closeOnConfirm: true,
            text: '<b>' + esc(titulo(c.Paciente)) + '</b><br>Cita del ' + fecha(c.Fecha) + ' ' + esc(c.Hora) + ' con ' + esc(c.Especialista)
                + '<br>' + esc(c.Servicios) + '<br>Total: <b>' + dinero(c.Total) + '</b>'
                + '<div class="small text-muted mt-2">Se emite la factura ahora. Al atender la cita solo se cobrará lo que se agregue. Si se cancela, queda a favor del paciente.</div>'
        }, function (ok) {
            if (!ok) return;
            $b.prop('disabled', true);
            api('CobrarCita', { cita: c.IdCita }).done(function (r) {
                if (!r.Ok) { error(r); return; }
                AjaxLink('Facturacion/frm_OpenFactura.aspx?id=' + r.IdFactura);
            }).fail(falla).always(function () { $b.prop('disabled', false); });
        });
    }

    function aplicarSaldo($b) {
        var c = $.grep(citas.lista, function (x) { return x.IdCita === +$b.closest('tr').data('cita'); })[0];
        if (!c) return;
        swal({
            title: 'Aplicar saldo a favor', type: 'warning', showCancelButton: true, confirmButtonText: 'Aplicar', cancelButtonText: 'Cancelar', closeOnConfirm: true,
            text: titulo(c.Paciente) + ' tiene ' + dinero(c.SaldoFavor) + ' a favor. Se usará para la cita del ' + fecha(c.Fecha) + ' ' + c.Hora
                + ' (' + dinero(c.Total) + '). Si al atenderla hay tratamientos que no cubre, se cobrarán aparte.'
        }, function (ok) {
            if (!ok) return;
            api('AplicarSaldo', { cita: c.IdCita }).done(function (r) {
                if (!r.Ok) { error(r); return; }
                showNotification(1, 'success', r.Mensaje);
                cargarCitas();
            }).fail(falla);
        });
    }

    // La cita usará el pago adelantado sin cita del paciente (o deja de usarlo)
    function usarPago($b, quitar) {
        var c = $.grep(citas.lista, function (x) { return x.IdCita === +$b.closest('tr').data('cita'); })[0];
        if (!c) return;
        swal({
            title: quitar ? 'Quitar pago adelantado' : 'Usar pago adelantado', type: quitar ? 'warning' : 'info', showCancelButton: true,
            confirmButtonText: quitar ? 'Quitar' : 'Usar pago', cancelButtonText: 'Cancelar', closeOnConfirm: true,
            text: quitar
                ? 'La cita del ' + fecha(c.Fecha) + ' ' + c.Hora + ' ya no usará el pago adelantado de ' + titulo(c.Paciente) + '. El pago queda pendiente de agendar.'
                : titulo(c.Paciente) + ' tiene ' + dinero(c.PagosPendientes) + ' pagados por adelantado. Se usarán en la cita del ' + fecha(c.Fecha) + ' ' + c.Hora
                  + ': al atenderla se descuentan y solo se cobra la diferencia; si sobra, queda para su siguiente cita.'
        }, function (ok) {
            if (!ok) return;
            api(quitar ? 'QuitarPagoAdelantado' : 'UsarPagoAdelantado', { cita: c.IdCita }).done(function (r) {
                if (!r.Ok) { error(r); return; }
                showNotification(1, 'success', r.Mensaje);
                cargarCitas();
            }).fail(falla);
        });
    }

    /* ---------- cobrar sin cita ---------- */
    var sinCita = { paciente: null, timer: null, req: 0 };

    function buscarPacienteSinCita(v) {
        var id = ++sinCita.req;
        if (v.length < 2) { $('#cjSinCitaResultados').empty(); return; }
        api('BuscarPacientes', { texto: v }).done(function (r) {
            if (id !== sinCita.req) return;
            if (!r.Ok) { error(r); return; }
            var l = r.Items || [];
            $('#cjSinCitaResultados').html(l.length ? l.map(function (p) {
                return '<button type="button" class="list-group-item list-group-item-action py-1" data-id="' + p.Id + '">'
                    + '<div class="fw-medium">' + esc(titulo(p.Nombre)) + '</div><small class="text-muted">' + esc(p.Documento || 'Sin documento') + (p.Celular ? ' · ' + esc(p.Celular) : '') + '</small></button>';
            }).join('') : '<div class="list-group-item small text-muted">No se encontraron pacientes.</div>');
            $('#cjSinCitaResultados').data('items', l);
        }).fail(falla);
    }

    function elegirPacienteSinCita(p) {
        sinCita.paciente = p;
        $('#cjSinCitaResultados').empty();
        $('#cjSinCitaBuscar').val('').toggleClass('d-none', !!p);
        $('#cjSinCitaPaciente').toggleClass('d-none', !p).html(p
            ? '<div class="d-flex align-items-center gap-2"><i class="bx bx-user fs-5"></i><div class="me-auto"><div class="fw-medium">' + esc(titulo(p.Nombre)) + '</div>'
              + '<small class="text-muted">' + esc(p.Documento || 'Sin documento') + (p.Celular ? ' · ' + esc(p.Celular) : '') + '</small></div>'
              + '<button type="button" class="btn btn-sm btn-outline-secondary" id="cjSinCitaCambiar">Cambiar</button></div>'
            : '');
        if (p) $('#cjSinCitaMonto').trigger('focus');
    }

    function abrirSinCita() {
        if (!puedeCobrar()) { showNotification(1, 'warning', 'Abra su caja para cobrar.'); return; }
        elegirPacienteSinCita(null);
        $('#cjSinCitaMonto, #cjSinCitaDesc').val('');
        bootstrap.Modal.getOrCreateInstance(document.getElementById('cjModalSinCita')).show();
        setTimeout(function () { $('#cjSinCitaBuscar').trigger('focus'); }, 400);
    }

    function cobrarSinCita(ev) {
        ev.preventDefault();
        var p = sinCita.paciente, monto = Math.round(Number($('#cjSinCitaMonto').val()) * 100) / 100;
        if (!p) { showNotification(1, 'warning', 'Seleccione el paciente.'); $('#cjSinCitaBuscar').trigger('focus'); return; }
        if (!(monto > 0)) { showNotification(1, 'warning', 'Escriba el monto del pago.'); $('#cjSinCitaMonto').trigger('focus'); return; }
        var $b = $('#cjSinCitaCobrar').prop('disabled', true);
        api('CobrarSinCita', { expediente: p.Id, monto: monto, descripcion: $.trim($('#cjSinCitaDesc').val()) }).done(function (r) {
            if (!r.Ok) { error(r); return; }
            bootstrap.Modal.getInstance(document.getElementById('cjModalSinCita')).hide();
            setTimeout(function () { AjaxLink('Facturacion/frm_OpenFactura.aspx?id=' + r.IdFactura); }, 300);
        }).fail(falla).always(function () { $b.prop('disabled', false); });
    }

    $('#cjSinCita').on('click', abrirSinCita);
    $('#cjSinCitaBuscar').on('input', function () {
        clearTimeout(sinCita.timer);
        var v = $.trim($(this).val());
        sinCita.timer = setTimeout(function () { buscarPacienteSinCita(v); }, 300);
    });
    $('#cjSinCitaResultados').on('click', '[data-id]', function () {
        var id = +$(this).data('id'), l = $('#cjSinCitaResultados').data('items') || [];
        elegirPacienteSinCita($.grep(l, function (x) { return x.Id === id; })[0] || null);
    });
    $('#cjSinCitaPaciente').on('click', '#cjSinCitaCambiar', function () { elegirPacienteSinCita(null); $('#cjSinCitaBuscar').trigger('focus'); });
    $('#cjSinCitaForm').on('submit', cobrarSinCita);
    $('#cjPagosResumen').on('click', '#cjVerPagos', function () { citas.verPagos = !citas.verPagos; pintarPagos(); });
    $('#cjPagos').on('click', '.cj-ver-anticipo', function () { AjaxLink('Facturacion/frm_OpenFactura.aspx?id=' + $(this).data('factura')); });

    $('#cjCitas').on('click', '.cj-cobrar-cita', function () { cobrarCita($(this)); })
        .on('click', '.cj-aplicar-saldo', function () { aplicarSaldo($(this)); })
        .on('click', '.cj-usar-pago', function () { usarPago($(this), false); })
        .on('click', '.cj-quitar-pago', function () { usarPago($(this), true); })
        .on('click', '.cj-ver-anticipo', function () { AjaxLink('Facturacion/frm_OpenFactura.aspx?id=' + $(this).data('factura')); });
    $('#cjCitasBuscar').on('input', function () {
        clearTimeout(citas.timer);
        var v = $.trim($(this).val());
        citas.timer = setTimeout(function () { citas.texto = v; cargarCitas(); }, 350);
    });
    // al volver a la pestaña con una búsqueda, refresca (pudo cobrarse una cita)
    $('#cjTabCitasBtn').on('shown.bs.tab', function () { if (citas.texto.length >= CITAS_MIN) cargarCitas(); });
    // el botón Cobrar depende de si la caja está abierta
    $('#cjTabCitasBtn').on('shown.bs.tab', pintarCitas);

    if (typeof mtd_ValidateSession === 'function') mtd_ValidateSession();
    $.when(cargarPendientes(), cargarEstado(), cargarCitas(), cargarPagos());
})(jQuery);
