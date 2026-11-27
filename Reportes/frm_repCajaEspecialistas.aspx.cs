using System;
using System.Web.Services;

namespace DPieCenter.Reportes
{
    /// <summary>Reporte de caja por especialista con filtros (assets/js/reporte-caja-especialistas.js).</summary>
    public partial class frm_repCajaEspecialistas : System.Web.UI.Page
    {
        private const string Url = "Reportes/frm_repCajaEspecialistas.aspx";

        protected void Page_Load(object sender, EventArgs e)
        {

        }

        [WebMethod(EnableSession = true)]
        public static CatalogosReporteDto Catalogos()
        {
            string permiso = ReportesWeb.Permiso(Url);
            if (permiso != null) return new CatalogosReporteDto { Ok = false, Mensaje = permiso };
            try
            {
                var c = ReportesDetalleRepository.Catalogos();
                c.FormasPago = ReportesDetalleRepository.FormasPago();
                return c;
            }
            catch (Exception ex) { return new CatalogosReporteDto { Ok = false, Mensaje = ReportesWeb.Detalle(ex, "No fue posible cargar los filtros.") }; }
        }

        /// <summary>filtro.FormaPago: código CAT-017 como número (1 = '01'); 0 = todas.</summary>
        [WebMethod(EnableSession = true)]
        public static ReporteCajaEspecialistasDto Consultar(FiltroReporteDto filtro)
        {
            DateTime desde, hasta;
            string error = ReportesWeb.Validar(Url, filtro, out desde, out hasta);
            if (error != null) return new ReporteCajaEspecialistasDto { Ok = false, Mensaje = error };
            try { return ReportesDetalleRepository.CajaEspecialistas(filtro, desde, hasta); }
            catch (Exception ex) { return new ReporteCajaEspecialistasDto { Ok = false, Mensaje = ReportesWeb.Detalle(ex, "No fue posible generar el reporte de caja por especialista.") }; }
        }

        /// <summary>Libro de Excel (.xlsx) con las tablas que se ven en pantalla (todo el reporte o un cuadro), en base64.</summary>
        [WebMethod(EnableSession = true)]
        public static ArchivoExcelDto Excel(LibroExcelDto libro)
        {
            return ReportesWeb.Excel(Url, libro);
        }
    }
}
