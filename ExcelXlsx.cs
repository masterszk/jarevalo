using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.IO.Packaging;
using System.Security;
using System.Text;

namespace DPieCenter
{
    /// <summary>Hoja de un libro de Excel (ExcelXlsx.CrearLibro).</summary>
    public class HojaXlsx
    {
        public string Nombre { get; set; }
        /// <summary>Primera fila de la hoja (por ejemplo el rango del reporte); null para omitirla.</summary>
        public string Titulo { get; set; }
        public string[] Encabezados { get; set; }
        public IEnumerable<object[]> Filas { get; set; }
        /// <summary>Ancho de cada columna en caracteres; null para el ancho por defecto.</summary>
        public double[] Anchos { get; set; }
        /// <summary>Formato de cada columna: "$" moneda (#,##0.00), "d" fecha, "f" fecha y hora; null o "" texto/número tal cual.</summary>
        public string[] Formatos { get; set; }
        /// <summary>Últimas filas en negrita (totales).</summary>
        public int FilasTotal { get; set; }
    }

    /// <summary>
    /// Genera libros de Excel (.xlsx) sin librerías externas (System.IO.Packaging de WindowsBase).
    /// Encabezado en negrita con filtro, fila de encabezado inmovilizada, moneda con dos decimales y fechas dd/mm/yyyy.
    /// Valores admitidos: string, números, DateTime, bool (Sí / No) y null.
    /// </summary>
    public static class ExcelXlsx
    {
        public const string TipoMime = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";

        private const string NsMain = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";
        private const string NsRel = "http://schemas.openxmlformats.org/officeDocument/2006/relationships";
        // índices de cellXfs (Estilos)
        private const int EstiloEncabezado = 1, EstiloFechaHora = 2, EstiloTitulo = 3, EstiloMoneda = 4, EstiloFecha = 5,
                          EstiloNegrita = 6, EstiloMonedaNegrita = 7, EstiloFechaHoraNegrita = 8, EstiloFechaNegrita = 9;

        /// <summary>Libro de una hoja (compatibilidad con Inbound).</summary>
        public static byte[] Crear(string hoja, string titulo, string[] encabezados, IEnumerable<object[]> filas, double[] anchos)
        {
            return CrearLibro(new[] { new HojaXlsx { Nombre = hoja, Titulo = titulo, Encabezados = encabezados, Filas = filas, Anchos = anchos } });
        }

