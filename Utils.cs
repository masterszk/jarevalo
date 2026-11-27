using System;
using System.Collections;
using System.IO;
using System.Security.Cryptography;
using System.Text;


namespace DPieCenter
{
    public class Utils
    {
        public static string EncodeString(string originalPassword)
        {
            SHA1 sha1 = new SHA1CryptoServiceProvider();

            byte[] inputBytes = (new UnicodeEncoding()).GetBytes(originalPassword);
            byte[] hash = sha1.ComputeHash(inputBytes);

            StringBuilder cadena = new StringBuilder();
            foreach (byte i in hash)
            {
                cadena.AppendFormat("{0:x2}", i);
            }

            return cadena.ToString(); //ToLower();
        }

        // ===== Claves con sal (PBKDF2) =====
        // Formato: "$" + versión ('1' normal, 'T' temporal: el usuario debe cambiarla) + sal (11 car.) + hash (22 car.) = 35 caracteres,
        // para que quepa donde antes iba el SHA1 en hexadecimal (40). Las claves antiguas (SHA1) se siguen aceptando hasta que se cambien.
        private const int IteracionesClave = 100000;
        private const int LargoClaveHash = 35;

        public static string HashClave(string clave, bool temporal = false)
        {
            byte[] sal = new byte[8];
            using (var rng = RandomNumberGenerator.Create()) rng.GetBytes(sal);
            return "$" + (temporal ? "T" : "1") + SinRelleno(sal) + SinRelleno(Pbkdf2(clave ?? "", sal));
        }

        public static bool VerificarClave(string clave, string guardada)
        {
            if (string.IsNullOrEmpty(guardada)) return false;
            if (guardada.Length == LargoClaveHash && guardada[0] == '$')
            {
                try
                {
                    byte[] sal = Convert.FromBase64String(guardada.Substring(2, 11) + "=");
                    string esperado = guardada.Substring(13, 22);
                    return IgualesConstante(SinRelleno(Pbkdf2(clave ?? "", sal)), esperado);
                }
                catch (FormatException) { return false; }
            }
            return IgualesConstante(EncodeString(clave ?? "").ToLowerInvariant(), guardada.ToLowerInvariant());   // SHA1 antiguo
        }

        /// <summary>Clave asignada por un administrador: el usuario debe cambiarla al entrar.</summary>
        public static bool EsClaveTemporal(string guardada)
        {
            return !string.IsNullOrEmpty(guardada) && guardada.Length == LargoClaveHash && guardada[0] == '$' && guardada[1] == 'T';
        }

        /// <summary>Clave temporal aleatoria de 10 caracteres (sin letras ni números que se confunden).</summary>
        public static string GenerarClaveTemporal()
        {
            const string alfabeto = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";
            var bytes = new byte[10];
            using (var rng = RandomNumberGenerator.Create()) rng.GetBytes(bytes);
            var sb = new StringBuilder();
            foreach (byte b in bytes) sb.Append(alfabeto[b % alfabeto.Length]);   // sesgo despreciable (256 % 56)
            return sb.ToString();
        }

        private static byte[] Pbkdf2(string clave, byte[] sal)
        {
            using (var kdf = new Rfc2898DeriveBytes(clave, sal, IteracionesClave)) return kdf.GetBytes(16);
        }

        private static string SinRelleno(byte[] datos) { return Convert.ToBase64String(datos).TrimEnd('='); }

        private static bool IgualesConstante(string a, string b)
        {
            if (a.Length != b.Length) return false;
            int dif = 0;
            for (int i = 0; i < a.Length; i++) dif |= a[i] ^ b[i];
            return dif == 0;
        }

        public static string mtd_GetCadenaEncabezados(string pathFile, char separador)
        {
            string respuesta = "";

            char separadorRecibido = separador;

            string path = pathFile;
            string lineaLectura = "";

            int contador = 0;

            string cadenaEncabezados = "";
            ArrayList encabezadosXML = new ArrayList();

            try
            {
                StreamReader objReader = new StreamReader(path);
                while (lineaLectura != null)
                {
                    ArrayList lineaXML = new ArrayList();
                    ArrayList arrayListDatosCliente = new ArrayList();
                    lineaLectura = objReader.ReadLine();

                    if (lineaLectura != null)
                    {
                        if (contador == 0)
                        {
                            string[] encabezados = lineaLectura.Split(separadorRecibido);
                            long campos = encabezados.Length;
                            for (int i = 0; i < campos; i++)
                            {
                                if (i < campos - 1)
                                {
                                    cadenaEncabezados += "encabezado_" + i + " " + "varchar(max),";
                                    encabezadosXML.Add(encabezados[i]);
                                }
                                else
                                {
                                    cadenaEncabezados += "encabezado_" + i + " " + "varchar(max)";
                                    encabezadosXML.Add(encabezados[i]);
                                }
                            }
                        }

                    }
                    contador++;
                }

                objReader.Close();

                respuesta = cadenaEncabezados;
            }
            catch (IOException iex)
            {
                respuesta = "NO" + iex.StackTrace + "MESSAGE: " + iex.Message;
            }
            catch (Exception ex)
            {
                respuesta = "NO" + ex.StackTrace + "MESSAGE: " + ex.Message;
            }

            return respuesta;
        }
    }
}