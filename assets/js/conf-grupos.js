/* Grupos de usuarios – Perfiles/form_confGrupos.aspx */
(function ($) {
    'use strict';

    var A = window.Admin, api = A.cliente('Perfiles/form_confGrupos.aspx');
    var state = { grupos: [], editando: null };

    function cargar() {
        $('#grFilas').html(A.cargando(6));
        api('Grupos').done(function (r) {
            if (!r.Ok) { A.error(r); return; }
            state.grupos = r.Items || [];
            pintar();
        }).fail(A.falla);
    }

    function pintar() {
        if (!state.grupos.length) { $('#grFilas').html(A.vacio(6, 'No hay grupos.')); return; }
        $('#grFilas').html(state.grupos.map(function (g) {
            var protegido = g.Id === 'Administradores';
            return '<tr data-id="' + A.attr(g.Id) + '">'
                + '<td><span class="fw-medium">' + A.esc(g.Id) + '</span></td>'
                + '<td>' + A.esc(g.Descripcion) + '</td>'
                + '<td class="text-center"><span class="ad-chip ' + (g.Usuarios ? 'ad-chip-lila' : '') + '">' + g.Usuarios + '</span></td>'
                + '<td class="text-center"><span class="ad-chip ' + (g.Permisos ? 'ad-chip-info' : 'ad-chip-no') + '">' + g.Permisos + '</span></td>'
                + '<td class="d-none d-lg-table-cell small text-muted">' + A.esc(g.Usuario) + ' · ' + A.esc(A.fecha(g.Fecha, false)) + '</td>'
                + '<td class="ad-acciones">'
                + '<button type="button" class="btn btn-sm btn-outline-success gr-permisos" title="Asignar permisos"><i class="bx bx-lock-open-alt"></i> Permisos</button> '
                + '<button type="button" class="btn btn-sm btn-outline-primary gr-editar" title="Editar"><i class="bx bx-edit-alt"></i></button> '
                + '<button type="button" class="btn btn-sm btn-outline-danger gr-eliminar" title="' + (protegido ? 'No se puede eliminar' : g.Usuarios ? 'Tiene usuarios' : 'Eliminar') + '"'
                + (protegido || g.Usuarios ? ' disabled' : '') + '><i class="bx bx-trash"></i></button>'
                + '</td></tr>';
        }).join(''));
    }

    function abrir(g) {
        state.editando = g || null;
        A.limpiarErrores($('#grForm'));
        $('#grModalTitulo').text(g ? 'Editar grupo' : 'Nuevo grupo');
        $('#grCodigo').val(g ? g.Id : '').prop('readonly', !!g);
        $('#grDescripcion').val(g ? g.Descripcion : '');
        A.modal('grModal').show();
        setTimeout(function () { $(g ? '#grDescripcion' : '#grCodigo').trigger('focus'); }, 300);
    }

    function guardar() {
        A.limpiarErrores($('#grForm'));
        var d = { Id: $.trim($('#grCodigo').val()), Descripcion: $.trim($('#grDescripcion').val()) };
        if (!d.Id) return A.marcarError($('#grCodigo'), 'Ingrese el código.');
        if (!/^\w+$/.test(d.Id)) return A.marcarError($('#grCodigo'), 'Use solo letras, números y guion bajo, sin espacios.');
        if (!d.Descripcion) return A.marcarError($('#grDescripcion'), 'Ingrese la descripción.');
        var nuevo = !state.editando;
        A.ocupado($('#grGuardar'), api('Guardar', { grupo: d, nuevo: nuevo }).done(function (r) {
            if (!r.Ok) { A.error(r); return; }
            showNotification(1, 'success', r.Mensaje);
            A.modal('grModal').hide();
            cargar();
            if (nuevo)
                A.confirmar('Grupo creado', 'El grupo ' + d.Id + ' aún no tiene opciones. ¿Asignar sus permisos ahora?', 'Asignar permisos', function () {
                    setTimeout(function () { AjaxLink('Opciones/form_confAccesosObjetos.aspx?grupo=' + encodeURIComponent(d.Id)); }, 350);
                });
        }).fail(A.falla));
    }

    function grupoDe(el) { var id = String($(el).closest('tr').data('id')); return $.grep(state.grupos, function (g) { return g.Id === id; })[0]; }

    $('#grNuevo').on('click', function () { abrir(null); });
    $('#grForm').on('submit', function (ev) { ev.preventDefault(); guardar(); });
    $('#grCodigo').on('input', function () { var v = $(this).val().replace(/\s+/g, '_'); if (v !== $(this).val()) $(this).val(v); });
    $('#grFilas')
        .on('click', '.gr-editar', function () { abrir(grupoDe(this)); })
        .on('click', '.gr-permisos', function () { AjaxLink('Opciones/form_confAccesosObjetos.aspx?grupo=' + encodeURIComponent(grupoDe(this).Id)); })
        .on('click', '.gr-eliminar', function () {
            var g = grupoDe(this);
            A.confirmar('Eliminar grupo', '¿Eliminar el grupo ' + g.Descripcion + '?\nTambién se quitan sus ' + g.Permisos + ' permisos.', 'Eliminar', function () {
                api('Eliminar', { grupo: g.Id }).done(function (r) {
                    if (!r.Ok) { A.error(r); return; }
                    showNotification(1, 'success', r.Mensaje);
                    cargar();
                }).fail(A.falla);
            });
        });

    cargar();
})(jQuery);
