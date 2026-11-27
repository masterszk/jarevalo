/* Ticket de venta de 80 mm (lo facturado con DTE). Lo usan la pantalla de cobro (pago-factura.js) y Caja › Emitidos (caja.js).
   Los datos salen del DTE guardado (Facturacion/TicketVenta.cs), así el ticket reimpreso es igual al original.
   La ventana se abre con el clic del usuario (ventana()) para que el navegador no la bloquee y luego se llena (imprimir()). */
(function ($) {
    'use strict';

    var URL = 'Facturacion/frm_OpenFactura.aspx/TicketVentaFactura';

    function esc(s) { return $('<div>').text(s == null ? '' : String(s)).html(); }
    function dinero(n) { return Number(n || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }); }
    function cant(n) { n = Number(n || 0); return n % 1 === 0 ? String(n) : n.toFixed(2); }

    function ventana() {
        var w = window.open('', '_blank', 'width=420,height=760');
        if (!w) { if (typeof showNotification === 'function') showNotification(1, 'warning', 'Permita las ventanas emergentes para imprimir el ticket.'); return null; }
        w.document.write('<p style="font-family:sans-serif;text-align:center;margin-top:40px">Preparando ticket…</p>');
        return w;
    }

    function html(t, base) {
        var filas = (t.Items || []).map(function (it) {
            return '<tr><td colspan="2">' + esc(it.Descripcion) + '</td></tr>'
                + '<tr><td class="sub">' + cant(it.Cantidad) + ' x $' + dinero(it.Precio) + (it.Descuento > 0 ? ' &nbsp;desc. -$' + dinero(it.Descuento) : '') + '</td>'
                + '<td class="v">$' + dinero(it.Total) + '</td></tr>';
        }).join('');
        var fila = function (a, b, cls) { return '<div class="fila' + (cls ? ' ' + cls : '') + '"><span>' + a + '</span><span>' + b + '</span></div>'; };
        return '<!doctype html><html lang="es"><head><meta charset="utf-8"><title>Ticket ' + esc(t.NumeroControl) + '</title><style>'
            + '@page{size:80mm auto;margin:0}'
            + '*{box-sizing:border-box}html,body{margin:0;padding:0;background:#fff;color:#000}'
            + 'body{width:80mm;font-family:Arial,Helvetica,sans-serif;font-size:10pt;line-height:1.25}'
            + '.t{width:72mm;margin:0 auto;padding:3mm 0 6mm}'
            + '.c{text-align:center}.logo{width:44mm;margin:0 auto 1mm;display:block}'
            + '.raya{border-top:1px dashed #000;margin:2.5mm 0}'
            + '.tit{font-size:11.5pt;font-weight:bold;letter-spacing:.3mm}'
            + '.num{font-family:"Courier New",monospace;font-size:8.5pt;word-break:break-all}'
            + '.emp{font-size:8.5pt}.dato{font-size:9pt;margin:.5mm 0}.dato b{display:inline-block;min-width:17mm}'
            + 'table{width:100%;border-collapse:collapse;font-size:9.5pt}td{padding:.3mm 0;vertical-align:top}.v{text-align:right;white-space:nowrap;padding-left:2mm}'
            + '.sub{font-size:8.5pt;color:#333;padding-bottom:1.2mm}'
            + '.fila{display:flex;justify-content:space-between;font-size:9.5pt;margin:.4mm 0}'
            + '.tot{font-size:13pt;font-weight:bold;margin-top:1mm}'
            + '.anulado{border:2px solid #000;text-align:center;font-weight:bold;font-size:12pt;padding:1mm;margin:2mm 0}'
            + '.pie{font-size:8pt;text-align:center}'
            + '@media screen{body{margin:10px auto;box-shadow:0 0 6px rgba(0,0,0,.25)}}'
            + '</style></head><body><div class="t">'
            + '<div class="c"><img class="logo" src="' + base + 'assets/images/logo-dpiecenter-clinica.png" alt="D\' Pie Center">'
            + (t.Empresa ? '<div class="emp"><b>' + esc(t.Empresa) + '</b></div>' : '')
            + (t.EmpresaNit ? '<div class="emp">NIT ' + esc(t.EmpresaNit) + (t.EmpresaNrc ? ' · NRC ' + esc(t.EmpresaNrc) : '') + '</div>' : '')
            + (t.EmpresaDireccion ? '<div class="emp">' + esc(t.EmpresaDireccion) + '</div>' : '')
            + (t.EmpresaTelefono ? '<div class="emp">Tel. ' + esc(t.EmpresaTelefono) + '</div>' : '')
            + '<div class="raya"></div><div class="tit">TICKET DE VENTA</div>'
            + '<div class="emp">' + esc(t.Documento) + '</div>'
            + '<div class="num">' + esc(t.NumeroControl) + '</div></div>'
            + (t.Anulado ? '<div class="anulado">DOCUMENTO ANULADO</div>' : '')
            + '<div class="raya"></div>'
            + '<div class="dato"><b>Fecha:</b> ' + esc(t.Fecha) + '</div>'
            + '<div class="dato"><b>Cliente:</b> ' + esc(t.Cliente) + '</div>'
            + (t.ClienteDocumento ? '<div class="dato"><b>' + (t.CreditoFiscal ? 'NIT' : 'Documento') + ':</b> ' + esc(t.ClienteDocumento) + '</div>' : '')
            + '<div class="dato"><b>Atendió:</b> ' + esc(t.Cajero) + '</div>'
            + '<div class="raya"></div><table>' + filas + '</table><div class="raya"></div>'
            + (t.Descuento > 0 ? fila('Subtotal', '$' + dinero(t.Subtotal)) + fila('Descuento', '-$' + dinero(t.Descuento)) : '')
            + (t.CreditoFiscal ? fila('Gravado', '$' + dinero(t.Gravado)) + fila('IVA 13%', '$' + dinero(t.Iva)) : fila('IVA incluido', '$' + dinero(t.Iva)))
            + fila('TOTAL', '$' + dinero(t.Total), 'tot')
            + '<div class="raya"></div>'
            + fila('Forma de pago', esc(t.FormaPago))
            + (t.Referencia ? fila('Referencia', esc(t.Referencia)) : '')
            + (t.Recibido > t.Total ? fila('Recibido', '$' + dinero(t.Recibido)) + fila('Cambio', '$' + dinero(t.Cambio)) : '')
            + '<div class="raya"></div>'
            + '<div class="pie">Código de generación:<br><span class="num">' + esc(t.CodigoGeneracion) + '</span><br><br>'
            + 'Comprobante interno de su compra. El documento tributario<br>electrónico (DTE) es ' + (t.CreditoFiscal ? 'el comprobante de crédito fiscal indicado' : 'la factura indicada') + ' arriba.<br>¡Gracias por su visita!</div>'
            + '</div><script>'
            + 'function listo(){var i=[].slice.call(document.images);return i.every(function(x){return x.complete;});}'
            + 'function imprimir(){if(!listo()){setTimeout(imprimir,150);return;}setTimeout(function(){window.focus();window.print();},150);}'
            + 'window.onafterprint=function(){window.close();};imprimir();'
            + '<\/script></body></html>';
    }

    /* Pide el ticket de la factura y lo imprime en la ventana w (si no se pasa, la abre). */
    function imprimir(factura, w) {
        w = w || ventana();
        if (!w) return $.Deferred().reject().promise();
        return $.ajax({ type: 'POST', url: URL, data: JSON.stringify({ factura: factura }), contentType: 'application/json; charset=utf-8', dataType: 'json' })
            .then(function (r) { return r.d; })
            .done(function (t) {
                if (!t || !t.Ok) {
                    w.close();
                    if (typeof showNotification === 'function') showNotification(1, 'warning', (t && t.Mensaje) || 'No fue posible preparar el ticket.');
                    return;
                }
                var base = location.href.replace(/[#?].*$/, '').replace(/[^\/]*$/, '');
                w.document.open();
                w.document.write(html(t, base));
                w.document.close();
            })
            .fail(function () { w.close(); if (typeof showNotification === 'function') showNotification(1, 'error', 'No fue posible preparar el ticket.'); });
    }

    window.TicketVenta = { ventana: ventana, imprimir: imprimir };
})(jQuery);
