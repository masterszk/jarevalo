using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Web;
using System.Web.Services;

namespace DPieCenter.Opciones
{
    /// <summary>Dashboards de inicio que se asignan a los usuarios (assets/js/conf-dashboards.js).</summary>
    public partial class form_confDashboardInicial : System.Web.UI.Page
    {
        private const string Url = "Opciones/form_confDashboardInicial.aspx";

        protected void Page_Load(object sender, EventArgs e)
        {

        }

        public class DashboardsDto
        {
            public bool Ok { get; set; }
            public string Mensaje { get; set; }
            public List<DashboardConfDto> Items { get; set; }
            /// <summary>Webforms que existen en la carpeta Dashboard, para elegir la página.</summary>
            public List<string> Paginas { get; set; }
        }

        [WebMethod(EnableSession = true)]
        public static DashboardsDto Lista()
        {
            string permiso = AdministracionWeb.Permiso(Url);
            if (permiso != null) return new DashboardsDto { Ok = false, Mensaje = permiso };
            try
            {
                var paginas = new List<string>();
                string carpeta = HttpContext.Current.Server.MapPath("~/Dashboard");
                if (Directory.Exists(carpeta))
                    paginas = Directory.GetFiles(carpeta, "*.aspx").Select(f => "Dashboard/" + Path.GetFileName(f)).OrderBy(f => f).ToList();
                return new DashboardsDto { Ok = true, Items = AdministracionRepository.Dashboards(), Paginas = paginas };
            }
            catch (Exception ex) { return new DashboardsDto { Ok = false, Mensaje = AdministracionWeb.Detalle(ex, "No fue posible cargar los dashboards.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static RespuestaDto Guardar(DashboardConfDto dashboard)
        {
            if (dashboard == null) return new RespuestaDto { Ok = false, Mensaje = "No se recibieron los datos." };
            return AdministracionWeb.Accion(Url, () => AdministracionRepository.GuardarDashboard(dashboard),
                dashboard.Id > 0 ? "Dashboard actualizado." : "Dashboard agregado.", "No fue posible guardar el dashboard.");
        }

        [WebMethod(EnableSession = true)]
        public static RespuestaDto Eliminar(long id)
        {
            return AdministracionWeb.Accion(Url, () => AdministracionRepository.EliminarDashboard(id), "Dashboard eliminado.", "No fue posible eliminar el dashboard.");
        }
    }
}
