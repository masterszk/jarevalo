using System;
using System.Configuration;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using System.Web;

namespace DPieCenter.Facturacion
{
    /// <summary>
    /// Carpeta de los archivos de los DTE (PDF y JSON). Por defecto ~/Facturacion/facturas; en el servidor se puede usar otra
    /// carpeta con permiso de escritura para la identidad del sitio de IIS: appSettings "DteCarpetaArchivos" (ruta absoluta o ~/...).
    /// Los archivos se descargan con Facturacion/DteArchivo.ashx (exige sesión), así la carpeta puede estar fuera del sitio.
    /// </summary>
    public static class DteArchivos
    {
        private const string CarpetaDefecto = "~/Facturacion/facturas";
        private static readonly Regex ReCodigo = new Regex(@"^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$", RegexOptions.IgnoreCase);

        /// <summary>Ruta física de la carpeta raíz de los DTE.</summary>
        public static string Carpeta()
        {
            string c = ConfigurationManager.AppSettings["DteCarpetaArchivos"];
            if (string.IsNullOrWhiteSpace(c)) c = CarpetaDefecto;
            c = c.Trim();
            return c.StartsWith("~") ? HttpContext.Current.Server.MapPath(c) : c;
        }

        public static bool CarpetaPersonalizada { get { return !string.IsNullOrWhiteSpace(ConfigurationManager.AppSettings["DteCarpetaArchivos"]); } }

        private static string Subcarpeta(string tipoDte) { return tipoDte == TiposDte.CreditoFiscal ? "ccf" : "cfinal"; }

        public static bool CodigoValido(string codigo) { return codigo != null && ReCodigo.IsMatch(codigo); }

        /// <summary>URL de descarga (relativa al sitio) que se guarda en RutaPdf / RutaJson.</summary>
        public static string Url(string codigo, string extension) { return "Facturacion/DteArchivo.ashx?c=" + codigo.ToUpperInvariant() + "&t=" + extension; }

        /// <summary>Guarda el JSON y el PDF. Lanza la excepción de E/S con el motivo (por ejemplo, permiso denegado).</summary>
        public static void Guardar(string tipoDte, string codigo, string json, byte[] pdf)
        {
            string dir = Path.Combine(Carpeta(), Subcarpeta(tipoDte));
            Directory.CreateDirectory(dir);
            File.WriteAllText(Path.Combine(dir, "DTE-" + codigo + ".json"), json, new UTF8Encoding(false));
            File.WriteAllBytes(Path.Combine(dir, "DTE-" + codigo + ".pdf"), pdf);
        }

        /// <summary>Lee un archivo del DTE (pdf o json); busca en la carpeta configurada y en la carpeta anterior del sitio. null si no existe.</summary>
        public static byte[] Leer(string tipoDte, string codigo, string extension)
        {
            if (!CodigoValido(codigo) || (extension != "pdf" && extension != "json")) return null;
            string archivo = "DTE-" + codigo.ToUpperInvariant() + "." + extension;
            foreach (string raiz in new[] { Carpeta(), HttpContext.Current.Server.MapPath(CarpetaDefecto) })
                foreach (string sub in new[] { Subcarpeta(tipoDte), "cfinal", "ccf" })
                {
                    string ruta = Path.Combine(raiz, sub, archivo);
                    if (File.Exists(ruta)) return File.ReadAllBytes(ruta);
                }
            return null;
        }

        /// <summary>Prueba escribir y borrar un archivo en la carpeta. Devuelve null si se puede, o el error.</summary>
        public static string PruebaEscritura()
        {
            try
            {
                string dir = Path.Combine(Carpeta(), "cfinal");
                Directory.CreateDirectory(dir);
                string prueba = Path.Combine(dir, "prueba-escritura-" + Guid.NewGuid().ToString("N") + ".tmp");
                File.WriteAllText(prueba, "ok");
                File.Delete(prueba);
                return null;
            }
            catch (Exception ex) { return ex.GetType().Name + ": " + ex.Message; }
        }

        /// <summary>Cuenta con la que corre el sitio (a la que hay que dar permiso de escritura en IIS).</summary>
        public static string Identidad()
        {
            try { return System.Security.Principal.WindowsIdentity.GetCurrent().Name; }
            catch (Exception ex) { return "(no disponible: " + ex.Message + ")"; }
        }
    }
}
