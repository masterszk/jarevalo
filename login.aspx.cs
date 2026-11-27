using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using System.Data;
using System.Web.SessionState;
using System.Collections;
using System.Web.Services;
using System.Security.Cryptography;
using System.Text;

namespace DPieCenter
{
    public partial class login : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            cerrarSesion();
        }

        private void cerrarSesion()
        {
            //Eliminar una sola
            HttpContext.Current.Session.Remove("dpsesion");
            HttpContext.Current.Session["dpsesion"] = null;
            Sesion.LimpiarCache();

        }

        [WebMethod]
        public static string mtd_leeEmpresa(long accion)
        {
            long emp = 0;
            string respuestaSql = "", mensajeRespuesta = "", lppagina = "", lcliente = "", logotitulopagina = "", tpagina = "", nsistema = "", cbtitulo = "", titubienvenida = "", mensajebienvenida = "";
            try
            {
                using (SqlProcess obj_sqlProccess = new SqlProcess())
                {
                    respuestaSql = obj_sqlProccess.mtdSys_InformacionEmpresa("", 0, "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", true, true, true, true, true, true, true, 10);
                    foreach (DataRow Reg1 in obj_sqlProccess.dtReturn.Rows)
                    {
                        if (Convert.ToInt32(Reg1[0]) == 0)
                        {

                            mensajeRespuesta = "";
                            lppagina = "";
                            lcliente = "";
                            logotitulopagina = "";
                            tpagina = "";
                            nsistema = "";
                            cbtitulo = "";
                            titubienvenida = "";
                            mensajebienvenida = "";
                        }

                        else
                        {
                            emp = Convert.ToInt32(Reg1[0]);
                            respuestaSql = obj_sqlProccess.mtdSys_InformacionEmpresa("", emp, "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", true, true, true, true, true, true, true, accion);
                            if (respuestaSql == "OK")
                            {
                                foreach (DataRow Reg in obj_sqlProccess.dtReturn.Rows)
                                {
                                    mensajeRespuesta = Reg["ImagenFonoLogin"].ToString();
                                    lppagina = Reg["LogoEmpresa"].ToString();
                                    lcliente = Reg["LogoCliente"].ToString();
                                    logotitulopagina = Reg["LogoTituloPagina"].ToString();
                                    tpagina = Reg["TituloPagina"].ToString();
                                    nsistema = Reg["NombreSistema"].ToString();
                                    //cbtitulo = Reg["ColorBarraTituloMenu"].ToString();
                                    titubienvenida = Reg["TituloBienvenida"].ToString();
                                    mensajebienvenida = Reg["MensajeBienvenida"].ToString();
                                }

                            }
                            else
                            {
                                mensajeRespuesta = respuestaSql;
                                mensajeRespuesta = mensajeRespuesta.Replace("\r", "");
                                mensajeRespuesta = mensajeRespuesta.Replace("\n", "");
                                mensajeRespuesta = mensajeRespuesta.Replace("'", "");
                                mensajeRespuesta = "N&&" + mensajeRespuesta;
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                mensajeRespuesta = "Se ha producido un error, si el problema persiste, por favor comunicarse \ncon el administrador del sistema:  " + ex.Message;
            }

            return mensajeRespuesta + "||" + lppagina + "||" + lcliente + "||" + logotitulopagina + "||" + tpagina + "||" + nsistema + "||" + cbtitulo + "||" + titubienvenida + "||" + mensajebienvenida;

        }

        /// <summary>
        /// Respuestas: D&amp;&amp;url (entra) | R&amp;&amp;url (debe cambiar la clave) | C&amp;&amp;n (usuario o clave incorrectos; n = intentos restantes)
        /// | B&amp;&amp;m (bloqueado m minutos) | I&amp;&amp; (usuario inactivo) | E&amp;&amp;mensaje (error del sistema).
        /// No se distingue "usuario no existe" de "clave incorrecta" para no revelar qué usuarios existen.
        /// </summary>
        [WebMethod(EnableSession = true)]
        public static string registraUsuario(string usuario, string clave, string empresa)
        {
            usuario = (usuario ?? "").Trim();
            clave = clave ?? "";
            string ip = HttpContext.Current.Request.UserHostAddress;
            if (usuario.Length == 0 || clave.Length == 0 || usuario.Length > 20) return "C&&" + LoginIntentos.MaxIntentos;

            int bloqueo = LoginIntentos.MinutosBloqueo(usuario, ip);
            if (bloqueo > 0) return "B&&" + bloqueo;

            try
            {
                string claveDB = "", estatus = "", grupo = "", fotoPerfil = "";
                int caducidad = 0;
                string usuarioCodificado = Utils.EncodeString(usuario);

                using (SqlProcess sqlProccess = new SqlProcess())
                {
                    string mensaje = sqlProccess.mtdSys_Usuario(usuario, "", clave, "", "", "", 0, "", "", "", "", 0, "", false, 12);
                    bool existe = mensaje != "N&&" && sqlProccess.dtReturn != null && sqlProccess.dtReturn.Rows.Count > 0;
                    if (existe)
                    {
                        DataRow Reg = sqlProccess.dtReturn.Rows[0];
                        estatus = Reg[0].ToString();
                        claveDB = Reg[2].ToString();
                        int.TryParse(Reg[3].ToString(), out caducidad);
                        grupo = Reg[4].ToString();
                        fotoPerfil = Reg[5].ToString();
                    }

                    // La clave se verifica antes que todo lo demás (antes, con la clave vencida se entraba sin verificarla)
                    if (!existe || !Utils.VerificarClave(clave, claveDB))
                        return "C&&" + LoginIntentos.RegistrarFallo(usuario, ip);

                    if (estatus == "I")
                        return "I&&";

                    LoginIntentos.Limpiar(usuario, ip);

                    // Clave temporal (asignada por un administrador), clave inicial antigua (igual al usuario) o vencida:
                    // debe cambiarla antes de entrar. Mientras tanto NO se crea la sesión del sistema, solo un permiso
                    // para cambiar la clave, así no se puede usar el resto del sitio con una clave que otros conocen.
                    if (Utils.EsClaveTemporal(claveDB) || usuarioCodificado.Equals(claveDB, StringComparison.OrdinalIgnoreCase) || caducidad <= 0)
                    {
                        Sesion.LimpiarCache();
                        HttpContext.Current.Session["dpsesion"] = null;
                        HttpContext.Current.Session["dpcambioclave"] = usuario;
                        return "R&&resetPass.aspx";
                    }

                    creaSession(usuario, grupo, fotoPerfil);

                    sqlProccess.mtdSys_Usuario(usuario, "", "", "", "", "", 0, "", "", "", "", 0, "", false, 9);
                    // El identificador lleva #, % y $: sin codificar, el # cortaba la dirección y el resto quedaba como fragmento
                    return "D&&Default.aspx?url=" + HttpUtility.UrlEncode(encodeId("2"));
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Trace.TraceError("Login: " + ex);
                return "E&&No fue posible iniciar sesión. Intente de nuevo en unos minutos.";
            }
        }

        private static void creaSession(string usuario, string grupo, string fotoPerfil)
        {
            string men = "";
            SqlProcess sqlProccess = new SqlProcess();
            //Estado = "Star";
            men = sqlProccess.mtdSys_LogAccess("", "", "", "", "", "Star");

            // Siempre una sesión nueva: antes se agregaba a la anterior y el usuario [0] seguía siendo el primero que entró
            ArrayList usuarios = new ArrayList();
            usuarios.Add(usuario);
            usuarios.Add(grupo);
            usuarios.Add(fotoPerfil);
            Sesion.LimpiarCache();               // permisos y sucursal del usuario anterior
            HttpContext.Current.Session["dpsesion"] = usuarios;
        }

        private static string encodeId(string id)
        {
            string cad = "0X646hgftdrfffcdde453454p34dscvbXX6m876yuhdhjnsdnm6@" + id + "X#032btkpnyteghs%hjs658$gshagsbxbn";
            return cad;
        }
    }
}
