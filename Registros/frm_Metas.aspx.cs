using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Services;

namespace DPieCenter.Registros
{
    /// <summary>
    /// Metas de ventas y esquema de bono por especialista (assets/js/metas.js). Cada especialista tiene su meta por mes;
    /// cada cambio crea una versión nueva y la anterior queda en el historial. Los meses sin cambios se generan solos
    /// copiando la meta del mes anterior. Los dashboards muestran el avance de cada uno contra su meta.
    /// </summary>
    public partial class frm_Metas : System.Web.UI.Page
    {
        private const string Url = "Registros/frm_Metas.aspx";

        protected void Page_Load(object sender, EventArgs e)
        {

        }

        public class MesMetasDto
        {
            public bool Ok { get; set; }
            public string Mensaje { get; set; }
            public int Anio { get; set; }
            public int Mes { get; set; }
            public string Periodo { get; set; }
            /// <summary>Meta vigente de cada especialista en el mes (Id = 0: sin meta).</summary>
            public List<MetaDto> Metas { get; set; }
            public MetasMesDto Avance { get; set; }
            /// <summary>Meta sugerida del mes para cada especialista y los factores por mes.</summary>
            public SugerenciasMesDto Sugeridas { get; set; }
        }

        public class MetaRespuestaDto
        {
            public bool Ok { get; set; }
            public string Mensaje { get; set; }
            public MetaDto Meta { get; set; }
            public List<MetaDto> Historial { get; set; }
            public int Guardadas { get; set; }
        }

        /// <summary>anio/mes = 0: el mes en curso.</summary>
        [WebMethod(EnableSession = true)]
        public static MesMetasDto Mes(int anio, int mes)
        {
            string permiso = Permiso();
            if (permiso != null) return new MesMetasDto { Ok = false, Mensaje = permiso };
            try
            {
                var hoy = DateTime.Today;
                if (anio < 2020 || anio > 2100 || mes < 1 || mes > 12) { anio = hoy.Year; mes = hoy.Month; }
                return new MesMetasDto
                {
                    Ok = true,
                    Anio = anio,
                    Mes = mes,
                    Periodo = MetasRepository.NombrePeriodo(anio, mes),
                    Metas = MetasRepository.Lista(anio, mes),
                    Avance = MetasRepository.AvanceMes(anio, mes, 0),
                    Sugeridas = MetasRepository.Sugerencias(anio, mes, 0)
                };
            }
            catch (Exception ex) { return new MesMetasDto { Ok = false, Mensaje = Detalle(ex, "No fue posible cargar las metas.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static MetaRespuestaDto Obtener(long id)
        {
            string permiso = Permiso();
            if (permiso != null) return new MetaRespuestaDto { Ok = false, Mensaje = permiso };
            try
            {
                var m = MetasRepository.Obtener(id);
                return m == null ? new MetaRespuestaDto { Ok = false, Mensaje = "La meta no existe." } : new MetaRespuestaDto { Ok = true, Meta = m };
            }
            catch (Exception ex) { return new MetaRespuestaDto { Ok = false, Mensaje = Detalle(ex, "No fue posible cargar la meta.") }; }
        }

        /// <summary>Todas las versiones de las metas del especialista.</summary>
        [WebMethod(EnableSession = true)]
        public static MetaRespuestaDto Historial(long especialista)
        {
            string permiso = Permiso();
            if (permiso != null) return new MetaRespuestaDto { Ok = false, Mensaje = permiso };
            try { return new MetaRespuestaDto { Ok = true, Historial = MetasRepository.Historial(especialista) }; }
            catch (Exception ex) { return new MetaRespuestaDto { Ok = false, Mensaje = Detalle(ex, "No fue posible cargar el historial.") }; }
        }

        /// <summary>Guarda la meta del mes para los especialistas indicados (versión nueva; la anterior queda en el historial).</summary>
        [WebMethod(EnableSession = true)]
        public static MetaRespuestaDto Guardar(MetaDto meta, List<long> especialistas)
        {
            string permiso = Permiso();
            if (permiso != null) return new MetaRespuestaDto { Ok = false, Mensaje = permiso };
            if (meta == null) return new MetaRespuestaDto { Ok = false, Mensaje = "Datos incompletos." };
            if (especialistas == null || especialistas.Count == 0) return new MetaRespuestaDto { Ok = false, Mensaje = "Seleccione al menos un especialista." };
            try
            {
                if (meta.Observaciones != null && meta.Observaciones.Length > 500) meta.Observaciones = meta.Observaciones.Substring(0, 500);
                if (meta.Escalas != null && meta.Escalas.Count > 20) return new MetaRespuestaDto { Ok = false, Mensaje = "La escala admite hasta 20 rangos." };
                int n = MetasRepository.Guardar(meta, especialistas, Sesion.Usuario);
                return new MetaRespuestaDto { Ok = true, Guardadas = n };
            }
            catch (Exception ex) { return new MetaRespuestaDto { Ok = false, Mensaje = Detalle(ex, "No fue posible guardar la meta.") }; }
        }

        /// <summary>Factores por mes (enero a diciembre), % de crecimiento y redondeo de la meta sugerida.</summary>
        [WebMethod(EnableSession = true)]
        public static MetaRespuestaDto GuardarSugerida(List<decimal> factores, decimal crecimiento, int redondeo)
        {
            string permiso = Permiso();
            if (permiso != null) return new MetaRespuestaDto { Ok = false, Mensaje = permiso };
            try
            {
                MetasRepository.GuardarParametros(factores, crecimiento, redondeo, Sesion.Usuario);
                return new MetaRespuestaDto { Ok = true };
            }
            catch (ArgumentException ex) { return new MetaRespuestaDto { Ok = false, Mensaje = ex.Message }; }
            catch (Exception ex) { return new MetaRespuestaDto { Ok = false, Mensaje = Detalle(ex, "No fue posible guardar los factores.") }; }
        }

        private static string Permiso()
        {
            if (!Sesion.Activa) return "La sesión expiró. Vuelva a iniciar sesión.";
            if (!Sesion.EsAdministrador && !Sesion.TieneAcceso(Url)) return "No tiene permiso para administrar metas.";
            return null;
        }

        private static string Detalle(Exception ex, string generico)
        {
            var sql = ex as SqlException;
            if (sql != null && sql.Number >= 50000) return sql.Message;
            System.Diagnostics.Trace.TraceError("Metas: " + ex);
            bool debug = HttpContext.Current != null && HttpContext.Current.IsDebuggingEnabled;
            return debug ? "[DEBUG] " + ex.Message : generico;
        }
    }
}
