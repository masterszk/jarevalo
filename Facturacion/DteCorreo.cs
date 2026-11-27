using System;
using System.Security.Cryptography;
using System.Text;
using System.Web;
using EASendMail;

namespace DPieCenter.Facturacion
{
    // Envío del DTE (PDF + JSON) por correo con los datos SMTP de FAC_DTE_PARAMETROS
    public static class DteCorreo
    {
        // Licencia de EASendMail: appSettings "EASendMailLicencia" en Web.config (no se sube al repositorio)
        private static string Licencia
        {
            get { return System.Configuration.ConfigurationManager.AppSettings["EASendMailLicencia"] ?? ""; }
        }
        private const string Prefijo = "dpapi:";
        private const string PrefijoAes = "aes:";
        private static readonly byte[] Entropia = Encoding.UTF8.GetBytes("DPieCenter.DTE.Smtp");

        /// <summary>
        /// Llave de Web.config (appSettings "DteClaveCifrado", 32 bytes en base64). Con ella la clave SMTP se puede descifrar en
        /// cualquier servidor que tenga el mismo Web.config. Sin llave se usa DPAPI del equipo (solo funciona en el equipo donde se guardó).
        /// </summary>
        private static byte[] Llave()
        {
            string b64 = System.Configuration.ConfigurationManager.AppSettings["DteClaveCifrado"];
            if (string.IsNullOrWhiteSpace(b64)) return null;
            try { var k = Convert.FromBase64String(b64.Trim()); return k.Length == 32 ? k : null; }
            catch (FormatException) { return null; }
        }

        public static bool TieneLlavePortable { get { return Llave() != null; } }

        /// <summary>Formato de la clave guardada: aes (portable), dpapi (solo este equipo) o texto.</summary>
        public static string FormatoClave(string guardada)
        {
            if (string.IsNullOrEmpty(guardada)) return "sin clave";
            return guardada.StartsWith(PrefijoAes) ? "aes" : guardada.StartsWith(Prefijo) ? "dpapi" : "texto";
        }

        public static string Cifrar(string clave)
        {
            byte[] llave = Llave();
            if (llave == null)
            {
                byte[] datos = ProtectedData.Protect(Encoding.UTF8.GetBytes(clave), Entropia, DataProtectionScope.LocalMachine);
                return Prefijo + Convert.ToBase64String(datos);
            }
            // AES-256-CBC + HMAC-SHA256 (cifrar y luego autenticar): iv | cifrado | hmac
            using (var aes = Aes.Create())
            {
                aes.Key = Derivar(llave, "cifrado");
                aes.GenerateIV();
                byte[] cifrado;
                using (var enc = aes.CreateEncryptor())
                {
                    byte[] plano = Encoding.UTF8.GetBytes(clave);
                    cifrado = enc.TransformFinalBlock(plano, 0, plano.Length);
                }
                byte[] cuerpo = new byte[aes.IV.Length + cifrado.Length];
                Buffer.BlockCopy(aes.IV, 0, cuerpo, 0, aes.IV.Length);
                Buffer.BlockCopy(cifrado, 0, cuerpo, aes.IV.Length, cifrado.Length);
                byte[] mac;
                using (var h = new HMACSHA256(Derivar(llave, "firma"))) mac = h.ComputeHash(cuerpo);
                byte[] todo = new byte[cuerpo.Length + mac.Length];
                Buffer.BlockCopy(cuerpo, 0, todo, 0, cuerpo.Length);
                Buffer.BlockCopy(mac, 0, todo, cuerpo.Length, mac.Length);
                return PrefijoAes + Convert.ToBase64String(todo);
            }
        }

        public static string Descifrar(string guardada)
        {
            if (string.IsNullOrEmpty(guardada)) return null;
            try
            {
                if (guardada.StartsWith(PrefijoAes))
                {
                    byte[] llave = Llave();
                    if (llave == null) return null;
                    byte[] todo = Convert.FromBase64String(guardada.Substring(PrefijoAes.Length));
                    if (todo.Length < 16 + 16 + 32) return null;
                    int largo = todo.Length - 32;
                    byte[] mac;
                    using (var h = new HMACSHA256(Derivar(llave, "firma"))) mac = h.ComputeHash(todo, 0, largo);
                    int dif = 0;
                    for (int i = 0; i < 32; i++) dif |= mac[i] ^ todo[largo + i];
                    if (dif != 0) return null;       // otra llave o dato alterado
                    using (var aes = Aes.Create())
                    {
                        aes.Key = Derivar(llave, "cifrado");
                        byte[] iv = new byte[16];
                        Buffer.BlockCopy(todo, 0, iv, 0, 16);
                        aes.IV = iv;
                        using (var dec = aes.CreateDecryptor())
                            return Encoding.UTF8.GetString(dec.TransformFinalBlock(todo, 16, largo - 16));
                    }
                }
                if (!guardada.StartsWith(Prefijo)) return guardada;
                byte[] datos = ProtectedData.Unprotect(Convert.FromBase64String(guardada.Substring(Prefijo.Length)), Entropia, DataProtectionScope.LocalMachine);
                return Encoding.UTF8.GetString(datos);
            }
            catch (CryptographicException) { return null; }
            catch (FormatException) { return null; }
        }

