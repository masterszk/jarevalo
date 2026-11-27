using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Web.Hosting;
using System.Web.Services;

namespace DPieCenter.Registros
{
    /// <summary>
    /// Pantalla de turnos para la sala de espera. Página completa (no se carga con AjaxLink) pensada para un televisor:
    /// 70% del ancho para videos publicitarios (carpeta assets/publicidad) y 30% para los turnos.
    /// Página pública, sin inicio de sesión: es para los pacientes en general y se presenta con su propio enlace.
    /// En pantalla solo se muestra el primer nombre y el primer apellido; el texto del audio (Anuncio) lleva el nombre completo
    /// del paciente y del especialista. Nunca datos clínicos ni de contacto.
    /// Parámetro opcional ?esp=Id_Especialista.
    /// </summary>
    public partial class frm_TurnosPacientes : System.Web.UI.Page
    {
        private const int MaxSiguientes = 8;
        private const string CarpetaVideos = "~/assets/publicidad";
        private static readonly string[] ExtensionesVideo = { ".mp4", ".webm" };
        private static readonly CultureInfo Es = new CultureInfo("es-SV");

        /// <summary>Sucursal que muestra la pantalla: ?suc=Id del enlace, o la del usuario que la abre (0 = todas).</summary>
        protected int SucursalPantalla { get; private set; }

        protected void Page_Load(object sender, EventArgs e)
        {
            int suc;
            SucursalPantalla = int.TryParse(Request.QueryString["suc"], out suc) && suc > 0 ? suc : Sesion.Sucursal;
        }

        [WebMethod]
        public static TurnosDto ObtenerTurnos(long especialista, int sucursal)
        {
            try
            {
                var cola = ProcedimientosRepository.Cola(especialista, Math.Max(0, sucursal));
                string horaActual = DateTime.Now.ToString("HH", CultureInfo.InvariantCulture) + ":00";

                var atendiendo = cola.Where(c => c.Estado == "I")
                    .OrderBy(c => c.Especialista)
                    .Select(c => Turno(c, "I"))
                    .ToList();

                // El que sigue de cada especialista (mayor tiempo de espera) va primero; luego los que están en sala
                // o tienen cita desde la hora en curso (no se muestran citas pasadas sin atender)
                var siguientes = cola.Where(c => c.Estado != "I" && (c.Sigue || c.Estado == "S" || string.CompareOrdinal(c.Hora, horaActual) >= 0))
                    .OrderByDescending(c => c.Sigue)
                    .Take(MaxSiguientes)
                    .Select(c =>
                    {
                        var t = Turno(c, c.Estado == "S" ? "S" : "P");
                        t.Sigue = c.Sigue;
                        return t;
                    })
                    .ToList();

                return new TurnosDto
                {
                    Ok = true,
                    Version = Version(),
                    HoraServidor = DateTime.Now.ToString("yyyy-MM-ddTHH:mm:ss", CultureInfo.InvariantCulture),
                    Atendiendo = atendiendo,
                    Siguientes = siguientes,
                    Videos = Videos()
                };
            }
            catch (Exception ex)
            {
                System.Diagnostics.Trace.TraceError("Turnos: " + ex);
                return new TurnosDto { Ok = false, Mensaje = "No fue posible actualizar los turnos." };
            }
        }

        // Versión de la pantalla (fecha de los archivos de la página, su script y la aplicación). El televisor deja la página
        // abierta todo el día: si cambia la versión, se recarga sola para usar el código nuevo (antes seguía con el anterior).
        private static string Version()
        {
            long v = 0;
            foreach (var f in new[] { "~/Registros/frm_TurnosPacientes.aspx", "~/assets/js/turnos-pacientes.js", "~/assets/css/turnos-pacientes.css", "~/bin/DPieCenter.dll" })
            {
                string ruta = HostingEnvironment.MapPath(f);
                if (ruta != null && File.Exists(ruta)) v = Math.Max(v, File.GetLastWriteTimeUtc(ruta).Ticks);
            }
            return v.ToString(CultureInfo.InvariantCulture);
        }

        // Videos .mp4/.webm de assets/publicidad, en orden alfabético (nombre los archivos 01-..., 02-... para ordenar)
        private static List<string> Videos()
        {
            string ruta = HostingEnvironment.MapPath(CarpetaVideos);
            if (ruta == null || !Directory.Exists(ruta)) return new List<string>();
            return Directory.GetFiles(ruta)
                .Where(f => ExtensionesVideo.Contains(Path.GetExtension(f).ToLowerInvariant()))
                .OrderBy(f => Path.GetFileName(f), StringComparer.OrdinalIgnoreCase)
                .Select(f => "../assets/publicidad/" + Uri.EscapeDataString(Path.GetFileName(f)))
                .ToList();
        }

        private static TurnoDto Turno(ColaItemDto c, string estado)
        {
            return new TurnoDto
            {
                Clave = c.IdCita,
                Paciente = NombrePublico(c.Nombres, c.Apellidos),
                Especialista = c.Especialista,
                Hora = c.Hora,
                Estado = estado,
                // En pantalla solo primer nombre y primer apellido; en el audio, los nombres completos para que el paciente se reconozca
                Anuncio = NombreCompleto(c.Nombres, c.Apellidos) + ", pase con " + Titulo(string.IsNullOrWhiteSpace(c.EspecialistaCompleto) ? c.Especialista : c.EspecialistaCompleto)
            };
        }

        private static string NombreCompleto(string nombres, string apellidos)
        {
            return string.Join(" ", Palabras(nombres + " " + apellidos)
                .Select((p, i) => i > 0 && Particulas.Contains(p.ToLower(Es)) ? p.ToLower(Es) : Titulo(p)));
        }

        private static readonly string[] Particulas = { "de", "del", "la", "las", "los", "y", "san", "santa" };

        // Primer nombre y primer apellido: "IVAN ALEJANDRO" "ASCENCIO HERNANDEZ" -> "Ivan Ascencio";
        // "ANA" "DE LA O LOPEZ" -> "Ana de la O"
        private static string NombrePublico(string nombres, string apellidos)
        {
            string nombre = Palabras(nombres).FirstOrDefault() ?? "";
            var ap = new List<string>();
            foreach (var p in Palabras(apellidos))
            {
                ap.Add(p);
                if (!Particulas.Contains(p.ToLower(Es))) break;     // termina en la primera palabra que no es partícula
            }
            string apellido = string.Join(" ", ap.Select((p, i) => i < ap.Count - 1 && Particulas.Contains(p.ToLower(Es)) ? p.ToLower(Es) : Titulo(p)));
            return (Titulo(nombre) + " " + apellido).Trim();
        }

        private static string[] Palabras(string s)
        {
            return (s ?? "").Trim().Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
        }

        private static string Titulo(string s) { return Es.TextInfo.ToTitleCase((s ?? "").ToLower(Es)); }
    }
}
