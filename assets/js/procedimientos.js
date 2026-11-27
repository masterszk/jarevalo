/* Atención de procedimientos – jQuery + AJAX contra WebMethods de Registros/frm_Procedimientos.aspx
   Cada especialista ve solo sus citas (el servidor toma el especialista del usuario).
   «Sigue» es el paciente con más tiempo de espera, calculado en el servidor.
   La cola del día se actualiza cada 10 segundos; el cronómetro de atención, cada segundo. */
(function ($) {
    'use strict';

    var URL = 'Registros/frm_Procedimientos.aspx/';
    var REFRESCO_MS = 10000;
    var ESTADOS = {
        I: { texto: 'En atención', clase: 'bg-success' },
        S: { texto: 'En sala', clase: 'bg-info text-dark' },
        '': { texto: 'Programado', clase: 'bg-light text-dark border' }
    };

    // La página se carga con AjaxLink: si se vuelve a abrir, se detienen los temporizadores anteriores
    if (window.__procAtencion) {
        clearInterval(window.__procAtencion.cola);
        clearInterval(window.__procAtencion.reloj);
    }

    var state = {
        cola: [],
        actual: null,         // ProcedimientoDto en pantalla
        catalogo: [],
        desfaseMs: 0,         // hora del servidor - hora del navegador
        ocupado: false,
        diagTimer: null,
        diagSucio: false,
        cargandoCola: false
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
    function dinero(n) { return '$ ' + Number(n || 0).toFixed(2); }
    function iniciales(nombre) {
        var p = $.trim(nombre || '').split(/\s+/);
        return ((p[0] || '').charAt(0) + (p.length > 2 ? p[2] : (p[1] || '')).charAt(0)).toUpperCase();
    }
    function parseIso(s) {
        var m = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})$/.exec(s || '');
        return m ? new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +m[6]) : null;
    }
    function dos(n) { return (n < 10 ? '0' : '') + n; }
    function espera(min) { return min >= 60 ? Math.floor(min / 60) + ' h ' + (min % 60) + ' min' : min + ' min'; }
    function activo() { return document.getElementById('procAtencion') !== null; }

    /* ---------- inicio ---------- */
    function iniciar() {
        api('Inicio', { user: usuario() }).done(function (r) {
            if (!r.Ok) { sinEspecialista(r.Mensaje); return; }
            state.catalogo = r.Catalogo || [];
            $('#paEspecialistaNombre').text(r.EspecialistaNombre);

            renderCatalogo('');
            cargarCola();
            window.__procAtencion = {
                cola: setInterval(function () { if (!activo()) return detener(); cargarCola(); }, REFRESCO_MS),
                reloj: setInterval(function () { if (!activo()) return detener(); reloj(); }, 1000)
            };
        }).fail(falla);
    }

    // El usuario no es especialista: no hay cola que mostrar
    function sinEspecialista(mensaje) {
        $('#paEspecialistaNombre').text('Sin especialista asignado');
        $('#paVacio h5').text('Pantalla solo para especialistas');
        $('#paVacioTexto').text(mensaje);
        $('#paLlamarSiguiente').addClass('d-none');
        $('#paCola').html('<div class="text-center text-muted py-4">Sin cola asignada.</div>');
    }

    function detener() {
        if (!window.__procAtencion) return;
        clearInterval(window.__procAtencion.cola);
        clearInterval(window.__procAtencion.reloj);
        window.__procAtencion = null;
    }

    /* ---------- cola del día ---------- */
    function cargarCola() {
        if (state.cargandoCola) return;
        state.cargandoCola = true;
        $('#paCargando').removeClass('d-none');

        api('ObtenerCola', { user: usuario() }).done(function (r) {
            if (!r.Ok) { showNotification(1, 'error', r.Mensaje); return; }
            var srv = parseIso(r.HoraServidor);
            if (srv) state.desfaseMs = srv.getTime() - Date.now();
            state.cola = r.Items || [];
            if (srv) $('#paActualizado').text('Actualizado ' + horaDe(srv, true));
            renderCola();
            sincronizarActual();
        }).fail(falla).always(function () {
            state.cargandoCola = false;
            $('#paCargando').addClass('d-none');
        });
    }

    // Paciente con más tiempo de espera (marcado por el servidor)
    function siguiente() {
        return $.grep(state.cola, function (c) { return c.Sigue; })[0];
    }

    function renderCola() {
        var $c = $('#paCola').empty();
        var sig = siguiente();

        $('#paColaNum').text(state.cola.length);
        $('#paLlamarSiguiente').prop('disabled', !sig);
        $('#paVacioTexto').text(sig
            ? 'Siguiente: ' + sig.Paciente + ' (cita ' + sig.Hora + (sig.EsperaMin > 0 ? ', espera ' + espera(sig.EsperaMin) : '') + ').'
            : 'No hay más pacientes en la cola de hoy.');

        if (!state.cola.length) {
            $c.html('<div class="text-center text-muted py-4"><i class="bx bx-calendar-check fs-3 d-block mb-1"></i>Sin citas pendientes para hoy.</div>');
            return;
        }

        $.each(state.cola, function (_, c) {
            var est = ESTADOS[c.Estado] || ESTADOS[''];
            var esActual = state.actual && state.actual.IdProcedimiento === c.IdProcedimiento && c.Estado === 'I';
            var badges = '<span class="badge ' + est.clase + '">' + est.texto + '</span>';
            if (c.Sigue) badges += ' <span class="badge bg-warning text-dark">Sigue</span>';
            if (c.Atrasada) badges += ' <span class="badge bg-danger-subtle text-danger border border-danger-subtle">Atrasado</span>';

            // Llamar a otro paciente fuera de turno (por ejemplo, si el que sigue no está presente)
            var boton = c.Estado === 'I' ? '' :
                '<button type="button" class="btn btn-sm ' + (c.Sigue ? 'btn-success' : 'btn-outline-secondary') + ' pa-llamar" data-cita="' + c.IdCita + '"><i class="bx bx-bell"></i> Llamar</button>';

            $c.append(
                '<div class="pa-item' + (esActual ? ' pa-item-actual' : '') + (c.Sigue ? ' pa-item-sigue' : '') + '">' +
                '  <div class="pa-hora">' + esc(c.Hora) + '</div>' +
                '  <div class="pa-item-cuerpo">' +
                '    <div class="fw-semibold">' + esc(c.Paciente) + '</div>' +
                (c.FechaNacimiento ? '    <div class="small text-muted"><i class="bx bx-cake"></i> ' + esc(c.FechaNacimiento) + (c.Edad ? ' · ' + esc(c.Edad) + ' años' : '') + '</div>' : '') +
                (c.EstadoCita === 'Reprogramada' ? '    <div><span class="badge bg-warning text-dark">Reprogramada</span></div>' : '') +
                '    <div class="small text-muted text-truncate" title="' + esc(c.Tratamientos) + '">' + esc(c.Tratamientos || c.TipoCita) + '</div>' +
                (c.EsperaMin > 0 ? '    <div class="small pa-espera"><i class="bx bx-time"></i> Espera ' + espera(c.EsperaMin) + '</div>' : '') +
                '    <div class="mt-1">' + badges + '</div>' +
                '  </div>' +
                '  <div class="pa-item-accion">' + boton + '</div>' +
                '</div>');
        });
    }

    // Muestra el procedimiento en atención; recarga el detalle solo si cambió
    function sincronizarActual() {
        var elegido = $.grep(state.cola, function (c) { return c.Estado === 'I'; })[0];

        if (!elegido) {
            if (state.actual) mostrarVacio();
            return;
        }
        if (!state.actual || state.actual.IdProcedimiento !== elegido.IdProcedimiento)
            cargarProcedimiento(elegido.IdProcedimiento);
    }

    /* ---------- paciente en atención ---------- */
    function cargarProcedimiento(id) {
        api('ObtenerProcedimiento', { procedimiento: id, user: usuario() }).done(function (r) {
            if (!r.Ok) { showNotification(1, 'error', r.Mensaje); return; }
            var cambio = !state.actual || state.actual.IdProcedimiento !== r.IdProcedimiento;
            state.actual = r;
            renderActual(cambio);
            renderCola();
        }).fail(falla);
    }

    function mostrarVacio() {
        guardarDiagnosticoPendiente();
        state.actual = null;
        $('#paActual, #paDetalle').addClass('d-none');
        $('#paVacio').removeClass('d-none');
        $('#paFinalizar').prop('disabled', true);
        renderCola();
    }

    function renderActual(cambioPaciente) {
        var a = state.actual;
        $('#paVacio').addClass('d-none');
        $('#paActual, #paDetalle').removeClass('d-none');
        $('#paFinalizar').prop('disabled', false);

        $('#paIniciales').text(iniciales(a.Paciente));
        $('#paPaciente').text(a.Paciente);
        $('#paTipoCita').text(a.TipoCita || 'Cita');
        $('#paHoraCita').text(a.HoraCita);
        $('#paEspecialistaActual').text(a.Especialista);
        $('#paDocumento').text(a.Documento || '—');
        $('#paNacimiento').text(a.FechaNacimiento || '—');
        $('#paEdad').text(a.Edad ? a.Edad + ' años' : '—');
        $('#paSexo').text(a.Sexo || '—');      // contacto, emergencia y dirección ya no se muestran en esta pantalla
        $('#paComentarios').text(a.Comentarios);
        $('#paComentariosFila').toggleClass('d-none', !a.Comentarios);

        renderTratamientos();
        renderHistorial();

        // No se pisa lo que el especialista está escribiendo
        if (cambioPaciente || !state.diagSucio) {
            $('#paDiagnostico').val(a.Diagnostico);
            state.diagSucio = false;
            $('#paDiagEstado').text('Se guarda automáticamente.');
        }
        reloj();
    }

    function renderTratamientos() {
        var a = state.actual, $t = $('#paTratamientos').empty();
        if (!a.Tratamientos.length)
            $t.html('<tr><td colspan="3" class="text-center text-muted py-3">Sin tratamientos. Use «Agregar tratamiento».</td></tr>');
        $.each(a.Tratamientos, function (_, t) {
            // con descuento del tratamiento: precio tachado, precio con descuento y el %; sin descuento, solo el precio
            var valor = t.Descuento > 0
                ? '<span class="text-muted text-decoration-line-through small me-1">' + dinero(t.Valor) + '</span>' + dinero(t.Valor - t.MontoDescuento)
                  + '<div class="small text-success">-' + Number(t.Descuento) + ' %</div>'
                : dinero(t.Valor);
            $t.append('<tr><td>' + esc(t.Descripcion) + '</td><td class="text-end">' + valor + '</td>' +
                '<td class="text-center"><button type="button" class="btn btn-sm btn-outline-danger pa-quitar" data-item="' + t.Id + '" aria-label="Quitar ' + esc(t.Descripcion) + '"><i class="bx bx-trash"></i></button></td></tr>');
        });
        $('#paTotal').html(dinero(a.Total) + (a.Descuento > 0 ? '<div class="small text-success fw-normal">Descuento -' + dinero(a.Descuento) + '</div>' : ''));
    }

    function renderHistorial() {
        var h = state.actual.Historial || [], $h = $('#paHistorial').empty();
        $('#paHistorialNum').text(h.length);
        if (!h.length) { $h.html('<div class="text-center text-muted py-4">Primera visita: el paciente no tiene procedimientos anteriores.</div>'); return; }
        $.each(h, function (_, p) {
            $h.append(
                '<div class="pa-hist">' +
                '  <div class="d-flex justify-content-between flex-wrap gap-2"><strong>' + esc(p.Fecha) + '</strong><span class="text-muted small">' + esc(p.Especialista) + ' · #' + p.IdProcedimiento + '</span></div>' +
                '  <div class="small mt-1"><i class="bx bx-list-check"></i> ' + esc(p.Tratamientos || 'Sin tratamientos') + ' <span class="text-muted">(' + dinero(p.Total) + ')</span></div>' +
                (p.Diagnostico ? '  <div class="small text-muted mt-1 pa-hist-diag">' + esc(p.Diagnostico) + '</div>' : '') +
                '</div>');
        });
    }

    function reloj() {
        var a = state.actual;
        if (!a) return;
        var inicio = parseIso(a.InicioAtencion);
        if (!inicio) { $('#paCronometro').text('--:--'); return; }
        var seg = Math.max(0, Math.floor((Date.now() + state.desfaseMs - inicio.getTime()) / 1000));
        var h = Math.floor(seg / 3600), m = Math.floor(seg / 60) % 60, s = seg % 60;
        $('#paCronometro').text((h ? h + ':' + dos(m) : dos(m)) + ':' + dos(s));
    }

    /* ---------- acciones ---------- */
    function ejecutar(metodo, datos, $btn) {
        if (state.ocupado) return $.Deferred().reject().promise();
        state.ocupado = true;
        if ($btn) $btn.prop('disabled', true);
        datos.user = usuario();
        return api(metodo, datos).then(function (r) {
            if (!r.Ok) { showNotification(1, 'warning', r.Mensaje); return $.Deferred().reject(r).promise(); }
            return r;
        }, function (xhr) { falla(xhr); return $.Deferred().reject().promise(); })
            .always(function () {
                state.ocupado = false;
                if ($btn) $btn.prop('disabled', false);
            });
    }

    function llamar(cita, $btn) {
        ejecutar('Llamar', { cita: cita }, $btn).done(function (r) {
            showNotification(1, 'success', r.Mensaje);
            state.actual = null;
            cargarCola();
        });
    }

    function recargarActual() {
        if (state.actual) cargarProcedimiento(state.actual.IdProcedimiento);
    }

    function guardarDiagnostico() {
        if (!state.actual) return $.Deferred().resolve().promise();
        clearTimeout(state.diagTimer);
        var id = state.actual.IdProcedimiento, texto = $('#paDiagnostico').val();
        $('#paDiagEstado').text('Guardando…');
        return api('GuardarDiagnostico', { procedimiento: id, diagnostico: texto, user: usuario() }).done(function (r) {
            if (!r.Ok) { $('#paDiagEstado').text(r.Mensaje); return; }
            if (state.actual && state.actual.IdProcedimiento === id) {
                state.actual.Diagnostico = texto;
                state.diagSucio = $('#paDiagnostico').val() !== texto;
            }
            $('#paDiagEstado').text('Guardado ' + horaDe(new Date()));
        }).fail(function () { $('#paDiagEstado').text('No se pudo guardar. Revise la conexión.'); });
    }

    function guardarDiagnosticoPendiente() {
        if (state.diagSucio && state.actual) guardarDiagnostico();
    }

    // Reprogramar, cambiar de especialista y cancelar se hacen en Facturación > Procedimientos (frm_ProcedimientosCurso.aspx)

    // Diálogo sin botones mientras el servidor trabaja
    function procesando(texto) {
        swal({
            title: 'Procesando…',
            text: '<div class="spinner-border text-success my-2" role="status"></div><div>' + esc(texto) + '</div>',
            html: true,
            showConfirmButton: false,
            showCancelButton: false,
            allowEscapeKey: false
        });
    }

    // Guarda el diagnóstico y finaliza (la factura queda pendiente de cobro en Caja).
    // No llama al siguiente: el especialista lo hace con "Llamar al siguiente" o "Llamar" en la cola.
    function finalizar() {
        var a = state.actual;
        if (!a || state.ocupado) return;
        if (!a.Tratamientos.length) { showNotification(1, 'warning', 'Agregue al menos un tratamiento antes de finalizar.'); return; }

        swal({
            title: 'Finalizar atención',
            text: a.Paciente + '\n' + a.Tratamientos.length + ' tratamiento(s) · Total ' + dinero(a.Total) +
                '\n\nSe guardará el diagnóstico y la factura quedará pendiente de cobro en Caja.',
            type: 'info',
            showCancelButton: true,
            confirmButtonText: 'Finalizar',
            cancelButtonText: 'Cancelar',
            confirmButtonColor: '#1A9608',
            closeOnConfirm: false
        }, function (ok) {
            if (!ok) return;
            clearTimeout(state.diagTimer);
            procesando('Guardando la atención de ' + a.Paciente + '…');
            ejecutar('Finalizar', { procedimiento: a.IdProcedimiento, diagnostico: $('#paDiagnostico').val() }, $('#paFinalizar'))
                .done(function (r) {
                    state.diagSucio = false;
                    state.actual = null;
                    swal.close();
                    showNotification(1, 'success', 'Atención finalizada: factura #' + r.Id + ' pendiente de cobro en Caja. Llame al siguiente paciente cuando esté listo.');
                    mostrarVacio();
                    cargarCola();
                })
                .fail(function () { swal.close(); });
        });
    }

    /* ---------- catálogo ---------- */
    function renderCatalogo(filtro) {
        var f = $.trim(filtro || '').toLowerCase(), $c = $('#paCatalogo').empty();
        var lista = $.grep(state.catalogo, function (t) { return !f || (t.Tratamiento || '').toLowerCase().indexOf(f) >= 0; });
        if (!lista.length) { $c.html('<div class="col-12 text-center text-muted py-4">No hay tratamientos que coincidan.</div>'); return; }
        $.each(lista, function (_, t) {
            $c.append(
                '<div class="col">' +
                '  <button type="button" class="card h-100 w-100 text-start pa-tratamiento" data-id="' + t.Id + '">' +
                '    <img src="' + esc(t.Imagen) + '" class="card-img-top" alt="" loading="lazy" onerror="this.style.display=\'none\'" />' +
                '    <span class="card-body p-2 d-block">' +
                '      <span class="d-block fw-semibold">' + esc(t.Tratamiento) + '</span>' +
                '      <span class="d-flex justify-content-between small mt-1"><span class="text-muted">' + t.DuracionMin + ' min</span>' + (t.Descuento > 0
                    ? '<span><span class="badge bg-success me-1">-' + Number(t.Descuento) + ' %</span><span class="text-muted text-decoration-line-through me-1">' + dinero(t.Precio) + '</span><strong>' + dinero(t.Precio - Math.round(t.Precio * t.Descuento) / 100) + '</strong></span>'
                    : '<strong>' + dinero(t.Precio) + '</strong>') + '</span>' +
                '    </span>' +
                '  </button>' +
                '</div>');
        });
    }

    /* ---------- eventos ---------- */
    $('#paCola').on('click', '.pa-llamar', function () { llamar($(this).data('cita'), $(this)); });

    // El servidor elige al paciente con más tiempo de espera
    $('#paLlamarSiguiente').on('click', function () {
        ejecutar('LlamarSiguiente', {}, $(this)).done(function (r) {
            showNotification(1, 'success', r.Mensaje);
            state.actual = null;
            cargarCola();
        });
    });

    $('#paTratamientos').on('click', '.pa-quitar', function () {
        if (!state.actual) return;
        ejecutar('QuitarTratamiento', { procedimiento: state.actual.IdProcedimiento, item: $(this).data('item') }, $(this))
            .done(recargarActual);
    });

    $('#paAgregar').on('click', function () {
        $('#paBuscarTratamiento').val('');
        renderCatalogo('');
        $('#paModalCatalogo').modal('show');
    });
    $('#paBuscarTratamiento').on('input', function () { renderCatalogo($(this).val()); });
    $('#paCatalogo').on('click', '.pa-tratamiento', function () {
        if (!state.actual) return;
        ejecutar('AgregarTratamiento', { procedimiento: state.actual.IdProcedimiento, tratamiento: $(this).data('id') }, $(this))
            .done(function (r) {
                showNotification(1, 'success', r.Mensaje);
                $('#paModalCatalogo').modal('hide');
                recargarActual();
            });
    });

    $('#paDiagnostico').on('input', function () {
        state.diagSucio = true;
        $('#paDiagEstado').text('Cambios sin guardar…');
        clearTimeout(state.diagTimer);
        state.diagTimer = setTimeout(guardarDiagnostico, 2000);
    });
    $('#paGuardarDiag').on('click', guardarDiagnostico);

    $('#paFinalizar').on('click', finalizar);

    iniciar();

})(jQuery);
