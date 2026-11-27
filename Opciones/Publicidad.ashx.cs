using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Web;
using System.Web.SessionState;
using Newtonsoft.Json;

namespace DPieCenter.Opciones
{
    /// <summary>
    /// Videos publicitarios de la pantalla de turnos (Registros/frm_TurnosPacientes.aspx), carpeta ~/assets/publicidad.
    /// La pantalla los reproduce en orden alfabético; aquí el orden se guarda con el prefijo "01-", "02-", ... del nombre.
    ///   GET                             lista de videos
    ///   POST accion=subir   (multipart)  campo "video": .mp4 o .webm, hasta 300 MB; queda al final de la lista
    ///   POST accion=eliminar nombre=...
    ///   POST accion=mover    nombre=... direccion=-1|1
    /// Requiere sesión y permiso a la opción del menú Opciones/frm_Publicidad.aspx.
    /// </summary>
    public class Publicidad : IHttpHandler, IRequiresSessionState
    {
        public const string UrlOpcion = "Opciones/frm_Publicidad.aspx";
        private const string Carpeta = "~/assets/publicidad";
        public const long MaxBytes = 300L * 1024 * 1024;
        private static readonly string[] Extensiones = { ".mp4", ".webm" };
        private static readonly Regex Prefijo = new Regex(@"^\d{2,3}-");
        private static readonly object Candado = new object();

        public bool IsReusable { get { return false; } }

        private class Resultado
        {
            public bool Ok { get; set; }
            public string Mensaje { get; set; }
            public List<VideoDto> Videos { get; set; }
            public long MaxMb { get { return MaxBytes / (1024 * 1024); } }
        }

        public class VideoDto
        {
            public string Nombre { get; set; }      // nombre del archivo
            public string Titulo { get; set; }      // nombre sin prefijo ni extensión
            public string Url { get; set; }
            public string Tamano { get; set; }
            public string Fecha { get; set; }
        }

        public void ProcessRequest(HttpContext context)
        {
            var r = new Resultado();
            try
            {
                string permiso = AdministracionWeb.Permiso(UrlOpcion);
                if (permiso != null)
                {
                    context.Response.StatusCode = Sesion.Activa ? 403 : 401;
                    r.Mensaje = permiso;
                }
                else
                {
                    string ruta = context.Server.MapPath(Carpeta);
                    Directory.CreateDirectory(ruta);
                    lock (Candado)
                    {
                        if (context.Request.HttpMethod == "POST")
                        {
                            string accion = context.Request.Form["accion"];
                            if (accion == "subir") r.Mensaje = Subir(context, ruta);
                            else if (accion == "eliminar") r.Mensaje = Eliminar(ruta, context.Request.Form["nombre"]);
                            else if (accion == "mover") r.Mensaje = Mover(ruta, context.Request.Form["nombre"], context.Request.Form["direccion"] == "-1" ? -1 : 1);
                            else throw new ArgumentException("Acción no válida.");
                        }
                        r.Ok = true;
                        r.Videos = Lista(ruta);
                    }
                }
            }
            catch (ErrorUsuario ex)
            {
                r.Ok = false; r.Mensaje = ex.Message;
                try { r.Videos = Lista(context.Server.MapPath(Carpeta)); } catch (IOException) { }   // la página se actualiza igual
            }
            catch (Exception ex)
            {
                System.Diagnostics.Trace.TraceError("Publicidad: " + ex);
                r.Ok = false;
                r.Mensaje = context.IsDebuggingEnabled ? "[DEBUG] " + ex.Message : "No fue posible completar la operación.";
            }
            context.Response.ContentType = "application/json";
            context.Response.Cache.SetCacheability(HttpCacheability.NoCache);
            context.Response.Write(JsonConvert.SerializeObject(r));
        }

        private class ErrorUsuario : Exception { public ErrorUsuario(string m) : base(m) { } }

        private static List<FileInfo> Archivos(string ruta)
        {
            return new DirectoryInfo(ruta).GetFiles()
                .Where(f => Extensiones.Contains(f.Extension.ToLowerInvariant()))
                .OrderBy(f => f.Name, StringComparer.OrdinalIgnoreCase)
                .ToList();
        }

        private static List<VideoDto> Lista(string ruta)
        {
            return Archivos(ruta).Select(f => new VideoDto
            {
                Nombre = f.Name,
                Titulo = Prefijo.Replace(Path.GetFileNameWithoutExtension(f.Name), ""),
                Url = "assets/publicidad/" + Uri.EscapeDataString(f.Name),
                Tamano = f.Length >= 1024 * 1024 ? (f.Length / 1048576.0).ToString("0.0") + " MB" : Math.Max(1, f.Length / 1024) + " KB",
                Fecha = f.LastWriteTime.ToString("dd/MM/yyyy hh:mm tt", System.Globalization.CultureInfo.InvariantCulture)
            }).ToList();
        }

