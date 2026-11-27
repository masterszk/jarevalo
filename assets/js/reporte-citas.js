/* Reporte de citas – Reportes/frm_repReporteCitas.aspx (base en reportes-comun.js) */
(function ($, R) {
    'use strict';

    R.iniciar({
        url: 'Reportes/frm_repReporteCitas.aspx/',
        nombre: 'citas',
        catalogos: { '#rpEspecialista': 'Especialistas', '#rpEstado': 'Estados', '#rpTipo': 'TiposCita' },
        filtros: function () {
            return {
                Especialista: parseInt($('#rpEspecialista').val(), 10) || 0,
                Estado: parseInt($('#rpEstado').val(), 10) || 0,
                TipoCita: parseInt($('#rpTipo').val(), 10) || 0,
                Paciente: $.trim($('#rpPaciente').val())
            };
        },
        render: function (d) {
            $('#kTotal').text(R.num(d.Total));
            $('#kTotalSub').text('Valor programado ' + R.dinero(d.ValorTotal));
            $('#kAtendidas').text(R.num(d.Atendidas));
            $('#kAtendidasSub').text(R.dinero(d.ValorAtendidas) + ' en tratamientos');
            $('#kCanceladas').text(R.num(d.Canceladas));
            $('#kCanceladasSub').text(d.Total ? Math.round(100 * d.Canceladas / d.Total) + ' % del total' : '');
            $('#kAsistencia').text(d.Atendidas + d.Canceladas ? d.Asistencia + ' %' : '—');
            $('#kPendientes').text(R.num(d.Pendientes));
            R.grupo($('#gEstado'), d.PorEstado, true);
            R.grupo($('#gEspecialista'), d.PorEspecialista, true);
            R.grupo($('#gTipo'), d.PorTipo, true);
            R.grupo($('#gDia'), d.PorDiaSemana, false);
        },
        items: function (d) { return d.Items; },
        buscar: function (c) { return [c.Paciente, c.Documento, c.Celular, c.Especialista, c.Estado, c.TipoCita, c.Tratamientos, c.Comentarios, c.Fecha].join(' '); },
        columnas: [
            { titulo: 'Fecha', html: function (c) { return R.esc(c.Fecha) + '<div class="small text-muted">' + R.esc(c.Hora) + '</div>'; }, csv: function (c) { return c.Fecha; } },
            { titulo: 'Hora', html: null, csv: function (c) { return c.Hora; } },
            {
                titulo: 'Paciente',
                html: function (c) { return '<span class="fw-semibold">' + R.esc(R.titulo(c.Paciente)) + '</span><div class="small text-muted">' + R.esc(c.Celular) + '</div>'; },
                csv: function (c) { return c.Paciente; }
            },
            { titulo: 'Documento', html: null, csv: function (c) { return c.Documento; } },
            { titulo: 'Celular', html: null, csv: function (c) { return c.Celular; } },
            { titulo: 'Tipo', html: function (c) { return R.esc(c.TipoCita); }, csv: function (c) { return c.TipoCita; } },
            { titulo: 'Especialista', html: function (c) { return R.esc(c.Especialista); }, csv: function (c) { return c.Especialista; } },
            { titulo: 'Estado', html: function (c) { return '<span class="badge bg-' + R.esc(c.Color || 'secondary') + '">' + R.esc(c.Estado) + '</span>'; }, csv: function (c) { return c.Estado; } },
            { titulo: 'Tratamientos', html: function (c) { return '<span class="small">' + R.esc(c.Tratamientos) + '</span>'; }, csv: function (c) { return c.Tratamientos; } },
            { titulo: 'Valor', clase: 'text-end', html: function (c) { return R.dinero(c.Valor); }, csv: function (c) { return Number(c.Valor || 0).toFixed(2).replace('.', ','); } },
            { titulo: 'Comentarios', html: null, csv: function (c) { return c.Comentarios; } },
            { titulo: 'Creada por', html: function (c) { return '<span class="small">' + R.esc(c.CreadoPor) + '<div class="text-muted">' + R.esc(c.Creado) + '</div></span>'; }, csv: function (c) { return c.CreadoPor + ' ' + c.Creado; } }
        ]
    });

})(jQuery, window.Reporte);
