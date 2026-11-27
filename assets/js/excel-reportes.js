/* Descarga de reportes en Excel (.xlsx): la pantalla arma las hojas con los datos que ya tiene y el servidor
   genera el libro (WebMethod Excel → Reportes/ReportesWeb.GenerarExcel → ExcelXlsx). Lo usan reporte-caja.js
   y reporte-caja-especialistas.js, tanto para todo el reporte (varias hojas) como para el botón de cada cuadro.

   Columnas: { t: 'Título', f: '$' | 'd' | 'f' | '', w: ancho, v: function (fila) { return valor; } }
     '$' moneda (número)   'd' fecha (yyyy-MM-dd)   'f' fecha y hora (yyyy-MM-ddTHH:mm)   '' texto o número tal cual */
(function ($) {
    'use strict';

    function dos(n) { return (n < 10 ? '0' : '') + n; }

    /** "26/11/2026" y opcionalmente "02:58 PM" / "14:58" → "2026-11-26" o "2026-11-26T14:58" (para columnas 'd' / 'f'). */
    function iso(fecha, hora) {
        var m = /^(\d{2})\/(\d{2})\/(\d{4})(?:\s+(.+))?$/.exec($.trim(fecha || ''));
        if (!m) return fecha || null;
        var r = m[3] + '-' + m[2] + '-' + m[1], h = $.trim(hora || m[4] || '');
        var t = /^(\d{1,2}):(\d{2})(?::\d{2})?\s*([AaPp])?\.?\s*[Mm]?\.?$/.exec(h);
        if (!t) return r;
        var hh = parseInt(t[1], 10), ap = (t[3] || '').toUpperCase();
        if (ap === 'P' && hh < 12) hh += 12;
        if (ap === 'A' && hh === 12) hh = 0;
        return r + 'T' + dos(hh) + ':' + t[2];
    }

    function numero(n) { var v = Number(n); return isFinite(v) ? Math.round(v * 100) / 100 : 0; }

    /** Hoja con columnas declarativas; totales: filas (arreglos de valores) que van al final en negrita. */
    function hoja(nombre, titulo, columnas, filas, totales) {
        var datos = $.map(filas || [], function (x) {
            return [$.map(columnas, function (c) {
                var v = c.v(x);
                if (c.f === '$') return [v == null || v === '' ? null : numero(v)];
                return [v === undefined || v === '' ? null : v];
            })];
        });
        $.each(totales || [], function (_, t) {
            datos.push($.map(columnas, function (c, i) {
                var v = t[i];
                return [v === undefined || v === '' ? null : (c.f === '$' && v != null ? numero(v) : v)];
            }));
        });
        return {
            Nombre: nombre, Titulo: titulo,
            Encabezados: $.map(columnas, function (c) { return c.t; }),
            Formatos: $.map(columnas, function (c) { return c.f || ''; }),
            Anchos: $.map(columnas, function (c) { return c.w || 14; }),
            Filas: datos,
            FilasTotal: (totales || []).length
        };
    }

    /** Lista de totales (Nombre, Documentos, Total) con su fila de total. */
    function hojaGrupo(nombre, titulo, encabezado, grupos) {
        var docs = 0, total = 0;
        $.each(grupos || [], function (_, g) { docs += g.Documentos || 0; total += g.Total || 0; });
        return hoja(nombre, titulo, [
            { t: encabezado, w: 34, v: function (g) { return g.Nombre; } },
            { t: 'Documentos', w: 13, v: function (g) { return g.Documentos; } },
            { t: 'Total', f: '$', w: 15, v: function (g) { return g.Total; } }
        ], grupos, (grupos || []).length ? [['Total', docs, total]] : []);
    }

    /** Pide el libro al servidor y lo descarga. url: 'Reportes/frm_X.aspx/' ; $btn: botón que muestra el avance. */
    function descargar(url, nombre, hojas, $btn) {
        var html = $btn ? $btn.html() : null;
        if ($btn) $btn.prop('disabled', true).html('<span class="spinner-border spinner-border-sm" role="status"></span>' + ($btn.data('texto-corto') ? '' : ' Generando…'));
        return $.ajax({
            type: 'POST', url: url + 'Excel', data: JSON.stringify({ libro: { Nombre: nombre, Hojas: hojas } }),
            contentType: 'application/json; charset=utf-8', dataType: 'json'
        }).then(function (r) { return r.d; }).done(function (r) {
            if (!r || !r.Ok) { showNotification(1, 'warning', (r && r.Mensaje) || 'No fue posible generar el archivo.'); return; }
            var bin = atob(r.Base64), bytes = new Uint8Array(bin.length);
            for (var i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
            var u = window.URL || window.webkitURL, href = u.createObjectURL(new Blob([bytes], { type: r.Tipo }));
            var a = document.createElement('a');
            a.href = href; a.download = r.Nombre;
            document.body.appendChild(a); a.click(); document.body.removeChild(a);
            setTimeout(function () { u.revokeObjectURL(href); }, 2000);
        }).fail(function (xhr) {
            showNotification(1, 'error', 'Error de conexión (HTTP ' + xhr.status + ').');
        }).always(function () {
            if ($btn) $btn.prop('disabled', false).html(html);
        });
    }

    window.ExcelReporte = { iso: iso, hoja: hoja, hojaGrupo: hojaGrupo, descargar: descargar };

})(jQuery);
