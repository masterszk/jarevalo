using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;

namespace DPieCenter.Registros
{
    /// <summary>Reglas del expediente compartidas por la lista (alta) y la ficha (edición).</summary>
    public static class ExpedientesService
    {
        public const long TipoDui = 1, TipoPasaporte = 2, TipoResidente = 3, TipoSinDocumento = 4, TipoExtranjero = 5;     // CAT_TIPOSDOCUMENTOS
        public const int FotoLado = 320;                         // px del lado mayor
        public const int FotoMaxBytes = 5 * 1024 * 1024;          // archivo original

        private static readonly Regex EmailValido = new Regex(@"^[^@\s]+@[^@\s]+\.[^@\s]+$");
        private static readonly Regex Dui = new Regex(@"^\d{8}-\d$");
        private static readonly Regex Pasaporte = new Regex(@"^[A-Z0-9]{5,20}$");
        private static readonly Regex Residente = new Regex(@"^[A-Z0-9][A-Z0-9-]{3,19}$");
        private static readonly Regex Alfanumerico = new Regex(@"^[A-Z0-9][A-Z0-9 .-]{2,19}$");

        private static string T(string s) { return (s ?? "").Trim(); }

        /// <summary>
        /// Normaliza nacionalidad, país de los teléfonos, teléfonos (solo dígitos) y documento (mayúsculas)
        /// y devuelve el motivo por el que no se puede guardar, o null si es válido.
        /// </summary>
        public static string Validar(ExpedienteEditDto e, out DateTime nacimiento)
        {
            nacimiento = DateTime.MinValue;
            if (e == null) return "No se recibieron los datos del paciente.";
            var sv = PaisesRepository.ElSalvador();
            var pais = PaisesRepository.Obtener(e.Pais) ?? sv;
            var paisTel = PaisesRepository.Obtener(e.PaisTelefono) ?? pais;
            e.Pais = pais.Id; e.PaisTelefono = paisTel.Id;
            e.Celular = PaisesRepository.Digitos(e.Celular);
            e.Telefono = PaisesRepository.Digitos(e.Telefono);
            e.TelefonoEmergencia = PaisesRepository.Digitos(e.TelefonoEmergencia);
            e.Documento = T(e.Documento).ToUpperInvariant();

            if (T(e.Nombres) == "" || T(e.Apellidos) == "") return "Nombres y apellidos son requeridos.";
            if (e.TipoDocumento <= 0) return "Seleccione el tipo de documento.";
            string doc = e.Documento;
            if (e.TipoDocumento != TipoSinDocumento && doc == "") return "Ingrese el documento (o elija el tipo N/A).";
            if (e.TipoDocumento == TipoDui && pais.Iso2 != "SV") return "El DUI es el documento de los salvadoreños. Para " + pais.Nombre + " use pasaporte, carné de residente o el documento de identidad de su país.";
            if (e.TipoDocumento == TipoExtranjero && pais.Iso2 == "SV") return "Para un paciente salvadoreño use el DUI.";
            if (e.TipoDocumento == TipoDui && !Dui.IsMatch(doc)) return "El DUI debe tener el formato 00000000-0.";
            if (e.TipoDocumento == TipoPasaporte && !Pasaporte.IsMatch(doc)) return "El pasaporte debe tener de 5 a 20 letras o números, sin espacios ni guiones.";
            if (e.TipoDocumento == TipoResidente && !Residente.IsMatch(doc)) return "El carné de residente debe tener de 4 a 20 letras, números o guiones.";
            if (e.TipoDocumento == TipoExtranjero)
            {
                var nombreDoc = pais.DocumentoNombre ?? "documento de identidad";
                if (pais.MascaraDocumento != null)
                {
                    if (!PaisesRepository.RegexMascara(pais.MascaraDocumento).IsMatch(doc))
                        return "El " + nombreDoc + " de " + pais.Nombre + " debe tener el formato " + Ejemplo(pais.MascaraDocumento) + ".";
                }
                else if (!Alfanumerico.IsMatch(doc)) return "El " + nombreDoc + " debe tener de 3 a 20 letras o números.";
            }
            if (!DateTime.TryParseExact(T(e.Nacimiento), "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out nacimiento)
                || nacimiento > DateTime.Today || nacimiento < DateTime.Today.AddYears(-120))
                return "La fecha de nacimiento no es válida.";
            if (e.Sexo <= 0) return "Seleccione el sexo.";
            string largo = paisTel.TelefonoMin == paisTel.TelefonoMax ? paisTel.TelefonoMin + " dígitos" : "de " + paisTel.TelefonoMin + " a " + paisTel.TelefonoMax + " dígitos";
            Func<string, bool> telOk = t => t.Length >= paisTel.TelefonoMin && t.Length <= paisTel.TelefonoMax;
            if (!telOk(e.Celular)) return "El celular de " + paisTel.Nombre + " (+" + paisTel.Codigo + ") debe tener " + largo + ".";
            if (e.Telefono != "" && !telOk(e.Telefono)) return "El teléfono de " + paisTel.Nombre + " debe tener " + largo + ".";
            if (!EmailValido.IsMatch(T(e.Email))) return "El email no es válido.";
            if (T(e.PersonaEmergencia) == "") return "Ingrese el contacto de emergencia.";
            if (!telOk(e.TelefonoEmergencia)) return "El teléfono de emergencia de " + paisTel.Nombre + " debe tener " + largo + ".";
            if (e.Municipio <= 0) return "Seleccione el municipio.";
            if (T(e.Direccion) == "") return "Ingrese la dirección.";
            return null;
        }

        /// <summary>Ejemplo legible de una máscara: # → 0, A → A, * → X.</summary>
        public static string Ejemplo(string mascara) { return (mascara ?? "").Replace('#', '0').Replace('*', 'X'); }

        /// <summary>Crea (accion 1) o actualiza (accion 2) con EXP_SP_Expedientes. Devuelve null si se guardó, o el motivo.</summary>
        public static string Guardar(ExpedienteEditDto e, int accion, string usuario)
        {
            DateTime nacimiento;
            string error = Validar(e, out nacimiento);
            if (error != null) return error;

            string documento = e.TipoDocumento == TipoSinDocumento ? "" : T(e.Documento);
            using (SqlProcess sql = new SqlProcess())
            {
                string resp = sql.mtdREG_Expedientes(accion == 1 ? 0 : e.Id, T(e.Nombres), T(e.Apellidos), e.TipoDocumento.ToString(CultureInfo.InvariantCulture)
                    , documento, T(e.Registro).ToUpperInvariant(), nacimiento.ToString("yyyyMMdd", CultureInfo.InvariantCulture)
                    , T(e.Telefono), T(e.Celular), T(e.Email), T(e.TelefonoEmergencia), T(e.PersonaEmergencia)
                    , e.Municipio, T(e.Direccion), e.Sexo
                    , e.Facebook ? 1 : 0, e.Instagram ? 1 : 0, e.Buscador ? 1 : 0, e.Recomendado ? 1 : 0, usuario, accion
                    , e.TikTok ? 1 : 0, e.WhatsApp ? 1 : 0, e.Otros ? 1 : 0, e.Pais, e.PaisTelefono);
                return resp == "OK" ? null : (resp ?? "").Replace("\r", "").Replace("\n", "");
            }
        }

        /// <summary>
        /// Valida que el archivo sea una imagen y la reduce a JPEG de FotoLado px como máximo.
        /// Devuelve el data URL para guardar en EXP_EXPEDIENTES.Foto.
        /// </summary>
        public static string NormalizarFoto(string base64)
        {
            return "data:image/jpeg;base64," + Convert.ToBase64String(ImagenJpeg(base64, FotoLado));
        }

        /// <summary>Valida que el base64 (o data URL) sea una imagen de hasta 5 MB y la devuelve como JPEG de "lado" px como máximo.</summary>
        public static byte[] ImagenJpeg(string base64, int lado)
        {
            string datos = (base64 ?? "").Trim();
            int coma = datos.IndexOf(',');
            if (datos.StartsWith("data:", StringComparison.OrdinalIgnoreCase) && coma > 0) datos = datos.Substring(coma + 1);

            byte[] bytes;
            try { bytes = Convert.FromBase64String(datos); }
            catch (FormatException) { throw new ArgumentException("El archivo no es una imagen válida."); }
            if (bytes.Length == 0) throw new ArgumentException("Seleccione una imagen.");
            if (bytes.Length > FotoMaxBytes) throw new ArgumentException("La imagen no puede superar 5 MB.");

            try
            {
                using (var ms = new MemoryStream(bytes))
                using (var original = Image.FromStream(ms, true, true))
                {
                    CorregirOrientacion(original);
                    double escala = Math.Min(1.0, (double)lado / Math.Max(original.Width, original.Height));
                    int w = Math.Max(1, (int)Math.Round(original.Width * escala)), h = Math.Max(1, (int)Math.Round(original.Height * escala));

                    using (var lienzo = new Bitmap(w, h))
                    using (var g = Graphics.FromImage(lienzo))
                    using (var salida = new MemoryStream())
                    {
                        g.Clear(Color.White);
                        g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                        g.SmoothingMode = SmoothingMode.HighQuality;
                        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                        g.DrawImage(original, 0, 0, w, h);

                        var jpeg = ImageCodecInfo.GetImageEncoders().First(c => c.FormatID == ImageFormat.Jpeg.Guid);
                        using (var p = new EncoderParameters(1))
                        {
                            p.Param[0] = new EncoderParameter(Encoder.Quality, 85L);
                            lienzo.Save(salida, jpeg, p);
                        }
                        return salida.ToArray();
                    }
                }
            }
            catch (ArgumentException) { throw new ArgumentException("El archivo no es una imagen válida."); }
            catch (OutOfMemoryException) { throw new ArgumentException("El archivo no es una imagen válida."); }
        }

        // Las fotos del celular traen la rotación en EXIF (0x0112)
        private static void CorregirOrientacion(Image img)
        {
            const int Orientacion = 0x0112;
            if (!img.PropertyIdList.Contains(Orientacion)) return;
            switch (img.GetPropertyItem(Orientacion).Value[0])
            {
                case 3: img.RotateFlip(RotateFlipType.Rotate180FlipNone); break;
                case 6: img.RotateFlip(RotateFlipType.Rotate90FlipNone); break;
                case 8: img.RotateFlip(RotateFlipType.Rotate270FlipNone); break;
            }
        }
    }
}
