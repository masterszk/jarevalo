using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Drawing.Imaging;
using System.Globalization;
using System.IO;
using System.Security.Cryptography;
using QRCoder;

namespace DPieCenter.Registros
{
    // ===== Modelos de cupones de descuento (Registros/frm_ListaCupones.aspx y caja) =====

    public class CuponDto
    {
        public long Id { get; set; }
        public string Codigo { get; set; }
        public string Asignado { get; set; }
        public long IdExpediente { get; set; }
        public string Paciente { get; set; }
        public string Celular { get; set; }
        public long IdTratamiento { get; set; }
        public string Tratamiento { get; set; }
        public decimal PrecioTratamiento { get; set; }
        public decimal Porcentaje { get; set; }
        /// <summary>yyyy-MM-dd</summary>
        public string Vence { get; set; }
        /// <summary>P pendiente, U usado, A anulado, V vencido</summary>
        public string Estado { get; set; }
        public string Nota { get; set; }
        public long IdFactura { get; set; }
        /// <summary>Factura pendiente a la que está aplicado (todavía sin cobrar).</summary>
        public long FacturaAplicada { get; set; }
        public string FechaUso { get; set; }
        public string UsuarioUso { get; set; }
        public decimal MontoDescuento { get; set; }
        public string MotivoAnulacion { get; set; }
        public string UsuarioCrea { get; set; }
        public string FechaCrea { get; set; }
    }

    public class CuponNuevoDto
    {
        public long IdExpediente { get; set; }
        public string Asignado { get; set; }
        public long IdTratamiento { get; set; }
        public decimal Porcentaje { get; set; }
        /// <summary>yyyy-MM-dd</summary>
        public string Vence { get; set; }
        public string Nota { get; set; }
    }

    public class CuponConfigDto
    {
        public decimal PorcentajeDefecto { get; set; }
        public decimal PorcentajeMaximo { get; set; }
        public int DiasVigencia { get; set; }
        public string Leyenda { get; set; }
        public string Usuario { get; set; }
        public string Fecha { get; set; }
    }

