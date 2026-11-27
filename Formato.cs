using System;
using System.Globalization;

namespace DPieCenter
{
    /// <summary>
    /// Formato de horas para mostrar en pantalla: reloj de 12 horas (02:30 PM).
    /// Solo para texto visible: los valores que se envían de vuelta al servidor, el JSON de Hacienda
    /// y las bitácoras conservan el formato de 24 horas.
    /// </summary>
    public static class Formato
    {
        private static readonly CultureInfo Inv = CultureInfo.InvariantCulture;

        /// <summary>02:30 PM</summary>
        public static string Hora(DateTime d) { return d.ToString("hh:mm tt", Inv); }
        public static string Hora(DateTime? d) { return d.HasValue ? Hora(d.Value) : ""; }
        public static string Hora(TimeSpan t) { return DateTime.Today.Add(t).ToString("hh:mm tt", Inv); }

        /// <summary>02:30:15 PM</summary>
        public static string HoraSegundos(DateTime d) { return d.ToString("hh:mm:ss tt", Inv); }

        private static readonly System.Text.RegularExpressions.Regex ReHora =
            new System.Text.RegularExpressions.Regex(@"\b([01]\d|2[0-3]):([0-5]\d)(:[0-5]\d)?\b(?!\s*[AaPp]\.?\s?[Mm])");

        /// <summary>Convierte las horas de 24 h dentro de un texto guardado en la base ("08:00", "14:30 - 15:30") a 12 h.</summary>
        public static string HoraTexto(string texto)
        {
            if (string.IsNullOrEmpty(texto)) return texto ?? "";
            return ReHora.Replace(texto, m =>
            {
                int h = int.Parse(m.Groups[1].Value, Inv);
                return (h % 12 == 0 ? 12 : h % 12).ToString("00", Inv) + ":" + m.Groups[2].Value + m.Groups[3].Value + (h < 12 ? " AM" : " PM");
            });
        }

        /// <summary>31/10/2026 02:30 PM</summary>
        public static string FechaHora(DateTime d) { return d.ToString("dd/MM/yyyy hh:mm tt", Inv); }
        public static string FechaHora(DateTime? d) { return d.HasValue ? FechaHora(d.Value) : ""; }
    }
}
