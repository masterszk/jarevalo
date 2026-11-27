using System;
using System.Globalization;
using System.Linq;
using System.Web;
using System.Web.SessionState;

namespace DPieCenter.Reportes
{
    /// <summary>
    /// GET Reportes/CajaPdf.ashx?desde=yyyy-MM-dd&amp;hasta=yyyy-MM-dd&amp;cajero=usuario  ->  PDF del cierre de caja.
    /// Mismo permiso y mismos datos que Reportes > Caja (frm_repCaja.aspx).
    /// </summary>
    public class CajaPdfHandler : IHttpHandler, IRequiresSessionState
    {
        private const string Url = "Reportes/frm_repCaja.aspx";
        public bool IsReusable { get { return false; } }

        public void ProcessRequest(HttpContext context)
        {
            var rq = context.Request;
            if (!Sesion.Activa) { Texto(context, 401, "La sesión expiró. Vuelva a iniciar sesión."); return; }
            if (!Sesion.EsAdministrador && !Sesion.TieneAcceso(Url)) { Texto(context, 403, "No tiene permiso para ver el reporte de caja."); return; }

            DateTime d, h;
            if (!DateTime.TryParseExact(rq["desde"] ?? "", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out d)
                || !DateTime.TryParseExact(rq["hasta"] ?? "", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out h) || h < d)
            { Texto(context, 400, "Seleccione un rango de fechas válido."); return; }
            if ((h - d).TotalDays > 366) { Texto(context, 400, "El rango no puede superar un año."); return; }
            string cajero = (rq["cajero"] ?? "").Trim();
            int suc; int.TryParse(rq["sucursal"], out suc);
            int sucursal = Sesion.SucursalFiltro(suc);

            try
            {
                var r = ReportesRepository.Caja(d, h, cajero, sucursal);
                if (!r.Ok) { Texto(context, 400, r.Mensaje); return; }

                string empresa = "D' Pie Center"; byte[] logo = null;
                try
                {
                    var e = Facturacion.DteRepository.ObtenerEmisor();
                    if (e != null) { empresa = string.IsNullOrWhiteSpace(e.NombreComercial) ? e.Nombre : e.NombreComercial; logo = e.Logo; }
                }
                catch (Exception) { }
                if (logo == null || logo.Length == 0)       // sin logo del DTE: el logo de la clínica
                {
                    string ruta = context.Server.MapPath("~/assets/images/logo-dpiecenter-clinica.png");
                    if (System.IO.File.Exists(ruta)) logo = System.IO.File.ReadAllBytes(ruta);
                }
                string nombreCajero = cajero.Length == 0 ? null
                    : (ReportesRepository.Cajeros().Where(c => string.Equals(c.Usuario, cajero, StringComparison.OrdinalIgnoreCase)).Select(c => c.Nombre).FirstOrDefault() ?? cajero);

                string nombreSucursal = sucursal == 0 ? "Todas las sucursales"
                    : (Opciones.SucursalesRepository.Obtener(sucursal) ?? new Opciones.SucursalDto { Nombre = "" }).Nombre;
                byte[] pdf = CajaPdf.Generar(r, empresa, logo, nombreCajero, Sesion.Usuario, nombreSucursal);
                string archivo = "cierre_caja_" + d.ToString("yyyyMMdd") + (h > d ? "_" + h.ToString("yyyyMMdd") : "") + (cajero.Length > 0 ? "_" + cajero : "") + ".pdf";
                context.Response.ContentType = "application/pdf";
                context.Response.AddHeader("Content-Disposition", "inline; filename=\"" + archivo + "\"");
                context.Response.Cache.SetCacheability(HttpCacheability.NoCache);
                context.Response.BinaryWrite(pdf);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Trace.TraceError("Cierre de caja PDF: " + ex);
                Texto(context, 500, context.IsDebuggingEnabled ? "[DEBUG] " + ex.Message : "No fue posible generar el PDF.");
            }
        }

        private static void Texto(HttpContext context, int estado, string mensaje)
        {
            context.Response.StatusCode = estado;
            context.Response.ContentType = "text/plain; charset=utf-8";
            context.Response.Write(mensaje);
        }
    }
}
