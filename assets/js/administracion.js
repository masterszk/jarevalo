/* Utilidades comunes de las páginas de administración (menú Opciones): llamadas a WebMethods, escape de texto,
   confirmaciones, modales y formato de fechas. Expone window.Admin. */
(function ($) {
    'use strict';

    function esc(s) { return $('<div/>').text(s == null ? '' : String(s)).html(); }
    function attr(s) { return esc(s).replace(/"/g, '&quot;'); }
    function dos(n) { return (n < 10 ? '0' : '') + n; }

    /** yyyy-MM-ddTHH:mm:ss → dd/MM/yyyy hh:mm AM/PM (o solo la fecha) */
    function fecha(iso, conHora) {
        if (!iso) return '';
        var p = iso.split('T'), f = p[0].split('-');
        return f[2] + '/' + f[1] + '/' + f[0] + (conHora === false || !p[1] ? '' : ' ' + hora12(p[1].substr(0, 5)));
    }

    function relativa(iso) {
        if (!iso) return 'Nunca';
        var d = new Date(iso.replace('T', ' ').replace(/-/g, '/')), dias = Math.floor((Date.now() - d) / 86400000);
        if (dias <= 0) return 'Hoy ' + horaDe(d);
        if (dias === 1) return 'Ayer';
        if (dias < 30) return 'Hace ' + dias + ' días';
        return fecha(iso, false);
    }

    function normalizar(s) { return String(s || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, ''); }

    /** Cliente de los WebMethods de una página: api('Metodo', datos) → promesa con r.d */
    function cliente(pagina) {
        return function (metodo, datos) {
            return $.ajax({
                type: 'POST',
                url: pagina + '/' + metodo,
                data: JSON.stringify(datos || {}),
                contentType: 'application/json; charset=utf-8',
                dataType: 'json'
            }).then(function (r) { return r.d; });
        };
    }

    function falla(xhr) {
        if (xhr && xhr.statusText === 'abort') return;
        showNotification(1, 'error', 'Error de conexión' + (xhr && xhr.status ? ' (HTTP ' + xhr.status + ')' : '') + '.');
    }

    /** Muestra el error de una respuesta { Ok:false, Mensaje }. Si la sesión expiró, default.aspx lo resuelve. */
    function error(r) {
        var m = (r && r.Mensaje) || 'No fue posible completar la acción.';
        if (/sesi[oó]n/i.test(m) && typeof mtd_ValidateSession === 'function') { mtd_ValidateSession(); return; }
        showNotification(1, 'warning', m);
    }

    function confirmar(titulo, texto, boton, alAceptar) {
        swal({
            title: titulo,
            text: texto,
            type: 'warning',
            showCancelButton: true,
            confirmButtonText: boton || 'Aceptar',
            cancelButtonText: 'Cancelar',
            confirmButtonColor: '#DD6B55',
            closeOnConfirm: true
        }, function (ok) { if (ok) alAceptar(); });
    }

    function modal(id) { return bootstrap.Modal.getOrCreateInstance(document.getElementById(id)); }

    /** Pone el botón en espera mientras dura la promesa. */
    function ocupado($b, promesa, texto) {
        var html = $b.html();
        $b.prop('disabled', true).html('<span class="spinner-border spinner-border-sm"></span> ' + (texto || 'Guardando…'));
        return promesa.always(function () { $b.prop('disabled', false).html(html); });
    }

    function marcarError($campo, texto) {
        $campo.addClass('is-invalid');
        var $f = $campo.siblings('.invalid-feedback');
        if (!$f.length) $f = $('<div class="invalid-feedback"></div>').insertAfter($campo);
        $f.text(texto);
        $campo.trigger('focus');
    }
    function limpiarErrores($form) { $form.find('.is-invalid').removeClass('is-invalid'); }

    function cargando(columnas) {
        return '<tr><td colspan="' + columnas + '" class="text-center py-4"><div class="spinner-border spinner-border-sm text-primary" role="status"></div> Cargando…</td></tr>';
    }
    function vacio(columnas, texto) {
        return '<tr><td colspan="' + columnas + '" class="text-center text-muted py-4">' + texto + '</td></tr>';
    }

    window.Admin = {
        esc: esc, attr: attr, fecha: fecha, relativa: relativa, normalizar: normalizar,
        cliente: cliente, falla: falla, error: error, confirmar: confirmar, modal: modal, ocupado: ocupado,
        marcarError: marcarError, limpiarErrores: limpiarErrores, cargando: cargando, vacio: vacio
    };

    if (typeof mtd_ValidateSession === 'function') mtd_ValidateSession();
})(jQuery);
