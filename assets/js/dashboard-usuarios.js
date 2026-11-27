/* Dashboard de usuarios – Dashboard/frm_DashboardUsuarios.aspx (gráficos con ApexCharts)
   El día de trabajo del usuario: si es especialista, solo sus citas y procedimientos; si no, los de toda la clínica.
   Se actualiza solo cada minuto mientras la página está abierta. */
(function ($) {
    'use strict';

    var URL = 'Dashboard/frm_DashboardUsuarios.aspx/';
    var REFRESCO_MS = 60 * 1000;
    var COLOR = { acento: '#0d8f9b', exito: '#198754', lila: '#b591bd', ambar: '#f2a516', gris: '#adb5bd' };
    var COLOR_META = { ok: '#198754', va: '#0d8f9b', bajo: '#f2a516' };   // cumple · comisiona · bajo el mínimo
    var DIAS = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
    var MESES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];

    // La página se carga con AjaxLink: se limpian los gráficos y el temporizador de una carga anterior
    if (window.__duGraficos) $.each(window.__duGraficos, function (_, g) { try { g.destroy(); } catch (e) { } });
    if (window.__duTimer) clearInterval(window.__duTimer);
    var graficos = window.__duGraficos = {};
    var cargando = false;

    /* ---------- utilidades ---------- */
    function esc(s) { return $('<div/>').text(s == null ? '' : String(s)).html(); }
    function num(n) { return Number(n || 0).toLocaleString('es-SV'); }
    function titulo(s) { return String(s || '').toLowerCase().replace(/(^|\s)(\S)/g, function (m, a, b) { return a + b.toUpperCase(); }); }
    function fecha(iso) { var p = String(iso).split('-'); return new Date(+p[0], +p[1] - 1, +p[2]); }
    function diaCorto(iso) { var d = fecha(iso); return DIAS[d.getDay()] + ' ' + d.getDate(); }
    function diaLargo(iso, hoy) {
        var d = fecha(iso), h = fecha(hoy), dif = Math.round((d - h) / 86400000);
        if (dif === 0) return 'Hoy';
        if (dif === 1) return 'Mañana';
        return DIAS[d.getDay()] + ' ' + d.getDate() + '/' + (d.getMonth() + 1);
    }
    function vacio(t) { return '<div class="text-center text-muted py-4 small">' + t + '</div>'; }
    function pct(a, b) { return b ? Math.round(a * 1000 / b) / 10 : 0; }
    function api(metodo) {
        return $.ajax({ type: 'POST', url: URL + metodo, data: '{}', contentType: 'application/json; charset=utf-8', dataType: 'json' })
            .then(function (r) { return r.d; });
    }

    /* ---------- encabezado ---------- */
    function saludo(d) {
        var h = new Date().getHours();
        var s = h < 12 ? 'Buenos días' : h < 19 ? 'Buenas tardes' : 'Buenas noches';
        $('#duSaludo').text(s + ', ' + titulo(d.Nombre));
        var hoy = fecha(d.Hoy);
        var cuando = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'][hoy.getDay()] + ' ' + hoy.getDate() + ' de ' + MESES[hoy.getMonth()];
        $('#duAlcance').html(esc(cuando) + ' · ' + (d.Especialista
            ? 'tus citas y procedimientos como <strong>' + esc(d.Especialista) + '</strong>'
            : 'la operación de toda la clínica'));
        $('#duMesTitulo').text('Este mes · ' + MESES[hoy.getMonth()]);
        $('#duActualizado').text('Actualizado ' + d.Actualizado);
    }

    /* ---------- indicadores ---------- */
    function indicadores(d) {
        var k = d.Indicadores;
        $('#kCitasHoy').text(num(k.CitasHoy));
        $('#kPorLlegar').text(num(k.PorLlegar));
        $('#kEnSala').text(num(k.EnSala));
        var espera = $.grep(d.Agenda, function (c) { return c.MinutosEspera != null; }).map(function (c) { return c.MinutosEspera; });
        $('#kEnSalaSub').text(espera.length ? 'mayor espera: ' + Math.max.apply(null, espera) + ' min' : 'esperando');
        $('#kEnAtencion').text(num(k.EnAtencion));
        $('#kAtendidasHoy').text(num(k.AtendidasHoy));
        $('#kAtendidasHoySub').text(k.CitasHoy ? pct(k.AtendidasHoy, k.CitasHoy) + ' % de las citas' : 'sin citas hoy');
        $('#kCanceladasHoy').text(num(k.CanceladasHoy));
        $('.du-kpi-sala').toggleClass('du-activo', k.EnSala > 0);
        $('.du-kpi-atencion').toggleClass('du-activo', k.EnAtencion > 0);

        $('#kProcMes').text(num(k.ProcedimientosMes));
        $('#kPacientesMes').text(num(k.PacientesMes));
        $('#kPacientesMesSub').text(d.Especialista ? 'pacientes distintos' : num(k.ExpedientesMes) + ' expedientes nuevos');
        $('#kMinutos').text(k.MinutosPromedio != null ? k.MinutosPromedio + ' min' : '—');
        var base = k.AtendidasMes + k.CanceladasMes;
        $('#kAsistencia').text(base ? pct(k.AtendidasMes, base) + ' %' : '—');
        $('#kAsistenciaSub').text(num(k.AtendidasMes) + ' atendidas · ' + num(k.CanceladasMes) + ' canceladas');
    }

    /* ---------- agenda de hoy ---------- */
    // Estado que se muestra: lo que pasa con el paciente (sala, atención) manda sobre el estado de la cita
    function estadoVisible(c) {
        if (c.EstadoProcedimiento === 'S') return { t: 'En sala' + (c.MinutosEspera != null ? ' · ' + c.MinutosEspera + ' min' : ''), cl: 'du-e-sala', orden: 1 };
        if (c.EstadoProcedimiento === 'I') return { t: 'En atención', cl: 'du-e-atencion', orden: 0 };
        if (c.EstadoProcedimiento === 'F' || c.IdEstado === 6) return { t: 'Atendida', cl: 'du-e-fin', orden: 3 };
        if (c.IdEstado === 3 || c.IdEstado === 7) return { t: c.Estado || 'Cancelada', cl: 'du-e-cancelada', orden: 4 };
        return { t: c.Estado || 'Pendiente', cl: 'du-e-pendiente', orden: 2 };
    }

    function agenda(d) {
        var lista = d.Agenda || [];
        $('#duAgendaTotal').text(lista.length ? lista.length + (lista.length === 1 ? ' cita' : ' citas') : '');
        if (!lista.length) { $('#duAgenda').html(vacio('<i class="bx bx-coffee fs-3 d-block mb-1"></i>No hay citas para hoy.')); return; }

        var ahora = new Date(), hhmm = ('0' + ahora.getHours()).slice(-2) + ':' + ('0' + ahora.getMinutes()).slice(-2);
        var siguienteMarcada = false;
        $('#duAgenda').html(lista.map(function (c) {
            var e = estadoVisible(c);
            // la próxima pendiente a partir de la hora actual
            var siguiente = !siguienteMarcada && e.orden === 2 && (!c.Hora || c.Hora >= hhmm);
            if (siguiente) siguienteMarcada = true;
            var detalle = [c.TipoCita, d.Especialista ? '' : c.Especialista].filter(Boolean).map(esc).join(' · ');
            return '<div class="du-cita ' + e.cl + (siguiente ? ' du-siguiente' : '') + '">'
                + '<div class="du-hora">' + (c.Hora ? esc(hora12(c.Hora)) : '<span class="text-muted small">Sin hora</span>')
                + (c.HoraFin && c.Hora ? '<small>' + esc(hora12(c.HoraFin)) + '</small>' : '') + '</div>'
                + '<div class="du-cuerpo">'
                + '<span class="du-paciente">' + esc(titulo(c.Paciente)) + '</span>'
                + (detalle ? '<small class="text-muted">' + detalle + '</small>' : '')
                + '</div>'
                + (siguiente ? '<span class="badge du-badge-siguiente">Sigue</span>' : '')
                + '<span class="du-estado">' + esc(e.t) + '</span>'
                + '</div>';
        }).join(''));
    }

    /* ---------- próximas citas y cumpleaños ---------- */
    function proximas(d) {
        var lista = d.Proximas || [];
        if (!lista.length) { $('#duProximas').html(vacio('Sin citas en los próximos días.')); return; }
        $('#duProximas').html(lista.map(function (c) {
            var cuando = diaLargo(c.Fecha, d.Hoy) + (c.Hora ? ' ' + hora12(c.Hora) : '');
            return '<div class="du-fila">'
                + '<span class="du-cuando">' + esc(cuando) + '</span>'
                + '<div class="du-cuerpo"><span class="fw-semibold">' + esc(titulo(c.Paciente)) + '</span>'
                + (d.Especialista ? '' : '<small class="text-muted">' + esc(c.Especialista) + '</small>') + '</div>'
                + '</div>';
        }).join(''));
    }

    function cumpleanos(d) {
        var lista = d.Cumpleanos || [];
        if (!lista.length) { $('#duCumpleanos').html(vacio('Nadie cumple años esta semana.')); return; }
        $('#duCumpleanos').html(lista.map(function (c) {
            return '<div class="du-fila' + (c.EsHoy ? ' du-hoy' : '') + '">'
                + '<span class="du-cuando">' + (c.EsHoy ? '<i class="bx bx-party"></i> Hoy' : esc(diaLargo(c.Cumple, d.Hoy))) + '</span>'
                + '<div class="du-cuerpo"><span class="fw-semibold">' + esc(titulo(c.Paciente)) + '</span>'
                + '<small class="text-muted">cumple ' + c.Edad + ' años</small></div>'
                + '</div>';
        }).join(''));
    }

    function tratamientos(d) {
        var lista = d.Tratamientos || [];
        if (!lista.length) { $('#duTratamientos').html(vacio('Sin procedimientos este mes.')); return; }
        var max = lista[0].Cantidad || 1;
        $('#duTratamientos').html(lista.map(function (t) {
            return '<div class="db-trat"><div class="d-flex justify-content-between small"><span class="text-truncate me-2">' + esc(titulo(t.Descripcion))
                + '</span><strong>' + num(t.Cantidad) + '</strong></div>'
                + '<div class="progress db-barra"><div class="progress-bar" style="width:' + Math.round(t.Cantidad * 100 / max) + '%"></div></div></div>';
        }).join(''));
    }

    /* ---------- meta del mes (solo especialistas) ---------- */
    function dinero(n) { return '$ ' + Number(n || 0).toLocaleString('es-SV', { minimumFractionDigits: 2, maximumFractionDigits: 2 }); }
    function monto(n) { return '$ ' + Number(n || 0).toLocaleString('es-SV', { maximumFractionDigits: 2 }); }

    function meta(d) {
        // cada especialista tiene su propia meta (e.Meta)
        var m = d.Meta, e = m && m.Meta && m.Especialistas && $.grep(m.Especialistas, function (x) { return x.Meta; })[0];
        $('#duMetaCard').toggleClass('d-none', !(m && m.Meta && e));
        if (!(m && m.Meta && e)) return;
        var mt = e.Meta;
        $('#duMetaPeriodo').text(m.Periodo + ' · día ' + m.DiasTranscurridos + ' de ' + m.DiasMes
            + (d.Especialista ? '' : m.MetaComun ? ' · meta ' + monto(m.Meta.MetaVentas) + ' por especialista' : ' · meta individual por especialista'));
        $('#duMetaTitulo').text(d.Especialista ? 'Mi meta del mes' : 'Metas del mes por especialista');
        $('#duMetaUno').toggleClass('d-none', !d.Especialista);
        $('#duMetaTodos').toggleClass('d-none', !!d.Especialista);
        if (!d.Especialista) { metaTodos(m); return; }

        var color = e.CumpleMeta ? COLOR_META.ok : e.Ventas > mt.MinimoComision ? COLOR_META.va : COLOR_META.bajo;
        grafico('duGraficoMeta', {
            chart: { type: 'radialBar', height: 230, fontFamily: 'inherit' },
            series: [Math.min(100, e.Avance)],
            colors: [color],
            plotOptions: { radialBar: { hollow: { size: '62%' }, track: { background: '#eef1f4' },
                dataLabels: { name: { offsetY: 22, color: '#6c757d', fontSize: '12px' }, value: { offsetY: -12, fontSize: '26px', fontWeight: 700, formatter: function () { return e.Avance + ' %'; } } } } },
            labels: [e.CumpleMeta ? '¡Meta cumplida!' : 'de la meta'],
            stroke: { lineCap: 'round' }
        });

        function dato(t, v, sub, cls) {
            return '<div class="col"><div class="border rounded-3 p-2 h-100"><div class="small text-muted">' + t + '</div><div class="fw-bold fs-5 ' + (cls || '') + '">' + v + '</div>'
                + (sub ? '<div class="small text-muted">' + sub + '</div>' : '') + '</div></div>';
        }
        $('#duMetaDatos').html(
            dato('Ventas sin IVA', dinero(e.Ventas), num(e.Procedimientos) + ' procedimientos')
            + dato('Meta', dinero(mt.MetaVentas), e.CumpleMeta ? '<span class="text-success"><i class="bx bx-check-circle"></i> cumplida</span>' : 'faltan ' + dinero(e.FaltaMeta))
            + dato('Bono estimado', dinero(e.TotalBono), e.PorcentajeEscala ? 'escala ' + e.PorcentajeEscala + ' %' + (e.BonoAlcance ? ' + alcance ' + monto(e.BonoAlcance) : '') : 'mínimo ' + monto(mt.MinimoComision), 'text-success')
            + dato('Proyección a fin de mes', e.Proyeccion != null ? dinero(e.Proyeccion) : '—',
                e.SiguienteEscala != null ? 'siguiente escala desde ' + monto(e.SiguienteEscala) : 'en la escala más alta'));

        var esc0 = mt.Escalas || [];
        var actual = e.PorcentajeEscala ? $.grep(esc0, function (x) { return e.Ventas > x.Desde - 1; }).pop() : null;
        $('#duMetaEscala').html(esc0.map(function (x) {
            var es = actual && x.Desde === actual.Desde;
            return '<div class="du-fila' + (es ? ' du-hoy' : '') + '"><span class="du-cuando">' + (es ? '<i class="bx bx-right-arrow-alt"></i> ' : '') + x.Porcentaje + ' %</span>'
                + '<div class="du-cuerpo"><span>' + monto(x.Desde) + (x.Hasta != null ? ' a ' + monto(x.Hasta) : ' en adelante') + '</span>'
                + (x.Bono ? '<small class="text-muted">+ bono ' + monto(x.Bono) + '</small>' : '') + '</div></div>';
        }).join('') + (mt.BonoAlcance ? '<div class="small text-muted mt-1"><i class="bx bx-trophy"></i> Bono por cumplir la meta: ' + monto(mt.BonoAlcance) + '</div>' : '')
            // meta sugerida del próximo mes (promedio de los últimos meses × factor del mes × crecimiento)
            + (d.MetaSugerida && !d.MetaSugerida.SinDatos ? '<div class="small mt-2 text-warning-emphasis" title="' + esc(d.MetaSugerida.Detalle) + '"><i class="bx bx-bulb"></i> Meta sugerida para '
                + esc(d.MetaSugerida.Periodo.toLowerCase()) + ': <strong>' + monto(d.MetaSugerida.Sugerida) + '</strong></div>' : ''));
    }

    // Administrador sin especialista vinculado: avance de cada especialista
    function metaTodos(m) {
        var lista = $.grep(m.Especialistas, function (e) { return e.Meta && (e.Ventas > 0 || e.Procedimientos > 0); });
        if (!lista.length) lista = $.grep(m.Especialistas, function (e) { return e.Meta; });
        $('#duMetaTodos').html(lista.map(function (e) {
            var mt = e.Meta;
            var color = e.CumpleMeta ? 'bg-success' : e.Ventas > mt.MinimoComision ? 'bg-info' : 'bg-warning';
            return '<div class="row g-2 align-items-center py-2 border-bottom">'
                + '<div class="col-md-3"><div class="fw-semibold">' + esc(e.Especialista) + '</div><small class="text-muted">meta ' + monto(mt.MetaVentas) + '</small></div>'
                + '<div class="col-md-5"><div class="d-flex justify-content-between small"><span>' + dinero(e.Ventas) + ' · ' + e.Avance + ' %</span>'
                + (e.CumpleMeta ? '<span class="text-success"><i class="bx bx-check-circle"></i> Meta cumplida</span>' : '<span class="text-muted">faltan ' + dinero(e.FaltaMeta) + '</span>') + '</div>'
                + '<div class="progress" style="height:8px"><div class="progress-bar ' + color + '" style="width:' + Math.min(100, e.Avance) + '%"></div></div></div>'
                + '<div class="col-6 col-md-2 small text-md-end">' + (e.PorcentajeEscala ? 'escala ' + e.PorcentajeEscala + ' %' : '<span class="text-muted">bajo el mínimo</span>')
                + (e.Proyeccion != null ? '<div class="text-muted">proy. ' + dinero(e.Proyeccion) + '</div>' : '') + '</div>'
                + '<div class="col-6 col-md-2 text-end"><div class="small text-muted">bono estimado</div><strong class="text-success">' + dinero(e.TotalBono) + '</strong></div>'
                + '</div>';
        }).join(''));
    }

    /* ---------- garantías de servicios (últimos 90 días) ---------- */
    function fechaCorta(iso) { if (!iso) return ''; var p = iso.split('-'); return p[2] + '/' + p[1] + '/' + p[0]; }

    function garantias(d) {
        var lista = d.Garantias || [], mes = String(d.Hoy || '').substr(0, 7);
        var delMes = $.grep(lista, function (g) { return g.Fecha.substr(0, 7) === mes; }).length;
        $('th.du-esp-col').toggleClass('d-lg-table-cell', !d.Especialista);   // el especialista ve solo las suyas: la columna sobra
        $('#duGarantiasResumen').html(lista.length
            ? '<strong>' + num(delMes) + '</strong> este mes · <strong>' + num(lista.length) + '</strong> en 90 días' : '');
        if (!lista.length) {
            $('#duGarantias').html('<tr><td colspan="6">' + vacio('<i class="bx bx-check-shield fs-3 d-block mb-1"></i>Sin garantías de servicios en los últimos 90 días.') + '</td></tr>');
            return;
        }
        $('#duGarantias').html(lista.map(function (g) {
            return '<tr>'
                + '<td class="text-nowrap">' + esc(fechaCorta(g.Fecha)) + '<br><small class="text-muted">' + esc(g.Hora) + '</small></td>'
                + '<td><span class="fw-semibold">' + esc(titulo(g.Paciente)) + '</span>'
                + (g.Celular ? '<br><small class="text-muted"><i class="bx bx-phone"></i> ' + esc(g.Celular) + '</small>' : '') + '</td>'
                + '<td class="d-none d-md-table-cell small">' + (g.FechaProcedimiento ? esc(fechaCorta(g.FechaProcedimiento)) : '—')
                + (g.Tratamientos ? '<br><span class="text-muted">' + esc(g.Tratamientos) + '</span>' : '') + '</td>'
                + (d.Especialista ? '' : '<td class="du-esp-col d-none d-lg-table-cell small">' + esc(g.Especialista) + '</td>')
                + '<td class="small" style="white-space:pre-wrap;min-width:220px;">' + esc(g.Detalle) + '</td>'
                + '<td class="d-none d-lg-table-cell small text-muted">' + esc(g.Usuario) + '</td>'
                + '</tr>';
        }).join(''));
    }

    /* ---------- gráficos ---------- */
    function grafico(id, opciones) {
        if (graficos[id]) { graficos[id].updateOptions(opciones, true, true); return; }
        if (typeof ApexCharts === 'undefined' || !document.getElementById(id)) return;
        graficos[id] = new ApexCharts(document.getElementById(id), opciones);
        graficos[id].render();
    }

    function dibujarGraficos(d) {
        var semana = d.Semana || [];
        grafico('duGraficoSemana', {
            chart: { type: 'bar', height: 180, toolbar: { show: false }, fontFamily: 'inherit' },
            series: [{ name: 'Citas', data: semana.map(function (s) { return s.Cantidad; }) }],
            xaxis: { categories: semana.map(function (s, i) { return i === 0 ? 'Hoy' : diaCorto(s.Dia); }) },
            yaxis: { labels: { formatter: function (v) { return Math.round(v); } }, forceNiceScale: true, min: 0 },
            colors: [COLOR.lila],
            plotOptions: { bar: { borderRadius: 4, columnWidth: '55%', dataLabels: { position: 'top' } } },
            dataLabels: { enabled: true, style: { colors: ['#495057'] }, offsetY: -18, formatter: function (v) { return v || ''; } },
            grid: { strokeDashArray: 4 },
            tooltip: { y: { formatter: function (v) { return v + (v === 1 ? ' cita' : ' citas'); } } }
        });

        var p30 = d.Procedimientos30 || [];
        grafico('duGraficoProc', {
            chart: { type: 'area', height: 290, toolbar: { show: false }, fontFamily: 'inherit', zoom: { enabled: false } },
            series: [{ name: 'Procedimientos', data: p30.map(function (s) { return s.Cantidad; }) }],
            xaxis: { categories: p30.map(function (s) { return diaCorto(s.Dia); }), tickAmount: 10, labels: { rotate: 0 } },
            yaxis: { labels: { formatter: function (v) { return Math.round(v); } }, min: 0, forceNiceScale: true },
            colors: [COLOR.acento],
            stroke: { curve: 'straight', width: 2 },
            fill: { type: 'gradient', gradient: { opacityFrom: .35, opacityTo: .05 } },
            dataLabels: { enabled: false },
            grid: { strokeDashArray: 4 }
        });
    }

    /* ---------- carga ---------- */
    function cargar() {
        if (cargando) return;
        cargando = true;
        $('#dashboardUsuario').addClass('db-cargando');
        api('Datos').done(function (d) {
            if (!d || !d.Ok) {
                if (d && /sesi[oó]n/i.test(d.Mensaje || '') && typeof mtd_ValidateSession === 'function') mtd_ValidateSession();
                else showNotification(1, 'error', (d && d.Mensaje) || 'No fue posible cargar el dashboard.');
                return;
            }
            saludo(d);
            indicadores(d);
            agenda(d);
            proximas(d);
            cumpleanos(d);
            tratamientos(d);
            garantias(d);
            dibujarGraficos(d);
            meta(d);
        }).fail(function (xhr) {
            if (xhr.statusText !== 'abort') showNotification(1, 'error', 'Error de conexión (HTTP ' + xhr.status + ').');
        }).always(function () {
            cargando = false;
            $('#dashboardUsuario').removeClass('db-cargando');
        });
    }

    $('#duRefrescar').on('click', cargar);
    $('#dashboardUsuario').on('click', '[data-ir]', function () { if (typeof AjaxLink === 'function') AjaxLink($(this).data('ir')); });

    cargar();
    // Se actualiza solo mientras la página siga abierta (al abrir otra página desaparece #dashboardUsuario)
    window.__duTimer = setInterval(function () {
        if (!document.getElementById('dashboardUsuario')) { clearInterval(window.__duTimer); return; }
        if (!document.hidden) cargar();
    }, REFRESCO_MS);

})(jQuery);
