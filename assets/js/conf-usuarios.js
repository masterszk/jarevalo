/* Usuarios del sistema – Perfiles/form_confUsuarios.aspx */
(function ($) {
    'use strict';

    var A = window.Admin, api = A.cliente('Perfiles/form_confUsuarios.aspx');
    var state = { usuarios: [], grupos: [], dashboards: [], yo: '', editando: null, texto: '', grupo: '', estado: 'A' };

    function iniciales(u) { return ((u.Nombres || '').charAt(0) + (u.Apellidos || '').charAt(0)).toUpperCase() || '?'; }
    function titulo(s) { return String(s || '').toLowerCase().replace(/(^|\s)(\S)/g, function (m, a, b) { return a + b.toUpperCase(); }); }
    function diasDesde(iso) { return iso ? Math.floor((Date.now() - new Date(iso.replace('T', ' ').replace(/-/g, '/'))) / 86400000) : null; }

    function cargar() {
        $('#usFilas').html(A.cargando(6));
        return api('Inicio').done(function (r) {
            if (!r.Ok) { A.error(r); return; }
            state.usuarios = r.Usuarios || [];
            state.grupos = r.Grupos || [];
            state.dashboards = r.Dashboards || [];
            state.sucursales = r.Sucursales || [];
            state.yo = r.UsuarioSesion || '';
            state.bloqueos = {};
            $.each(r.Bloqueos || [], function (_, b) { state.bloqueos[String(b.Usuario).toLowerCase()] = b; });
            pintarBloqueos(r.Bloqueos || []);
            var g = $('#usFiltroGrupo').val();
            $('#usFiltroGrupo').html('<option value="">Todos los grupos</option>' + state.grupos.map(function (x) { return '<option value="' + A.attr(x.Id) + '">' + A.esc(x.Descripcion) + '</option>'; }).join('')).val(g);
            resumen();
            pintar();
        }).fail(A.falla);
    }

    function resumen() {
        var activos = $.grep(state.usuarios, function (u) { return u.Estado === 'A'; });
        $('#usActivos').text(activos.length);
        $('#usInactivos').text(state.usuarios.length - activos.length);
        $('#usHoy').text($.grep(activos, function (u) { return diasDesde(u.UltimoIngreso) === 0; }).length);
        $('#us30').text($.grep(activos, function (u) { var d = diasDesde(u.UltimoIngreso); return d === null || d > 30; }).length);
    }

    function bloqueoDe(u) { return (state.bloqueos || {})[String(u.Id).toLowerCase()] || null; }

    // Aviso arriba de la tabla con los usuarios bloqueados por intentos fallidos de inicio de sesión
    function pintarBloqueos(lista) {
        var $c = $('#usBloqueos');
        if (!$c.length) $c = $('<div id="usBloqueos"></div>').insertBefore($('#usFilas').closest('.card'));
        var bloqueados = $.grep(lista, function (b) { return b.Bloqueado; });
        if (!bloqueados.length) { $c.empty(); return; }
        $c.html('<div class="alert alert-warning d-flex flex-wrap align-items-center gap-2">'
            + '<i class="bx bx-lock-alt fs-4"></i><div class="me-auto"><strong>' + (bloqueados.length === 1 ? '1 usuario bloqueado' : bloqueados.length + ' usuarios bloqueados')
            + '</strong> por intentos fallidos de inicio de sesión. Se desbloquean solos en 15 minutos, o desbloquéelos ahora.</div>'
            + bloqueados.map(function (b) {
                return '<button type="button" class="btn btn-sm btn-warning us-desbloquear-id" data-usuario="' + A.attr(b.Usuario) + '"><i class="bx bx-lock-open-alt"></i> '
                    + A.esc(b.Usuario) + ' <span class="small">(' + b.Minutos + ' min)</span></button>';
            }).join(' ') + '</div>');
    }

    function desbloquear(id) {
        var u = $.grep(state.usuarios, function (x) { return String(x.Id).toLowerCase() === String(id).toLowerCase(); })[0];
        accion('Desbloquear', { usuario: u ? u.Id : id }, 'Desbloquear usuario',
            '¿Desbloquear a ' + (u ? titulo(u.Nombres) + ' (' + u.Id + ')' : id) + '?\nPodrá intentar iniciar sesión de nuevo. Su contraseña no cambia.', 'Desbloquear');
    }

    function pintar() {
        var q = A.normalizar(state.texto);
        var lista = $.grep(state.usuarios, function (u) {
            return (!state.estado || u.Estado === state.estado) && (!state.grupo || u.IdGrupo === state.grupo)
                && (!q || A.normalizar([u.Id, u.Nombres, u.Apellidos, u.Email, u.Especialista].join(' ')).indexOf(q) >= 0);
        });
        $('#usConteo').text(lista.length + ' de ' + state.usuarios.length);
        if (!lista.length) { $('#usFilas').html(A.vacio(6, 'No hay usuarios con estos filtros.')); return; }

        $('#usFilas').html(lista.map(function (u) {
            var activo = u.Estado === 'A', yo = u.Id === state.yo, dias = diasDesde(u.UltimoIngreso), b = bloqueoDe(u);
            return '<tr class="' + (activo ? '' : 'ad-inactivo') + '" data-id="' + A.attr(u.Id) + '">'
                + '<td><div class="d-flex align-items-center gap-2"><span class="ad-avatar">' + A.esc(iniciales(u)) + '</span><div>'
                + '<div class="fw-medium">' + A.esc(titulo(u.Nombres + ' ' + u.Apellidos)) + (yo ? ' <span class="ad-chip ad-chip-info">Usted</span>' : '') + '</div>'
                + '<div class="ad-ayuda">' + A.esc(u.Id) + (u.Email ? ' · ' + A.esc(u.Email) : '') + '</div>'
                + (u.Especialista ? '<div class="ad-ayuda"><i class="bx bx-plus-medical"></i> Especialista: ' + A.esc(u.Especialista) + '</div>' : '')
                + '</div></div></td>'
                + '<td><span class="ad-chip ad-chip-lila">' + A.esc(u.Grupo) + '</span>' + (u.Responsable ? ' <span class="ad-chip" title="Responsable">Resp.</span>' : '')
                + (u.Sucursal ? '<div class="ad-ayuda"><i class="bx bx-store-alt"></i> ' + A.esc(u.Sucursal) + '</div>' : '') + '</td>'
                + '<td class="d-none d-lg-table-cell small">' + (A.esc(u.Dashboard) || '<span class="text-muted">General</span>') + '</td>'
                + '<td class="d-none d-md-table-cell small' + (activo && (dias === null || dias > 30) ? ' text-warning' : '') + '" title="' + A.attr(A.fecha(u.UltimoIngreso)) + '">' + A.esc(A.relativa(u.UltimoIngreso)) + '</td>'
                + '<td class="text-center"><span class="ad-chip ' + (activo ? 'ad-chip-ok' : 'ad-chip-no') + '">' + (activo ? 'Activo' : 'Inactivo') + '</span>'
                + (b ? '<div class="mt-1"><span class="ad-chip ' + (b.Bloqueado ? 'ad-chip-no' : '') + '" title="Último intento fallido: ' + A.attr(b.UltimoIntento) + '">'
                    + (b.Bloqueado ? '<i class="bx bx-lock-alt"></i> Bloqueado ' + b.Minutos + ' min' : b.Fallos + (b.Fallos === 1 ? ' intento fallido' : ' intentos fallidos')) + '</span></div>' : '')
                + '</td>'
                + '<td class="ad-acciones"><div class="btn-group">'
                + '<button type="button" class="btn btn-sm btn-outline-primary us-editar" title="Editar"><i class="bx bx-edit-alt"></i></button>'
                + '<button type="button" class="btn btn-sm btn-outline-primary dropdown-toggle dropdown-toggle-split" data-bs-toggle="dropdown" aria-expanded="false"><span class="visually-hidden">Más acciones</span></button>'
                + '<ul class="dropdown-menu dropdown-menu-end">'
                + (b ? '<li><a class="dropdown-item us-desbloquear" href="javascript:;"><i class="bx bx-lock-open-alt"></i> Desbloquear inicio de sesión</a></li>' : '')
                + '<li><a class="dropdown-item us-clave" href="javascript:;"><i class="bx bx-key"></i> Restablecer clave</a></li>'
                + (yo ? '' : '<li><a class="dropdown-item us-estado" href="javascript:;"><i class="bx ' + (activo ? 'bx-block' : 'bx-check-circle') + '"></i> ' + (activo ? 'Inactivar' : 'Activar') + '</a></li>'
                    + '<li><hr class="dropdown-divider"></li><li><a class="dropdown-item text-danger us-eliminar" href="javascript:;"><i class="bx bx-trash"></i> Eliminar</a></li>')
                + '</ul></div></td></tr>';
        }).join(''));
    }

    function usuarioDe(el) { var id = String($(el).closest('tr').data('id')); return $.grep(state.usuarios, function (u) { return u.Id === id; })[0]; }

    /* ---------- modal ---------- */
    function abrir(u) {
        state.editando = u || null;
        A.limpiarErrores($('#usForm'));
        $('#usModalTitulo').text(u ? 'Editar usuario' : 'Nuevo usuario');
        $('#usGrupo').html('<option value="">Seleccione…</option>' + state.grupos.map(function (g) { return '<option value="' + A.attr(g.Id) + '">' + A.esc(g.Descripcion) + '</option>'; }).join(''));
        $('#usDashboard').html('<option value="0">General (predeterminado)</option>' + state.dashboards.map(function (d) {
            return '<option value="' + d.Id + '"' + (d.Estado !== 'A' ? ' disabled' : '') + '>' + A.esc(d.Descripcion) + (d.Estado !== 'A' ? ' (inactivo)' : '') + '</option>';
        }).join(''));
        $('#usSucursal').html(state.sucursales.map(function (s) { return '<option value="' + s.Id + '">' + A.esc(s.Texto) + '</option>'; }).join(''))
            .val(String(u && u.IdSucursal ? u.IdSucursal : (state.sucursales[0] ? state.sucursales[0].Id : '')));
        $('#usId').val(u ? u.Id : '').prop('readonly', !!u);
        $('#usIdAyuda').toggle(!u);
        $('#usNombres').val(u ? u.Nombres : '');
        $('#usApellidos').val(u ? u.Apellidos : '');
        $('#usGrupo').val(u ? u.IdGrupo : '');
        $('#usDashboard').val(u ? String(u.IdDashboard || 0) : '0');
        $('#usCaducidad').val(u ? u.Caducidad : 90);
        $('#usEmail').val(u ? u.Email : '');
        $('#usTelefono').val(u ? u.Telefono : '');
        $('#usCelular').val(u ? u.Celular : '');
        $('#usDocumento').val(u ? (u.Documento || '') : '');
        $('#usResponsable').prop('checked', u ? u.Responsable : false);
        $('#usInfo').toggleClass('d-none', !u).html(u ? 'Último ingreso: ' + A.esc(A.relativa(u.UltimoIngreso)) + ' · Clave cambiada: ' + A.esc(A.fecha(u.CambioClave, false) || '—')
            + ' · Modificado por ' + A.esc(u.Usuario) + ' el ' + A.esc(A.fecha(u.Fecha)) : '');
        A.modal('usModal').show();
        setTimeout(function () { $(u ? '#usNombres' : '#usId').trigger('focus'); }, 300);
    }

    function guardar() {
        A.limpiarErrores($('#usForm'));
        var d = {
            Id: $.trim($('#usId').val()), Nombres: $.trim($('#usNombres').val()), Apellidos: $.trim($('#usApellidos').val()),
            IdGrupo: $('#usGrupo').val(), IdDashboard: +$('#usDashboard').val() || 0, Caducidad: parseInt($('#usCaducidad').val(), 10) || 0,
            Email: $.trim($('#usEmail').val()), Telefono: $.trim($('#usTelefono').val()), Celular: $.trim($('#usCelular').val()),
            Documento: $.trim($('#usDocumento').val()),
            IdSucursal: +$('#usSucursal').val() || 0,
            Responsable: $('#usResponsable').is(':checked')
        };
        if (!d.Id) return A.marcarError($('#usId'), 'Ingrese el usuario.');
        if (!/^[A-Za-z0-9._]{3,20}$/.test(d.Id)) return A.marcarError($('#usId'), 'De 3 a 20 caracteres: letras, números, punto o guion bajo.');
        if (!d.Nombres) return A.marcarError($('#usNombres'), 'Ingrese los nombres.');
        if (!d.Apellidos) return A.marcarError($('#usApellidos'), 'Ingrese los apellidos.');
        if (!d.IdGrupo) return A.marcarError($('#usGrupo'), 'Seleccione el grupo.');
        if (d.Caducidad < 1) return A.marcarError($('#usCaducidad'), 'Ingrese los días de vigencia.');
        if (d.Email && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(d.Email)) return A.marcarError($('#usEmail'), 'El correo no es válido.');
        if (d.Documento && !(/^[0-9-]+$/.test(d.Documento) && [9, 14].indexOf(d.Documento.replace(/-/g, '').length) >= 0))
            return A.marcarError($('#usDocumento'), 'Debe ser un DUI (00000000-0) o un NIT de 14 dígitos.');
        var nuevo = !state.editando;
        A.ocupado($('#usGuardar'), api('Guardar', { usuario: d, nuevo: nuevo }).done(function (r) {
            if (!r.Ok) { A.error(r); return; }
            A.modal('usModal').hide();
            if (nuevo) swal({ title: 'Usuario creado', text: r.Mensaje + '\nPídale que la cambie al iniciar sesión.', type: 'success' });
            else showNotification(1, 'success', r.Mensaje);
            cargar();
        }).fail(A.falla));
    }

    function accion(metodo, datos, titulo, texto, boton, alTerminar) {
        A.confirmar(titulo, texto, boton, function () {
            api(metodo, datos).done(function (r) {
                if (!r.Ok) { A.error(r); return; }
                if (alTerminar) alTerminar(r); else showNotification(1, 'success', r.Mensaje);
                cargar();
            }).fail(A.falla);
        });
    }

    /* ---------- eventos ---------- */
    $('#usNuevo').on('click', function () { abrir(null); });
    $('#usuarios').on('click', '.us-desbloquear-id', function () { desbloquear(String($(this).data('usuario'))); });
    $('#usForm').on('submit', function (ev) { ev.preventDefault(); guardar(); });
    $('#usId').on('input', function () { var v = $(this).val().replace(/\s+/g, '').toLowerCase(); if (v !== $(this).val()) $(this).val(v); });
    $('#usBuscar').on('input', function () { state.texto = $.trim($(this).val()); pintar(); });
    $('#usFiltroGrupo').on('change', function () { state.grupo = $(this).val(); pintar(); });
    $('#usFiltroEstado').on('change', function () { state.estado = $(this).val(); pintar(); });
    $('#usFilas')
        .on('click', '.us-editar', function () { abrir(usuarioDe(this)); })
        .on('click', '.us-desbloquear', function () { desbloquear(usuarioDe(this).Id); })
        .on('click', '.us-clave', function () {
            var u = usuarioDe(this);
            accion('RestablecerClave', { usuario: u.Id }, 'Restablecer clave', '¿Restablecer la clave de ' + titulo(u.Nombres) + '?\nLa nueva clave será su usuario: ' + u.Id + '.', 'Restablecer',
                function (r) { swal({ title: 'Clave restablecida', text: r.Mensaje, type: 'success' }); });
        })
        .on('click', '.us-estado', function () {
            var u = usuarioDe(this), activar = u.Estado !== 'A';
            accion('Estado', { usuario: u.Id, activo: activar }, activar ? 'Activar usuario' : 'Inactivar usuario',
                activar ? '¿Activar a ' + titulo(u.Nombres) + '? Podrá volver a iniciar sesión.' : '¿Inactivar a ' + titulo(u.Nombres) + '? Ya no podrá iniciar sesión.',
                activar ? 'Activar' : 'Inactivar');
        })
        .on('click', '.us-eliminar', function () {
            var u = usuarioDe(this);
            accion('Eliminar', { usuario: u.Id }, 'Eliminar usuario', '¿Eliminar a ' + titulo(u.Nombres + ' ' + u.Apellidos) + '?\nSi ya trabajó en el sistema no se podrá: inactívelo en su lugar.', 'Eliminar');
        });

    // form_confNuevoUsuario.aspx y form_confUsuarioPerfilEdit.aspx redirigen aquí con ?nuevo=1 o ?user=
    cargar().done(function () {
        var pedido = String($('#usuarios').data('usuario') || ''), u = pedido ? $.grep(state.usuarios, function (x) { return x.Id === pedido; })[0] : null;
        if (u) abrir(u); else if ($('#usuarios').data('nuevo')) abrir(null);
    });
})(jQuery);
