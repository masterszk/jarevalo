/* Reporte de pacientes por procedimientos y citas, de mayor a menor – Reportes/frm_repPacientesActividad.aspx (base en reportes-comun.js) */
(function ($, R) {
    'use strict';

    // Orden de mayor a menor: el criterio elegido primero y luego los otros como desempate
    var CRITERIOS = {
        procedimientos: ['Procedimientos', 'Citas', 'Valor'],
        citas: ['Citas', 'Procedimientos', 'Valor'],
        valor: ['Valor', 'Procedimientos', 'Citas']
    };
    var ultimo = null;

    function ordenar(items) {
        var c = CRITERIOS[$('#rpOrden').val()] || CRITERIOS.procedimientos;
        var lista = items.slice().sort(function (a, b) {
            for (var i = 0; i < c.length; i++) if (b[c[i]] !== a[c[i]]) return b[c[i]] - a[c[i]];
            return String(a.Paciente).localeCompare(String(b.Paciente));
        });
        $.each(lista, function (i, x) { x.Posicion = i + 1; });
        return lista;
    }

    function top(items) {
        var $ul = $('#gTop').empty(), c = ($('#rpOrden').val() || 'procedimientos');
        var lista = items.slice(0, 10);
        if (!lista.length) { $ul.html('<li class="list-group-item px-0 text-muted">Sin datos</li>'); return; }
        var campo = CRITERIOS[c][0], max = Math.max.apply(null, $.map(lista, function (x) { return Number(x[campo]) || 0; }).concat([1]));
        $.each(lista, function (_, x) {
            $ul.append(
                '<li class="list-group-item px-0 d-block">' +
                '  <div class="d-flex justify-content-between gap-2"><span class="text-truncate"><span class="text-muted me-1">' + x.Posicion + '.</span>' + R.esc(R.titulo(x.Paciente)) + '</span>' +
                '    <span class="text-nowrap small"><strong>' + x.Procedimientos + '</strong> proc. · <strong>' + x.Citas + '</strong> citas · ' + R.dinero(x.Valor) + '</span></div>' +
                '  <div class="progress db-barra"><div class="progress-bar" style="width:' + Math.round(100 * (Number(x[campo]) || 0) / max) + '%"></div></div>' +
                '</li>');
        });
    }

    R.iniciar({
        url: 'Reportes/frm_repPacientesActividad.aspx/',
        nombre: 'pacientes_actividad',
        catalogos: { '#rpEspecialista': 'Especialistas' },
        filtros: function () {
            return { Especialista: parseInt($('#rpEspecialista').val(), 10) || 0, Paciente: $.trim($('#rpPaciente').val()) };
        },
        render: function (d) {
            ultimo = d;
            $('#kPacientes').text(R.num(d.Pacientes));
            $('#kProcedimientos').text(R.num(d.Procedimientos));
            $('#kProcedimientosSub').text(d.Pacientes ? 'finalizados · ' + (d.Procedimientos / d.Pacientes).toFixed(1) + ' por paciente' : 'finalizados');
            $('#kCitas').text(R.num(d.Citas));
            $('#kCitasSub').text(R.num(d.Canceladas) + ' canceladas · sin anuladas');
            $('#kRecurrentes').text(R.num(d.Recurrentes));
            $('#kValor').text(R.dinero(d.Valor));
            R.grupo($('#gProcedimientos'), d.PorProcedimientos, true, 'pac.');
            top(d.Items);
        },
        // reportes-comun.js llama items() antes que render(): aquí se ordena según el criterio elegido
        items: function (d) { d.Items = ordenar(d.Items); return d.Items; },
        buscar: function (x) { return [x.Paciente, x.Documento, x.Celular].join(' '); },
        columnas: [
            { titulo: '#', clase: 'text-end', html: function (x) { return '<span class="text-muted">' + x.Posicion + '</span>'; }, csv: function (x) { return x.Posicion; } },
            {
                titulo: 'Paciente',
                html: function (x) { return '<span class="fw-semibold">' + R.esc(R.titulo(x.Paciente)) + '</span><div class="small text-muted">#' + x.Id + ' · ' + R.esc(x.Documento || 'Sin documento') + (x.Edad ? ' · ' + R.esc(x.Edad) + ' años' : '') + '</div>'; },
                csv: function (x) { return x.Paciente; }
            },
            { titulo: 'Documento', html: null, csv: function (x) { return x.Documento; } },
            { titulo: 'Edad', html: null, csv: function (x) { return x.Edad; } },
            { titulo: 'Celular', html: function (x) { return '<span class="small">' + R.esc(x.Celular) + '</span>'; }, csv: function (x) { return x.Celular; } },
            {
                titulo: 'Procedimientos', clase: 'text-end',
                html: function (x) { return x.Procedimientos ? '<strong>' + x.Procedimientos + '</strong><div class="small text-muted">' + x.Visitas + (x.Visitas === 1 ? ' visita' : ' visitas') + '</div>' : '<span class="text-muted">0</span>'; },
                csv: function (x) { return x.Procedimientos; }
            },
            { titulo: 'Visitas', html: null, csv: function (x) { return x.Visitas; } },
            { titulo: 'Último procedimiento', html: function (x) { return '<span class="small">' + R.esc(x.UltimoProcedimiento || '—') + '</span>'; }, csv: function (x) { return x.UltimoProcedimiento; } },
            {
                titulo: 'Citas', clase: 'text-end',
                html: function (x) {
                    return x.Citas ? '<strong>' + x.Citas + '</strong><div class="small text-muted">' + x.Atendidas + ' atendidas' + (x.Canceladas ? ' · <span class="text-danger">' + x.Canceladas + ' canc.</span>' : '') + '</div>' : '<span class="text-muted">0</span>';
                },
                csv: function (x) { return x.Citas; }
            },
            { titulo: 'Atendidas', html: null, csv: function (x) { return x.Atendidas; } },
            { titulo: 'Canceladas', html: null, csv: function (x) { return x.Canceladas; } },
            { titulo: 'Última cita', html: function (x) { return '<span class="small">' + R.esc(x.UltimaCita || '—') + '</span>'; }, csv: function (x) { return x.UltimaCita; } },
            { titulo: 'Valor', clase: 'text-end', html: function (x) { return R.dinero(x.Valor); }, csv: function (x) { return Number(x.Valor || 0).toFixed(2).replace('.', ','); } }
        ]
    });

    // Cambiar el orden vuelve a consultar (el servidor no cambia; se reordena y se renumera)
    $('#rpOrden').on('change', function () { $('#rpConsultar').trigger('click'); });
    // "Quitar filtros" pone los selects en 0: el orden vuelve a Procedimientos
    $('#rpLimpiar').on('click', function () { $('#rpOrden').val('procedimientos'); });

})(jQuery, window.Reporte);
