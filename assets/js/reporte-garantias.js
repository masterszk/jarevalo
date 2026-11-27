/* Reporte de Garantía de Servicios – Reportes/frm_repGarantias.aspx (base en reportes-comun.js)
   Filtros: fechas de registro, especialista, tratamiento, visto por el especialista, paciente y sucursal (administradores). */
(function ($, R) {
    'use strict';

    function porcentaje(n) { return Number(n || 0).toLocaleString('es-SV', { maximumFractionDigits: 1 }) + ' %'; }

    function especialistas(lista) {
        var $t = $('#gEspecialistas').empty();
        if (!lista || !lista.length) { $t.html('<tr><td colspan="4" class="text-muted">Sin datos</td></tr>'); return; }
        $.each(lista, function (_, e) {
            $t.append('<tr><td>' + R.esc(e.Especialista) + (e.NoVistas ? ' <span class="badge bg-warning text-dark" title="No vistas por el especialista">' + e.NoVistas + ' sin ver</span>' : '') + '</td>'
                + '<td class="text-end fw-semibold">' + R.num(e.Garantias) + '</td>'
                + '<td class="text-end text-muted">' + R.num(e.Procedimientos) + '</td>'
                + '<td class="text-end">' + (e.Procedimientos ? porcentaje(e.Porcentaje) : '—') + '</td></tr>');
        });
    }

    R.iniciar({
        url: 'Reportes/frm_repGarantias.aspx/',
        nombre: 'garantias_servicios',
        catalogos: { '#rpEspecialista': 'Especialistas', '#rpTratamiento': 'Tratamientos' },
        filtros: function () {
            return {
                Especialista: parseInt($('#rpEspecialista').val(), 10) || 0,
                Tratamiento: parseInt($('#rpTratamiento').val(), 10) || 0,
                Estado: parseInt($('#rpVisto').val(), 10) || 0,
                Paciente: $.trim($('#rpPaciente').val())
            };
        },
        render: function (d) {
            $('#kGarantias').text(R.num(d.Garantias));
            $('#kGarantiasSub').text(d.Garantias === 1 ? 'registrada en el periodo' : 'registradas en el periodo');
            $('#kPorcentaje').text(d.Procedimientos ? porcentaje(d.Porcentaje) : '—');
            $('#kPorcentajeSub').text(R.num(d.Procedimientos) + ' procedimientos finalizados');
            $('#kPacientes').text(R.num(d.Pacientes));
            $('#kNoVistas').text(R.num(d.NoVistas)).toggleClass('text-warning', d.NoVistas > 0);
            $('#kDias').text(d.DiasPromedio != null ? Number(d.DiasPromedio).toLocaleString('es-SV') + ' días' : '—');
            especialistas(d.PorEspecialista);
            R.grupo($('#gTratamientos'), d.PorTratamiento, false, '');
            R.grupo($('#gSemanas'), d.PorSemana, false, '');
        },
        items: function (d) { return d.Items; },
        buscar: function (x) { return [x.Paciente, x.Documento, x.Celular, x.Especialista, x.Tratamientos, x.Garantia, x.Usuario].join(' '); },
        columnas: [
            { titulo: 'Registrada', html: function (x) { return '<span class="text-nowrap small">' + R.esc(x.Fecha) + '</span><div class="small text-muted">por ' + R.esc(x.Usuario) + '</div>'; }, csv: function (x) { return x.Fecha; } },
            { titulo: 'Registrada por', html: null, csv: function (x) { return x.Usuario; } },
            {
                titulo: 'Paciente',
                html: function (x) { return '<span class="fw-semibold">' + R.esc(R.titulo(x.Paciente)) + '</span><div class="small text-muted">#' + x.IdExpediente + ' · ' + R.esc(x.Documento || 'Sin documento') + (x.Celular ? ' · ' + R.esc(x.Celular) : '') + '</div>'; },
                csv: function (x) { return x.Paciente; }
            },
            { titulo: 'Documento', html: null, csv: function (x) { return x.Documento; } },
            { titulo: 'Celular', html: null, csv: function (x) { return x.Celular; } },
            { titulo: 'Especialista', html: function (x) { return R.esc(x.Especialista); }, csv: function (x) { return x.Especialista; } },
            {
                titulo: 'Procedimiento',
                html: function (x) {
                    return '<span class="text-nowrap small">' + R.esc(x.FechaProcedimiento || '—') + '</span>'
                        + (x.DiasDesdeProcedimiento != null ? '<div class="small text-muted">' + x.DiasDesdeProcedimiento + (x.DiasDesdeProcedimiento === 1 ? ' día antes' : ' días antes') + '</div>' : '')
                        + '<div class="small">' + R.esc(x.Tratamientos) + '</div>';
                },
                csv: function (x) { return x.FechaProcedimiento; }
            },
            { titulo: 'Tratamientos', html: null, csv: function (x) { return x.Tratamientos; } },
            { titulo: 'Días después del procedimiento', html: null, csv: function (x) { return x.DiasDesdeProcedimiento; } },
            { titulo: 'Garantía', html: function (x) { return '<div class="small" style="max-width:420px;white-space:pre-wrap">' + R.esc(x.Garantia) + '</div>'; }, csv: function (x) { return x.Garantia; } },
            {
                titulo: 'Visto', clase: 'text-center',
                html: function (x) {
                    return x.Visto ? '<span class="badge bg-success" title="' + R.esc(x.VistoDetalle) + '">Vista</span>' : '<span class="badge bg-warning text-dark">Sin ver</span>';
                },
                csv: function (x) { return x.Visto ? 'Sí (' + x.VistoDetalle + ')' : 'No'; }
            },
            { titulo: 'Sucursal', html: null, csv: function (x) { return x.Sucursal; } }
        ]
    });

    $('#rpVisto').on('change', function () { $('#rpConsultar').trigger('click'); });

})(jQuery, window.Reporte);
