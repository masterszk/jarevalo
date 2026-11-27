/* Lista de expedientes – jQuery + AJAX contra WebMethods de Registros/frm_ListaExpedientes.aspx
   Búsqueda única (nombre, documento, celular o email) con paginación en el servidor y filtro por inicial del apellido. */
(function ($) {
    'use strict';

    var URL = 'Registros/frm_ListaExpedientes.aspx/';
    var ESPERA_BUSQUEDA_MS = 350;
    var formulario = window.ExpedienteForm.crear({ url: URL, form: '#exForm' });   // assets/js/expediente-form.js

    var state = {
        texto: '',
        letra: '',
        pagina: 1,
        total: 0,
        tamano: 25,
        filas: [],
        timer: null,
        consulta: 0,          // descarta respuestas de búsquedas anteriores
        reclamo: null,        // expediente del reclamo en edición
        procedimientos: [],
        guardando: false
    };

    /* ---------- utilidades ---------- */
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
    function esc(s) { return $('<div/>').text(s == null ? '' : String(s)).html(); }
    var soloDigitos = window.ExpedienteForm.soloDigitos;
    function titulo(s) {
        return String(s || '').toLowerCase().replace(/(^|\s)(\S)/g, function (m, a, b) { return a + b.toUpperCase(); });
    }
    function iniciales(n, a) { return ((n || '').charAt(0) + (a || '').charAt(0)).toUpperCase(); }
    function resaltar(texto) {
        var t = esc(texto);
        if (!state.texto || state.texto.length < 2) return t;
        var q = esc(state.texto).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
        return t.replace(new RegExp('(' + q + ')', 'ig'), '<mark>$1</mark>');
    }
    /* ---------- inicio ---------- */
    function iniciar() {
        if (typeof mtd_ValidateSession === 'function') mtd_ValidateSession();   // default.aspx
        cargarResumen();
        buscar();
        // con los países cargados, los teléfonos se muestran con el formato de su país
        formulario.cargarCatalogos().done(function () { if (state.filas && state.filas.length) renderFilas(); });
    }

    // "7000-0000" para El Salvador; "+1 (305) 555-0100" para otros países
    function telefono(e) {
        var p = formulario.pais(e.PaisTelefono);
        if (!p) return e.Celular;
        return window.ExpedienteForm.formatoTelefono(p, e.Celular, p.Iso2 !== 'SV');
    }

    function cargarResumen() {
        api('Inicio', { user: usuario() }).done(function (r) {
            if (!r.Ok) { showNotification(1, 'error', r.Mensaje); return; }
            $('#exTotal').text(r.Resumen.Total);
            $('#exNuevosMes').text(r.Resumen.NuevosMes);
            $('#exCitaHoy').text(r.Resumen.ConCitaHoy);
            $('#exActivos').text(r.Resumen.Activos90);

            var $l = $('#exLetras').empty();
            $l.append('<button type="button" class="btn btn-sm ' + (state.letra ? 'btn-outline-secondary' : 'btn-primary') + ' ex-letra" data-letra="">Todas</button>');
            $.each(r.Letras, function (_, x) {
                $l.append('<button type="button" class="btn btn-sm ' + (state.letra === x.Letra ? 'btn-primary' : 'btn-outline-secondary') +
                    ' ex-letra" data-letra="' + esc(x.Letra) + '" title="' + x.Cantidad + ' paciente(s)">' + esc(x.Letra) + '</button>');
            });
        }).fail(falla);
    }

    /* ---------- búsqueda ---------- */
    function buscar() {
        var id = ++state.consulta;
        $('#exFilas').html('<tr><td colspan="6" class="text-center py-4"><div class="spinner-border spinner-border-sm text-primary" role="status"></div> Buscando…</td></tr>');

        api('Buscar', { texto: state.texto, letra: state.letra, pagina: state.pagina, user: usuario() }).done(function (r) {
            if (id !== state.consulta) return;
            if (!r.Ok) { showNotification(1, 'error', r.Mensaje); $('#exFilas').empty(); return; }
            state.total = r.Total;
            state.tamano = r.Tamano;
            state.filas = r.Items;
            renderFilas();
            renderPaginas();
        }).fail(falla);
    }

    function renderFilas() {
        var $t = $('#exFilas').empty();
        var filtro = state.texto || state.letra;

        $('#exResultado').text(filtro
            ? state.total + ' paciente(s) encontrado(s)'
            : 'Mostrando los registrados o modificados más recientemente');

        if (!state.filas.length) {
            $t.html('<tr><td colspan="6" class="text-center text-muted py-5"><i class="bx bx-user-x fs-2 d-block mb-1"></i>' +
                'No se encontraron pacientes' + (state.texto ? ' para «' + esc(state.texto) + '»' : '') + '.' +
                '<div class="mt-2"><button type="button" class="btn btn-sm btn-primary ex-nuevo-vacio"><i class="bx bx-user-plus"></i> Registrar paciente nuevo</button></div></td></tr>');
            return;
        }

        $.each(state.filas, function (_, e) {
            var nombre = titulo(e.Nombres) + ' ' + titulo(e.Apellidos);
            var doc = e.Documento ? (e.TipoDocumento ? e.TipoDocumento + ' ' : '') + e.Documento : 'Sin documento';
            var proxima = e.ProximaCita
                ? '<span class="badge bg-success-subtle text-success border border-success-subtle"><i class="bx bx-calendar-check"></i> ' + esc(e.ProximaCita) + '</span>'
                : '<span class="text-muted">—</span>';

            $t.append(
                '<tr>' +
                '  <td>' +
                '    <div class="d-flex align-items-center gap-2">' +
                '      <div class="ex-avatar" aria-hidden="true">' + esc(iniciales(e.Nombres, e.Apellidos)) + '</div>' +
                '      <div class="min-w-0">' +
                '        <a href="javascript:;" class="fw-semibold ex-abrir" data-id="' + e.Id + '">' + resaltar(nombre) + '</a>' +
                '        <div class="small text-muted">#' + e.Id + ' · ' + resaltar(doc) + '</div>' +
                '        <div class="small text-muted d-md-none">' + resaltar(telefono(e)) + '</div>' +
                '      </div>' +
                '    </div>' +
                '  </td>' +
                '  <td class="d-none d-md-table-cell small">' +
                (e.Celular ? '<div><i class="bx bx-mobile"></i> ' + resaltar(telefono(e)) + '</div>' : '') +
                (e.Email ? '<div class="text-muted text-truncate ex-email" title="' + esc(e.Email) + '"><i class="bx bx-envelope"></i> ' + resaltar(e.Email) + '</div>' : '') +
                '  </td>' +
                '  <td class="d-none d-lg-table-cell small">' + (e.Edad ? esc(e.Edad) + ' años' : '—') + '<div class="text-muted">' + esc(titulo(e.Sexo)) + '</div></td>' +
                '  <td class="d-none d-lg-table-cell small">' + (e.UltimaVisita ? esc(e.UltimaVisita) + '<div class="text-muted">' + e.Visitas + ' visita(s)</div>' : '<span class="text-muted">Sin visitas</span>') + '</td>' +
                '  <td class="d-none d-md-table-cell small">' + proxima + '</td>' +
                '  <td class="text-end text-nowrap">' +
                '    <button type="button" class="btn btn-sm btn-outline-primary ex-abrir" data-id="' + e.Id + '" title="Abrir expediente" aria-label="Abrir expediente de ' + esc(nombre) + '"><i class="bx bx-folder-open"></i></button>' +
                '    <button type="button" class="btn btn-sm btn-outline-info ex-reclamo" data-id="' + e.Id + '" title="Registrar Garantía de Servicios" aria-label="Registrar Garantía de Servicios de ' + esc(nombre) + '"><i class="bx bx-comment-error"></i></button>' +
                '    <button type="button" class="btn btn-sm btn-outline-danger ex-eliminar" data-id="' + e.Id + '" title="Eliminar" aria-label="Eliminar expediente de ' + esc(nombre) + '"><i class="bx bx-trash"></i></button>' +
                '  </td>' +
                '</tr>');
        });
    }

    function renderPaginas() {
        var paginas = Math.max(1, Math.ceil(state.total / state.tamano));
        var desde = state.total ? (state.pagina - 1) * state.tamano + 1 : 0;
        var hasta = Math.min(state.pagina * state.tamano, state.total);
        $('#exPaginaTexto').text(state.total ? desde + '–' + hasta + ' de ' + state.total : '');

        var $p = $('#exPaginas').empty();
        if (paginas <= 1) return;
        function item(n, texto, deshabilitado, activo) {
            $p.append('<li class="page-item' + (deshabilitado ? ' disabled' : '') + (activo ? ' active' : '') + '">' +
                '<a class="page-link" href="javascript:;" data-pagina="' + n + '">' + texto + '</a></li>');
        }
        item(state.pagina - 1, '&laquo;', state.pagina === 1);
        var ini = Math.max(1, state.pagina - 2), fin = Math.min(paginas, ini + 4);
        ini = Math.max(1, fin - 4);
        for (var i = ini; i <= fin; i++) item(i, i, false, i === state.pagina);
        item(state.pagina + 1, '&raquo;', state.pagina === paginas);
    }

    /* ---------- nuevo expediente ---------- */
    function abrirNuevo(prellenar) {
        formulario.limpiar();

        // Si la búsqueda no encontró a nadie, se aprovecha lo escrito
        if (prellenar && state.texto) {
            var t = state.texto;
            if (/^[\d\-\s]+$/.test(t)) {
                if (soloDigitos(t).length === 8) $('#celular').val(soloDigitos(t)); else $('#documento').val(t);
            } else if (t.indexOf('@') > 0) $('#email').val(t);
            else $('#nombres').val(titulo(t));
        }
        $('#modalExpediente').modal('show');
    }

    function guardar() {
        if (state.guardando || !formulario.validar()) return;
        state.guardando = true;
        var $btn = $('#btnSave').prop('disabled', true);
        var apellidos = $.trim($('#apellidos').val());
        var paciente = { documento: $.trim($('#documento').val()), nombre: titulo($.trim($('#nombres').val()) + ' ' + apellidos) };

        api('Guardar', { expediente: formulario.datos(0), user: usuario() }).done(function (r) {
            if (!r.Ok) { showNotification(1, 'warning', r.Mensaje); return; }
            $('#modalExpediente').modal('hide');
            // Se muestra al paciente recién registrado
            state.texto = apellidos; state.letra = ''; state.pagina = 1;
            $('#exBuscar').val(apellidos);
            cargarResumen();
            buscar();
            ofrecerCita(paciente, r.Mensaje);
        }).fail(falla).always(function () {
            state.guardando = false;
            $btn.prop('disabled', false);
        });
    }

    // Después de registrar el expediente: ¿agendar la cita? Abre el asistente con el paciente ya seleccionado.
    function ofrecerCita(paciente, mensaje) {
        if (typeof window.swal !== 'function') { showNotification(1, 'success', mensaje); return; }
        swal({
            title: 'Expediente registrado',
            text: '¿Desea agendar una cita para ' + paciente.nombre + '?',
            type: 'success',
            showCancelButton: true,
            confirmButtonText: 'Sí, agendar cita',
            cancelButtonText: 'Ahora no',
            confirmButtonColor: '#0d8f9b'
        }, function (si) {
            if (!si) return;
            window.dpCitaPaciente = paciente;               // lo lee Registros/js/citas.js
            window.AjaxLink('Registros/frm_CitasAgenda.aspx');
        });
    }

    /* ---------- reclamos ---------- */
    function abrirReclamo(id) {
        var e = $.grep(state.filas, function (x) { return x.Id === id; })[0];
        state.reclamo = id;
        state.procedimientos = [];
        $('#reclamoPaciente').text(e ? titulo(e.Nombres) + ' ' + titulo(e.Apellidos) : '#' + id);
        $('#reclamo').val('');
        $('#reclamoCuenta').text('0');
        $('#reclamoEspecialista').text('');
        $('#procedimiento02').html('<option value="-1">Cargando…</option>').prop('disabled', true);
        $('#btnReclamo').prop('disabled', true);
        $('#modalReclamos').modal('show');

        api('ProcedimientosPaciente', { id: id, user: usuario() }).done(function (r) {
            if (!r.Ok) { showNotification(1, 'error', r.Mensaje); return; }
            state.procedimientos = r.Items;
            var $s = $('#procedimiento02').empty();
            if (!r.Items.length) {
                $s.html('<option value="-1">El paciente no tiene procedimientos finalizados</option>');
                return;
            }
            $s.append('<option value="-1">--Seleccione el procedimiento--</option>');
            $.each(r.Items, function (_, p) {
                $s.append($('<option/>').val(p.Id).text(p.Fecha + ' · ' + (p.Tratamientos || 'Sin tratamientos')));
            });
            $s.prop('disabled', false);
            $('#btnReclamo').prop('disabled', false);
        }).fail(falla);
    }

    function guardarReclamo() {
        var proc = parseInt($('#procedimiento02').val(), 10) || -1, texto = $.trim($('#reclamo').val());
        if (proc < 0) { showNotification(1, 'warning', 'Seleccione el <strong>procedimiento</strong>.'); return; }
        if (!texto) { showNotification(1, 'warning', 'Describa la <strong>Garantía de Servicios</strong>.'); return; }
        var $btn = $('#btnReclamo').prop('disabled', true);

        api('GuardarReclamo', { expediente: state.reclamo, procedimiento: proc, reclamo: texto, user: usuario() }).done(function (r) {
            if (!r.Ok) { showNotification(1, 'warning', r.Mensaje); return; }
            showNotification(1, 'success', r.Mensaje);
            $('#modalReclamos').modal('hide');
        }).fail(falla).always(function () { $btn.prop('disabled', false); });
    }

    /* ---------- eliminar ---------- */
    function eliminar(id) {
        var e = $.grep(state.filas, function (x) { return x.Id === id; })[0];
        var nombre = e ? titulo(e.Nombres) + ' ' + titulo(e.Apellidos) : '#' + id;
        swal({
            title: 'Eliminar expediente',
            text: '¿Eliminar el expediente de ' + nombre + '?\nSolo se pueden eliminar expedientes sin citas ni procedimientos.',
            type: 'warning',
            showCancelButton: true,
            confirmButtonText: 'Eliminar',
            cancelButtonText: 'Cancelar',
            confirmButtonColor: '#DD6B55',
            closeOnConfirm: true
        }, function (ok) {
            if (!ok) return;
            api('Eliminar', { id: id, user: usuario() }).done(function (r) {
                if (!r.Ok) { showNotification(1, 'warning', r.Mensaje); return; }
                showNotification(1, 'success', r.Mensaje);
                if (state.filas.length === 1 && state.pagina > 1) state.pagina--;
                cargarResumen();
                buscar();
            }).fail(falla);
        });
    }

    /* ---------- eventos ---------- */
    $('#exBuscar').on('input', function () {
        var v = $.trim($(this).val());
        clearTimeout(state.timer);
        state.timer = setTimeout(function () {
            if (v === state.texto) return;
            state.texto = v;
            state.pagina = 1;
            buscar();
        }, ESPERA_BUSQUEDA_MS);
    }).on('keydown', function (ev) {
        if (ev.key === 'Enter') { ev.preventDefault(); clearTimeout(state.timer); state.texto = $.trim($(this).val()); state.pagina = 1; buscar(); }
        if (ev.key === 'Escape') { $(this).val('').trigger('input'); }
    });

    $('#exLetras').on('click', '.ex-letra', function () {
        state.letra = String($(this).data('letra') || '');
        state.pagina = 1;
        $('#exLetras .ex-letra').removeClass('btn-primary').addClass('btn-outline-secondary');
        $(this).removeClass('btn-outline-secondary').addClass('btn-primary');
        buscar();
    });

    $('#exPaginas').on('click', '.page-link', function () {
        var n = parseInt($(this).data('pagina'), 10);
        if (!n || $(this).parent().hasClass('disabled') || n === state.pagina) return;
        state.pagina = n;
        buscar();
        $('html, body').animate({ scrollTop: $('#expedientes').offset().top - 80 }, 150);
    });

    $('#exFilas')
        .on('click', '.ex-abrir', function () { AjaxLink('Registros/frm_EditExpediente.aspx?id=' + $(this).data('id')); })
        .on('click', '.ex-reclamo', function () { abrirReclamo($(this).data('id')); })
        .on('click', '.ex-eliminar', function () { eliminar($(this).data('id')); })
        .on('click', '.ex-nuevo-vacio', function () { abrirNuevo(true); });

    $('#exNuevo').on('click', function () { abrirNuevo(false); });
    $('#btnSave').on('click', guardar);

    $('#procedimiento02').on('change', function () {
        var id = parseInt($(this).val(), 10);
        var p = $.grep(state.procedimientos, function (x) { return x.Id === id; })[0];
        $('#reclamoEspecialista').text(p ? 'Atendido por ' + p.Especialista : '');
    });
    $('#reclamo').on('input', function () { $('#reclamoCuenta').text($(this).val().length); });
    $('#btnReclamo').on('click', guardarReclamo);

    iniciar();

})(jQuery);
