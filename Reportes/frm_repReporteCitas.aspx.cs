using System;
using System.Web.Services;

namespace DPieCenter.Reportes
{
    /// <summary>Reporte de citas (assets/js/reporte-citas.js).</summary>
    public partial class frm_repReporteCitas : System.Web.UI.Page
    {
        private const string Url = "Reportes/frm_repReporteCitas.aspx";

        protected void Page_Load(object sender, EventArgs e)
        {

        }

        [WebMethod(EnableSession = true)]
        public static CatalogosReporteDto Catalogos()
        {
            string permiso = ReportesWeb.Permiso(Url);
            if (permiso != null) return new CatalogosReporteDto { Ok = false, Mensaje = permiso };
            try { return ReportesDetalleRepository.Catalogos(); }
            catch (Exception ex) { return new CatalogosReporteDto { Ok = false, Mensaje = ReportesWeb.Detalle(ex, "No fue posible cargar los filtros.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static ReporteCitasDto Consultar(FiltroReporteDto filtro)
        {
            DateTime desde, hasta;
            string error = ReportesWeb.Validar(Url, filtro, out desde, out hasta);
            if (error != null) return new ReporteCitasDto { Ok = false, Mensaje = error };
            try { return ReportesDetalleRepository.Citas(filtro, desde, hasta); }
            catch (Exception ex) { return new ReporteCitasDto { Ok = false, Mensaje = ReportesWeb.Detalle(ex, "No fue posible generar el reporte de citas.") }; }
        }
    }
}
