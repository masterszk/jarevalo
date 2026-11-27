/* Agenda de citas (wizard) – jQuery + AJAX contra WebMethods de frm_CitasAgenda.aspx */
(function ($) {
    'use strict';

    var DIAS  = ['domingo','lunes','martes','miércoles','jueves','viernes','sábado'];
    var MESES = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    var IMG_BASE = (window.CITAS_URL || '').replace(/frm_CitasAgenda\.aspx.*$/i, '') + 'Content/img/';

    var state = {
        paso: 1,
        paciente: null,         // PacienteDto seleccionado
        resultados: [],
        lunes: null,
        profesionalId: 0,
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
    function ids() { return Object.keys(state.seleccion).map(Number); }
    function duracion() { return ids().reduce(function (a, id) { return a + state.seleccion[id].DuracionMin; }, 0); }
    function total() { return ids().reduce(function (a, id) { return a + state.seleccion[id].Precio; }, 0); }
    function etiquetaSlot() {
        var f = parseFecha(state.slot.fecha);
        return DIAS[f.getDay()] + ' ' + f.getDate() + ' ' + MESES[f.getMonth()] + ', ' + state.slot.hora;
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
        if (n === 3 && !state.slot) return 'Elija un día y una hora en el calendario.';
        return '';
    }

    function siguiente() {
        var err = validarPaso(state.paso);
        if (err) { $('#wizMsg').text(err); return; }
        irAPaso(state.paso + 1);
    }

    function reiniciar() {
        state.paciente = null; state.resultados = []; state.seleccion = {}; state.slot = null;
        $('#txtBuscar').val(''); $('#txtNotas').val(''); $('#busMsg').text(''); $('#lstPacientes').empty();
        sincronizarTarjetas(); actualizarBarra();
        irAPaso(1);
    }

    /* ---------- paso 1: pacientes ---------- */
    function buscar() {
        var termino = $.trim($('#txtBuscar').val()), tipo = +$('#selTipo').val();
        var $msg = $('#busMsg').text('');
        if (termino.length < 3) { $msg.text('Escriba al menos 3 caracteres.'); return; }
        var $btn = $('#btnBuscar').prop('disabled', true).text('Buscando…');
        api('BuscarPacientes', { tipo: tipo, termino: termino }).done(function (r) {
            if (!r.Ok) { $msg.text(r.Mensaje); renderPacientes([]); return; }
            state.resultados = r.Pacientes;
            if (state.paciente && !r.Pacientes.some(function (p) { return p.Codigo === state.paciente.Codigo; })) state.paciente = null;
            renderPacientes(r.Pacientes);
            $msg.text(r.Mensaje || (r.Pacientes.length ? r.Pacientes.length + ' paciente(s) encontrado(s).' : ''));
        }).fail(function () {
            $msg.text('Error de conexión. Intente nuevamente.');
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
                $('<img alt="" loading="lazy">').attr('src', IMG_BASE + t.Imagen)
                    .on('error', function () { $(this).remove(); }).appendTo($img);
            }
            $g.append(
                $('<button type="button" class="trat">').attr({ 'data-id': t.Id, 'aria-pressed': 'false' })
                    .append($img)
                    .append($('<div class="trat-body">')
                        .append($('<span class="trat-name">').text(t.Nombre))
                        .append($('<div class="trat-meta">')
                            .append($('<span>').html('<b>' + t.DuracionMin + '</b> min'))
                            .append($('<b>').text(dinero(t.Precio))))
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

    /* ---------- paso 3: calendario ---------- */
    function cargarSemana() {
        if (!state.profesionalId) return;
        var miReq = ++state.reqId;
        $('#calGrid').attr('aria-busy', 'true').html('<div class="cal-empty" style="grid-column:1/-1">Cargando horarios…</div>');
        api('ObtenerSemana', { fecha: fmtFecha(state.lunes), profesionalId: state.profesionalId, duracionMin: duracion() })
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
                var $b = $('<button type="button" class="slot">').text(s.Hora).attr({ 'data-fecha': d.Fecha, 'data-hora': s.Hora });
                if (!s.Disponible) $b.addClass('is-busy').prop('disabled', true).attr('aria-label', s.Hora + ' no disponible');
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
        fila('Profesional', $('#selProfesional option:selected').text());
        fila('Fecha y hora', etiquetaSlot());
        fila('Tratamientos', ids().map(function (id) { return state.seleccion[id].Nombre; }).join(', '));
        fila('Duración', duracion() + ' min');
        fila('Total', dinero(total()));
    }

    function confirmar() {
        var $btn = $('#btnConfirmar'), $msg = $('#wizMsg').text('');
        $btn.prop('disabled', true).text('Guardando…');
        api('CrearCita', {
            req: {
                ProfesionalId: state.profesionalId,
                Fecha: state.slot.fecha,
                Hora: state.slot.hora,
                TratamientoIds: ids(),
                PacienteCodigo: state.paciente.Codigo,
                Documento: state.paciente.Documento || '',
                PacienteNombre: state.paciente.Nombre,
                Notas: $.trim($('#txtNotas').val())
            }
        }).done(function (r) {
            if (r.Ok) { toast(r.Mensaje, true); reiniciar(); }
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
        $('#selProfesional').on('change', function () { state.profesionalId = +$(this).val(); state.slot = null; cargarSemana(); });

        $('#btnSiguiente').on('click', siguiente);
        $('#btnAnterior').on('click', function () { if (state.paso > 1) irAPaso(state.paso - 1); });
        $('#btnConfirmar').on('click', confirmar);
        $('#btnAgregarCita').on('click', reiniciar);

        $.when(api('ObtenerProfesionales'), api('ObtenerTratamientos')).done(function (profs, trats) {
            state.tratamientos = trats;
            var $s = $('#selProfesional').empty();
            $.each(profs, function (_, p) { $s.append($('<option>').val(p.Id).text(p.Nombre)); });
            state.profesionalId = profs.length ? profs[0].Id : 0;
            renderTratamientos(trats);
            actualizarBarra();
        }).fail(function () { toast('No se pudo cargar la información. Recargue la página.'); });

        irAPaso(1, true);
    });

})(jQuery);
