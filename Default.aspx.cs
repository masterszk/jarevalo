using System;
using System.Data;
using System.Web;
using System.Web.Services;

namespace DPieCenter
{
    /// <summary>
    /// Página principal (menú y contenedor de las páginas que se cargan con AjaxLink).
    /// Los datos del usuario se leen de SU sesión (helper Sesion). Antes se guardaban en campos estáticos,
    /// compartidos por todos los usuarios conectados, y mtd_SessionUser borraba Session["dpsesion"].
    /// </summary>
    public partial class _default : System.Web.UI.Page
    {
        protected string UsuarioActual { get; private set; }
        /// <summary>Dashboard asignado al usuario: se abre al entrar y con los botones de inicio.</summary>
        protected string DashboardUsuario { get; private set; }

        protected void Page_Load(object sender, EventArgs e)
        {
            if (!Sesion.Activa)
            {
                Response.Redirect("login.aspx", false);
                Context.ApplicationInstance.CompleteRequest();
                return;
            }

            UsuarioActual = Sesion.Usuario;
            DashboardUsuario = DashboardDelUsuario(UsuarioActual);
            CargarSucursales();
            using (SqlProcess obj_sqlProccess = new SqlProcess())
            {
                obj_sqlProccess.mtdSys_SesionesUsuarios(UsuarioActual, "D", 0, 1);
            }
        }

        // ===== Sucursal de trabajo (barra superior) =====
        protected string SucursalActual { get; private set; }
        protected bool PuedeCambiarSucursal { get; private set; }
        protected string OpcionesSucursal { get; private set; }

        private void CargarSucursales()
        {
            SucursalActual = Sesion.SucursalNombre;
            PuedeCambiarSucursal = Sesion.EsAdministrador;
            if (!PuedeCambiarSucursal) return;
            var sb = new System.Text.StringBuilder();
            foreach (var s in Opciones.SucursalesRepository.Activas())
                sb.Append("<option value=\"").Append(s.Id).Append('"').Append(s.Id == Sesion.Sucursal ? " selected" : "").Append('>')
                  .Append(HttpUtility.HtmlEncode(s.Texto)).Append("</option>");
            OpcionesSucursal = sb.ToString();
        }

        /// <summary>Solo administradores: cambia la sucursal en la que trabaja durante la sesión.</summary>
        [WebMethod(EnableSession = true)]
        public static Opciones.RespuestaDto CambiarSucursal(int sucursal)
        {
            if (!Sesion.Activa) return new Opciones.RespuestaDto { Ok = false, Mensaje = "La sesión expiró." };
            if (!Sesion.EsAdministrador) return new Opciones.RespuestaDto { Ok = false, Mensaje = "Su usuario trabaja en una sucursal fija." };
            return Sesion.CambiarSucursal(sucursal)
                ? new Opciones.RespuestaDto { Ok = true, Id = sucursal, Mensaje = "Ahora trabaja en " + Sesion.SucursalNombre + "." }
                : new Opciones.RespuestaDto { Ok = false, Mensaje = "La sucursal no existe o está inactiva." };
        }

        public class UsuarioSesionDto
        {
            public bool Ok { get; set; }
            public string Usuario { get; set; }
            public string Nombre { get; set; }
            public string Grupo { get; set; }
            public string Foto { get; set; }
            public string Email { get; set; }
        }

        [WebMethod(EnableSession = true)]
        public static UsuarioSesionDto mtd_SessionUser()
        {
            if (!Sesion.Activa) return new UsuarioSesionDto { Ok = false };

            var d = new UsuarioSesionDto { Ok = true, Usuario = Sesion.Usuario, Grupo = Sesion.Grupo, Nombre = Sesion.Usuario, Foto = Sesion.Foto };
            try
            {
                using (SqlProcess sql = new SqlProcess())
                {
                    if (sql.mtdSys_Usuario(d.Usuario, "", "", "", "", "", 0, "", "", "", "", 0, "", false, 13) == "OK" && sql.dtReturn.Rows.Count > 0)
                    {
                        DataRow r = sql.dtReturn.Rows[0];
                        string nombre = (r["Nombres"] + " " + r["Apellidos"]).Trim();
                        if (nombre.Length > 0) d.Nombre = nombre;
                        d.Email = Convert.ToString(r["Email"]);
                    }
                }
            }
            catch (Exception ex) { System.Diagnostics.Trace.TraceError("mtd_SessionUser: " + ex); }

            // Fotos de perfil sin configurar o con rutas de la plantilla anterior
            if (string.IsNullOrWhiteSpace(d.Foto) || d.Foto.StartsWith("../")) d.Foto = "assets/images/user1.png";
            return d;
        }

