using System;
using System.Web.Services;

namespace DPieCenter.Reportes
{
    /// <summary>Reporte de Garantía de Servicios con filtros (assets/js/reporte-garantias.js).</summary>
    public partial class frm_repGarantias : System.Web.UI.Page
    {
        private const string Url = "Reportes/frm_repGarantias.aspx";

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

        /// <summary>filtro.Estado: 0 todas | 1 no vistas | 2 vistas por el especialista.</summary>
        [WebMethod(EnableSession = true)]
        public static ReporteGarantiasDto Consultar(FiltroReporteDto filtro)
        {
            DateTime desde, hasta;
            string error = ReportesWeb.Validar(Url, filtro, out desde, out hasta);
            if (error != null) return new ReporteGarantiasDto { Ok = false, Mensaje = error };
            try { return ReportesDetalleRepository.Garantias(filtro, desde, hasta); }
            catch (Exception ex) { return new ReporteGarantiasDto { Ok = false, Mensaje = ReportesWeb.Detalle(ex, "No fue posible generar el reporte de garantías.") }; }
        }
    }
}
