/* Agenda de citas (wizard) – jQuery + AJAX contra WebMethods de frm_CitasAgenda.aspx */
(function ($) {
    'use strict';

    // Horas en 12 h para mostrar (assets/js/utiles.js); esta página también se abre sola, sin utiles.js
    var hora12 = window.hora12 || function (texto) {
        return String(texto == null ? '' : texto).replace(/\b([01]\d|2[0-3]):([0-5]\d)\b/g, function (_, h, m) {
            h = +h;
            var h12 = h % 12 || 12;
            return (h12 < 10 ? '0' : '') + h12 + ':' + m + (h < 12 ? ' AM' : ' PM');
        });
    };

    var DIAS  = ['domingo','lunes','martes','miércoles','jueves','viernes','sábado'];
    var MESES = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    var TIPO_EXPRESS_ID = 2;   // solo para mostrar el aviso; el servidor es quien decide
    var IMG_BASE = (window.CITAS_URL || '').replace(/frm_CitasAgenda\.aspx.*$/i, '') + 'Content/img/';

    var state = {
        paso: 1,
        paciente: null,         // PacienteDto seleccionado
        resultados: [],
        lunes: null,
        profesionalId: 0,
        tipoCitaId: 0,
        tratamientos: [],
        seleccion: {},          // id -> tratamiento
        slot: null,             // { fecha, hora }
        reqId: 0
    };

    /* ---------- utilidades ---------- */
    function api(metodo, datos) {
        return $.ajax({
            type: 'POST',
            url: window.CITAS_URL + '/' + metodo,
            data: JSON.stringify(datos || {}),
            contentType: 'application/json; charset=utf-8',
            dataType: 'json'
        }).then(function (r) { return r.d; });
    }
    function usuario() { return $.trim($('#idUser').val() || ''); }   // usuario de la sesión (campo oculto de default.aspx)
    function pad(n) { return (n < 10 ? '0' : '') + n; }
    function fmtFecha(d) { return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()); }
    function parseFecha(s) { var p = s.split('-'); return new Date(+p[0], +p[1] - 1, +p[2]); }
    function lunesDe(d) { var x = new Date(d.getFullYear(), d.getMonth(), d.getDate()); x.setDate(x.getDate() - ((x.getDay() + 6) % 7)); return x; }
    function dinero(n) { return '$' + Number(n).toFixed(2); }
    function toast(msg, ok) {
        var $t = $('#toast').text(msg).toggleClass('ok', !!ok).prop('hidden', false);
        clearTimeout(toast._t);
        toast._t = setTimeout(function () { $t.prop('hidden', true); }, 4200);
    }
    function ids() { return Object.keys(state.seleccion).map(function (k) { return state.seleccion[k].Id; }); }
    function duracion() { return ids().reduce(function (a, id) { return a + state.seleccion[id].DuracionMin; }, 0); }
    // Precio con el descuento del tratamiento (Catálogos › Tratamientos); sin descuento, el precio normal
    function neto(t) { return t.Descuento > 0 ? t.Precio - Math.round(t.Precio * t.Descuento) / 100 : t.Precio; }
    function total() { return ids().reduce(function (a, id) { return a + neto(state.seleccion[id]); }, 0); }
    function etiquetaSlot() {
        var f = parseFecha(state.slot.fecha);
        return DIAS[f.getDay()] + ' ' + f.getDate() + ' ' + MESES[f.getMonth()] + ', ' + hora12(state.slot.hora);
    }

    /* ---------- wizard ---------- */
    function irAPaso(n, sinScroll) {
        state.paso = n;
        $('.step-panel').prop('hidden', true).filter('[data-step="' + n + '"]').prop('hidden', false);
        $('#steps li').each(function () {
            var s = +$(this).data('step');
            $(this).toggleClass('is-active', s === n).toggleClass('is-done', s < n);
            if (s === n) $(this).attr('aria-current', 'step'); else $(this).removeAttr('aria-current');
        });
        $('#btnAnterior').prop('hidden', n === 1);
        $('#btnSiguiente').prop('hidden', n === 4);
        $('#btnConfirmar').prop('hidden', n !== 4);
        $('#wizMsg').text('');
        if (n === 3) cargarSemana();
        if (n === 4) pintarConfirmacion();
        var el = document.getElementById('steps');
        if (!sinScroll && el && el.scrollIntoView) el.scrollIntoView({ block: 'start' });
    }

    function validarPaso(n) {
        if (n === 1 && !state.paciente) return 'Busque y seleccione un paciente para continuar.';
        if (n === 2 && !ids().length) return 'Seleccione al menos un tratamiento.';
        if (n === 3 && !state.tipoCitaId) return 'Seleccione el tipo de cita.';
        if (n === 3 && !state.profesionalId) return 'Seleccione el profesional.';
        if (n === 3 && !state.slot) return 'Elija un día y una hora en el calendario.';
        return '';
    }

    function siguiente() {
        var err = validarPaso(state.paso);
        if (err) { $('#wizMsg').text(err); return; }
        irAPaso(state.paso + 1);
    }

    function reiniciar() {
        state.paciente = null; state.resultados = []; state.seleccion = {}; state.slot = null; state.tipoCitaId = 0; state.profesionalId = 0;
        $('#selTipoCita').val('0'); $('#selProfesional').val('0'); $('#noteExpress').prop('hidden', true);
        $('#txtBuscar').val(''); $('#txtNotas').val(''); $('#busMsg').text(''); $('#lstPacientes').empty();
        sincronizarTarjetas(); actualizarBarra();
        irAPaso(1);
    }

    /* ---------- paso 1: pacientes ---------- */
    function buscar() {
        var termino = $.trim($('#txtBuscar').val()), tipo = +$('#selTipo').val();
        var $msg = $('#busMsg').text('');
        if (termino.length < 3) { $msg.text('Escriba al menos 3 caracteres.'); return $.Deferred().reject().promise(); }
        var $btn = $('#btnBuscar').prop('disabled', true).text('Buscando…');
        return api('BuscarPacientes', { tipo: tipo, termino: termino, user: usuario() }).done(function (r) {
            if (!r.Ok) { $msg.text(r.Mensaje); renderPacientes([]); return; }
            state.resultados = r.Pacientes;
            if (state.paciente && !r.Pacientes.some(function (p) { return p.Codigo === state.paciente.Codigo; })) state.paciente = null;
            renderPacientes(r.Pacientes);
            $msg.text(r.Mensaje || (r.Pacientes.length ? r.Pacientes.length + ' paciente(s) encontrado(s).' : ''));
        }).fail(function (xhr) {
            console.error('BuscarPacientes falló. HTTP ' + xhr.status + ' ' + xhr.statusText, xhr.responseText);
            $msg.text('Error de conexión (HTTP ' + xhr.status + '). Intente nuevamente.');
        }).always(function () { $btn.prop('disabled', false).text('Buscar'); });
    }

    function renderPacientes(lista) {
        var $ul = $('#lstPacientes').empty();
        if (!lista.length) { $ul.append($('<li class="pac-empty">').text('No se encontraron pacientes.')); return; }
        $.each(lista, function (i, p) {
            var sel = state.paciente && state.paciente.Codigo === p.Codigo;
            var meta = [p.Documento ? 'Doc.: ' + p.Documento : '', p.Telefono ? 'Tel.: ' + p.Telefono : ''].filter(Boolean).join(' · ');
            $ul.append($('<li>').append(
                $('<button type="button" class="pac">').toggleClass('is-selected', !!sel).attr({ 'data-i': i, 'aria-pressed': !!sel })
                    .append($('<span>').append($('<b>').text(p.Nombre), $('<small>').text(meta || 'Sin datos de contacto')))
                    .append($('<span class="sel">').text(sel ? '✓ Seleccionado' : 'Seleccionar'))
            ));
        });
    }

    /* ---------- paso 2: tratamientos ---------- */
    function renderTratamientos(lista) {
        var $g = $('#tratGrid').empty();
        $.each(lista, function (_, t) {
            var $img = $('<div class="trat-img" aria-hidden="true">').text('\u2756');
            if (t.Imagen) {
                $('<img alt="" loading="lazy">').attr('src', t.Imagen)
                    .on('error', function () { $(this).remove(); }).appendTo($img);
            }
            $g.append(
                $('<button type="button" class="trat">').attr({ 'data-id': t.Id, 'aria-pressed': 'false' })
                    .append($img)
                    .append($('<div class="trat-body">')
                        .append($('<span class="trat-name">').text(t.Tratamiento))
                        .append($('<div class="trat-meta">')
                            .append($('<span>').html('<b>' + t.DuracionMin + '</b> min'))
                            .append(t.Descuento > 0
                                ? $('<span>').append($('<span class="badge bg-success me-1">').text('-' + Number(t.Descuento) + ' %'),
                                    $('<s class="text-muted me-1">').text(dinero(t.Precio)), $('<b>').text(dinero(neto(t))))
                                : $('<b>').text(dinero(t.Precio))))
                        .append($('<span class="trat-cta">').text('+ Agregar')))
            );
        });
    }

    function toggleTratamiento(id) {
        var t = state.tratamientos.filter(function (x) { return x.Id === id; })[0];
        if (!t) return;
        if (state.seleccion[id]) delete state.seleccion[id]; else state.seleccion[id] = t;
        state.slot = null;                       // la duración cambió: se vuelve a elegir hora
        sincronizarTarjetas();
        actualizarBarra();
    }

    function sincronizarTarjetas() {
        $('#tratGrid .trat').each(function () {
            var on = !!state.seleccion[$(this).data('id')];
            $(this).toggleClass('is-on', on).attr('aria-pressed', on)
                .find('.trat-cta').text(on ? '✓ Agregado' : '+ Agregar');
        });
    }

    function actualizarBarra() {
        var n = ids().length;
        $('#barTrat').text(n
            ? n + (n === 1 ? ' tratamiento' : ' tratamientos') + ' · ' + duracion() + ' min · Total ' + dinero(total())
            : 'Aún no agrega tratamientos.');
    }

    /* ---------- paso 3: selector de mes (el actual y los 12 siguientes) ---------- */
    var MESES_LARGO = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    function dos(n) { return (n < 10 ? '0' : '') + n; }
    function llenarMeses() {
        var $s = $('#selMes').empty(), hoy = new Date();
        for (var i = 0; i <= 12; i++) {
            var m = new Date(hoy.getFullYear(), hoy.getMonth() + i, 1);
            $s.append($('<option>').val(m.getFullYear() + '-' + dos(m.getMonth() + 1)).text(MESES_LARGO[m.getMonth()] + ' ' + m.getFullYear()));
        }
    }
    // el mes que se ve: el del jueves de la semana (el mes con la mayoría de sus días)
    function sincronizarMes() {
        var j = new Date(state.lunes); j.setDate(j.getDate() + 3);
        var v = j.getFullYear() + '-' + dos(j.getMonth() + 1);
        $('#selMes option.fuera').remove();
        if (!$('#selMes option[value="' + v + '"]').length)
            $('#selMes').append($('<option class="fuera">').val(v).text(MESES_LARGO[j.getMonth()] + ' ' + j.getFullYear()));
        $('#selMes').val(v);
    }
    function irAMes(v) {
        var p = v.split('-'), primero = new Date(+p[0], +p[1] - 1, 1), hoy = new Date();
        var lunes = lunesDe(primero);
        if (primero.getDay() === 0 || primero.getDay() >= 5) lunes.setDate(lunes.getDate() + 7);   // el 1 cae vie–dom: la semana siguiente
        if (+p[0] === hoy.getFullYear() && +p[1] - 1 === hoy.getMonth()) lunes = lunesDe(hoy);    // mes en curso: la semana de hoy
        state.lunes = lunes;
        cargarSemana();
    }

    /* ---------- paso 3: calendario ---------- */
    function cargarSemana() {
        if ($('#selMes option').length) sincronizarMes();
        if (!state.tipoCitaId || !state.profesionalId) {
            $('#calGrid').attr('aria-busy', 'false').html('<div class="cal-empty" style="grid-column:1/-1">Seleccione el tipo de cita y el profesional para ver los horarios disponibles.</div>');
            return;
        }
        var miReq = ++state.reqId;
        $('#calGrid').attr('aria-busy', 'true').html('<div class="cal-empty" style="grid-column:1/-1">Cargando horarios…</div>');
        api('ObtenerSemana', { fecha: fmtFecha(state.lunes), profesionalId: state.profesionalId, duracionMin: duracion(), tipoCitaId: state.tipoCitaId })
            .done(function (sem) { if (miReq === state.reqId) renderSemana(sem); })
            .fail(function () {
                $('#calGrid').attr('aria-busy', 'false').html('<div class="cal-empty" style="grid-column:1/-1">No se pudo cargar la agenda. Intente de nuevo.</div>');
            });
    }

    function renderSemana(sem) {
        var hoy = fmtFecha(new Date());
        var $g = $('#calGrid').empty().attr('aria-busy', 'false');
        var primero = parseFecha(sem.Dias[0].Fecha), ultimo = parseFecha(sem.Dias[6].Fecha);
        $('#lblSemana').text(primero.getDate() + ' ' + MESES[primero.getMonth()] + ' – ' + ultimo.getDate() + ' ' + MESES[ultimo.getMonth()] + ' ' + ultimo.getFullYear());

        $.each(sem.Dias, function (_, d) {
            var f = parseFecha(d.Fecha);
            var $col = $('<div class="cal-col">').toggleClass('is-today', d.Fecha === hoy);
            $col.append($('<div class="cal-head">')
                .append($('<span class="dow">').text(DIAS[f.getDay()]))
                .append($('<span class="dnum">').text(f.getDate() + ' ' + MESES[f.getMonth()])));
            var $list = $('<div class="cal-slots">');
            $.each(d.Slots, function (_, s) {
                // data-hora va en 24 h (lo lee el servidor); el texto, en 12 h
                var $b = $('<button type="button" class="slot">').text(hora12(s.Hora)).attr({ 'data-fecha': d.Fecha, 'data-hora': s.Hora });
                if (!s.Disponible) $b.addClass('is-busy').prop('disabled', true).attr('aria-label', hora12(s.Hora) + ' no disponible');
                if (state.slot && state.slot.fecha === d.Fecha && state.slot.hora === s.Hora) $b.addClass('is-selected').attr('aria-pressed', 'true');
                $list.append($b);
            });
            $g.append($col.append($list));
        });
    }

    /* ---------- paso 4: confirmación ---------- */
    function pintarConfirmacion() {
        var $d = $('#confirmList').empty();
        function fila(k, v) { $d.append($('<div>').append($('<dt>').text(k), $('<dd>').text(v))); }
        var p = state.paciente;
        fila('Paciente', p.Nombre + (p.Documento ? ' · ' + p.Documento : ''));
        fila('Tipo de cita', $('#selTipoCita option:selected').text());
        fila('Profesional', $('#selProfesional option:selected').text());
        fila('Fecha y hora', etiquetaSlot());
        fila('Tratamientos', ids().map(function (id) { return state.seleccion[id].Tratamiento || ('Id ' + id); }).join(', '));
        fila('Duración', duracion() + ' min');
        fila('Total', dinero(total()));
    }

    // Cita guardada: aviso y regreso al calendario (la página se abre con AjaxLink desde frm_CitasCalendario)
    function citaCreada(mensaje) {
        var cuando = state.slot ? state.slot.fecha.split('-').reverse().join('/') + ' ' + hora12(state.slot.hora) : '';
        var texto = (mensaje || 'La cita fue agendada.') + (cuando ? '\n' + state.paciente.Nombre + ' · ' + cuando : '');
        function volver() {
            if (typeof window.AjaxLink === 'function') window.AjaxLink('Registros/frm_CitasCalendario.aspx');
            else reiniciar();
        }
        if (typeof window.swal === 'function') {
            swal({ title: 'Cita agendada', text: texto, type: 'success', confirmButtonText: 'Ir al calendario', confirmButtonColor: '#0d8f9b' }, volver);
        } else {
            toast(mensaje, true);
            volver();
        }
    }

    function confirmar() {
        var $btn = $('#btnConfirmar'), $msg = $('#wizMsg').text('');
        $btn.prop('disabled', true).text('Guardando…');
        api('CrearCita', {
            req: {
                ProfesionalId: state.profesionalId,
                TipoCitaId: state.tipoCitaId,
                Fecha: state.slot.fecha,
                Hora: state.slot.hora,
                TratamientoIds: ids(),
                PacienteCodigo: state.paciente.Codigo,
                Documento: state.paciente.Documento || '',
                PacienteNombre: state.paciente.Nombre,
                Notas: $.trim($('#txtNotas').val()),
                Usuario: usuario()
            }
        }).done(function (r) {
            if (r.Ok) { citaCreada(r.Mensaje); }
            else {
                $msg.text(r.Mensaje);
                if (/horario/i.test(r.Mensaje)) { state.slot = null; irAPaso(3); }
            }
        }).fail(function () {
            $msg.text('Error de conexión. Intente nuevamente.');
        }).always(function () { $btn.prop('disabled', false).text('Confirmar cita'); });
    }

    /* ---------- eventos ---------- */
    $(function () {
        state.lunes = lunesDe(new Date());

        $('#selTipo').on('change', function () {
            var doc = $(this).val() === '2';
            $('#lblBuscar').text(doc ? 'Número de documento' : 'Nombre del paciente');
            $('#txtBuscar').attr('maxlength', doc ? 20 : 100).val('').trigger('focus');
        });
        $('#btnBuscar').on('click', buscar);
        $('#txtBuscar').on('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); buscar(); } });
        $('#lstPacientes').on('click', '.pac', function () {
            state.paciente = state.resultados[+$(this).data('i')];
            renderPacientes(state.resultados);
            $('#wizMsg').text('');
        });

        $('#tratGrid').on('click', '.trat', function () { toggleTratamiento(+$(this).data('id')); });

        $('#calGrid').on('click', '.slot:not(:disabled)', function () {
            state.slot = { fecha: $(this).data('fecha'), hora: String($(this).data('hora')) };
            $('#calGrid .slot').removeClass('is-selected').removeAttr('aria-pressed');
            $(this).addClass('is-selected').attr('aria-pressed', 'true');
            $('#wizMsg').text('');
        });
        $('#btnPrev').on('click', function () { state.lunes.setDate(state.lunes.getDate() - 7); cargarSemana(); });
        $('#btnNext').on('click', function () { state.lunes.setDate(state.lunes.getDate() + 7); cargarSemana(); });
        $('#btnHoy').on('click',  function () { state.lunes = lunesDe(new Date()); cargarSemana(); });
        llenarMeses();
        sincronizarMes();
        $('#selMes').on('change', function () { irAMes(this.value); });
        $('#selTipoCita').on('change', function () {
            state.tipoCitaId = +$(this).val(); state.slot = null; $('#wizMsg').text('');
            $('#noteExpress').prop('hidden', state.tipoCitaId !== TIPO_EXPRESS_ID);
            cargarSemana();                      // el horario y la hora en curso cambian según el tipo
        });
        $('#selProfesional').on('change', function () { state.profesionalId = +$(this).val(); state.slot = null; $('#wizMsg').text(''); cargarSemana(); });

        $('#btnSiguiente').on('click', siguiente);
        $('#btnAnterior').on('click', function () { if (state.paso > 1) irAPaso(state.paso - 1); });
        $('#btnConfirmar').on('click', confirmar);
        $('#btnAgregarCita').on('click', reiniciar);

        $.when(api('ObtenerProfesionales'), api('ObtenerTratamientos'), api('ObtenerTiposCita', { user: usuario() })).done(function (profs, trats, tipos) {
            state.tratamientos = trats;
            var $t = $('#selTipoCita').empty().append($('<option>').val('0').text('Seleccione…'));
            $.each(tipos, function (_, x) { $t.append($('<option>').val(x.Id).text(x.TipoCita)); });
            var $s = $('#selProfesional').empty();
            $s.append($('<option>').val('0').text('Seleccione…'));
            $.each(profs, function (_, p) { $s.append($('<option>').val(p.Id).text(p.Profesional)); });
            state.profesionalId = 0;                // obligatorio: debe elegir uno distinto de "Seleccione…"
            renderTratamientos(trats);
            actualizarBarra();
        }).fail(function () { toast('No se pudo cargar la información. Recargue la página.'); });

        irAPaso(1, true);
        precargarPaciente();
    });

    // Viene de Registros > Expedientes al guardar un expediente nuevo ("¿Agendar cita?"):
    // se busca al paciente por documento y, si coincide uno solo, queda seleccionado y se pasa a tratamientos.
    function precargarPaciente() {
        var pre = window.dpCitaPaciente;
        try { delete window.dpCitaPaciente; } catch (e) { window.dpCitaPaciente = undefined; }
        if (!pre || !pre.documento) return;
        var dig = function (s) { return String(s || '').replace(/\D/g, ''); };
        $('#selTipo').val('2');
        $('#lblBuscar').text('Número de documento');
        $('#txtBuscar').attr('maxlength', 20).val(pre.documento);
        buscar().done(function (r) {
            if (!r || !r.Ok) return;
            var iguales = $.grep(state.resultados, function (p) { return dig(p.Documento) === dig(pre.documento); });
            if (iguales.length !== 1) return;            // varios o ninguno: el usuario elige
            state.paciente = iguales[0];
            renderPacientes(state.resultados);
            irAPaso(2);
        });
    }

})(jQuery);
