/* Página principal (default.aspx): menú, carga de páginas con AjaxLink, historial del navegador y control de la sesión.
   AjaxLink, mtd_ValidateSession, mtd_leeDashboard, WaitProcess, mtd_OpenModal y mtd_CloseModal son globales
   porque las páginas que se cargan dentro de #content los usan. */
(function ($) {
    'use strict';

    // Dashboard asignado al usuario (lo escribe default.aspx); se abre al entrar y con los botones de inicio
    var INICIO = $.trim($('#prDashboard').val() || '') || 'Dashboard/form_DashboardGeneral.aspx';
    var VALIDAR_MS = 5 * 60 * 1000;
    var cargaActual = null;        // petición en curso: si se abre otra página antes de que termine, se cancela
    var avisoSesion = false;

    function usuario() { return $.trim($('#idUser').val() || ''); }
    function post(metodo, datos) {
        return $.ajax({
            type: 'POST',
            url: 'default.aspx/' + metodo,
            data: JSON.stringify(datos || {}),
            contentType: 'application/json; charset=utf-8',
            dataType: 'json'
        }).then(function (r) { return r.d; });
    }
    function esc(s) { return $('<div/>').text(s == null ? '' : String(s)).html(); }
    function sinConsulta(url) { return String(url || '').split('?')[0].split('#')[0].toLowerCase(); }
    // Página indicada en la dirección (#Registros/frm_X.aspx); '' si el fragmento no es una página
    function paginaDelHash() {
        var h = location.hash ? location.hash.substr(1) : '';
        try { h = decodeURIComponent(h); } catch (e) { return ''; }      // p. ej. restos de un parámetro mal codificado
        return /^[A-Za-z]+\/[\w\-]+\.aspx(\?[^#]*)?$/.test(h) ? h : '';
    }

    /* ---------- sesión ---------- */
    function sesionTerminada(destino) {
        if (avisoSesion) return;
        avisoSesion = true;
        var ir = function () { window.location.replace(destino || 'login.aspx'); };
        if (typeof swal === 'function')
            swal({ title: 'Sesión finalizada', text: 'Su sesión terminó. Vuelva a iniciar sesión para continuar.', type: 'warning', confirmButtonText: 'Iniciar sesión' }, ir);
        else { alert('Su sesión terminó. Vuelva a iniciar sesión.'); ir(); }
    }

    window.mtd_ValidateSession = function () {
        post('mtd_ValidateSession', { user: usuario() }).done(function (r) {
            var p = String(r || '').split('||');
            if (p[0] === 'ERROR') sesionTerminada(p[1]);
        });
    };

    function cargarUsuario() {
        return post('mtd_SessionUser').done(function (u) {
            if (!u || !u.Ok) { sesionTerminada('login.aspx'); return; }
            $('#idUser').val(u.Usuario);
            $('#nameuser').text(u.Nombre);
            $('#groupuser').text(u.Grupo);
            $('#photouser').attr('src', u.Foto);
            $('#prUsuarioDetalle').html('<strong>' + esc(u.Nombre) + '</strong><br>' + esc(u.Usuario) + (u.Email ? ' · ' + esc(u.Email) : ''));
        });
    }

    /* ---------- navegación ---------- */
    function progreso(activo) {
        $('#prProgreso').toggleClass('activo', activo);
        $('#content').toggleClass('pr-cargando', activo);
    }

    // Solo resalta la opción abierta y su módulo: no abre ni cierra módulos (eso lo decide el usuario con clic)
    function marcarMenu(url) {
        var clave = sinConsulta(url), $op = null;
        $('#menu .menu-opcion').each(function () {
            if (sinConsulta($(this).data('url')) === clave) { $op = $(this); return false; }
        });
        $('#menu .pr-actual').removeClass('pr-actual');
        $('#menu .pr-contiene').removeClass('pr-contiene');
        var titulo = 'D\' Pie Center';
        if ($op) {
            $op.parent('li').addClass('pr-actual');
            $op.parents('li').not($op.parent('li')).addClass('pr-contiene');
            titulo = String($op.data('titulo') || $op.text()).trim();
        }
        $('#prTitulo').text(titulo);
        document.title = (titulo === 'D\' Pie Center' ? '' : titulo + ' · ') + 'D\' Pie Center';
    }

    function errorCarga(url, xhr) {
        $('#content').html(
            '<div class="card radius-10"><div class="card-body text-center py-5">' +
            '<i class="bx bx-error-circle text-danger" style="font-size:3rem"></i>' +
            '<h5 class="mt-2">No fue posible abrir la página</h5>' +
            '<p class="text-muted">' + (xhr && xhr.status ? 'El servidor respondió con el código ' + xhr.status + '.' : 'Revise su conexión e intente de nuevo.') + '</p>' +
            '<button type="button" class="btn btn-primary me-2" id="prReintentar"><i class="bx bx-refresh"></i> Reintentar</button>' +
            '<button type="button" class="btn btn-outline-secondary" id="prIrInicio"><i class="bx bx-home-alt"></i> Ir al dashboard</button>' +
            '</div></div>');
        $('#prReintentar').on('click', function () { window.AjaxLink(url, { historial: false }); });
        $('#prIrInicio').on('click', function () { window.AjaxLink(INICIO); });
    }

    /**
     * Abre una página dentro de #content. opciones.historial: true (por defecto) agrega una entrada al historial,
     * 'reemplazar' reemplaza la actual (primera página) y false no lo toca (botón Atrás del navegador o reintentar).
     */
    // Un modal de la página anterior que seguía abierto (o cerrándose) dejaría su fondo oscuro sobre la nueva
    function cerrarModales() {
        $('#content .modal.show').each(function () {
            try { bootstrap.Modal.getInstance(this) && bootstrap.Modal.getInstance(this).dispose(); } catch (e) { }
        });
        $('.modal-backdrop').remove();
        $('body').removeClass('modal-open').css({ overflow: '', paddingRight: '' });
    }

    window.AjaxLink = function (url, opciones) {
        url = $.trim(url || '');
        if (!url || url === '1') url = INICIO;
        opciones = opciones || {};

        if (cargaActual) cargaActual.abort();
        progreso(true);
        marcarMenu(url);

        // Se registra la última página del usuario (para volver a ella al recargar); no se espera la respuesta
        post('mtd_UpdateAjaxLink', { idAjaxLink: 0, usuario: usuario(), url: url, accion: 1 }).done(function (r) {
            if (String(r || '').indexOf('SESION') === 0) sesionTerminada('login.aspx');
        });

        cargaActual = $.ajax({ url: url, type: 'GET', dataType: 'html', cache: false });
        cargaActual.done(function (html) {
            // Si la sesión expiró, el servidor puede devolver la pantalla de inicio de sesión completa
            if (/<form[^>]+id="lgForm"/i.test(html)) { sesionTerminada('login.aspx'); return; }
            cerrarModales();
            $('#content').empty().html(html);
            if (opciones.historial === 'reemplazar') history.replaceState({ url: url }, '', '#' + url);
            else if (opciones.historial !== false) history.pushState({ url: url }, '', '#' + url);
            window.scrollTo(0, 0);
        }).fail(function (xhr, estado) {
            if (estado !== 'abort') errorCarga(url, xhr);
        }).always(function (_, estado) {
            if (estado !== 'abort') { progreso(false); cargaActual = null; }
        });

        // En el celular se cierra el menú al elegir una opción
        if (window.innerWidth < 1025) $('.wrapper').removeClass('toggled');
        return cargaActual;
    };

    /** Última página abierta por el usuario, o el dashboard de su perfil. */
    window.mtd_leeDashboard = function (accion, opciones) {
        post('mtd_leeDashboard', { user: usuario(), accion: parseInt(accion, 10) || 5 })
            .done(function (url) { window.AjaxLink(url, opciones); })
            .fail(function () { window.AjaxLink(INICIO, opciones); });
    };

    window.WaitProcess = function (obj) {
        $('#' + obj).empty().html('<div class="spinner-border" role="status"><span class="visually-hidden">Cargando…</span></div>');
    };
    window.mtd_OpenModal = function (obj) { $('#' + obj).modal('show'); };
    window.mtd_CloseModal = function (obj) { $('#' + obj).modal('hide'); };

    /* ---------- buscador del menú ---------- */
    function normalizar(s) { return String(s || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, ''); }

    $('#prBuscarMenu').on('input', function () {
        var q = normalizar($.trim($(this).val())), hay = false;
        $('#menu > li').each(function () {
            var $mod = $(this), $ops = $mod.find('ul li');
            if (!q) { $mod.show(); $ops.show(); $mod.removeClass('pr-filtrado'); return; }
            var coincideModulo = normalizar($mod.children('a').text()).indexOf(q) >= 0, alguna = false;
            $ops.each(function () {
                var si = coincideModulo || normalizar($(this).text()).indexOf(q) >= 0;
                $(this).toggle(si);
                alguna = alguna || si;
            });
            var visible = alguna || (!$ops.length && coincideModulo);
            $mod.toggle(visible).toggleClass('pr-filtrado', visible && $ops.length > 0);
            hay = hay || visible;
        });
        $('#prSinResultados').toggleClass('d-none', hay || !q);
    }).on('keydown', function (ev) {
        if (ev.key === 'Escape') { $(this).val('').trigger('input'); }
        if (ev.key === 'Enter') { ev.preventDefault(); $('#menu .menu-opcion:visible').first().trigger('click'); }
    });

    /* ---------- eventos ---------- */
    // Páginas completas (no fragmentos): se abren en otra pestaña, p. ej. la pantalla de turnos para el televisor
    var PAGINAS_COMPLETAS = /(^|\/)frm_TurnosPacientes\.aspx/i;

    $('#menu').on('click', '.menu-opcion', function (ev) {
        ev.preventDefault();
        var url = String($(this).data('url') || '');
        if (PAGINAS_COMPLETAS.test(url)) { window.open(url, 'dpTurnos', 'noopener'); return; }
        window.AjaxLink(url);
        if ($('#prBuscarMenu').val()) $('#prBuscarMenu').val('').trigger('input');
    });
    $('#prInicio, #prInicioLogo, #prMenuInicio').on('click', function () { window.AjaxLink(INICIO); });

    // Administradores: cambiar la sucursal en la que trabajan. Se recarga la página para que todo use la nueva sucursal.
    $('#prSucursal').on('change', function () {
        var $s = $(this).prop('disabled', true);
        $.ajax({ type: 'POST', url: 'Default.aspx/CambiarSucursal', data: JSON.stringify({ sucursal: +$s.val() }), contentType: 'application/json; charset=utf-8', dataType: 'json' })
            .done(function (r) {
                r = r.d;
                if (!r.Ok) { showNotification(1, 'warning', r.Mensaje); $s.prop('disabled', false); return; }
                window.location.reload();
            })
            .fail(function () { showNotification(1, 'error', 'No fue posible cambiar la sucursal.'); $s.prop('disabled', false); });
    });
    $('#prSalir').on('click', function () { window.location.replace('login.aspx'); });   // login.aspx cierra la sesión

    // Botón Atrás / Adelante del navegador
    window.addEventListener('popstate', function (ev) {
        var url = ev.state && ev.state.url ? ev.state.url : (paginaDelHash() || INICIO);
        window.AjaxLink(url, { historial: false });
    });

    $('#prAnio').text(new Date().getFullYear());

    // El menú arranca con todos los módulos retraídos; al hacer clic en uno se expande (y se cierra el anterior)
    function retraerMenu() {
        $('#menu li.mm-active').removeClass('mm-active');
        $('#menu ul.mm-show').removeClass('mm-show');
        $('#menu ul.mm-collapse').css('height', '');
        $('#menu a[aria-expanded]').attr('aria-expanded', 'false');
    }

    /* ---------- inicio ---------- */
    $(function () {
        retraerMenu();       // app.js marca como activo lo que coincide con la dirección; se deja todo cerrado
        cargarUsuario();
        // Con #pagina en la dirección (recargar o enlace directo) se abre esa página; al entrar, siempre su dashboard
        var hash = paginaDelHash();
        window.AjaxLink(hash || INICIO, { historial: 'reemplazar' });

        setInterval(window.mtd_ValidateSession, VALIDAR_MS);
    });

})(jQuery);
