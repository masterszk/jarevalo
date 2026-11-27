using System;
using System.Data.SqlClient;
using System.Globalization;
using System.Web;
using System.Web.Services;
using DPieCenter.Reportes;

namespace DPieCenter.Dashboard
{
    /// <summary>Dashboard de inicio: especialistas, expedientes, citas y procedimientos (assets/js/dashboard.js).</summary>
    public partial class form_DashboardGeneral : System.Web.UI.Page
    {
        private const int MaxDias = 366;

        protected void Page_Load(object sender, EventArgs e)
        {

        }

        /// <summary>desde / hasta con formato yyyy-MM-dd. Los montos solo se envían a los administradores.</summary>
        [WebMethod(EnableSession = true)]
        public static DashboardDto Datos(string desde, string hasta)
        {
            if (!Sesion.Activa) return new DashboardDto { Ok = false, Mensaje = "La sesión expiró. Vuelva a iniciar sesión." };

            DateTime d, h;
            if (!DateTime.TryParseExact(desde ?? "", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out d)
                || !DateTime.TryParseExact(hasta ?? "", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out h)
                || h < d)
                return new DashboardDto { Ok = false, Mensaje = "Seleccione un rango de fechas válido." };
            if ((h - d).TotalDays > MaxDias)
                return new DashboardDto { Ok = false, Mensaje = "El rango no puede superar un año." };

            try { return ReportesRepository.Dashboard(d, h, Sesion.EsAdministrador, Sesion.Sucursal); }    // sucursal en la que trabaja
            catch (Exception ex) { return new DashboardDto { Ok = false, Mensaje = Detalle(ex, "No fue posible cargar el dashboard.") }; }
        }

        /// <summary>
        /// Top 10 de pacientes recurrentes. alcance: periodo (desde/hasta del dashboard) | 12m (últimos 12 meses) | todo (todo el historial).
        /// </summary>
        [WebMethod(EnableSession = true)]
        public static TopPacientesDto TopPacientes(string desde, string hasta, string alcance)
        {
            if (!Sesion.Activa) return new TopPacientesDto { Ok = false, Mensaje = "La sesión expiró. Vuelva a iniciar sesión." };

            DateTime d, h = DateTime.Today;
            alcance = (alcance ?? "12m").Trim().ToLowerInvariant();
            if (alcance == "periodo")
            {
                if (!DateTime.TryParseExact(desde ?? "", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out d)
                    || !DateTime.TryParseExact(hasta ?? "", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out h)
                    || h < d)
                    return new TopPacientesDto { Ok = false, Mensaje = "Seleccione un rango de fechas válido." };
            }
            else if (alcance == "todo") d = new DateTime(2000, 1, 1);
            else { alcance = "12m"; d = h.AddMonths(-12).AddDays(1); }

            try
            {
                return new TopPacientesDto
                {
                    Ok = true,
                    VerDinero = Sesion.EsAdministrador,
                    Alcance = alcance,
                    Desde = d.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture),
                    Hasta = h.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture),
                    Pacientes = ReportesRepository.TopPacientes(d, h, Sesion.EsAdministrador, Sesion.Sucursal)
                };
            }
            catch (Exception ex) { return new TopPacientesDto { Ok = false, Mensaje = Detalle(ex, "No fue posible cargar los pacientes recurrentes.") }; }
        }

        private static string Detalle(Exception ex, string generico)
        {
            var sql = ex as SqlException;
            if (sql != null && sql.Number >= 50000) return sql.Message;
            System.Diagnostics.Trace.TraceError("Dashboard: " + ex);
            bool debug = HttpContext.Current != null && HttpContext.Current.IsDebuggingEnabled;
            return debug ? "[DEBUG] " + ex.Message : generico;
        }
    }
}
