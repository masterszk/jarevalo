using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Globalization;
using System.Linq;
using System.Web;

namespace DPieCenter.Reportes
{
    /// <summary>Libro de Excel que arma la pantalla: una hoja por tabla.</summary>
    public class LibroExcelDto
    {
        public string Nombre { get; set; }               // nombre del archivo sin extensión
        public List<HojaExcelDto> Hojas { get; set; }
    }

    public class HojaExcelDto
    {
        public string Nombre { get; set; }
        public string Titulo { get; set; }
        public List<string> Encabezados { get; set; }
        public List<string> Formatos { get; set; }       // "$" moneda, "d" fecha, "f" fecha y hora, "" tal cual
        public List<double> Anchos { get; set; }
        public List<List<object>> Filas { get; set; }
        public int FilasTotal { get; set; }              // últimas filas en negrita
    }

    public class ArchivoExcelDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public string Nombre { get; set; }
        public string Tipo { get; set; }
        public string Base64 { get; set; }
    }

    /// <summary>Validaciones comunes de los WebMethods de reportes: sesión, permiso de la opción del menú y rango de fechas.</summary>
    public static class ReportesWeb
    {
        public const int MaxDias = 731;

        /// <summary>Devuelve el motivo por el que no se puede consultar, o null. Deja en desde/hasta las fechas del filtro.</summary>
        public static string Validar(string accesoUrl, FiltroReporteDto filtro, out DateTime desde, out DateTime hasta)
        {
            desde = hasta = DateTime.MinValue;
            string permiso = Permiso(accesoUrl);
            if (permiso != null) return permiso;
            if (filtro == null) return "No se recibieron los filtros.";
            if (!DateTime.TryParseExact(filtro.Desde ?? "", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out desde)
                || !DateTime.TryParseExact(filtro.Hasta ?? "", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out hasta)
                || hasta < desde)
                return "Seleccione un rango de fechas válido.";
            if ((hasta - desde).TotalDays > MaxDias) return "El rango no puede superar dos años.";
            if (filtro.Paciente != null && filtro.Paciente.Length > 100) filtro.Paciente = filtro.Paciente.Substring(0, 100);
            return null;
        }

        public static string Permiso(string accesoUrl)
        {
            if (!Sesion.Activa) return "La sesión expiró. Vuelva a iniciar sesión.";
            if (!Sesion.TieneAcceso(accesoUrl)) return "No tiene permiso para ver este reporte.";
            return null;
        }

        /// <summary>
        /// Libro de Excel (.xlsx) con las tablas que arma la pantalla (assets/js/excel-reportes.js), en base64.
        /// Columnas con formato "d" / "f" reciben la fecha como yyyy-MM-dd / yyyy-MM-ddTHH:mm; "$" recibe números.
        /// </summary>
        public static ArchivoExcelDto Excel(string accesoUrl, LibroExcelDto libro)
        {
            string permiso = Permiso(accesoUrl);
            if (permiso != null) return new ArchivoExcelDto { Ok = false, Mensaje = permiso };
            return GenerarExcel(libro);
        }

        /// <summary>Igual que Excel, para las pantallas que ya validaron el permiso con su propia regla.</summary>
        public static ArchivoExcelDto GenerarExcel(LibroExcelDto libro)
        {
            if (libro == null || libro.Hojas == null || libro.Hojas.Count == 0) return new ArchivoExcelDto { Ok = false, Mensaje = "No hay datos para exportar." };
            if (libro.Hojas.Count > 20 || libro.Hojas.Sum(h => h.Filas == null ? 0 : h.Filas.Count) > 60000)
                return new ArchivoExcelDto { Ok = false, Mensaje = "El archivo es demasiado grande; reduzca el rango de fechas." };
            try
            {
                var hojas = libro.Hojas.Select(h =>
                {
                    var enc = (h.Encabezados ?? new List<string>()).Take(80).ToArray();
                    var formatos = h.Formatos == null ? null : h.Formatos.ToArray();
                    return new HojaXlsx
                    {
                        Nombre = h.Nombre, Titulo = h.Titulo, Encabezados = enc, Formatos = formatos,
                        Anchos = h.Anchos == null ? null : h.Anchos.Select(a => Math.Max(4, Math.Min(80, a))).ToArray(),
                        FilasTotal = Math.Max(0, h.FilasTotal),
                        Filas = (h.Filas ?? new List<List<object>>()).Select(f => (f ?? new List<object>()).Take(enc.Length).Select((v, i) =>
                            ValorExcel(v, formatos != null && i < formatos.Length ? formatos[i] : null)).ToArray()).ToList()
                    };
                }).ToList();

                string nombre = string.Concat((libro.Nombre ?? "reporte").Where(c => char.IsLetterOrDigit(c) || c == '_' || c == '-'));
                return new ArchivoExcelDto
                {
                    Ok = true,
                    Nombre = (nombre.Length == 0 ? "reporte" : nombre.Length > 80 ? nombre.Substring(0, 80) : nombre) + ".xlsx",
                    Tipo = ExcelXlsx.TipoMime,
                    Base64 = Convert.ToBase64String(ExcelXlsx.CrearLibro(hojas))
                };
            }
            catch (Exception ex) { return new ArchivoExcelDto { Ok = false, Mensaje = Detalle(ex, "No fue posible generar el archivo de Excel.") }; }
        }

        private static object ValorExcel(object v, string formato)
        {
            var s = v as string;
            if (s != null && (formato == "d" || formato == "f"))
            {
                DateTime f;
                if (DateTime.TryParseExact(s, new[] { "yyyy-MM-dd", "yyyy-MM-ddTHH:mm", "yyyy-MM-ddTHH:mm:ss" }, CultureInfo.InvariantCulture, DateTimeStyles.None, out f))
                    return f;
            }
            if (s != null && s.Length > 32000) return s.Substring(0, 32000);
            return v;
        }

        public static string Detalle(Exception ex, string generico)
        {
            var sql = ex as SqlException;
            if (sql != null && sql.Number >= 50000) return sql.Message;
            System.Diagnostics.Trace.TraceError(generico + ": " + ex);
            bool debug = HttpContext.Current != null && HttpContext.Current.IsDebuggingEnabled;
            return debug ? "[DEBUG] " + ex.GetType().Name + ": " + ex.Message : generico;
        }
    }
}
