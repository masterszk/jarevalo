using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;

namespace DPieCenter.Registros
{
    /// <summary>País de CAT_PAISES con el formato de teléfono y documento (Registros/sql/CAT_Paises.sql).</summary>
    public class PaisDto
    {
        public int Id { get; set; }
        public string Iso2 { get; set; }
        public string Nombre { get; set; }
        /// <summary>Código telefónico internacional sin "+".</summary>
        public string Codigo { get; set; }
        public int TelefonoMin { get; set; }
        public int TelefonoMax { get; set; }
        /// <summary># = dígito; el resto se escribe tal cual. null: sin formato.</summary>
        public string MascaraTelefono { get; set; }
        /// <summary>Documento de identidad del país (DUI, DPI, DNI...).</summary>
        public string DocumentoNombre { get; set; }
        /// <summary># = dígito, A = letra, * = letra o dígito. null: libre.</summary>
        public string MascaraDocumento { get; set; }
    }

    public static class PaisesRepository
    {
        private static List<PaisDto> _cache;
        private static DateTime _leido;
        private static readonly object Bloqueo = new object();

        private static string Cn { get { return ConfigurationManager.ConnectionStrings["conexionDiarypro"].ConnectionString; } }

        /// <summary>Países activos (El Salvador primero). Se guardan en memoria 30 minutos.</summary>
        public static List<PaisDto> Lista()
        {
            lock (Bloqueo)
            {
                if (_cache != null && DateTime.Now - _leido < TimeSpan.FromMinutes(30)) return _cache;
                var l = new List<PaisDto>();
                using (var cn = new SqlConnection(Cn))
                using (var cmd = new SqlCommand("dbo.CAT_SP_Paises", cn) { CommandType = CommandType.StoredProcedure })
                {
                    cn.Open();
                    using (var rd = cmd.ExecuteReader())
                        while (rd.Read())
                            l.Add(new PaisDto
                            {
                                Id = Convert.ToInt32(rd["Id_Pais"]),
                                Iso2 = Convert.ToString(rd["Iso2"]).Trim(),
                                Nombre = Convert.ToString(rd["Nombre"]).Trim(),
                                Codigo = Convert.ToString(rd["CodigoTelefono"]).Trim(),
                                TelefonoMin = Convert.ToInt32(rd["TelefonoMin"]),
                                TelefonoMax = Convert.ToInt32(rd["TelefonoMax"]),
                                MascaraTelefono = rd["MascaraTelefono"] == DBNull.Value ? null : Convert.ToString(rd["MascaraTelefono"]),
                                DocumentoNombre = rd["DocumentoNombre"] == DBNull.Value ? null : Convert.ToString(rd["DocumentoNombre"]),
                                MascaraDocumento = rd["MascaraDocumento"] == DBNull.Value ? null : Convert.ToString(rd["MascaraDocumento"])
                            });
                }
                _cache = l; _leido = DateTime.Now;
                return l;
            }
        }

        public static PaisDto Obtener(int id) { return Lista().FirstOrDefault(p => p.Id == id); }
        public static PaisDto ElSalvador() { return Lista().FirstOrDefault(p => p.Iso2 == "SV"); }

        /// <summary>Regex de una máscara (# dígito, A letra, * letra o dígito).</summary>
        public static Regex RegexMascara(string mascara)
        {
            var sb = new StringBuilder("^");
            foreach (char c in mascara)
                sb.Append(c == '#' ? "\\d" : c == 'A' ? "[A-ZÑ]" : c == '*' ? "[A-Z0-9]" : Regex.Escape(c.ToString()));
            return new Regex(sb.Append("$").ToString());
        }

        public static string Digitos(string s) { return new string((s ?? "").Where(char.IsDigit).ToArray()); }
    }
}
