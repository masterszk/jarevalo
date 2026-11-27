using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using iTextSharp.text;
using iTextSharp.text.pdf;

namespace DPieCenter.Reportes
{
    /// <summary>
    /// Reporte de caja en PDF con formato de cierre de caja (Reportes/CajaPdf.ashx):
    /// resumen, arqueo de efectivo por caja, ingresos por forma de pago / tipo / cajero, salidas, detalle de cobros y firmas.
    /// </summary>
    public static class CajaPdf
    {
        private static readonly CultureInfo Inv = CultureInfo.InvariantCulture;
        private static readonly BaseColor Verde = new BaseColor(11, 111, 120);
        private static readonly BaseColor VerdeClaro = new BaseColor(230, 244, 245);
        private static readonly BaseColor Gris = new BaseColor(100, 110, 118);
        private static readonly BaseColor Linea = new BaseColor(214, 222, 228);
        private static readonly BaseColor Fondo = new BaseColor(246, 248, 250);
        private static readonly BaseColor Rojo = new BaseColor(200, 45, 60);
        private static readonly BaseColor Ambar = new BaseColor(190, 120, 0);
        private static readonly BaseColor VerdeOk = new BaseColor(25, 135, 84);

        private static Font F(float t, int estilo = Font.NORMAL, BaseColor c = null)
        {
            return FontFactory.GetFont(FontFactory.HELVETICA, BaseFont.CP1252, BaseFont.NOT_EMBEDDED, t, estilo, c ?? BaseColor.BLACK);
        }

        private static string D(decimal v) { return "$ " + v.ToString("#,##0.00", Inv); }

        public static byte[] Generar(CajaReporteDto r, string empresa, byte[] logo, string cajeroNombre, string usuario, string sucursal = null)
        {
            if (!string.IsNullOrEmpty(sucursal)) empresa = empresa + " · " + sucursal;
            using (var ms = new MemoryStream())
            {
                var doc = new Document(PageSize.LETTER, 32, 32, 30, 40);
                var writer = PdfWriter.GetInstance(doc, ms);
                writer.PageEvent = new Pie(usuario);
                doc.Open();

                Encabezado(doc, r, empresa, logo, cajeroNombre);
                Resumen(doc, r);
                Arqueo(doc, r);
                Ingresos(doc, r);
                Salidas(doc, r);
                Cobros(doc, r);
                Firmas(doc, r, cajeroNombre);

                doc.Close();
                return ms.ToArray();
            }
        }

        /* ---------- encabezado ---------- */
        private static void Encabezado(Document doc, CajaReporteDto r, string empresa, byte[] logo, string cajeroNombre)
        {
            var t = new PdfPTable(2) { WidthPercentage = 100, SpacingAfter = 6 };
            t.SetWidths(new float[] { 30, 70 });
            var cLogo = new PdfPCell { Border = Rectangle.NO_BORDER, VerticalAlignment = Element.ALIGN_MIDDLE };
            if (logo != null && logo.Length > 0)
            {
                try { var img = Image.GetInstance(logo); img.ScaleToFit(120, 60); cLogo.AddElement(img); }
                catch (Exception) { cLogo.AddElement(new Phrase(empresa, F(12, Font.BOLD, Verde))); }
            }
            else cLogo.AddElement(new Phrase(empresa, F(12, Font.BOLD, Verde)));
            t.AddCell(cLogo);

            var c = new PdfPCell { Border = Rectangle.NO_BORDER, HorizontalAlignment = Element.ALIGN_RIGHT, VerticalAlignment = Element.ALIGN_MIDDLE };
            c.AddElement(new Paragraph("CIERRE DE CAJA", F(18, Font.BOLD, Verde)) { Alignment = Element.ALIGN_RIGHT });
            c.AddElement(new Paragraph(empresa, F(9.5f, Font.BOLD)) { Alignment = Element.ALIGN_RIGHT });
            string periodo = r.Desde == r.Hasta ? Fecha(r.Desde) : Fecha(r.Desde) + " al " + Fecha(r.Hasta);
            c.AddElement(new Paragraph("Período: " + periodo + "   ·   Cajero: " + (string.IsNullOrEmpty(cajeroNombre) ? "Todos" : cajeroNombre), F(9, Font.NORMAL, Gris)) { Alignment = Element.ALIGN_RIGHT });
            t.AddCell(c);
            doc.Add(t);
            doc.Add(Raya(Verde, 1.5f));
        }

