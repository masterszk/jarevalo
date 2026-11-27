using System;
using System.Collections.Generic;
using System.Web;
using System.Web.SessionState;

namespace DPieCenter.Seguridad
{
    /// <summary>
    /// Exige un usuario con sesión iniciada para todo el sitio, salvo las páginas públicas.
    /// Antes cada página y cada WebMethod debía validar la sesión por su cuenta y muchas no lo hacían
    /// (se podía buscar pacientes o ver citas sin entrar al sistema).
    ///
    /// Protege: páginas .aspx, sus WebMethods (/pagina.aspx/Metodo), manejadores .ashx / .asmx y /api/*.
    /// No toca los archivos estáticos (assets: css, js, imágenes, videos) ni los recursos .axd.
    /// Registrado en Web.config (system.webServer/modules).
    /// </summary>
    public class AccesoModule : IHttpModule
    {
        // Rutas públicas (sin sesión), relativas a la aplicación y en minúsculas
        private static readonly HashSet<string> Publicas = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            "~/login.aspx",                          // inicio de sesión y sus WebMethods
            "~/resetpass.aspx",                      // cambio de clave obligatorio: valida su propio permiso (Session["dpcambioclave"])
            "~/recuperarclave.aspx",                // recuperar la contraseña con código por correo
            "~/registros/frm_turnospacientes.aspx",  // pantalla de turnos del televisor (solo primer nombre, apellido y hora)
        };

        private static readonly string[] Protegidas = { ".aspx", ".ashx", ".asmx", ".svc" };

        public void Init(HttpApplication app)
        {
            app.PostMapRequestHandler += AsegurarSesion;
            app.AcquireRequestState += Validar;
        }

        public void Dispose() { }

        private static bool EsProtegida(HttpContext ctx)
        {
            string ruta = ctx.Request.AppRelativeCurrentExecutionFilePath ?? "";
            if (Publicas.Contains(ruta)) return false;
            if (ruta.StartsWith("~/api/", StringComparison.OrdinalIgnoreCase) || string.Equals(ruta, "~/api", StringComparison.OrdinalIgnoreCase)) return true;
            if (ruta == "~/" || ruta == "~") return true;                     // documento por defecto
            foreach (var ext in Protegidas)
                if (ruta.EndsWith(ext, StringComparison.OrdinalIgnoreCase)) return true;
            return false;
        }

        // Manejadores que no piden sesión (.ashx sin IRequiresSessionState, WebMethods sin EnableSession):
        // se les da sesión de solo lectura para poder validarla. No se cambia a los que ya la usan.
        private static void AsegurarSesion(object sender, EventArgs e)
        {
            var ctx = ((HttpApplication)sender).Context;
            if (!EsProtegida(ctx)) return;
            if (!(ctx.Handler is IRequiresSessionState) && !(ctx.Handler is IReadOnlySessionState))
                ctx.SetSessionStateBehavior(SessionStateBehavior.ReadOnly);
        }

        // AcquireRequestState: la sesión ya está cargada y todavía no se ejecuta la página ni el WebMethod
        private static void Validar(object sender, EventArgs e)
        {
            var app = (HttpApplication)sender;
            var ctx = app.Context;
            if (!EsProtegida(ctx) || Sesion.Activa) return;

            var rq = ctx.Request;
            bool ajax = !string.IsNullOrEmpty(rq.PathInfo)                                                     // WebMethod
                        || string.Equals(rq.Headers["X-Requested-With"], "XMLHttpRequest", StringComparison.OrdinalIgnoreCase)
                        || (rq.ContentType ?? "").IndexOf("json", StringComparison.OrdinalIgnoreCase) >= 0
                        || !string.Equals(rq.HttpMethod, "GET", StringComparison.OrdinalIgnoreCase)
                        || rq.AppRelativeCurrentExecutionFilePath.EndsWith(".ashx", StringComparison.OrdinalIgnoreCase);

            var rs = ctx.Response;
            rs.Clear();
            rs.Cache.SetCacheability(HttpCacheability.NoCache);
            if (ajax)
            {
                rs.StatusCode = 401;
                rs.ContentType = "application/json; charset=utf-8";
                rs.Write("{\"Message\":\"La sesión expiró o no ha iniciado sesión. Vuelva a iniciar sesión.\",\"Sesion\":false}");
            }
            else
            {
                rs.Redirect(VirtualPathUtility.ToAbsolute("~/login.aspx"), false);
            }
            app.CompleteRequest();
        }
    }
}
