/* Datos de la empresa – Opciones/form_confEmpresa.aspx */
(function ($) {
    'use strict';

    var A = window.Admin, api = A.cliente('Opciones/form_confEmpresa.aspx');
    var state = { empresa: null };

    function opciones(lista, valor) {
        return '<option value="">Seleccione…</option>' + (lista || []).map(function (x) {
            return '<option value="' + x.Id + '"' + (x.Id === valor ? ' selected' : '') + '>' + A.esc(x.Texto) + '</option>';
        }).join('');
    }

    function cargar() {
        $('#emForm :input').prop('disabled', true);
        api('Inicio').done(function (r) {
            if (!r.Ok) { A.error(r); return; }
            state.empresa = r.Empresa || {};
            $('#emDepartamento').html(opciones(r.Departamentos, state.empresa.Departamento));
            $('#emMunicipio').html(opciones(r.Municipios, state.empresa.Municipio));
            llenar(state.empresa);
        }).fail(A.falla).always(function () { $('#emForm :input').prop('disabled', false); });
    }

    function llenar(e) {
        A.limpiarErrores($('#emForm'));
        $('#emNombre').val(e.Nombre || '');
        $('#emPropietario').val(e.Propietario || '');
        $('#emNrc').val(e.Nrc || '');
        $('#emNit').val(e.Nit || '');
        $('#emDui').val(e.Dui || '');
        $('#emTelefono').val(e.Telefono || '');
        $('#emActividad').val(e.Actividad || '');
        $('#emDepartamento').val(e.Departamento ? String(e.Departamento) : '');
        $('#emMunicipio').val(e.Municipio ? String(e.Municipio) : '');
        $('#emDireccion').val(e.Direccion || '');
        $('#emEmail').val(e.Email || '');
        $('#emServidor').val(e.Servidor || '');
        $('#emPuerto').val(e.Puerto || '');
        $('#emClave').val('').attr('placeholder', e.TieneClave ? '•••••••• (guardada)' : 'Sin clave');
        $('#emClaveAyuda').text(e.TieneClave ? 'Déjela vacía para conservar la clave guardada.' : 'Ingrese la clave para poder enviar correos.');
        $('#emModificado').text(e.Fecha ? 'Modificado por ' + e.Usuario + ' el ' + A.fecha(e.Fecha) : '');
    }

    function guardar() {
        A.limpiarErrores($('#emForm'));
        var d = {
            Nombre: $.trim($('#emNombre').val()), Propietario: $.trim($('#emPropietario').val()), Nrc: $.trim($('#emNrc').val()),
            Nit: $.trim($('#emNit').val()), Dui: $.trim($('#emDui').val()), Telefono: $.trim($('#emTelefono').val()),
            Actividad: $.trim($('#emActividad').val()), Departamento: +$('#emDepartamento').val() || 0, Municipio: +$('#emMunicipio').val() || 0,
            Direccion: $.trim($('#emDireccion').val()), Email: $.trim($('#emEmail').val()), Servidor: $.trim($('#emServidor').val()),
            Puerto: parseInt($('#emPuerto').val(), 10) || 0, ClaveEmail: $('#emClave').val()
        };
        if (!d.Nombre) return A.marcarError($('#emNombre'), 'Ingrese el nombre comercial.');
        if (!d.Propietario) return A.marcarError($('#emPropietario'), 'Ingrese el propietario o razón social.');
        if (!d.Nrc) return A.marcarError($('#emNrc'), 'Ingrese el NRC.');
        if (!d.Nit) return A.marcarError($('#emNit'), 'Ingrese el NIT.');
        if (!/^[\d-]+$/.test(d.Nit)) return A.marcarError($('#emNit'), 'Solo números y guiones.');
        if (!d.Departamento) return A.marcarError($('#emDepartamento'), 'Seleccione el departamento.');
        if (!d.Municipio) return A.marcarError($('#emMunicipio'), 'Seleccione el municipio.');
        if (d.Email && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(d.Email)) return A.marcarError($('#emEmail'), 'El correo no es válido.');
        if (d.Puerto && (d.Puerto < 1 || d.Puerto > 65535)) return A.marcarError($('#emPuerto'), 'Entre 1 y 65535.');
        A.ocupado($('#emGuardar'), api('Guardar', { empresa: d }).done(function (r) {
            if (!r.Ok) { A.error(r); return; }
            showNotification(1, 'success', r.Mensaje);
            cargar();
        }).fail(A.falla));
    }

    $('#emDepartamento').on('change', function () {
        var dep = +$(this).val() || 0;
        $('#emMunicipio').html('<option value="">' + (dep ? 'Cargando…' : 'Seleccione…') + '</option>');
        if (!dep) return;
        api('Municipios', { departamento: dep }).done(function (r) {
            if (!r.Ok) { A.error(r); return; }
            $('#emMunicipio').html(opciones(r.Items, 0));
        }).fail(A.falla);
    });
    $('#emVerClave').on('click', function () {
        var $c = $('#emClave'), ver = $c.attr('type') === 'password';
        $c.attr('type', ver ? 'text' : 'password');
        $(this).find('i').attr('class', ver ? 'bx bx-hide' : 'bx bx-show');
    });
    $('#emDeshacer').on('click', function () { if (state.empresa) cargar(); });
    $('#emForm').on('submit', function (ev) { ev.preventDefault(); guardar(); });

    // ?tab=dte | firma abre directamente esa pestaña (enlaces desde Diagnóstico DTE y la antigua página Datos DTE)
    var tab = $('#emTabs').data('tab') || ((/[?&]tab=(\w+)/.exec(location.hash + location.search) || [])[1]);
    var $btn = tab ? $('#emTabs [data-tab="' + tab + '"]') : $();
    if ($btn.length && window.bootstrap) bootstrap.Tab.getOrCreateInstance($btn[0]).show();

    cargar();
})(jQuery);