        private static string Fecha(string iso)
        {
            DateTime d;
            return DateTime.TryParseExact(iso ?? "", "yyyy-MM-dd", Inv, DateTimeStyles.None, out d) ? d.ToString("dd/MM/yyyy", Inv) : iso;
        }

        /* ---------- resumen ---------- */
        private static void Resumen(Document doc, CajaReporteDto r)
        {
            var t = new PdfPTable(4) { WidthPercentage = 100, SpacingBefore = 8, SpacingAfter = 3 };
            t.AddCell(Tarjeta("TOTAL COBRADO", D(r.Total), "Gravado " + D(r.Gravado) + " · IVA " + D(r.Iva), Verde, true));
            t.AddCell(Tarjeta("DOCUMENTOS", r.Documentos.ToString(Inv), "Ticket promedio " + D(r.TicketPromedio), BaseColor.BLACK, false));
            t.AddCell(Tarjeta("ANULADOS", r.Anulados.ToString(Inv), D(r.TotalAnulado), r.Anulados > 0 ? Rojo : BaseColor.BLACK, false));
            t.AddCell(Tarjeta("PENDIENTE DE COBRO", D(r.PendientesTotal), r.PendientesFacturas + " factura(s) sin cobrar", r.PendientesTotal > 0 ? Ambar : BaseColor.BLACK, false));
            doc.Add(t);

            var t2 = new PdfPTable(4) { WidthPercentage = 100, SpacingAfter = 4 };
            var movs = (r.SalidasDetalle ?? new List<SalidaReporteDto>()).Where(s => !s.Anulada).ToList();
            t2.AddCell(Tarjeta("MANEJO DE EFECTIVO", "+" + D(r.Entradas) + " / −" + D(r.Salidas),
                movs.Count(s => s.Entrada) + " entrada(s) · " + movs.Count(s => !s.Entrada) + " salida(s)", BaseColor.BLACK, false));
            decimal dif = r.Sobrantes - r.Faltantes;
            t2.AddCell(Tarjeta("ARQUEO", (dif >= 0 ? "+" : "−") + D(Math.Abs(dif)), "Sobrantes " + D(r.Sobrantes) + " · Faltantes " + D(r.Faltantes), r.Faltantes > 0 ? Rojo : VerdeOk, false));
            t2.AddCell(Tarjeta("DESCUENTOS", D(r.Descuentos),
                r.Descuentos > 0 ? "Tratamientos " + D(r.DescuentosTratamientos) + " · Cupones " + D(r.DescuentosCupones) + " (" + r.Cupones + ")" : "Sin descuentos",
                BaseColor.BLACK, false));
            t2.AddCell(Tarjeta("TICKETS SIN COSTO", r.Tickets.ToString(Inv), "servicios sin DTE", BaseColor.BLACK, false));
            doc.Add(t2);
        }

        private static PdfPCell Tarjeta(string titulo, string valor, string sub, BaseColor color, bool destacado)
        {
            var c = new PdfPCell { BorderColor = Linea, BorderWidth = 0.8f, Padding = 6, PaddingBottom = 7, BackgroundColor = destacado ? VerdeClaro : BaseColor.WHITE };
            c.AddElement(new Paragraph(titulo, F(7, Font.BOLD, Gris)));
            c.AddElement(new Paragraph(valor, F(15, Font.BOLD, color)) { SpacingBefore = 1 });
            c.AddElement(new Paragraph(sub, F(7, Font.NORMAL, Gris)));
            return c;
        }

