/* Permisos por grupo – Opciones/form_confAccesosObjetos.aspx */
(function ($) {
    'use strict';

    var A = window.Admin, api = A.cliente('Opciones/form_confAccesosObjetos.aspx');
    var CLAVE_GRUPO = 'dpie.permisos.grupo';
    var state = { grupos: [], grupo: $('#permisos').data('grupo') || leer() || '', permisos: [], filtro: '' };

    function leer() { try { return localStorage.getItem(CLAVE_GRUPO); } catch (e) { return null; } }
    function guardar(v) { try { localStorage.setItem(CLAVE_GRUPO, v); } catch (e) { } }

    function cargarGrupos() {
        api('Grupos').done(function (r) {
            if (!r.Ok) { A.error(r); return; }
            state.grupos = r.Items || [];
            if (!state.grupos.some(function (g) { return g.Id === state.grupo; })) state.grupo = state.grupos.length ? state.grupos[0].Id : '';
            pintarGrupos();
            cargarPermisos();
        }).fail(A.falla);
    }

    function pintarGrupos() {
        $('#peGrupos').html(state.grupos.map(function (g) {
            var activo = g.Id === state.grupo;
            return '<button type="button" class="btn btn-sm ' + (activo ? 'btn-primary active' : 'btn-outline-secondary') + '" data-grupo="' + A.attr(g.Id) + '" role="tab" aria-selected="' + activo + '"'
                + ' title="' + A.attr(g.Usuarios + ' usuarios') + '">' + A.esc(g.Descripcion) + ' <span class="badge ' + (activo ? 'bg-light text-dark' : 'bg-secondary') + '">' + g.Usuarios + '</span></button>';
        }).join(''));
    }

    function cargarPermisos() {
        if (!state.grupo) { $('#peModulos').html('<div class="col-12 text-center text-muted py-4">No hay grupos.</div>'); return; }
        guardar(state.grupo);
        $('#peModulos').html('<div class="col-12 text-center py-4"><div class="spinner-border spinner-border-sm text-primary"></div> Cargando permisos…</div>');
        api('Permisos', { grupo: state.grupo }).done(function (r) {
            if (!r.Ok) { A.error(r); return; }
            state.permisos = r.Items || [];
            pintarPermisos();
        }).fail(A.falla);
    }

    function pintarPermisos() {
        var q = A.normalizar(state.filtro), modulos = [], porModulo = {};
        $.each(state.permisos, function (_, p) {
            if (!porModulo[p.IdModulo]) { porModulo[p.IdModulo] = { id: p.IdModulo, nombre: p.Modulo, icono: p.Icono, opciones: [] }; modulos.push(porModulo[p.IdModulo]); }
            porModulo[p.IdModulo].opciones.push(p);
        });

        var total = state.permisos.length, con = $.grep(state.permisos, function (p) { return p.Tiene; }).length;
        var grupo = $.grep(state.grupos, function (g) { return g.Id === state.grupo; })[0];
        $('#peResumen').html('<strong>' + A.esc(grupo ? grupo.Descripcion : state.grupo) + '</strong> tiene acceso a <strong>' + con + '</strong> de ' + total + ' opciones.');

        var html = modulos.map(function (m) {
            var visibles = $.grep(m.opciones, function (o) { return !q || A.normalizar(o.Opcion + ' ' + m.nombre).indexOf(q) >= 0; });
            if (!visibles.length) return '';
            var conMod = $.grep(m.opciones, function (o) { return o.Tiene; }).length, todas = conMod === m.opciones.length;
            return '<div class="col-md-6 col-xl-4"><div class="card radius-10 h-100 mb-0 ad-permiso-modulo">'
                + '<div class="card-header"><span class="ad-icono"><i class="' + A.attr(m.icono) + '"></i></span>'
                + '<div class="flex-fill"><div class="fw-medium">' + A.esc(m.nombre) + '</div><div class="ad-ayuda">' + conMod + ' de ' + m.opciones.length + '</div></div>'
                + '<button type="button" class="btn btn-sm ' + (todas ? 'btn-outline-danger' : 'btn-outline-success') + ' pe-modulo" data-id="' + m.id + '" data-valor="' + (todas ? 0 : 1) + '">'
                + (todas ? 'Quitar todo' : 'Dar todo') + '</button></div>'
                + '<div class="card-body py-2">' + visibles.map(function (o) {
                    var id = 'pe' + o.IdOpcion;
                    return '<div class="ad-permiso-opcion"><input class="form-check-input pe-opcion" type="checkbox" role="switch" id="' + id + '" data-id="' + o.IdOpcion + '"' + (o.Tiene ? ' checked' : '') + ' />'
                        + '<label class="flex-fill mb-0" for="' + id + '">' + A.esc(o.Opcion) + '<div class="ad-url">' + A.esc(o.Url) + '</div></label></div>';
                }).join('') + '</div></div></div>';
        }).join('');
        $('#peModulos').html(html || '<div class="col-12 text-center text-muted py-4">Ninguna opción coincide con la búsqueda.</div>');
    }

    function cambiar(id, modulo, valor, $control) {
        $control.prop('disabled', true);
        api('Cambiar', { grupo: state.grupo, id: id, modulo: modulo, valor: valor }).done(function (r) {
            if (!r.Ok) { A.error(r); pintarPermisos(); return; }
            $.each(state.permisos, function (_, p) { if (modulo ? p.IdModulo === id : p.IdOpcion === id) p.Tiene = valor; });
            showNotification(1, 'success', r.Mensaje);
            pintarPermisos();
        }).fail(function (xhr) { A.falla(xhr); pintarPermisos(); });
    }

    $('#peGrupos').on('click', '[data-grupo]', function () {
        state.grupo = String($(this).data('grupo'));
        pintarGrupos();
        cargarPermisos();
    });
    $('#peModulos')
        .on('change', '.pe-opcion', function () { cambiar(+$(this).data('id'), false, $(this).is(':checked'), $(this)); })
        .on('click', '.pe-modulo', function () {
            var $b = $(this), valor = +$b.data('valor') === 1, nombre = $b.closest('.card-header').find('.fw-medium').text();
            var hacer = function () { cambiar(+$b.data('id'), true, valor, $b); };
            if (valor) hacer();
            else A.confirmar('Quitar permisos', '¿Quitar todas las opciones de ' + nombre + ' a este grupo?', 'Quitar', hacer);
        });
    $('#peBuscar').on('input', function () { state.filtro = $.trim($(this).val()); pintarPermisos(); });

    cargarGrupos();
})(jQuery);
