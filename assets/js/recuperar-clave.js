/* Recuperar contraseña (recuperarClave.aspx): usuario -> código de 6 dígitos (al correo registrado en el usuario) -> nueva contraseña */
(function ($) {
    'use strict';

    var URL = 'recuperarClave.aspx/', email = '', espera = null;

    function api(metodo, datos) {
        return $.ajax({ type: 'POST', url: URL + metodo, data: JSON.stringify(datos || {}), contentType: 'application/json; charset=utf-8', dataType: 'json' })
            .then(function (r) { return r.d; });
    }

    function aviso(tipo, texto) {
        $('#rcAviso').removeClass('d-none alert-danger alert-success alert-info alert-warning').addClass('alert-' + tipo).text(texto);
    }
    function ocultarAviso() { $('#rcAviso').addClass('d-none').empty(); }

    function ocupado($b, si) {
        $b.prop('disabled', si).find('.spinner-border').toggleClass('d-none', !si);
    }

    function paso(n) {
        $('.rc-paso').addClass('d-none');
        $(n === 4 ? '#rcListo' : '#rcPaso' + n).removeClass('d-none');
        $('.rc-pasos li').each(function () {
            var p = +$(this).data('paso');
            $(this).toggleClass('activo', p === n).toggleClass('hecho', p < n || n === 4);
        });
        $('#rcVolver').toggleClass('d-none', n === 4);
        var foco = { 1: '#rcEmail', 2: '#rcCodigo', 3: '#rcClave' }[n];
        if (foco) setTimeout(function () { $(foco).trigger('focus'); }, 50);
    }

    function falla() { aviso('danger', 'No fue posible conectar con el servidor. Revise su conexión e intente de nuevo.'); }

    // Evita reenviar el código varias veces seguidas
    function bloquearReenvio(seg) {
        var $a = $('#rcReenviar'); clearInterval(espera);
        function pintar() { $a.addClass('disabled').attr('aria-disabled', 'true').text('Reenviar código (' + seg + ' s)'); }
        pintar();
        espera = setInterval(function () {
            if (--seg <= 0) { clearInterval(espera); $a.removeClass('disabled').removeAttr('aria-disabled').text('Reenviar código'); return; }
            pintar();
        }, 1000);
    }

    function solicitar($boton, reenvio) {
        ocultarAviso(); ocupado($boton, true);
        return api('Solicitar', { usuario: email }).done(function (r) {
            if (!r.Ok) { aviso('danger', r.Mensaje); if (r.Reiniciar && reenvio) paso(1); return; }
            $('#rcEnviadoA').text(r.Mensaje);
            aviso(reenvio ? 'success' : 'info', reenvio ? 'Le enviamos un código nuevo al mismo correo.' : 'Revise su correo.');
            $('#rcCodigo').val('');
            bloquearReenvio(60);
            paso(2);
        }).fail(falla).always(function () { ocupado($boton, false); });
    }

    $('#rcPaso1').on('submit', function (ev) {
        ev.preventDefault();
        email = $.trim($('#rcEmail').val());      // ahora es el usuario (el nombre de la variable se mantiene)
        if (!/^[A-Za-z0-9._]{1,20}$/.test(email)) { aviso('warning', 'Escriba su usuario, el mismo con el que inicia sesión.'); $('#rcEmail').trigger('focus'); return; }
        solicitar($('#rcEnviar'), false);
    });

    $('#rcReenviar').on('click', function () {
        if ($(this).hasClass('disabled')) return;
        solicitar($(this), true);
    });

    $('#rcOtroCorreo').on('click', function () { ocultarAviso(); clearInterval(espera); paso(1); });

    $('#rcCodigo').on('input', function () {
        var v = this.value.replace(/\D/g, '').slice(0, 6);
        if (v !== this.value) this.value = v;
        if (v.length === 6) $('#rcPaso2').trigger('submit');
    });

    $('#rcPaso2').on('submit', function (ev) {
        ev.preventDefault();
        var codigo = $('#rcCodigo').val(), $b = $('#rcValidar');
        if (!/^\d{6}$/.test(codigo)) { aviso('warning', 'El código tiene 6 dígitos.'); return; }
        if ($b.prop('disabled')) return;
        ocultarAviso(); ocupado($b, true);
        api('Validar', { codigo: codigo }).done(function (r) {
            if (!r.Ok) {
                aviso('danger', r.Mensaje);
                $('#rcCodigo').val('');
                if (r.Reiniciar) { clearInterval(espera); paso(1); } else $('#rcCodigo').trigger('focus');
                return;
            }
            aviso('success', r.Mensaje);
            $('#rcUsuarioOculto').val(email);
            paso(3);
        }).fail(falla).always(function () { ocupado($b, false); });
    });

    function reglas() {
        var v = $('#rcClave').val();
        var ok = { largo: v.length >= 8, letra: /[A-Za-zÁÉÍÓÚáéíóúÑñ]/.test(v), numero: /\d/.test(v) };
        $('#rcReglas li').each(function () { $(this).toggleClass('ok', !!ok[$(this).data('regla')]); });
        return ok.largo && ok.letra && ok.numero;
    }
    $('#rcClave').on('input', reglas);

    // Ojo de cada campo: muestra u oculta solo esa contraseña
    function verClave($b, ver) {
        var c = document.getElementById($b.data('campo'));
        c.type = ver ? 'text' : 'password';
        $b.attr({ 'aria-label': ver ? 'Ocultar contraseña' : 'Mostrar contraseña', title: ver ? 'Ocultar contraseña' : 'Mostrar contraseña', 'aria-pressed': ver })
            .find('i').attr('class', ver ? 'bx bx-show' : 'bx bx-hide');
    }
    $('.rc-ver').on('mousedown', function (ev) { ev.preventDefault(); })      // no quita el foco del campo
        .on('click', function () {
            var $b = $(this);
            verClave($b, document.getElementById($b.data('campo')).type === 'password');
        });

    $('#rcPaso3').on('submit', function (ev) {
        ev.preventDefault();
        var clave = $('#rcClave').val(), conf = $('#rcConfirmar').val(), $b = $('#rcCambiar');
        if (!reglas()) { aviso('warning', 'La contraseña debe tener al menos 8 caracteres, con letras y números.'); $('#rcClave').trigger('focus'); return; }
        if (clave !== conf) { aviso('warning', 'Las contraseñas no coinciden.'); $('#rcConfirmar').trigger('focus'); return; }
        ocultarAviso(); ocupado($b, true);
        api('Cambiar', { clave: clave, confirmacion: conf }).done(function (r) {
            if (!r.Ok) { aviso('danger', r.Mensaje); if (r.Reiniciar) paso(1); return; }
            $('#rcClave, #rcConfirmar').val('');
            $('.rc-ver').each(function () { verClave($(this), false); });
            paso(4);
        }).fail(falla).always(function () { ocupado($b, false); });
    });

    $('#rcAnio').text(new Date().getFullYear());
    paso(1);
})(jQuery);
