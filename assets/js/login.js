/* Inicio de sesión (login.aspx) – login.aspx/registraUsuario */
(function ($) {
    'use strict';

    var CLAVE_RECORDAR = 'dpie.login.usuario';
    var enviando = false;

    function leer() { try { return localStorage.getItem(CLAVE_RECORDAR) || ''; } catch (e) { return ''; } }
    function guardar(v) { try { if (v) localStorage.setItem(CLAVE_RECORDAR, v); else localStorage.removeItem(CLAVE_RECORDAR); } catch (e) { } }

    function aviso(tipo, html) {
        $('#lgAviso').removeClass('d-none alert-danger alert-warning alert-info').addClass('alert-' + tipo).html(html);
    }
    function ocultarAviso() { $('#lgAviso').addClass('d-none').empty(); }

    function ocupado(si) {
        enviando = si;
        $('#btnEntrar').prop('disabled', si).find('.spinner-border').toggleClass('d-none', !si);
        $('#btnEntrar .lg-entrar-texto').text(si ? 'Verificando…' : 'Entrar');
    }

    function entrar(ev) {
        if (ev) ev.preventDefault();
        if (enviando) return;
        ocultarAviso();

        var usuario = $.trim($('#inputEmailAddress').val());
        var clave = $('#inputChoosePassword').val();
        if (!usuario) { aviso('warning', 'Ingrese su <strong>usuario</strong>.'); $('#inputEmailAddress').trigger('focus'); return; }
        if (!clave) { aviso('warning', 'Ingrese su <strong>contraseña</strong>.'); $('#inputChoosePassword').trigger('focus'); return; }

        ocupado(true);
        $.ajax({
            type: 'POST',
            url: 'login.aspx/registraUsuario',
            data: JSON.stringify({ usuario: usuario, clave: clave, empresa: '' }),
            contentType: 'application/json; charset=utf-8',
            dataType: 'json'
        }).done(function (r) {
            var partes = String(r.d || '').split('&&'), codigo = partes[0], dato = partes[1] || '';

            if (codigo === 'D' || codigo === 'R') {
                guardar($('#flexSwitchCheckChecked').is(':checked') ? usuario : '');
                $('#btnEntrar .lg-entrar-texto').text(codigo === 'R' ? 'Debe cambiar su contraseña…' : 'Entrando…');
                window.location.replace(dato);
                return;     // se mantiene el botón ocupado mientras navega
            }

            ocupado(false);
            $('#inputChoosePassword').val('').trigger('focus');
            if (codigo === 'C') {
                var quedan = parseInt(dato, 10);
                aviso('danger', 'Usuario o contraseña incorrectos.' +
                    (quedan > 0 && quedan <= 3 ? '<br><small>Le quedan ' + quedan + ' intento(s) antes de un bloqueo temporal.</small>' : '') +
                    (quedan === 0 ? '<br><small>Por seguridad, el acceso quedó bloqueado por 15 minutos.</small>' : ''));
            } else if (codigo === 'B') {
                aviso('warning', 'Demasiados intentos fallidos. Intente de nuevo en <strong>' + dato + ' minuto(s)</strong>.');
            } else if (codigo === 'I') {
                aviso('warning', 'Su usuario está <strong>inactivo</strong>. Comuníquese con el administrador del sistema.');
            } else {
                aviso('danger', dato || 'No fue posible iniciar sesión. Intente de nuevo.');
            }
        }).fail(function (xhr) {
            ocupado(false);
            aviso('danger', 'No hay conexión con el servidor (HTTP ' + xhr.status + '). Intente de nuevo.');
        });
    }

    /* ---------- eventos ---------- */
    $('#lgForm').on('submit', entrar);

    $('#lgVerClave').on('click', function () {
        var $c = $('#inputChoosePassword'), ver = $c.attr('type') === 'password';
        $c.attr('type', ver ? 'text' : 'password');
        $(this).attr('aria-label', ver ? 'Ocultar contraseña' : 'Mostrar contraseña')
            .find('i').toggleClass('bx-hide', !ver).toggleClass('bx-show', ver);
    });

    $('#inputChoosePassword').on('keyup keydown', function (ev) {
        var oe = ev.originalEvent;
        if (oe && oe.getModifierState) $('#lgMayus').toggleClass('d-none', !oe.getModifierState('CapsLock'));
    });

    $('#inputEmailAddress, #inputChoosePassword').on('input', ocultarAviso);

    $('#lgAnio').text(new Date().getFullYear());

    var recordado = leer();
    if (recordado) {
        $('#inputEmailAddress').val(recordado);
        $('#flexSwitchCheckChecked').prop('checked', true);
        $('#inputChoosePassword').trigger('focus');
    } else {
        $('#inputEmailAddress').trigger('focus');
    }

})(jQuery);
