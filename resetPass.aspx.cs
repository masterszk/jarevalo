using System;
using System.Collections;
using System.Web;
using System.Web.Services;

namespace DPieCenter
{
    /// <summary>
    /// Cambio obligatorio de contraseña: el login manda aquí cuando la clave es la inicial (igual al usuario) o está vencida.
    /// Respuestas de mtd_ChangePass: "OK||login.aspx" o "ERROR||mensaje" (antes los errores de validación llegaban sin
    /// "ERROR||" y la página redirigía a "undefined" sin avisar: el usuario creía haber cambiado la clave y no podía entrar).
    /// </summary>
    public partial class resetPass : System.Web.UI.Page
    {
        public const int MinimoCaracteres = 8;

        protected void Page_Load(object sender, EventArgs e)
        {
            // Página pública para el módulo de acceso: solo se abre con el permiso que deja el login
            if (Session["dpcambioclave"] as string == null) Response.Redirect("login.aspx", true);
        }

        [WebMethod(EnableSession = true)]
        public static string mtd_ChangePass(string newpass, string conpass, string accion)
        {
            newpass = newpass ?? "";
            conpass = conpass ?? "";

            // El login deja aquí solo el permiso de cambiar la clave (no una sesión completa del sistema)
            string user = HttpContext.Current.Session == null ? null : HttpContext.Current.Session["dpcambioclave"] as string;
            if (string.IsNullOrWhiteSpace(user))
                return "ERROR||Su sesión expiró. Vuelva a iniciar sesión con su usuario y la contraseña que le asignaron.";
            user = user.Trim();

            if (newpass.Length == 0) return "ERROR||Ingrese la contraseña nueva.";
            if (!newpass.Equals(conpass)) return "ERROR||La confirmación no coincide con la contraseña nueva. Escríbalas de nuevo.";
            if (newpass.Length < MinimoCaracteres) return "ERROR||La contraseña debe tener al menos " + MinimoCaracteres + " caracteres.";
            if (newpass.Trim() != newpass) return "ERROR||La contraseña no puede empezar ni terminar con espacios.";
            if (newpass.Equals(user, StringComparison.OrdinalIgnoreCase)) return "ERROR||La contraseña nueva no puede ser igual a su usuario.";

            try
            {
                using (SqlProcess sqlProccess = new SqlProcess())
                {
                    string respuestaSql = sqlProccess.mtdSys_ChangePass(user, Utils.HashClave(newpass), "1");
                    if (respuestaSql == "OK")
                    {
                        HttpContext.Current.Session.Remove("dpcambioclave");
                        HttpContext.Current.Session.Abandon();     // se vuelve a entrar con la clave nueva
                        return "OK||login.aspx";
                    }
                    System.Diagnostics.Trace.TraceError("Cambio de clave (" + user + "): " + respuestaSql);
                    return "ERROR||No fue posible guardar la contraseña. Intente de nuevo.";
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Trace.TraceError("Cambio de clave (" + user + "): " + ex);
                return "ERROR||No fue posible guardar la contraseña. Intente de nuevo; si el problema sigue, avise al administrador.";
            }
        }
    }
}
