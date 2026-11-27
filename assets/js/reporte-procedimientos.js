/* Reporte de procedimientos finalizados – Reportes/frm_repReporteProcedimientos.aspx (base en reportes-comun.js) */
(function ($, R) {
    'use strict';

    var FACTURA = { Cobrada: 'bg-success', Pendiente: 'bg-warning text-dark', 'Sin factura': 'bg-light text-dark border' };
    function monto(n) { return Number(n || 0).toFixed(2).replace('.', ','); }

    R.iniciar({
        url: 'Reportes/frm_repReporteProcedimientos.aspx/',
        nombre: 'procedimientos',
        catalogos: { '#rpEspecialista': 'Especialistas', '#rpTratamiento': 'Tratamientos', '#rpTipo': 'TiposCita' },
        filtros: function () {
            return {
                Especialista: parseInt($('#rpEspecialista').val(), 10) || 0,
                Tratamiento: parseInt($('#rpTratamiento').val(), 10) || 0,
                TipoCita: parseInt($('#rpTipo').val(), 10) || 0,
                Paciente: $.trim($('#rpPaciente').val())
            };
        },
        render: function (d) {
            $('#kProc').text(R.num(d.Procedimientos));
            $('#kProcSub').text(R.num(d.Pacientes) + ' pacientes · ' + R.num(d.Tratamientos) + ' tratamientos');
            $('#kTotal').text(R.dinero(d.Total));
            $('#kTotalSub').text('Ticket promedio ' + R.dinero(d.TicketPromedio));
            $('#kCobrado').text(R.dinero(d.Cobrado));
            $('#kPendiente').text(R.dinero(d.Pendiente));
            $('#kMinutos').text(d.MinutosPromedio ? d.MinutosPromedio + ' min' : '—');
            $('#kMinutosSub').text(d.MinutosPromedio ? 'de inicio a fin de la atención' : 'sin horas registradas');
            R.grupo($('#gEspecialista'), d.PorEspecialista, true);
            R.grupo($('#gTratamiento'), d.PorTratamiento, true);
            R.grupo($('#gDia'), d.PorDia, true);
        },
        items: function (d) { return d.Items; },
        buscar: function (p) { return [p.Paciente, p.Documento, p.Especialista, p.TipoCita, p.Tratamientos, p.Diagnostico, p.Factura, p.Fecha].join(' '); },
        columnas: [
            { titulo: 'Fecha', html: function (p) { return R.esc(p.Fecha) + '<div class="small text-muted">' + R.esc(p.Horario) + '</div>'; }, csv: function (p) { return p.Fecha; } },
            { titulo: 'Horario', html: null, csv: function (p) { return p.Horario; } },
            { titulo: 'Minutos', html: null, csv: function (p) { return p.Minutos == null ? '' : p.Minutos; } },
            {
                titulo: 'Paciente',
                html: function (p) { return '<span class="fw-semibold">' + R.esc(R.titulo(p.Paciente)) + '</span><div class="small text-muted">' + R.esc(p.Documento) + '</div>'; },
                csv: function (p) { return p.Paciente; }
            },
            { titulo: 'Documento', html: null, csv: function (p) { return p.Documento; } },
            { titulo: 'Especialista', html: function (p) { return R.esc(p.Especialista) + '<div class="small text-muted">' + R.esc(p.TipoCita) + '</div>'; }, csv: function (p) { return p.Especialista; } },
            { titulo: 'Tipo de cita', html: null, csv: function (p) { return p.TipoCita; } },
            { titulo: 'Tratamientos', html: function (p) { return '<span class="small">' + R.esc(p.Tratamientos) + '</span>'; }, csv: function (p) { return p.Tratamientos; } },
            { titulo: 'Cant.', clase: 'text-end', html: function (p) { return R.num(p.Cantidad); }, csv: function (p) { return p.Cantidad; } },
            { titulo: 'Total', clase: 'text-end', html: function (p) { return '<strong>' + R.dinero(p.Total) + '</strong>'; }, csv: function (p) { return monto(p.Total); } },
            { titulo: 'Diagnóstico', html: function (p) { return '<span class="small text-muted rp-corto" title="' + R.esc(p.Diagnostico) + '">' + R.esc(p.Diagnostico) + '</span>'; }, csv: function (p) { return p.Diagnostico; } },
            {
                titulo: 'Factura',
                html: function (p) { return '<span class="badge ' + (FACTURA[p.Factura] || 'bg-secondary') + '">' + R.esc(p.Factura) + '</span>' + (p.IdFactura ? '<div class="small text-muted">#' + p.IdFactura + '</div>' : ''); },
                csv: function (p) { return p.Factura + (p.IdFactura ? ' #' + p.IdFactura : ''); }
            }
        ]
    });

})(jQuery, window.Reporte);
