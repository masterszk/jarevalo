using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;
using System.Web;
using System.Web.Services;

namespace DPieCenter.Facturacion
{
    /// <summary>
    /// Anulación (evento de invalidación) de DTE dentro del plazo de Hacienda (assets/js/anulaciones.js).
    /// Los plazos por tipo de documento están en FAC_DTE_PLAZOSINVALIDACION y solo los cambian los administradores.
    /// </summary>
    public partial class frm_Anulaciones : System.Web.UI.Page
    {
        private const string Url = "Facturacion/frm_Anulaciones.aspx";

        protected void Page_Load(object sender, EventArgs e)
        {

        }

        public class InicioAnulacionesDto
        {
            public bool Ok { get; set; }
            public string Mensaje { get; set; }
            public bool EsAdministrador { get; set; }
            public string NombreUsuario { get; set; }
            public List<PlazoDto> Plazos { get; set; }
            public List<string[]> Cajeros { get; set; }
        }

        public class FiltroAnulacionesDto
        {
            public string Desde { get; set; }
            public string Hasta { get; set; }
            public string TipoDte { get; set; }
            public string Cajero { get; set; }
            public string Texto { get; set; }
            /// <summary>plazo | anulados | todos</summary>
            public string Vista { get; set; }
        }

        public class ListaAnulacionesDto
        {
            public bool Ok { get; set; }
            public string Mensaje { get; set; }
            public List<DteListaDto> Items { get; set; }
        }

        public class RespuestaAnulacionDto
        {
            public bool Ok { get; set; }
            public string Mensaje { get; set; }
            public string CodigoEvento { get; set; }
        }

        [WebMethod(EnableSession = true)]
        public static InicioAnulacionesDto Inicio()
        {
            string permiso = Permiso();
            if (permiso != null) return new InicioAnulacionesDto { Ok = false, Mensaje = permiso };
            try
            {
                return new InicioAnulacionesDto
                {
                    Ok = true,
                    EsAdministrador = Sesion.EsAdministrador,
                    NombreUsuario = NombreDe(Sesion.Usuario),
                    Plazos = CajaRepository.Plazos(),
                    Cajeros = CajaRepository.Cajeros()
                };
            }
            catch (Exception ex) { return new InicioAnulacionesDto { Ok = false, Mensaje = Detalle(ex, "No fue posible cargar la pantalla.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static ListaAnulacionesDto Lista(FiltroAnulacionesDto filtro)
        {
            string permiso = Permiso();
            if (permiso != null) return new ListaAnulacionesDto { Ok = false, Mensaje = permiso };
            if (filtro == null) return new ListaAnulacionesDto { Ok = false, Mensaje = "No se recibieron los filtros." };
            DateTime? d = FechaN(filtro.Desde), h = FechaN(filtro.Hasta);
            if (d.HasValue && h.HasValue && h < d) return new ListaAnulacionesDto { Ok = false, Mensaje = "La fecha final no puede ser anterior a la inicial." };
            string vista = filtro.Vista == "anulados" || filtro.Vista == "todos" ? filtro.Vista : "plazo";
            string texto = filtro.Texto != null && filtro.Texto.Length > 100 ? filtro.Texto.Substring(0, 100) : filtro.Texto;
            try { return new ListaAnulacionesDto { Ok = true, Items = CajaRepository.Documentos(d, h, filtro.TipoDte, filtro.Cajero, texto, vista) }; }
            catch (Exception ex) { return new ListaAnulacionesDto { Ok = false, Mensaje = Detalle(ex, "No fue posible cargar los documentos.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static RespuestaAnulacionDto Anular(AnulacionRequest anulacion)
        {
            string permiso = Permiso();
            if (permiso != null) return new RespuestaAnulacionDto { Ok = false, Mensaje = permiso };
            if (anulacion == null) return new RespuestaAnulacionDto { Ok = false, Mensaje = "No se recibieron los datos." };
            string[] tiposDoc = { "13", "36", "03", "02", "37" };
            if (Array.IndexOf(tiposDoc, anulacion.TipoDocResponsable) < 0 || Array.IndexOf(tiposDoc, anulacion.TipoDocSolicita) < 0)
                return new RespuestaAnulacionDto { Ok = false, Mensaje = "Seleccione el tipo de documento del responsable y de quien solicita." };
            try
            {
                string codigo = CajaRepository.Anular(anulacion, Sesion.Usuario);
                return new RespuestaAnulacionDto
                {
                    Ok = true,
                    CodigoEvento = codigo,
                    Mensaje = anulacion.TipoAnulacion == 2
                        ? "Documento anulado. La operación quedó rescindida."
                        : "Documento anulado. La factura volvió a la caja como pendiente para emitir el documento que lo reemplaza."
                };
            }
            catch (Exception ex) { return new RespuestaAnulacionDto { Ok = false, Mensaje = Detalle(ex, "No fue posible anular el documento.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static RespuestaAnulacionDto GuardarPlazo(string tipoDte, int dias)
        {
            string permiso = Permiso();
            if (permiso != null) return new RespuestaAnulacionDto { Ok = false, Mensaje = permiso };
            if (!Sesion.EsAdministrador) return new RespuestaAnulacionDto { Ok = false, Mensaje = "Solo un administrador puede cambiar los plazos." };
            try
            {
                CajaRepository.GuardarPlazo(tipoDte, dias, Sesion.Usuario);
                return new RespuestaAnulacionDto { Ok = true, Mensaje = "Plazo actualizado." };
            }
            catch (Exception ex) { return new RespuestaAnulacionDto { Ok = false, Mensaje = Detalle(ex, "No fue posible guardar el plazo.") }; }
        }

        private static string NombreDe(string usuario)
        {
            try
            {
                using (SqlProcess sql = new SqlProcess())
                    if (sql.mtdSys_Usuario(usuario, "", "", "", "", "", 0, "", "", "", "", 0, "", false, 13) == "OK" && sql.dtReturn.Rows.Count > 0)
                    {
                        DataRow r = sql.dtReturn.Rows[0];
                        string nombre = (r["Nombres"] + " " + r["Apellidos"]).Trim();
                        if (nombre.Length > 0) return nombre;
                    }
            }
            catch (Exception ex) { System.Diagnostics.Trace.TraceError("Anulaciones.NombreDe: " + ex); }
            return usuario;
        }

        private static DateTime? FechaN(string s)
        {
            DateTime d;
            return DateTime.TryParseExact(s ?? "", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out d) ? d : (DateTime?)null;
        }

        private static string Permiso()
        {
            if (!Sesion.Activa) return "La sesión expiró. Vuelva a iniciar sesión.";
            if (!Sesion.EsAdministrador && !Sesion.TieneAcceso(Url)) return "No tiene permiso para anular documentos.";
            return null;
        }

        private static string Detalle(Exception ex, string generico)
        {
            var sql = ex as SqlException;
            if (sql != null && sql.Number >= 50000) return sql.Message;
            if (ex is ArgumentException) return ex.Message;
            System.Diagnostics.Trace.TraceError("Anulaciones: " + ex);
            bool debug = HttpContext.Current != null && HttpContext.Current.IsDebuggingEnabled;
            return debug ? "[DEBUG] " + ex.Message : generico;
        }
    }
}
