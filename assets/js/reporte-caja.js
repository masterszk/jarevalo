/* Reporte de caja por rango de fechas y cajero – Reportes/frm_repCaja.aspx */
(function ($) {
    'use strict';

    var URL = 'Reportes/frm_repCaja.aspx/';
    var datos = null;

    function api(metodo, d) {
        return $.ajax({
            type: 'POST',
            url: URL + metodo,
            data: JSON.stringify(d || {}),
            contentType: 'application/json; charset=utf-8',
            dataType: 'json'
        }).then(function (r) { return r.d; });
    }
    function falla(xhr) { showNotification(1, 'error', 'Error de conexión (HTTP ' + xhr.status + ').'); }
    function esc(s) { return $('<div/>').text(s == null ? '' : String(s)).html(); }
    function dinero(n) { return '$ ' + Number(n || 0).toLocaleString('es-SV', { minimumFractionDigits: 2, maximumFractionDigits: 2 }); }
    function dos(n) { return (n < 10 ? '0' : '') + n; }
    function iso(d) { return d.getFullYear() + '-' + dos(d.getMonth() + 1) + '-' + dos(d.getDate()); }
    function texto(isoFecha) { var p = isoFecha.split('-'); return p[2] + '/' + p[1] + '/' + p[0]; }

    function rango(tipo) {
        var hoy = new Date(), d = new Date(hoy), h = new Date(hoy);
        if (tipo === 'ayer') { d.setDate(hoy.getDate() - 1); h = new Date(d); }
        else if (tipo === 'semana') { var dia = (hoy.getDay() + 6) % 7; d.setDate(hoy.getDate() - dia); }      // lunes
        else if (tipo === 'mes') d = new Date(hoy.getFullYear(), hoy.getMonth(), 1);
        else if (tipo === 'anterior') { d = new Date(hoy.getFullYear(), hoy.getMonth() - 1, 1); h = new Date(hoy.getFullYear(), hoy.getMonth(), 0); }
        $('#cjDesde').val(iso(d));
        $('#cjHasta').val(iso(h));
    }

    /* ---------- consulta ---------- */
    function consultar() {
        var desde = $('#cjDesde').val(), hasta = $('#cjHasta').val();
        if (!desde || !hasta) { showNotification(1, 'warning', 'Seleccione la fecha inicial y final.'); return; }
        if (hasta < desde) { showNotification(1, 'warning', 'La fecha final no puede ser anterior a la inicial.'); return; }

        var $b = $('#cjConsultar').prop('disabled', true);
        api('Consultar', { desde: desde, hasta: hasta, cajero: $('#cjCajero').val(), sucursal: parseInt($('#cjSucursal').val(), 10) || 0 }).done(function (r) {
            if (!r.Ok) { showNotification(1, 'warning', r.Mensaje); return; }
            datos = r;
            render();
        }).fail(falla).always(function () { $b.prop('disabled', false); });
    }

    function grupo($ul, lista) {
        $ul.empty();
        if (!lista.length) { $ul.html('<li class="list-group-item text-muted">Sin cobros</li>'); return; }
        $.each(lista, function (_, g) {
            $ul.append('<li class="list-group-item px-0"><span>' + esc(g.Nombre) + ' <span class="text-muted">(' + g.Documentos + ')</span></span><strong>' + dinero(g.Total) + '</strong></li>');
        });
    }

    function render() {
        var r = datos, cajero = $('#cjCajero option:selected').text();
        $('#cjVacio').addClass('d-none');
        $('#cjResultado').removeClass('d-none');
        $('#cjTitulo').text((r.Desde === r.Hasta ? texto(r.Desde) : texto(r.Desde) + ' al ' + texto(r.Hasta)) + ' · ' + (r.Cajero ? cajero : 'Todos los cajeros'));

        $('#cjTotal').text(dinero(r.Total));
        $('#cjTotalSub').text('Gravado ' + dinero(r.Gravado) + ' · IVA ' + dinero(r.Iva));
        $('#cjDocs').text(r.Documentos);
        $('#cjDocsSub').text(r.Documentos === 1 ? 'documento emitido' : 'documentos emitidos');
        $('#cjTicket').text(dinero(r.TicketPromedio));
        $('#cjAnulados').text(r.Anulados);
        $('#cjAnuladosSub').text(r.Anulados ? dinero(r.TotalAnulado) + ' anulado' : 'Sin anulaciones');
        $('#cjPendiente').text(dinero(r.PendientesTotal));
        $('#cjPendienteSub').text(r.PendientesFacturas + ' factura(s) sin cobrar del periodo');

        // Manejo de efectivo: neto de entradas y salidas
        var activos = $.grep(r.SalidasDetalle, function (s) { return !s.Anulada; });
        var nEnt = $.grep(activos, function (s) { return s.Entrada; }).length;
        $('#cjSalidas').html('<span class="text-success">+' + dinero(r.Entradas) + '</span> / <span class="text-danger">−' + dinero(r.Salidas) + '</span>');
        $('#cjSalidasSub').text(nEnt + ' entrada(s) · ' + (activos.length - nEnt) + ' salida(s) · ' + r.Cajas.length + ' caja(s)');
        var neto = r.Sobrantes - r.Faltantes;
        $('#cjArqueo').text(dinero(neto)).toggleClass('text-danger', neto < 0).toggleClass('text-success', neto > 0);
        $('#cjArqueoSub').text('Sobrantes ' + dinero(r.Sobrantes) + ' · Faltantes ' + dinero(r.Faltantes) + (r.CajasAbiertas ? ' · ' + r.CajasAbiertas + ' abierta(s)' : ''));
        $('#cjDescuentos').text(dinero(r.Descuentos));
        $('#cjDescuentosSub').text(r.Descuentos > 0
            ? 'Tratamientos ' + dinero(r.DescuentosTratamientos) + ' · Cupones ' + dinero(r.DescuentosCupones) + ' (' + r.Cupones + ')'
            : 'Sin descuentos');
        $('#cjTickets').text(r.Tickets);

        grupo($('#cjPorForma'), r.PorFormaPago);
        var docsForma = 0, totalForma = 0;
        $.each(r.PorFormaPago, function (_, g) { docsForma += g.Documentos; totalForma += g.Total; });
        $('#cjPorFormaTotal').toggleClass('d-none', !r.PorFormaPago.length)
            .html('<span>Total <span class="text-muted fw-normal">(' + docsForma + ')</span></span><span>' + dinero(totalForma) + '</span>');
        grupo($('#cjPorCajero'), r.PorCajero);
        grupo($('#cjPorTipo'), r.PorTipo);
        grupo($('#cjPorDia'), r.PorDia);
        renderCajas();
        renderSalidas();
        renderAnulaciones();
        renderFilas();
    }

    function renderCajas() {
        var $t = $('#cjCajas').empty();
        if (!datos.Cajas.length) { $t.html('<tr><td colspan="11" class="text-center text-muted py-3">No se abrió caja en el periodo.</td></tr>'); return; }
        $.each(datos.Cajas, function (_, c) {
            var dif = c.Sobrante - c.Faltante;
            $t.append('<tr>' +
                '<td>' + esc(c.Fecha) + '</td>' +
                '<td>' + esc(c.CajeroNombre) + '<div class="small text-muted">' + c.Documentos + ' doc.' + (c.Tickets ? ' · ' + c.Tickets + ' ticket(s)' : '') + '</div></td>' +
                '<td>' + esc(c.Apertura) + ' – ' + (c.Abierta ? '<span class="badge bg-warning text-dark">Abierta</span>' : esc(c.Cierre)) + '</td>' +
                '<td class="text-end">' + dinero(c.Fondo) + '</td>' +
                '<td class="text-end">' + dinero(c.Cobrado) +
                    (c.DescuentoTratamientos > 0 ? '<div class="small text-success">Trat. -' + dinero(c.DescuentoTratamientos) + '</div>' : '') +
                    (c.DescuentoCupones > 0 ? '<div class="small text-success">Cupones -' + dinero(c.DescuentoCupones) + '</div>' : '') + '</td>' +
                '<td class="text-end">' + dinero(c.Efectivo) + '</td>' +
                '<td class="text-end">' + (c.Entradas ? '<div class="text-success">+' + dinero(c.Entradas) + '</div>' : '')
                    + (c.Salidas ? '<div class="text-danger">-' + dinero(c.Salidas) + '</div>' : (c.Entradas ? '' : dinero(0))) + '</td>' +
                '<td class="text-end fw-semibold">' + dinero(c.EfectivoEsperado) + '</td>' +
                '<td class="text-end">' + (c.EfectivoContado == null ? '—' : dinero(c.EfectivoContado)) + '</td>' +
                '<td class="text-end ' + (dif < 0 ? 'text-danger' : dif > 0 ? 'text-success' : '') + '">' + (c.Abierta ? '—' : (dif > 0 ? '+' : '') + dinero(dif)) + '</td>' +
                '<td class="cj-texto small">' + esc(c.Observaciones) + '</td>' +
                '</tr>');
        });
    }

    function renderSalidas() {
        var $t = $('#cjSalidasFilas').empty(), lista = datos.SalidasDetalle;
        $('#cjPorCategoria').text($.map(datos.PorCategoriaSalida, function (g) { return g.Nombre + ' ' + dinero(g.Total); }).join(' · '));
        if (!lista.length) { $t.html('<tr><td colspan="5" class="text-center text-muted py-3">Sin entradas ni salidas de efectivo.</td></tr>'); return; }
        $.each(lista, function (_, s) {
            $t.append('<tr' + (s.Anulada ? ' class="cj-anulado"' : '') + '>' +
                '<td>' + esc(s.Fecha) + '</td>' +
                '<td>' + esc(s.CajeroNombre) + '</td>' +
                '<td><span class="' + (s.Entrada ? 'text-success' : 'text-danger') + ' small fw-semibold">' + (s.Entrada ? 'Entrada' : 'Salida') + '</span> · ' + esc(s.Categoria)
                    + (s.Referencia ? '<div class="small text-muted">Ref. ' + esc(s.Referencia) + '</div>' : '') + '</td>' +
                '<td class="cj-texto">' + esc(s.Motivo) + (s.Anulada ? '<div class="small text-danger" style="text-decoration:none">Anulada: ' + esc(s.MotivoAnulacion) + '</div>' : '') + '</td>' +
                '<td class="text-end ' + (s.Entrada ? 'text-success' : 'text-danger') + '">' + (s.Entrada ? '+' : '-') + dinero(s.Monto) + '</td>' +
                '</tr>');
        });
    }

    function renderAnulaciones() {
        var $t = $('#cjAnulaciones').empty(), lista = $.grep(datos.Cobros, function (c) { return c.Anulado; });
        if (!lista.length) { $t.html('<tr><td colspan="4" class="text-center text-muted py-3">Sin anulaciones en el periodo.</td></tr>'); return; }
        $.each(lista, function (_, c) {
            $t.append('<tr>' +
                '<td>' + esc(c.TipoDte) + '<div class="small text-muted">' + esc(c.NumeroControl) + '</div></td>' +
                '<td>' + esc(c.FechaAnulacion || '—') + (c.UsuarioAnula ? '<div class="small text-muted">' + esc(c.UsuarioAnula) + '</div>' : '') + '</td>' +
                '<td class="cj-texto small">' + esc(c.MotivoAnulacion) + '</td>' +
                '<td class="text-end">' + dinero(c.Total) + '</td>' +
                '</tr>');
        });
    }

    function renderFilas() {
        var r = datos, verAnulados = $('#cjVerAnulados').is(':checked'), $t = $('#cjFilas').empty();
        var filas = $.grep(r.Cobros, function (c) { return verAnulados || !c.Anulado; });
        if (!filas.length) { $t.html('<tr><td colspan="9" class="text-center text-muted py-4">No hay cobros en el periodo.</td></tr>'); }

        $.each(filas, function (_, c) {
            $t.append(
                '<tr' + (c.Anulado ? ' class="cj-anulado"' : c.Ticket ? ' class="cj-ticket"' : '') + '>' +
                '  <td>' + esc(c.Fecha) + '<div class="small text-muted">' + esc(c.Hora) + '</div></td>' +
                '  <td>' + esc(c.TipoDte) + '<div class="small text-muted">' + esc(c.NumeroControl) + '</div></td>' +
                '  <td>' + esc(c.Cliente) + (c.Paciente && c.Paciente !== c.Cliente ? '<div class="small text-muted">Paciente: ' + esc(c.Paciente) + '</div>' : '') +
                (c.DescuentoTratamiento > 0 ? '<div class="small text-success">Desc. tratamiento: -' + dinero(c.DescuentoTratamiento) + '</div>' : '') +
                (c.DescuentoCupon > 0 ? '<div class="small text-success">Cupón ' + esc(c.Cupon) + ': -' + dinero(c.DescuentoCupon) + '</div>' : '') + '</td>' +
                '  <td>' + esc(c.FormaPago) + (c.Referencia ? '<div class="small text-muted">Ref. ' + esc(c.Referencia) + '</div>' : '') + '</td>' +
                '  <td>' + esc(c.CajeroNombre) + '</td>' +
                '  <td class="text-end">' + dinero(c.Gravado) + '</td>' +
                '  <td class="text-end">' + dinero(c.Iva) + '</td>' +
                '  <td class="text-end fw-semibold">' + dinero(c.Total) + '</td>' +
                '  <td>' + (c.Anulado ? '<span class="badge bg-danger">Anulado</span>' : c.Ticket ? '<span class="badge bg-secondary">Sin costo</span>' : '') + '</td>' +
                '</tr>');
        });
        $('#cjPieGravado').text(dinero(r.Gravado));
        $('#cjPieIva').text(dinero(r.Iva));
        $('#cjPieTotal').text(dinero(r.Total));
    }

    /* ---------- exportar a Excel (.xlsx) ---------- */
    // Cada cuadro arma su hoja con los mismos datos de la pantalla (assets/js/excel-reportes.js)
    var X = window.ExcelReporte;
    function suma(lista, f) { var t = 0; $.each(lista || [], function (_, x) { t += Number(f(x)) || 0; }); return t; }

    function tituloExcel(cuadro) { return 'Reporte de caja · ' + cuadro + ' · ' + $('#cjTitulo').text(); }

    var hojas = {
        resumen: function () {
            var r = datos;
            var filas = [
                ['Total cobrado', r.Total], ['Gravado', r.Gravado], ['IVA', r.Iva], ['Documentos', r.Documentos], ['Ticket promedio', r.TicketPromedio],
                ['Anulados', r.Anulados], ['Total anulado', r.TotalAnulado], ['Pendiente de cobro', r.PendientesTotal], ['Facturas pendientes', r.PendientesFacturas],
                ['Entradas de efectivo', r.Entradas], ['Salidas de efectivo', r.Salidas], ['Sobrantes', r.Sobrantes], ['Faltantes', r.Faltantes],
                ['Descuentos por tratamiento', r.DescuentosTratamientos], ['Descuentos por cupón', r.DescuentosCupones], ['Descuentos (total)', r.Descuentos],
                ['Tickets sin costo', r.Tickets]
            ];
            var cantidades = { 'Documentos': 1, 'Anulados': 1, 'Facturas pendientes': 1, 'Tickets sin costo': 1 };
            return X.hoja('Resumen', tituloExcel('Resumen'), [
                { t: 'Concepto', w: 32, v: function (f) { return f[0]; } },
                { t: 'Monto', f: '$', w: 16, v: function (f) { return cantidades[f[0]] ? null : f[1]; } },
                { t: 'Cantidad', w: 12, v: function (f) { return cantidades[f[0]] ? f[1] : null; } }
            ], filas);
        },
        forma: function () { return X.hojaGrupo('Por forma de pago', tituloExcel('Por forma de pago'), 'Forma de pago', datos.PorFormaPago); },
        cajero: function () { return X.hojaGrupo('Por cajero', tituloExcel('Por cajero'), 'Cajero', datos.PorCajero); },
        tipo: function () { return X.hojaGrupo('Por tipo de documento', tituloExcel('Por tipo de documento'), 'Tipo de documento', datos.PorTipo); },
        dia: function () {
            var g = datos.PorDia;
            return X.hoja('Por día', tituloExcel('Por día'), [
                { t: 'Día', f: 'd', w: 13, v: function (x) { return X.iso(x.Nombre); } },
                { t: 'Documentos', w: 13, v: function (x) { return x.Documentos; } },
                { t: 'Total', f: '$', w: 15, v: function (x) { return x.Total; } }
            ], g, g.length ? [['Total', suma(g, function (x) { return x.Documentos; }), suma(g, function (x) { return x.Total; })]] : []);
        },
        cajas: function () {
            var c = datos.Cajas;
            function t(f) { return suma(c, f); }
            return X.hoja('Aperturas y cierres', tituloExcel('Aperturas y cierres de caja'), [
                { t: 'Fecha', f: 'd', w: 12, v: function (x) { return X.iso(x.Fecha); } },
                { t: 'Cajero', w: 24, v: function (x) { return x.CajeroNombre; } },
                { t: 'Apertura', w: 11, v: function (x) { return x.Apertura; } },
                { t: 'Cierre', w: 16, v: function (x) { return x.Abierta ? 'Abierta' : x.Cierre; } },
                { t: 'Documentos', w: 12, v: function (x) { return x.Documentos; } },
                { t: 'Tickets', w: 9, v: function (x) { return x.Tickets; } },
                { t: 'Fondo', f: '$', w: 12, v: function (x) { return x.Fondo; } },
                { t: 'Cobrado', f: '$', w: 13, v: function (x) { return x.Cobrado; } },
                { t: 'Desc. tratamientos', f: '$', w: 13, v: function (x) { return x.DescuentoTratamientos; } },
                { t: 'Desc. cupones', f: '$', w: 13, v: function (x) { return x.DescuentoCupones; } },
                { t: 'Efectivo', f: '$', w: 13, v: function (x) { return x.Efectivo; } },
                { t: 'Entradas', f: '$', w: 12, v: function (x) { return x.Entradas; } },
                { t: 'Salidas', f: '$', w: 12, v: function (x) { return x.Salidas; } },
                { t: 'Esperado', f: '$', w: 13, v: function (x) { return x.EfectivoEsperado; } },
                { t: 'Contado', f: '$', w: 13, v: function (x) { return x.EfectivoContado; } },
                { t: 'Sobrante', f: '$', w: 12, v: function (x) { return x.Sobrante; } },
                { t: 'Faltante', f: '$', w: 12, v: function (x) { return x.Faltante; } },
                { t: 'Observaciones', w: 40, v: function (x) { return x.Observaciones; } }
            ], c, c.length ? [['Total', '', '', '', t(function (x) { return x.Documentos; }), t(function (x) { return x.Tickets; }),
                t(function (x) { return x.Fondo; }), t(function (x) { return x.Cobrado; }), t(function (x) { return x.DescuentoTratamientos; }),
                t(function (x) { return x.DescuentoCupones; }), t(function (x) { return x.Efectivo; }), t(function (x) { return x.Entradas; }),
                t(function (x) { return x.Salidas; }), t(function (x) { return x.EfectivoEsperado; }), t(function (x) { return x.EfectivoContado || 0; }),
                t(function (x) { return x.Sobrante; }), t(function (x) { return x.Faltante; }), '']] : []);
        },
        efectivo: function () {
            var s = datos.SalidasDetalle, activos = $.grep(s, function (x) { return !x.Anulada; });
            return X.hoja('Manejo de efectivo', tituloExcel('Manejo de efectivo'), [
                { t: 'Fecha', f: 'f', w: 17, v: function (x) { return X.iso(x.Fecha); } },
                { t: 'Cajero', w: 24, v: function (x) { return x.CajeroNombre; } },
                { t: 'Movimiento', w: 11, v: function (x) { return x.Entrada ? 'Entrada' : 'Salida'; } },
                { t: 'Tipo', w: 20, v: function (x) { return x.Categoria; } },
                { t: 'Motivo', w: 40, v: function (x) { return x.Motivo; } },
                { t: 'Referencia', w: 16, v: function (x) { return x.Referencia; } },
                { t: 'Monto', f: '$', w: 13, v: function (x) { return x.Entrada ? x.Monto : -x.Monto; } },
                { t: 'Estado', w: 10, v: function (x) { return x.Anulada ? 'Anulada' : 'Activa'; } },
                { t: 'Motivo de anulación', w: 30, v: function (x) { return x.MotivoAnulacion; } }
            ], s, s.length ? [
                ['Entradas (activas)', '', '', '', '', '', suma(activos, function (x) { return x.Entrada ? x.Monto : 0; }), '', ''],
                ['Salidas (activas)', '', '', '', '', '', -suma(activos, function (x) { return x.Entrada ? 0 : x.Monto; }), '', ''],
                ['Neto', '', '', '', '', '', suma(activos, function (x) { return x.Entrada ? x.Monto : -x.Monto; }), '', '']
            ] : []);
        },
        anulaciones: function () {
            var a = $.grep(datos.Cobros, function (c) { return c.Anulado; });
            return X.hoja('Anulaciones', tituloExcel('Anulaciones de DTE'), [
                { t: 'Tipo', w: 15, v: function (c) { return c.TipoDte; } },
                { t: 'Número de control', w: 34, v: function (c) { return c.NumeroControl; } },
                { t: 'Emitido', f: 'd', w: 12, v: function (c) { return X.iso(c.Fecha); } },
                { t: 'Anulado', f: 'f', w: 17, v: function (c) { return X.iso(c.FechaAnulacion); } },
                { t: 'Anuló', w: 14, v: function (c) { return c.UsuarioAnula; } },
                { t: 'Motivo', w: 40, v: function (c) { return c.MotivoAnulacion; } },
                { t: 'Total', f: '$', w: 13, v: function (c) { return c.Total; } }
            ], a, a.length ? [['Total', '', '', '', '', '', suma(a, function (c) { return c.Total; })]] : []);
        },
        // todos: incluye los anulados (columna Estado); el botón del cuadro respeta "Mostrar anulados"
        detalle: function (todos) {
            var filas = todos || $('#cjVerAnulados').is(':checked') ? datos.Cobros : $.grep(datos.Cobros, function (c) { return !c.Anulado; });
            var r = datos;
            return X.hoja('Detalle de cobros', tituloExcel('Detalle de cobros'), [
                { t: 'Fecha', f: 'f', w: 17, v: function (c) { return X.iso(c.Fecha, c.Hora); } },
                { t: 'Tipo', w: 15, v: function (c) { return c.TipoDte; } },
                { t: 'Número de control', w: 34, v: function (c) { return c.NumeroControl; } },
                { t: 'Factura', w: 10, v: function (c) { return c.IdFactura; } },
                { t: 'Cliente', w: 30, v: function (c) { return c.Cliente; } },
                { t: 'Paciente', w: 30, v: function (c) { return c.Paciente; } },
                { t: 'Forma de pago', w: 18, v: function (c) { return c.FormaPago; } },
                { t: 'Referencia', w: 14, v: function (c) { return c.Referencia; } },
                { t: 'Cajero', w: 22, v: function (c) { return c.CajeroNombre; } },
                { t: 'Cupón', w: 12, v: function (c) { return c.Cupon; } },
                { t: 'Desc. tratamiento', f: '$', w: 13, v: function (c) { return c.DescuentoTratamiento; } },
                { t: 'Desc. cupón', f: '$', w: 12, v: function (c) { return c.DescuentoCupon; } },
                { t: 'Gravado', f: '$', w: 13, v: function (c) { return c.Gravado; } },
                { t: 'IVA', f: '$', w: 11, v: function (c) { return c.Iva; } },
                { t: 'Total', f: '$', w: 13, v: function (c) { return c.Total; } },
                { t: 'Estado', w: 10, v: function (c) { return c.Anulado ? 'Anulado' : c.Ticket ? 'Sin costo' : 'Vigente'; } },
                { t: 'Motivo de anulación', w: 30, v: function (c) { return c.MotivoAnulacion; } }
            ], filas, filas.length ? [['Total (sin anulados)', '', '', '', '', '', '', '', '', '', r.DescuentosTratamientos, r.DescuentosCupones, r.Gravado, r.Iva, r.Total, '', '']] : []);
        }
    };

    function archivo(sufijo) { return 'caja_' + datos.Desde + '_' + datos.Hasta + (datos.Cajero ? '_' + datos.Cajero : '') + (sufijo ? '_' + sufijo : ''); }

    function exportar() {
        if (!datos) return;
        X.descargar(URL, archivo(''), [hojas.resumen(), hojas.forma(), hojas.cajero(), hojas.tipo(), hojas.dia(),
            hojas.cajas(), hojas.efectivo(), hojas.anulaciones(), hojas.detalle(true)], $('#cjExportar'));
    }

    /* ---------- inicio ---------- */
    api('Cajeros').done(function (lista) {
        var $s = $('#cjCajero');
        $.each(lista || [], function (_, c) { $s.append($('<option/>').val(c.Usuario).text(c.Nombre + ' (' + c.Usuario + ')')); });
    }).fail(falla);

    $('#cjRapidos').on('click', '.btn', function () { rango($(this).data('rango')); consultar(); });
    $('#cjConsultar').on('click', consultar);
    $('#cjVerAnulados').on('change', function () { if (datos) renderFilas(); });
    $('#cjExportar').on('click', exportar);
    // Botón de descarga de cada cuadro
    $('#caja').on('click', '.cj-xlsx', function () {
        var cual = $(this).data('xlsx');
        if (!datos || !hojas[cual]) return;
        X.descargar(URL, archivo(cual), [hojas[cual]()], $(this));
    });
    // PDF con formato de cierre de caja (Reportes/CajaPdf.ashx), con las mismas fechas y cajero de la pantalla
    $('#cjPdf').on('click', function () {
        var desde = $('#cjDesde').val(), hasta = $('#cjHasta').val();
        if (!desde || !hasta || hasta < desde) { showNotification(1, 'warning', 'Seleccione un rango de fechas válido.'); return; }
        window.open('Reportes/CajaPdf.ashx?desde=' + encodeURIComponent(desde) + '&hasta=' + encodeURIComponent(hasta)
            + '&cajero=' + encodeURIComponent($('#cjCajero').val() || '') + '&sucursal=' + encodeURIComponent($('#cjSucursal').val() || '0'), '_blank', 'noopener');
    });

    rango('hoy');
    // Administradores: selector de sucursal (por defecto la suya). Después se consulta el día en curso.
    api('Sucursales').done(function (s) {
        if (s && s.Items && s.Items.length) {
            var $s = $('#cjSucursal');
            $.each(s.Items, function (_, x) { $s.append($('<option/>').val(x.Id).text(x.Texto)); });
            $s.val(String(s.Actual || 0));
            $('#cjSucursalCol').removeClass('d-none');
        }
    }).always(function () { consultar(); });        // al abrir muestra la información del día en curso
    $('#cjSucursal').on('change', consultar);

})(jQuery);
