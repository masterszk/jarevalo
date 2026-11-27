/* Dashboards de inicio – Opciones/form_confDashboardInicial.aspx */
(function ($) {
    'use strict';

    var A = window.Admin, api = A.cliente('Opciones/form_confDashboardInicial.aspx');
    var state = { items: [], paginas: [], editando: null };

    function cargar() {
        $('#dbFilas').html(A.cargando(7));
        api('Lista').done(function (r) {
            if (!r.Ok) { A.error(r); return; }
            state.items = r.Items || [];
            state.paginas = r.Paginas || [];
            $('#dbPaginas').html(state.paginas.map(function (p) { return '<option value="' + A.attr(p) + '"></option>'; }).join(''));
            pintar();
        }).fail(A.falla);
    }

    function existe(url) { return state.paginas.some(function (p) { return p.toLowerCase() === String(url || '').toLowerCase(); }); }

    function pintar() {
        if (!state.items.length) { $('#dbFilas').html(A.vacio(7, 'No hay dashboards.')); return; }
        $('#dbFilas').html(state.items.map(function (d) {
            var activo = d.Estado === 'A', ok = existe(d.Url);
            return '<tr data-id="' + d.Id + '">'
                + '<td>' + d.Id + '</td>'
                + '<td class="fw-medium">' + A.esc(d.Descripcion) + '</td>'
                + '<td><span class="ad-url">' + A.esc(d.Url) + '</span>'
                + (ok ? '' : ' <span class="ad-chip ad-chip-no" title="La página no existe en la carpeta Dashboard: los usuarios verán el dashboard general">No existe</span>') + '</td>'
                + '<td class="text-center"><span class="ad-chip ' + (d.Usuarios ? 'ad-chip-lila' : '') + '">' + d.Usuarios + '</span></td>'
                + '<td class="text-center"><span class="ad-chip ' + (activo ? 'ad-chip-ok' : 'ad-chip-no') + '">' + (activo ? 'Activo' : 'Inactivo') + '</span></td>'
                + '<td class="d-none d-lg-table-cell small text-muted">' + A.esc(d.Usuario) + ' · ' + A.esc(A.fecha(d.Fecha, false)) + '</td>'
                + '<td class="ad-acciones">'
                + (ok ? '<button type="button" class="btn btn-sm btn-outline-secondary db-ver" title="Ver"><i class="bx bx-show"></i></button> ' : '')
                + '<button type="button" class="btn btn-sm btn-outline-primary db-editar" title="Editar"><i class="bx bx-edit-alt"></i></button> '
                + '<button type="button" class="btn btn-sm btn-outline-danger db-eliminar" title="' + (d.Usuarios ? 'Tiene usuarios asignados' : 'Eliminar') + '"' + (d.Usuarios ? ' disabled' : '') + '><i class="bx bx-trash"></i></button>'
                + '</td></tr>';
        }).join(''));
    }

    function abrir(d) {
        state.editando = d || null;
        A.limpiarErrores($('#dbForm'));
        $('#dbModalTitulo').text(d ? 'Editar dashboard' : 'Nuevo dashboard');
        $('#dbDescripcion').val(d ? d.Descripcion : '');
        $('#dbUrl').val(d ? d.Url : '');
        $(d && d.Estado === 'I' ? '#dbInactivo' : '#dbActivo').prop('checked', true);
        $('#dbPaginasAyuda').text(state.paginas.length ? 'Páginas disponibles: ' + state.paginas.join(', ') : '');
        A.modal('dbModal').show();
        setTimeout(function () { $('#dbDescripcion').trigger('focus'); }, 300);
    }

    function guardar() {
        A.limpiarErrores($('#dbForm'));
        var d = { Id: state.editando ? state.editando.Id : 0, Descripcion: $.trim($('#dbDescripcion').val()), Url: $.trim($('#dbUrl').val()).replace(/^\/+/, ''), Estado: $('input[name="dbEstado"]:checked').val() };
        if (!d.Descripcion) return A.marcarError($('#dbDescripcion'), 'Ingrese la descripción.');
        if (!/^[\w\-]+\/[\w\-]+\.aspx$/i.test(d.Url)) return A.marcarError($('#dbUrl'), 'Escriba la página como Dashboard/pagina.aspx.');
        var enviar = function () {
            A.ocupado($('#dbGuardar'), api('Guardar', { dashboard: d }).done(function (r) {
                if (!r.Ok) { A.error(r); return; }
                showNotification(1, 'success', r.Mensaje);
                A.modal('dbModal').hide();
                cargar();
            }).fail(A.falla));
        };
        if (!existe(d.Url)) A.confirmar('Página no encontrada', d.Url + ' no existe en la carpeta Dashboard. Los usuarios con este dashboard verán el general. ¿Guardar de todos modos?', 'Guardar', enviar);
        else enviar();
    }

    function itemDe(el) { var id = +$(el).closest('tr').data('id'); return $.grep(state.items, function (d) { return d.Id === id; })[0]; }

    $('#dbNuevo').on('click', function () { abrir(null); });
    $('#dbForm').on('submit', function (ev) { ev.preventDefault(); guardar(); });
    $('#dbFilas')
        .on('click', '.db-editar', function () { abrir(itemDe(this)); })
        .on('click', '.db-ver', function () { AjaxLink(itemDe(this).Url); })
        .on('click', '.db-eliminar', function () {
            var d = itemDe(this);
            A.confirmar('Eliminar dashboard', '¿Eliminar el dashboard ' + d.Descripcion + '?', 'Eliminar', function () {
                api('Eliminar', { id: d.Id }).done(function (r) {
                    if (!r.Ok) { A.error(r); return; }
                    showNotification(1, 'success', r.Mensaje);
                    cargar();
                }).fail(A.falla);
            });
        });

    cargar();
})(jQuery);
