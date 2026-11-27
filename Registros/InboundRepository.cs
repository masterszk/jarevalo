using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;

namespace DPieCenter.Registros
{
    // ===== Modelos de Inbound (Registros/frm_Inbound.aspx) =====

    public class InboundDto
    {
        public long Id { get; set; }
        public string Telefono { get; set; }
        public string NombreCliente { get; set; }
        public bool Contesto { get; set; }
        public string UsuarioCrea { get; set; }
        /// <summary>yyyy-MM-ddTHH:mm:ss</summary>
        public string FechaCrea { get; set; }
        public string UsuarioModifica { get; set; }
        public string FechaModificacion { get; set; }
        /// <summary>Paciente que ya tiene ese teléfono (0 si no hay).</summary>
        public long IdExpediente { get; set; }
        public string Paciente { get; set; }
    }

    public class FiltroInboundDto
    {
        /// <summary>yyyy-MM-dd; vacío = sin límite.</summary>
        public string Desde { get; set; }
        public string Hasta { get; set; }
        /// <summary>1 contestó, 0 pendiente, -1 todos.</summary>
        public int Contesto { get; set; }
        public string Texto { get; set; }
    }

    public class InboundResumenDto
    {
        public int Pendientes { get; set; }
        public int Hoy { get; set; }
        public int ContestadosHoy { get; set; }
        public int Mes { get; set; }
    }

    public class InboundListaDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public InboundResumenDto Resumen { get; set; }
        public List<InboundDto> Items { get; set; }
    }

    /// <summary>Acceso a dbo.REG_SP_Inbound (Registros/sql/REG_Inbound.sql).</summary>
    public static class InboundRepository
    {
        private static readonly CultureInfo Inv = CultureInfo.InvariantCulture;

        private static string Cn
        {
            get { return ConfigurationManager.ConnectionStrings["conexionDiarypro"].ConnectionString; }
        }

        private static string Txt(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? "" : Convert.ToString(v).Trim(); }
        private static long Num(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? 0 : Convert.ToInt64(v); }
        private static DateTime? Fecha(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? (DateTime?)null : Convert.ToDateTime(v); }
        private static string Iso(DateTime? d) { return d.HasValue ? d.Value.ToString("yyyy-MM-ddTHH:mm:ss", Inv) : ""; }

        private static SqlCommand Sp(SqlConnection cn, int accion)
        {
            var cmd = new SqlCommand("REG_SP_Inbound", cn) { CommandType = CommandType.StoredProcedure };
            cmd.Parameters.Add("@accion", SqlDbType.Int).Value = accion;
            cmd.Parameters.Add("@sucursal", SqlDbType.Int).Value = Sesion.Sucursal;     // registros de la sucursal en la que trabaja
            return cmd;
        }

        public static List<InboundDto> Lista(DateTime? desde, DateTime? hasta, int contesto, string texto)
        {
            var lista = new List<InboundDto>();
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, 1))
            {
                cmd.Parameters.Add("@desde", SqlDbType.Date).Value = (object)desde ?? DBNull.Value;
                cmd.Parameters.Add("@hasta", SqlDbType.Date).Value = (object)hasta ?? DBNull.Value;
                cmd.Parameters.Add("@contesto", SqlDbType.Int).Value = contesto;
                cmd.Parameters.Add("@texto", SqlDbType.NVarChar, 100).Value = string.IsNullOrWhiteSpace(texto) ? (object)DBNull.Value : texto.Trim();
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                        lista.Add(new InboundDto
                        {
                            Id = Num(rd, "Id_Inbound"),
                            Telefono = Txt(rd, "Telefono"),
                            NombreCliente = Txt(rd, "NombreCliente"),
                            Contesto = Convert.ToBoolean(rd["Contesto"]),
                            UsuarioCrea = Txt(rd, "UsuarioCrea"),
                            FechaCrea = Iso(Fecha(rd, "FechaCrea")),
                            UsuarioModifica = Txt(rd, "UsuarioModifica"),
                            FechaModificacion = Iso(Fecha(rd, "FechaModificacion")),
                            IdExpediente = Num(rd, "Id_Expediente"),
                            Paciente = Txt(rd, "Paciente")
                        });
            }
            return lista;
        }

        public static InboundResumenDto Resumen()
        {
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, 6))
            {
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    return rd.Read()
                        ? new InboundResumenDto { Pendientes = (int)Num(rd, "Pendientes"), Hoy = (int)Num(rd, "Hoy"), ContestadosHoy = (int)Num(rd, "ContestadosHoy"), Mes = (int)Num(rd, "Mes") }
                        : new InboundResumenDto();
            }
        }

        /// <summary>accion 2 agregar (id = 0), 3 modificar.</summary>
        public static long Guardar(long id, string telefono, string nombre, bool contesto, string usuario)
        {
            return Escalar(id > 0 ? 3 : 2, id, usuario, p =>
            {
                p.Add("@telefono", SqlDbType.VarChar, 20).Value = (object)telefono ?? DBNull.Value;
                p.Add("@nombre", SqlDbType.NVarChar, 150).Value = (object)nombre ?? DBNull.Value;
                p.Add("@contesto", SqlDbType.Int).Value = contesto ? 1 : 0;
            });
        }

        public static void MarcarContesto(long id, bool contesto, string usuario)
        {
            Escalar(4, id, usuario, p => p.Add("@contesto", SqlDbType.Int).Value = contesto ? 1 : 0);
        }

        public static void Eliminar(long id, string usuario)
        {
            Escalar(5, id, usuario, p => { });
        }

        private static long Escalar(int accion, long id, string usuario, Action<SqlParameterCollection> parametros)
        {
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, accion))
            {
                cmd.Parameters.Add("@id", SqlDbType.BigInt).Value = id;
                cmd.Parameters.Add("@usuario", SqlDbType.VarChar, 50).Value = usuario;
                parametros(cmd.Parameters);
                cn.Open();
                var v = cmd.ExecuteScalar();
                return v == null || v == DBNull.Value ? 0 : Convert.ToInt64(v);
            }
        }
    }
}