        /* ---------- arqueo ---------- */
        private static void Arqueo(Document doc, CajaReporteDto r)
        {
            Titulo(doc, "ARQUEO DE EFECTIVO POR CAJA");
            var cajas = r.Cajas ?? new List<CajaDiaDto>();
            if (!cajas.Any()) { doc.Add(Vacio("No hubo cajas abiertas en el período.")); return; }

            var t = Tabla(new float[] { 11, 17, 13, 10, 10, 10, 11, 11, 12 },
                "Fecha", "Cajero", "Horario", "Fondo", "Efectivo", "Ent./Sal.", "Esperado", "Contado", "Diferencia");
            foreach (var c in cajas)
            {
                decimal dif = c.Sobrante - c.Faltante;
                Fila(t, c.Fecha, Txt(c.CajeroNombre, c.Cajero), c.Apertura + " – " + (c.Abierta ? "abierta" : c.Cierre),
                    D(c.Fondo), D(c.Efectivo), (c.Entradas - c.Salidas >= 0 ? "+" : "−") + D(Math.Abs(c.Entradas - c.Salidas)), D(c.EfectivoEsperado),
                    c.EfectivoContado.HasValue ? D(c.EfectivoContado.Value) : "—");
                t.AddCell(Num(c.Abierta || !c.EfectivoContado.HasValue ? "Pendiente" : (dif == 0 ? "Cuadra" : (dif > 0 ? "+" : "−") + D(Math.Abs(dif))),
                    c.Abierta ? Ambar : (dif < 0 ? Rojo : (dif > 0 ? Ambar : VerdeOk)), true));
            }
            Totales(t, 3, D(cajas.Sum(x => x.Fondo)), D(cajas.Sum(x => x.Efectivo)), D(cajas.Sum(x => x.Entradas - x.Salidas)),
                D(cajas.Sum(x => x.EfectivoEsperado)), D(cajas.Where(x => x.EfectivoContado.HasValue).Sum(x => x.EfectivoContado.Value)),
                D(cajas.Sum(x => x.Sobrante - x.Faltante)));
            doc.Add(t);
            var obs = cajas.Where(x => !string.IsNullOrWhiteSpace(x.Observaciones)).ToList();
            foreach (var o in obs)
                doc.Add(new Paragraph("Observación " + o.Fecha + " (" + Txt(o.CajeroNombre, o.Cajero) + "): " + o.Observaciones, F(7.5f, Font.ITALIC, Gris)) { SpacingBefore = 2 });
        }

        /* ---------- ingresos ---------- */
        private static void Ingresos(Document doc, CajaReporteDto r)
        {
            Titulo(doc, "INGRESOS");
            var t = new PdfPTable(3) { WidthPercentage = 100 };
            t.SetWidths(new float[] { 34, 33, 33 });
            t.AddCell(Grupo("Por forma de pago", r.PorFormaPago));
            t.AddCell(Grupo("Por tipo de documento", r.PorTipo));
            t.AddCell(Grupo("Por cajero", r.PorCajero));
            doc.Add(t);
        }

        private static PdfPCell Grupo(string titulo, List<TotalGrupoDto> items)
        {
            var interna = new PdfPTable(3) { WidthPercentage = 100 };
            interna.SetWidths(new float[] { 56, 14, 30 });
            interna.AddCell(new PdfPCell(new Phrase(titulo, F(8, Font.BOLD, Verde))) { Colspan = 3, Border = Rectangle.BOTTOM_BORDER, BorderColor = Linea, PaddingBottom = 4 });
            items = items ?? new List<TotalGrupoDto>();
            if (!items.Any()) interna.AddCell(new PdfPCell(new Phrase("Sin movimientos", F(7.5f, Font.ITALIC, Gris))) { Colspan = 3, Border = Rectangle.NO_BORDER, PaddingTop = 4 });
            foreach (var x in items)
            {
                interna.AddCell(new PdfPCell(new Phrase(x.Nombre, F(8))) { Border = Rectangle.NO_BORDER, PaddingTop = 3 });
                interna.AddCell(new PdfPCell(new Phrase("(" + x.Documentos + ")", F(7.5f, Font.NORMAL, Gris))) { Border = Rectangle.NO_BORDER, PaddingTop = 3, HorizontalAlignment = Element.ALIGN_RIGHT });
                interna.AddCell(new PdfPCell(new Phrase(D(x.Total), F(8, Font.BOLD))) { Border = Rectangle.NO_BORDER, PaddingTop = 3, HorizontalAlignment = Element.ALIGN_RIGHT });
            }
            if (items.Any())
            {
                interna.AddCell(new PdfPCell(new Phrase("Total", F(8, Font.BOLD))) { Colspan = 2, Border = Rectangle.TOP_BORDER, BorderColor = Linea, PaddingTop = 4 });
                interna.AddCell(new PdfPCell(new Phrase(D(items.Sum(x => x.Total)), F(8.5f, Font.BOLD, Verde))) { Border = Rectangle.TOP_BORDER, BorderColor = Linea, PaddingTop = 4, HorizontalAlignment = Element.ALIGN_RIGHT });
            }
            return new PdfPCell(interna) { BorderColor = Linea, Padding = 7, BackgroundColor = BaseColor.WHITE };
        }

