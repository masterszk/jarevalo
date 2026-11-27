/* Dashboard de indicadores – Dashboard/form_DashboardGeneral.aspx (gráficos con ApexCharts)
   KPI con variación contra el periodo anterior de igual duración y tendencia diaria;
   gráficas de expedientes nuevos, citas, procedimientos y top 10 de pacientes recurrentes. */
(function ($) {
    'use strict';

    var URL = 'Dashboard/form_DashboardGeneral.aspx/';
    var COLOR = { acento: '#0d8f9b', exito: '#198754', peligro: '#dc3545', lila: '#b591bd', ambar: '#f2a516', gris: '#adb5bd' };
    var BOOTSTRAP = { success: COLOR.exito, danger: COLOR.peligro, info: '#0dcaf0', warning: COLOR.ambar, primary: COLOR.acento, secondary: COLOR.gris };
    var CLAVE_PERIODO = 'dpie.dashboard.periodo', CLAVE_ALCANCE = 'dpie.dashboard.top';

    // La página se carga con AjaxLink: se destruyen los gráficos de una carga anterior
    if (window.__dashboardGraficos) $.each(window.__dashboardGraficos, function (_, g) { try { g.destroy(); } catch (e) { } });
    var graficos = window.__dashboardGraficos = {};
    var state = { desde: '', hasta: '', alcance: leer(CLAVE_ALCANCE) || '12m', consulta: 0 };

    /* ---------- utilidades ---------- */
    function esc(s) { return $('<div/>').text(s == null ? '' : String(s)).html(); }
    function dinero(n) { return '$ ' + Number(n || 0).toLocaleString('es-SV', { minimumFractionDigits: 2, maximumFractionDigits: 2 }); }
    function num(n) { return Number(n || 0).toLocaleString('es-SV'); }
    function dos(n) { return (n < 10 ? '0' : '') + n; }
    function iso(d) { return d.getFullYear() + '-' + dos(d.getMonth() + 1) + '-' + dos(d.getDate()); }
    function texto(isoFecha) { var p = isoFecha.split('-'); return p[2] + '/' + p[1] + '/' + p[0]; }
    function corto(isoFecha) { return isoFecha.substr(8, 2) + '/' + isoFecha.substr(5, 2); }
    function titulo(s) { return String(s || '').toLowerCase().replace(/(^|\s)(\S)/g, function (m, a, b) { return a + b.toUpperCase(); }); }
    function nombreCorto(s) { var p = titulo(s).split(/\s+/); return p.length > 2 ? p[0] + ' ' + p[p.length > 3 ? 2 : 1] : p.join(' '); }
    function vacio(t) { return '<div class="text-center text-muted py-4 small">' + t + '</div>'; }
    function leer(c) { try { return localStorage.getItem(c); } catch (e) { return null; } }
    function guardar(c, v) { try { localStorage.setItem(c, v); } catch (e) { } }
    function api(metodo, datos) {
        return $.ajax({
            type: 'POST',
            url: URL + metodo,
            data: JSON.stringify(datos),
            contentType: 'application/json; charset=utf-8',
            dataType: 'json'
        }).then(function (r) { return r.d; });
    }
    function falla(xhr) { showNotification(1, 'error', 'Error de conexión (HTTP ' + xhr.status + ').'); }

    function rango(periodo) {
        var hoy = new Date(), d = new Date(hoy), h = new Date(hoy);
        if (periodo === '7') d.setDate(hoy.getDate() - 6);
        else if (periodo === '90') d.setDate(hoy.getDate() - 89);
        // mes a la fecha: así se compara contra la misma cantidad de días del periodo anterior
        else if (periodo === 'mes') d = new Date(hoy.getFullYear(), hoy.getMonth(), 1);
        else if (periodo === 'anterior') { d = new Date(hoy.getFullYear(), hoy.getMonth() - 1, 1); h = new Date(hoy.getFullYear(), hoy.getMonth(), 0); }
        return { desde: iso(d), hasta: iso(h) };
    }

    // Variación porcentual contra el periodo anterior. puntos = true para porcentajes (asistencia)
    function delta(id, actual, anterior, rangoAnt, puntos) {
        var $d = $('#' + id).removeClass('db-sube db-baja db-igual');
        var t, clase;
        if (puntos) {
            var p = Math.round((actual - anterior) * 10) / 10;
            t = (p > 0 ? '▲ +' : p < 0 ? '▼ ' : '') + p + ' pts';
            clase = p > 0 ? 'db-sube' : p < 0 ? 'db-baja' : 'db-igual';
        } else if (!anterior) {
            t = actual ? '▲ nuevo' : '—';
            clase = actual ? 'db-sube' : 'db-igual';
        } else {
            var pct = Math.round((actual - anterior) / anterior * 100);
            t = (pct > 0 ? '▲ +' : pct < 0 ? '▼ ' : '= ') + pct + ' %';
            clase = pct > 0 ? 'db-sube' : pct < 0 ? 'db-baja' : 'db-igual';
        }
        $d.addClass(clase).text(t).attr('title', 'Periodo anterior (' + rangoAnt + '): ' + (puntos ? anterior + ' %' : num(anterior)));
    }

    /* ---------- carga ---------- */
    function cargar(desde, hasta) {
        state.desde = desde; state.hasta = hasta;
        var id = ++state.consulta;
        $('#dbDesde').val(desde);
        $('#dbHasta').val(hasta);
        $('#dbRango').text('Cargando…');
        $('#dashboard').addClass('db-cargando');

        api('Datos', { desde: desde, hasta: hasta }).done(function (d) {
            if (id !== state.consulta) return;
            if (!d.Ok) { showNotification(1, 'warning', d.Mensaje); $('#dbRango').text(''); return; }
            render(d);
        }).fail(falla).always(function () { if (id === state.consulta) $('#dashboard').removeClass('db-cargando'); });

        if (state.alcance === 'periodo') cargarTop();
    }

    function render(d) {
        var ahora = new Date(), k = d.Indicadores, a = d.Anterior;
        var rangoAnt = a ? (a.Desde === a.Hasta ? texto(a.Desde) : texto(a.Desde) + ' al ' + texto(a.Hasta)) : '';
        $('#dbRango').text((d.Desde === d.Hasta ? texto(d.Desde) : texto(d.Desde) + ' al ' + texto(d.Hasta)) +
            ' · comparado con ' + rangoAnt + ' · actualizado ' + horaDe(ahora));
        $('.db-dinero').toggleClass('d-none', !d.VerDinero);

        var serie = serieDiaria(d);

        // KPI principales
        $('#kNuevos').text(num(k.PacientesNuevos));
        $('#kNuevosSub').text('expedientes abiertos');
        $('#kCitas').text(num(k.Citas));
        $('#kCitasSub').html('<span class="text-success">' + num(k.CitasAtendidas) + ' atendidas</span> · <span class="text-danger">' + num(k.CitasCanceladas) + ' canceladas</span>');
        $('#kProc').text(num(k.Procedimientos));
        $('#kProcSub').text(num(k.PacientesAtendidos) + ' pacientes' + (k.MinutosPromedio ? ' · ' + k.MinutosPromedio + ' min prom.' : ''));
        $('#kAsistencia').text(k.CitasAtendidas + k.CitasCanceladas ? k.Asistencia + ' %' : '—');
        $('#kAsistenciaSub').text(num(k.CitasPendientes) + ' citas pendientes');
        $('#kAsistenciaBarra').css('width', (k.Asistencia || 0) + '%');
        if (a) {
            delta('kNuevosDelta', k.PacientesNuevos, a.PacientesNuevos, rangoAnt);
            delta('kCitasDelta', k.Citas, a.Citas, rangoAnt);
            delta('kProcDelta', k.Procedimientos, a.Procedimientos, rangoAnt);
            delta('kAsistenciaDelta', k.Asistencia, a.Asistencia, rangoAnt, true);
        }
        sparkline('sparkNuevos', serie.dias, serie.nuevos, COLOR.lila, 'Nuevos');
        sparkline('sparkCitas', serie.dias, serie.citas, COLOR.acento, 'Citas');
        sparkline('sparkProc', serie.dias, serie.procedimientos, COLOR.exito, 'Procedimientos');

        // KPI secundarios
        $('#kPacientes').text(num(k.Pacientes));
        $('#kPacientesSub').text('total de expedientes');
        if (d.VerDinero) {
            $('#kFacturado').text(dinero(k.Facturado));
            $('#kFacturadoSub').html((k.TicketPromedio ? 'Ticket ' + dinero(k.TicketPromedio) + ' · ' : '') +
                (a && a.Facturado ? 'antes ' + dinero(a.Facturado) : ''));
            $('#kCobrado').text(dinero(k.Cobrado));
            $('#kCobradoSub').text('documentos emitidos en caja');
        }
        $('#kAhora').text(num(k.EnAtencion) + ' en atención');
        $('#kAhoraSub').text(num(k.EnSala) + ' en sala de espera');

        if (d.VerDinero) { graficoIngresos(serie, d.IngresosFormaPago); graficoMetas(d.Metas); graficoMetasHist(d.MetasHistorico); }
        graficoNuevosDia(serie);
        graficoNuevos(d.NuevosPorMes);
        renderFuentes(d.Fuentes);
        graficoPacientesCita(serie, d.PacientesCitaDia || [], d.PacientesCitaPeriodo);
        graficoCitas(serie, d.CitasPorDia.length);
        graficoEstados(d.EstadosCita);
        graficoProc(serie);
        renderTratamientos(d);
        renderEspecialistas(d);
        renderGarantias(d.Garantias);
        renderHoy(d.Hoy);
    }

    // Completa los días sin movimiento para que los ejes sean continuos
    function serieDiaria(d) {
        var porDia = {}, s = { dias: [], citas: [], atendidas: [], canceladas: [], otras: [], procedimientos: [], nuevos: [], efectivo: [], otrasFormas: [] };
        $.each(d.CitasPorDia, function (_, x) { porDia[x.Dia] = x; });
        for (var f = new Date(d.Desde + 'T00:00:00'), fin = new Date(d.Hasta + 'T00:00:00'); f <= fin; f.setDate(f.getDate() + 1)) {
            var dia = iso(f), x = porDia[dia] || { Total: 0, Atendidas: 0, Canceladas: 0, Procedimientos: 0, Nuevos: 0, Ingresos: 0, IngresosEfectivo: 0 };
            var ef = Number(x.IngresosEfectivo || 0);
            s.efectivo.push(Math.round(ef * 100) / 100);
            s.otrasFormas.push(Math.round((Number(x.Ingresos || 0) - ef) * 100) / 100);
            s.dias.push(dia);
            s.citas.push(x.Total);
            s.atendidas.push(x.Atendidas);
            s.canceladas.push(x.Canceladas);
            s.otras.push(x.Total - x.Atendidas - x.Canceladas);
            s.procedimientos.push(x.Procedimientos);
            s.nuevos.push(x.Nuevos);
        }
        return s;
    }

    function suma(a) { var t = 0; $.each(a, function (_, v) { t += v; }); return t; }

    function dibujar(id, opciones) {
        if (graficos[id]) { try { graficos[id].destroy(); } catch (e) { } delete graficos[id]; }
        var el = document.getElementById(id);
        if (!el || typeof ApexCharts === 'undefined') return;
        $(el).empty();
        graficos[id] = new ApexCharts(el, opciones);
        graficos[id].render();
    }

    function sinDatos(id, mensaje) {
        if (graficos[id]) { try { graficos[id].destroy(); } catch (e) { } delete graficos[id]; }
        $('#' + id).html(vacio(mensaje));
    }

    function ejeDias(dias) {
        return { categories: $.map(dias, corto), labels: { rotate: -45, hideOverlappingLabels: true }, tickPlacement: 'on' };
    }
    var ejeEnteros = { labels: { formatter: function (v) { return Math.round(v); } }, forceNiceScale: true, min: 0 };

    function sparkline(id, dias, datos, color, nombre) {
        if (dias.length < 2) { sinDatos(id, ''); return; }
        dibujar(id, {
            chart: { type: 'area', height: 46, sparkline: { enabled: true }, fontFamily: 'inherit' },
            series: [{ name: nombre, data: datos }],
            labels: $.map(dias, texto),
            colors: [color],
            stroke: { curve: 'smooth', width: 2 },
            fill: { type: 'gradient', gradient: { opacityFrom: .4, opacityTo: 0 } },
            tooltip: { x: { show: true }, y: { title: { formatter: function () { return nombre + ':'; } } } }
        });
    }

    // Ingresos diarios: barras apiladas por forma de pago, con la línea del promedio por día con ingresos
    var COLORES_PAGO = { '01': '#198754', '02': '#0d6efd', '03': '#0d8f9b', '04': '#f2a516', '05': '#b591bd', '99': '#adb5bd' };
    function graficoIngresos(s, porForma) {
        var formas = [], idx = {}, dia = {};
        $.each(s.dias, function (i, d) { dia[d] = i; });
        $.each(porForma || [], function (_, x) {
            if (!(x.Codigo in idx)) { idx[x.Codigo] = formas.length; formas.push({ codigo: x.Codigo, nombre: x.FormaPago, datos: $.map(s.dias, function () { return 0; }), total: 0 }); }
            var f = formas[idx[x.Codigo]], i = dia[x.Dia];
            if (i === undefined) return;
            f.datos[i] = Math.round((f.datos[i] + Number(x.Total)) * 100) / 100;
            f.total += Number(x.Total);
        });
        formas.sort(function (a, b) { return a.codigo < b.codigo ? -1 : 1; });
        var totales = $.map(s.dias, function (_, i) { var t = 0; $.each(formas, function (_, f) { t += f.datos[i]; }); return Math.round(t * 100) / 100; });
        var total = suma(totales), conIngreso = $.grep(totales, function (v) { return v > 0; }).length;
        if (!total) {
            $('#dbIngresosResumen').text('');
            sinDatos('dbGraficoIngresos', 'No hay cobros en caja en el periodo.');
            return;
        }
        var promedio = Math.round(total / conIngreso * 100) / 100, max = Math.max.apply(null, totales), iMax = totales.indexOf(max);
        $('#dbIngresosResumen').html('Total <b>' + dinero(total) + '</b> · promedio ' + dinero(promedio) + ' por día con cobros · mejor día ' + texto(s.dias[iMax]) + ' (' + dinero(max) + ')' +
            '<br>' + $.map(formas, function (f) { return esc(f.nombre) + ' <b>' + dinero(f.total) + '</b> (' + Math.round(100 * f.total / total) + '%)'; }).join(' · '));
        dibujar('dbGraficoIngresos', {
            chart: { type: 'bar', height: 280, stacked: true, toolbar: { show: false }, fontFamily: 'inherit' },
            series: $.map(formas, function (f) { return { name: f.nombre, data: f.datos }; }),
            colors: $.map(formas, function (f) { return COLORES_PAGO[f.codigo] || COLOR.gris; }),
            xaxis: ejeDias(s.dias),
            yaxis: { min: 0, forceNiceScale: true, labels: { formatter: function (v) { return '$' + Math.round(v); } } },
            plotOptions: { bar: { columnWidth: s.dias.length > 40 ? '90%' : '60%', borderRadius: 2 } },
            dataLabels: { enabled: false },
            legend: { position: 'top', horizontalAlign: 'left' },
            tooltip: {
                shared: true, intersect: false,
                y: { formatter: function (v) { return dinero(v); } },
                x: { formatter: function (v, o) { var i = o.dataPointIndex; return texto(s.dias[i]) + ' · total ' + dinero(totales[i]); } }
            },
            annotations: {
                yaxis: [{
                    y: promedio, borderColor: COLOR.ambar, strokeDashArray: 4,
                    label: { text: 'Promedio ' + dinero(promedio), style: { background: COLOR.ambar, color: '#3b2a00' } }
                }]
            },
            grid: { borderColor: 'rgba(0,0,0,.06)' }
        });
    }

    function graficoNuevosDia(s) {
        if (!suma(s.nuevos)) { sinDatos('dbGraficoNuevosDia', 'No se abrieron expedientes en el periodo.'); return; }
        dibujar('dbGraficoNuevosDia', {
            chart: { type: 'bar', height: 260, toolbar: { show: false }, fontFamily: 'inherit' },
            series: [{ name: 'Pacientes nuevos', data: s.nuevos }],
            colors: [COLOR.lila],
            xaxis: ejeDias(s.dias),
            yaxis: ejeEnteros,
            plotOptions: { bar: { columnWidth: s.dias.length > 40 ? '90%' : '55%', borderRadius: 3 } },
            dataLabels: { enabled: s.dias.length <= 31, style: { fontSize: '10px' }, formatter: function (v) { return v || ''; } },
            grid: { borderColor: 'rgba(0,0,0,.06)' }
        });
    }

    function graficoNuevos(meses) {
        dibujar('dbGraficoNuevos', {
            chart: { type: 'area', height: 180, toolbar: { show: false }, fontFamily: 'inherit' },
            series: [{ name: 'Expedientes nuevos', data: $.map(meses, function (m) { return m.Cantidad; }) }],
            xaxis: { categories: $.map(meses, function (m) { return m.Nombre; }) },
            yaxis: ejeEnteros,
            colors: [COLOR.lila],
            stroke: { curve: 'smooth', width: 3 },
            fill: { type: 'gradient', gradient: { opacityFrom: .45, opacityTo: .05 } },
            dataLabels: { enabled: false },
            grid: { borderColor: 'rgba(0,0,0,.06)' }
        });
    }

    // Pacientes con cita por día: expediente creado en meses anteriores al de la cita vs en el mes de la cita
    function graficoPacientesCita(s, dias, periodo) {
        var porDia = {};
        $.each(dias, function (_, x) { porDia[x.Dia] = x; });
        var ant = $.map(s.dias, function (d) { return porDia[d] ? porDia[d].Anteriores : 0; }),
            nue = $.map(s.dias, function (d) { return porDia[d] ? porDia[d].Nuevos : 0; });
        if (!suma(ant) && !suma(nue)) {
            $('#dbPacCitaResumen').text('');
            sinDatos('dbGraficoPacCita', 'No hay pacientes con cita en el periodo.');
            return;
        }
        var p = periodo || { Anteriores: 0, Nuevos: 0 }, tot = p.Anteriores + p.Nuevos;
        $('#dbPacCitaResumen').html('Periodo: <b>' + num(tot) + '</b> pacientes · ' + num(p.Anteriores) + ' antiguos' +
            (tot ? ' (' + Math.round(100 * p.Anteriores / tot) + '%)' : '') + ' · ' + num(p.Nuevos) + ' nuevos' +
            (tot ? ' (' + Math.round(100 * p.Nuevos / tot) + '%)' : ''));
        dibujar('dbGraficoPacCita', {
            chart: { type: 'bar', height: 280, stacked: true, toolbar: { show: false }, fontFamily: 'inherit' },
            series: [{ name: 'Pacientes antiguos', data: ant }, { name: 'Pacientes nuevos', data: nue }],
            colors: [COLOR.acento, COLOR.lila],
            xaxis: ejeDias(s.dias),
            yaxis: ejeEnteros,
            plotOptions: { bar: { columnWidth: s.dias.length > 40 ? '90%' : '60%', borderRadius: 2 } },
            dataLabels: { enabled: s.dias.length <= 31, style: { fontSize: '10px' }, formatter: function (v) { return v || ''; } },
            legend: { position: 'top', horizontalAlign: 'left' },
            tooltip: {
                shared: true, intersect: false,
                x: { formatter: function (v, o) { var i = o.dataPointIndex; return texto(s.dias[i]) + ' · ' + num(ant[i] + nue[i]) + ' pacientes con cita'; } }
            },
            grid: { borderColor: 'rgba(0,0,0,.06)' }
        });
    }

    function renderFuentes(fuentes) {
        var total = 0, $c = $('#dbFuentes').empty();
        $.each(fuentes, function (_, f) { total += f.Cantidad; });
        if (!total) { $c.html('<span class="text-muted small">Sin expedientes nuevos en el periodo.</span>'); return; }
        var iconos = { Facebook: 'bxl-facebook-circle', Instagram: 'bxl-instagram', TikTok: 'bx-music', WhatsApp: 'bxl-whatsapp','Buscador web': 'bx-search-alt', Recomendado: 'bx-like', Otros: 'bx-dots-horizontal-rounded', 'Sin dato': 'bx-help-circle' };
        $.each(fuentes, function (_, f) {
            if (!f.Cantidad) return;
            $c.append('<span class="db-fuente"><i class="bx ' + (iconos[f.Nombre] || 'bx-circle') + '"></i> ' + esc(f.Nombre) +
                ' <b>' + num(f.Cantidad) + '</b> <span class="text-muted">(' + Math.round(100 * f.Cantidad / total) + '%)</span></span>');
        });
    }

    function graficoCitas(s, hayCitas) {
        if (!hayCitas || !suma(s.citas)) { sinDatos('dbGraficoCitas', 'No hay citas en el periodo.'); return; }
        dibujar('dbGraficoCitas', {
            chart: { type: 'bar', height: 280, stacked: true, toolbar: { show: false }, fontFamily: 'inherit' },
            series: [{ name: 'Atendidas', data: s.atendidas }, { name: 'Programadas / en proceso', data: s.otras }, { name: 'Canceladas', data: s.canceladas }],
            colors: [COLOR.exito, COLOR.acento, COLOR.peligro],
            xaxis: ejeDias(s.dias),
            yaxis: ejeEnteros,
            plotOptions: { bar: { columnWidth: s.dias.length > 40 ? '90%' : '60%', borderRadius: 2 } },
            dataLabels: { enabled: false },
            legend: { position: 'top', horizontalAlign: 'left' },
            grid: { borderColor: 'rgba(0,0,0,.06)' }
        });
    }

    function graficoEstados(estados) {
        if (!estados.length) { sinDatos('dbGraficoEstados', 'Sin datos.'); return; }
        dibujar('dbGraficoEstados', {
            chart: { type: 'donut', height: 280, fontFamily: 'inherit' },
            series: $.map(estados, function (e) { return e.Cantidad; }),
            labels: $.map(estados, function (e) { return e.Nombre; }),
            colors: $.map(estados, function (e) { return e.Nombre === 'En proceso' ? COLOR.lila : (BOOTSTRAP[e.Color] || COLOR.gris); }),
            legend: { position: 'bottom' },
            dataLabels: { enabled: true, formatter: function (v) { return Math.round(v) + '%'; } },
            plotOptions: { pie: { donut: { size: '62%', labels: { show: true, total: { show: true, label: 'Citas' } } } } }
        });
    }

    // Procedimientos por día con la línea del promedio diario del periodo
    function graficoProc(s) {
        if (!suma(s.procedimientos)) { sinDatos('dbGraficoProc', 'No hay procedimientos finalizados en el periodo.'); return; }
        var promedio = Math.round(suma(s.procedimientos) / s.dias.length * 10) / 10;
        dibujar('dbGraficoProc', {
            chart: { type: 'area', height: 280, toolbar: { show: false }, fontFamily: 'inherit' },
            series: [{ name: 'Procedimientos', data: s.procedimientos }],
            colors: [COLOR.exito],
            xaxis: ejeDias(s.dias),
            yaxis: ejeEnteros,
            stroke: { curve: 'smooth', width: 3 },
            fill: { type: 'gradient', gradient: { opacityFrom: .35, opacityTo: .05 } },
            markers: { size: s.dias.length <= 31 ? 3 : 0 },
            dataLabels: { enabled: false },
            annotations: {
                yaxis: [{
                    y: promedio, borderColor: COLOR.ambar, strokeDashArray: 4,
                    label: { text: 'Promedio ' + promedio + '/día', style: { background: COLOR.ambar, color: '#3b2a00' } }
                }]
            },
            grid: { borderColor: 'rgba(0,0,0,.06)' }
        });
    }

    function renderTratamientos(d) {
        var $c = $('#dbTratamientos').empty();
        if (!d.Tratamientos.length) { $c.html(vacio('No hay procedimientos finalizados en el periodo.')); return; }
        var max = d.Tratamientos[0].Cantidad || 1;
        $.each(d.Tratamientos, function (_, t) {
            $c.append(
                '<div class="db-trat">' +
                '  <div class="d-flex justify-content-between small"><span class="text-truncate me-2">' + esc(titulo(t.Nombre)) + '</span>' +
                '    <span class="text-nowrap"><b>' + num(t.Cantidad) + '</b>' + (d.VerDinero ? ' · ' + dinero(t.Total) : '') + '</span></div>' +
                '  <div class="progress db-barra"><div class="progress-bar" style="width:' + Math.round(100 * t.Cantidad / max) + '%"></div></div>' +
                '</div>');
        });
    }

    function renderEspecialistas(d) {
        var $t = $('#dbEspecialistas').empty(), $f = $('#dbEspecialistasTotal').empty();
        if (!d.Especialistas.length) { $t.html('<tr><td colspan="9">' + vacio('Sin especialistas.') + '</td></tr>'); return; }
        var tot = { Citas: 0, Atendidas: 0, Canceladas: 0, Procedimientos: 0, Pacientes: 0, Facturado: 0, FacturadoCaja: 0, Min: 0, NMin: 0 };
        var maxProc = Math.max.apply(null, $.map(d.Especialistas, function (e) { return e.Procedimientos; }).concat([1]));
        $.each(d.Especialistas, function (_, e) {
            var asist = e.Atendidas + e.Canceladas ? Math.round(100 * e.Atendidas / (e.Atendidas + e.Canceladas)) : null;
            $t.append(
                '<tr>' +
                '  <td><div class="fw-semibold">' + esc(e.Especialista) + (e.Activo ? '' : ' <span class="badge bg-secondary">Inactivo</span>') + '</div>' +
                '      <div class="progress db-barra" title="' + e.Procedimientos + ' procedimientos"><div class="progress-bar" style="width:' + Math.round(100 * e.Procedimientos / maxProc) + '%"></div></div></td>' +
                '  <td class="text-end">' + num(e.Citas) + '</td>' +
                '  <td class="text-end">' + num(e.Atendidas) + (asist !== null ? '<div class="small text-muted">' + asist + ' %</div>' : '') + '</td>' +
                '  <td class="text-end d-none d-md-table-cell">' + num(e.Canceladas) + '</td>' +
                '  <td class="text-end fw-semibold">' + num(e.Procedimientos) + '</td>' +
                '  <td class="text-end d-none d-md-table-cell">' + num(e.Pacientes) + '</td>' +
                '  <td class="text-end d-none d-lg-table-cell">' + (e.MinutosPromedio ? e.MinutosPromedio : '—') + '</td>' +
                (d.VerDinero ? '  <td class="text-end">' + dinero(e.Facturado) + '</td><td class="text-end">' + dinero(e.FacturadoCaja) + '</td>' : '') +
                '</tr>');
            tot.Citas += e.Citas; tot.Atendidas += e.Atendidas; tot.Canceladas += e.Canceladas;
            tot.Procedimientos += e.Procedimientos; tot.Pacientes += e.Pacientes;
            tot.Facturado += e.Facturado || 0; tot.FacturadoCaja += e.FacturadoCaja || 0;
            if (e.MinutosPromedio) { tot.Min += e.MinutosPromedio * e.Procedimientos; tot.NMin += e.Procedimientos; }
        });
        // Totales (pacientes: suma por especialista; minutos: promedio ponderado por procedimientos)
        var asistT = tot.Atendidas + tot.Canceladas ? Math.round(100 * tot.Atendidas / (tot.Atendidas + tot.Canceladas)) : null;
        $f.html(
            '<tr>' +
            '  <td>Total</td>' +
            '  <td class="text-end">' + num(tot.Citas) + '</td>' +
            '  <td class="text-end">' + num(tot.Atendidas) + (asistT !== null ? '<div class="small text-muted fw-normal">' + asistT + ' %</div>' : '') + '</td>' +
            '  <td class="text-end d-none d-md-table-cell">' + num(tot.Canceladas) + '</td>' +
            '  <td class="text-end">' + num(tot.Procedimientos) + '</td>' +
            '  <td class="text-end d-none d-md-table-cell">' + num(tot.Pacientes) + '</td>' +
            '  <td class="text-end d-none d-lg-table-cell">' + (tot.NMin ? (Math.round(10 * tot.Min / tot.NMin) / 10) : '—') + '</td>' +
            (d.VerDinero ? '  <td class="text-end">' + dinero(tot.Facturado) + '</td><td class="text-end">' + dinero(tot.FacturadoCaja) + '</td>' : '') +
            '</tr>');
    }

    // Metas: ventas sin IVA del mes por especialista contra la meta (línea) y el mínimo para comisionar (punteada)
    function graficoMetas(m) {
        var id = 'dbGraficoMetas';
        if (!m || !m.Meta) {
            $('#dbMetasPeriodo').text(m ? m.Periodo : ''); $('#dbMetasResumen,#dbMetasDetalle').empty();
            sinDatos(id, 'No hay metas registradas. Créelas en Registros › Metas.'); return;
        }
        // cada especialista tiene su propia meta (e.Meta); si todas son iguales se dibujan como líneas de referencia
        var meta = m.Meta, comun = !!m.MetaComun;
        var lista = $.grep(m.Especialistas || [], function (e) { return e.Meta && (e.Ventas > 0 || e.Procedimientos > 0); });
        if (!lista.length) lista = $.grep(m.Especialistas || [], function (e) { return e.Meta; });
        $('#dbMetasPeriodo').text(m.Periodo + (m.MesEnCurso ? ' · día ' + m.DiasTranscurridos + ' de ' + m.DiasMes : '')
            + (comun ? ' · meta ' + dinero(meta.MetaVentas) + ' por especialista' : ' · meta individual por especialista'));
        var cumplen = $.grep(lista, function (e) { return e.CumpleMeta; }).length;
        var bonos = 0; $.each(lista, function (_, e) { bonos += e.TotalBono; });
        $('#dbMetasResumen').html('<strong>' + cumplen + '</strong> de ' + lista.length + ' cumplen la meta · bonos estimados <strong>' + dinero(bonos) + '</strong>');
        if (!lista.length) { sinDatos(id, 'Sin especialistas con meta.'); return; }

        var series = [{ name: 'Ventas sin IVA', type: 'bar', data: $.map(lista, function (e) { return e.Ventas; }) }];
        if (m.MesEnCurso) series.push({ name: 'Proyección a fin de mes', type: 'bar', data: $.map(lista, function (e) { return e.Proyeccion || 0; }) });
        if (!comun) series.push({ name: 'Meta', type: 'line', data: $.map(lista, function (e) { return e.Meta.MetaVentas; }) });
        var maxMeta = Math.max.apply(null, $.map(lista, function (e) { return e.Meta.MetaVentas; }));
        var maxY = Math.max(maxMeta * 1.15, Math.max.apply(null, $.map(series, function (s) { return Math.max.apply(null, s.data); })) * 1.1);
        var colorBarra = function (o) { var e = lista[o.dataPointIndex]; return e && e.CumpleMeta ? COLOR.exito : e && e.Ventas > e.Meta.MinimoComision ? COLOR.acento : COLOR.ambar; };
        var colores = [colorBarra]; if (m.MesEnCurso) colores.push('#cfd4da'); if (!comun) colores.push(COLOR.exito);
        dibujar(id, {
            chart: { type: 'line', height: 320, toolbar: { show: false }, fontFamily: 'inherit' },
            series: series,
            colors: colores,
            stroke: { width: 0 },     // la meta individual se ve como un marcador sobre cada barra
            markers: { size: $.map(series, function (s) { return s.type === 'line' ? 7 : 0; }), shape: 'square', strokeWidth: 0, hover: { sizeOffset: 2 } },
            plotOptions: { bar: { borderRadius: 4, columnWidth: m.MesEnCurso ? '60%' : '45%', dataLabels: { position: 'top' } } },
            dataLabels: {
                enabled: true, enabledOnSeries: [0], offsetY: -18, style: { colors: ['#495057'], fontSize: '11px' }, background: { enabled: false },
                formatter: function (v, o) { return lista[o.dataPointIndex].Avance + ' %'; }
            },
            xaxis: { categories: $.map(lista, function (e) { return e.Especialista; }) },
            yaxis: { min: 0, max: Math.ceil(maxY / 500) * 500, tickAmount: Math.min(10, Math.ceil(maxY / 500)), labels: { formatter: function (v) { return '$ ' + Math.round(v).toLocaleString('es-SV'); } } },
            annotations: {
                yaxis: comun ? [
                    { y: meta.MetaVentas, borderColor: COLOR.exito, strokeDashArray: 0, label: { text: 'Meta ' + dinero(meta.MetaVentas), position: 'right', textAnchor: 'end', style: { background: COLOR.exito, color: '#fff' } } },
                    { y: meta.MinimoComision, borderColor: COLOR.ambar, strokeDashArray: 5, label: { text: 'Mínimo ' + dinero(meta.MinimoComision), position: 'right', textAnchor: 'end', offsetY: 18, style: { background: COLOR.ambar, color: '#fff' } } }
                ] : []
            },
            legend: { show: !!m.MesEnCurso || !comun, position: 'top', horizontalAlign: 'right', markers: { fillColors: [COLOR.acento].concat(m.MesEnCurso ? ['#cfd4da'] : []).concat(comun ? [] : [COLOR.exito]) } },
            grid: { strokeDashArray: 4 },
            tooltip: { shared: true, intersect: false, y: { formatter: function (v) { return dinero(v); } } }
        });
        // meta, escala y bono estimado de cada especialista
        $('#dbMetasDetalle').html($.map(lista, function (e) {
            return '<span><strong>' + esc(e.Especialista) + '</strong>: ' + (comun ? '' : 'meta ' + dinero(e.Meta.MetaVentas) + ' · ') + (e.PorcentajeEscala ? 'escala ' + e.PorcentajeEscala + ' %' : 'bajo el mínimo')
                + ' · bono ' + dinero(e.TotalBono) + (e.CumpleMeta ? ' <i class="bx bx-check-circle text-success" title="Cumple la meta"></i>' : ' · faltan ' + dinero(e.FaltaMeta)) + '</span>';
        }).join(''));
    }

    // Metas por mes: ventas sin IVA (barras) contra la meta (línea punteada) de cada especialista, últimos 6 meses
    var PALETA_ESP = [COLOR.acento, COLOR.lila, COLOR.ambar, '#6f42c1', '#20c997', '#fd7e14'];
    var hist = null;
    function graficoMetasHist(h) {
        var id = 'dbGraficoMetasHist';
        hist = h;
        var $s = $('#dbHistEspecialista'), previo = $s.val();
        if (!h || !h.Especialistas || !h.Especialistas.length) { $s.addClass('d-none'); $('#dbMetasHistNota').empty(); sinDatos(id, 'Sin ventas ni metas en los últimos meses.'); return; }
        $s.removeClass('d-none').html('<option value="">Todos los especialistas</option>' + h.Especialistas.map(function (e) {
            return '<option value="' + e.IdEspecialista + '">' + esc(nombreCorto(e.Especialista)) + '</option>';
        }).join(''));
        if (previo && $s.find('option[value="' + previo + '"]').length) $s.val(previo);
        pintarMetasHist();
    }

    function pintarMetasHist() {
        var h = hist, id = 'dbGraficoMetasHist';
        if (!h) return;
        var sel = $('#dbHistEspecialista').val();
        var lista = sel ? $.grep(h.Especialistas, function (e) { return String(e.IdEspecialista) === sel; }) : h.Especialistas;
        // los meses iniciales sin datos (antes de que empezara el sistema) no se muestran
        var ini = 0;
        while (ini < h.Meses.length - 1 && h.Notas[ini] === 'sin datos') ini++;
        var corta = function (arr) { return arr.slice(ini); };
        var meses = corta($.map(h.Meses, function (m, i) { return h.Notas[i] ? m + '*' : m; }));
        var series = [], colores = [], anchos = [], guiones = [], maximo = 0;
        $.each(lista, function (i, e) {
            var c = PALETA_ESP[h.Especialistas.indexOf(e) % PALETA_ESP.length];
            series.push({ name: (lista.length > 1 ? nombreCorto(e.Especialista) + ' · ' : '') + 'Ventas', type: 'column', data: corta(e.Ventas) });
            colores.push(c); anchos.push(0); guiones.push(0);
            maximo = Math.max.apply(null, [maximo].concat(corta(e.Ventas)));
        });
        $.each(lista, function (i, e) {
            var metas = corta(e.Metas);
            if (!$.grep(metas, function (m) { return m != null; }).length) return;
            var c = PALETA_ESP[h.Especialistas.indexOf(e) % PALETA_ESP.length];
            series.push({ name: (lista.length > 1 ? nombreCorto(e.Especialista) + ' · ' : '') + 'Meta', type: 'line', data: metas });
            colores.push(c); anchos.push(3); guiones.push(6);
            maximo = Math.max.apply(null, [maximo].concat($.grep(metas, function (m) { return m != null; })));
        });
        var tope = Math.ceil(maximo * 1.15 / 500) * 500 || 500;
        var solo = lista.length === 1 ? lista[0] : null;
        dibujar(id, {
            chart: { type: 'line', height: 320, toolbar: { show: false }, fontFamily: 'inherit' },
            series: series,
            colors: colores,
            stroke: { width: anchos, dashArray: guiones, curve: 'straight' },
            markers: { size: $.map(series, function (s) { return s.type === 'line' ? 5 : 0; }) },
            plotOptions: { bar: { borderRadius: 3, columnWidth: lista.length > 1 ? '70%' : '45%', dataLabels: { position: 'top' } } },
            dataLabels: {
                // con un especialista: % de la meta sobre cada barra
                enabled: !!solo, enabledOnSeries: [0], offsetY: -18, style: { colors: ['#495057'], fontSize: '11px' }, background: { enabled: false },
                formatter: function (v, o) { var m = solo && solo.Metas[ini + o.dataPointIndex]; return m ? Math.round(100 * v / m) + ' %' : ''; }
            },
            xaxis: { categories: meses },
            yaxis: { min: 0, max: tope, tickAmount: Math.min(10, tope / 500), labels: { formatter: function (v) { return '$ ' + Math.round(v).toLocaleString('es-SV'); } } },
            legend: { position: 'top', horizontalAlign: 'right' },
            grid: { strokeDashArray: 4 },
            tooltip: { shared: true, intersect: false, y: { formatter: function (v) { return v == null ? 'sin meta' : dinero(v); } } }
        });
        var notas = $.map(h.Meses, function (m, i) { return i >= ini && h.Notas[i] ? m + '*: ' + h.Notas[i] : null; });
        $('#dbMetasHistNota').text((notas.length ? notas.join(' · ') + '. ' : '') + 'Las metas se registran desde noviembre 2026; antes de las facturas electrónicas, las ventas son el valor de los procedimientos finalizados.');
    }
    $('#dbHistEspecialista').on('change', pintarMetasHist);

    // Garantías de servicios del periodo por especialista (contra sus procedimientos finalizados del periodo)
    function renderGarantias(lista) {
        lista = lista || [];
        var $t = $('#dbGarantias').empty();
        var total = 0, pacientes = 0, max = 1;
        $.each(lista, function (_, g) { total += g.Garantias; pacientes += g.Pacientes; max = Math.max(max, g.Garantias); });
        $('#dbGarantiasResumen').html(total ? '<strong>' + num(total) + '</strong> ' + (total === 1 ? 'garantía' : 'garantías')
            + ' · <strong>' + num(lista.length) + '</strong> ' + (lista.length === 1 ? 'especialista' : 'especialistas') : '');
        if (!lista.length) { $t.html('<tr><td colspan="5">' + vacio('<i class="bx bx-check-shield fs-3 d-block mb-1"></i>Sin garantías de servicios en el periodo.') + '</td></tr>'); return; }
        $.each(lista, function (_, g) {
            var tasa = g.Procedimientos ? Math.round(1000 * g.Garantias / g.Procedimientos) / 10 : null;
            var p = (g.Ultima || '').split('-');
            $t.append(
                '<tr>' +
                '  <td><div class="fw-semibold">' + esc(g.Especialista) + '</div>' +
                '      <div class="progress db-barra"><div class="progress-bar bg-warning" style="width:' + Math.round(100 * g.Garantias / max) + '%"></div></div></td>' +
                '  <td class="text-end fw-semibold">' + num(g.Garantias) + '</td>' +
                '  <td class="text-end d-none d-md-table-cell">' + num(g.Pacientes) + '</td>' +
                '  <td class="text-end">' + (tasa !== null ? tasa + ' %<div class="small text-muted">de ' + num(g.Procedimientos) + ' proced.</div>' : '—') + '</td>' +
                '  <td class="d-none d-md-table-cell">' + (p.length === 3 ? p[2] + '/' + p[1] + '/' + p[0] : '—') + '</td>' +
                '</tr>');
        });
    }

    function renderHoy(hoy) {
        var $c = $('#dbHoy').empty();
        if (!hoy.length) { $c.html(vacio('No hay citas para hoy.')); return; }
        $.each(hoy, function (_, c) {
            var estado = c.EstadoProcedimiento === 'I' ? '<span class="badge bg-success">En atención</span>'
                : c.EstadoProcedimiento === 'S' ? '<span class="badge bg-info text-dark">En sala</span>'
                : '<span class="badge bg-' + esc(c.Color || 'secondary') + '">' + esc(c.Estado) + '</span>';
            $c.append(
                '<div class="db-cita">' +
                '  <span class="db-cita-hora">' + esc(c.Hora) + '</span>' +
                '  <span class="db-cita-cuerpo"><span class="fw-semibold">' + esc(titulo(c.Paciente)) + '</span><span class="small text-muted">' + esc(c.Especialista) + '</span></span>' +
                '  <span>' + estado + '</span>' +
                '</div>');
        });
    }

    /* ---------- top 10 pacientes recurrentes ---------- */
    function cargarTop() {
        $('#dbTopAlcance .btn').removeClass('active').filter('[data-alcance="' + state.alcance + '"]').addClass('active');
        $('#dbTop').html('<tr><td colspan="7" class="text-center py-3"><div class="spinner-border spinner-border-sm text-primary" role="status"></div></td></tr>');
        api('TopPacientes', { desde: state.desde, hasta: state.hasta, alcance: state.alcance }).done(function (r) {
            if (!r.Ok) { showNotification(1, 'warning', r.Mensaje); $('#dbTop').empty(); return; }
            renderTop(r);
        }).fail(falla);
    }

    function renderTop(r) {
        var etiquetas = { periodo: 'del periodo', '12m': 'de los últimos 12 meses', todo: 'de todo el historial' };
        $('#dbTopRango').text('Más visitas ' + (etiquetas[r.Alcance] || '') + (r.Alcance === 'todo' ? '' : ' (' + texto(r.Desde) + ' al ' + texto(r.Hasta) + ')') + ' · mínimo 2 visitas');
        $('#dbGraficoTop').closest('.card').find('.db-dinero').toggleClass('d-none', !r.VerDinero);

        var $t = $('#dbTop').empty(), p = r.Pacientes;
        if (!p.length) {
            $t.html('<tr><td colspan="7">' + vacio('Ningún paciente tiene 2 o más visitas en este alcance.') + '</td></tr>');
            sinDatos('dbGraficoTop', 'Sin pacientes recurrentes.');
            return;
        }
        $.each(p, function (i, x) {
            $t.append(
                '<tr>' +
                '  <td><span class="db-puesto' + (i < 3 ? ' db-puesto-' + (i + 1) : '') + '">' + (i + 1) + '</span></td>' +
                '  <td><span class="fw-semibold">' + esc(titulo(x.Paciente)) + '</span>' +
                (x.Celular ? '<div class="small text-muted">' + esc(x.Celular) + '</div>' : '') + '</td>' +
                '  <td class="text-end fw-semibold">' + num(x.Visitas) + '</td>' +
                '  <td class="text-end d-none d-md-table-cell">' + num(x.Procedimientos) + '</td>' +
                '  <td class="d-none d-lg-table-cell small">' + esc(x.UltimaVisita) + (x.PrimeraVisita ? '<div class="text-muted">desde ' + esc(x.PrimeraVisita) + '</div>' : '') + '</td>' +
                '  <td class="d-none d-lg-table-cell small">' + esc(x.Especialista) + '</td>' +
                (r.VerDinero ? '  <td class="text-end">' + dinero(x.Total) + '</td>' : '') +
                '</tr>');
        });

        dibujar('dbGraficoTop', {
            chart: { type: 'bar', height: Math.max(220, 34 * p.length + 40), toolbar: { show: false }, fontFamily: 'inherit' },
            series: [{ name: 'Visitas', data: $.map(p, function (x) { return x.Visitas; }) }],
            xaxis: { categories: $.map(p, function (x) { return nombreCorto(x.Paciente); }), labels: { formatter: function (v) { return Math.round(v); } } },
            colors: [COLOR.acento],
            plotOptions: { bar: { horizontal: true, borderRadius: 3, barHeight: '65%', distributed: false } },
            dataLabels: { enabled: true, style: { colors: ['#fff'] } },
            tooltip: { y: { formatter: function (v, o) { var x = p[o.dataPointIndex]; return v + ' visitas · ' + x.Procedimientos + ' procedimientos'; } } },
            grid: { borderColor: 'rgba(0,0,0,.06)' }
        });
    }

    /* ---------- comparativo: mes actual vs mes anterior / mismo mes del año anterior ---------- */
    var CLAVE_CMP = 'dpie.dashboard.cmp';
    state.cmp = leer(CLAVE_CMP) === 'anio' ? 'anio' : 'mes';

    function nombreMes(d) { var t = d.toLocaleDateString('es-SV', { month: 'long', year: 'numeric' }); return t.charAt(0).toUpperCase() + t.slice(1); }
    function finMes(a, m) { return new Date(a, m + 1, 0); }

    // Rangos del comparativo. mismosDias: del 1 al día de hoy en ambos meses (justo para un mes en curso)
    function rangosComparativo() {
        var hoy = new Date(), a = hoy.getFullYear(), m = hoy.getMonth();
        var otroIni = state.cmp === 'anio' ? new Date(a - 1, m, 1) : new Date(a, m - 1, 1);
        var otroFin = finMes(otroIni.getFullYear(), otroIni.getMonth());
        var mismos = $('#dbCmpMismosDias').is(':checked');
        var actFin = mismos ? hoy : finMes(a, m);
        if (mismos) otroFin = new Date(otroIni.getFullYear(), otroIni.getMonth(), Math.min(hoy.getDate(), otroFin.getDate()));
        return {
            mismos: mismos, hoy: hoy.getDate(),
            actual: { desde: iso(new Date(a, m, 1)), hasta: iso(actFin), nombre: nombreMes(hoy) },
            otro: { desde: iso(otroIni), hasta: iso(otroFin), nombre: nombreMes(otroIni) }
        };
    }

    function cargarComparativo() {
        var r = rangosComparativo(), id = ++state.consulta;
        state.desde = r.actual.desde; state.hasta = r.actual.hasta;     // para el top 10 con alcance "periodo"
        $('#dbDesde').val(state.desde); $('#dbHasta').val(state.hasta);
        $('#dbCmpTipo .btn').removeClass('active').filter('[data-cmp="' + state.cmp + '"]').addClass('active');
        $('#dbRango').text('Comparativo · cargando…');
        $('#dashboard').addClass('db-cargando');
        $.when(api('Datos', { desde: r.actual.desde, hasta: r.actual.hasta }), api('Datos', { desde: r.otro.desde, hasta: r.otro.hasta }))
            .done(function (a, b) {
                if (id !== state.consulta) return;
                if (!a.Ok || !b.Ok) { showNotification(1, 'warning', (a.Ok ? b : a).Mensaje); $('#dbRango').text(''); return; }
                renderComparativo(r, a, b);
            })
            .fail(falla)
            .always(function () { if (id === state.consulta) $('#dashboard').removeClass('db-cargando'); });
    }

    // Serie por día del mes (índice 0 = día 1)
    function porDiaDelMes(d) {
        var s = { dias: 0, ingresos: [], proc: [], citas: [], nuevos: [] }, porDia = {};
        $.each(d.CitasPorDia, function (_, x) { porDia[x.Dia] = x; });
        for (var f = new Date(d.Desde + 'T00:00:00'), fin = new Date(d.Hasta + 'T00:00:00'); f <= fin; f.setDate(f.getDate() + 1)) {
            var x = porDia[iso(f)] || {};
            s.ingresos.push(Number(x.Ingresos || 0));
            s.proc.push(x.Procedimientos || 0);
            s.citas.push(x.Total || 0);
            s.nuevos.push(x.Nuevos || 0);
            s.dias++;
        }
        return s;
    }

    function acumulado(a, hasta) {
        var t = 0;
        return $.map(a, function (v, i) { t += v; return hasta && i >= hasta ? null : Math.round(t * 100) / 100; });
    }

    function renderComparativo(r, a, b) {
        var ka = a.Indicadores, kb = b.Indicadores, dinero$ = a.VerDinero;
        var rangoTxt = function (x) { return texto(x.Desde) + ' al ' + texto(x.Hasta); };
        $('#dbRango').text('Comparativo · ' + r.actual.nombre + ' (' + rangoTxt(a) + ') vs ' + r.otro.nombre + ' (' + rangoTxt(b) + ') · actualizado ' + horaDe(new Date()));
        $('#dbCmpRango').text(r.mismos ? 'Del día 1 al ' + r.hoy + ' en ambos meses' : 'Meses completos (el actual llega hasta hoy)');
        $('#dbCmpCol1').text(r.actual.nombre);
        $('#dbCmpCol2').text(r.otro.nombre);
        $('#dbComparativo .db-dinero').toggleClass('d-none', !dinero$);

        var filas = [
            ['Expedientes nuevos', ka.PacientesNuevos, kb.PacientesNuevos],
            ['Citas', ka.Citas, kb.Citas],
            ['Citas atendidas', ka.CitasAtendidas, kb.CitasAtendidas],
            ['Citas canceladas', ka.CitasCanceladas, kb.CitasCanceladas, 'menos'],
            ['Asistencia', ka.CitasAtendidas + ka.CitasCanceladas ? ka.Asistencia : null, kb.CitasAtendidas + kb.CitasCanceladas ? kb.Asistencia : null, 'pts'],
            ['Procedimientos finalizados', ka.Procedimientos, kb.Procedimientos],
            ['Pacientes atendidos', ka.PacientesAtendidos, kb.PacientesAtendidos],
            ['Minutos promedio por procedimiento', ka.MinutosPromedio || 0, kb.MinutosPromedio || 0, 'neutro']
        ];
        if (dinero$) filas.push(
            ['Facturado (procedimientos)', ka.Facturado, kb.Facturado, '$'],
            ['Cobrado en caja', ka.Cobrado, kb.Cobrado, '$'],
            ['Ticket promedio', ka.TicketPromedio || 0, kb.TicketPromedio || 0, '$']);

        $('#dbCmpFilas').html($.map(filas, function (f) {
            var tipo = f[3], v1 = Number(f[1] || 0), v2 = Number(f[2] || 0), dif = Math.round((v1 - v2) * 100) / 100;
            if (tipo === 'pts' && (f[1] == null || f[2] == null))   // sin citas en alguno de los meses: no hay asistencia que comparar
                return '<tr><td>' + f[0] + '</td><td class="text-end fw-semibold">' + (f[1] == null ? '—' : (Math.round(v1 * 10) / 10) + ' %') + '</td><td class="text-end">'
                    + (f[2] == null ? '—' : (Math.round(v2 * 10) / 10) + ' %') + '</td><td class="text-end">—</td><td class="text-end"><span class="db-delta db-igual">—</span></td></tr>';
            var fmt = function (v) { return tipo === '$' ? dinero(v) : tipo === 'pts' ? (Math.round(v * 10) / 10) + ' %' : num(Math.round(v * 10) / 10); };
            var var_, clase;
            // la flecha ya indica si sube o baja: el número va sin signo
            if (tipo === 'pts') var_ = Math.abs(Math.round(dif * 10) / 10) + ' pts';
            else if (!v2) var_ = v1 ? 'nuevo' : '—';
            else var_ = Math.abs(Math.round((v1 - v2) / v2 * 1000) / 10) + ' %';
            var bueno = tipo === 'menos' ? dif < 0 : dif > 0;
            clase = !dif || tipo === 'neutro' ? 'db-igual' : bueno ? 'db-sube' : 'db-baja';
            var flecha = dif > 0 ? '▲ ' : dif < 0 ? '▼ ' : '';
            return '<tr><td>' + f[0] + '</td><td class="text-end fw-semibold">' + fmt(v1) + '</td><td class="text-end">' + fmt(v2) + '</td>'
                + '<td class="text-end">' + (dif > 0 ? '+' : dif < 0 ? '−' : '') + (tipo === 'pts' ? Math.abs(Math.round(dif * 10) / 10) + ' pts' : fmt(Math.abs(dif))) + '</td>'
                + '<td class="text-end"><span class="db-delta ' + clase + '">' + flecha + var_ + '</span></td></tr>';
        }).join(''));

        var sa = porDiaDelMes(a), sb = porDiaDelMes(b), n = Math.max(sa.dias, sb.dias);
        var diasEje = []; for (var i = 1; i <= n; i++) diasEje.push(String(i));
        var cortar = r.mismos ? 0 : r.hoy;     // el mes actual completo no se dibuja después de hoy
        var linea = function (id, nombre1, d1, nombre2, d2, esDinero) {
            dibujar(id, {
                chart: { type: 'line', height: 280, toolbar: { show: false }, fontFamily: 'inherit', zoom: { enabled: false } },
                series: [{ name: nombre1, data: d1 }, { name: nombre2, data: d2 }],
                colors: [COLOR.acento, COLOR.gris],
                stroke: { curve: 'smooth', width: [3, 3], dashArray: [0, 5] },
                xaxis: { categories: diasEje, title: { text: 'Día del mes' }, labels: { hideOverlappingLabels: true } },
                yaxis: { min: 0, forceNiceScale: true, labels: { formatter: function (v) { return esDinero ? '$' + Math.round(v) : Math.round(v); } } },
                legend: { position: 'top', horizontalAlign: 'left' },
                tooltip: { shared: true, x: { formatter: function (v) { return 'Día ' + v; } }, y: { formatter: function (v) { return v == null ? '—' : esDinero ? dinero(v) : num(v); } } },
                markers: { size: 0 },
                grid: { borderColor: 'rgba(0,0,0,.06)' }
            });
        };
        if (dinero$) linea('dbCmpIngresos', r.actual.nombre, acumulado(sa.ingresos, cortar), r.otro.nombre, acumulado(sb.ingresos), true);
        linea('dbCmpProc', r.actual.nombre, acumulado(sa.proc, cortar), r.otro.nombre, acumulado(sb.proc), false);

        var recorte = function (arr) { return $.map(arr, function (v, i) { return cortar && i >= cortar ? null : v; }); };
        // tipo 'line' para que se dibujen juntas las columnas (citas) y las líneas (expedientes nuevos);
        // con 'bar' ApexCharts no mostraba las series de línea
        dibujar('dbCmpCitas', {
            chart: { type: 'line', height: 280, toolbar: { show: false }, fontFamily: 'inherit', zoom: { enabled: false } },
            series: [
                { name: 'Citas ' + r.actual.nombre, type: 'column', data: recorte(sa.citas) },
                { name: 'Citas ' + r.otro.nombre, type: 'column', data: sb.citas },
                { name: 'Expedientes nuevos ' + r.actual.nombre, type: 'line', data: recorte(sa.nuevos) },
                { name: 'Expedientes nuevos ' + r.otro.nombre, type: 'line', data: sb.nuevos }
            ],
            colors: [COLOR.acento, COLOR.gris, COLOR.lila, '#d9c6de'],
            stroke: { width: [0, 0, 3, 3], dashArray: [0, 0, 0, 5], curve: 'smooth' },
            markers: { size: [0, 0, 4, 3] },
            xaxis: { categories: diasEje, title: { text: 'Día del mes' }, labels: { hideOverlappingLabels: true } },
            yaxis: ejeEnteros,
            plotOptions: { bar: { columnWidth: '70%', borderRadius: 2 } },
            dataLabels: { enabled: false },
            legend: { position: 'top', horizontalAlign: 'left' },
            tooltip: { shared: true, intersect: false, x: { formatter: function (v) { return 'Día ' + v; } } },
            grid: { borderColor: 'rgba(0,0,0,.06)' }
        });
    }

    function modo(comparativo) {
        state.comparativo = comparativo;
        $('#dbComparativo').toggleClass('d-none', !comparativo);
        $('#dbNormal').toggleClass('d-none', comparativo);
    }

    /* ---------- eventos ---------- */
    function elegir(periodo) {
        $('#dbPeriodos .btn').removeClass('active').filter('[data-periodo="' + periodo + '"]').addClass('active');
        guardar(CLAVE_PERIODO, periodo);
        if (periodo === 'comparativo') { modo(true); cargarComparativo(); return; }
        modo(false);
        var r = rango(periodo);
        cargar(r.desde, r.hasta);
    }

    $('#dbPeriodos').on('click', '.btn', function () { elegir(String($(this).data('periodo'))); });
    $('#dbCmpTipo').on('click', '.btn', function () { state.cmp = String($(this).data('cmp')); guardar(CLAVE_CMP, state.cmp); cargarComparativo(); });
    $('#dbCmpMismosDias').on('change', cargarComparativo);
    $('#dbAplicar').on('click', function () {
        var d = $('#dbDesde').val(), h = $('#dbHasta').val();
        if (!d || !h) { showNotification(1, 'warning', 'Seleccione la fecha inicial y final.'); return; }
        if (h < d) { showNotification(1, 'warning', 'La fecha final no puede ser anterior a la inicial.'); return; }
        $('#dbPeriodos .btn').removeClass('active');
        modo(false);
        cargar(d, h);
    });
    $('#dbRefrescar').on('click', function () {
        if (state.comparativo) cargarComparativo(); else cargar(state.desde, state.hasta);
        if (state.alcance !== 'periodo') cargarTop();
    });
    $('#dbTopAlcance').on('click', '.btn', function () {
        state.alcance = String($(this).data('alcance'));
        guardar(CLAVE_ALCANCE, state.alcance);
        cargarTop();
    });

    elegir(leer(CLAVE_PERIODO) || 'mes');
    if (state.alcance !== 'periodo') cargarTop();

})(jQuery);
