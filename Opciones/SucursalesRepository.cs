using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;

namespace DPieCenter.Opciones
{
    public class SucursalDto
    {
        public int Id { get; set; }
        public string Codigo { get; set; }
        public string Nombre { get; set; }
        public bool EsMatriz { get; set; }
        public string Direccion { get; set; }
        public string Telefono { get; set; }
        public string CodDepartamento { get; set; }
        public string CodMunicipio { get; set; }
        public string CodDistrito { get; set; }
        public string CodEstableMH { get; set; }
        public string CodEstable { get; set; }
        public string CodPuntoVentaMH { get; set; }
        public string CodPuntoVenta { get; set; }
        public bool Activo { get; set; }
        public int Usuarios { get; set; }
        public int Especialistas { get; set; }
        public int Citas { get; set; }
        public string Usuario { get; set; }
        public string Fecha { get; set; }
    }

    public class EspecialistaSucursalDto
    {
        public long Id { get; set; }
        public string Nombre { get; set; }
        public bool Activo { get; set; }
        public bool Asignado { get; set; }
    }

    /// <summary>Acceso a dbo.SUC_SP_Sucursales (Opciones/sql/SUC_Sucursales.sql).</summary>
    public static class SucursalesRepository
    {
        private static string Cn { get { return ConfigurationManager.ConnectionStrings["conexionDiarypro"].ConnectionString; } }

        private static SqlCommand Sp(SqlConnection cn, int accion)
        {
            var cmd = new SqlCommand("dbo.SUC_SP_Sucursales", cn) { CommandType = CommandType.StoredProcedure };
            cmd.Parameters.Add("@accion", SqlDbType.Int).Value = accion;
            return cmd;
        }

        private static string Txt(IDataRecord r, string c) { var v = r[c]; return v == DBNull.Value ? "" : Convert.ToString(v).Trim(); }

        /// <summary>Sucursales activas (para listas desplegables).</summary>
        public static List<CatalogoItemDto> Activas()
        {
            var lista = new List<CatalogoItemDto>();
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, 6))
            {
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read()) lista.Add(new CatalogoItemDto { Id = Convert.ToInt64(rd["Id"]), Texto = Txt(rd, "Texto") });
            }
            return lista;
        }

        public static List<SucursalDto> Lista()
        {
            var lista = new List<SucursalDto>();
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, 1))
            {
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                        lista.Add(new SucursalDto
                        {
                            Id = Convert.ToInt32(rd["Id_Sucursal"]), Codigo = Txt(rd, "Codigo"), Nombre = Txt(rd, "Nombre"),
                            EsMatriz = Convert.ToBoolean(rd["EsMatriz"]), Direccion = Txt(rd, "Direccion"), Telefono = Txt(rd, "Telefono"),
                            CodDepartamento = Txt(rd, "CodDepartamento"), CodMunicipio = Txt(rd, "CodMunicipio"), CodDistrito = Txt(rd, "CodDistrito"),
                            CodEstableMH = Txt(rd, "CodEstableMH"), CodEstable = Txt(rd, "CodEstable"),
                            CodPuntoVentaMH = Txt(rd, "CodPuntoVentaMH"), CodPuntoVenta = Txt(rd, "CodPuntoVenta"),
                            Activo = Convert.ToBoolean(rd["IsActivo"]), Usuarios = Convert.ToInt32(rd["Usuarios"]),
                            Especialistas = Convert.ToInt32(rd["Especialistas"]), Citas = Convert.ToInt32(rd["Citas"]),
                            Usuario = Txt(rd, "Usuario"),
                            Fecha = rd["Fecha"] == DBNull.Value ? "" : Convert.ToDateTime(rd["Fecha"]).ToString("dd/MM/yyyy", System.Globalization.CultureInfo.InvariantCulture)
                        });
            }
            return lista;
        }

        /// <summary>Datos de una sucursal (para el DTE y la pantalla). null si no existe.</summary>
        public static SucursalDto Obtener(int id)
        {
            return Lista().Find(s => s.Id == id);
        }

        public static List<EspecialistaSucursalDto> Especialistas(int sucursal)
        {
            var lista = new List<EspecialistaSucursalDto>();
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, 2))
            {
                cmd.Parameters.Add("@id", SqlDbType.Int).Value = sucursal;
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                        lista.Add(new EspecialistaSucursalDto
                        {
                            Id = Convert.ToInt64(rd["Id"]), Nombre = Txt(rd, "Nombre"),
                            Activo = Convert.ToBoolean(rd["Activo"]), Asignado = Convert.ToBoolean(rd["Asignado"])
                        });
            }
            return lista;
        }

        public static long Guardar(SucursalDto s, string usuario)
        {
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, 3))
            {
                var p = cmd.Parameters;
                p.Add("@id", SqlDbType.Int).Value = s.Id;
                p.Add("@codigo", SqlDbType.VarChar, 10).Value = (object)s.Codigo ?? DBNull.Value;
                p.Add("@nombre", SqlDbType.VarChar, 100).Value = (object)s.Nombre ?? DBNull.Value;
                p.Add("@direccion", SqlDbType.VarChar, 250).Value = (object)s.Direccion ?? DBNull.Value;
                p.Add("@telefono", SqlDbType.VarChar, 20).Value = (object)s.Telefono ?? DBNull.Value;
                p.Add("@codDepartamento", SqlDbType.Char, 2).Value = (object)s.CodDepartamento ?? DBNull.Value;
                p.Add("@codMunicipio", SqlDbType.Char, 2).Value = (object)s.CodMunicipio ?? DBNull.Value;
                p.Add("@codDistrito", SqlDbType.Char, 2).Value = (object)s.CodDistrito ?? DBNull.Value;
                p.Add("@codEstableMH", SqlDbType.Char, 4).Value = (object)s.CodEstableMH ?? DBNull.Value;
                p.Add("@codEstable", SqlDbType.Char, 4).Value = (object)s.CodEstable ?? DBNull.Value;
                p.Add("@codPuntoVentaMH", SqlDbType.Char, 4).Value = (object)s.CodPuntoVentaMH ?? DBNull.Value;
                p.Add("@codPuntoVenta", SqlDbType.Char, 4).Value = (object)s.CodPuntoVenta ?? DBNull.Value;
                p.Add("@activo", SqlDbType.Bit).Value = s.Activo;
                p.Add("@usuario", SqlDbType.VarChar, 20).Value = usuario;
                cn.Open();
                return Convert.ToInt64(cmd.ExecuteScalar());
            }
        }

        public static void Estado(int id, bool activo, string usuario)
        {
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, 4))
            {
                cmd.Parameters.Add("@id", SqlDbType.Int).Value = id;
                cmd.Parameters.Add("@activo", SqlDbType.Bit).Value = activo;
                cmd.Parameters.Add("@usuario", SqlDbType.VarChar, 20).Value = usuario;
                cn.Open();
                cmd.ExecuteNonQuery();
            }
        }

        public static void AsignarEspecialistas(int id, IEnumerable<long> especialistas, string usuario)
        {
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, 5))
            {
                cmd.Parameters.Add("@id", SqlDbType.Int).Value = id;
                cmd.Parameters.Add("@especialistas", SqlDbType.VarChar, -1).Value = string.Join(",", especialistas ?? new long[0]);
                cmd.Parameters.Add("@usuario", SqlDbType.VarChar, 20).Value = usuario;
                cn.Open();
                cmd.ExecuteNonQuery();
            }
        }
    }
}
