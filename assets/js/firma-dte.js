/* Generador de firma de Hacienda (svfe-api-firmador) – pestaña Firma electrónica de Opciones/form_confEmpresa.aspx */
(function ($) {
    'use strict';

    var A = window.Admin, api = A.cliente('Opciones/form_confEmpresa.aspx');
    var cargado = false;

    function soloDigitos(s) { return String(s || '').replace(/[^0-9]/g, ''); }

    function pintarResultado(f) {
        var $u = $('#fiUltima');
        if (!f.UltimaPrueba) { $u.attr('class', 'alert alert-light border small mt-3 mb-0').html('<i class="bx bx-info-circle"></i> Aún no se ha probado el firmador.'); return; }
        var ok = /^OK/.test(f.Resultado || '');
        $u.attr('class', 'alert small mt-3 mb-0 ' + (ok ? 'alert-success' : 'alert-danger'))
            .html('<i class="bx ' + (ok ? 'bx-check-circle' : 'bx-error-circle') + '"></i> Última prueba ' + A.esc(f.UltimaPrueba) + ': ' + A.esc(f.Resultado || ''));
    }

    function pintar(f) {
        A.limpiarErrores($('#frmFirmador'));
        $('#fiUrl').val(f.Url || '');
        $('#fiNit').val(f.Nit || '');
        $('#fiNitAyuda').text('Sin guiones.' + (f.NitEmisor ? ' NIT del emisor: ' + f.NitEmisor + '.' : ''));
        $('#fiClave').val('').attr('placeholder', f.TieneClave ? '•••••••• (guardada)' : 'Sin contraseña');
        $('#fiClaveAyuda').text(f.TieneClave ? 'Déjela vacía para conservar la contraseña guardada.' : 'Es la contraseña de la llave privada definida al generar el certificado.');
        pintarResultado(f);
    }

    function cargar() {
        $('#frmFirmador :input').prop('disabled', true);
        api('Firmador').done(function (r) {
            if (!r.Ok) { A.error(r); return; }
            cargado = true;
            pintar(r);
            if (r.Mensaje) showNotification(1, 'info', r.Mensaje);
        }).fail(A.falla).always(function () { $('#frmFirmador :input').prop('disabled', false); });
    }

    function datos() {
        A.limpiarErrores($('#frmFirmador'));
        var d = { Url: $.trim($('#fiUrl').val()), Nit: soloDigitos($('#fiNit').val()), Clave: $('#fiClave').val() };
        if (!d.Url) { A.marcarError($('#fiUrl'), 'Ingrese la dirección del firmador.'); return null; }
        if (!/^https?:\/\/.+/i.test(d.Url)) { A.marcarError($('#fiUrl'), 'Debe empezar con http:// o https://.'); return null; }
        if (d.Nit.length !== 14 && d.Nit.length !== 9) { A.marcarError($('#fiNit'), '14 dígitos (o 9 si es DUI), sin guiones.'); return null; }
        return d;
    }

    function guardar() {
        var d = datos();
        if (!d) return;
        A.ocupado($('#fiGuardar'), api('GuardarFirmador', { firmador: d }).done(function (r) {
            if (!r.Ok) { A.error(r); return; }
            showNotification(1, 'success', r.Mensaje);
            pintar(r);
        }).fail(A.falla));
    }

    function probar() {
        A.ocupado($('#fiProbar'), api('ProbarFirmador').done(function (r) {
            if (r.Url === undefined && !r.Ok) { A.error(r); return; }
            showNotification(1, r.Ok ? 'success' : 'error', r.Mensaje);
            pintar(r);
        }).fail(A.falla));
    }

    $('#fiVerClave').on('click', function () {
        var $c = $('#fiClave'), ver = $c.attr('type') === 'password';
        $c.attr('type', ver ? 'text' : 'password');
        $(this).find('i').attr('class', ver ? 'bx bx-hide' : 'bx bx-show');
    });
    $('#frmFirmador').on('submit', function (ev) { ev.preventDefault(); guardar(); });
    $('#fiProbar').on('click', probar);

    // Se carga al abrir la pestaña (o de inmediato si la página abrió en ella)
    $('[data-bs-target="#emTabFirma"]').on('shown.bs.tab', function () { if (!cargado) cargar(); });
    if ($('#emTabFirma').hasClass('active')) cargar();
})(jQuery);
