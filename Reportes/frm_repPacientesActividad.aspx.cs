using System;
using System.Web.Services;

namespace DPieCenter.Reportes
{
    /// <summary>Reporte de pacientes por procedimientos y citas, de mayor a menor (assets/js/reporte-pacientes-actividad.js).</summary>
    public partial class frm_repPacientesActividad : System.Web.UI.Page
    {
        private const string Url = "Reportes/frm_repPacientesActividad.aspx";

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
        public static ReportePacientesActividadDto Consultar(FiltroReporteDto filtro)
        {
            DateTime desde, hasta;
            string error = ReportesWeb.Validar(Url, filtro, out desde, out hasta);
            if (error != null) return new ReportePacientesActividadDto { Ok = false, Mensaje = error };
            try { return ReportesDetalleRepository.PacientesActividad(filtro, desde, hasta); }
            catch (Exception ex) { return new ReportePacientesActividadDto { Ok = false, Mensaje = ReportesWeb.Detalle(ex, "No fue posible generar el reporte de pacientes.") }; }
        }
    }
}
