/* Módulos y opciones del menú – Opciones/form_confModulos.aspx */
(function ($) {
    'use strict';

    var A = window.Admin, api = A.cliente('Opciones/form_confModulos.aspx');
    var state = { modulos: [], opciones: [], actual: +($('#modulos').data('mod') || 0), modulo: null, opcion: null };

    /* ---------- módulos ---------- */
    function cargarModulos() {
        $('#mdLista').html('<div class="text-center py-4"><div class="spinner-border spinner-border-sm text-primary"></div></div>');
        return api('Modulos').done(function (r) {
            if (!r.Ok) { A.error(r); return; }
            state.modulos = r.Items || [];
            if (!state.modulos.some(function (m) { return m.Id === state.actual; })) state.actual = state.modulos.length ? state.modulos[0].Id : 0;
            pintarModulos();
            cargarOpciones();
        }).fail(A.falla);
    }

    function pintarModulos() {
        $('#mdTotal').text('(' + state.modulos.length + ')');
        if (!state.modulos.length) { $('#mdLista').html('<div class="text-center text-muted py-4">No hay módulos.</div>'); return; }
        $('#mdLista').html(state.modulos.map(function (m) {
            return '<div class="list-group-item ad-modulo' + (m.Id === state.actual ? ' active' : '') + '" data-id="' + m.Id + '" tabindex="0" role="button">'
                + '<span class="ad-icono"><i class="' + A.attr(m.Icono) + '"></i></span>'
                + '<div class="ad-modulo-cuerpo"><div class="fw-medium">' + A.esc(m.Descripcion) + '</div>'
                + '<div class="ad-ayuda">Orden ' + m.Orden + ' · ' + m.Opciones + (m.Opciones === 1 ? ' opción' : ' opciones') + '</div></div>'
                + '<div class="ad-acciones">'
                + '<button type="button" class="btn btn-sm btn-outline-primary md-editar" title="Editar módulo"><i class="bx bx-edit-alt"></i></button> '
                + '<button type="button" class="btn btn-sm btn-outline-danger md-eliminar" title="Eliminar módulo"' + (m.Opciones ? ' disabled' : '') + '><i class="bx bx-trash"></i></button>'
                + '</div></div>';
        }).join(''));
    }

    function moduloActual() { return $.grep(state.modulos, function (m) { return m.Id === state.actual; })[0]; }

    /* ---------- selector de iconos ---------- */
    function pintarIconos(filtro) {
        var q = A.normalizar(filtro).replace(/\s+/g, '-'), actual = $('#mdIcono').val();
        var lista = $.grep(window.ICONOS_BOXICONS || [], function (i) { return !q || i.indexOf(q) >= 0; }).slice(0, 240);
        $('#mdIconos').html(lista.length ? lista.map(function (i) {
            var cls = 'bx ' + i;
            return '<button type="button" class="' + (cls === actual ? 'active' : '') + '" data-icono="' + cls + '" title="' + i.replace(/^bx[sl]?-/, '') + '" role="option"><i class="' + cls + '"></i></button>';
        }).join('') : '<div class="text-muted small p-2">Sin resultados.</div>');
    }
    function elegirIcono(cls) {
        $('#mdIcono').val(cls);
        $('#mdIconoVista').html('<i class="' + A.attr(cls || 'bx bx-question-mark') + '"></i>');
        $('#mdIconoError').text('');
        $('#mdIconos button').removeClass('active').filter('[data-icono="' + cls + '"]').addClass('active');
    }

    function abrirModulo(m) {
        state.modulo = m || null;
        A.limpiarErrores($('#mdForm'));
        $('#mdModalTitulo').text(m ? 'Editar módulo' : 'Nuevo módulo');
        $('#mdDescripcion').val(m ? m.Descripcion : '');
        var siguiente = state.modulos.reduce(function (x, y) { return Math.max(x, y.Orden); }, 0) + 1;
        $('#mdOrden').val(m ? m.Orden : siguiente);
        $('#mdBuscarIcono').val('');
        elegirIcono(m ? m.Icono : '');
        pintarIconos('');
        A.modal('mdModal').show();
        setTimeout(function () { $('#mdDescripcion').trigger('focus'); }, 300);
    }

    function guardarModulo() {
        A.limpiarErrores($('#mdForm'));
        var d = { Id: state.modulo ? state.modulo.Id : 0, Descripcion: $.trim($('#mdDescripcion').val()), Icono: $('#mdIcono').val(), Orden: parseInt($('#mdOrden').val(), 10) || 0 };
        if (!d.Descripcion) return A.marcarError($('#mdDescripcion'), 'Ingrese el nombre del módulo.');
        if (d.Orden < 1) return A.marcarError($('#mdOrden'), 'El orden debe ser 1 o mayor.');
        if (!d.Icono) { $('#mdIconoError').text('Seleccione un icono.'); return; }
        A.ocupado($('#mdGuardar'), api('GuardarModulo', { modulo: d }).done(function (r) {
            if (!r.Ok) { A.error(r); return; }
            showNotification(1, 'success', r.Mensaje);
            A.modal('mdModal').hide();
            if (!d.Id && r.Id) state.actual = r.Id;
            cargarModulos();
        }).fail(A.falla));
    }

    function eliminarModulo(m) {
        A.confirmar('Eliminar módulo', '¿Eliminar el módulo ' + m.Descripcion + '?', 'Eliminar', function () {
            api('EliminarModulo', { id: m.Id }).done(function (r) {
                if (!r.Ok) { A.error(r); return; }
                showNotification(1, 'success', r.Mensaje);
                cargarModulos();
            }).fail(A.falla);
        });
    }

    /* ---------- opciones ---------- */
    function cargarOpciones() {
        var m = moduloActual();
        $('#opNueva').prop('disabled', !m);
        if (!m) { $('#opFilas').html(A.vacio(5, 'Elija un módulo.')); return; }
        $('#opIcono').html('<i class="' + A.attr(m.Icono) + '"></i>');
        $('#opTitulo').text(m.Descripcion);
        $('#opSub').text('Opciones del módulo');
        $('#opFilas').html(A.cargando(5));
        api('Opciones', { modulo: m.Id }).done(function (r) {
            if (!r.Ok) { A.error(r); return; }
            state.opciones = r.Items || [];
            pintarOpciones();
        }).fail(A.falla);
    }

    function pintarOpciones() {
        if (!state.opciones.length) { $('#opFilas').html(A.vacio(5, 'Este módulo no tiene opciones.')); return; }
        $('#opFilas').html(state.opciones.map(function (o) {
            return '<tr data-id="' + o.Id + '">'
                + '<td class="text-center">' + o.Orden + '</td>'
                + '<td><div class="fw-medium">' + A.esc(o.Descripcion) + '</div><div class="ad-url d-md-none">' + A.esc(o.Url) + '</div></td>'
                + '<td class="d-none d-md-table-cell"><span class="ad-url">' + A.esc(o.Url) + '</span></td>'
                + '<td class="text-center"><span class="ad-chip ' + (o.Grupos ? 'ad-chip-info' : 'ad-chip-no') + '" title="Grupos con permiso">' + o.Grupos + '</span></td>'
                + '<td class="ad-acciones">'
                + '<button type="button" class="btn btn-sm btn-outline-primary op-editar" title="Editar opción"><i class="bx bx-edit-alt"></i></button> '
                + '<button type="button" class="btn btn-sm btn-outline-danger op-eliminar" title="Eliminar opción"><i class="bx bx-trash"></i></button>'
                + '</td></tr>';
        }).join(''));
    }

    function abrirOpcion(o) {
        state.opcion = o || null;
        A.limpiarErrores($('#opForm'));
        $('#opModalTitulo').text(o ? 'Editar opción' : 'Nueva opción');
        $('#opModulo').html(state.modulos.map(function (m) { return '<option value="' + m.Id + '">' + A.esc(m.Descripcion) + '</option>'; }).join(''))
            .val(o ? o.IdModulo : state.actual);
        $('#opDescripcion').val(o ? o.Descripcion : '');
        $('#opUrl').val(o ? o.Url : '');
        $('#opAbreviado').val(o ? o.Abreviado : '');
        $('#opOrden').val(o ? o.Orden : state.opciones.reduce(function (x, y) { return Math.max(x, y.Orden); }, 0) + 1);
        A.modal('opModal').show();
        setTimeout(function () { $('#opDescripcion').trigger('focus'); }, 300);
    }

    function guardarOpcion() {
        A.limpiarErrores($('#opForm'));
        var d = {
            Id: state.opcion ? state.opcion.Id : 0, IdModulo: +$('#opModulo').val(), Descripcion: $.trim($('#opDescripcion').val()),
            Url: $.trim($('#opUrl').val()).replace(/^\/+/, ''), Abreviado: $.trim($('#opAbreviado').val()).toUpperCase(), Orden: parseInt($('#opOrden').val(), 10) || 0
        };
        if (!d.Descripcion) return A.marcarError($('#opDescripcion'), 'Ingrese el nombre de la opción.');
        if (!/^[\w\-]+\/[\w\-]+\.aspx(\?.*)?$/i.test(d.Url)) return A.marcarError($('#opUrl'), 'Escriba la página como Carpeta/pagina.aspx.');
        if (d.Orden < 1) return A.marcarError($('#opOrden'), 'El orden debe ser 1 o mayor.');
        A.ocupado($('#opGuardar'), api('GuardarOpcion', { opcion: d }).done(function (r) {
            if (!r.Ok) { A.error(r); return; }
            showNotification(1, 'success', r.Mensaje);
            A.modal('opModal').hide();
            cargarModulos();     // actualiza los conteos (y la opción puede haber cambiado de módulo)
        }).fail(A.falla));
    }

    function eliminarOpcion(o) {
        A.confirmar('Eliminar opción', '¿Eliminar la opción ' + o.Descripcion + ' del menú?\nTambién se quitan sus permisos (' + o.Grupos + ' grupos).', 'Eliminar', function () {
            api('EliminarOpcion', { id: o.Id }).done(function (r) {
                if (!r.Ok) { A.error(r); return; }
                showNotification(1, 'success', r.Mensaje);
                cargarModulos();
            }).fail(A.falla);
        });
    }

    function opcionDe(el) { var id = +$(el).closest('tr').data('id'); return $.grep(state.opciones, function (o) { return o.Id === id; })[0]; }
    function moduloDe(el) { var id = +$(el).closest('.ad-modulo').data('id'); return $.grep(state.modulos, function (m) { return m.Id === id; })[0]; }

    /* ---------- eventos ---------- */
    $('#mdNuevoModulo').on('click', function () { abrirModulo(null); });
    $('#mdLista')
        .on('click keydown', '.ad-modulo', function (ev) {
            if (ev.type === 'keydown' && ev.key !== 'Enter') return;
            if ($(ev.target).closest('button').length) return;
            state.actual = +$(this).data('id');
            pintarModulos();
            cargarOpciones();
        })
        .on('click', '.md-editar', function () { abrirModulo(moduloDe(this)); })
        .on('click', '.md-eliminar', function () { eliminarModulo(moduloDe(this)); });
    $('#mdForm').on('submit', function (ev) { ev.preventDefault(); guardarModulo(); });
    $('#mdBuscarIcono').on('input', function () { pintarIconos($(this).val()); });
    $('#mdIconos').on('click', 'button', function () { elegirIcono($(this).data('icono')); });

    $('#opNueva').on('click', function () { abrirOpcion(null); });
    $('#opFilas')
        .on('click', '.op-editar', function () { abrirOpcion(opcionDe(this)); })
        .on('click', '.op-eliminar', function () { eliminarOpcion(opcionDe(this)); });
    $('#opForm').on('submit', function (ev) { ev.preventDefault(); guardarOpcion(); });
    $('#opDescripcion').on('blur', function () {
        if (!$.trim($('#opAbreviado').val())) $('#opAbreviado').val($.trim($(this).val()).substr(0, 2).toUpperCase());
    });

    cargarModulos();
})(jQuery);
