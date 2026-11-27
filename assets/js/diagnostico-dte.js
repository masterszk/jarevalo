/* Diagnóstico de la emisión de DTE – Facturacion/frm_DiagnosticoDte.aspx (solo administradores) */
(function ($) {
    'use strict';

    var URL = 'Facturacion/frm_DiagnosticoDte.aspx/';
    var ICONOS = { ok: 'bx-check-circle text-success', aviso: 'bx-error text-warning', error: 'bx-x-circle text-danger' };
    var state = { datos: null };

    function api(metodo, datos) {
        return $.ajax({ type: 'POST', url: URL + metodo, data: JSON.stringify(datos || {}), contentType: 'application/json; charset=utf-8', dataType: 'json' })
            .then(function (r) { return r.d; });
    }
    function falla(xhr) { if (xhr && xhr.statusText !== 'abort') showNotification(1, 'error', 'Error de conexión (HTTP ' + xhr.status + ').'); }
    function esc(s) { return $('<div/>').text(s == null ? '' : String(s)).html(); }
    function fecha(s) { if (!s) return ''; var p = s.split('T'), f = p[0].split('-'); return f[2] + '/' + f[1] + '/' + f[0] + (p[1] ? ' ' + hora12(p[1].substr(0, 5)) : ''); }
    function dinero(n) { return '$ ' + Number(n || 0).toFixed(2); }

    function revisar() {
        $('#dgRevisiones').html('<tr><td colspan="3" class="text-center py-4"><div class="spinner-border spinner-border-sm text-primary"></div> Revisando…</td></tr>');
        api('Revisar').done(function (d) {
            if (!d.Ok) {
                if (/sesi[oó]n/i.test(d.Mensaje || '') && typeof mtd_ValidateSession === 'function') mtd_ValidateSession();
                $('#dgRevisiones').html('<tr><td colspan="3" class="text-danger">' + esc(d.Mensaje) + '</td></tr>');
                return;
            }
            state.datos = d;
            var errores = $.grep(d.Revisiones, function (x) { return x.Estado === 'error'; }).length;
            $('#dgServidor').removeClass('alert-light alert-success alert-danger').addClass(errores ? 'alert-danger' : 'alert-success')
                .html('<strong>' + (errores ? errores + (errores === 1 ? ' problema' : ' problemas') + ' encontrados.' : 'Sin problemas que impidan generar y enviar los DTE.') + '</strong>'
                    + '<div class="small mt-1">Servidor <strong>' + esc(d.Servidor) + '</strong> · el sitio corre como <strong>' + esc(d.Identidad) + '</strong> · revisado el ' + esc(d.Fecha) + '</div>');
            var grupo = '';
            $('#dgRevisiones').html(d.Revisiones.map(function (x) {
                var titulo = x.Grupo !== grupo ? '<tr class="table-light"><td colspan="3" class="small fw-bold text-uppercase text-muted">' + esc(x.Grupo) + '</td></tr>' : '';
                grupo = x.Grupo;
                return titulo + '<tr><td class="text-center"><i class="bx ' + (ICONOS[x.Estado] || '') + ' fs-5"></i></td>'
                    + '<td class="fw-medium">' + esc(x.Nombre) + '</td>'
                    + '<td>' + esc(x.Detalle) + (x.Solucion ? '<div class="small mt-1 ' + (x.Estado === 'error' ? 'text-danger' : 'text-muted') + '"><i class="bx bx-right-arrow-alt"></i> ' + esc(x.Solucion) + '</div>' : '') + '</td></tr>';
            }).join(''));
            if (!$('#dgCorreo').val() && d.CorreoAdministrador) $('#dgCorreo').val(d.CorreoAdministrador);
            pintarPendientes(d.Pendientes || []);
            pintarEventos(d.Eventos || []);
        }).fail(falla);
    }

    function pintarPendientes(lista) {
        $('#dgPendientes').html(lista.length ? lista.map(function (p) {
            var archivos = !!p.RutaPdf, correo = !!p.FechaCorreo;
            return '<tr data-id="' + p.Id_Dte + '" data-correo="' + esc(p.CorreoCliente || '') + '">'
                + '<td class="text-nowrap">' + fecha(p.FechaEmision).substr(0, 10) + ' ' + esc(p.HoraEmision || '') + '</td>'
                + '<td><div class="ad-url">' + esc(p.NumeroControl) + '</div><div class="ad-ayuda">' + dinero(p.TotalPagar) + ' · ' + esc(p.UsuarioCrea) + '</div></td>'
                + '<td>' + esc(p.ReceptorNombre) + '<div class="ad-ayuda">' + esc(p.CorreoCliente || 'sin correo') + '</div></td>'
                + '<td>' + (archivos ? '<span class="ad-chip ad-chip-ok">Guardados</span>' : '<span class="ad-chip ad-chip-no">Faltan</span>') + '</td>'
                + '<td>' + (correo ? '<span class="ad-chip ad-chip-ok">Enviado</span>' : '<span class="ad-chip ad-chip-no">No enviado</span>') + '</td>'
                + '<td class="d-none d-lg-table-cell small text-danger" style="max-width:280px">' + esc(p.UltimoError || '') + '</td>'
                + '<td class="text-end text-nowrap">'
                + '<a class="btn btn-sm btn-outline-secondary" target="_blank" rel="noopener" href="Facturacion/DteArchivo.ashx?c=' + esc(p.CodigoGeneracion) + '&t=pdf" title="Ver PDF"><i class="bx bxs-file-pdf"></i></a> '
                + '<button type="button" class="btn btn-sm btn-outline-primary dg-regenerar" title="Regenerar archivos y enviar al cliente"><i class="bx bx-revision"></i> Regenerar</button>'
                + '</td></tr>';
        }).join('') : '<tr><td colspan="7" class="text-center text-muted py-3">Todos los documentos tienen sus archivos y fueron enviados.</td></tr>');
    }

    function pintarEventos(lista) {
        $('#dgEventos').html(lista.length ? lista.map(function (e) {
            return '<tr><td class="text-nowrap small">' + fecha(e.Fecha) + '</td><td>' + esc(e.Etapa) + '</td><td class="ad-url">' + esc(e.NumeroControl || '') + '</td>'
                + '<td><i class="bx ' + (e.Ok ? 'bx-check-circle text-success' : 'bx-x-circle text-danger') + '"></i> <span class="small">' + esc(e.Mensaje) + '</span></td>'
                + '<td class="d-none d-md-table-cell small text-muted">' + esc(e.Usuario || '') + ' · ' + esc(e.Servidor || '') + '</td></tr>';
        }).join('') : '<tr><td colspan="5" class="text-center text-muted py-3">Aún no hay eventos registrados.</td></tr>');
    }

    function probarCorreo() {
        var correo = $.trim($('#dgCorreo').val()), $b = $('#dgProbar').prop('disabled', true);
        $('#dgResultadoCorreo').html('<span class="spinner-border spinner-border-sm"></span> Enviando…');
        api('ProbarCorreo', { correo: correo }).done(function (r) {
            $('#dgResultadoCorreo').html('<i class="bx ' + (ICONOS[r.Estado] || '') + '"></i> ' + esc(r.Detalle) + (r.Solucion ? '<div class="text-muted">' + esc(r.Solucion) + '</div>' : ''));
            revisar();
        }).fail(falla).always(function () { $b.prop('disabled', false); });
    }

    function regenerar($tr) {
        var correo = $tr.data('correo') || '';
        swal({
            title: 'Regenerar documento', text: correo ? 'Se guardarán de nuevo el PDF y el JSON y se enviarán a ' + correo + '.' : 'Se guardarán de nuevo el PDF y el JSON. El cliente no tiene correo registrado.',
            type: 'info', showCancelButton: true, confirmButtonText: 'Regenerar', cancelButtonText: 'Cancelar', closeOnConfirm: true
        }, function (ok) {
            if (!ok) return;
            api('Regenerar', { id: +$tr.data('id'), correo: correo }).done(function (r) {
                showNotification(1, r.Ok ? 'success' : 'warning', r.Mensaje);
                revisar();
            }).fail(falla);
        });
    }

    $('#dgRevisar').on('click', revisar);
    $('#dgProbar').on('click', probarCorreo);
    $('#dgPendientes').on('click', '.dg-regenerar', function () { regenerar($(this).closest('tr')); });

    if (typeof mtd_ValidateSession === 'function') mtd_ValidateSession();
    revisar();
})(jQuery);
