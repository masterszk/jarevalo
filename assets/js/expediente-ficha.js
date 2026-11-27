/* Ficha del paciente – jQuery + AJAX contra WebMethods de Registros/frm_EditExpediente.aspx
   Perfil con foto, edición de datos con aviso de cambios sin guardar e historial (citas, procedimientos, reclamos). */
(function ($) {
    'use strict';

    var URL = 'Registros/frm_EditExpediente.aspx/';
    var LISTA = 'Registros/frm_ListaExpedientes.aspx?app=1';
    var formulario = window.ExpedienteForm.crear({ url: URL, form: '#exForm' });   // assets/js/expediente-form.js
    var ESTADO_PROC = { F: 'Finalizado', I: 'En atención', S: 'En sala', C: 'Cancelado', R: 'Reprogramado' };

    var state = {
        id: parseInt($('#ficha').data('id'), 10) || 0,
        perfil: null,
        huella: '',          // datos tal como se cargaron, para detectar cambios
        guardando: false
    };

    /* ---------- utilidades ---------- */
    function usuario() { return $.trim($('#idUser').val() || ''); }   // usuario de la sesión (campo oculto de default.aspx)
    var api = formulario.api;
    function falla(xhr) { showNotification(1, 'error', 'Error de conexión (HTTP ' + xhr.status + ').'); }
    function esc(s) { return $('<div/>').text(s == null ? '' : String(s)).html(); }
    function multilinea(s) { return esc(s).replace(/\n/g, '<br>'); }
    function dinero(n) { return '$ ' + Number(n || 0).toFixed(2); }
    function titulo(s) {
        return String(s || '').toLowerCase().replace(/(^|\s)(\S)/g, function (m, a, b) { return a + b.toUpperCase(); });
    }
    function vacio(icono, texto) {
        return '<div class="text-center text-muted py-5"><i class="bx ' + icono + ' fs-2 d-block mb-1"></i>' + texto + '</div>';
    }
    function sucio() { return state.perfil && formulario.huella() !== state.huella; }

    /* ---------- carga ---------- */
    function iniciar() {
        if (typeof mtd_ValidateSession === 'function') mtd_ValidateSession();   // default.aspx
        if (!state.id) { $('#ficha').html(vacio('bx-error', 'No se indicó el expediente.')); return; }

        // Primero los catálogos y la ficha; luego se llena el formulario (antes se cruzaban y el municipio quedaba en blanco)
        $.when(formulario.cargarCatalogos(), api('Ficha', { id: state.id, user: usuario() })).done(function (_, ficha) {
            if (!ficha.Ok) { showNotification(1, 'error', ficha.Mensaje); $('#ficha').html(vacio('bx-error', esc(ficha.Mensaje))); return; }
            mostrarPerfil(ficha.Perfil, ficha.Resumen);
            formulario.llenar(ficha.Perfil).done(function () {
                state.huella = formulario.huella();
                marcarCambios();
            });
        }).fail(falla);

        cargarHistorial();
    }

    function mostrarPerfil(p, r) {
        state.perfil = p;
        var nombre = titulo(p.Nombres) + ' ' + titulo(p.Apellidos);
        $('#fiNombre').text(nombre);
        $('#fiDocumento').text('#' + p.Id + ' · ' + (p.Documento ? (p.TipoDocumentoTexto ? p.TipoDocumentoTexto + ' ' : '') + p.Documento : 'Sin documento'));
        $('#fiEtiquetas').html(
            (p.Edad ? '<span class="badge bg-light text-dark border">' + esc(p.Edad) + ' años</span>' : '') +
            (p.SexoTexto ? '<span class="badge bg-light text-dark border">' + esc(titulo(p.SexoTexto)) + '</span>' : '') +
            (p.PaisTexto ? '<span class="badge bg-light text-dark border"><i class="bx bx-globe"></i> ' + esc(p.PaisTexto) + '</span>' : '') +
            (p.PagosAdelantados > 0 ? '<span class="badge bg-primary" title="Pagado en caja sin cita: al agendar use &quot;Usar pago adelantado&quot;"><i class="bx bx-wallet"></i> $ '
                + Number(p.PagosAdelantados).toFixed(2) + ' pagados, pendiente de agendar</span>' : '') +
            (p.Registro ? '<span class="badge bg-light text-dark border">NRC ' + esc(p.Registro) + '</span>' : ''));
        mostrarFoto(p.Foto, p.Nombres, p.Apellidos);

        // teléfonos con el código y el formato de su país
        var pt = formulario.pais(p.PaisTelefono || p.Pais), codigo = pt ? pt.Codigo : '503';
        $('#fiCelular').text(p.Celular ? formulario.telefono(p.PaisTelefono, p.Celular) : '—');
        $('#fiEmail').text(p.Email || '—');
        $('#fiEmergencia').text(p.PersonaEmergencia ? p.PersonaEmergencia + (p.TelefonoEmergencia ? ' · ' + formulario.telefono(p.PaisTelefono, p.TelefonoEmergencia) : '') : '—');
        $('#fiUbicacion').text([p.Direccion, p.Ubicacion].filter(Boolean).join(', ') || '—');
        $('#fiLlamar').attr('href', p.Celular ? 'tel:+' + codigo + p.Celular : '#').toggleClass('disabled', !p.Celular);
        $('#fiWhatsapp').attr('href', p.Celular ? 'https://wa.me/' + codigo + p.Celular : '#').toggleClass('disabled', !p.Celular);
        $('#fiCorreo').attr('href', p.Email ? 'mailto:' + p.Email : '#').toggleClass('disabled', !p.Email);
        $('#fiCreado').text(p.Creado || '—');
        $('#fiModificado').text(p.Modificado);
        $('#fiModificadoFila').toggle(!!p.Modificado);

        if (r) {
            $('#fiCitas').text(r.Citas);
            $('#fiAtendidas').text(r.Atendidas);
            $('#fiCanceladas').text(r.Canceladas);
            $('#fiProcedimientos').text(r.Procedimientos);
            $('#fiReclamos').text(r.Reclamos);
            $('#fiUltima').text(r.UltimaVisita || 'Sin visitas');
            $('#fiProxima').html(r.ProximaCita ? '<span class="text-success">' + esc(r.ProximaCita) + '</span>' : 'Sin cita agendada');
        }
    }

    function mostrarFoto(foto, nombres, apellidos) {
        var hay = /^data:image\/(jpeg|png);base64,/.test(foto || '');
        $('#fiFoto').toggleClass('d-none', !hay).attr('src', hay ? foto : '');
        $('#fiIniciales').toggleClass('d-none', hay).text(((nombres || '').charAt(0) + (apellidos || '').charAt(0)).toUpperCase());
        $('#fiQuitarFoto').toggleClass('d-none', !hay);
    }

    /* ---------- historial ---------- */
    function cargarHistorial() {
        var espera = '<div class="text-center py-4"><div class="spinner-border spinner-border-sm text-primary" role="status"></div> Cargando…</div>';
        $('#fiListaCitas, #fiListaProc, #fiListaReclamos').html(espera);

        api('Historial', { id: state.id, user: usuario() }).done(function (h) {
            if (!h.Ok) { showNotification(1, 'error', h.Mensaje); $('#fiListaCitas, #fiListaProc, #fiListaReclamos').empty(); return; }
            renderCitas(h.Citas);
            renderProcedimientos(h.Procedimientos);
            renderReclamos(h.Reclamos);
        }).fail(falla);
    }

    function renderCitas(citas) {
        $('#fiNumCitas').text(citas.length);
        var $c = $('#fiListaCitas').empty();
        if (!citas.length) { $c.html(vacio('bx-calendar-x', 'El paciente no tiene citas registradas.')); return; }

        $.each(citas, function (i, c) {
            $c.append(
                '<div class="fi-linea' + (c.Futura ? ' fi-linea-futura' : '') + '">' +
                '  <div class="fi-linea-fecha"><strong>' + esc(c.Fecha) + '</strong><span>' + esc(c.Hora) + '</span></div>' +
                '  <div class="fi-linea-cuerpo">' +
                '    <div class="d-flex flex-wrap align-items-center gap-2">' +
                '      <span class="badge bg-' + esc(c.Color || 'secondary') + '">' + esc(c.Estado) + '</span>' +
                (c.Futura ? '<span class="badge bg-success-subtle text-success border border-success-subtle">Próxima</span>' : '') +
                '      <span class="fw-semibold">' + esc(c.TipoCita) + '</span>' +
                '      <span class="text-muted small"><i class="bx bx-user-pin"></i> ' + esc(c.Especialista) + '</span>' +
                '    </div>' +
                (c.Tratamientos ? '<div class="small mt-1"><i class="bx bx-list-check"></i> ' + esc(c.Tratamientos) + '</div>' : '') +
                (c.Comentarios ? '<div class="small text-muted mt-1">' + multilinea(c.Comentarios) + '</div>' : '') +
                '  </div>' +
                '</div>');
        });
    }

    function renderProcedimientos(procs) {
        $('#fiNumProc').text(procs.length);
        var $p = $('#fiListaProc').empty();
        if (!procs.length) { $p.html(vacio('bx-clipboard', 'El paciente no tiene procedimientos registrados.')); return; }

        $.each(procs, function (i, p) {
            var idc = 'fiProc' + p.Id, abierto = i === 0;
            var filas = $.map(p.Tratamientos, function (t) {
                return '<tr><td>' + esc(t.Descripcion) + '</td><td class="text-end">' + dinero(t.Valor) + '</td></tr>';
            }).join('');
            // Del registro clínico solo se muestra el diagnóstico
            var diagnostico = p.Diagnostico
                ? '<div class="fi-nota"><span>Diagnóstico</span>' + multilinea(p.Diagnostico) + '</div>'
                : '<p class="text-muted small mb-0">Sin diagnóstico registrado.</p>';

            $p.append(
                '<div class="accordion-item">' +
                '  <h2 class="accordion-header">' +
                '    <button class="accordion-button' + (abierto ? '' : ' collapsed') + '" type="button" data-bs-toggle="collapse" data-bs-target="#' + idc + '" aria-expanded="' + abierto + '">' +
                '      <span class="d-flex flex-wrap align-items-center gap-2 w-100 me-2">' +
                '        <strong>' + esc(p.Fecha) + '</strong>' +
                (p.Horario ? '<span class="text-muted small">' + esc(p.Horario) + '</span>' : '') +
                '        <span class="small"><i class="bx bx-user-pin"></i> ' + esc(p.Especialista) + '</span>' +
                '        <span class="badge ' + (p.Estado === 'F' ? 'bg-success' : 'bg-secondary') + '">' + esc(ESTADO_PROC[p.Estado] || p.Estado) + '</span>' +
                '        <span class="ms-auto fw-semibold">' + dinero(p.Total) + '</span>' +
                '      </span>' +
                '    </button>' +
                '  </h2>' +
                '  <div id="' + idc + '" class="accordion-collapse collapse' + (abierto ? ' show' : '') + '" data-bs-parent="#fiListaProc">' +
                '    <div class="accordion-body">' +
                '      <div class="small text-muted mb-2">#' + p.Id + (p.TipoCita ? ' · ' + esc(p.TipoCita) : '') + '</div>' +
                (filas ? '<table class="table table-sm mb-3"><thead><tr><th>Tratamiento</th><th class="text-end">Precio</th></tr></thead><tbody>' + filas +
                    '</tbody><tfoot><tr><th class="text-end">Total</th><th class="text-end">' + dinero(p.Total) + '</th></tr></tfoot></table>'
                    : '<p class="text-muted small">Sin tratamientos registrados.</p>') +
                diagnostico +
                '    </div>' +
                '  </div>' +
                '</div>');
        });
    }

    function renderReclamos(reclamos) {
        $('#fiNumReclamos').text(reclamos.length);
        var $r = $('#fiListaReclamos').empty();
        if (!reclamos.length) { $r.html(vacio('bx-happy', 'El paciente no tiene Garantías de Servicios registradas.')); return; }

        $.each(reclamos, function (_, x) {
            $r.append(
                '<div class="fi-linea">' +
                '  <div class="fi-linea-fecha"><strong>' + esc(x.Fecha.substr(0, 10)) + '</strong><span>' + esc(x.Fecha.substr(11)) + '</span></div>' +
                '  <div class="fi-linea-cuerpo">' +
                '    <div class="small text-muted mb-1"><i class="bx bx-user-pin"></i> ' + esc(x.Especialista) +
                (x.IdProcedimiento ? ' · procedimiento #' + x.IdProcedimiento + (x.FechaProcedimiento ? ' del ' + esc(x.FechaProcedimiento) : '') : '') +
                (x.Usuario ? ' · registrado por ' + esc(x.Usuario) : '') + '</div>' +
                '    <div>' + multilinea(x.Reclamo) + '</div>' +
                '  </div>' +
                '</div>');
        });
    }

    /* ---------- edición ---------- */
    function marcarCambios() {
        var hay = sucio();
        $('#fiSinGuardar').toggleClass('d-none', !hay);
        $('#fiGuardar, #fiGuardar2, #fiDescartar').prop('disabled', !hay || state.guardando);
    }

    function guardar() {
        if (state.guardando || !sucio()) return;
        if (!formulario.validar()) return;
        state.guardando = true;
        marcarCambios();

        api('Guardar', { expediente: formulario.datos(state.id), user: usuario() }).done(function (r) {
            if (!r.Ok) { showNotification(1, 'warning', r.Mensaje); return; }
            showNotification(1, 'success', r.Mensaje);
            state.huella = formulario.huella();
            // se recarga el perfil para ver la ubicación, la edad y la auditoría actualizadas
            api('Ficha', { id: state.id, user: usuario() }).done(function (f) { if (f.Ok) mostrarPerfil(f.Perfil, f.Resumen); });
        }).fail(falla).always(function () {
            state.guardando = false;
            marcarCambios();
        });
    }

    function descartar() {
        if (!state.perfil) return;
        formulario.limpiar();
        formulario.llenar(state.perfil).done(function () {
            state.huella = formulario.huella();
            marcarCambios();
        });
    }

    function volver() {
        if (!sucio()) { AjaxLink(LISTA); return; }
        swal({
            title: 'Cambios sin guardar',
            text: 'Hay cambios en los datos del paciente que no se han guardado. ¿Salir sin guardar?',
            type: 'warning',
            showCancelButton: true,
            confirmButtonText: 'Salir sin guardar',
            cancelButtonText: 'Seguir editando',
            confirmButtonColor: '#DD6B55'
        }, function (ok) { if (ok) AjaxLink(LISTA); });
    }

    /* ---------- foto ---------- */
    // Se reduce en el navegador para no subir fotos de varios MB; el servidor vuelve a validar y normalizar
    function reducir(archivo, lado) {
        var d = $.Deferred();
        var lector = new FileReader();
        lector.onerror = function () { d.reject('No se pudo leer el archivo.'); };
        lector.onload = function () {
            var img = new Image();
            img.onerror = function () { d.reject('El archivo no es una imagen válida.'); };
            img.onload = function () {
                var escala = Math.min(1, lado / Math.max(img.width, img.height));
                var c = document.createElement('canvas');
                c.width = Math.max(1, Math.round(img.width * escala));
                c.height = Math.max(1, Math.round(img.height * escala));
                var g = c.getContext('2d');
                g.fillStyle = '#fff';
                g.fillRect(0, 0, c.width, c.height);
                g.drawImage(img, 0, 0, c.width, c.height);
                d.resolve(c.toDataURL('image/jpeg', 0.9));
            };
            img.src = lector.result;
        };
        lector.readAsDataURL(archivo);
        return d.promise();
    }

    function subirFoto(archivo) {
        if (!archivo) return;
        if (!/^image\//.test(archivo.type)) { showNotification(1, 'warning', 'Seleccione una imagen (JPG o PNG).'); return; }
        if (archivo.size > 15 * 1024 * 1024) { showNotification(1, 'warning', 'La imagen es demasiado grande.'); return; }

        reducir(archivo, 640).then(function (dataUrl) {
            return api('GuardarFoto', { id: state.id, foto: dataUrl, user: usuario() });
        }).done(function (r) {
            if (!r.Ok) { showNotification(1, 'warning', r.Mensaje); return; }
            state.perfil.Foto = r.Mensaje;
            mostrarFoto(r.Mensaje, state.perfil.Nombres, state.perfil.Apellidos);
            showNotification(1, 'success', 'Foto actualizada.');
        }).fail(function (e) { if (typeof e === 'string') showNotification(1, 'warning', e); else falla(e); });
    }

    function quitarFoto() {
        swal({
            title: 'Quitar foto',
            text: '¿Quitar la foto del paciente?',
            type: 'warning',
            showCancelButton: true,
            confirmButtonText: 'Quitar',
            cancelButtonText: 'Cancelar',
            confirmButtonColor: '#DD6B55'
        }, function (ok) {
            if (!ok) return;
            api('QuitarFoto', { id: state.id, user: usuario() }).done(function (r) {
                if (!r.Ok) { showNotification(1, 'warning', r.Mensaje); return; }
                state.perfil.Foto = '';
                mostrarFoto('', state.perfil.Nombres, state.perfil.Apellidos);
                showNotification(1, 'success', r.Mensaje);
            }).fail(falla);
        });
    }

    /* ---------- eventos ---------- */
    $('#exForm').on('input change', 'input, select', function () { setTimeout(marcarCambios, 0); });
    $('#fiGuardar, #fiGuardar2').on('click', guardar);
    $('#fiDescartar').on('click', descartar);
    $('#fiVolver').on('click', volver);
    $('#fiArchivo').on('change', function () { subirFoto(this.files[0]); $(this).val(''); });
    $('#fiQuitarFoto').on('click', quitarFoto);
    $('#fiContacto').on('click', 'a.disabled', function (ev) { ev.preventDefault(); });

    // Ctrl+S guarda mientras la ficha está abierta
    $(document).off('keydown.ficha').on('keydown.ficha', function (ev) {
        if (!document.getElementById('ficha')) { $(document).off('keydown.ficha'); return; }
        if ((ev.ctrlKey || ev.metaKey) && (ev.key === 's' || ev.key === 'S')) { ev.preventDefault(); guardar(); }
    });

    iniciar();

})(jQuery);