        // Nombre de archivo seguro: letras, números, guion; sin acentos ni rutas
        private static string Limpio(string nombre)
        {
            string s = Path.GetFileNameWithoutExtension(nombre ?? "").Normalize(NormalizationForm.FormD);
            var sb = new StringBuilder();
            foreach (char c in s)
            {
                var cat = System.Globalization.CharUnicodeInfo.GetUnicodeCategory(c);
                if (cat == System.Globalization.UnicodeCategory.NonSpacingMark) continue;
                sb.Append(char.IsLetterOrDigit(c) && c < 128 ? char.ToLowerInvariant(c) : '-');
            }
            string r = Regex.Replace(sb.ToString(), "-{2,}", "-").Trim('-');
            r = Prefijo.Replace(r, "");
            if (r.Length > 60) r = r.Substring(0, 60).TrimEnd('-');
            return r.Length == 0 ? "video" : r;
        }

        // Verifica el contenido, no solo la extensión: MP4 tiene "ftyp" en el byte 4; WebM empieza con 1A 45 DF A3
        private static bool FirmaValida(Stream s, string ext)
        {
            var b = new byte[12];
            int n = s.Read(b, 0, b.Length);
            s.Position = 0;
            if (n < 12) return false;
            if (ext == ".mp4") return b[4] == 'f' && b[5] == 't' && b[6] == 'y' && b[7] == 'p';
            return b[0] == 0x1A && b[1] == 0x45 && b[2] == 0xDF && b[3] == 0xA3;
        }

        private static string Subir(HttpContext context, string ruta)
        {
            var archivo = context.Request.Files["video"];
            if (archivo == null || archivo.ContentLength == 0) throw new ErrorUsuario("Seleccione un video.");
            string ext = Path.GetExtension(archivo.FileName ?? "").ToLowerInvariant();
            if (!Extensiones.Contains(ext)) throw new ErrorUsuario("Solo se aceptan videos .mp4 o .webm.");
            if (archivo.ContentLength > MaxBytes) throw new ErrorUsuario("El video no debe superar " + (MaxBytes / 1048576) + " MB.");
            if (!FirmaValida(archivo.InputStream, ext)) throw new ErrorUsuario("El archivo no es un video " + ext + " válido.");

            var actuales = Archivos(ruta);
            Renumerar(ruta, actuales.Select(f => f.Name).ToList());     // deja 01-, 02-, ... y el nuevo va al final
            string baseNombre = Limpio(archivo.FileName);
            string nombre = (actuales.Count + 1).ToString("00") + "-" + baseNombre + ext;
            int i = 2;
            while (File.Exists(Path.Combine(ruta, nombre)))
                nombre = (actuales.Count + 1).ToString("00") + "-" + baseNombre + "-" + i++ + ext;

            string temporal = Path.Combine(ruta, "." + Guid.NewGuid().ToString("N") + ".subiendo");
            try
            {
                archivo.SaveAs(temporal);
                File.Move(temporal, Path.Combine(ruta, nombre));
            }
            finally { if (File.Exists(temporal)) File.Delete(temporal); }
            return "Video agregado. La pantalla de turnos lo reproducirá en unos segundos.";
        }

        private static string Validar(string ruta, string nombre)
        {
            nombre = Path.GetFileName(nombre ?? "");
            if (nombre.Length == 0 || !Archivos(ruta).Any(f => string.Equals(f.Name, nombre, StringComparison.OrdinalIgnoreCase)))
                throw new ErrorUsuario("El video ya no existe. Actualice la lista.");
            return nombre;
        }

        private static string Eliminar(string ruta, string nombre)
        {
            nombre = Validar(ruta, nombre);
            File.Delete(Path.Combine(ruta, nombre));
            Renumerar(ruta, Archivos(ruta).Select(f => f.Name).ToList());
            return "Video eliminado.";
        }

        private static string Mover(string ruta, string nombre, int direccion)
        {
            nombre = Validar(ruta, nombre);
            var orden = Archivos(ruta).Select(f => f.Name).ToList();
            int i = orden.FindIndex(n => string.Equals(n, nombre, StringComparison.OrdinalIgnoreCase)), j = i + direccion;
            if (j < 0 || j >= orden.Count) return "El video ya está en esa posición.";
            orden[i] = orden[j]; orden[j] = nombre;
            Renumerar(ruta, orden);
            return "Orden actualizado.";
        }

        // Renombra a 01-nombre, 02-nombre, ... según el orden recibido (en dos pasos para no chocar nombres)
        private static void Renumerar(string ruta, List<string> orden)
        {
            var cambios = new List<Tuple<string, string, string>>();
            for (int k = 0; k < orden.Count; k++)
            {
                string actual = orden[k];
                string sinPrefijo = Prefijo.Replace(actual, "");
                string nuevo = (k + 1).ToString("00") + "-" + sinPrefijo;
                if (!string.Equals(actual, nuevo, StringComparison.Ordinal))
                    cambios.Add(Tuple.Create(actual, "." + Guid.NewGuid().ToString("N") + ".tmp", nuevo));
            }
            foreach (var c in cambios) File.Move(Path.Combine(ruta, c.Item1), Path.Combine(ruta, c.Item2));
            foreach (var c in cambios) File.Move(Path.Combine(ruta, c.Item2), Path.Combine(ruta, c.Item3));
        }
    }
}
