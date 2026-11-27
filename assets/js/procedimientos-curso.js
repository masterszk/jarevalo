/* Procedimientos en curso de todos los especialistas – Facturacion/frm_ProcedimientosCurso.aspx
   Reprogramar, cambiar de especialista y cancelar (la atención la finaliza el especialista). La lista se actualiza cada 30 segundos. */
(function ($) {
    'use strict';

    var A = window.Admin, api = A.cliente('Facturacion/frm_ProcedimientosCurso.aspx');
    var REFRESCO_MS = 30000;
    var state = { items: [], especialistas: [], actual: null, ocupado: false };

    // La página se carga con AjaxLink: al volver a abrirla se detiene el temporizador anterior
    if (window.__procCurso) clearInterval(window.__procCurso);

    function activo() { return document.getElementById('pcFilas') !== null; }
    function dinero(n) { return '$ ' + Number(n || 0).toLocaleString('es-SV', { minimumFractionDigits: 2, maximumFractionDigits: 2 }); }
    function tiempo(min) {
        min = Math.max(0, min || 0);
        if (min >= 1440) { var d = Math.floor(min / 1440), h = Math.floor((min % 1440) / 60); return d + (d === 1 ? ' día' : ' días') + (h ? ' ' + h + ' h' : ''); }
        return min >= 60 ? Math.floor(min / 60) + ' h ' + (min % 60) + ' min' : min + ' min';
    }
    function porId(id) { return $.grep(state.items, function (x) { return x.IdProcedimiento === id; })[0]; }

    /* ---------- lista ---------- */
    function cargar(silencioso) {
        if (!silencioso) $('#pcFilas').html(A.cargando(7));
        return api('Lista').done(function (r) {
            if (!r.Ok) { A.error(r); $('#pcFilas').html(A.vacio(7, A.esc(r.Mensaje))); return; }
            state.items = r.Items || [];
            if (!state.especialistas.length) {
                state.especialistas = r.Especialistas || [];
                var $s = $('#pcEspecialista');
                $.each(state.especialistas, function (_, e) { $s.append($('<option/>').val(e.Id).text(e.Texto)); });
            }
            $('#pcActualizado').text('Actualizado ' + r.Actualizado);
            pintar();
        }).fail(A.falla);
    }

    function filtrados() {
        var q = A.normalizar($('#pcBuscar').val()), esp = +$('#pcEspecialista').val() || 0, est = $('#pcEstado').val();
        return $.grep(state.items, function (x) {
            if (esp && x.IdEspecialista !== esp) return false;
            if (est && x.Estado !== est) return false;
            return !q || A.normalizar([x.Paciente, x.Documento, x.Celular, x.Detalle, x.TipoCita].join(' ')).indexOf(q) >= 0;
        });
    }

    function pintar() {
        var lista = filtrados(), atencion = $.grep(state.items, function (x) { return x.Estado === 'I'; }).length;
        $('#pcConteo').text(lista.length + ' de ' + state.items.length + ' · ' + atencion + ' en atención');
        if (!lista.length) {
            $('#pcFilas').html(A.vacio(7, state.items.length ? 'Ningún procedimiento coincide con los filtros.' : 'No hay procedimientos en curso.'));
            return;
        }
        $('#pcFilas').html(lista.map(function (x) {
            var enAtencion = x.Estado === 'I';
            var estado = enAtencion
                ? '<span class="badge bg-success">En atención</span><div class="ad-ayuda">desde ' + A.esc(x.InicioAtencion) + ' · ' + tiempo(x.Minutos) + '</div>'
                : '<span class="badge bg-info text-dark">En sala</span><div class="ad-ayuda">espera ' + tiempo(x.Minutos) + '</div>';
            return '<tr data-id="' + x.IdProcedimiento + '">'
                + '<td><div class="fw-semibold">' + A.esc(x.Paciente) + '</div><div class="ad-ayuda">' + A.esc(x.Documento || x.Celular || ('Expediente #' + x.IdExpediente)) + '</div></td>'
                + '<td>' + A.esc(x.Especialista) + '</td>'
                + '<td class="text-nowrap">' + (x.HoraCita ? A.esc(x.HoraCita) : '<span class="text-muted">Sin hora</span>')
                + '<div class="ad-ayuda">' + A.esc(x.Fecha) + (x.DeOtroDia ? ' <span class="badge bg-warning text-dark">Día anterior</span>' : '') + '</div>'
                + (x.TipoCita ? '<div class="ad-ayuda">' + A.esc(x.TipoCita) + '</div>' : '') + '</td>'
                + '<td>' + estado + '</td>'
                + '<td class="small">' + (x.Tratamientos ? A.esc(x.Detalle) : '<span class="text-muted">Sin tratamientos</span>') + '</td>'
                + '<td class="text-end fw-medium">' + dinero(x.Total) + '</td>'
                + '<td class="text-end text-nowrap">'
                + '<div class="dropdown">'
                + '<button type="button" class="btn btn-sm btn-outline-secondary dropdown-toggle" data-bs-toggle="dropdown" aria-expanded="false"><i class="bx bx-cog"></i> Acciones</button>'
                + '<ul class="dropdown-menu dropdown-menu-end">'
                + '<li><a class="dropdown-item pc-reprogramar" href="javascript:;"><i class="bx bx-calendar"></i> Reprogramar</a></li>'
                + '<li><a class="dropdown-item pc-especialista" href="javascript:;"><i class="bx bx-group"></i> Cambiar especialista</a></li>'
                + '<li><hr class="dropdown-divider"></li>'
                + '<li><a class="dropdown-item text-danger pc-cancelar" href="javascript:;"><i class="bx bx-x-circle"></i> Cancelar cita</a></li>'
                + '</ul></div></td></tr>';
        }).join(''));
    }

    /* ---------- acciones ---------- */
    // Diálogo sin botones mientras el servidor trabaja
    function procesando(texto) {
        swal({
            title: 'Procesando…',
            text: '<div class="spinner-border text-success my-2" role="status"></div><div>' + A.esc(texto) + '</div>',
            html: true, showConfirmButton: false, showCancelButton: false, allowEscapeKey: false
        });
    }

    function ejecutar(metodo, datos) {
        if (state.ocupado) return $.Deferred().reject().promise();
        state.ocupado = true;
        return api(metodo, datos).then(function (r) {
            if (!r.Ok) { swal.close(); A.error(r); return $.Deferred().reject(r).promise(); }
            return r;
        }, function (xhr) { swal.close(); A.falla(xhr); return $.Deferred().reject().promise(); })
            .always(function () { state.ocupado = false; });
    }

    function abrirReprogramar(x) {
        state.actual = x;
        $('#pcRepPaciente').text(x.Paciente + ' · ' + x.Especialista);
        var $f = $('#pcNuevaFecha');
        if (!$f[0]._flatpickr && $.fn.flatpickr) {
            $f.flatpickr({
                enableTime: true,
                time_24hr: false,               // se muestra en 12 h; el valor enviado sigue en 24 h (Y-m-d H:i)
                dateFormat: 'Y-m-d H:i',
                altInput: true,
                altFormat: 'd/m/Y h:i K',
                minDate: 'today',
                minTime: '08:00',
                maxTime: '17:30',
                minuteIncrement: 30
            });
        }
        if ($f[0]._flatpickr) $f[0]._flatpickr.clear(); else $f.val('');
        A.modal('pcModalReprogramar').show();
    }

    function reprogramar() {
        var x = state.actual, fecha = $.trim($('#pcNuevaFecha').val());
        if (!x) return;
        if (!fecha) { showNotification(1, 'warning', 'Seleccione la nueva fecha y hora.'); return; }
        A.ocupado($('#pcRepGuardar'), ejecutar('Reprogramar', { cita: x.IdCita, fecha: fecha }).done(function (r) {
            A.modal('pcModalReprogramar').hide();
            showNotification(1, 'success', r.Mensaje);
            cargar(true);
        }));
    }

    function abrirEspecialista(x) {
        state.actual = x;
        $('#pcEspPaciente').text(x.Paciente + ' · ahora con ' + x.Especialista);
        var $s = $('#pcNuevoEspecialista').empty();
        $.each(state.especialistas, function (_, e) { if (e.Id !== x.IdEspecialista) $s.append($('<option/>').val(e.Id).text(e.Texto)); });
        A.modal('pcModalEspecialista').show();
    }

    function cambiarEspecialista() {
        var x = state.actual, esp = +$('#pcNuevoEspecialista').val() || 0;
        if (!x) return;
        if (!esp) { showNotification(1, 'warning', 'Seleccione el especialista.'); return; }
        A.ocupado($('#pcEspGuardar'), ejecutar('CambiarEspecialista', { procedimiento: x.IdProcedimiento, especialista: esp }).done(function (r) {
            A.modal('pcModalEspecialista').hide();
            showNotification(1, 'success', r.Mensaje);
            cargar(true);
        }));
    }

    function cancelar(x) {
        swal({
            title: 'Cancelar cita',
            text: 'Se cancelará la atención y la cita de ' + x.Paciente + '. Escriba el motivo:',
            type: 'input', inputPlaceholder: 'Motivo de la cancelación', showCancelButton: true,
            confirmButtonText: 'Cancelar cita', cancelButtonText: 'Volver', confirmButtonColor: '#DD6B55', closeOnConfirm: false
        }, function (motivo) {
            if (motivo === false) return;
            if ($.trim(motivo).length < 5) { swal.showInputError('Escriba el motivo (al menos 5 caracteres).'); return; }
            procesando('Cancelando la cita de ' + x.Paciente + '…');
            ejecutar('Cancelar', { procedimiento: x.IdProcedimiento, motivo: motivo }).done(function (r) {
                swal.close();
                showNotification(1, 'success', r.Mensaje);
                cargar(true);
            });
        });
    }

    function detener() { if (window.__procCurso) { clearInterval(window.__procCurso); window.__procCurso = null; } }

    /* ---------- eventos ---------- */
    function fila(el) { return porId(+$(el).closest('tr').data('id')); }
    $('#pcFilas')
        .on('click', '.pc-reprogramar', function () { var x = fila(this); if (x) abrirReprogramar(x); })
        .on('click', '.pc-especialista', function () { var x = fila(this); if (x) abrirEspecialista(x); })
        .on('click', '.pc-cancelar', function () { var x = fila(this); if (x) cancelar(x); });
    $('#pcBuscar').on('input', pintar);
    $('#pcEspecialista, #pcEstado').on('change', pintar);
    $('#pcRefrescar').on('click', function () { A.ocupado($(this), cargar(), 'Actualizando…'); });
    $('#pcRepGuardar').on('click', reprogramar);
    $('#pcEspGuardar').on('click', cambiarEspecialista);

    cargar();
    window.__procCurso = setInterval(function () {
        if (!activo()) return detener();
        // no se recarga mientras hay un diálogo o un menú abierto
        if (state.ocupado || $('.modal.show, .sweet-alert:visible, #pcFilas .dropdown-menu.show').length) return;
        cargar(true);
    }, REFRESCO_MS);
})(jQuery);
