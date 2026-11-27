/* Metas de ventas por especialista – Registros/frm_Metas.aspx
   Cada especialista tiene su meta mensual de ventas sin IVA y su esquema de bono (salario base, mínimo para comisionar,
   bonificación por escala y por alcance). Cada cambio crea una versión nueva; la anterior queda en el historial.
   Los meses sin cambios se generan automáticamente con la meta del mes anterior (lo hace el servidor al consultar el mes). */
(function ($) {
    'use strict';

    var URL = 'Registros/frm_Metas.aspx/';
    var MESES = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    var hoy = new Date();
    var state = { anio: hoy.getFullYear(), mes: hoy.getMonth() + 1, datos: null, modo: 'nueva', meta: null };

    /* ---------- utilidades ---------- */
    function api(metodo, datos) {
        return $.ajax({ type: 'POST', url: URL + metodo, data: JSON.stringify(datos || {}), contentType: 'application/json; charset=utf-8', dataType: 'json' })
            .then(function (r) { return r.d; });
    }
    function falla(xhr) { if (xhr && xhr.statusText !== 'abort') showNotification(1, 'error', 'Error de conexión (HTTP ' + xhr.status + ').'); }
    function error(r) {
        var m = (r && r.Mensaje) || 'No fue posible completar la acción.';
        if (/sesi[oó]n/i.test(m) && typeof mtd_ValidateSession === 'function') { mtd_ValidateSession(); return; }
        showNotification(1, 'warning', m);
    }
    function esc(s) { return $('<div/>').text(s == null ? '' : String(s)).html(); }
    function dinero(n) { return '$ ' + Number(n || 0).toLocaleString('es-SV', { minimumFractionDigits: 2, maximumFractionDigits: 2 }); }
    function monto(n) { return '$ ' + Number(n || 0).toLocaleString('es-SV', { maximumFractionDigits: 2 }); }
    function pct(n) { return Number(n || 0).toLocaleString('es-SV', { maximumFractionDigits: 2 }) + ' %'; }
    function numero(id) { var v = $.trim($(id).val()); return v === '' ? null : Number(v); }
    function rango(e) { return e.Hasta != null ? monto(e.Desde) + ' a ' + monto(e.Hasta) : monto(e.Desde) + ' en adelante'; }
    function origen(m) {
        return m.Automatica
            ? '<span class="badge bg-light text-secondary border" title="Generada automáticamente con la meta del mes anterior (sin cambios)"><i class="bx bx-refresh"></i> Automática</span>'
            : '<span class="badge bg-primary-subtle text-primary border border-primary-subtle" style="background:#e7f1ff"><i class="bx bx-edit-alt"></i> Manual</span>';
    }
    function quien(u) { return u === 'sistema' ? 'automático' : u; }

    /* ---------- pantalla ---------- */
    function cargar() {
        $('#mtFiltroMes').val(state.mes); $('#mtFiltroAnio').val(state.anio);
        api('Mes', { anio: state.anio, mes: state.mes }).done(function (r) {
            if (!r || !r.Ok) { error(r); return; }
            state.datos = r; state.anio = r.Anio; state.mes = r.Mes;
            $('#mtPeriodo').text(r.Periodo);
            pintarLista(r.Metas);
            pintarAvance(r.Avance);
            pintarFactores(r.Sugeridas);
        }).fail(falla);
    }

    function pintarLista(lista) {
        var $t = $('#mtLista');
        $('#mtSelTodos').prop('checked', false); selCambio();
        var con = $.grep(lista, function (m) { return m.Id; }), auto = $.grep(con, function (m) { return m.Automatica; });
        $('#mtResumen').text(con.length + ' de ' + lista.length + ' con meta' + (auto.length ? ' · ' + auto.length + ' generadas automáticamente' : ''));
        if (!lista.length) { $t.html('<tr><td colspan="11" class="text-center text-muted small py-3">No hay especialistas activos.</td></tr>'); return; }
        $t.html(lista.map(function (m) {
            var chk = '<td><input type="checkbox" class="form-check-input mt-sel" value="' + m.IdEspecialista + '" aria-label="Seleccionar ' + esc(m.Especialista) + '"></td>';
            var nombre = '<td class="fw-semibold">' + esc(m.Especialista) + '</td>';
            var hist = '<button type="button" class="btn btn-sm btn-outline-secondary" data-hist="' + m.IdEspecialista + '" title="Historial de cambios"><i class="bx bx-history"></i><span class="d-none d-md-inline"> Historial</span></button>';
            var sug = sugDe(m.IdEspecialista);
            var celdaSug = '<td class="text-end">' + (sug && !sug.SinDatos
                ? '<span class="text-warning-emphasis fw-medium" title="' + esc(sug.Detalle) + '"><i class="bx bx-bulb"></i> ' + monto(sug.Sugerida) + '</span>'
                  + (m.Id && sug.Sugerida !== m.MetaVentas ? '<div class="small text-muted">' + (sug.Sugerida > m.MetaVentas ? '+' : '') + monto(sug.Sugerida - m.MetaVentas).replace('$ -', '-$ ') + '</div>' : '')
                : '<span class="text-muted small" title="Sin ventas en los meses anteriores">—</span>') + '</td>';
            if (!m.Id)
                return '<tr class="table-warning">' + chk + nombre + '<td class="text-muted small"><i class="bx bx-error"></i> Sin meta</td>' + celdaSug
                    + '<td colspan="6" class="text-muted small">Asígnele una: desde ese mes se generará automáticamente.</td>'
                    + '<td class="text-end text-nowrap"><button type="button" class="btn btn-sm btn-primary" data-cambiar="' + m.IdEspecialista + '"><i class="bx bx-plus"></i> Asignar</button> ' + hist + '</td></tr>';
            var es = m.NumEscalas;
            return '<tr>' + chk + nombre
                + '<td class="text-end fw-semibold">' + monto(m.MetaVentas) + '</td>'
                + celdaSug
                + '<td class="text-end d-none d-md-table-cell">' + monto(m.SalarioBase) + '</td>'
                + '<td class="text-end d-none d-md-table-cell">' + monto(m.MinimoComision) + '</td>'
                + '<td class="text-end d-none d-lg-table-cell">' + monto(m.BonoAlcance) + '</td>'
                + '<td class="d-none d-lg-table-cell small">' + es + (es === 1 ? ' rango' : ' rangos') + '</td>'
                + '<td>' + origen(m) + (m.Versiones > 1 ? '<div class="small text-muted">' + m.Versiones + ' versiones</div>' : '') + '</td>'
                + '<td class="d-none d-xl-table-cell small">' + esc(quien(m.UsuarioCrea)) + '<div class="text-muted">' + esc(m.FechaCrea) + '</div></td>'
                + '<td class="text-end text-nowrap"><button type="button" class="btn btn-sm btn-outline-primary" data-cambiar="' + m.IdEspecialista + '" title="Cambiar meta"><i class="bx bx-edit"></i><span class="d-none d-md-inline"> Cambiar</span></button> ' + hist + '</td>'
                + '</tr>';
        }).join(''));
    }

    function pintarAvance(a) {
        var $t = $('#mtAvance');
        $('#mtAvancePeriodo').text(a ? a.Periodo + (a.MesEnCurso ? ' · día ' + a.DiasTranscurridos + ' de ' + a.DiasMes : '') : '');
        var lista = a ? a.Especialistas : [];
        if (!lista.length) { $t.html('<tr><td colspan="8" class="text-center text-muted small py-3">Sin especialistas.</td></tr>'); return; }
        $t.html(lista.map(function (e) {
            var mt = e.Meta;
            var conIva = '<td class="text-end d-none d-md-table-cell">' + dinero(e.VentasConIva) + '</td>';
            if (!mt) return '<tr><td class="fw-semibold">' + esc(e.Especialista) + '</td>' + conIva + '<td class="text-end">' + dinero(e.Ventas) + '</td><td colspan="5" class="text-muted small">Sin meta asignada</td></tr>';
            var color = e.CumpleMeta ? 'bg-success' : e.Ventas > mt.MinimoComision ? 'bg-primary' : 'bg-warning';
            var bonoEstimado = e.Comision + e.BonoEscala;       // comisión escalonada + bono fijo de la escala
            return '<tr>'
                + '<td><div class="fw-semibold">' + esc(e.Especialista) + '</div><small class="text-muted">' + e.Procedimientos + ' procedimientos</small></td>'
                + conIva
                + '<td class="text-end fw-semibold">' + dinero(e.Ventas) + (e.Proyeccion != null ? '<div class="small text-muted" title="Al ritmo actual">proy. ' + dinero(e.Proyeccion) + '</div>' : '') + '</td>'
                + '<td class="text-end d-none d-sm-table-cell">' + monto(mt.MetaVentas) + (mt.Periodo !== a.Periodo ? '<div class="small text-muted">de ' + esc(mt.Periodo) + '</div>' : '') + '</td>'
                + '<td><div class="d-flex justify-content-between small"><span>' + pct(e.Avance) + '</span>'
                + (e.CumpleMeta ? '<span class="text-success"><i class="bx bx-check-circle"></i> Meta</span>' : '<span class="text-muted">faltan ' + dinero(e.FaltaMeta) + '</span>') + '</div>'
                + '<div class="progress" style="height:6px"><div class="progress-bar ' + color + '" style="width:' + Math.min(100, e.Avance) + '%"></div></div></td>'
                + '<td class="text-end"' + (e.DetalleComision ? ' title="' + esc(e.DetalleComision) + '"' : '') + '>' + dinero(bonoEstimado)
                + (e.DetalleComision ? '<div class="small text-muted text-nowrap">' + esc(e.DetalleComision) + '</div>' : e.Ventas > mt.MinimoComision ? '' : '<div class="small text-muted">bajo el mínimo</div>')
                + (e.BonoEscala ? '<div class="small text-muted">+ bono de escala ' + monto(e.BonoEscala) + '</div>' : '') + '</td>'
                + '<td class="text-end">' + (e.CumpleMeta ? '<span class="text-success fw-semibold">' + dinero(e.BonoAlcance) + '</span>' : dinero(0)) + '</td>'
                + '<td class="text-end d-none d-lg-table-cell">' + dinero(e.TotalEstimado) + '</td>'
                + '</tr>';
        }).join(''));
    }

    /* ---------- meta sugerida según el mes del año ---------- */
    function sugDe(idEsp) {
        var s = state.datos && state.datos.Sugeridas;
        return s ? $.grep(s.Especialistas || [], function (x) { return x.IdEspecialista === idEsp; })[0] : null;
    }

    function pintarFactores(s) {
        if (!s || !s.Parametros) return;
        var p = s.Parametros;
        $('#mtSugMeses').text(p.MesesBase);
        var mes = $.grep(p.Factores, function (f) { return f.Mes === state.mes; })[0];
        $('#mtSugResumen').text(state.datos.Periodo + ': factor ' + (mes ? mes.Factor.toFixed(2) : '1.00') + ' · crecimiento ' + p.Crecimiento + ' % · redondeo $' + p.Redondeo);
        $('#mtFactores').html(p.Factores.map(function (f) {
            return '<div class="col"><label class="form-label small mb-1' + (f.Mes === state.mes ? ' fw-bold text-primary' : '') + '" for="mtF' + f.Mes + '">' + esc(f.Nombre) + '</label>'
                + '<input type="number" class="form-control form-control-sm text-end" id="mtF' + f.Mes + '" data-mes="' + f.Mes + '" min="0.1" max="5" step="0.05" value="' + f.Factor.toFixed(2) + '"></div>';
        }).join(''));
        $('#mtCrecimiento').val(p.Crecimiento);
        $('#mtRedondeo').val(String(p.Redondeo));
        $('#mtSugModificado').text(p.Modificado ? 'Modificado por ' + p.Modificado : '');
    }

    function guardarFactores(ev) {
        ev.preventDefault();
        var factores = [], ok = true;
        $('#mtFactores input').each(function () {
            var v = Number($(this).val());
            if (!(v >= 0.1 && v <= 5)) { ok = false; $(this).addClass('is-invalid').trigger('focus'); return false; }
            $(this).removeClass('is-invalid'); factores.push(v);
        });
        if (!ok) { showNotification(1, 'warning', 'Cada factor debe estar entre 0.10 y 5.00 (1.00 = un mes normal).'); return; }
        var crec = Number($('#mtCrecimiento').val());
        if (isNaN(crec) || crec < -50 || crec > 100) { showNotification(1, 'warning', 'El crecimiento debe estar entre -50 % y 100 %.'); $('#mtCrecimiento').trigger('focus'); return; }
        var $b = $('#mtSugGuardar').prop('disabled', true);
        api('GuardarSugerida', { factores: factores, crecimiento: crec, redondeo: Number($('#mtRedondeo').val()) }).done(function (r) {
            if (!r.Ok) { error(r); return; }
            showNotification(1, 'success', 'Factores guardados: la meta sugerida se recalculó.');
            cargar();
        }).fail(falla).always(function () { $b.prop('disabled', false); });
    }

    // En el formulario: la sugerida del primer especialista marcado (solo para el mes que se está viendo)
    function pintarSugeridaModal() {
        var esp = $('#mtEspLista .mt-esp:checked').map(function () { return Number(this.value); }).get();
        var mismoMes = Number($('#mtMes').val()) === state.mes && Number($('#mtAnio').val()) === state.anio;
        var s = esp.length && mismoMes && state.modo !== 'ver' ? sugDe(esp[0]) : null;
        $('#mtSugBloque').toggleClass('d-none', !(s && !s.SinDatos));
        if (!s || s.SinDatos) return;
        var nombre = (metaDe(esp[0]) || {}).Especialista || '';
        $('#mtSugValor').text(monto(s.Sugerida) + (esp.length > 1 ? ' (de ' + titulo(nombre) + ')' : ''));
        $('#mtSugDetalle').html(esc(s.Detalle) + '<br>' + s.Meses.map(function (m) {
            return esc(m.Periodo) + ': ' + dinero(m.Ventas) + (m.Nota ? ' (' + esc(m.Nota) + ')' : '') + (m.Incluido ? '' : ' — no se promedia');
        }).join(' · '));
        $('#mtUsarSugerida').data('valor', s.Sugerida);
    }
    function titulo(s) { return String(s || '').toLowerCase().replace(/(^|\s)(\S)/g, function (m, a, b) { return a + b.toUpperCase(); }); }

    function seleccionados() { return $('#mtLista .mt-sel:checked').map(function () { return Number(this.value); }).get(); }
    function selCambio() { var n = seleccionados().length; $('#mtCambiarSel').toggleClass('d-none', !n).html('<i class="bx bx-edit"></i> Cambiar ' + n + (n === 1 ? ' seleccionado' : ' seleccionados')); }
    function metaDe(idEsp) { return $.grep((state.datos && state.datos.Metas) || [], function (m) { return m.IdEspecialista === idEsp; })[0]; }

    /* ---------- historial ---------- */
    function historial(idEsp) {
        var m = metaDe(idEsp);
        $('#mtHistTitulo').text('Historial de metas · ' + (m ? m.Especialista : ''));
        $('#mtHistorial').html('<tr><td colspan="10" class="text-center text-muted small py-3">Cargando…</td></tr>');
        bootstrap.Modal.getOrCreateInstance(document.getElementById('mtHistModal')).show();
        api('Historial', { especialista: idEsp }).done(function (r) {
            if (!r.Ok) { error(r); return; }
            var l = r.Historial || [];
            if (!l.length) { $('#mtHistorial').html('<tr><td colspan="10" class="text-center text-muted small py-3">Sin metas registradas.</td></tr>'); return; }
            var ant = null;
            $('#mtHistorial').html(l.map(function (h) {
                var nuevoMes = ant !== h.Periodo; ant = h.Periodo;
                return '<tr class="' + (h.Vigente ? '' : 'text-muted') + '">'
                    + '<td class="' + (nuevoMes ? 'fw-semibold' : '') + '">' + (nuevoMes ? esc(h.Periodo) : '<span class="ps-3 small">↳ versión anterior</span>') + '</td>'
                    + '<td class="text-end">' + monto(h.MetaVentas) + '</td>'
                    + '<td class="text-end d-none d-md-table-cell">' + monto(h.SalarioBase) + '</td>'
                    + '<td class="text-end d-none d-md-table-cell">' + monto(h.MinimoComision) + '</td>'
                    + '<td class="text-end d-none d-lg-table-cell">' + monto(h.BonoAlcance) + '</td>'
                    + '<td>' + origen(h) + '</td>'
                    + '<td>' + (h.Vigente ? '<span class="badge bg-success">Vigente</span>' : '<span class="badge bg-secondary">Reemplazada</span>') + '</td>'
                    + '<td class="d-none d-lg-table-cell small">' + esc(quien(h.UsuarioCrea)) + '<div class="text-muted">' + esc(h.FechaCrea) + '</div>' + (h.Observaciones ? '<div class="text-muted fst-italic">' + esc(h.Observaciones) + '</div>' : '') + '</td>'
                    + '<td class="d-none d-lg-table-cell small">' + esc(h.Modificado || '') + '</td>'
                    + '<td class="text-end"><button type="button" class="btn btn-sm btn-outline-secondary" data-ver="' + h.Id + '"><i class="bx bx-show"></i> Ver</button></td>'
                    + '</tr>';
            }).join(''));
        }).fail(falla);
    }

    /* ---------- formulario ---------- */
    function filaEscala(e) {
        e = e || {};
        function v(x) { return x == null ? '' : x; }
        return '<tr>'
            + '<td><input type="number" class="form-control form-control-sm text-end" data-c="Desde" min="0" step="0.01" value="' + v(e.Desde) + '" aria-label="Desde"></td>'
            + '<td><input type="number" class="form-control form-control-sm text-end" data-c="Hasta" min="0" step="0.01" value="' + v(e.Hasta) + '" placeholder="en adelante" aria-label="Hasta"></td>'
            + '<td><div class="input-group input-group-sm"><input type="number" class="form-control text-end" data-c="Porcentaje" min="0" max="100" step="0.01" value="' + v(e.Porcentaje) + '" aria-label="Porcentaje"><span class="input-group-text">%</span></div></td>'
            + '<td><input type="number" class="form-control form-control-sm text-end" data-c="Bono" min="0" step="0.01" value="' + v(e.Bono) + '" aria-label="Bono fijo"></td>'
            + '<td class="text-end"><button type="button" class="btn btn-sm btn-outline-danger mt-quitar" title="Quitar rango" aria-label="Quitar rango"><i class="bx bx-trash"></i></button></td>'
            + '</tr>';
    }

    function listaEspecialistas(marcados, soloVer) {
        var l = (state.datos && state.datos.Metas) || [];
        $('#mtEspLista').html(l.map(function (m) {
            var id = 'mtEsp' + m.IdEspecialista;
            return '<div class="form-check mb-0"><input class="form-check-input mt-esp" type="checkbox" id="' + id + '" value="' + m.IdEspecialista + '"'
                + (marcados.indexOf(m.IdEspecialista) >= 0 ? ' checked' : '') + (soloVer ? ' disabled' : '') + '>'
                + '<label class="form-check-label" for="' + id + '">' + esc(m.Especialista) + '</label></div>';
        }).join(''));
    }

    // modo: 'nueva' (asignar/cambiar, crea versión nueva) | 'ver' (una versión del historial)
    // especialistas: ids a marcar; m: valores iniciales (meta actual o versión)
    function abrir(modo, especialistas, m) {
        state.modo = modo; state.meta = m || null;
        var soloVer = modo === 'ver';
        var nombres = $.map(especialistas, function (id) { var x = metaDe(id); return x ? x.Especialista : null; });
        $('#mtModalTitulo').text(soloVer ? 'Meta de ' + m.Periodo + ' · ' + (m.Especialista || '') + (m.Vigente ? '' : ' (versión reemplazada)')
            : especialistas.length === 1 ? 'Meta de ' + nombres[0] : 'Asignar meta');
        $('#mtEspBloque').toggleClass('d-none', soloVer);
        listaEspecialistas(especialistas, soloVer);

        var base = m || {};
        $('#mtMes').val(soloVer ? base.Mes : state.mes);
        $('#mtAnio').val(soloVer ? base.Anio : state.anio);
        $('#mtMeta').val(base.MetaVentas != null ? base.MetaVentas : '');
        $('#mtSalario').val(base.SalarioBase != null ? base.SalarioBase : '');
        $('#mtMinimo').val(base.MinimoComision != null ? base.MinimoComision : '');
        $('#mtBono').val(base.BonoAlcance != null ? base.BonoAlcance : '');
        $('#mtObs').val(soloVer ? base.Observaciones || '' : '');
        var escalas = base.Escalas && base.Escalas.length ? base.Escalas : [{}];
        $('#mtEscalaForm').html(escalas.map(filaEscala).join(''));
        $('#mtAuditoria').text(soloVer ? 'Registrada por ' + quien(m.UsuarioCrea) + ' el ' + m.FechaCrea + (m.Automatica ? ' (copiada del mes anterior)' : '') + (m.Modificado ? ' · reemplazada por ' + m.Modificado : '') : '');
        avisoModal();
        pintarSugeridaModal();

        $('#mtForm').find('input:not(.mt-esp),select').prop('disabled', soloVer);
        $('#mtAgregarEscala, .mt-quitar').toggleClass('d-none', soloVer);
        $('#mtGuardar').toggleClass('d-none', soloVer).html('<i class="bx bx-save"></i> Guardar versión nueva');
        $('#mtUsarBase').toggleClass('d-none', !soloVer);
        $('#mtForm .is-invalid').removeClass('is-invalid');
        bootstrap.Modal.getOrCreateInstance(document.getElementById('mtModal')).show();
    }

    function avisoModal() {
        if (state.modo === 'ver') {
            var m = state.meta;
            $('#mtAviso').removeClass('alert-warning').addClass('alert-info')
                .html(m.Vigente ? '<i class="bx bx-check-circle"></i> Versión vigente de ' + esc(m.Periodo) + '.' : '<i class="bx bx-history"></i> Versión anterior, conservada en el historial.');
            return;
        }
        var periodo = MESES[Number($('#mtMes').val()) - 1] + ' ' + $('#mtAnio').val();
        $('#mtAviso').removeClass('alert-info').addClass('alert-warning')
            .html('<i class="bx bx-info-circle"></i> Se guarda como meta de <strong>' + esc(periodo) + '</strong> para los especialistas marcados. '
                + 'Si ya tenían meta ese mes, la anterior queda en el <strong>historial</strong>. Los meses siguientes sin cambios se generarán con esta meta.');
    }

    function leerFormulario() {
        var invalido = function (id, msj) { $(id).addClass('is-invalid').trigger('focus'); showNotification(1, 'warning', msj); return null; };
        $('#mtForm .is-invalid').removeClass('is-invalid');
        var m = {
            Mes: Number($('#mtMes').val()), Anio: numero('#mtAnio'),
            MetaVentas: numero('#mtMeta'), SalarioBase: numero('#mtSalario') || 0, MinimoComision: numero('#mtMinimo') || 0, BonoAlcance: numero('#mtBono') || 0,
            Observaciones: $.trim($('#mtObs').val()), Escalas: []
        };
        if (!m.Anio || m.Anio < 2020 || m.Anio > 2100) return invalido('#mtAnio', 'Escriba un año válido.');
        if (!m.MetaVentas || m.MetaVentas <= 0) return invalido('#mtMeta', 'La meta mensual debe ser mayor que cero.');
        if (m.SalarioBase < 0 || m.MinimoComision < 0 || m.BonoAlcance < 0) return invalido('#mtSalario', 'Los montos no pueden ser negativos.');

        var ok = true;
        $('#mtEscalaForm tr').each(function () {
            var $f = $(this), val = function (c) { var v = $.trim($f.find('[data-c="' + c + '"]').val()); return v === '' ? null : Number(v); };
            var e = { Desde: val('Desde'), Hasta: val('Hasta'), Porcentaje: val('Porcentaje'), Bono: val('Bono') };
            if (e.Desde == null && e.Hasta == null && e.Porcentaje == null && e.Bono == null) return;   // fila vacía
            if (e.Desde == null || e.Desde < 0) { ok = false; invalido($f.find('[data-c="Desde"]'), 'Cada rango necesita el monto "Desde".'); return false; }
            if (e.Hasta != null && e.Hasta < e.Desde) { ok = false; invalido($f.find('[data-c="Hasta"]'), '"Hasta" no puede ser menor que "Desde".'); return false; }
            if (e.Porcentaje == null) e.Porcentaje = 0;
            if (e.Porcentaje < 0 || e.Porcentaje > 100) { ok = false; invalido($f.find('[data-c="Porcentaje"]'), 'El porcentaje debe estar entre 0 y 100.'); return false; }
            e.Bono = e.Bono || 0;
            m.Escalas.push(e);
        });
        if (!ok) return null;
        m.Escalas.sort(function (a, b) { return a.Desde - b.Desde; });
        for (var i = 1; i < m.Escalas.length; i++)
            if (m.Escalas[i].Desde === m.Escalas[i - 1].Desde) { showNotification(1, 'warning', 'Hay dos rangos que empiezan en el mismo monto.'); return null; }
        return m;
    }

    function guardar(ev) {
        ev.preventDefault();
        var esp = $('#mtEspLista .mt-esp:checked').map(function () { return Number(this.value); }).get();
        if (!esp.length) { showNotification(1, 'warning', 'Marque al menos un especialista.'); return; }
        var m = leerFormulario();
        if (!m) return;
        var $b = $('#mtGuardar').prop('disabled', true);
        api('Guardar', { meta: m, especialistas: esp }).done(function (r) {
            if (!r.Ok) { error(r); return; }
            bootstrap.Modal.getInstance(document.getElementById('mtModal')).hide();
            showNotification(1, 'success', 'Meta de ' + MESES[m.Mes - 1] + ' ' + m.Anio + ' guardada para ' + r.Guardadas + (r.Guardadas === 1 ? ' especialista.' : ' especialistas.'));
            state.anio = m.Anio; state.mes = m.Mes;
            cargar();
        }).fail(falla).always(function () { $b.prop('disabled', false); });
    }

    // Abre el formulario con la meta actual del primer especialista (o la de cualquiera si no tiene)
    function cambiar(ids) {
        var actual = metaDe(ids[0]);
        var base = actual && actual.Id ? actual : $.grep(state.datos.Metas, function (x) { return x.Id; })[0];
        if (!base) {
            // mes sin metas (p. ej. un mes futuro): parte de la última meta vigente del especialista
            api('Historial', { especialista: ids[0] }).done(function (h) {
                var ult = h && h.Ok ? $.grep(h.Historial || [], function (x) { return x.Vigente; })[0] : null;
                if (!ult) { abrir('nueva', ids, null); return; }
                api('Obtener', { id: ult.Id }).done(function (r) { abrir('nueva', ids, r.Ok ? r.Meta : null); }).fail(falla);
            }).fail(falla);
            return;
        }
        api('Obtener', { id: base.Id }).done(function (r) { if (!r.Ok) { error(r); return; } abrir('nueva', ids, r.Meta); }).fail(falla);
    }

    /* ---------- eventos ---------- */
    var opciones = MESES.map(function (n, i) { return '<option value="' + (i + 1) + '">' + n + '</option>'; }).join('');
    $('#mtMes, #mtFiltroMes').html(opciones);
    $('#mtFiltroMes, #mtFiltroAnio').on('change', function () {
        var a = Number($('#mtFiltroAnio').val());
        if (a < 2020 || a > 2100) return;
        state.mes = Number($('#mtFiltroMes').val()); state.anio = a; cargar();
    });
    $('#mtMesAnt, #mtMesSig').on('click', function () {
        var d = new Date(state.anio, state.mes - 1 + (this.id === 'mtMesSig' ? 1 : -1), 1);
        state.anio = d.getFullYear(); state.mes = d.getMonth() + 1; cargar();
    });
    $('#mtNueva').on('click', function () {
        if (!state.datos) return;
        var sin = $.map($.grep(state.datos.Metas, function (m) { return !m.Id; }), function (m) { return m.IdEspecialista; });
        cambiar(sin.length ? sin : $.map(state.datos.Metas, function (m) { return m.IdEspecialista; }));
    });
    $('#mtLista').on('click', '[data-cambiar]', function () { cambiar([Number($(this).data('cambiar'))]); })
        .on('click', '[data-hist]', function () { historial(Number($(this).data('hist'))); })
        .on('change', '.mt-sel', selCambio);
    $('#mtSelTodos').on('change', function () { $('#mtLista .mt-sel').prop('checked', this.checked); selCambio(); });
    $('#mtCambiarSel').on('click', function () { var s = seleccionados(); if (s.length) cambiar(s); });
    $('#mtHistorial').on('click', '[data-ver]', function () {
        api('Obtener', { id: Number($(this).data('ver')) }).done(function (r) {
            if (!r.Ok) { error(r); return; }
            bootstrap.Modal.getInstance(document.getElementById('mtHistModal')).hide();
            setTimeout(function () { abrir('ver', [r.Meta.IdEspecialista], r.Meta); }, 350);
        }).fail(falla);
    });
    $('#mtUsarBase').on('click', function () {
        var m = state.meta;
        bootstrap.Modal.getInstance(document.getElementById('mtModal')).hide();
        setTimeout(function () { abrir('nueva', [m.IdEspecialista], m); }, 350);
    });
    $('#mtEspTodos').on('click', function () { $('#mtEspLista .mt-esp').prop('checked', true); pintarSugeridaModal(); });
    $('#mtEspNinguno').on('click', function () { $('#mtEspLista .mt-esp').prop('checked', false); pintarSugeridaModal(); });
    $('#mtEspLista').on('change', '.mt-esp', pintarSugeridaModal);
    $('#mtMes, #mtAnio').on('change', function () { avisoModal(); pintarSugeridaModal(); });
    $('#mtUsarSugerida').on('click', function () { $('#mtMeta').val($(this).data('valor')).removeClass('is-invalid').trigger('focus'); });
    $('#mtSugForm').on('submit', guardarFactores);
    $('#mtAgregarEscala').on('click', function () {
        var $u = $('#mtEscalaForm tr:last'), hasta = Number($u.find('[data-c="Hasta"]').val());
        $('#mtEscalaForm').append(filaEscala(hasta ? { Desde: hasta + 1 } : {}));
    });
    $('#mtEscalaForm').on('click', '.mt-quitar', function () {
        if ($('#mtEscalaForm tr').length > 1) $(this).closest('tr').remove();
        else $(this).closest('tr').find('input').val('');
    });
    $('#mtForm').on('submit', guardar);

    cargar();
})(jQuery);
