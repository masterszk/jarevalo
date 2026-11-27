using System;
using System.Web.Services;
using DPieCenter.Opciones;

namespace DPieCenter.Perfiles
{
    /// <summary>Grupos de usuarios (assets/js/conf-grupos.js).</summary>
    public partial class form_confGrupos : System.Web.UI.Page
    {
        private const string Url = "Perfiles/form_confGrupos.aspx";

        protected void Page_Load(object sender, EventArgs e)
        {

        }

        [WebMethod(EnableSession = true)]
        public static ListaDto<GrupoDto> Grupos()
        {
            return AdministracionWeb.Lista(Url, AdministracionRepository.Grupos, "No fue posible cargar los grupos.");
        }

        [WebMethod(EnableSession = true)]
        public static RespuestaDto Guardar(GrupoDto grupo, bool nuevo)
        {
            if (grupo == null) return new RespuestaDto { Ok = false, Mensaje = "No se recibieron los datos." };
            return AdministracionWeb.Accion(Url, () => AdministracionRepository.GuardarGrupo(grupo, nuevo),
                nuevo ? "Grupo agregado." : "Grupo actualizado.", "No fue posible guardar el grupo.");
        }

        [WebMethod(EnableSession = true)]
        public static RespuestaDto Eliminar(string grupo)
        {
            return AdministracionWeb.Accion(Url, () => AdministracionRepository.EliminarGrupo(grupo), "Grupo eliminado.", "No fue posible eliminar el grupo.");
        }
    }
}
