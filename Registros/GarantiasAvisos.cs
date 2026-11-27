using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;
using System.Linq;

namespace DPieCenter.Registros
{
    // ===== Campana de la barra superior: garantías de servicios que el especialista no ha visto =====

    public class GarantiaAvisoDto
    {
        public long Id { get; set; }
        public string Especialista { get; set; }
        public string Paciente { get; set; }
        /// <summary>dd/MM/yyyy del procedimiento reclamado; vacío si no tiene.</summary>
        public string FechaProcedimiento { get; set; }
        public string Tratamientos { get; set; }
        public string Detalle { get; set; }
        public string Usuario { get; set; }
        /// <summary>dd/MM/yyyy hh:mm AM/PM en que se registró (o modificó).</summary>
        public string Fecha { get; set; }
    }

    public class GarantiaConteoDto
    {
        public string Especialista { get; set; }
        public int Cantidad { get; set; }
    }

    public class GarantiasAvisoRespuestaDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        /// <summary>false: el usuario no es especialista ni administrador (no se muestra la campana).</summary>
        public bool Visible { get; set; }
        /// <summary>true: ve sus garantías y al abrirlas quedan vistas; false (administrador): ve las de todos sin marcarlas.</summary>
        public bool EsEspecialista { get; set; }
        public int Total { get; set; }
        public List<GarantiaAvisoDto> Items { get; set; }
        public List<GarantiaConteoDto> PorEspecialista { get; set; }
    }

    /// <summary>Acceso a dbo.EXP_SP_Reclamos acciones 7 y 8 (Registros/sql/EXP_Reclamos.sql).</summary>
    public static class GarantiasAvisos
    {
        private static readonly CultureInfo Inv = CultureInfo.InvariantCulture;
        private static string Cn { get { return ConfigurationManager.ConnectionStrings["conexionDiarypro"].ConnectionString; } }
        private static string Txt(IDataRecord r, string c) { var v = r[c]; return v == DBNull.Value ? "" : Convert.ToString(v).Trim(); }

        /// <summary>especialista = 0: las no vistas de todos los especialistas.</summary>
        public static List<GarantiaAvisoDto> NoVistas(long especialista)
        {
            var lista = new List<GarantiaAvisoDto>();
            using (var cn = new SqlConnection(Cn))
            using (var cmd = new SqlCommand("dbo.EXP_SP_Reclamos", cn) { CommandType = CommandType.StoredProcedure })
            {
                cmd.Parameters.Add("@accion", SqlDbType.Int).Value = 7;
                cmd.Parameters.Add("@especialista", SqlDbType.BigInt).Value = especialista;
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                    {
                        var fp = rd["FechaProcedimiento"]; var f = rd["Fecha"];
                        lista.Add(new GarantiaAvisoDto
                        {
                            Id = Convert.ToInt64(rd["Id_Reclamo"]),
                            Especialista = Txt(rd, "Especialista"),
                            Paciente = Txt(rd, "Paciente"),
                            FechaProcedimiento = fp == DBNull.Value ? "" : Convert.ToDateTime(fp).ToString("dd/MM/yyyy", Inv),
                            Tratamientos = Txt(rd, "Tratamientos"),
                            Detalle = Txt(rd, "Reclamo"),
                            Usuario = Txt(rd, "Usuario"),
                            Fecha = f == DBNull.Value ? "" : Convert.ToDateTime(f).ToString("dd/MM/yyyy", Inv) + " " + Formato.Hora(Convert.ToDateTime(f))
                        });
                    }
            }
            return lista;
        }

        /// <summary>Marca como vistas las garantías no vistas del especialista (id > 0: solo esa). Devuelve cuántas.</summary>
        public static int MarcarVistas(long especialista, long id, string usuario)
        {
            using (var cn = new SqlConnection(Cn))
            using (var cmd = new SqlCommand("dbo.EXP_SP_Reclamos", cn) { CommandType = CommandType.StoredProcedure })
            {
                cmd.Parameters.Add("@accion", SqlDbType.Int).Value = 8;
                cmd.Parameters.Add("@especialista", SqlDbType.BigInt).Value = especialista;
                cmd.Parameters.Add("@id", SqlDbType.BigInt).Value = id;
                cmd.Parameters.Add("@user", SqlDbType.VarChar, 20).Value = usuario;
                cn.Open();
                return Convert.ToInt32(cmd.ExecuteScalar());
            }
        }

        /// <summary>Datos de la campana para el usuario de la sesión.</summary>
        public static GarantiasAvisoRespuestaDto ParaUsuario(string usuario, bool esAdministrador)
        {
            var esp = ProcedimientosRepository.EspecialistaDeUsuario(usuario);
            if (esp == null && !esAdministrador) return new GarantiasAvisoRespuestaDto { Ok = true, Visible = false };

            var lista = NoVistas(esp != null ? esp.Id : 0);
            return new GarantiasAvisoRespuestaDto
            {
                Ok = true,
                Visible = true,
                EsEspecialista = esp != null,
                Total = lista.Count,
                Items = lista.Take(15).ToList(),
                PorEspecialista = lista.GroupBy(x => x.Especialista)
                    .Select(g => new GarantiaConteoDto { Especialista = g.Key, Cantidad = g.Count() })
                    .OrderByDescending(g => g.Cantidad).ThenBy(g => g.Especialista).ToList()
            };
        }
    }
}
