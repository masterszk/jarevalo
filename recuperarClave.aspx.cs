using System;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Runtime.Caching;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Web;
using System.Web.Services;
using DPieCenter.Facturacion;

namespace DPieCenter
{
    /// <summary>
    /// Recuperación de contraseña desde el login (assets/js/recuperar-clave.js):
    /// 1) correo -> se envía un código de 6 dígitos, 2) se valida el código, 3) nueva contraseña.
    /// Reglas en dbo.Sys_SP_RecuperarClave (Opciones/sql/SYS_Recuperar_Clave.sql). El código solo se guarda como hash.
    /// El correo se envía con la cuenta "Correo para envíos (SMTP)" de Opciones > Empresa (Sys_ConfiguracionApp).
    /// </summary>
    public partial class recuperarClave : System.Web.UI.Page
    {
        public class RespuestaDto
        {
            public bool Ok { get; set; }
            public string Mensaje { get; set; }
            public int Restantes { get; set; }
            public bool Reiniciar { get; set; }      // volver al paso 1
        }

        private const string SesId = "rc_id", SesEmail = "rc_email", SesVerificado = "rc_ok";
        private const int MaxPorIp = 10;
        private static readonly MemoryCache PorIp = new MemoryCache("DPieCenter.RecuperarClave");
        private static readonly Regex ReEmail = new Regex(@"^[^@\s]+@[^@\s]+\.[^@\s]+$");
        private static readonly Regex ReUsuario = new Regex(@"^[A-Za-z0-9._]+$");

