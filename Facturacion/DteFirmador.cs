using System;
using System.Data;
using System.Data.SqlClient;
using System.IO;
using System.Net;
using System.Text;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace DPieCenter.Facturacion
{
    public class FirmadorDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public string Url { get; set; }
        public string Nit { get; set; }
        public string NitEmisor { get; set; }
        /// <summary>Solo al guardar: contraseña de la llave privada; vacía conserva la guardada. Nunca se envía al navegador.</summary>
        public string Clave { get; set; }
        public bool TieneClave { get; set; }
        public string UltimaPrueba { get; set; }
        public string Resultado { get; set; }
    }

    /// <summary>
    /// Generador de firma de Hacienda (svfe-api-firmador). Recibe { nit, activo, passwordPri, dteJson } y devuelve
    /// { status: "OK", body: "&lt;JWS firmado&gt;" } o { status: "ERROR", body: { codigo, mensaje } }.
    /// La contraseña de la llave privada se guarda cifrada con la llave de Web.config (DteCorreo.Cifrar).
    /// </summary>
    public static class DteFirmador
    {
        private const int TiempoEsperaMs = 15000;

        private static SqlCommand Sp(SqlConnection cn, int accion)
        {
            var cmd = new SqlCommand("dbo.FAC_SP_DTE_FIRMADOR", cn) { CommandType = CommandType.StoredProcedure };
            cmd.Parameters.Add("@accion", SqlDbType.Int).Value = accion;
            return cmd;
        }

        public static FirmadorDto Consultar()
        {
            using (var cn = new SqlConnection(DteRepository.Cn))
            using (var cmd = Sp(cn, 1))
            {
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                {
                    if (!rd.Read()) return new FirmadorDto { Ok = true, Mensaje = "Guarde primero los datos de facturación electrónica." };
                    var prueba = rd["FirmadorPrueba"];
                    return new FirmadorDto
                    {
                        Ok = true, Url = Convert.ToString(rd["FirmadorUrl"]), Nit = Convert.ToString(rd["FirmadorNit"]), NitEmisor = Convert.ToString(rd["NitEmisor"]),
                        TieneClave = Convert.ToBoolean(rd["TieneClave"]),
                        UltimaPrueba = prueba == DBNull.Value ? "" : Formato.FechaHora(Convert.ToDateTime(prueba)),
                        Resultado = Convert.ToString(rd["FirmadorResultado"])
                    };
                }
            }
        }

        public static void Guardar(FirmadorDto f, string usuario)
        {
            using (var cn = new SqlConnection(DteRepository.Cn))
            using (var cmd = Sp(cn, 2))
            {
                cmd.Parameters.Add("@url", SqlDbType.VarChar, 250).Value = (object)(f.Url ?? "").Trim() ?? DBNull.Value;
                cmd.Parameters.Add("@nit", SqlDbType.VarChar, 14).Value = (object)System.Text.RegularExpressions.Regex.Replace(f.Nit ?? "", "[^0-9]", "");
                cmd.Parameters.Add("@clave", SqlDbType.VarChar, 1000).Value = string.IsNullOrEmpty(f.Clave) ? (object)DBNull.Value : DteCorreo.Cifrar(f.Clave);
                cmd.Parameters.Add("@usuario", SqlDbType.VarChar, 20).Value = usuario;
                cn.Open();
                cmd.ExecuteNonQuery();
            }
        }

        /// <summary>Firma un JSON con el firmador configurado. Devuelve el JWS o lanza InvalidOperationException con el motivo.</summary>
        public static string Firmar(object dteJson)
        {
            string url, nit, claveCifrada;
            using (var cn = new SqlConnection(DteRepository.Cn))
            using (var cmd = Sp(cn, 4))
            {
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                {
                    if (!rd.Read()) throw new InvalidOperationException("No hay datos de facturación electrónica.");
                    url = Convert.ToString(rd["FirmadorUrl"]); nit = Convert.ToString(rd["FirmadorNit"]); claveCifrada = Convert.ToString(rd["FirmadorClave"]);
                }
            }
            if (string.IsNullOrWhiteSpace(url)) throw new InvalidOperationException("Configure la dirección del firmador.");
            string clave = DteCorreo.Descifrar(claveCifrada);
            if (string.IsNullOrEmpty(clave)) throw new InvalidOperationException("Ingrese la contraseña de la llave privada del certificado.");

            string cuerpo = JsonConvert.SerializeObject(new { nit, activo = true, passwordPri = clave, dteJson });
            var req = (HttpWebRequest)WebRequest.Create(url);
            req.Method = "POST";
            req.ContentType = "application/json";
            req.Timeout = req.ReadWriteTimeout = TiempoEsperaMs;
            byte[] datos = Encoding.UTF8.GetBytes(cuerpo);
            string respuesta;
            try
            {
                using (var s = req.GetRequestStream()) s.Write(datos, 0, datos.Length);
                using (var r = (HttpWebResponse)req.GetResponse())
                using (var lector = new StreamReader(r.GetResponseStream(), Encoding.UTF8)) respuesta = lector.ReadToEnd();
            }
            catch (WebException ex)
            {
                if (ex.Response == null) throw new InvalidOperationException("No se pudo conectar con el firmador en " + url + ": " + ex.Message);
                using (var lector = new StreamReader(ex.Response.GetResponseStream(), Encoding.UTF8)) respuesta = lector.ReadToEnd();
            }

            JObject j;
            try { j = JObject.Parse(respuesta); }
            catch (JsonException) { throw new InvalidOperationException("El firmador respondió algo que no es JSON: " + Recortar(respuesta, 200)); }
            if (string.Equals((string)j["status"], "OK", StringComparison.OrdinalIgnoreCase) && j["body"] != null && j["body"].Type == JTokenType.String)
                return (string)j["body"];
            var b = j["body"];
            string detalle = b != null && b.Type == JTokenType.Object ? ((string)b["mensaje"] ?? b.ToString(Formatting.None)) : Recortar(respuesta, 300);
            throw new InvalidOperationException("El firmador rechazó la solicitud: " + detalle);
        }

        /// <summary>Firma un documento de prueba con la configuración guardada y registra el resultado.</summary>
        public static FirmadorDto Probar(string usuario)
        {
            bool ok; string mensaje;
            try
            {
                string jws = Firmar(new { prueba = "DPieCenter", fecha = DateTime.Now.ToString("s") });
                ok = jws.Split('.').Length == 3;
                mensaje = ok ? "El firmador devolvió el documento firmado (" + jws.Length + " caracteres)." : "El firmador respondió OK pero la firma no tiene el formato esperado.";
            }
            catch (Exception ex) { ok = false; mensaje = ex.Message; }

            using (var cn = new SqlConnection(DteRepository.Cn))
            using (var cmd = Sp(cn, 3))
            {
                cmd.Parameters.Add("@ok", SqlDbType.Bit).Value = ok;
                cmd.Parameters.Add("@resultado", SqlDbType.NVarChar, 500).Value = Recortar(mensaje, 480);
                cn.Open();
                cmd.ExecuteNonQuery();
            }
            DteRepository.RegistrarEvento(0, "Firma", ok, mensaje, usuario);
            var f = Consultar();
            f.Ok = ok;
            f.Mensaje = mensaje;
            return f;
        }

        private static string Recortar(string s, int max) { s = s ?? ""; return s.Length > max ? s.Substring(0, max) + "…" : s; }
    }
}
