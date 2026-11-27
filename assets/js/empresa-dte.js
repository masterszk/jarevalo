/* Datos del emisor de los DTE – pestaña Facturación electrónica de Opciones/form_confEmpresa.aspx (logo: Facturacion/LogoEmpresa.ashx) */
(function ($) {
    'use strict';

    var URL = 'Opciones/form_confEmpresa.aspx/';
    var URL_LOGO = 'Facturacion/LogoEmpresa.ashx';
    var cat = window.DteCatalogos;
    var tieneClave = false;

    function usuario() { return $.trim($('#idUser').val() || ''); }   // usuario de la sesión (campo oculto de default.aspx)
    function api(metodo, datos) {
        return $.ajax({
            type: 'POST',
            url: URL + metodo,
            data: JSON.stringify(datos || {}),
            contentType: 'application/json; charset=utf-8',
            dataType: 'json'
        }).then(function (r) { return r.d; });
    }
    function falla(xhr) { showNotification(1, 'error', 'Error de conexión (HTTP ' + xhr.status + ').'); }
    function soloDigitos(s) { return String(s || '').replace(/[^0-9]/g, ''); }
    function esCorreo(s) { return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(s); }

    function llenarMunicipios(depto, muni) {
        var $m = $('#empMunicipio').empty().append($('<option>').val('').text('Seleccione…'));
        $.each(cat.departamentos, function (_, d) {
            if (d[0] !== depto) return;
            $.each(d[2], function (_, m) { $m.append($('<option>').val(m[0]).text(m[1])); });
        });
        $m.val(muni || '');
    }

    // DTE 2.0: distritos (antiguos municipios) del municipio seleccionado
    function llenarDistritos(depto, muni, distrito) {
        var $d = $('#empDistrito').empty().append($('<option>').val('').text('Seleccione…'));
        $.each(cat.distritosDe(depto, muni), function (_, x) { $d.append($('<option>').val(x[0]).text(x[1])); });
        $d.val(distrito || '');
    }

    function pintarClave() {
        $('#lblClave').text(tieneClave ? 'Hay una clave guardada. Déjela en blanco para conservarla.' : 'No hay clave guardada.');
        $('#empSmtpClave').val('');
    }

    function pintarLogo(tiene, version) {
        $('#imgLogo').toggleClass('d-none', !tiene).attr('src', tiene ? URL_LOGO + '?v=' + encodeURIComponent(version || Date.now()) : '');
        $('#sinLogo').toggleClass('d-none', tiene);
        $('#btnQuitarLogo').prop('disabled', !tiene);
    }

    function pintar(e) {
        $('#empNombre').val(e.Nombre);
        $('#empComercial').val(e.NombreComercial);
        $('#empNit').val(e.Nit);
        $('#empNrc').val(e.Nrc);
        $('#empTelefono').val(e.Telefono);
        $('#empCodActividad').val(e.CodActividad);
        $('#empDescActividad').val(e.DescActividad);
        $('#empCorreo').val(e.Correo);
        $('#empDepto').val(e.CodDepartamento);
        llenarMunicipios(e.CodDepartamento, e.CodMunicipio);
        llenarDistritos(e.CodDepartamento, e.CodMunicipio, e.CodDistrito);
        $('#empVersionFE').val(String(e.VersionFE || 2));
        $('#empVersionCCF').val(String(e.VersionCCF || 4));
        $('#empComplemento').val(e.Complemento);
        $('#empTipoEst').val(e.TipoEstablecimiento);
        $('#empCodEstable').val(e.CodEstable);
        $('#empCodPuntoVenta').val(e.CodPuntoVenta);
        $('#empAmbiente').val(e.Ambiente);
        $('#empCodEstableMH').val(e.CodEstableMH);
        $('#empCodPuntoVentaMH').val(e.CodPuntoVentaMH);
        $('#empEnviarCorreo').prop('checked', e.EnviarCorreo);
        $('#empSmtpServidor').val(e.SmtpServidor);
        $('#empSmtpPuerto').val(e.SmtpPuerto || '');
        $('#empSmtpUsuario').val(e.SmtpUsuario);
        tieneClave = e.TieneClave;
        pintarClave();
        pintarLogo(e.TieneLogo, e.Version);
    }

    function leer() {
        return {
            Nombre: $.trim($('#empNombre').val()),
            NombreComercial: $.trim($('#empComercial').val()),
            Nit: soloDigitos($('#empNit').val()),
            Nrc: soloDigitos($('#empNrc').val()),
            Telefono: $.trim($('#empTelefono').val()),
            CodActividad: soloDigitos($('#empCodActividad').val()),
            DescActividad: $.trim($('#empDescActividad').val()),
            Correo: $.trim($('#empCorreo').val()),
            CodDepartamento: $('#empDepto').val() || '',
            CodMunicipio: $('#empMunicipio').val() || '',
            CodDistrito: $('#empDistrito').val() || '',
            VersionFE: parseInt($('#empVersionFE').val(), 10) || 0,
            VersionCCF: parseInt($('#empVersionCCF').val(), 10) || 0,
            Complemento: $.trim($('#empComplemento').val()),
            TipoEstablecimiento: $('#empTipoEst').val() || '',
            CodEstable: $.trim($('#empCodEstable').val()).toUpperCase(),
            CodPuntoVenta: $.trim($('#empCodPuntoVenta').val()).toUpperCase(),
            Ambiente: $('#empAmbiente').val(),
            CodEstableMH: $.trim($('#empCodEstableMH').val()).toUpperCase(),
            CodPuntoVentaMH: $.trim($('#empCodPuntoVentaMH').val()).toUpperCase(),
            EnviarCorreo: $('#empEnviarCorreo').is(':checked'),
            SmtpServidor: $.trim($('#empSmtpServidor').val()),
            SmtpPuerto: parseInt($('#empSmtpPuerto').val(), 10) || 0,
            SmtpUsuario: $.trim($('#empSmtpUsuario').val()),
            SmtpClave: $('#empSmtpClave').val(),
            Usuario: usuario()
        };
    }

    // Validación rápida en el navegador; el servidor vuelve a validar todo
    function validar(e) {
        var campos = [
            [!e.Nombre, '#empNombre', 'Ingrese el nombre o razón social.'],
            [e.Nit.length !== 14 && e.Nit.length !== 9, '#empNit', 'El NIT debe tener 14 o 9 dígitos.'],
            [!e.Nrc || e.Nrc.length > 8, '#empNrc', 'El NRC debe tener de 1 a 8 dígitos.'],
            [soloDigitos(e.Telefono).length < 8, '#empTelefono', 'Ingrese un teléfono válido.'],
            [e.CodActividad.length < 2, '#empCodActividad', 'Ingrese el código de actividad económica.'],
            [!e.DescActividad, '#empDescActividad', 'Ingrese la actividad económica.'],
            [!esCorreo(e.Correo), '#empCorreo', 'Ingrese un correo válido para la empresa.'],
            [!e.CodDepartamento, '#empDepto', 'Seleccione el departamento.'],
            [!e.CodMunicipio, '#empMunicipio', 'Seleccione el municipio.'],
            [!e.CodDistrito, '#empDistrito', 'Seleccione el distrito (DTE 2.0).'],
            [!e.Complemento, '#empComplemento', 'Ingrese la dirección.'],
            [!/^[A-Z0-9]{4}$/.test(e.CodEstable), '#empCodEstable', 'El código de establecimiento debe tener 4 caracteres.'],
            [!/^[A-Z0-9]{4}$/.test(e.CodPuntoVenta), '#empCodPuntoVenta', 'El código de punto de venta debe tener 4 caracteres.'],
            [e.SmtpUsuario && !esCorreo(e.SmtpUsuario), '#empSmtpUsuario', 'El usuario del correo debe ser una dirección válida.'],
            [e.EnviarCorreo && (!e.SmtpServidor || !e.SmtpPuerto || !e.SmtpUsuario), '#empSmtpServidor', 'Para enviar correos ingrese servidor, puerto y usuario.'],
            [e.EnviarCorreo && !tieneClave && !e.SmtpClave, '#empSmtpClave', 'Ingrese la clave del correo.']
        ];
        for (var i = 0; i < campos.length; i++)
            if (campos[i][0]) { $(campos[i][1]).trigger('focus'); return campos[i][2]; }
        return null;
    }

    function cargar() {
        api('ObtenerEmpresa', { user: usuario() }).done(function (r) {
            if (!r.Ok) { showNotification(1, 'error', r.Mensaje); return; }
            if (r.Empresa) pintar(r.Empresa);
            else { pintarClave(); pintarLogo(false); }
        }).fail(falla);
    }

    function guardar(ev) {
        ev.preventDefault();
        var e = leer(), error = validar(e);
        if (error) { showNotification(1, 'warning', error); return; }
        if (e.Ambiente === '01' && !confirm('El ambiente de PRODUCCIÓN emite documentos con validez tributaria. ¿Continuar?')) return;

        var $btn = $('#btnGuardarEmpresa').prop('disabled', true).html('<span class="spinner-border spinner-border-sm"></span> Guardando…');
        api('GuardarEmpresa', { empresa: e }).done(function (r) {
            if (!r.Ok) { showNotification(1, 'error', r.Mensaje); return; }
            showNotification(1, 'success', r.Mensaje);
            if (r.Empresa) pintar(r.Empresa);
        }).fail(falla).always(function () {
            $btn.prop('disabled', false).html('<i class="bx bx-check"></i> Guardar');
        });
    }

    function enviarLogo(fd, $btn, html) {
        fd.append('user', usuario());
        $btn.prop('disabled', true);
        $.ajax({ type: 'POST', url: URL_LOGO, data: fd, processData: false, contentType: false, dataType: 'json' })
            .done(function (r) {
                if (!r.Ok) { showNotification(1, 'error', r.Mensaje); return; }
                showNotification(1, 'success', r.Mensaje);
                $('#fileLogo').val('');
                pintarLogo(!fd.has('quitar'));
            })
            .fail(function (xhr) {
                var r = xhr.responseJSON;
                if (r && r.Mensaje) showNotification(1, 'error', r.Mensaje); else falla(xhr);
            })
            .always(function () {
                $btn.html(html);
                $('#btnSubirLogo').prop('disabled', false);
                $('#btnQuitarLogo').prop('disabled', $('#imgLogo').hasClass('d-none'));
            });
    }

    function subirLogo() {
        var f = $('#fileLogo')[0].files[0];
        if (!f) { showNotification(1, 'warning', 'Seleccione una imagen.'); return; }
        if (!/^image\/(png|jpeg)$/.test(f.type)) { showNotification(1, 'warning', 'El logo debe ser PNG o JPG.'); return; }
        if (f.size > 2 * 1024 * 1024) { showNotification(1, 'warning', 'La imagen no debe superar 2 MB.'); return; }
        var fd = new FormData();
        fd.append('logo', f);
        var $btn = $('#btnSubirLogo');
        $btn.html('<span class="spinner-border spinner-border-sm"></span> Subiendo…');
        enviarLogo(fd, $btn, '<i class="bx bx-upload"></i> Subir logo');
    }

    function quitarLogo() {
        if (!confirm('¿Quitar el logo? Los próximos DTE se generarán sin logo.')) return;
        var fd = new FormData();
        fd.append('quitar', '1');
        enviarLogo(fd, $('#btnQuitarLogo'), '<i class="bx bx-trash"></i>');
    }

    $(function () {
        if (!$('#empresaDte').length) return;
        mtd_ValidateSession();

        var $d = $('#empDepto').append($('<option>').val('').text('Seleccione…'));
        $.each(cat.departamentos, function (_, d) { $d.append($('<option>').val(d[0]).text(d[1])); });
        llenarMunicipios('', '');
        var $t = $('#empTipoEst');
        $.each(cat.tiposEstablecimiento, function (_, t) { $t.append($('<option>').val(t[0]).text(t[0] + ' · ' + t[1])); });

        $('#empDepto').on('change', function () { llenarMunicipios(this.value, ''); llenarDistritos(this.value, '', ''); });
        $('#empMunicipio').on('change', function () { llenarDistritos($('#empDepto').val(), this.value, ''); });
        llenarDistritos('', '', '');
        $('#frmEmpresa').on('submit', guardar);
        $('#btnSubirLogo').on('click', subirLogo);
        $('#btnQuitarLogo').on('click', quitarLogo);
        $('#fileLogo').on('change', function () {   // vista previa local antes de subir
            var f = this.files[0];
            if (f && /^image\/(png|jpeg)$/.test(f.type)) {
                $('#imgLogo').removeClass('d-none').attr('src', window.URL.createObjectURL(f));
                $('#sinLogo').addClass('d-none');
            }
        });

        cargar();
    });

})(jQuery);
