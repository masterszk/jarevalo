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
    /// Caja por especialista en PDF (Reportes/CajaEspecialistasPdf.ashx): las tarjetas del resumen
    /// y la tabla por especialista con la comisión, igual que en Reportes/frm_repCajaEspecialistas.aspx.
    /// </summary>
    public static class CajaEspecialistasPdf
    {
        private static readonly CultureInfo Inv = CultureInfo.InvariantCulture;
        private static readonly BaseColor Verde = new BaseColor(11, 111, 120);
        private static readonly BaseColor VerdeClaro = new BaseColor(230, 244, 245);
        private static readonly BaseColor Gris = new BaseColor(100, 110, 118);
        private static readonly BaseColor Linea = new BaseColor(214, 222, 228);
        private static readonly BaseColor Fondo = new BaseColor(246, 248, 250);

        private static Font F(float t, int estilo = Font.NORMAL, BaseColor c = null)
        {
            return FontFactory.GetFont(FontFactory.HELVETICA, BaseFont.CP1252, BaseFont.NOT_EMBEDDED, t, estilo, c ?? BaseColor.BLACK);
        }

        private static string D(decimal v) { return "$ " + v.ToString("#,##0.00", Inv); }
        private static string P(decimal v) { return v.ToString("0.#", Inv) + " %"; }

        /// <param name="filtros">Texto de los filtros aplicados ("Especialista: ... · Forma de pago: ..."), vacío si no hay.</param>
        /// <param name="especialista">Especialista del filtro (0 = todos): la tarjeta de comisión muestra la suya.</param>
        public static byte[] Generar(ReporteCajaEspecialistasDto r, string empresa, byte[] logo, string sucursal, string filtros, string usuario, long especialista)
        {
            using (var ms = new MemoryStream())
            {
                int formas = (r.FormasPago ?? new List<string>()).Count;
                // con muchas formas de pago la tabla necesita la hoja horizontal
                var doc = new Document(formas > 2 ? PageSize.LETTER.Rotate() : PageSize.LETTER, 32, 32, 30, 40);
                var writer = PdfWriter.GetInstance(doc, ms);
                writer.PageEvent = new Pie(usuario);
                doc.Open();

                Encabezado(doc, r, empresa, logo, sucursal, filtros);
                Tarjetas(doc, r, especialista);
                PorEspecialista(doc, r);

                doc.Close();
                return ms.ToArray();
            }
        }

        private static string Fecha(string iso)
        {
            DateTime d;
            return DateTime.TryParseExact(iso ?? "", "yyyy-MM-dd", Inv, DateTimeStyles.None, out d) ? d.ToString("dd/MM/yyyy", Inv) : iso;
        }

        private static void Encabezado(Document doc, ReporteCajaEspecialistasDto r, string empresa, byte[] logo, string sucursal, string filtros)
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
            c.AddElement(new Paragraph("CAJA POR ESPECIALISTA", F(17, Font.BOLD, Verde)) { Alignment = Element.ALIGN_RIGHT });
            c.AddElement(new Paragraph(empresa + (string.IsNullOrEmpty(sucursal) ? "" : " · " + sucursal), F(9.5f, Font.BOLD)) { Alignment = Element.ALIGN_RIGHT });
            string periodo = r.Desde == r.Hasta ? Fecha(r.Desde) : Fecha(r.Desde) + " al " + Fecha(r.Hasta);
            c.AddElement(new Paragraph("Período: " + periodo, F(9, Font.NORMAL, Gris)) { Alignment = Element.ALIGN_RIGHT });
            if (!string.IsNullOrEmpty(filtros))
                c.AddElement(new Paragraph(filtros, F(8, Font.NORMAL, Gris)) { Alignment = Element.ALIGN_RIGHT });
            t.AddCell(c);
            doc.Add(t);
            doc.Add(new Chunk(new iTextSharp.text.pdf.draw.LineSeparator(1.5f, 100, Verde, Element.ALIGN_CENTER, -2)));
        }

        private static void Tarjetas(Document doc, ReporteCajaEspecialistasDto r, long especialista)
        {
            var t = new PdfPTable(5) { WidthPercentage = 100, SpacingBefore = 10, SpacingAfter = 4 };
            t.AddCell(Tarjeta("TOTAL COBRADO", D(r.Cobrado), "IVA " + D(r.Iva), Verde, true));
            t.AddCell(Tarjeta("VENTAS SIN IVA", D(r.SinIva),
                r.Adelantos > 0 ? "incluye " + D(r.Adelantos) + " de pagos adelantados" : "como en las metas", Verde, false));
            t.AddCell(TarjetaComision(r, especialista));
            t.AddCell(Tarjeta("PACIENTES", r.Pacientes.ToString("#,##0", Inv), "con cobros en el periodo", Verde, false));
            t.AddCell(Tarjeta("TICKET PROMEDIO", D(r.TicketPromedio), "por documento", Verde, false));
            doc.Add(t);
        }

        /// <summary>Comisión del especialista seleccionado (0 = todos: la suma).</summary>
        private static PdfPCell TarjetaComision(ReporteCajaEspecialistasDto r, long especialista)
        {
            var es = new CultureInfo("es-SV");
            if (especialista <= 0)
            {
                int con = (r.PorEspecialista ?? new List<CajaEspecialistaDto>()).Count(x => x.Comision > 0);
                return Tarjeta("COMISIÓN", D(r.Comision),
                    "total de " + r.MetaEspecialistas + " especialista" + (r.MetaEspecialistas == 1 ? "" : "s") + " con meta"
                    + (con > 0 ? " · " + con + " comisiona" + (con == 1 ? "" : "n") : ""), Verde, false);
            }
            var e = (r.PorEspecialista ?? new List<CajaEspecialistaDto>()).FirstOrDefault(x => x.IdEspecialista == especialista);
            string titulo = ("COMISIÓN · " + (e != null ? e.Especialista : "")).ToUpper(es);
            if (e == null) return Tarjeta(titulo, "—", "sin cobros en el periodo", Verde, false);
            if (e.Meta == null) return Tarjeta(titulo, "—", "sin meta registrada", Verde, false);
            if (e.SinEscalas) return Tarjeta(titulo, D(e.Comision), "meta sin escalas de comisión", Verde, false);
            var sub = new List<string>();
            sub.Add(e.PorcentajeEscala > 0 ? "escala " + P(e.PorcentajeEscala) : (e.SinEscalas ? "meta sin escalas" : "bajo el mínimo"));
            sub.Add("meta " + D(e.Meta.Value));
            if (e.Meta > 0) sub.Add("avance " + P(r.MetaAvance));
            return Tarjeta(titulo, D(e.Comision), string.Join(" · ", sub), Verde, false);
        }

        private static PdfPCell Tarjeta(string titulo, string valor, string sub, BaseColor color, bool destacado)
        {
            var c = new PdfPCell { BorderColor = Linea, BorderWidth = 0.8f, Padding = 6, PaddingBottom = 7, BackgroundColor = destacado ? VerdeClaro : BaseColor.WHITE };
            c.AddElement(new Paragraph(titulo, F(7, Font.BOLD, Gris)));
            c.AddElement(new Paragraph(valor, F(14, Font.BOLD, color)) { SpacingBefore = 1 });
            c.AddElement(new Paragraph(sub, F(7, Font.NORMAL, Gris)));
            return c;
        }

        private static void PorEspecialista(Document doc, ReporteCajaEspecialistasDto r)
        {
            doc.Add(new Paragraph("POR ESPECIALISTA", F(9.5f, Font.BOLD, Verde)) { SpacingBefore = 8, SpacingAfter = 4, KeepTogether = true });
            var lista = r.PorEspecialista ?? new List<CajaEspecialistaDto>();
            if (!lista.Any()) { doc.Add(new Paragraph("No hay cobros con estos filtros.", F(8, Font.ITALIC, Gris))); return; }

            var formas = r.FormasPago ?? new List<string>();
            bool adelantos = r.Adelantos > 0;
            var enc = new List<string> { "Especialista", "Pacientes" };
            enc.AddRange(formas);
            enc.AddRange(new[] { "Cobrado con IVA", "IVA" });
            if (adelantos) enc.Add("Adelantos aplicados");
            enc.AddRange(new[] { "Ventas sin IVA", "Comisión" });

            var anchos = new List<float> { 22, 10 };
            anchos.AddRange(formas.Select(f => 13f));
            anchos.AddRange(new[] { 13f, 10f });
            if (adelantos) anchos.Add(12);
            anchos.AddRange(new[] { 13f, 15f });

            var t = new PdfPTable(enc.Count) { WidthPercentage = 100, HeaderRows = 1 };
            t.SetWidths(anchos.ToArray());
            for (int i = 0; i < enc.Count; i++)
                t.AddCell(new PdfPCell(new Phrase(enc[i], F(7.5f, Font.BOLD, BaseColor.WHITE)))
                {
                    BackgroundColor = Verde, BorderColor = Verde, Padding = 4, PaddingLeft = 2, PaddingRight = 4, VerticalAlignment = Element.ALIGN_BOTTOM,
                    HorizontalAlignment = i == 0 ? Element.ALIGN_LEFT : Element.ALIGN_RIGHT
                });

            foreach (var e in lista)
            {
                t.AddCell(Celda(e.Especialista, Font.BOLD, Element.ALIGN_LEFT));
                t.AddCell(Celda(e.Pacientes.ToString("#,##0", Inv)));
                foreach (var f in formas)
                {
                    var g = (e.PorFormaPago ?? new List<TotalGrupoDto>()).FirstOrDefault(x => x.Nombre == f);
                    t.AddCell(Celda(D(g != null ? g.Total : 0), Font.NORMAL, Element.ALIGN_RIGHT, g == null ? Gris : null));
                }
                t.AddCell(Celda(D(e.Cobrado), Font.BOLD));
                t.AddCell(Celda(D(e.Iva), Font.NORMAL, Element.ALIGN_RIGHT, Gris));
                if (adelantos) t.AddCell(Celda(D(e.Adelantos)));
                t.AddCell(Celda(D(e.SinIva), Font.BOLD));
                t.AddCell(CeldaComision(e));
            }

            Total(t, "TOTAL", Element.ALIGN_LEFT);
            Total(t, r.Pacientes.ToString("#,##0", Inv));
            foreach (var f in formas)
            {
                var g = (r.PorFormaPago ?? new List<TotalGrupoDto>()).FirstOrDefault(x => x.Nombre == f);
                Total(t, D(g != null ? g.Total : 0));
            }
            Total(t, D(r.Cobrado));
            Total(t, D(r.Iva));
            if (adelantos) Total(t, D(r.Adelantos));
            Total(t, D(r.SinIva));
            Total(t, D(r.Comision));
            doc.Add(t);

            doc.Add(new Paragraph(
                "Cobrado: DTE vigentes emitidos en el periodo, asignados al especialista que atendió el procedimiento. "
                + "Ventas sin IVA: factura ÷ 1.13 y crédito fiscal por su venta gravada (mismo cálculo de las metas). "
                + "Comisión: esquema de bono de Registros › Metas (comisión por escala + bono de escala + bono por cumplir la meta) "
                + "con las ventas sin IVA del periodo y la meta de cada mes.", F(7, Font.ITALIC, Gris)) { SpacingBefore = 5 });
        }

        private static PdfPCell Celda(string texto, int estilo = Font.NORMAL, int alineacion = Element.ALIGN_RIGHT, BaseColor color = null)
        {
            return new PdfPCell(new Phrase(texto ?? "", F(8, estilo, color))) { BorderColor = Linea, BorderWidthLeft = 0, BorderWidthRight = 0, Padding = 5, HorizontalAlignment = alineacion, VerticalAlignment = Element.ALIGN_MIDDLE };
        }

        private static PdfPCell CeldaComision(CajaEspecialistaDto e)
        {
            var c = new PdfPCell { BorderColor = Linea, BorderWidthLeft = 0, BorderWidthRight = 0, Padding = 5, PaddingTop = 2, VerticalAlignment = Element.ALIGN_MIDDLE };
            if (e.Meta == null && e.Comision == 0)
            {
                c.AddElement(new Paragraph("sin meta", F(7.5f, Font.ITALIC, Gris)) { Alignment = Element.ALIGN_RIGHT });
                return c;
            }
            c.AddElement(new Paragraph(D(e.Comision), F(8, Font.BOLD)) { Alignment = Element.ALIGN_RIGHT });
            var sub = new List<string>();
            if (e.PorcentajeEscala > 0) sub.Add("escala " + P(e.PorcentajeEscala));
            if (e.BonoAlcance > 0) sub.Add("incl. bono meta " + D(e.BonoAlcance));
            if (e.Comision == 0) sub.Add(e.SinEscalas ? "meta sin escalas" : "bajo el mínimo");
            if (sub.Any()) c.AddElement(new Paragraph(string.Join(" · ", sub), F(6.5f, Font.NORMAL, Gris)) { Alignment = Element.ALIGN_RIGHT });
            return c;
        }

        private static void Total(PdfPTable t, string texto, int alineacion = Element.ALIGN_RIGHT)
        {
            t.AddCell(new PdfPCell(new Phrase(texto, F(8, Font.BOLD, alineacion == Element.ALIGN_LEFT ? BaseColor.BLACK : Verde)))
            { BackgroundColor = Fondo, BorderColor = Linea, Padding = 5, HorizontalAlignment = alineacion });
        }

        /// <summary>Pie de página: quién lo generó, cuándo y número de página.</summary>
        private class Pie : PdfPageEventHelper
        {
            private readonly string usuario;
            public Pie(string usuario) { this.usuario = usuario; }

            public override void OnEndPage(PdfWriter writer, Document document)
            {
                var texto = "Generado por " + (usuario ?? "") + " el " + DateTime.Now.ToString("dd/MM/yyyy hh:mm tt", Inv) + "   ·   Página " + writer.PageNumber;
                ColumnText.ShowTextAligned(writer.DirectContent, Element.ALIGN_CENTER, new Phrase(texto, F(7, Font.NORMAL, Gris)),
                    (document.Left + document.Right) / 2, document.Bottom - 20, 0);
            }
        }
    }
}
