/* Campana de la barra superior (Default.aspx): garantías de servicios que el especialista no ha visto.
   - Especialista: ve sus garantías nuevas o modificadas y las marca como vistas (una o todas).
   - Administrador: ve cuántas tiene sin ver cada especialista (no las marca; las marca el especialista).
   - Otros usuarios: la campana no se muestra. Se actualiza cada 2 minutos. */
(function ($) {
    'use strict';

    var URL = 'Default.aspx/', REFRESCO_MS = 2 * 60 * 1000;
    var estado = { datos: null, anterior: null };

    function api(metodo, datos) {
        return $.ajax({ type: 'POST', url: URL + metodo, data: JSON.stringify(datos || {}), contentType: 'application/json; charset=utf-8', dataType: 'json' })
            .then(function (r) { return r.d; });
    }
    function esc(s) { return $('<div/>').text(s == null ? '' : String(s)).html(); }
    function titulo(s) { return String(s || '').toLowerCase().replace(/(^|\s)(\S)/g, function (m, a, b) { return a + b.toUpperCase(); }); }

    function cargar() {
        return api('GarantiasPendientes').done(function (r) {
            if (!r || !r.Ok) return;
            $('#gaCampana').toggleClass('d-none', !r.Visible);
            if (!r.Visible) return;
            // suena si llegaron nuevas desde la última consulta
            if (estado.anterior !== null && r.Total > estado.anterior) {
                $('#gaCampanaBtn').removeClass('ga-sonando');
                setTimeout(function () { $('#gaCampanaBtn').addClass('ga-sonando'); }, 30);
            }
            estado.anterior = r.Total;
            estado.datos = r;
            pintar();
        });
    }

    function pintar() {
        var r = estado.datos;
        $('#gaCampanaCont').toggleClass('d-none', !r.Total).text(r.Total > 99 ? '99+' : r.Total);
        $('#gaCampanaBtn').attr('title', r.Total ? r.Total + (r.Total === 1 ? ' garantía de servicios sin ver' : ' garantías de servicios sin ver') : 'Sin garantías de servicios pendientes');
        $('#gaCampanaResumen').text(r.Total ? r.Total + ' sin ver' : '');

        if (!r.Total) {
            $('#gaCampanaLista').html('<div class="text-center text-muted small py-4"><i class="bx bx-check-shield fs-3 d-block mb-1 text-success"></i>'
                + (r.EsEspecialista ? 'No tiene garantías de servicios sin ver.' : 'Los especialistas no tienen garantías sin ver.') + '</div>');
        } else {
            var html = '';
            if (!r.EsEspecialista) {
                html += '<div class="px-3 py-2 small border-bottom bg-light">' + r.PorEspecialista.map(function (g) {
                    return '<span class="me-3"><strong>' + esc(g.Especialista || 'Sin especialista') + '</strong>: ' + g.Cantidad + '</span>';
                }).join('') + '</div>';
            }
            html += r.Items.map(function (g) {
                return '<div class="ga-item" data-id="' + g.Id + '">'
                    + '<div class="d-flex align-items-start gap-2"><div class="flex-fill">'
                    + '<div class="fw-semibold">' + esc(titulo(g.Paciente)) + '</div>'
                    + '<div class="text-muted small">' + (r.EsEspecialista ? '' : esc(g.Especialista) + ' · ')
                    + (g.FechaProcedimiento ? 'procedimiento del ' + esc(g.FechaProcedimiento) : 'sin procedimiento') + (g.Tratamientos ? ' · ' + esc(g.Tratamientos) : '') + '</div>'
                    + '</div>'
                    + (r.EsEspecialista ? '<button type="button" class="btn btn-sm btn-outline-success py-0 px-1 ga-visto" title="Marcar como vista"><i class="bx bx-check"></i></button>' : '')
                    + '</div>'
                    + '<div class="ga-detalle mt-1">' + esc(g.Detalle) + '</div>'
                    + '<div class="text-muted small mt-1">' + esc(g.Fecha) + ' · registró ' + esc(g.Usuario) + '</div>'
                    + '</div>';
            }).join('');
            if (r.Total > r.Items.length) html += '<div class="text-center text-muted small py-2">y ' + (r.Total - r.Items.length) + ' más…</div>';
            $('#gaCampanaLista').html(html);
        }

        var pie = '';
        if (r.EsEspecialista && r.Total) pie += '<button type="button" class="btn btn-sm btn-success" id="gaTodasVistas"><i class="bx bx-check-double"></i> Marcar todas como vistas</button>';
        pie += '<button type="button" class="btn btn-sm btn-outline-secondary ms-auto" id="gaVerDashboard"><i class="bx bx-shield-quarter"></i> '
            + (r.EsEspecialista ? 'Ver en mi dashboard' : 'Ver por especialista') + '</button>';
        if (!r.EsEspecialista && r.Total) pie = '<div class="small text-muted w-100">Se marcan como vistas cuando el especialista las revisa.</div>' + pie;
        $('#gaCampanaPie').html(pie);
    }

    function marcar(id) {
        return api('MarcarGarantiasVistas', { id: id || 0 }).done(function (r) {
            if (!r || !r.Ok) { if (typeof showNotification === 'function') showNotification(1, 'warning', (r && r.Mensaje) || 'No fue posible marcar la garantía.'); return; }
            cargar();
        });
    }

    $('#gaCampanaLista').on('click', '.ga-visto', function () {
        var $i = $(this).closest('.ga-item');
        $(this).prop('disabled', true);
        $i.fadeTo(150, .4);
        marcar(+$i.data('id'));
    });
    $('#gaCampanaPie')
        .on('click', '#gaTodasVistas', function () { $(this).prop('disabled', true); marcar(0); })
        .on('click', '#gaVerDashboard', function () {
            var dd = bootstrap.Dropdown.getInstance(document.getElementById('gaCampanaBtn'));
            if (dd) dd.hide();
            if (typeof AjaxLink !== 'function') return;
            // especialista: su dashboard (detalle de garantías); administrador: dashboard de gerencia (resumen por especialista)
            AjaxLink(estado.datos && estado.datos.EsEspecialista ? 'Dashboard/frm_DashboardUsuarios.aspx' : 'Dashboard/form_DashboardGeneral.aspx');
        });
    // al abrir se refresca para mostrar lo último
    document.getElementById('gaCampanaBtn').addEventListener('show.bs.dropdown', function () { cargar(); });

    cargar();
    setInterval(function () { if (!document.hidden) cargar(); }, REFRESCO_MS);
})(jQuery);