        private static byte[] Derivar(byte[] llave, string uso)
        {
            using (var h = new HMACSHA256(llave)) return h.ComputeHash(Encoding.UTF8.GetBytes("DPieCenter.DTE.Smtp." + uso));
        }

        // Devuelve null si está listo para enviar, o el motivo por el que no se puede
        public static string Configuracion(EmisorDte e)
        {
            if (string.IsNullOrWhiteSpace(e.SmtpServidor) || e.SmtpPuerto <= 0 || string.IsNullOrWhiteSpace(e.SmtpUsuario))
                return "Configure el servidor de correo en Opciones > Datos de la empresa > Facturación electrónica.";
            if (Descifrar(e.SmtpClave) == null)
                return FormatoClave(e.SmtpClave) == "dpapi"
                    ? "La clave del correo se guardó en otro equipo y este servidor no la puede leer. Ingrésela de nuevo en Opciones > Datos de la empresa > Facturación electrónica."
                    : "No se puede leer la clave del correo. Ingrésela de nuevo en Opciones > Datos de la empresa > Facturación electrónica.";
            return null;
        }

        public static void Enviar(EmisorDte e, string para, string asunto, string html, params Tuple<string, byte[]>[] adjuntos)
        {
            string motivo = Configuracion(e);
            if (motivo != null) throw new InvalidOperationException(motivo);

            string nombre = string.IsNullOrWhiteSpace(e.NombreComercial) ? e.Nombre : e.NombreComercial;
            EnviarSmtp(e.SmtpServidor, e.SmtpPuerto, e.SmtpUsuario, Descifrar(e.SmtpClave), nombre, para, asunto, html, adjuntos);
        }

        /// <summary>Envío con una cuenta SMTP cualquiera (clave ya descifrada). Lo usa también la recuperación de contraseña.</summary>
        public static void EnviarSmtp(string servidor, int puerto, string usuario, string clave, string remitente,
            string para, string asunto, string html, params Tuple<string, byte[]>[] adjuntos)
        {
            var mail = new SmtpMail(Licencia)
            {
                From = new MailAddress(string.IsNullOrWhiteSpace(remitente) ? usuario : remitente, usuario),
                To = para,
                Subject = asunto,
                HtmlBody = html
            };
            foreach (var a in adjuntos) mail.AddAttachment(a.Item1, a.Item2);

            var server = new SmtpServer(servidor)
            {
                User = usuario,
                Password = clave,
                Port = puerto,
                ConnectType = SmtpConnectType.ConnectSSLAuto   // 465 = SSL directo, 587 = STARTTLS
            };
            new SmtpClient().SendMail(server, mail);
        }

        public static string CuerpoDte(EmisorDte e, string receptor, string tipoDte, string numeroControl, string codigoGeneracion, string total)
        {
            string nombre = HttpUtility.HtmlEncode(string.IsNullOrWhiteSpace(e.NombreComercial) ? e.Nombre : e.NombreComercial);
            string documento = tipoDte == TiposDte.CreditoFiscal ? "Comprobante de Crédito Fiscal" : "Factura";
            var sb = new StringBuilder();
            sb.Append("<div style=\"font-family:Arial,Helvetica,sans-serif;font-size:14px;color:#212529\">");
            sb.Append("<p>Estimado(a) ").Append(HttpUtility.HtmlEncode(receptor)).Append(":</p>");
            sb.Append("<p>Adjunto encontrará su <strong>").Append(documento).Append("</strong> emitido por ").Append(nombre)
              .Append(", en formato PDF y JSON (Documento Tributario Electrónico).</p>");
            sb.Append("<table style=\"border-collapse:collapse;font-size:13px\">");
            Fila(sb, "No. de control", numeroControl);
            Fila(sb, "Código de generación", codigoGeneracion);
            if (!string.IsNullOrEmpty(total)) Fila(sb, "Total", "$" + total);
            sb.Append("</table>");
            sb.Append("<p>Gracias por su preferencia.</p>");
            sb.Append("<p style=\"color:#6c757d;font-size:12px\">").Append(nombre).Append(" · Tel: ").Append(HttpUtility.HtmlEncode(e.Telefono))
              .Append("<br>Este correo fue generado automáticamente, por favor no lo responda.</p></div>");
            return sb.ToString();
        }

        private static void Fila(StringBuilder sb, string etiqueta, string valor)
        {
            sb.Append("<tr><td style=\"padding:2px 12px 2px 0;color:#6c757d\">").Append(etiqueta).Append("</td><td style=\"padding:2px 0\"><strong>")
              .Append(HttpUtility.HtmlEncode(valor)).Append("</strong></td></tr>");
        }
    }
}