        /* ---------- salidas ---------- */
        private static void Salidas(Document doc, CajaReporteDto r)
        {
            var salidas = r.SalidasDetalle ?? new List<SalidaReporteDto>();
            if (!salidas.Any()) return;
            Titulo(doc, "MANEJO DE EFECTIVO");
            var t = Tabla(new float[] { 17, 18, 16, 33, 16 }, "Fecha", "Cajero", "Movimiento", "Motivo", "Monto");
            foreach (var s in salidas)
            {
                Fila(t, s.Fecha, s.CajeroNombre, (s.Entrada ? "Entrada · " : "Salida · ") + s.Categoria,
                    s.Motivo + (string.IsNullOrEmpty(s.Referencia) ? "" : " · Ref. " + s.Referencia) + (s.Anulada ? " (ANULADA)" : ""));
                t.AddCell(Num((s.Entrada ? "+" : "−") + D(s.Monto), s.Anulada ? Gris : (s.Entrada ? VerdeOk : Rojo), false));
            }
            decimal neto = salidas.Where(x => !x.Anulada).Sum(x => x.Entrada ? x.Monto : -x.Monto);
            Totales(t, 4, (neto >= 0 ? "+" : "−") + D(Math.Abs(neto)));
            doc.Add(t);
        }

        /* ---------- detalle de cobros ---------- */
        private static void Cobros(Document doc, CajaReporteDto r)
        {
            Titulo(doc, "DETALLE DE COBROS");
            var cobros = r.Cobros ?? new List<CobroDto>();
            if (!cobros.Any()) { doc.Add(Vacio("No hay cobros en el período.")); return; }
            var t = Tabla(new float[] { 15, 14, 28, 15, 14, 14 }, "Fecha", "Documento", "Cliente / paciente", "Forma de pago", "Cajero", "Total");
            foreach (var c in cobros)
            {
                string doctxt = c.Ticket ? "Ticket" : c.TipoDte;
                string cliente = Txt(c.Cliente, c.Paciente)
                    + (c.DescuentoTratamiento > 0 ? " · desc. tratamiento -" + D(c.DescuentoTratamiento) : "")
                    + (string.IsNullOrEmpty(c.Cupon) || c.DescuentoCupon <= 0 ? "" : " · cupón " + c.Cupon + " -" + D(c.DescuentoCupon));
                var color = c.Anulado ? Gris : BaseColor.BLACK;
                t.AddCell(Celda(c.Fecha + " " + c.Hora, color));
                t.AddCell(Celda(doctxt + (c.Anulado ? " (ANULADO)" : ""), c.Anulado ? Rojo : color));
                t.AddCell(Celda(cliente, color));
                t.AddCell(Celda(c.FormaPago, color));
                t.AddCell(Celda(Txt(c.CajeroNombre, c.Cajero), color));
                t.AddCell(Num(D(c.Total), color, !c.Anulado));
            }
            Totales(t, 5, D(r.Total));
            doc.Add(t);
            doc.Add(new Paragraph("Los documentos anulados se muestran en gris y no suman al total.", F(7, Font.ITALIC, Gris)) { SpacingBefore = 3 });
        }

        /* ---------- firmas ---------- */
        private static void Firmas(Document doc, CajaReporteDto r, string cajeroNombre)
        {
            var t = new PdfPTable(2) { WidthPercentage = 90, SpacingBefore = 32, KeepTogether = true };
            foreach (var n in new[] { "Entregado por (cajero)" + (string.IsNullOrEmpty(cajeroNombre) ? "" : ": " + cajeroNombre), "Recibido y revisado por" })
            {
                var c = new PdfPCell { Border = Rectangle.NO_BORDER, PaddingLeft = 18, PaddingRight = 18 };
                c.AddElement(Raya(BaseColor.BLACK, 0.6f));
                c.AddElement(new Paragraph(n, F(8, Font.NORMAL, Gris)) { Alignment = Element.ALIGN_CENTER });
                t.AddCell(c);
            }
            doc.Add(t);
        }

