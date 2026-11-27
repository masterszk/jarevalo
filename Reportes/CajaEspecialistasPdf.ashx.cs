using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Web;
using System.Web.SessionState;

namespace DPieCenter.Reportes
{
    /// <summary>
    /// GET Reportes/CajaEspecialistasPdf.ashx?desde=yyyy-MM-dd&amp;hasta=yyyy-MM-dd&amp;especialista=0&amp;formaPago=0&amp;paciente=&amp;sucursal=0
    /// -> PDF de la caja por especialista (tarjetas y tabla por especialista). Mismo permiso y datos que frm_repCajaEspecialistas.aspx.
    /// </summary>
    public class CajaEspecialistasPdfHandler : IHttpHandler, IRequiresSessionState
    {
        private const string Url = "Reportes/frm_repCajaEspecialistas.aspx";
        public bool IsReusable { get { return false; } }

        public void ProcessRequest(HttpContext context)
        {
            var rq = context.Request;
            long especialista, forma; int suc;
            long.TryParse(rq["especialista"], NumberStyles.Integer, CultureInfo.InvariantCulture, out especialista);
            long.TryParse(rq["formaPago"], NumberStyles.Integer, CultureInfo.InvariantCulture, out forma);
            int.TryParse(rq["sucursal"], NumberStyles.Integer, CultureInfo.InvariantCulture, out suc);
            var filtro = new FiltroReporteDto
            {
                Desde = rq["desde"], Hasta = rq["hasta"], Especialista = especialista, FormaPago = forma,
                Paciente = (rq["paciente"] ?? "").Trim(), Sucursal = suc
            };

            DateTime desde, hasta;
            string error = ReportesWeb.Validar(Url, filtro, out desde, out hasta);
            if (error != null) { Texto(context, Sesion.Activa ? 400 : 401, error); return; }

            try
            {
                var r = ReportesDetalleRepository.CajaEspecialistas(filtro, desde, hasta);
                if (!r.Ok) { Texto(context, 400, r.Mensaje); return; }

                string empresa = "D' Pie Center"; byte[] logo = null;
                try
                {
                    var e = Facturacion.DteRepository.ObtenerEmisor();
                    if (e != null) { empresa = string.IsNullOrWhiteSpace(e.NombreComercial) ? e.Nombre : e.NombreComercial; logo = e.Logo; }
                }
                catch (Exception) { }
                if (logo == null || logo.Length == 0)
                {
                    string ruta = context.Server.MapPath("~/assets/images/logo-dpiecenter-clinica.png");
                    if (System.IO.File.Exists(ruta)) logo = System.IO.File.ReadAllBytes(ruta);
                }

                int sucursal = Sesion.SucursalFiltro(suc);
                string nombreSucursal = sucursal == 0 ? "Todas las sucursales"
                    : (Opciones.SucursalesRepository.Obtener(sucursal) ?? new Opciones.SucursalDto { Nombre = "" }).Nombre;

                var filtros = new List<string>();
                if (especialista > 0)
                {
                    var esp = r.PorEspecialista.FirstOrDefault(x => x.IdEspecialista == especialista);
                    filtros.Add("Especialista: " + (esp != null ? esp.Especialista : especialista.ToString(CultureInfo.InvariantCulture)));
                }
                if (forma > 0)
                {
                    var fp = ReportesDetalleRepository.FormasPago().FirstOrDefault(x => x.Id == forma);
                    filtros.Add("Forma de pago: " + (fp != null ? fp.Texto : forma.ToString("00", CultureInfo.InvariantCulture)));
                }
                if (filtro.Paciente.Length > 0) filtros.Add("Paciente: " + filtro.Paciente);

                byte[] pdf = CajaEspecialistasPdf.Generar(r, empresa, logo, nombreSucursal, string.Join(" · ", filtros), Sesion.Usuario, especialista);
                string archivo = "caja_por_especialista_" + desde.ToString("yyyyMMdd") + (hasta > desde ? "_" + hasta.ToString("yyyyMMdd") : "") + ".pdf";
                context.Response.ContentType = "application/pdf";
                context.Response.AddHeader("Content-Disposition", "inline; filename=\"" + archivo + "\"");
                context.Response.Cache.SetCacheability(HttpCacheability.NoCache);
                context.Response.BinaryWrite(pdf);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Trace.TraceError("Caja por especialista PDF: " + ex);
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