        // ===== Campana: garantías de servicios no vistas =====

        /// <summary>Especialista: sus garantías no vistas. Administrador: las no vistas de todos los especialistas.</summary>
        [WebMethod(EnableSession = true)]
        public static Registros.GarantiasAvisoRespuestaDto GarantiasPendientes()
        {
            if (!Sesion.Activa) return new Registros.GarantiasAvisoRespuestaDto { Ok = false, Mensaje = "La sesión expiró." };
            try { return Registros.GarantiasAvisos.ParaUsuario(Sesion.Usuario, Sesion.EsAdministrador); }
            catch (Exception ex)
            {
                System.Diagnostics.Trace.TraceError("GarantiasPendientes: " + ex);
                return new Registros.GarantiasAvisoRespuestaDto { Ok = false, Mensaje = "No fue posible consultar las garantías." };
            }
        }

        /// <summary>Solo el especialista marca como vistas sus garantías (id = 0: todas las suyas). El especialista sale de la sesión.</summary>
        [WebMethod(EnableSession = true)]
        public static Opciones.RespuestaDto MarcarGarantiasVistas(long id)
        {
            if (!Sesion.Activa) return new Opciones.RespuestaDto { Ok = false, Mensaje = "La sesión expiró." };
            try
            {
                var esp = Registros.ProcedimientosRepository.EspecialistaDeUsuario(Sesion.Usuario);
                if (esp == null) return new Opciones.RespuestaDto { Ok = false, Mensaje = "Solo el especialista marca sus garantías como vistas." };
                int n = Registros.GarantiasAvisos.MarcarVistas(esp.Id, Math.Max(0, id), Sesion.Usuario);
                return new Opciones.RespuestaDto { Ok = true, Id = n, Mensaje = n + " marcada(s) como vista(s)." };
            }
            catch (Exception ex)
            {
                System.Diagnostics.Trace.TraceError("MarcarGarantiasVistas: " + ex);
                return new Opciones.RespuestaDto { Ok = false, Mensaje = "No fue posible marcar las garantías." };
            }
        }

        /// <summary>OK si la sesión sigue activa y es del mismo usuario que tiene abierta la página.</summary>
        [WebMethod(EnableSession = true)]
        public static string mtd_ValidateSession(string user)
        {
            if (!Sesion.Activa) return "ERROR||login.aspx";
            if (!string.IsNullOrWhiteSpace(user) && !string.Equals(user.Trim(), Sesion.Usuario, StringComparison.OrdinalIgnoreCase))
                return "ERROR||default.aspx";      // en otra pestaña se inició sesión con otro usuario
            return "OK||0";
        }

