/* Reporte de expedientes registrados – Reportes/frm_Expedientes.aspx (base en reportes-comun.js) */
(function ($, R) {
    'use strict';

    R.iniciar({
        url: 'Reportes/frm_Expedientes.aspx/',
        nombre: 'expedientes',
        catalogos: { '#rpSexo': 'Sexos', '#rpDepartamento': 'Departamentos' },
        filtros: function () {
            var fuente = $('#rpFuente').val();
            return {
                Sexo: parseInt($('#rpSexo').val(), 10) || 0,
                Departamento: parseInt($('#rpDepartamento').val(), 10) || 0,
                Fuente: fuente === '0' ? '' : fuente,
                Paciente: $.trim($('#rpPaciente').val())
            };
        },
        render: function (d) {
            $('#kTotal').text(R.num(d.Total));
            $('#kVisitas').text(R.num(d.ConVisitas));
            $('#kVisitasSub').text(d.Total ? Math.round(100 * d.ConVisitas / d.Total) + ' % ya tuvo una visita' : '');
            $('#kRecurrentes').text(R.num(d.Recurrentes));
            $('#kEdad').text(d.EdadPromedio != null ? d.EdadPromedio : '—');
            $('#kSinEmail').text(R.num(d.SinEmail));
            R.grupo($('#gSexo'), d.PorSexo, false);
            R.grupo($('#gEdad'), d.PorEdad, false);
            R.grupo($('#gFuente'), d.PorFuente, false);
            R.grupo($('#gDepartamento'), d.PorDepartamento, false);
            R.grupo($('#gUsuario'), d.PorUsuario, false);
        },
        items: function (d) { return d.Items; },
        buscar: function (e) { return [e.Paciente, e.Documento, e.Celular, e.Email, e.Ubicacion, e.Fuentes, e.Sexo, e.RegistradoPor].join(' '); },
        columnas: [
            { titulo: 'Registro', html: function (e) { return '<span class="small">' + R.esc(e.Registro) + '</span>'; }, csv: function (e) { return e.Registro; } },
            {
                titulo: 'Paciente',
                html: function (e) { return '<span class="fw-semibold">' + R.esc(R.titulo(e.Paciente)) + '</span><div class="small text-muted">#' + e.Id + ' · ' + R.esc(e.Documento || 'Sin documento') + '</div>'; },
                csv: function (e) { return e.Paciente; }
            },
            { titulo: 'Documento', html: null, csv: function (e) { return e.Documento; } },
            { titulo: 'Edad', clase: 'text-end', html: function (e) { return e.Edad ? R.esc(e.Edad) : '—'; }, csv: function (e) { return e.Edad; } },
            { titulo: 'Sexo', html: function (e) { return R.esc(R.titulo(e.Sexo)); }, csv: function (e) { return e.Sexo; } },
            { titulo: 'Contacto', html: function (e) { return '<span class="small">' + R.esc(e.Celular) + '<div class="text-muted">' + R.esc(e.Email) + '</div></span>'; }, csv: null },
            { titulo: 'Celular', html: null, csv: function (e) { return e.Celular; } },
            { titulo: 'Email', html: null, csv: function (e) { return e.Email; } },
            { titulo: 'Ubicación', html: function (e) { return '<span class="small">' + R.esc(e.Ubicacion) + '</span>'; }, csv: function (e) { return e.Ubicacion; } },
            { titulo: 'Nos conoció por', html: function (e) { return '<span class="small">' + R.esc(e.Fuentes || '—') + '</span>'; }, csv: function (e) { return e.Fuentes; } },
            {
                titulo: 'Visitas', clase: 'text-end',
                html: function (e) { return e.Visitas ? '<strong>' + e.Visitas + '</strong><div class="small text-muted">' + R.esc(e.UltimaVisita) + '</div>' : '<span class="text-muted">0</span>'; },
                csv: function (e) { return e.Visitas; }
            },
            { titulo: 'Última visita', html: null, csv: function (e) { return e.UltimaVisita; } },
            { titulo: 'Registrado por', html: function (e) { return '<span class="small">' + R.esc(e.RegistradoPor) + '</span>'; }, csv: function (e) { return e.RegistradoPor; } }
        ]
    });

})(jQuery, window.Reporte);
