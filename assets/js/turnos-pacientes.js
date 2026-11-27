/* Pantalla de turnos para pacientes – se actualiza cada 10 segundos contra Registros/frm_TurnosPacientes.aspx/ObtenerTurnos.
   Cuando un paciente pasa a atención se muestra un aviso a pantalla completa (y suena un tono si el sonido está activado). */
(function ($) {
    'use strict';

    var REFRESCO_MS = 10000;
    var AVISO_MS = 8000;
    var CLAVE_SONIDO = 'dpie.turnos.sonido';

    var state = {
        especialista: parseInt($('#turnos').data('especialista'), 10) || 0,
        sucursal: parseInt($('#turnos').data('sucursal'), 10) || 0,      // ?suc= o la del usuario que abrió la pantalla
        atendiendo: null,      // claves en atención en la última lectura (null = primera carga)
        desfaseMs: 0,
        sonido: leerSonido(),
        avisos: [],
        mostrandoAviso: false,
        audio: null,
        videos: [],           // URLs de assets/publicidad (las envía el servidor en cada actualización)
        video: -1             // índice del video en reproducción
    };
    var reproductor = document.getElementById('tpVideo');

    /* ---------- utilidades ---------- */
    function esc(s) { return $('<div/>').text(s == null ? '' : String(s)).html(); }
    function dos(n) { return (n < 10 ? '0' : '') + n; }
    // Reloj de 12 horas: 02:30 PM (esta pantalla se abre sola, sin assets/js/utiles.js)
    function hora12(d, conSegundos) {
        var h = d.getHours() % 12 || 12;
        return dos(h) + ':' + dos(d.getMinutes()) + (conSegundos ? ':' + dos(d.getSeconds()) : '') + (d.getHours() < 12 ? ' AM' : ' PM');
    }
    function ahora() { return new Date(Date.now() + state.desfaseMs); }
    function parseIso(s) {
        var m = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})$/.exec(s || '');
        return m ? new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +m[6]) : null;
    }
    function leerSonido() { try { return localStorage.getItem(CLAVE_SONIDO) === '1'; } catch (e) { return false; } }
    function guardarSonido(v) { try { localStorage.setItem(CLAVE_SONIDO, v ? '1' : '0'); } catch (e) { } }

    /* ---------- reloj ---------- */
    function reloj() {
        var d = ahora();
        $('#tpReloj').text(hora12(d));
        var fecha = d.toLocaleDateString('es-SV', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });
        fecha = fecha.charAt(0).toUpperCase() + fecha.slice(1);
        if ($('#tpFecha').text() !== fecha) $('#tpFecha').text(fecha);
    }

    /* ---------- datos ---------- */
    function actualizar() {
        $.ajax({
            type: 'POST',
            url: 'frm_TurnosPacientes.aspx/ObtenerTurnos',
            data: JSON.stringify({ especialista: state.especialista, sucursal: state.sucursal }),
            contentType: 'application/json; charset=utf-8',
            dataType: 'json',
            timeout: 8000
        }).done(function (r) {
            var t = r.d;
            if (!t.Ok) { estado(t.Mensaje, true); return; }   // se conservan los últimos turnos mostrados
            // Versión nueva de la pantalla (se actualizó el sistema). No se recarga sola: perdería la pantalla completa y el
            // navegador no deja sonar la voz hasta que alguien toque la página. Se avisa para que alguien la actualice.
            if (t.Version) {
                state.version = state.version || t.Version;
                if (state.version !== t.Version && !$('#tpActualizar').length)
                    $('<button type="button" id="tpActualizar" class="tp-actualizar"><i class="bx bx-refresh"></i> Hay una actualización: toque aquí para actualizar</button>')
                        .on('click', function () { location.reload(); })
                        .appendTo('body');
            }
            var srv = parseIso(t.HoraServidor);
            if (srv) state.desfaseMs = srv.getTime() - Date.now();
            render(t);
            actualizarVideos(t.Videos || []);
            var d = ahora();
            estado('Actualizado ' + hora12(d, true), false);
        }).fail(function () {
            estado('Sin conexión. Reintentando…', true);
        });
    }

    function estado(texto, error) {
        $('#tpEstado').text(texto).toggleClass('error', !!error);
    }

    function render(t) {
        var anteriores = state.atendiendo, actuales = {}, nuevos = [];

        var $a = $('#tpAtendiendo').empty();
        if (!t.Atendiendo.length)
            $a.html('<div class="tp-vacio"><i class="bx bx-coffee"></i>En breve llamaremos al siguiente paciente.</div>');
        $.each(t.Atendiendo, function (_, p) {
            actuales[p.Clave] = true;
            var esNuevo = anteriores !== null && !anteriores[p.Clave];
            if (esNuevo) nuevos.push(p);
            $a.append(
                '<article class="tp-tarjeta' + (esNuevo ? ' nuevo' : '') + '">' +
                '  <div class="tp-tarjeta-nombre">' + esc(p.Paciente) + '</div>' +
                '  <div class="tp-tarjeta-con"><i class="bx bx-user-pin"></i> con ' + esc(p.Especialista) + '</div>' +
                '</article>');
        });
        state.atendiendo = actuales;

        var $s = $('#tpSiguientes').empty();
        if (!t.Siguientes.length)
            $s.html('<li class="tp-vacio" style="display:block;border:0;">No hay más turnos por ahora.</li>');
        $.each(t.Siguientes, function (_, p) {
            var etiqueta = p.Sigue ? 'Sigue' : (p.Estado === 'S' ? 'En sala' : 'Programado');
            $s.append(
                '<li' + (p.Sigue ? ' class="sigue"' : '') + '>' +
                '  <span class="tp-hora">' + esc(p.Hora) + '</span>' +
                '  <span class="tp-nombre">' + esc(p.Paciente) +
                '    <span class="tp-con"><span>' + esc(p.Especialista) + '</span><span class="tp-etiqueta">' + etiqueta + '</span></span>' +
                '  </span>' +
                '</li>');
        });

        $.each(nuevos, function (_, p) { state.avisos.push(p); });
        siguienteAviso();
    }

    /* ---------- videos publicitarios (70%) ---------- */
    // Se reproducen en orden y en bucle. Una lista nueva no interrumpe el video que se está viendo.
    function actualizarVideos(lista) {
        var antes = state.videos.join('|');
        if (antes === lista.join('|')) return;
        var actual = state.video >= 0 ? state.videos[state.video] : null;
        state.videos = lista;
        state.fallos = 0;
        $('.tp-publicidad').toggleClass('con-video', lista.length > 0);

        if (!lista.length) { state.video = -1; reproductor.removeAttribute('src'); reproductor.load(); return; }
        var i = actual ? lista.indexOf(actual) : -1;
        if (i >= 0) state.video = i;          // sigue el mismo video
        else reproducir(0);
    }

    function reproducir(i) {
        if (!state.videos.length) return;
        state.video = i % state.videos.length;
        reproductor.src = state.videos[state.video];
        reproductor.muted = !state.sonido;
        var p = reproductor.play();
        // Sin un clic previo el navegador solo permite reproducir en silencio
        if (p && p.catch) p.catch(function () { reproductor.muted = true; reproductor.play().catch(function () { }); });
    }

    reproductor.addEventListener('playing', function () { state.fallos = 0; });
    reproductor.addEventListener('ended', function () { reproducir(state.video + 1); });
    // Un video dañado o con formato no soportado se salta; si fallan todos, se muestra el logo
    reproductor.addEventListener('error', function () {
        if (!state.videos.length || !reproductor.getAttribute('src')) return;
        state.fallos = (state.fallos || 0) + 1;
        if (state.fallos >= state.videos.length) { $('.tp-publicidad').removeClass('con-video'); return; }
        setTimeout(function () { reproducir(state.video + 1); }, 1000);
    });

    /* ---------- aviso de llamado ---------- */
    function siguienteAviso() {
        if (state.mostrandoAviso || !state.avisos.length) return;
        var p = state.avisos.shift();
        state.mostrandoAviso = true;
        $('#tpAvisoNombre').text(p.Paciente);
        $('#tpAvisoCon').text('con ' + p.Especialista);
        $('#tpAviso').addClass('visible');
        reproductor.volume = 0.1;             // baja el video mientras se anuncia al paciente
        tono();
        hablar(p.Anuncio || (p.Paciente + ', pase con ' + p.Especialista));     // nombres completos en el audio
        setTimeout(function () {
            $('#tpAviso').removeClass('visible');
            reproductor.volume = 1;
            state.mostrandoAviso = false;
            setTimeout(siguienteAviso, 400);
        }, AVISO_MS);
    }

    function tono() {
        if (!state.sonido) return;
        try {
            var Ctx = window.AudioContext || window.webkitAudioContext;
            if (!Ctx) return;
            state.audio = state.audio || new Ctx();
            var ctx = state.audio, t0 = ctx.currentTime;
            [[659.25, 0], [880, 0.35]].forEach(function (n) {
                var o = ctx.createOscillator(), g = ctx.createGain();
                o.type = 'sine';
                o.frequency.value = n[0];
                g.gain.setValueAtTime(0.0001, t0 + n[1]);
                g.gain.exponentialRampToValueAtTime(0.3, t0 + n[1] + 0.03);
                g.gain.exponentialRampToValueAtTime(0.0001, t0 + n[1] + 0.6);
                o.connect(g); g.connect(ctx.destination);
                o.start(t0 + n[1]); o.stop(t0 + n[1] + 0.65);
            });
        } catch (e) { }
    }

    function hablar(texto) {
        if (!state.sonido || !window.speechSynthesis) return;
        try {
            var u = new SpeechSynthesisUtterance(texto);
            u.lang = 'es-ES';
            u.rate = 0.9;
            setTimeout(function () { window.speechSynthesis.speak(u); }, 900);   // después del tono
        } catch (e) { }
    }

    /* ---------- controles ---------- */
    function pintarSonido() {
        $('#tpSonido').toggleClass('activo', state.sonido)
            .attr('title', state.sonido ? 'Silenciar' : 'Activar sonido al llamar un paciente')
            .find('i').attr('class', state.sonido ? 'bx bx-volume-full' : 'bx bx-volume-mute');
    }

    // El navegador solo permite audio después de un clic en la página
    $('#tpSonido').on('click', function () {
        state.sonido = !state.sonido;
        guardarSonido(state.sonido);
        pintarSonido();
        reproductor.muted = !state.sonido;    // el botón activa también el audio de los videos
        if (state.sonido) tono();
    });

    $('#tpPantalla').on('click', function () {
        var el = document.documentElement;
        if (!document.fullscreenElement) { if (el.requestFullscreen) el.requestFullscreen(); }
        else if (document.exitFullscreen) document.exitFullscreen();
    });

    pintarSonido();
    reloj();
    actualizar();
    setInterval(reloj, 1000);
    setInterval(actualizar, REFRESCO_MS);

})(jQuery);