        /* ---------- utilidades ---------- */
        private static string Txt(string a, string b) { return string.IsNullOrWhiteSpace(a) ? (b ?? "") : a; }

        private static void Titulo(Document doc, string texto)
        {
            var p = new Paragraph(texto, F(9.5f, Font.BOLD, Verde)) { SpacingBefore = 8, SpacingAfter = 4, KeepTogether = true };
            doc.Add(p);
        }

        private static Paragraph Vacio(string texto) { return new Paragraph(texto, F(8, Font.ITALIC, Gris)); }

        private static Chunk Raya(BaseColor color, float grosor)
        {
            return new Chunk(new iTextSharp.text.pdf.draw.LineSeparator(grosor, 100, color, Element.ALIGN_CENTER, -2));
        }

        private static PdfPTable Tabla(float[] anchos, params string[] encabezados)
        {
            var t = new PdfPTable(anchos.Length) { WidthPercentage = 100, HeaderRows = 1 };
            t.SetWidths(anchos);
            for (int i = 0; i < encabezados.Length; i++)
                t.AddCell(new PdfPCell(new Phrase(encabezados[i], F(7.5f, Font.BOLD, BaseColor.WHITE)))
                {
                    BackgroundColor = Verde, BorderColor = Verde, Padding = 4,
                    HorizontalAlignment = i >= encabezados.Length - 1 || encabezados[i] == "Fondo" || encabezados[i] == "Efectivo" || encabezados[i] == "Salidas"
                        || encabezados[i] == "Esperado" || encabezados[i] == "Contado" ? Element.ALIGN_RIGHT : Element.ALIGN_LEFT
                });
            return t;
        }

        private static PdfPCell Celda(string texto, BaseColor color = null)
        {
            return new PdfPCell(new Phrase(texto ?? "", F(7.5f, Font.NORMAL, color))) { BorderColor = Linea, BorderWidthLeft = 0, BorderWidthRight = 0, Padding = 4 };
        }

        private static PdfPCell Num(string texto, BaseColor color, bool negrita)
        {
            return new PdfPCell(new Phrase(texto ?? "", F(7.5f, negrita ? Font.BOLD : Font.NORMAL, color))) { BorderColor = Linea, BorderWidthLeft = 0, BorderWidthRight = 0, Padding = 4, HorizontalAlignment = Element.ALIGN_RIGHT };
        }

        // Las primeras columnas de texto van a la izquierda; las que tienen "$" a la derecha
        private static void Fila(PdfPTable t, params string[] valores)
        {
            foreach (var v in valores)
                t.AddCell(v != null && v.StartsWith("$") || v == "—" ? Num(v, BaseColor.BLACK, false) : Celda(v));
        }

        private static void Totales(PdfPTable t, int columnasEtiqueta, params string[] valores)
        {
            t.AddCell(new PdfPCell(new Phrase("TOTAL", F(8, Font.BOLD))) { Colspan = columnasEtiqueta, BackgroundColor = Fondo, BorderColor = Linea, Padding = 4 });
            foreach (var v in valores)
                t.AddCell(new PdfPCell(new Phrase(v, F(8, Font.BOLD, Verde))) { BackgroundColor = Fondo, BorderColor = Linea, Padding = 4, HorizontalAlignment = Element.ALIGN_RIGHT });
        }

        /// <summary>Pie de página: quién lo generó, cuándo y número de página.</summary>
        private class Pie : PdfPageEventHelper
        {
            private readonly string usuario;
            public Pie(string usuario) { this.usuario = usuario; }

            public override void OnEndPage(PdfWriter writer, Document document)
            {
                var cb = writer.DirectContent;
                var texto = "Generado por " + (usuario ?? "") + " el " + DateTime.Now.ToString("dd/MM/yyyy hh:mm tt", Inv) + "   ·   Página " + writer.PageNumber;
                ColumnText.ShowTextAligned(cb, Element.ALIGN_CENTER, new Phrase(texto, F(7, Font.NORMAL, Gris)),
                    (document.Left + document.Right) / 2, document.Bottom - 20, 0);
            }
        }
    }
}
