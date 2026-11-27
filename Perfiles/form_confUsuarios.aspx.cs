using System;
using System.Collections.Generic;
using System.Web.Services;
using DPieCenter.Opciones;

namespace DPieCenter.Perfiles
{
    /// <summary>
    /// Usuarios del sistema (assets/js/conf-usuarios.js): lista, alta y edición en un modal, activar / inactivar,
    /// restablecer la clave y eliminar. Reemplaza a form_confNuevoUsuario.aspx y form_confUsuarioPerfilEdit.aspx.
    /// La clave nunca viaja al navegador.
    /// </summary>
    public partial class form_confUsuarios : System.Web.UI.Page
    {
        private const string Url = "Perfiles/form_confUsuarios.aspx";

        protected void Page_Load(object sender, EventArgs e)
        {

        }

        public class InicioUsuariosDto
        {
            public bool Ok { get; set; }
            public string Mensaje { get; set; }
            public string UsuarioSesion { get; set; }
            public List<UsuarioConfDto> Usuarios { get; set; }
            public List<GrupoDto> Grupos { get; set; }
            public List<DashboardConfDto> Dashboards { get; set; }
            public List<CatalogoItemDto> Sucursales { get; set; }
            /// <summary>Usuarios con intentos fallidos de inicio de sesión en los últimos 15 minutos.</summary>
            public List<LoginIntentos.EstadoBloqueo> Bloqueos { get; set; }
        }

        [WebMethod(EnableSession = true)]
        public static InicioUsuariosDto Inicio()
        {
            string permiso = AdministracionWeb.Permiso(Url);
            if (permiso != null) return new InicioUsuariosDto { Ok = false, Mensaje = permiso };
            try
            {
                return new InicioUsuariosDto
                {
                    Ok = true,
                    UsuarioSesion = Sesion.Usuario,
                    Usuarios = AdministracionRepository.Usuarios(),
                    Grupos = AdministracionRepository.Grupos(),
                    Dashboards = AdministracionRepository.Dashboards(),
                    Sucursales = SucursalesRepository.Activas(),
                    Bloqueos = LoginIntentos.Usuarios()
                };
            }
            catch (Exception ex) { return new InicioUsuariosDto { Ok = false, Mensaje = AdministracionWeb.Detalle(ex, "No fue posible cargar los usuarios.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static RespuestaDto Guardar(UsuarioConfDto usuario, bool nuevo)
        {
            if (usuario == null) return new RespuestaDto { Ok = false, Mensaje = "No se recibieron los datos." };
            string temporal = Utils.GenerarClaveTemporal();
            return AdministracionWeb.Accion(Url, () => AdministracionRepository.GuardarUsuario(usuario, nuevo, temporal),
                nuevo ? "Usuario creado. Su clave temporal es: " + temporal + " (anótela y entréguela al usuario; la cambiará al entrar)." : "Usuario actualizado.",
                "No fue posible guardar el usuario.");
        }

        [WebMethod(EnableSession = true)]
        public static RespuestaDto Estado(string usuario, bool activo)
        {
            return AdministracionWeb.Accion(Url, () => AdministracionRepository.EstadoUsuario(usuario, activo),
                activo ? "Usuario activado." : "Usuario inactivado.", "No fue posible cambiar el estado.");
        }

        [WebMethod(EnableSession = true)]
        public static RespuestaDto RestablecerClave(string usuario)
        {
            string temporal = Utils.GenerarClaveTemporal();
            return AdministracionWeb.Accion(Url, () => { long r = AdministracionRepository.RestablecerClave(usuario, temporal); LoginIntentos.Desbloquear(usuario); return r; },
                "Clave restablecida. La clave temporal es: " + temporal + " (anótela y entréguela al usuario; la cambiará al entrar).", "No fue posible restablecer la clave.");
        }

        /// <summary>Quita el bloqueo por intentos fallidos de inicio de sesión (no cambia la clave).</summary>
        [WebMethod(EnableSession = true)]
        public static RespuestaDto Desbloquear(string usuario)
        {
            return AdministracionWeb.Accion(Url, () => { LoginIntentos.Desbloquear(usuario); return 0L; },
                "Usuario " + usuario + " desbloqueado. Ya puede intentar iniciar sesión de nuevo.", "No fue posible desbloquear el usuario.");
        }

        [WebMethod(EnableSession = true)]
        public static RespuestaDto Eliminar(string usuario)
        {
            return AdministracionWeb.Accion(Url, () => AdministracionRepository.EliminarUsuario(usuario), "Usuario eliminado.", "No fue posible eliminar el usuario.");
        }
    }
}
