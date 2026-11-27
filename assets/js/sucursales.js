/* Opciones > Sucursales (Opciones/frm_Sucursales.aspx) */
(function ($) {
    'use strict';

    var URL = 'Opciones/frm_Sucursales.aspx/', cat = window.DteCatalogos;
    var state = { items: [], editando: null };

    function api(metodo, datos) {
        return $.ajax({ type: 'POST', url: URL + metodo, data: JSON.stringify(datos || {}), contentType: 'application/json; charset=utf-8', dataType: 'json' })
            .then(function (r) { return r.d; });
    }
    function falla(xhr) { showNotification(1, 'error', 'Error de conexión (HTTP ' + xhr.status + ').'); }
    function esc(s) { return $('<div>').text(s == null ? '' : String(s)).html(); }
    function modal() { return bootstrap.Modal.getOrCreateInstance(document.getElementById('suModal')); }

    /* ---------- lista ---------- */
    function cargar() {
        api('Lista').done(function (r) {
            if (!r.Ok) { showNotification(1, 'error', r.Mensaje); return; }
            state.items = r.Items || [];
            pintar();
        }).fail(falla);
    }

    function pintar() {
        if (!state.items.length) { $('#suFilas').html('<tr><td colspan="8" class="text-center text-muted py-4">No hay sucursales.</td></tr>'); return; }
        $('#suFilas').html(state.items.map(function (s) {
            return '<tr data-id="' + s.Id + '">'
                + '<td><div class="fw-semibold">' + esc(s.Nombre) + (s.EsMatriz ? ' <span class="badge bg-primary-subtle text-primary border border-primary-subtle">Casa Matriz</span>' : '') + '</div>'
                + '<div class="small text-muted">' + esc(s.Codigo) + (s.Direccion ? ' · ' + esc(s.Direccion) : '') + '</div></td>'
                + '<td><code>' + esc(s.CodEstable + s.CodPuntoVenta) + '</code>' + (s.CodEstableMH ? '<div class="small text-muted">MH ' + esc(s.CodEstableMH + (s.CodPuntoVentaMH || '')) + '</div>' : '') + '</td>'
                + '<td class="text-center">' + s.Usuarios + '</td><td class="text-center">' + s.Especialistas + '</td><td class="text-center">' + s.Citas + '</td>'
                + '<td>' + (s.Activo ? '<span class="badge bg-success-subtle text-success">Activa</span>' : '<span class="badge bg-secondary-subtle text-secondary">Inactiva</span>') + '</td>'
                + '<td class="small text-muted">' + esc(s.Usuario) + ' · ' + esc(s.Fecha) + '</td>'
                + '<td class="text-end text-nowrap"><button type="button" class="btn btn-sm btn-outline-primary su-editar" title="Editar"><i class="bx bx-edit-alt"></i></button> '
                + (s.EsMatriz ? '' : '<button type="button" class="btn btn-sm btn-outline-' + (s.Activo ? 'warning' : 'success') + ' su-estado" title="' + (s.Activo ? 'Inactivar' : 'Activar') + '"><i class="bx ' + (s.Activo ? 'bx-hide' : 'bx-show') + '"></i></button>')
                + '</td></tr>';
        }).join(''));
    }

    /* ---------- ubicación ---------- */
    function llenarDeptos(depto) {
        var $d = $('#suDepto').empty().append($('<option>').val('').text('Seleccione…'));
        $.each(cat.departamentos, function (_, d) { $d.append($('<option>').val(d[0]).text(d[1])); });
        $d.val(depto || '');
    }
    function llenarMunicipios(depto, muni) {
        var $m = $('#suMunicipio').empty().append($('<option>').val('').text('Seleccione…'));
        $.each(cat.departamentos, function (_, d) { if (d[0] === depto) $.each(d[2], function (_, m) { $m.append($('<option>').val(m[0]).text(m[1])); }); });
        $m.val(muni || '');
    }
    function llenarDistritos(depto, muni, distrito) {
        var $d = $('#suDistrito').empty().append($('<option>').val('').text('Seleccione…'));
        if (depto && muni) $.each(cat.distritosDe(depto, muni), function (_, x) { $d.append($('<option>').val(x[0]).text(x[1])); });
        $d.val(distrito || '');
    }

    /* ---------- formulario ---------- */
    function abrir(s) {
        state.editando = s;
        $('#suForm .is-invalid').removeClass('is-invalid');
        $('#suModalTitulo').text(s ? 'Editar sucursal' : 'Nueva sucursal');
        $('#suCodigo').val(s ? s.Codigo : ''); $('#suNombre').val(s ? s.Nombre : ''); $('#suTelefono').val(s ? s.Telefono : '');
        $('#suDireccion').val(s ? s.Direccion : '');
        llenarDeptos(s ? s.CodDepartamento : ''); llenarMunicipios(s ? s.CodDepartamento : '', s ? s.CodMunicipio : '');
        llenarDistritos(s ? s.CodDepartamento : '', s ? s.CodMunicipio : '', s ? s.CodDistrito : '');
        $('#suEstable').val(s ? s.CodEstable : ''); $('#suPunto').val(s ? s.CodPuntoVenta : 'P001');
        $('#suEstableMH').val(s ? s.CodEstableMH : ''); $('#suPuntoMH').val(s ? s.CodPuntoVentaMH : '');
        $('#suActivo').prop('checked', s ? s.Activo : true).prop('disabled', !!(s && s.EsMatriz));
        // La Casa Matriz emite con los códigos de Opciones > Empresa > Facturación electrónica
        var matriz = !!(s && s.EsMatriz);
        $('#suEstable, #suPunto, #suEstableMH, #suPuntoMH').prop('readonly', matriz);
        $('#suNotaMatriz').toggleClass('d-none', !matriz);
        $('#suEspecialistas').html('<div class="col text-muted small">Cargando…</div>');
        api('Especialistas', { sucursal: s ? s.Id : 0 }).done(function (r) {
            if (!r.Ok) { $('#suEspecialistas').html('<div class="col text-danger small">' + esc(r.Mensaje) + '</div>'); return; }
            $('#suEspecialistas').html((r.Items || []).map(function (e) {
                var id = 'suEsp' + e.Id;
                return '<div class="col"><div class="form-check"><input class="form-check-input su-esp" type="checkbox" id="' + id + '" value="' + e.Id + '"' + (e.Asignado ? ' checked' : '') + ' />'
                    + '<label class="form-check-label" for="' + id + '">' + esc(e.Nombre) + (e.Activo ? '' : ' <span class="text-muted small">(inactivo)</span>') + '</label></div></div>';
            }).join('') || '<div class="col text-muted small">No hay especialistas.</div>');
        }).fail(falla);
        modal().show();
    }

    function marcar(sel, texto) { $(sel).addClass('is-invalid').trigger('focus'); showNotification(1, 'warning', texto); return false; }

    function guardar() {
        var s = state.editando || {};
        var d = {
            Id: s.Id || 0, Codigo: $.trim($('#suCodigo').val()).toUpperCase(), Nombre: $.trim($('#suNombre').val()),
            Telefono: $.trim($('#suTelefono').val()), Direccion: $.trim($('#suDireccion').val()),
            CodDepartamento: $('#suDepto').val() || null, CodMunicipio: $('#suMunicipio').val() || null, CodDistrito: $('#suDistrito').val() || null,
            CodEstable: $.trim($('#suEstable').val()).toUpperCase(), CodPuntoVenta: $.trim($('#suPunto').val()).toUpperCase(),
            CodEstableMH: $.trim($('#suEstableMH').val()).toUpperCase() || null, CodPuntoVentaMH: $.trim($('#suPuntoMH').val()).toUpperCase() || null,
            Activo: $('#suActivo').is(':checked')
        };
        if (!d.Codigo) return marcar('#suCodigo', 'Ingrese el código.');
        if (!d.Nombre) return marcar('#suNombre', 'Ingrese el nombre.');
        if (!/^[A-Z0-9]{4}$/.test(d.CodEstable)) return marcar('#suEstable', 'El establecimiento debe tener 4 caracteres (ej. S001).');
        if (!/^[A-Z0-9]{4}$/.test(d.CodPuntoVenta)) return marcar('#suPunto', 'El punto de venta debe tener 4 caracteres (ej. P001).');
        var esp = $('#suEspecialistas .su-esp:checked').map(function () { return +this.value; }).get();
        var $b = $('#suGuardar').prop('disabled', true);
        api('Guardar', { sucursal: d, especialistas: esp }).done(function (r) {
            if (!r.Ok) { showNotification(1, 'warning', r.Mensaje); return; }
            showNotification(1, 'success', r.Mensaje);
            modal().hide();
            cargar();
        }).fail(falla).always(function () { $b.prop('disabled', false); });
    }

    /* ---------- eventos ---------- */
    $('#suNuevo').on('click', function () { abrir(null); });
    $('#suFilas').on('click', '.su-editar', function () {
        var id = +$(this).closest('tr').data('id');
        abrir($.grep(state.items, function (x) { return x.Id === id; })[0]);
    }).on('click', '.su-estado', function () {
        var id = +$(this).closest('tr').data('id'), s = $.grep(state.items, function (x) { return x.Id === id; })[0];
        api('Estado', { id: id, activo: !s.Activo }).done(function (r) {
            showNotification(1, r.Ok ? 'success' : 'warning', r.Mensaje);
            if (r.Ok) cargar();
        }).fail(falla);
    });
    $('#suDepto').on('change', function () { llenarMunicipios(this.value, ''); llenarDistritos('', '', ''); });
    $('#suMunicipio').on('change', function () { llenarDistritos($('#suDepto').val(), this.value, ''); });
    $('#suForm').on('submit', function (ev) { ev.preventDefault(); guardar(); });
    $('#suForm').on('input change', 'input, select', function () { $(this).removeClass('is-invalid'); });

    cargar();
})(jQuery);
