/* Base común de los reportes (citas, procedimientos, expedientes): filtros con rangos rápidos, catálogos,
   tabla de detalle con búsqueda y paginación, exportación a CSV (Excel) e impresión.
   Cada reporte llama a window.Reporte.iniciar({...}) con sus columnas y su forma de mostrar los totales. */
(function ($) {
    'use strict';

    var TAMANO_PAGINA = 50;

    function esc(s) { return $('<div/>').text(s == null ? '' : String(s)).html(); }
    function dinero(n) { return '$ ' + Number(n || 0).toLocaleString('es-SV', { minimumFractionDigits: 2, maximumFractionDigits: 2 }); }
    function num(n) { return Number(n || 0).toLocaleString('es-SV'); }
    function dos(n) { return (n < 10 ? '0' : '') + n; }
    function iso(d) { return d.getFullYear() + '-' + dos(d.getMonth() + 1) + '-' + dos(d.getDate()); }
    function texto(isoFecha) { var p = String(isoFecha || '').split('-'); return p.length === 3 ? p[2] + '/' + p[1] + '/' + p[0] : ''; }
    function titulo(s) { return String(s || '').toLowerCase().replace(/(^|\s)(\S)/g, function (m, a, b) { return a + b.toUpperCase(); }); }
    function normalizar(s) { return String(s || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, ''); }

    function rango(tipo) {
        var hoy = new Date(), d = new Date(hoy), h = new Date(hoy);
        if (tipo === 'ayer') { d.setDate(hoy.getDate() - 1); h = new Date(d); }
        else if (tipo === 'semana') d.setDate(hoy.getDate() - ((hoy.getDay() + 6) % 7));
        else if (tipo === 'mes') d = new Date(hoy.getFullYear(), hoy.getMonth(), 1);
        else if (tipo === 'anterior') { d = new Date(hoy.getFullYear(), hoy.getMonth() - 1, 1); h = new Date(hoy.getFullYear(), hoy.getMonth(), 0); }
        else if (tipo === 'anio') d = new Date(hoy.getFullYear(), 0, 1);
        return { desde: iso(d), hasta: iso(h) };
    }

    /** Lista de totales (TotalGrupoDto) como list-group. conTotal: muestra el monto además de la cantidad. */
    function grupo($ul, lista, conTotal, etiqueta) {
        $ul.empty();
        if (!lista || !lista.length) { $ul.html('<li class="list-group-item px-0 text-muted">Sin datos</li>'); return; }
        var max = Math.max.apply(null, $.map(lista, function (g) { return g.Documentos; }).concat([1]));
        $.each(lista, function (_, g) {
            $ul.append(
                '<li class="list-group-item px-0 d-block">' +
                '  <div class="d-flex justify-content-between gap-2"><span class="text-truncate">' + esc(g.Nombre) + '</span>' +
                '    <span class="text-nowrap"><strong>' + num(g.Documentos) + '</strong>' + (etiqueta ? ' ' + etiqueta : '') +
                (conTotal ? ' <span class="text-muted">· ' + dinero(g.Total) + '</span>' : '') + '</span></div>' +
                '  <div class="progress db-barra"><div class="progress-bar" style="width:' + Math.round(100 * g.Documentos / max) + '%"></div></div>' +
                '</li>');
        });
    }

    /**
     * opciones:
     *   url        'Reportes/frm_X.aspx/'          nombre     prefijo del archivo CSV
     *   catalogos  { '#selector': 'Especialistas' } (propiedad de CatalogosReporteDto)
     *   filtros()  datos adicionales del filtro (los de fecha se agregan solos)
     *   render(d)  pinta indicadores y resúmenes      items(d)   filas del detalle
     *   columnas   [{ titulo, html(x), csv(x), clase }]     buscar(x) texto en el que se busca
     *   exportar(datos, filas, $boton)  opcional: reemplaza el CSV (por ejemplo, Excel .xlsx)
     */
    function iniciar(o) {
        var state = { datos: null, filas: [], filtradas: [], pagina: 1 };
        // Columnas con html van en la tabla; las que solo tienen csv se exportan pero no se muestran
        var visibles = $.grep(o.columnas, function (c) { return typeof c.html === 'function'; });

        function api(metodo, datos) {
            return $.ajax({
                type: 'POST', url: o.url + metodo, data: JSON.stringify(datos || {}),
                contentType: 'application/json; charset=utf-8', dataType: 'json'
            }).then(function (r) { return r.d; });
        }
        function falla(xhr) { showNotification(1, 'error', 'Error de conexión (HTTP ' + xhr.status + ').'); }

        function filtro() {
            return $.extend({ Desde: $('#rpDesde').val(), Hasta: $('#rpHasta').val(), Sucursal: parseInt($('#rpSucursal').val(), 10) || 0 },
                o.filtros ? o.filtros() : {});
        }

        // Administradores: selector de sucursal (0 = todas). Los demás usuarios ven siempre su sucursal (lo decide el servidor).
        function selectorSucursal(c) {
            if (!c.Sucursales || !c.Sucursales.length || $('#rpSucursal').length) return;
            var $col = $('<div class="col-md-4 col-xl-2"><label for="rpSucursal" class="form-label small mb-1">Sucursal</label>'
                + '<select class="form-select" id="rpSucursal"><option value="0">Todas las sucursales</option></select></div>');
            $.each(c.Sucursales, function (_, s) { $col.find('select').append($('<option/>').val(s.Id).text(s.Texto)); });
            $col.find('select').val(String(c.SucursalActual || 0));
            var $antes = $('#rpPaciente').closest('[class*="col-"]');
            if ($antes.length) $col.insertBefore($antes); else $('#rpFiltros').prepend($col);
        }

        function consultar() {
            var f = filtro();
            if (!f.Desde || !f.Hasta) { showNotification(1, 'warning', 'Seleccione la fecha inicial y final.'); return; }
            if (f.Hasta < f.Desde) { showNotification(1, 'warning', 'La fecha final no puede ser anterior a la inicial.'); return; }

            var $b = $('#rpConsultar').prop('disabled', true).find('i').attr('class', 'bx bx-loader-alt bx-spin').end();
            api('Consultar', { filtro: f }).done(function (d) {
                if (!d.Ok) { showNotification(1, 'warning', d.Mensaje); return; }
                state.datos = d;
                state.filas = o.items(d) || [];
                $('#rpVacio').addClass('d-none');
                $('#rpResultado').removeClass('d-none');
                $('#rpTitulo').text((d.Desde === d.Hasta ? texto(d.Desde) : texto(d.Desde) + ' al ' + texto(d.Hasta)) + filtrosTexto());
                o.render(d);
                filtrar();
            }).fail(falla).always(function () { $b.prop('disabled', false).find('i').attr('class', 'bx bx-search'); });
        }

        // Filtros aplicados, para el título y la impresión
        function filtrosTexto() {
            var partes = [];
            $('#rpFiltros select').each(function () {
                if ($(this).val() && $(this).val() !== '0') partes.push($(this).find('option:selected').text());
            });
            var p = $.trim($('#rpPaciente').val() || '');
            if (p) partes.push('Paciente: ' + p);
            return partes.length ? ' · ' + partes.join(' · ') : '';
        }

        /* ---------- tabla de detalle ---------- */
        function filtrar() {
            var q = normalizar($.trim($('#rpBuscar').val()));
            state.filtradas = !q ? state.filas : $.grep(state.filas, function (x) { return normalizar(o.buscar(x)).indexOf(q) >= 0; });
            state.pagina = 1;
            pintar();
        }

        function pintar() {
            var total = state.filtradas.length, paginas = Math.max(1, Math.ceil(total / TAMANO_PAGINA));
            if (state.pagina > paginas) state.pagina = paginas;
            var ini = (state.pagina - 1) * TAMANO_PAGINA, filas = state.filtradas.slice(ini, ini + TAMANO_PAGINA);
            var $t = $('#rpFilas').empty();

            if (!total) $t.html('<tr><td colspan="' + visibles.length + '" class="text-center text-muted py-4">' +
                (state.filas.length ? 'Ninguna fila coincide con la búsqueda.' : 'No hay registros con estos filtros.') + '</td></tr>');
            $.each(filas, function (_, x) {
                $t.append('<tr>' + $.map(visibles, function (c) { return '<td' + (c.clase ? ' class="' + c.clase + '"' : '') + '>' + c.html(x) + '</td>'; }).join('') + '</tr>');
            });

            $('#rpPaginaTexto').text(total ? (ini + 1) + '–' + Math.min(ini + TAMANO_PAGINA, total) + ' de ' + num(total) +
                (total !== state.filas.length ? ' (filtrado de ' + num(state.filas.length) + ')' : '') : '');
            var $p = $('#rpPaginas').empty();
            if (paginas <= 1) return;
            function item(n, t, off, act) {
                $p.append('<li class="page-item' + (off ? ' disabled' : '') + (act ? ' active' : '') + '"><a class="page-link" href="javascript:;" data-pagina="' + n + '">' + t + '</a></li>');
            }
            item(state.pagina - 1, '&laquo;', state.pagina === 1);
            var desde = Math.max(1, Math.min(state.pagina - 2, paginas - 4)), hasta = Math.min(paginas, desde + 4);
            for (var i = desde; i <= hasta; i++) item(i, i, false, i === state.pagina);
            item(state.pagina + 1, '&raquo;', state.pagina === paginas);
        }

        // Exporta las filas que coinciden con la búsqueda; ; y BOM para que Excel en español respete acentos y columnas
        function exportar() {
            if (!state.datos) return;
            // El reporte puede exportar a su manera (por ejemplo a .xlsx); recibe los datos y las filas que coinciden con la búsqueda
            if (o.exportar) { o.exportar(state.datos, state.filtradas, $('#rpExportar')); return; }
            function campo(v) { var s = String(v == null ? '' : v); return /[;"\n\r]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s; }
            var lineas = [$.map(o.columnas, function (c) { return c.csv ? campo(c.titulo) : null; }).join(';')];
            $.each(state.filtradas, function (_, x) {
                lineas.push($.map(o.columnas, function (c) { return c.csv ? campo(c.csv(x)) : null; }).join(';'));
            });
            var blob = new Blob(['﻿' + lineas.join('\r\n')], { type: 'text/csv;charset=utf-8' });
            var u = window.URL || window.webkitURL, a = document.createElement('a');
            a.href = u.createObjectURL(blob);
            a.download = o.nombre + '_' + state.datos.Desde + '_' + state.datos.Hasta + '.csv';
            document.body.appendChild(a);
            a.click();
            setTimeout(function () { u.revokeObjectURL(a.href); a.remove(); }, 500);
        }

        /* ---------- inicio ---------- */
        $('#rpThead').html('<tr>' + $.map(visibles, function (c) { return '<th' + (c.clase ? ' class="' + c.clase + '"' : '') + '>' + esc(c.titulo) + '</th>'; }).join('') + '</tr>');

        api('Catalogos').done(function (c) {
            if (!c.Ok) { showNotification(1, 'warning', c.Mensaje); return; }
            selectorSucursal(c);
            $.each(o.catalogos || {}, function (sel, prop) {
                var $s = $(sel);
                $.each(c[prop] || [], function (_, x) { $s.append($('<option/>').val(x.Id).text(x.Texto)); });
            });
        }).fail(falla);

        $('#rpRapidos').on('click', '.btn', function () {
            var r = rango($(this).data('rango'));
            $('#rpDesde').val(r.desde); $('#rpHasta').val(r.hasta);
            $('#rpRapidos .btn').removeClass('active'); $(this).addClass('active');
            consultar();
        });
        $('#rpDesde, #rpHasta').on('change', function () { $('#rpRapidos .btn').removeClass('active'); });
        $('#rpConsultar').on('click', consultar);
        $('#rpPaciente').on('keydown', function (ev) { if (ev.key === 'Enter') { ev.preventDefault(); consultar(); } });
        $('#rpLimpiar').on('click', function () {
            $('#rpFiltros select').val('0');
            $('#rpPaciente').val('');
            consultar();
        });
        $('#rpBuscar').on('input', filtrar);
        $('#rpPaginas').on('click', '.page-link', function () {
            var n = parseInt($(this).data('pagina'), 10);
            if (!n || $(this).parent().hasClass('disabled')) return;
            state.pagina = n; pintar();
        });
        $('#rpExportar').on('click', exportar);
        $('#rpImprimir').on('click', function () { window.print(); });

        var r = rango(o.rangoInicial || 'mes');
        $('#rpDesde').val(r.desde); $('#rpHasta').val(r.hasta);
        $('#rpRapidos .btn[data-rango="' + (o.rangoInicial || 'mes') + '"]').addClass('active');
        consultar();
    }

    window.Reporte = { iniciar: iniciar, esc: esc, dinero: dinero, num: num, titulo: titulo, grupo: grupo };

})(jQuery);
