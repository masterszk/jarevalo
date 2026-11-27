using System;
using System.Web.Services;

namespace DPieCenter.Opciones
{
    /// <summary>
    /// Permisos de cada grupo sobre las opciones del menú (assets/js/conf-permisos.js).
    /// Lee y guarda directamente Sys_Permisos; antes usaba Sys_AccesosObjetos, que se borraba completa en cada consulta.
    /// </summary>
    public partial class form_confAccesosObjetos : System.Web.UI.Page
    {
        private const string Url = "Opciones/form_confAccesosObjetos.aspx";

        protected void Page_Load(object sender, EventArgs e)
        {

        }

        [WebMethod(EnableSession = true)]
        public static ListaDto<GrupoDto> Grupos()
        {
            return AdministracionWeb.Lista(Url, AdministracionRepository.Grupos, "No fue posible cargar los grupos.");
        }

        [WebMethod(EnableSession = true)]
        public static ListaDto<PermisoDto> Permisos(string grupo)
        {
            return AdministracionWeb.Lista(Url, () => AdministracionRepository.Permisos(grupo), "No fue posible cargar los permisos.");
        }

        /// <summary>modulo = true aplica el cambio a todas las opciones del módulo id.</summary>
        [WebMethod(EnableSession = true)]
        public static RespuestaDto Cambiar(string grupo, long id, bool modulo, bool valor)
        {
            return AdministracionWeb.Accion(Url, () => AdministracionRepository.CambiarPermiso(grupo, id, modulo, valor),
                valor ? "Permiso asignado." : "Permiso quitado.", "No fue posible cambiar el permiso.");
        }
    }
}
