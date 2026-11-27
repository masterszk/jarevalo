using System;
using System.Collections.Generic;
using System.Web.Services;

namespace DPieCenter.Opciones
{
    /// <summary>Módulos del menú y sus opciones (assets/js/conf-modulos.js). Antes las opciones estaban en form_confOpciones.aspx.</summary>
    public partial class form_confModulos : System.Web.UI.Page
    {
        internal const string Url = "Opciones/form_confModulos.aspx?app=2";

        protected void Page_Load(object sender, EventArgs e)
        {

        }

        [WebMethod(EnableSession = true)]
        public static ListaDto<ModuloDto> Modulos()
        {
            return AdministracionWeb.Lista(Url, AdministracionRepository.Modulos, "No fue posible cargar los módulos.");
        }

        [WebMethod(EnableSession = true)]
        public static RespuestaDto GuardarModulo(ModuloDto modulo)
        {
            if (modulo == null) return new RespuestaDto { Ok = false, Mensaje = "No se recibieron los datos." };
            return AdministracionWeb.Accion(Url, () => AdministracionRepository.GuardarModulo(modulo),
                modulo.Id > 0 ? "Módulo actualizado." : "Módulo agregado.", "No fue posible guardar el módulo.");
        }

        [WebMethod(EnableSession = true)]
        public static RespuestaDto EliminarModulo(long id)
        {
            return AdministracionWeb.Accion(Url, () => AdministracionRepository.EliminarModulo(id), "Módulo eliminado.", "No fue posible eliminar el módulo.");
        }

        [WebMethod(EnableSession = true)]
        public static ListaDto<OpcionMenuDto> Opciones(long modulo)
        {
            return AdministracionWeb.Lista(Url, () => AdministracionRepository.Opciones(modulo), "No fue posible cargar las opciones.");
        }

        [WebMethod(EnableSession = true)]
        public static RespuestaDto GuardarOpcion(OpcionMenuDto opcion)
        {
            if (opcion == null) return new RespuestaDto { Ok = false, Mensaje = "No se recibieron los datos." };
            return AdministracionWeb.Accion(Url, () => AdministracionRepository.GuardarOpcion(opcion),
                opcion.Id > 0 ? "Opción actualizada." : "Opción agregada.", "No fue posible guardar la opción.");
        }

        [WebMethod(EnableSession = true)]
        public static RespuestaDto EliminarOpcion(long id)
        {
            return AdministracionWeb.Accion(Url, () => AdministracionRepository.EliminarOpcion(id), "Opción eliminada.", "No fue posible eliminar la opción.");
        }
    }
}
