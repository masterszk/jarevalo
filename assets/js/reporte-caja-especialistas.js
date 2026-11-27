/* Reporte de caja por especialista – Reportes/frm_repCajaEspecialistas.aspx (base en reportes-comun.js)
   Filtros: fechas de emisión, especialista, forma de pago, paciente y sucursal (administradores).
   Cobrado con IVA por forma de pago y venta sin IVA (mismo cálculo de las metas) de cada especialista. */
(function ($, R) {
    'use strict';

    function porcentaje(n) { return Number(n || 0).toLocaleString('es-SV', { maximumFractionDigits: 1 }) + ' %'; }

    function forma(e, nombre) {
        var g = $.grep(e.PorFormaPago || [], function (x) { return x.Nombre === nombre; })[0];
        return g ? g.Total : 0;
    }

    // Comisión con el % de escala y el bono por meta debajo; el cálculo completo en el title
    function comision(e) {
        var sub = [];
        if (e.PorcentajeEscala) sub.push('escala ' + porcentaje(e.PorcentajeEscala));
        if (e.BonoAlcance) sub.push('incl. bono meta ' + R.dinero(e.BonoAlcance));
        if (!e.Comision && e.Meta != null) sub.push(e.SinEscalas ? 'meta sin escalas' : 'bajo el mínimo');
        if (e.Meta == null && !e.Comision) return '<span class="text-muted small" title="Sin meta registrada en Registros › Metas">sin meta</span>';
        return '<span class="fw-semibold">' + R.dinero(e.Comision) + '</span>'
            + (sub.length ? '<div class="small text-muted text-nowrap">' + R.esc(sub.join(' · ')) + '</div>' : '');
    }

    // Tarjeta: comisión del especialista seleccionado en el filtro (con "Todos", la suma de todos)
    function tarjetaComision(d) {
        var id = parseInt($('#rpEspecialista').val(), 10) || 0;
        var e = id ? $.grep(d.PorEspecialista, function (x) { return x.IdEspecialista === id; })[0] : null;
        if (id) {
            $('#kComisionTitulo').text('Comisión · ' + $('#rpEspecialista option:selected').text());
            $('#kComision').text(e && (e.Meta != null || e.Comision) ? R.dinero(e.Comision) : '—');
            var sub = [];
            if (!e) sub.push('sin cobros en el periodo');
            else if (e.Meta == null) sub.push('sin meta registrada');
            else if (e.SinEscalas) sub.push('meta sin escalas de comisión (Registros › Metas)');
            else {
                if (e.PorcentajeEscala) sub.push('escala ' + porcentaje(e.PorcentajeEscala));
                else sub.push(e.SinEscalas ? 'meta sin escalas' : 'bajo el mínimo');
                sub.push('meta ' + R.dinero(e.Meta));
                if (e.Meta > 0) sub.push('avance ' + porcentaje(d.MetaAvance));
            }
            $('#kComisionSub').text(sub.join(' · ')).attr('title', e && e.DetalleComision || '');
        } else {
            $('#kComisionTitulo').text('Comisión');
            $('#kComision').text(R.dinero(d.Comision));
            var con = $.grep(d.PorEspecialista, function (x) { return x.Comision > 0; }).length;
            $('#kComisionSub').text('total de ' + (d.MetaEspecialistas || 0) + ' especialista' + (d.MetaEspecialistas === 1 ? '' : 's') + ' con meta'
                + (con ? ' · ' + con + ' comisiona' + (con === 1 ? '' : 'n') : '')).attr('title', '');
        }
    }

    function especialistas(d) {
        var formas = d.FormasPago || [], conAdelantos = d.Adelantos > 0;
        $('#ceThead').html('<tr><th>Especialista</th><th class="text-end">Pacientes</th>'
            + $.map(formas, function (f) { return '<th class="text-end">' + R.esc(f) + '</th>'; }).join('')
            + '<th class="text-end">Cobrado con IVA</th><th class="text-end">IVA</th>'
            + (conAdelantos ? '<th class="text-end" title="Pagos adelantados aplicados en el periodo (sin IVA)">Adelantos aplicados</th>' : '')
            + '<th class="text-end">Ventas sin IVA</th><th class="text-end" title="Comisión por escala + bono de escala + bono por cumplir la meta">Comisión</th></tr>');

        var $t = $('#ceFilas').empty(), columnas = 6 + formas.length + (conAdelantos ? 1 : 0);
        if (!d.PorEspecialista.length) {
            $t.html('<tr><td colspan="' + columnas + '" class="text-center text-muted py-3">No hay cobros con estos filtros.</td></tr>');
            $('#cePie').empty();
            return;
        }
        $.each(d.PorEspecialista, function (_, e) {
            $t.append('<tr><td class="fw-semibold">' + R.esc(e.Especialista)
                + '<div class="progress db-barra" title="' + porcentaje(e.Porcentaje) + ' del cobrado"><div class="progress-bar" style="width:' + Math.round(e.Porcentaje) + '%"></div></div></td>'
                + '<td class="text-end">' + R.num(e.Pacientes) + '</td>'
                + $.map(formas, function (f) { var v = forma(e, f); return '<td class="text-end' + (v ? '' : ' text-muted') + '">' + R.dinero(v) + '</td>'; }).join('')
                + '<td class="text-end fw-semibold">' + R.dinero(e.Cobrado) + '</td>'
                + '<td class="text-end text-muted">' + R.dinero(e.Iva) + '</td>'
                + (conAdelantos ? '<td class="text-end">' + R.dinero(e.Adelantos) + '</td>' : '')
                + '<td class="text-end fw-semibold">' + R.dinero(e.SinIva) + '</td>'
                + '<td class="text-end"' + (e.DetalleComision ? ' title="' + R.esc(e.DetalleComision) + '"' : '') + '>' + comision(e) + '</td></tr>');
        });
        $('#cePie').html('<tr><td>Total</td>'
            + '<td class="text-end">' + R.num(d.Pacientes) + '</td>'
            + $.map(d.PorFormaPago, function (g) { return '<td class="text-end">' + R.dinero(g.Total) + '</td>'; }).join('')
            + '<td class="text-end">' + R.dinero(d.Cobrado) + '</td>'
            + '<td class="text-end">' + R.dinero(d.Iva) + '</td>'
            + (conAdelantos ? '<td class="text-end">' + R.dinero(d.Adelantos) + '</td>' : '')
            + '<td class="text-end">' + R.dinero(d.SinIva) + '</td>'
            + '<td class="text-end">' + R.dinero(d.Comision) + '</td></tr>');
    }

    // Lista con cantidad de documentos y monto; total al pie (fuera del scroll)
    function lista($ul, $total, grupos) {
        $ul.empty();
        if (!grupos.length) { $ul.html('<li class="list-group-item px-0 text-muted">Sin cobros</li>'); $total.addClass('d-none'); return; }
        var docs = 0, monto = 0;
        $.each(grupos, function (_, g) {
            docs += g.Documentos; monto += g.Total;
            $ul.append('<li class="list-group-item px-0"><span>' + R.esc(g.Nombre) + ' <span class="text-muted">(' + g.Documentos + ')</span></span><strong>' + R.dinero(g.Total) + '</strong></li>');
        });
        $total.removeClass('d-none').html('<span>Total <span class="text-muted fw-normal">(' + docs + ')</span></span><span>' + R.dinero(monto) + '</span>');
    }

    /* ---------- Excel (.xlsx) ---------- */
    var X = window.ExcelReporte, URL = 'Reportes/frm_repCajaEspecialistas.aspx/', ultimo = null;

    function titulo(cuadro) { return 'Caja por especialista · ' + cuadro + ' · ' + $('#rpTitulo').text(); }
    function archivo(d, sufijo) { return 'caja_por_especialista_' + d.Desde + '_' + d.Hasta + (sufijo ? '_' + sufijo : ''); }
    function normalizar(s) { return String(s || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, ''); }
    function buscar(x) { return [x.Documento, x.Paciente, x.DocumentoPaciente, x.Especialista, x.FormaPago, x.Tratamientos, x.Cajero, x.Tipo].join(' '); }

    var hojas = {
        resumen: function (d) {
            return X.hoja('Resumen', titulo('Resumen'), [
                { t: 'Concepto', w: 40, v: function (f) { return f[0]; } },
                { t: 'Monto', f: '$', w: 16, v: function (f) { return f[2] ? null : f[1]; } },
                { t: 'Cantidad', w: 12, v: function (f) { return f[2] ? f[1] : null; } }
            ], [['Total cobrado (con IVA)', d.Cobrado], ['IVA', d.Iva], ['Ventas sin IVA', d.SinIva], ['Pagos adelantados aplicados (sin IVA)', d.Adelantos],
                ['Meta del mes (' + (d.MetaPeriodo || '') + ')', d.MetaMes], ['Avance de la meta (%)', d.MetaAvance, true], ['Comisión', d.Comision],
                ['Ticket promedio', d.TicketPromedio], ['Documentos', d.Documentos, true], ['Pacientes', d.Pacientes, true]]);
        },
        especialistas: function (d) {
            var formas = d.FormasPago || [];
            var cols = [
                { t: 'Especialista', w: 28, v: function (e) { return e.Especialista; } },
                { t: 'Pacientes', w: 11, v: function (e) { return e.Pacientes; } }
            ].concat($.map(formas, function (f) { return { t: f, f: '$', w: 16, v: function (e) { return forma(e, f); } }; })).concat([
                { t: 'Cobrado con IVA', f: '$', w: 16, v: function (e) { return e.Cobrado; } },
                { t: 'IVA', f: '$', w: 12, v: function (e) { return e.Iva; } },
                { t: 'Adelantos aplicados', f: '$', w: 15, v: function (e) { return e.Adelantos; } },
                { t: 'Ventas sin IVA', f: '$', w: 16, v: function (e) { return e.SinIva; } },
                { t: 'Meta del mes', f: '$', w: 14, v: function (e) { return e.Meta; } },
                { t: 'Comisión', f: '$', w: 14, v: function (e) { return e.Comision; } },
                { t: 'Cálculo de la comisión', w: 60, v: function (e) { return e.DetalleComision; } }
            ]);
            var total = ['Total', d.Pacientes].concat($.map(d.PorFormaPago, function (g) { return g.Total; }))
                .concat([d.Cobrado, d.Iva, d.Adelantos, d.SinIva, d.MetaMes || null, d.Comision, '']);
            return X.hoja('Por especialista', titulo('Por especialista'), cols, d.PorEspecialista, d.PorEspecialista.length ? [total] : []);
        },
        forma: function (d) { return X.hojaGrupo('Por forma de pago', titulo('Por forma de pago'), 'Forma de pago', d.PorFormaPago); },
        dia: function (d) {
            var g = d.PorDia, docs = 0, tot = 0;
            $.each(g, function (_, x) { docs += x.Documentos; tot += x.Total; });
            return X.hoja('Por día', titulo('Por día'), [
                { t: 'Día', f: 'd', w: 13, v: function (x) { return X.iso(x.Nombre); } },
                { t: 'Documentos', w: 13, v: function (x) { return x.Documentos; } },
                { t: 'Cobrado con IVA', f: '$', w: 16, v: function (x) { return x.Total; } }
            ], g, g.length ? [['Total', docs, tot]] : []);
        },
        detalle: function (d, filas) {
            var cobrado = 0, iva = 0, gravado = 0, sinIva = 0;
            $.each(filas, function (_, x) { if (x.Cobro) { cobrado += x.Total; iva += x.Iva; gravado += x.Gravado; } sinIva += x.SinIva; });
            return X.hoja('Detalle de cobros', titulo('Detalle de cobros'), [
                { t: 'Fecha', f: 'f', w: 17, v: function (x) { return X.iso(x.Fecha); } },
                { t: 'Tipo', w: 22, v: function (x) { return x.Tipo; } },
                { t: 'Número de control', w: 34, v: function (x) { return x.Documento; } },
                { t: 'Expediente', w: 11, v: function (x) { return x.IdExpediente || null; } },
                { t: 'Paciente', w: 32, v: function (x) { return x.Paciente; } },
                { t: 'Documento del paciente', w: 18, v: function (x) { return x.DocumentoPaciente; } },
                { t: 'Especialista', w: 22, v: function (x) { return x.Especialista; } },
                { t: 'Fecha de atención', f: 'd', w: 13, v: function (x) { return X.iso(x.FechaAtencion); } },
                { t: 'Tratamientos', w: 40, v: function (x) { return x.Tratamientos; } },
                { t: 'Forma de pago', w: 18, v: function (x) { return x.FormaPago; } },
                { t: 'Gravado', f: '$', w: 12, v: function (x) { return x.Gravado; } },
                { t: 'IVA', f: '$', w: 11, v: function (x) { return x.Iva; } },
                { t: 'Cobrado', f: '$', w: 13, v: function (x) { return x.Cobro ? x.Total : 0; } },
                { t: 'Sin IVA', f: '$', w: 13, v: function (x) { return x.SinIva; } },
                { t: 'Origen', w: 24, v: function (x) { return x.Origen; } },
                { t: 'Cajero', w: 22, v: function (x) { return x.Cajero; } },
                { t: 'Sucursal', w: 16, v: function (x) { return x.Sucursal; } }
            ], filas, filas.length ? [['Total', '', '', '', '', '', '', '', '', '', gravado, iva, cobrado, sinIva, '', '', '']] : []);
        }
    };

    // Filas del detalle que coinciden con la búsqueda de la pantalla
    function filasDetalle(d) {
        var q = normalizar($.trim($('#rpBuscar').val()));
        return !q ? d.Items : $.grep(d.Items, function (x) { return normalizar(buscar(x)).indexOf(q) >= 0; });
    }

    $('#rpResultado').on('click', '.cj-xlsx', function () {
        var cual = $(this).data('xlsx');
        if (!ultimo || !hojas[cual]) return;
        X.descargar(URL, archivo(ultimo, cual), [hojas[cual](ultimo, filasDetalle(ultimo))], $(this));
    });

    R.iniciar({
        url: 'Reportes/frm_repCajaEspecialistas.aspx/',
        exportar: function (d, filas, $b) {
            X.descargar(URL, archivo(d, ''), [hojas.resumen(d), hojas.especialistas(d), hojas.forma(d), hojas.dia(d), hojas.detalle(d, filas)], $b);
        },
        nombre: 'caja_por_especialista',
        catalogos: { '#rpEspecialista': 'Especialistas', '#rpFormaPago': 'FormasPago' },
        filtros: function () {
            return {
                Especialista: parseInt($('#rpEspecialista').val(), 10) || 0,
                FormaPago: parseInt($('#rpFormaPago').val(), 10) || 0,
                Paciente: $.trim($('#rpPaciente').val())
            };
        },
        render: function (d) {
            ultimo = d;
            $('#kCobrado').text(R.dinero(d.Cobrado));
            $('#kCobradoSub').text('IVA ' + R.dinero(d.Iva));
            $('#kSinIva').text(R.dinero(d.SinIva));
            $('#kSinIvaSub').text(d.Adelantos > 0 ? 'incluye ' + R.dinero(d.Adelantos) + ' de pagos adelantados aplicados' : 'como en las metas');
            tarjetaComision(d);
            $('#kPacientes').text(R.num(d.Pacientes));
            $('#kTicket').text(R.dinero(d.TicketPromedio));
            especialistas(d);
            lista($('#ceFormas'), $('#ceFormasTotal'), d.PorFormaPago);
            lista($('#ceDias'), $('#ceDiasTotal'), d.PorDia);
        },
        items: function (d) { return d.Items; },
        buscar: buscar,
        columnas: [
            { titulo: 'Fecha', html: function (x) { return '<span class="text-nowrap small">' + R.esc(x.Fecha) + '</span>'; }, csv: function (x) { return x.Fecha; } },
            {
                titulo: 'Documento',
                html: function (x) {
                    return '<span class="small">' + R.esc(x.Tipo) + '</span>' + (x.Documento ? '<div class="small text-muted">' + R.esc(x.Documento) + '</div>' : '');
                },
                csv: function (x) { return x.Tipo; }
            },
            { titulo: 'Número de control', html: null, csv: function (x) { return x.Documento; } },
            {
                titulo: 'Paciente',
                html: function (x) {
                    return '<span class="fw-semibold">' + R.esc(R.titulo(x.Paciente)) + '</span>'
                        + (x.IdExpediente ? '<div class="small text-muted">#' + x.IdExpediente + (x.DocumentoPaciente ? ' · ' + R.esc(x.DocumentoPaciente) : '') + '</div>' : '');
                },
                csv: function (x) { return x.Paciente; }
            },
            { titulo: 'Documento del paciente', html: null, csv: function (x) { return x.DocumentoPaciente; } },
            {
                titulo: 'Especialista',
                html: function (x) {
                    return R.esc(x.Especialista) + (x.FechaAtencion ? '<div class="small text-muted">Atendió ' + R.esc(x.FechaAtencion) + '</div>' : '');
                },
                csv: function (x) { return x.Especialista; }
            },
            { titulo: 'Fecha de atención', html: null, csv: function (x) { return x.FechaAtencion; } },
            { titulo: 'Tratamientos', html: function (x) { return '<div class="small text-wrap" style="max-width:280px">' + R.esc(x.Tratamientos) + '</div>'; }, csv: function (x) { return x.Tratamientos; } },
            { titulo: 'Forma de pago', html: function (x) { return R.esc(x.FormaPago); }, csv: function (x) { return x.FormaPago; } },
            { titulo: 'Gravado', html: null, csv: function (x) { return x.Gravado; } },
            { titulo: 'IVA', html: null, csv: function (x) { return x.Iva; } },
            {
                titulo: 'Cobrado', clase: 'text-end',
                html: function (x) { return x.Cobro ? R.dinero(x.Total) : '<span class="text-muted small" title="Ya se cobró cuando se pagó por adelantado">—</span>'; },
                csv: function (x) { return x.Cobro ? x.Total : 0; }
            },
            { titulo: 'Sin IVA', clase: 'text-end', html: function (x) { return R.dinero(x.SinIva); }, csv: function (x) { return x.SinIva; } },
            { titulo: 'Origen', html: null, csv: function (x) { return x.Origen; } },
            { titulo: 'Cajero', html: function (x) { return '<span class="small">' + R.esc(x.Cajero) + '</span>'; }, csv: function (x) { return x.Cajero; } },
            { titulo: 'Sucursal', html: null, csv: function (x) { return x.Sucursal; } }
        ]
    });

    $('#rpEspecialista, #rpFormaPago').on('change', function () { $('#rpConsultar').trigger('click'); });

    // PDF con las tarjetas y la tabla por especialista (Reportes/CajaEspecialistasPdf.ashx), con los mismos filtros del reporte
    $('#rpPdf').on('click', function () {
        if (!ultimo) return;
        var q = {
            desde: ultimo.Desde, hasta: ultimo.Hasta,
            especialista: $('#rpEspecialista').val() || '0', formaPago: $('#rpFormaPago').val() || '0',
            paciente: $.trim($('#rpPaciente').val()), sucursal: $('#rpSucursal').val() || '0'
        };
        window.open('Reportes/CajaEspecialistasPdf.ashx?' + $.param(q), '_blank', 'noopener');
    });

})(jQuery, window.Reporte);
