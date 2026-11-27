/* Agenda semanal – jQuery + AJAX contra WebMethods de frm_CitasCalendario.aspx */
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

    var DIAS = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];
    var MESES = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    var HORA_INI = 8, HORA_FIN = 19;          // filas 08:00 … 18:00 (la agenda llega hasta las 19:00)

    var state = { lunes: null, citas: [], tipos: [], detalle: null, reqId: 0 };

    /* ---------- utilidades ---------- */
    function api(metodo, datos) {
        return $.ajax({
            type: 'POST',
            url: window.CAL_URL + '/' + metodo,
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
    function minutos(hhmm) { var p = hhmm.split(':'); return (+p[0]) * 60 + (+p[1]); }
    function hhmm(min) { return pad(Math.floor(min / 60)) + ':' + pad(min % 60); }
    function toast(msg, ok) {
        var $t = $('#toast').text(msg).toggleClass('ok', !!ok).prop('hidden', false);
        clearTimeout(toast._t);
        toast._t = setTimeout(function () { $t.prop('hidden', true); }, 4200);
    }
    function llenarSelect($s, lista, seleccionado) {
        $s.empty();
        $.each(lista, function (_, o) { $s.append($('<option>').val(o.Id).text(o.Texto)); });
        if (seleccionado !== undefined) $s.val(String(seleccionado));
    }

    /* ---------- selector de mes (el actual y los 12 siguientes) ---------- */
    var MESES_LARGO = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    function llenarMeses() {
        var $s = $('#selMes').empty(), hoy = new Date();
        for (var i = 0; i <= 12; i++) {
            var m = new Date(hoy.getFullYear(), hoy.getMonth() + i, 1);
            $s.append($('<option>').val(m.getFullYear() + '-' + pad(m.getMonth() + 1)).text(MESES_LARGO[m.getMonth()] + ' ' + m.getFullYear()));
        }
    }
    // el mes que se ve: el del jueves de la semana (la semana pertenece al mes que tiene la mayoría de sus días)
    function sincronizarMes() {
        var j = new Date(state.lunes); j.setDate(j.getDate() + 3);
        var v = j.getFullYear() + '-' + pad(j.getMonth() + 1);
        if (!$('#selMes option[value="' + v + '"]').length) {
            // semana pasada o más allá de 12 meses: se muestra como opción aparte
            $('#selMes option.fuera').remove();
            $('#selMes').prepend($('<option class="fuera">').val(v).text(MESES_LARGO[j.getMonth()] + ' ' + j.getFullYear()));
        }
        $('#selMes').val(v);
    }
    function irAMes(v) {
        var p = v.split('-'), primero = new Date(+p[0], +p[1] - 1, 1);
        // primera semana del mes: la del día 1, o la siguiente si el 1 cae en fin de semana (vie-dom)
        var lunes = lunesDe(primero);
        if (primero.getDay() === 0 || primero.getDay() >= 5) lunes.setDate(lunes.getDate() + 7);
        // en el mes en curso se queda en la semana de hoy
        var hoy = new Date();
        if (+p[0] === hoy.getFullYear() && +p[1] - 1 === hoy.getMonth()) lunes = lunesDe(hoy);
        state.lunes = lunes;
        cargarSemana();
    }

    /* ---------- calendario ---------- */
    function cargarSemana() {
        if ($('#selMes').length) sincronizarMes();
        var miReq = ++state.reqId;
        $('#calGrid').attr('aria-busy', 'true');
        api('ObtenerCitasSemana', { fecha: fmtFecha(state.lunes) }).done(function (r) {
            if (miReq !== state.reqId) return;
            if (!r.Ok) { state.citas = []; $('#calMsg').text(r.Mensaje); }
            else { state.citas = r.Citas; $('#calMsg').text(''); }
            renderSemana();
        }).fail(function (xhr) {
            console.error('ObtenerCitasSemana falló. HTTP ' + xhr.status, xhr.responseText);
            $('#calMsg').text('Error de conexión (HTTP ' + xhr.status + ').');
            renderSemana();
        });
    }

    function indiceTipo(texto) {
        for (var i = 0; i < state.tipos.length; i++) if (state.tipos[i].Texto === texto) return i % 4;
        return 0;
    }

    function renderSemana() {
        var hoy = fmtFecha(new Date()), horaActual = new Date().getHours();
        var filtro = $('#selFiltroProf').val() === '0' ? null : $('#selFiltroProf option:selected').text();
        var dias = [];
        for (var i = 0; i < 7; i++) { var d = new Date(state.lunes); d.setDate(d.getDate() + i); dias.push(d); }

        var p = dias[0], u = dias[6];
        $('#lblSemana').text(p.getDate() + ' ' + MESES[p.getMonth()] + ' – ' + u.getDate() + ' ' + MESES[u.getMonth()] + ' ' + u.getFullYear());

        var $g = $('#calGrid').empty().attr('aria-busy', 'false');
        $g.append('<div class="wk-corner"></div>');
        $.each(dias, function (_, d) {
            $g.append($('<div class="wk-head">').toggleClass('is-today', fmtFecha(d) === hoy)
                .append($('<span class="dow">').text(DIAS[d.getDay()]))
                .append($('<span class="dnum">').text(d.getDate() + ' ' + MESES[d.getMonth()])));
        });

        // índice rápido: "fecha|hora" -> citas
        var idx = {};
        $.each(state.citas, function (_, c) {
            if (filtro && c.Profesional !== filtro) return;
            var h = Math.min(Math.max(parseInt(c.Hora, 10), HORA_INI), HORA_FIN - 1);
            (idx[c.Fecha + '|' + h] = idx[c.Fecha + '|' + h] || []).push(c);
        });

        for (var h = HORA_INI; h < HORA_FIN; h++) {
            $g.append($('<div class="wk-hour">').text(hora12(pad(h) + ':00')));
            $.each(dias, function (_, d) {
                var f = fmtFecha(d), $c = $('<div class="wk-cell">').toggleClass('is-today', f === hoy);
                $.each(idx[f + '|' + h] || [], function (_, c) {
                    // días anteriores y, hoy, horas anteriores a la hora en curso: solo consulta, no se abren
                    var pasada = c.Fecha < hoy || (c.Fecha === hoy && parseInt(c.Hora, 10) < horaActual);
                    $c.append($('<button type="button" class="cita">')
                        .addClass('t' + indiceTipo(c.TipoCita)).toggleClass('pasada', pasada).attr('data-id', c.Id)
                        .prop('disabled', pasada).attr('aria-disabled', pasada ? 'true' : null)
                        .attr('title', hora12(c.Hora) + ' · ' + c.TipoCita + ' · ' + (c.Paciente || '') + ' · ' + c.Profesional + (pasada ? ' · cita pasada' : ''))
                        .append($('<b>').text(hora12(c.Hora) + ' · ' + c.TipoCita), $('<span>').text(c.Paciente || c.Profesional)));
                });
                $g.append($c);
            });
        }
    }

    /* ---------- formulario de modificación ---------- */
    function abrirCita(id) {
        $('#calMsg').text('');
        api('ObtenerCita', { id: id }).done(function (r) {
            if (!r.Ok) { toast(r.Mensaje); return; }
            state.detalle = r.Cita;
            pintarFormulario(r.Cita);
            $('#modalMsg').text('');
            $('#modalCita').prop('hidden', false);
            $('#selProfesional').trigger('focus');
        }).fail(function (xhr) {
            console.error('ObtenerCita falló. HTTP ' + xhr.status, xhr.responseText);
            toast('No se pudo cargar la cita (HTTP ' + xhr.status + ').');
        });
    }

    function pintarFormulario(d) {
        var $i = $('#infoPaciente').empty();
        function dato(k, v, full) { $i.append($('<div>').toggleClass('full', !!full).append($('<dt>').text(k), $('<dd>').text(v || '—'))); }
        dato('Paciente', d.Paciente, true);
        dato('Documento', d.Documento); dato('Edad', d.Edad);
        dato('Celular', d.Celular); dato('Email', d.Email);
        dato('Dirección', d.Direccion, true);
        dato('Tipo de cita', d.TipoCita, true);     // informativo: el tipo de cita no se cambia aquí

        // Tratamientos: solo consulta
        var $t = $('#lstTratamientos').empty(), lista = d.Tratamientos || [];
        if (!lista.length) $t.append($('<li class="vacio">').text('La cita no tiene tratamientos registrados.'));
        // Con descuento del tratamiento: precio tachado, % y precio con descuento; sin descuento, solo el precio
        $.each(lista, function (_, x) {
            var valor = Number(x.Valor || 0), desc = Number(x.MontoDescuento || 0), $v = $('<strong>');
            if (x.Descuento > 0 && desc > 0)
                $v.append($('<span class="badge bg-success me-1 fw-normal">').text('-' + Number(x.Descuento) + ' %'),
                    $('<span class="text-muted text-decoration-line-through fw-normal me-1">').text('$ ' + valor.toFixed(2)),
                    document.createTextNode('$ ' + (valor - desc).toFixed(2)));
            else $v.text('$ ' + valor.toFixed(2));
            $t.append($('<li>').append($('<span>').text(x.Tratamiento || '—'), $v));
        });
        if (lista.length > 1) {
            var total = lista.reduce(function (a, x) { return a + Number(x.Valor || 0) - Number(x.MontoDescuento || 0); }, 0);
            $t.append($('<li class="total">').append($('<span>').text('Total'), $('<strong>').text('$ ' + total.toFixed(2))));
        }

        // Pagada por adelantado en caja: el pago sigue con la cita aunque se cambie la fecha, la hora o el profesional
        $('#avisoAnticipo').prop('hidden', !d.AnticipoFactura).text(!d.AnticipoFactura ? ''
            : d.AnticipoLibre
            ? 'Usará el pago adelantado del paciente: $ ' + Number(d.AnticipoMonto || 0).toFixed(2) + (d.AnticipoFecha ? ' (pagado el ' + d.AnticipoFecha + ')' : '')
              + '. Al atenderla se descuenta y solo se cobra la diferencia; si sobra, queda para su siguiente cita.'
            : 'Pagada por adelantado: $ ' + Number(d.AnticipoMonto || 0).toFixed(2) + (d.AnticipoFecha ? ' el ' + d.AnticipoFecha : '') + ' (factura N.º ' + d.AnticipoFactura + ').'
              + ' Si cambia la fecha, la hora o el profesional, el pago se mantiene; al atenderla solo se cobra lo que se agregue.');

        // Pago adelantado sin cita: "Usar pago adelantado" (o quitarlo si ya se asignó a esta cita)
        var pendiente = !d.AnticipoFactura && d.PagosPendientes > 0;
        $('#avisoPagoAdelantado').prop('hidden', !(pendiente || d.AnticipoLibre));
        $('#txtPagoAdelantado').text(pendiente
            ? 'El paciente tiene $ ' + Number(d.PagosPendientes).toFixed(2) + ' pagados por adelantado, pendientes de agendar.'
            : 'El pago adelantado ya está asignado a esta cita.');
        $('#btnUsarPago').text(pendiente ? 'Usar pago adelantado' : 'Quitar pago adelantado')
            .toggleClass('btn-primary', pendiente).toggleClass('btn-outline-secondary', !pendiente).data('quitar', !pendiente);

        llenarSelect($('#selProfesional'), state.cat.Profesionales, d.IdEspecialista);
        $('#txtDia').val(d.Fecha);

        // Horas en punto desde las 08:00 hasta (cierre - duración); se conserva la hora original aunque no sea en punto
        var dur = d.DuracionMin > 0 ? d.DuracionMin : 60, cierre = minutos(d.HoraCierre), opciones = [];
        for (var m = HORA_INI * 60; m + dur <= cierre; m += 60) opciones.push(m);
        var orig = minutos(d.Hora);
        if (opciones.indexOf(orig) < 0) { opciones.push(orig); opciones.sort(function (a, b) { return a - b; }); }
        var $h = $('#selHora').empty();
        // el valor va en 24 h (lo lee el servidor); el texto, en 12 h
        $.each(opciones, function (_, m) { $h.append($('<option>').val(hhmm(m)).text(hora12(hhmm(m)))); });
        $h.val(d.Hora);
        actualizarDuracion();
    }

    function actualizarDuracion() {
        var d = state.detalle; if (!d) return;
        var dur = d.DuracionMin > 0 ? d.DuracionMin : 60;
        $('#lblDuracion').text(dur + ' min · termina ' + hora12(hhmm(minutos($('#selHora').val() || d.Hora) + dur)));
    }

    function cerrarModal() { $('#modalCita').prop('hidden', true); state.detalle = null; }

    // Pago adelantado sin cita del paciente: la cita lo usará (al atenderla se descuenta) o deja de usarlo
    function usarPagoAdelantado() {
        var d = state.detalle, $b = $('#btnUsarPago'), quitar = !!$b.data('quitar');
        if (!d) return;
        $b.prop('disabled', true);
        api(quitar ? 'QuitarPagoAdelantado' : 'UsarPagoAdelantado', { id: d.Id }).done(function (r) {
            if (!r.Ok) { $('#modalMsg').text(r.Mensaje); return; }
            toast(r.Mensaje, true);
            abrirCita(d.Id);          // recarga el detalle con el pago asignado
        }).fail(function (xhr) {
            $('#modalMsg').text('Error de conexión (HTTP ' + xhr.status + '). Intente nuevamente.');
        }).always(function () { $b.prop('disabled', false); });
    }

    function guardar() {
        var d = state.detalle, $btn = $('#btnGuardar'), $msg = $('#modalMsg').text('');
        if (!d) return;
        if (!$('#txtDia').val()) { $msg.text('Seleccione el día.'); return; }
        $btn.prop('disabled', true).text('Guardando…');
        api('GuardarCita', {
            req: {
                Cita: d.Id,
                Profesional: +$('#selProfesional').val(),          // el estado lo decide el servidor (Reprogramada si cambia el horario)
                Fecha: $('#txtDia').val(),
                Hora: $('#selHora').val(),
                Usuario: usuario()
            }
        }).done(function (r) {
            if (r.Ok) {
                cerrarModal();
                toast(r.Mensaje, true);
                var f = parseFecha($('#txtDia').val());         // vuelve a la agenda, en la semana de la cita
                state.lunes = lunesDe(f);
                cargarSemana();
            } else { $msg.text(r.Mensaje); }
        }).fail(function (xhr) {
            console.error('GuardarCita falló. HTTP ' + xhr.status, xhr.responseText);
            $msg.text('Error de conexión (HTTP ' + xhr.status + '). Intente nuevamente.');
        }).always(function () { $btn.prop('disabled', false).text('Guardar cambios'); });
    }

    // Cancelar la cita: pide el motivo; la cita queda "Cancelada", libera la hora y al especialista y sale del calendario
    function cancelarCita() {
        var d = state.detalle, $msg = $('#modalMsg').text('');
        if (!d) return;
        var pagada = d.AnticipoFactura ? '\n\nEstá pagada por adelantado ($ ' + Number(d.AnticipoMonto || 0).toFixed(2) + '): lo pagado quedará a favor del paciente.' : '';
        swal({
            title: 'Cancelar cita',
            text: d.Paciente + '\n' + d.Fecha.split('-').reverse().join('/') + ' ' + hora12(d.Hora) + ' con ' + d.Especialista
                + '\n\nLa hora y el especialista quedarán libres.' + pagada + '\n\nEscriba el motivo:',
            type: 'input', inputPlaceholder: 'Ejemplo: el paciente avisó que no puede asistir',
            showCancelButton: true, confirmButtonText: 'Cancelar cita', cancelButtonText: 'Volver',
            confirmButtonColor: '#dc3545', closeOnConfirm: false
        }, function (motivo) {
            if (motivo === false) return;
            motivo = $.trim(motivo || '');
            if (motivo.length < 5) { swal.showInputError('Escriba el motivo (al menos 5 caracteres).'); return false; }
            var $btn = $('#btnCancelarCita').prop('disabled', true);
            api('CancelarCita', { id: d.Id, motivo: motivo, user: usuario() }).done(function (r) {
                if (!r.Ok) { swal.showInputError(r.Mensaje); return; }
                swal.close();
                cerrarModal();
                toast(r.Mensaje, true);
                cargarSemana();
            }).fail(function (xhr) {
                swal.close();
                $msg.text('Error de conexión (HTTP ' + xhr.status + '). Intente nuevamente.');
            }).always(function () { $btn.prop('disabled', false); });
        });
    }

    /* ---------- eventos ---------- */
    $(function () {
        state.lunes = lunesDe(new Date());

        $('#calGrid').on('click', '.cita:not(.pasada)', function () { abrirCita(+$(this).data('id')); });
        $('#btnPrev').on('click', function () { state.lunes.setDate(state.lunes.getDate() - 7); cargarSemana(); });
        $('#btnNext').on('click', function () { state.lunes.setDate(state.lunes.getDate() + 7); cargarSemana(); });
        $('#btnHoy').on('click', function () { state.lunes = lunesDe(new Date()); cargarSemana(); });
        $('#selFiltroProf').on('change', renderSemana);
        // al cambiar la hora se bloquean las citas que quedaron atrás (sin volver a consultar el servidor)
        var horaVista = new Date().getHours();
        var reloj = setInterval(function () {
            if (!document.getElementById('calGrid')) { clearInterval(reloj); return; }     // se salió de la pantalla
            var h = new Date().getHours();
            if (h !== horaVista && $('#modalCita').prop('hidden') && state.citas) { horaVista = h; renderSemana(); }
        }, 60000);

        $('#selHora').on('change', actualizarDuracion);
        $('#btnCancelar').on('click', cerrarModal);
        $('#btnCancelarCita').on('click', cancelarCita);
        $('#btnUsarPago').on('click', usarPagoAdelantado);
        llenarMeses();
        $('#selMes').on('change', function () { irAMes(this.value); });
        $('#btnGuardar').on('click', guardar);
        $(document).on('keydown', function (e) { if (e.key === 'Escape') cerrarModal(); });
        $('#modalCita').on('click', function (e) { if (e.target === this) cerrarModal(); });

        api('ObtenerCatalogos').done(function (c) {
            if (!c.Ok) { $('#calMsg').text(c.Mensaje); return; }
            state.cat = c; state.tipos = c.Tipos;
            var $f = $('#selFiltroProf').empty().append($('<option>').val('0').text('Todos'));
            $.each(c.Profesionales, function (_, p) { $f.append($('<option>').val(p.Id).text(p.Texto)); });
            cargarSemana();
        }).fail(function (xhr) {
            console.error('ObtenerCatalogos falló. HTTP ' + xhr.status, xhr.responseText);
            $('#calMsg').text('Error de conexión (HTTP ' + xhr.status + ').');
        });
    });

})(jQuery);