    public class CuponImpresionDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public string Codigo { get; set; }
        public string Asignado { get; set; }
        public decimal Porcentaje { get; set; }
        public string Tratamiento { get; set; }
        public string Vence { get; set; }
        public string Emitido { get; set; }
        public string Nota { get; set; }
        public string Leyenda { get; set; }
        public string Estado { get; set; }
        /// <summary>QR en PNG como data URL.</summary>
        public string Qr { get; set; }
    }

    /// <summary>Cupón aplicado a una factura pendiente (lo usa DteService para calcular el descuento).</summary>
    public class CuponFacturaDto
    {
        public long Id { get; set; }
        public string Codigo { get; set; }
        public decimal Porcentaje { get; set; }
        /// <summary>0: el descuento se aplica a toda la factura.</summary>
        public long IdTratamiento { get; set; }
        public string Tratamiento { get; set; }
        public string Vence { get; set; }
        /// <summary>Motivo por el que ya no se puede usar (vencido, anulado, usado en otra factura), o null.</summary>
        public string NoValido { get; set; }
    }

    /// <summary>Acceso a dbo.CUP_SP_Cupones (Registros/sql/CUP_Cupones.sql).</summary>
    public static class CuponesRepository
    {
        private static readonly CultureInfo Inv = CultureInfo.InvariantCulture;
        // sin I ni O para que no se confundan con 1 y 0; sin números para que el lector de QR no escriba en el monto de la caja
        private const string Letras = "ABCDEFGHJKLMNPQRSTUVWXYZ";

        private static string Cn
        {
            get { return ConfigurationManager.ConnectionStrings["conexionDiarypro"].ConnectionString; }
        }

        private static string Txt(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? "" : Convert.ToString(v).Trim(); }
        private static int Ent(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? 0 : Convert.ToInt32(v); }
        private static long Num(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? 0 : Convert.ToInt64(v); }
        private static decimal Dec(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? 0 : Convert.ToDecimal(v); }
        private static DateTime? Fecha(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? (DateTime?)null : Convert.ToDateTime(v); }
        private static string Dia(DateTime? d) { return d.HasValue ? d.Value.ToString("yyyy-MM-dd", Inv) : ""; }
        private static string Iso(DateTime? d) { return d.HasValue ? d.Value.ToString("yyyy-MM-ddTHH:mm:ss", Inv) : ""; }
        private static object Valor(string s) { return string.IsNullOrWhiteSpace(s) ? (object)DBNull.Value : s.Trim(); }

        private static SqlCommand Sp(SqlConnection cn, int accion, SqlTransaction tx = null)
        {
            var cmd = new SqlCommand("dbo.CUP_SP_Cupones", cn, tx) { CommandType = CommandType.StoredProcedure };
            cmd.Parameters.Add("@accion", SqlDbType.Int).Value = accion;
            return cmd;
        }

        private static void Decimal(SqlParameterCollection p, string nombre, decimal valor, byte precision, byte escala)
        {
            var d = p.Add(nombre, SqlDbType.Decimal);
            d.Precision = precision; d.Scale = escala; d.Value = Math.Round(valor, escala);
        }

        private static long Escalar(int accion, string usuario, Action<SqlParameterCollection> parametros)
        {
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, accion))
            {
                cmd.Parameters.Add("@usuario", SqlDbType.VarChar, 20).Value = (object)usuario ?? DBNull.Value;
                parametros(cmd.Parameters);
                cn.Open();
                var v = cmd.ExecuteScalar();
                return v == null || v == DBNull.Value ? 0 : Convert.ToInt64(v);
            }
        }

        /// <summary>DPC- y 8 letras al azar (24^8 ≈ 110 mil millones de combinaciones).</summary>
        public static string NuevoCodigo()
        {
            var bytes = new byte[8];
            using (var rng = RandomNumberGenerator.Create()) rng.GetBytes(bytes);
            var c = new char[8];
            for (int i = 0; i < 8; i++) c[i] = Letras[bytes[i] % Letras.Length];
            return "DPC-" + new string(c);
        }

        /// <summary>Código QR del cupón en PNG (data URL). El QR solo contiene el código.</summary>
        public static string Qr(string codigo)
        {
            using (var gen = new QRCodeGenerator())
            using (var datos = gen.CreateQrCode(codigo, QRCodeGenerator.ECCLevel.M))
            using (var qr = new QRCode(datos))
            using (var bmp = qr.GetGraphic(10))
            using (var ms = new MemoryStream())
            {
                bmp.Save(ms, ImageFormat.Png);
                return "data:image/png;base64," + Convert.ToBase64String(ms.ToArray());
            }
        }

        public static List<CuponDto> Lista(string estado, string texto, DateTime? desde, DateTime? hasta)
        {
            var lista = new List<CuponDto>();
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, 1))
            {
                cmd.Parameters.Add("@estado", SqlDbType.VarChar, 1).Value = Valor(estado);
                cmd.Parameters.Add("@texto", SqlDbType.NVarChar, 100).Value = Valor(texto);
                cmd.Parameters.Add("@desde", SqlDbType.Date).Value = (object)desde ?? DBNull.Value;
                cmd.Parameters.Add("@hasta", SqlDbType.Date).Value = (object)hasta ?? DBNull.Value;
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                        lista.Add(new CuponDto
                        {
                            Id = Num(rd, "Id_Cupon"), Codigo = Txt(rd, "CodigoCupon"), Asignado = Txt(rd, "Asignado"), IdExpediente = Num(rd, "Id_expediente_FK"),
                            Paciente = Txt(rd, "Paciente"), Celular = Txt(rd, "Celular"), IdTratamiento = Num(rd, "Id_Tratamiento_FK"), Tratamiento = Txt(rd, "Tratamiento"),
                            PrecioTratamiento = Dec(rd, "PrecioTratamiento"), Porcentaje = Dec(rd, "Porcentaje"), Vence = Dia(Fecha(rd, "FechaVence")),
                            Estado = Txt(rd, "Estado"), Nota = Txt(rd, "Nota"), IdFactura = Num(rd, "Id_Factura_FK"), FacturaAplicada = Num(rd, "FacturaAplicada"),
                            FechaUso = Iso(Fecha(rd, "FechaUso")), UsuarioUso = Txt(rd, "UsuarioUso"), MontoDescuento = Dec(rd, "MontoDescuento"),
                            MotivoAnulacion = Txt(rd, "MotivoAnulacion"), UsuarioCrea = Txt(rd, "UsuarioCrea"), FechaCrea = Iso(Fecha(rd, "FechaCrea"))
                        });
            }
            return lista;
        }

        /// <summary>Crea el cupón con un código nuevo (reintenta si el código ya existiera). Devuelve el id.</summary>
        public static long Crear(CuponNuevoDto c, string usuario)
        {
            DateTime vence;
            if (!DateTime.TryParseExact(c.Vence ?? "", "yyyy-MM-dd", Inv, DateTimeStyles.None, out vence))
                throw new ArgumentException("Seleccione la fecha de vencimiento.");
            for (int intento = 0; ; intento++)
            {
                try
                {
                    return Escalar(2, usuario, p =>
                    {
                        p.Add("@codigo", SqlDbType.VarChar, 20).Value = NuevoCodigo();
                        p.Add("@asignado", SqlDbType.VarChar, 150).Value = Valor(c.Asignado);
                        p.Add("@expediente", SqlDbType.BigInt).Value = c.IdExpediente;
                        p.Add("@tratamiento", SqlDbType.BigInt).Value = c.IdTratamiento;
                        Decimal(p, "@porcentaje", c.Porcentaje, 5, 2);
                        p.Add("@vence", SqlDbType.Date).Value = vence;
                        p.Add("@nota", SqlDbType.VarChar, 250).Value = Valor(c.Nota);
                    });
                }
                catch (SqlException ex) when (ex.Number == 50501 && intento < 3) { }
            }
        }

        public static void Anular(long id, string motivo, string usuario)
        {
            Escalar(3, usuario, p => { p.Add("@id", SqlDbType.BigInt).Value = id; p.Add("@nota", SqlDbType.VarChar, 250).Value = Valor(motivo); });
        }

        public static CuponConfigDto Configuracion()
        {
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, 4))
            {
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    return rd.Read() ? new CuponConfigDto
                    {
                        PorcentajeDefecto = Dec(rd, "PorcentajeDefecto"), PorcentajeMaximo = Dec(rd, "PorcentajeMaximo"), DiasVigencia = Ent(rd, "DiasVigencia"),
                        Leyenda = Txt(rd, "Leyenda"), Usuario = Txt(rd, "UsuarioModifica"), Fecha = Iso(Fecha(rd, "FechaModifica"))
                    } : new CuponConfigDto { PorcentajeDefecto = 10, PorcentajeMaximo = 50, DiasVigencia = 30 };
            }
        }

        public static void GuardarConfiguracion(CuponConfigDto c, string usuario)
        {
            Escalar(5, usuario, p =>
            {
                Decimal(p, "@porcentaje", c.PorcentajeDefecto, 5, 2);
                Decimal(p, "@maximo", c.PorcentajeMaximo, 5, 2);
                p.Add("@dias", SqlDbType.Int).Value = c.DiasVigencia;
                p.Add("@nota", SqlDbType.VarChar, 250).Value = Valor(c.Leyenda);
            });
        }

        public static CuponImpresionDto Impresion(long id)
        {
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, 6))
            {
                cmd.Parameters.Add("@id", SqlDbType.BigInt).Value = id;
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                {
                    if (!rd.Read()) return new CuponImpresionDto { Ok = false, Mensaje = "El cupón no existe." };
                    string codigo = Txt(rd, "CodigoCupon");
                    return new CuponImpresionDto
                    {
                        Ok = true, Codigo = codigo, Asignado = Txt(rd, "Asignado"), Porcentaje = Dec(rd, "Porcentaje"), Tratamiento = Txt(rd, "Tratamiento"),
                        Vence = Dia(Fecha(rd, "FechaVence")), Emitido = Dia(Fecha(rd, "FechaCrea")), Nota = Txt(rd, "Nota"), Leyenda = Txt(rd, "Leyenda"),
                        Estado = Txt(rd, "Estado"), Qr = Qr(codigo)
                    };
                }
            }
        }

        public static void AplicarAFactura(string codigo, long factura, string usuario)
        {
            Escalar(7, usuario, p => { p.Add("@codigo", SqlDbType.VarChar, 20).Value = Valor(codigo); p.Add("@factura", SqlDbType.BigInt).Value = factura; });
        }

        public static void QuitarDeFactura(long factura, string usuario)
        {
            Escalar(8, usuario, p => p.Add("@factura", SqlDbType.BigInt).Value = factura);
        }

        /// <summary>Marca el cupón de la factura como usado; se llama dentro de la transacción del pago.</summary>
        public static void MarcarUsado(SqlConnection cn, SqlTransaction tx, long factura, decimal descuento, string usuario)
        {
            using (var cmd = Sp(cn, 9, tx))
            {
                cmd.Parameters.Add("@usuario", SqlDbType.VarChar, 20).Value = usuario;
                cmd.Parameters.Add("@factura", SqlDbType.BigInt).Value = factura;
                Decimal(cmd.Parameters, "@monto", descuento, 12, 2);
                cmd.ExecuteNonQuery();
            }
        }

        /// <summary>Cupón aplicado a la factura, o null.</summary>
        public static CuponFacturaDto CuponDeFactura(long factura)
        {
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, 10))
            {
                cmd.Parameters.Add("@factura", SqlDbType.BigInt).Value = factura;
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                {
                    if (!rd.Read()) return null;
                    var vence = Fecha(rd, "FechaVence");
                    string estado = Txt(rd, "Estado");
                    long usadoEn = Num(rd, "Id_Factura_FK");
                    string noValido = estado == "A" ? "El cupón fue anulado."
                        : estado == "U" && usadoEn != factura ? "El cupón ya fue utilizado."
                        : vence.HasValue && vence.Value.Date < DateTime.Today ? "El cupón venció el " + vence.Value.ToString("dd/MM/yyyy", Inv) + "."
                        : null;
                    return new CuponFacturaDto
                    {
                        Id = Num(rd, "Id_Cupon"), Codigo = Txt(rd, "CodigoCupon"), Porcentaje = Dec(rd, "Porcentaje"),
                        IdTratamiento = Num(rd, "Id_Tratamiento_FK"), Tratamiento = Txt(rd, "Tratamiento"), Vence = Dia(vence), NoValido = noValido
                    };
                }
            }
        }

        /// <summary>Pacientes para asignar el cupón (nombre, documento o celular), máximo 15.</summary>
        public static List<OpcionDto> BuscarPacientes(string texto)
        {
            var lista = new List<OpcionDto>();
            texto = (texto ?? "").Trim();
            if (texto.Length < 2) return lista;
            using (var cn = new SqlConnection(Cn))
            using (var cmd = new SqlCommand(
                "select top 15 Id_Expediente, LTRIM(RTRIM(Nombres + ' ' + Apellidos)) + ISNULL(' · ' + NULLIF(Documento, ''), '') + ISNULL(' · ' + NULLIF(Celular, ''), '') as Texto " +
                "from EXP_EXPEDIENTES where Nombres + ' ' + Apellidos like @t or Documento like @t or Celular like @t order by Nombres, Apellidos", cn))
            {
                cmd.Parameters.Add("@t", SqlDbType.NVarChar, 110).Value = "%" + texto + "%";
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read()) lista.Add(new OpcionDto { Id = Num(rd, "Id_Expediente"), Texto = Txt(rd, "Texto") });
            }
            return lista;
        }

        /// <summary>Tratamientos activos con su precio (Texto = "nombre|precio").</summary>
        public static List<OpcionDto> Tratamientos()
        {
            var lista = new List<OpcionDto>();
            using (var cn = new SqlConnection(Cn))
            using (var cmd = new SqlCommand("select Id_Tratamientos, Descripcion, CAST(Precio as decimal(12,2)) as Precio from CAT_TRATAMIENTOS where IsActivo = 1 order by Descripcion", cn))
            {
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read()) lista.Add(new OpcionDto { Id = Num(rd, "Id_Tratamientos"), Texto = Txt(rd, "Descripcion") + "|" + Dec(rd, "Precio").ToString("0.00", Inv) });
            }
            return lista;
        }

        public static int[] Resumen(out decimal descuentoMes)
        {
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, 11))
            {
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                {
                    rd.Read();
                    descuentoMes = Dec(rd, "DescuentoMes");
                    return new[] { Ent(rd, "Pendientes"), Ent(rd, "Usados"), Ent(rd, "Vencidos") };
                }
            }
        }
    }
}