        private static string Cn { get { return ConfigurationManager.ConnectionStrings["conexionDiarypro"].ConnectionString; } }

        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack) Limpiar();
        }

        private static void Limpiar()
        {
            var s = HttpContext.Current.Session;
            s.Remove(SesId); s.Remove(SesEmail); s.Remove(SesVerificado);
        }

        private static RespuestaDto Falla(string m, bool reiniciar = false) { return new RespuestaDto { Ok = false, Mensaje = m, Reiniciar = reiniciar }; }

        // Hash del código ligado al usuario: un código copiado no sirve para otra solicitud
        private static string Hash(string email, string codigo)
        {
            using (var sha = SHA256.Create())
            {
                var b = sha.ComputeHash(Encoding.UTF8.GetBytes("DPieCenter.Recuperar|" + email.ToLowerInvariant() + "|" + codigo));
                var sb = new StringBuilder(64);
                foreach (var x in b) sb.Append(x.ToString("x2"));
                return sb.ToString();
            }
        }

        private static string Codigo()
        {
            var b = new byte[4];
            using (var rng = RandomNumberGenerator.Create()) rng.GetBytes(b);
            return (BitConverter.ToUInt32(b, 0) % 1000000).ToString("000000");
        }

        private static bool LimiteIp()
        {
            string ip = "ip:" + HttpContext.Current.Request.UserHostAddress;
            lock (PorIp)
            {
                int n = (PorIp.Get(ip) as int?) ?? 0;
                if (n >= MaxPorIp) return true;
                PorIp.Set(ip, n + 1, DateTimeOffset.Now.AddMinutes(15));
                return false;
            }
        }

        private static SqlCommand Sp(SqlConnection cn, int accion)
        {
            var cmd = new SqlCommand("dbo.Sys_SP_RecuperarClave", cn) { CommandType = CommandType.StoredProcedure };
            cmd.Parameters.Add("@accion", SqlDbType.Int).Value = accion;
            return cmd;
        }

        private static string MensajeSql(SqlException ex)
        {
            return ex.Number >= 50000 ? ex.Message : "No fue posible completar la solicitud. Intente de nuevo en unos minutos.";
        }

        /// <summary>
        /// Paso 1. Se pide el USUARIO y el código va solo al correo registrado en ese usuario (antes se escribía un correo
        /// y se tomaba el primer usuario que lo tuviera: con un correo compartido, el código era para otro usuario).
        /// Responde lo mismo exista o no el usuario; si existe, muestra el correo enmascarado para que sepa dónde buscarlo.
        /// </summary>
        [WebMethod(EnableSession = true)]
        public static RespuestaDto Solicitar(string usuario)
        {
            usuario = (usuario ?? "").Trim();
            if (usuario.Length == 0 || usuario.Length > 20 || !ReUsuario.IsMatch(usuario)) return Falla("Escriba su usuario (el mismo con el que inicia sesión).");
            if (LimiteIp()) return Falla("Se hicieron demasiadas solicitudes desde este equipo. Espere 15 minutos.");

            const string generico = "Si el usuario existe y tiene correo registrado, recibirá un código de 6 dígitos en ese correo. Revise también el correo no deseado. Si no le llega, pida al administrador que revise el correo de su usuario.";
            string codigo = Codigo();
            long id = 0; string nombre = "", destino = "";
            try
            {
                using (var cn = new SqlConnection(Cn))
                using (var cmd = Sp(cn, 1))
                {
                    cmd.Parameters.Add("@idUsuario", SqlDbType.VarChar, 20).Value = usuario;
                    cmd.Parameters.Add("@codigoHash", SqlDbType.Char, 64).Value = Hash(usuario, codigo);
                    cmd.Parameters.Add("@ip", SqlDbType.VarChar, 45).Value = HttpContext.Current.Request.UserHostAddress ?? "";
                    cn.Open();
                    using (var rd = cmd.ExecuteReader())
                        if (rd.Read())
                        {
                            id = Convert.ToInt64(rd["Id_Recuperacion"]);
                            nombre = Convert.ToString(rd["Nombre"]);
                            destino = Convert.ToString(rd["Email"]);
                        }
                }
            }
            catch (SqlException ex) { return Falla(MensajeSql(ex)); }

            var s = HttpContext.Current.Session;
            s[SesId] = id; s[SesEmail] = usuario; s.Remove(SesVerificado);      // el hash del código va ligado al usuario
            if (id == 0) return new RespuestaDto { Ok = true, Mensaje = generico };
            if (!ReEmail.IsMatch(destino ?? "")) return new RespuestaDto { Ok = true, Mensaje = generico };

            try
            {
                // Cuenta "Correo para envíos (SMTP)" de Opciones > Empresa (no la de los DTE)
                var smtp = Opciones.AdministracionRepository.CorreoEmpresa();
                if (smtp == null || !smtp.Completo)
                    throw new InvalidOperationException("Configure el correo para envíos (SMTP) en Opciones > Empresa: correo, clave, servidor y puerto.");
                string clinica = NombreClinica(smtp);
                DteCorreo.EnviarSmtp(smtp.Servidor, smtp.Puerto, smtp.Usuario, smtp.Clave, clinica,
                    destino, "Código de recuperación", Cuerpo(clinica, nombre, codigo));
            }
            catch (Exception ex)
            {
                System.Diagnostics.Trace.TraceError("Recuperar clave: " + ex.Message);
                return Falla("No fue posible enviar el correo en este momento. Intente más tarde o solicite al administrador que restablezca su contraseña.", true);
            }
            return new RespuestaDto { Ok = true, Mensaje = "Enviamos un código de 6 dígitos al correo registrado en su usuario: " + Enmascarar(destino) + ". Revise también el correo no deseado." };
        }

        // jo******@gm***.com: suficiente para reconocer su correo sin mostrarlo completo
        private static string Enmascarar(string email)
        {
            int a = email.IndexOf('@'), p = email.LastIndexOf('.');
            if (a < 1 || p < a) return "su correo";
            string local = email.Substring(0, a), dominio = email.Substring(a + 1, p - a - 1), fin = email.Substring(p);
            Func<string, int, string> m = (t, ver) => t.Substring(0, Math.Min(ver, t.Length)) + new string('*', Math.Max(3, t.Length - ver));
            return m(local, local.Length > 4 ? 2 : 1) + "@" + m(dominio, 2) + fin;
        }

        // Nombre comercial del emisor DTE si existe; si no, el nombre de la empresa
        private static string NombreClinica(Opciones.AdministracionRepository.CorreoSmtp smtp)
        {
            try
            {
                var e = DteRepository.ObtenerEmisor();
                if (e != null && !string.IsNullOrWhiteSpace(e.NombreComercial)) return e.NombreComercial.Trim();
            }
            catch (Exception) { }
            return string.IsNullOrWhiteSpace(smtp.Empresa) ? "D' Pie Center" : smtp.Empresa;
        }

        private static string Cuerpo(string nombreClinica, string nombre, string codigo)
        {
            string clinica = HttpUtility.HtmlEncode(nombreClinica);
            return "<div style=\"font-family:Arial,Helvetica,sans-serif;font-size:14px;color:#17323a\">"
                + "<p>Hola " + HttpUtility.HtmlEncode(nombre) + ":</p>"
                + "<p>Recibimos una solicitud para restablecer su contraseña del sistema de " + clinica + ". Su código es:</p>"
                + "<p style=\"font-size:28px;font-weight:bold;letter-spacing:6px;color:#0b6f78;margin:16px 0\">" + codigo + "</p>"
                + "<p>El código vence en 10 minutos. Si usted no hizo esta solicitud, ignore este correo: su contraseña no cambiará.</p>"
                + "<p style=\"color:#6c757d;font-size:12px\">Este correo fue generado automáticamente, por favor no lo responda.</p></div>";
        }

        /// <summary>Paso 2.</summary>
        [WebMethod(EnableSession = true)]
        public static RespuestaDto Validar(string codigo)
        {
            codigo = (codigo ?? "").Trim();
            if (!Regex.IsMatch(codigo, @"^\d{6}$")) return Falla("El código tiene 6 dígitos.");
            var s = HttpContext.Current.Session;
            if (s[SesEmail] == null) return Falla("La solicitud venció. Solicite un código nuevo.", true);
            long id = (long)s[SesId];
            if (id == 0) return Falla("El código no es válido o ya venció.");   // correo no registrado: misma respuesta

            try
            {
                using (var cn = new SqlConnection(Cn))
                using (var cmd = Sp(cn, 2))
                {
                    cmd.Parameters.Add("@id", SqlDbType.BigInt).Value = id;
                    cmd.Parameters.Add("@codigoHash", SqlDbType.Char, 64).Value = Hash((string)s[SesEmail], codigo);
                    cn.Open();
                    using (var rd = cmd.ExecuteReader())
                    {
                        if (!rd.Read()) return Falla("No fue posible validar el código.");
                        string r = Convert.ToString(rd["Resultado"]);
                        int quedan = Convert.ToInt32(rd["Restantes"]);
                        switch (r)
                        {
                            case "OK":
                                s[SesVerificado] = true;
                                return new RespuestaDto { Ok = true, Mensaje = "Código correcto. Escriba su nueva contraseña." };
                            case "INCORRECTO":
                                return new RespuestaDto { Ok = false, Restantes = quedan, Mensaje = "Código incorrecto. Le quedan " + quedan + (quedan == 1 ? " intento." : " intentos.") };
                            case "BLOQUEADO":
                                Limpiar();
                                return Falla("Se agotaron los intentos. Solicite un código nuevo.", true);
                            default:
                                Limpiar();
                                return Falla("El código venció. Solicite uno nuevo.", true);
                        }
                    }
                }
            }
            catch (SqlException ex) { return Falla(MensajeSql(ex)); }
        }

        /// <summary>Paso 3. Mismas reglas que resetPass.aspx, más letras y números.</summary>
        [WebMethod(EnableSession = true)]
        public static RespuestaDto Cambiar(string clave, string confirmacion)
        {
            var s = HttpContext.Current.Session;
            if (s[SesVerificado] == null || s[SesId] == null) return Falla("Primero valide el código que recibió por correo.", true);
            clave = clave ?? "";
            if (clave.Length < 8 || clave.Length > 50) return Falla("La contraseña debe tener entre 8 y 50 caracteres.");
            if (!Regex.IsMatch(clave, "[A-Za-zÁÉÍÓÚáéíóúÑñ]") || !Regex.IsMatch(clave, @"\d")) return Falla("La contraseña debe tener letras y números.");
            if (clave != (confirmacion ?? "")) return Falla("Las contraseñas no coinciden.");

            try
            {
                using (var cn = new SqlConnection(Cn))
                using (var cmd = Sp(cn, 3))
                {
                    cmd.Parameters.Add("@id", SqlDbType.BigInt).Value = (long)s[SesId];
                    cmd.Parameters.Add("@newpass", SqlDbType.VarChar, 50).Value = Utils.HashClave(clave);
                    cn.Open();
                    string r = Convert.ToString(cmd.ExecuteScalar());
                    if (r == "REPETIDA") return Falla("No puede usar su contraseña actual ni una de las 3 anteriores.");
                    if (r != "OK") { Limpiar(); return Falla("La solicitud venció. Solicite un código nuevo.", true); }
                }
            }
            catch (SqlException ex) { return Falla(MensajeSql(ex)); }

            LoginIntentos.Desbloquear(s[SesEmail] as string);     // si estaba bloqueado por intentos fallidos, ya puede entrar
            Limpiar();
            return new RespuestaDto { Ok = true, Mensaje = "Su contraseña fue cambiada. Ya puede iniciar sesión." };
        }
    }
}