        [WebMethod]
        public static string leeModulos(string usuario, string aplicativo)
        {
            string respuestaSql = "", mensajeRespuesta = "";
            try
            {
                using (SqlProcess obj_sqlProccess = new SqlProcess())
                {
                    long IdAplicativo = Convert.ToInt64(decodeId(aplicativo));
                    respuestaSql = obj_sqlProccess.mtdSys_AccesoModulos(usuario, IdAplicativo);
                    if (respuestaSql == "OK")
                    {
                        foreach (DataRow Reg in obj_sqlProccess.dtReturn.Rows)
                        {
                            mensajeRespuesta += "<li class=\"menu-modulo\">";
                            mensajeRespuesta += "<a href=\"javascript:;\" class=\"has-arrow\">";
                            mensajeRespuesta += "<div class=\"parent-icon\"><i class=\"" + HttpUtility.HtmlAttributeEncode(Reg[2].ToString()) + "\"></i></div>";
                            mensajeRespuesta += "<div class=\"menu-title\">" + HttpUtility.HtmlEncode(Reg[1].ToString()) + "</div>";
                            mensajeRespuesta += "</a>";
                            mensajeRespuesta += "<ul>";
                            mensajeRespuesta += leeOpciones(usuario, Reg[0].ToString(), Reg[1].ToString());
                            mensajeRespuesta += "</ul>";
                            mensajeRespuesta += "</li>";
                        }
                    }
                    else
                        mensajeRespuesta = "<li class=\"text-muted small px-3\">No fue posible cargar el menú.</li>";
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Trace.TraceError("leeModulos: " + ex);
                mensajeRespuesta = "<li class=\"text-muted small px-3\">No fue posible cargar el menú.</li>";
            }
            return mensajeRespuesta;
        }

        // Cada opción lleva data-url y data-titulo para marcar la opción activa y titular la página
        private static string leeOpciones(string usuario, string modulo, string nombreModulo)
        {
            string respuestaSql = "", mensajeRespuesta = "";
            try
            {
                using (SqlProcess obj_sqlProccess = new SqlProcess())
                {
                    respuestaSql = obj_sqlProccess.mtdSys_AccesoOpciones(usuario, Convert.ToInt32(modulo));
                    if (respuestaSql == "OK")
                    {
                        foreach (DataRow Reg in obj_sqlProccess.dtReturn.Rows)
                        {
                            string url = HttpUtility.HtmlAttributeEncode(Reg[3].ToString());
                            string texto = Reg[1].ToString();
                            mensajeRespuesta += "<li>";
                            mensajeRespuesta += "<a href=\"javascript:void(0)\" class=\"menu-opcion\" data-url=\"" + url + "\" data-titulo=\""
                                + HttpUtility.HtmlAttributeEncode(nombreModulo + " · " + texto) + "\">";
                            mensajeRespuesta += "<i class='bx bx-radio-circle'></i> " + HttpUtility.HtmlEncode(texto);
                            mensajeRespuesta += "</a>";
                            mensajeRespuesta += "</li>";
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Trace.TraceError("leeOpciones: " + ex);
            }
            return mensajeRespuesta;
        }

        private static string decodeId(string cadenaCodificada)
        {
            string id = "0";

            if (cadenaCodificada != null && cadenaCodificada.Contains("@"))
            {
                string[] arrayCadena = cadenaCodificada.Split('@');
                string[] arrayId = arrayCadena[1].Split('X');

                id = arrayId[0];
            }
            else
                id = "2";        // aplicativo de la clínica cuando se entra a default.aspx sin el parámetro url

            return id;
        }

        [WebMethod(EnableSession = true)]
        public static string mtd_UpdateAjaxLink(int idAjaxLink, string usuario, string url, int accion)
        {
            if (!Sesion.Activa) return "SESION||login.aspx";
            try
            {
                using (SqlProcess obj_sqlProccess = new SqlProcess())
                {
                    string respuestaSql = obj_sqlProccess.mtdSys_AjaxLink(idAjaxLink, Sesion.Usuario, url, 1);
                    return respuestaSql == "OK" ? "OK||1" : "NO||" + respuestaSql.Replace("\r", "").Replace("\n", "").Replace("'", "");
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Trace.TraceError("mtd_UpdateAjaxLink: " + ex);
                return "NO||No fue posible registrar la página.";
            }
        }

        /// <summary>
        /// Con accion 5: última página abierta por el usuario o, si no hay, el dashboard de su perfil.
        /// Con accion 25: siempre el dashboard de su perfil (es lo que se abre al entrar).
        /// </summary>
        [WebMethod(EnableSession = true)]
        public static string mtd_leeDashboard(string user, int accion)
        {
            if (!Sesion.Activa) return DashboardPredeterminado;
            string usuario = Sesion.Usuario, url = "";
            try
            {
                if (accion != 25)
                    using (SqlProcess obj_sqlProccess = new SqlProcess())
                    {
                        if (obj_sqlProccess.mtdSys_AjaxLink(0, usuario, "", accion) == "OK")
                            foreach (DataRow Reg in obj_sqlProccess.dtReturn.Rows)
                                url = Reg[0].ToString();
                    }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Trace.TraceError("mtd_leeDashboard: " + ex);
            }
            return url.Length == 0 || url == "1" ? DashboardDelUsuario(usuario) : url;
        }

        const string DashboardPredeterminado = "Dashboard/form_DashboardGeneral.aspx";

        /// <summary>Dashboard asignado al usuario (Sys_Usuarios.Id_Dashboard_FK → Sys_DashboardInicial).</summary>
        static string DashboardDelUsuario(string usuario)
        {
            string url = DashboardPredeterminado, dashboard = "";
            try
            {
                using (SqlProcess obj_sqlProccess = new SqlProcess())
                {
                    if (obj_sqlProccess.mtdSys_Usuario(usuario, "", "", "", "", "", 0, "", "", "", "", 0, "", false, 13) == "OK")
                        foreach (DataRow Reg in obj_sqlProccess.dtReturn.Rows)
                            dashboard = Reg["Id_Dashboard_FK"].ToString();

                    long id;
                    if (long.TryParse(dashboard, out id) && obj_sqlProccess.mtdSys_DashboardInicial(id, "", "", "", "", 5) == "OK")
                        foreach (DataRow Reg in obj_sqlProccess.dtReturn.Rows)
                        {
                            string u = Reg["DashboardUrl"].ToString().Trim();
                            if (u.EndsWith(".aspx", StringComparison.OrdinalIgnoreCase)) url = u;   // hay registros con URL no válida
                        }
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Trace.TraceError("DashboardDelUsuario: " + ex);
            }
            return url;
        }
    }
}