        public static byte[] CrearLibro(IList<HojaXlsx> hojas)
        {
            if (hojas == null || hojas.Count == 0) throw new ArgumentException("El libro necesita al menos una hoja.");
            using (var ms = new MemoryStream())
            {
                using (Package p = Package.Open(ms, FileMode.Create))
                {
                    var uLibro = new Uri("/xl/workbook.xml", UriKind.Relative);
                    var uEstilos = new Uri("/xl/styles.xml", UriKind.Relative);
                    var libro = p.CreatePart(uLibro, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml", CompressionOption.Normal);
                    p.CreateRelationship(uLibro, TargetMode.Internal, NsRel + "/officeDocument", "rId1");
                    var estilos = p.CreatePart(uEstilos, "application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml", CompressionOption.Normal);
                    libro.CreateRelationship(new Uri("styles.xml", UriKind.Relative), TargetMode.Internal, NsRel + "/styles", "rIdEstilos");

                    var sheets = new StringBuilder();
                    var nombres = new StringBuilder();
                    var usados = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                    for (int i = 0; i < hojas.Count; i++)
                    {
                        var h = hojas[i];
                        var enc = h.Encabezados ?? new string[0];
                        string nombre = NombreUnico(NombreHoja(h.Nombre), usados);
                        int filaEnc = string.IsNullOrEmpty(h.Titulo) ? 1 : 3;
                        var uHoja = new Uri("/xl/worksheets/sheet" + (i + 1) + ".xml", UriKind.Relative);
                        var parte = p.CreatePart(uHoja, "application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml", CompressionOption.Normal);
                        libro.CreateRelationship(new Uri("worksheets/sheet" + (i + 1) + ".xml", UriKind.Relative), TargetMode.Internal, NsRel + "/worksheet", "rId" + (i + 1));
                        sheets.Append("<sheet name=\"").Append(X(nombre)).Append("\" sheetId=\"").Append(i + 1).Append("\" r:id=\"rId").Append(i + 1).Append("\"/>");
                        if (enc.Length > 0)
                            nombres.Append("<definedName name=\"_xlnm._FilterDatabase\" localSheetId=\"").Append(i).Append("\" hidden=\"1\">'")
                                   .Append(X(nombre.Replace("'", "''"))).Append("'!$A$").Append(filaEnc).Append(":$").Append(Columna(enc.Length - 1)).Append("$").Append(filaEnc).Append("</definedName>");
                        Escribir(parte, Hoja(h, enc, filaEnc));
                    }
                    Escribir(libro, "<workbook xmlns=\"" + NsMain + "\" xmlns:r=\"" + NsRel + "\"><sheets>" + sheets + "</sheets>"
                        + (nombres.Length > 0 ? "<definedNames>" + nombres + "</definedNames>" : "") + "</workbook>");
                    Escribir(estilos, Estilos());
                }
                return ms.ToArray();
            }
        }

        private static string Hoja(HojaXlsx h, string[] enc, int filaEnc)
        {
            var filas = new List<object[]>(h.Filas ?? new object[0][]);
            int primeraTotal = filas.Count - Math.Max(0, h.FilasTotal);
            var sb = new StringBuilder();
            sb.Append("<worksheet xmlns=\"").Append(NsMain).Append("\"><sheetViews><sheetView workbookViewId=\"0\">")
              .Append("<pane ySplit=\"").Append(filaEnc).Append("\" topLeftCell=\"A").Append(filaEnc + 1).Append("\" activePane=\"bottomLeft\" state=\"frozen\"/>")
              .Append("</sheetView></sheetViews>");
            if (h.Anchos != null && h.Anchos.Length > 0)
            {
                sb.Append("<cols>");
                for (int i = 0; i < h.Anchos.Length; i++)
                    sb.Append("<col min=\"").Append(i + 1).Append("\" max=\"").Append(i + 1).Append("\" width=\"")
                      .Append(h.Anchos[i].ToString(CultureInfo.InvariantCulture)).Append("\" customWidth=\"1\"/>");
                sb.Append("</cols>");
            }
            sb.Append("<sheetData>");
            int fila = 1;
            if (filaEnc > 1)
            {
                sb.Append("<row r=\"1\">");
                Celda(sb, 0, 1, h.Titulo, EstiloTitulo, null);
                sb.Append("</row>");
                fila = filaEnc;
            }
            sb.Append("<row r=\"").Append(fila).Append("\">");
            for (int i = 0; i < enc.Length; i++) Celda(sb, i, fila, enc[i], EstiloEncabezado, null);
            sb.Append("</row>");
            for (int n = 0; n < filas.Count; n++)
            {
                var valores = filas[n] ?? new object[0];
                bool total = n >= primeraTotal;
                fila++;
                sb.Append("<row r=\"").Append(fila).Append("\">");
                for (int i = 0; i < valores.Length; i++)
                {
                    string formato = h.Formatos != null && i < h.Formatos.Length ? h.Formatos[i] : null;
                    Celda(sb, i, fila, valores[i], total ? EstiloNegrita : 0, formato);
                }
                sb.Append("</row>");
            }
            sb.Append("</sheetData>");
            // el filtro no incluye las filas de total
            if (enc.Length > 0)
                sb.Append("<autoFilter ref=\"A").Append(filaEnc).Append(":").Append(Columna(enc.Length - 1))
                  .Append(Math.Max(filaEnc, filaEnc + primeraTotal)).Append("\"/>");
            sb.Append("</worksheet>");
            return sb.ToString();
        }

        private static void Celda(StringBuilder sb, int col, int fila, object v, int estilo, string formato)
        {
            if (v == null || v == DBNull.Value) return;
            string r = Columna(col) + fila;
            bool negrita = estilo == EstiloNegrita;
            if (v is DateTime)
            {
                // las fechas de Excel son días desde 1899-12-30
                double serie = ((DateTime)v - new DateTime(1899, 12, 30)).TotalDays;
                int e = formato == "d" ? (negrita ? EstiloFechaNegrita : EstiloFecha) : (negrita ? EstiloFechaHoraNegrita : EstiloFechaHora);
                sb.Append("<c r=\"").Append(r).Append("\" s=\"").Append(e).Append("\"><v>")
                  .Append(serie.ToString("0.########", CultureInfo.InvariantCulture)).Append("</v></c>");
                return;
            }
            if (v is int || v is long || v is decimal || v is double || v is float || v is short)
            {
                int e = formato == "$" ? (negrita ? EstiloMonedaNegrita : EstiloMoneda) : estilo;
                sb.Append("<c r=\"").Append(r).Append("\"").Append(e > 0 ? " s=\"" + e + "\"" : "").Append("><v>")
                  .Append(Convert.ToDecimal(v).ToString(CultureInfo.InvariantCulture)).Append("</v></c>");
                return;
            }
            string texto = v is bool ? ((bool)v ? "Sí" : "No") : Convert.ToString(v, CultureInfo.CurrentCulture);
            sb.Append("<c r=\"").Append(r).Append("\" t=\"inlineStr\"").Append(estilo > 0 ? " s=\"" + estilo + "\"" : "")
              .Append("><is><t xml:space=\"preserve\">").Append(X(texto)).Append("</t></is></c>");
        }

        private static string Estilos()
        {
            return "<styleSheet xmlns=\"" + NsMain + "\">"
                + "<numFmts count=\"3\"><numFmt numFmtId=\"164\" formatCode=\"dd/mm/yyyy hh:mm\"/><numFmt numFmtId=\"165\" formatCode=\"#,##0.00\"/>"
                + "<numFmt numFmtId=\"166\" formatCode=\"dd/mm/yyyy\"/></numFmts>"
                + "<fonts count=\"4\"><font><sz val=\"11\"/><name val=\"Calibri\"/></font>"
                + "<font><b/><sz val=\"11\"/><color rgb=\"FFFFFFFF\"/><name val=\"Calibri\"/></font>"
                + "<font><b/><sz val=\"13\"/><color rgb=\"FF0B6F78\"/><name val=\"Calibri\"/></font>"
                + "<font><b/><sz val=\"11\"/><name val=\"Calibri\"/></font></fonts>"
                + "<fills count=\"4\"><fill><patternFill patternType=\"none\"/></fill><fill><patternFill patternType=\"gray125\"/></fill>"
                + "<fill><patternFill patternType=\"solid\"><fgColor rgb=\"FF0D8F9B\"/><bgColor indexed=\"64\"/></patternFill></fill>"
                + "<fill><patternFill patternType=\"solid\"><fgColor rgb=\"FFE9F5F6\"/><bgColor indexed=\"64\"/></patternFill></fill></fills>"
                + "<borders count=\"2\"><border><left/><right/><top/><bottom/><diagonal/></border>"
                + "<border><left/><right/><top style=\"thin\"><color rgb=\"FF0D8F9B\"/></top><bottom/><diagonal/></border></borders>"
                + "<cellStyleXfs count=\"1\"><xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/></cellStyleXfs>"
                + "<cellXfs count=\"10\"><xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\" xfId=\"0\"/>"
                + "<xf numFmtId=\"0\" fontId=\"1\" fillId=\"2\" borderId=\"0\" xfId=\"0\" applyFont=\"1\" applyFill=\"1\"/>"
                + "<xf numFmtId=\"164\" fontId=\"0\" fillId=\"0\" borderId=\"0\" xfId=\"0\" applyNumberFormat=\"1\"/>"
                + "<xf numFmtId=\"0\" fontId=\"2\" fillId=\"0\" borderId=\"0\" xfId=\"0\" applyFont=\"1\"/>"
                + "<xf numFmtId=\"165\" fontId=\"0\" fillId=\"0\" borderId=\"0\" xfId=\"0\" applyNumberFormat=\"1\"/>"
                + "<xf numFmtId=\"166\" fontId=\"0\" fillId=\"0\" borderId=\"0\" xfId=\"0\" applyNumberFormat=\"1\"/>"
                + "<xf numFmtId=\"0\" fontId=\"3\" fillId=\"3\" borderId=\"1\" xfId=\"0\" applyFont=\"1\" applyFill=\"1\" applyBorder=\"1\"/>"
                + "<xf numFmtId=\"165\" fontId=\"3\" fillId=\"3\" borderId=\"1\" xfId=\"0\" applyNumberFormat=\"1\" applyFont=\"1\" applyFill=\"1\" applyBorder=\"1\"/>"
                + "<xf numFmtId=\"164\" fontId=\"3\" fillId=\"3\" borderId=\"1\" xfId=\"0\" applyNumberFormat=\"1\" applyFont=\"1\" applyFill=\"1\" applyBorder=\"1\"/>"
                + "<xf numFmtId=\"166\" fontId=\"3\" fillId=\"3\" borderId=\"1\" xfId=\"0\" applyNumberFormat=\"1\" applyFont=\"1\" applyFill=\"1\" applyBorder=\"1\"/></cellXfs>"
                + "<cellStyles count=\"1\"><cellStyle name=\"Normal\" xfId=\"0\" builtinId=\"0\"/></cellStyles></styleSheet>";
        }

        private static void Escribir(PackagePart parte, string xml)
        {
            using (var s = parte.GetStream(FileMode.Create, FileAccess.Write))
            {
                var b = new UTF8Encoding(false).GetBytes("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" + xml);
                s.Write(b, 0, b.Length);
            }
        }

        private static string Columna(int i)
        {
            string s = "";
            for (i++; i > 0; i = (i - 1) / 26) s = (char)('A' + (i - 1) % 26) + s;
            return s;
        }

        // Excel no admite : \ / ? * [ ] en el nombre de la hoja y lo limita a 31 caracteres
        private static string NombreHoja(string s)
        {
            var sb = new StringBuilder();
            foreach (char c in s ?? "Hoja1") if (":\\/?*[]".IndexOf(c) < 0) sb.Append(c);
            string n = sb.ToString().Trim();
            if (n.Length == 0) n = "Hoja1";
            return n.Length > 31 ? n.Substring(0, 31) : n;
        }

        // Los nombres de hoja no se pueden repetir en un libro
        private static string NombreUnico(string n, HashSet<string> usados)
        {
            string r = n;
            for (int i = 2; !usados.Add(r); i++)
            {
                string sufijo = " (" + i + ")";
                r = (n.Length + sufijo.Length > 31 ? n.Substring(0, 31 - sufijo.Length) : n) + sufijo;
            }
            return r;
        }

        // Escapa el texto y quita los caracteres de control que XML no admite
        private static string X(string s)
        {
            if (string.IsNullOrEmpty(s)) return "";
            var sb = new StringBuilder(s.Length);
            foreach (char c in s) if (c >= 0x20 || c == '\t' || c == '\n' || c == '\r') sb.Append(c);
            return SecurityElement.Escape(sb.ToString());
        }
    }
}
