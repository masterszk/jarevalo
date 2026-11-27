using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Globalization;
using System.Web;
using System.Web.Services;

namespace DPieCenter.Reportes
{
    /// <summary>Reporte de caja por rango de fechas y cajero (assets/js/reporte-caja.js). Grupos con la opción en Opciones > Permisos.</summary>
    public partial class frm_repCaja : System.Web.UI.Page
    {
        private const int MaxDias = 366;

        protected void Page_Load(object sender, EventArgs e)
        {

        }

        private const string Url = "Reportes/frm_repCaja.aspx";

        // Mismo permiso que el menú (Opciones > Permisos); antes exigía ser administrador aunque el grupo tuviera la opción
        private static string Permiso()
        {
            if (!Sesion.Activa) return "La sesión expiró. Vuelva a iniciar sesión.";
            if (!Sesion.EsAdministrador && !Sesion.TieneAcceso(Url)) return "No tiene permiso para ver el reporte de caja.";
            return null;
        }

        private static string Detalle(Exception ex, string generico)
        {
            var sql = ex as SqlException;
            if (sql != null && sql.Number >= 50000) return sql.Message;
            System.Diagnostics.Trace.TraceError(generico + ": " + ex);
            bool debug = HttpContext.Current != null && HttpContext.Current.IsDebuggingEnabled;
            return debug ? "[DEBUG] " + ex.GetType().Name + ": " + ex.Message : generico;
        }

        [WebMethod(EnableSession = true)]
        public static List<CajeroDto> Cajeros()
        {
            if (Permiso() != null) return new List<CajeroDto>();
            try { return ReportesRepository.Cajeros(); }
            catch (Exception ex) { Detalle(ex, "Cajeros"); return new List<CajeroDto>(); }
        }

        public class SucursalesReporteDto
        {
            public int Actual { get; set; }
            public List<Opciones.CatalogoItemDto> Items { get; set; }   // null: el usuario no elige (ve su sucursal)
        }

        /// <summary>Sucursales para el filtro: solo los administradores eligen (o ven todas).</summary>
        [WebMethod(EnableSession = true)]
        public static SucursalesReporteDto Sucursales()
        {
            if (Permiso() != null) return new SucursalesReporteDto();
            return new SucursalesReporteDto { Actual = Sesion.Sucursal, Items = Sesion.EsAdministrador ? Opciones.SucursalesRepository.Activas() : null };
        }

        /// <summary>desde / hasta con formato yyyy-MM-dd; cajero vacío = todos; sucursal 0 = todas (solo administradores).</summary>
        [WebMethod(EnableSession = true)]
        public static CajaReporteDto Consultar(string desde, string hasta, string cajero, int sucursal)
        {
            string permiso = Permiso();
            if (permiso != null) return new CajaReporteDto { Ok = false, Mensaje = permiso };

            DateTime d, h;
            if (!DateTime.TryParseExact(desde ?? "", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out d)
                || !DateTime.TryParseExact(hasta ?? "", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out h)
                || h < d)
                return new CajaReporteDto { Ok = false, Mensaje = "Seleccione un rango de fechas válido." };
            if ((h - d).TotalDays > MaxDias)
                return new CajaReporteDto { Ok = false, Mensaje = "El rango no puede superar un año." };

            try { return ReportesRepository.Caja(d, h, cajero, Sesion.SucursalFiltro(sucursal)); }
            catch (Exception ex) { return new CajaReporteDto { Ok = false, Mensaje = Detalle(ex, "No fue posible generar el reporte de caja.") }; }
        }

        /// <summary>Libro de Excel (.xlsx) con las tablas que se ven en pantalla (todo el reporte o un cuadro), en base64.</summary>
        [WebMethod(EnableSession = true)]
        public static ArchivoExcelDto Excel(LibroExcelDto libro)
        {
            string permiso = Permiso();
            if (permiso != null) return new ArchivoExcelDto { Ok = false, Mensaje = permiso };
            return ReportesWeb.GenerarExcel(libro);
        }
    }
}
