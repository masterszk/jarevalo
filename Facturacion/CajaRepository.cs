using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace DPieCenter.Facturacion
{
    // ===== Modelos de la caja diaria (frm_Facturas.aspx) y de las anulaciones de DTE (frm_Anulaciones.aspx) =====

    public class CajaDto
    {
        public long Id { get; set; }
        /// <summary>yyyy-MM-dd</summary>
        public string Fecha { get; set; }
        public bool Abierta { get; set; }
        /// <summary>Es una caja de un día anterior que quedó abierta: hay que cerrarla antes de abrir la de hoy.</summary>
        public bool Anterior { get; set; }
        public decimal Fondo { get; set; }
        public string HoraApertura { get; set; }
        public string HoraCierre { get; set; }
        public decimal? EfectivoEsperado { get; set; }
        public decimal? EfectivoContado { get; set; }
        public decimal Sobrante { get; set; }
        public decimal Faltante { get; set; }
        public string Observaciones { get; set; }
    }

    public class CajaTotalFormaDto
    {
        public string Codigo { get; set; }
        public string FormaPago { get; set; }
        public int Documentos { get; set; }
        public decimal Total { get; set; }
    }

    public class CajaResumenDto
    {
        public decimal Fondo { get; set; }
        public decimal Efectivo { get; set; }
        public decimal Total { get; set; }
        public int Documentos { get; set; }
        public int Anulados { get; set; }
        /// <summary>Dinero sacado de la caja (salidas activas).</summary>
        public decimal Salidas { get; set; }
        public int CantidadSalidas { get; set; }
        /// <summary>Dinero que entró a la caja sin ser cobro (reposición de fondo, cambio…).</summary>
        public decimal Entradas { get; set; }
        public int CantidadEntradas { get; set; }
        /// <summary>Tickets POS de servicios sin costo.</summary>
        public int Tickets { get; set; }
        public decimal EfectivoEsperado { get { return Fondo + Efectivo + Entradas - Salidas; } }
        public List<CajaTotalFormaDto> PorForma { get; set; }
    }

    /// <summary>Último cierre de caja del usuario (CAJ_SP_Caja acción 12).</summary>
    public class UltimoCierreDto
    {
        /// <summary>yyyy-MM-dd de la caja cerrada.</summary>
        public string Fecha { get; set; }
        public string HoraCierre { get; set; }
        public decimal EfectivoContado { get; set; }
    }

    /// <summary>Datos del cierre de la caja del usuario (CAJ_SP_Caja acción 11): solo sus cobros; los pendientes son una alerta.</summary>
    public class CuadreCajaDto
    {
        public string Fecha { get; set; }
        /// <summary>Documentos (DTE vigentes y tickets) emitidos en esta caja.</summary>
        public int Documentos { get; set; }
        /// <summary>Todo lo cobrado en esta caja.</summary>
        public decimal CajaTotal { get; set; }
        /// <summary>Descuentos (tratamientos y cupones) de los documentos de esta caja.</summary>
        public decimal Descuentos { get; set; }
        public decimal DescuentoTratamientos { get; set; }
        public decimal DescuentoCupones { get; set; }
        /// <summary>Documentos con cupón.</summary>
        public int Cupones { get; set; }
        /// <summary>Valor de los servicios cobrados antes de descuentos (CajaTotal + Descuentos).</summary>
        public decimal ValorServicios { get; set; }
        /// <summary>Procedimientos finalizados del día en la sucursal aún sin facturar (solo alerta).</summary>
        public int Pendientes { get; set; }
        public decimal ValorPendientes { get; set; }
        public List<CuadrePendienteDto> ListaPendientes { get; set; }
    }

    public class CuadrePendienteDto
    {
        public long IdProcedimiento { get; set; }
        public long IdFactura { get; set; }
        public string Hora { get; set; }
        public string Paciente { get; set; }
        public string Especialista { get; set; }
        public string Servicios { get; set; }
        public decimal Valor { get; set; }
    }

    /// <summary>Movimiento de efectivo de la caja (CAJ_SALIDAS): entrada o salida.</summary>
    public class SalidaCajaDto
    {
        public long Id { get; set; }
        /// <summary>E entrada, S salida</summary>
        public string Tipo { get; set; }
        public decimal Monto { get; set; }
        public string Categoria { get; set; }
        public string Motivo { get; set; }
        public string Referencia { get; set; }
        /// <summary>A activa, X anulada</summary>
        public string Estado { get; set; }
        public string MotivoAnulacion { get; set; }
        public string Usuario { get; set; }
        public string Hora { get; set; }
        public string AnuladaPor { get; set; }
        public string HoraAnulacion { get; set; }
    }

    public class PendienteCobroDto
    {
        public long IdFactura { get; set; }
        public string Fecha { get; set; }
        public string Hora { get; set; }
        public long IdExpediente { get; set; }
        public string Paciente { get; set; }
        public string Documento { get; set; }
        public string Celular { get; set; }
        public string Especialista { get; set; }
        public string Servicios { get; set; }
        public decimal Total { get; set; }
        /// <summary>Su DTE anterior se anuló: hay que emitir el que lo reemplaza.</summary>
        public bool Reemplazo { get; set; }
    }

    // ===== Cobro de citas por adelantado (Facturacion/sql/CAJ_Anticipos.sql) =====
    public class CitaPorCobrarDto
    {
        public long IdCita { get; set; }
        public string Fecha { get; set; }               // yyyy-MM-dd
        public string Hora { get; set; }
        public long IdExpediente { get; set; }
        public string Paciente { get; set; }
        public string Documento { get; set; }
        public string Celular { get; set; }
        public string Especialista { get; set; }
        public string Estado { get; set; }
        public string Servicios { get; set; }
        public decimal Total { get; set; }              // con el descuento de cada tratamiento
        /// <summary>Factura del anticipo (0 si no se ha creado).</summary>
        public long IdFactura { get; set; }
        public bool Pagada { get; set; }
        /// <summary>Saldo a favor del paciente (anticipos de citas canceladas o anuladas).</summary>
        public decimal SaldoFavor { get; set; }
        /// <summary>Pago adelantado sin cita que se usará en esta cita (saldo disponible).</summary>
        public decimal PagoAdelantado { get; set; }
        /// <summary>Pagos adelantados del paciente pendientes de agendar.</summary>
        public decimal PagosPendientes { get; set; }
    }

    /// <summary>Pago adelantado sin cita (monto libre) con saldo.</summary>
    public class PagoAdelantadoDto
    {
        public long IdFactura { get; set; }
        public long IdExpediente { get; set; }
        public string Paciente { get; set; }
        public string Documento { get; set; }
        public string Celular { get; set; }
        public string Descripcion { get; set; }
        public decimal Pagado { get; set; }
        public decimal Usado { get; set; }
        public decimal Disponible { get; set; }
        public string FechaPago { get; set; }
        /// <summary>Cita donde se usará (0 = pendiente de agendar).</summary>
        public long IdCita { get; set; }
        public string Cita { get; set; }
    }

    /// <summary>Paciente encontrado para cobrarle un pago adelantado.</summary>
    public class PacienteCajaDto
    {
        public long Id { get; set; }
        public string Nombre { get; set; }
        public string Documento { get; set; }
        public string Celular { get; set; }
    }

    public class SaldoFavorDto
    {
        public long IdFactura { get; set; }
        public long IdExpediente { get; set; }
        public string Paciente { get; set; }
        public string Documento { get; set; }
        public long IdCita { get; set; }
        public string Cita { get; set; }                // dd/MM/yyyy hh:mm de la cita cancelada
        public string EstadoCita { get; set; }
        public decimal Total { get; set; }
        public string FechaPago { get; set; }
    }

    public class DteListaDto
    {
        public long Id { get; set; }
        public long IdFactura { get; set; }
        public string TipoDte { get; set; }
        public string NumeroControl { get; set; }
        public string CodigoGeneracion { get; set; }
        public string Fecha { get; set; }
        public string Hora { get; set; }
        public string Receptor { get; set; }
        public string ReceptorDocumento { get; set; }
        public decimal Iva { get; set; }
        public decimal Total { get; set; }
        public string FormaPago { get; set; }
        /// <summary>G generado, T transmitido, R rechazado, A anulado</summary>
        public string Estado { get; set; }
        public string RutaPdf { get; set; }
        public string Cajero { get; set; }
        public string Ambiente { get; set; }
        public bool Transmitido { get; set; }
        public int DiasPlazo { get; set; }
        public string VencePlazo { get; set; }
        public int DiasRestantes { get; set; }
        public bool EnPlazo { get; set; }
        public string FechaAnulacion { get; set; }
        public int TipoAnulacion { get; set; }
        public string Motivo { get; set; }
        public string AnuladoPor { get; set; }
    }

    public class PlazoDto
    {
        public string TipoDte { get; set; }
        public string Descripcion { get; set; }
        public int Dias { get; set; }
        public string Usuario { get; set; }
        public string Fecha { get; set; }
    }

    public class AnulacionRequest
    {
        public long IdDte { get; set; }
        /// <summary>1 error en la información, 2 rescindir la operación, 3 otro</summary>
        public int TipoAnulacion { get; set; }
        public string Motivo { get; set; }
        public string NombreResponsable { get; set; }
        public string TipoDocResponsable { get; set; }
        public string NumDocResponsable { get; set; }
        public string NombreSolicita { get; set; }
        public string TipoDocSolicita { get; set; }
        public string NumDocSolicita { get; set; }
    }

    /// <summary>Ticket POS de un servicio sin costo (Facturacion/sql/CAJ_Tickets.sql): reemplaza al DTE cuando el total es $0.00.</summary>
    public class TicketPosDto
    {
        public long Id { get; set; }
        public string Numero { get; set; }
        public long IdFactura { get; set; }
        public string Paciente { get; set; }
        public string Documento { get; set; }
        public decimal Total { get; set; }
        public string Motivo { get; set; }
        public string Cajero { get; set; }
        /// <summary>dd/MM/yyyy hh:mm AM/PM</summary>
        public string Fecha { get; set; }
        public List<ItemTicketDto> Items { get; set; } = new List<ItemTicketDto>();
        // Encabezado del ticket (datos del emisor)
        public string Empresa { get; set; }
        public string EmpresaNit { get; set; }
        public string EmpresaNrc { get; set; }
        public string EmpresaDireccion { get; set; }
        public string EmpresaTelefono { get; set; }
    }

    public class ItemTicketDto
    {
        public string Descripcion { get; set; }
        public decimal Valor { get; set; }
    }

    /// <summary>Acceso a dbo.CAJ_SP_Caja y dbo.FAC_SP_DTE_ANULACIONES (Facturacion/sql/CAJ_Caja_Anulaciones.sql).</summary>
    public static class CajaRepository
    {
        private static readonly CultureInfo Inv = CultureInfo.InvariantCulture;

        private static string Txt(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? "" : Convert.ToString(v).Trim(); }
        private static int Ent(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? 0 : Convert.ToInt32(v); }
        private static long Num(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? 0 : Convert.ToInt64(v); }
        private static decimal Dec(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? 0 : Convert.ToDecimal(v); }
        private static decimal? DecN(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? (decimal?)null : Convert.ToDecimal(v); }
        private static bool Bit(IDataRecord r, string col) { var v = r[col]; return v != DBNull.Value && Convert.ToBoolean(v); }
        private static DateTime? Fecha(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? (DateTime?)null : Convert.ToDateTime(v); }
        private static string Dia(DateTime? d) { return d.HasValue ? d.Value.ToString("yyyy-MM-dd", Inv) : ""; }
        private static string Hora(DateTime? d) { return Formato.Hora(d); }
        private static object Valor(string s) { return string.IsNullOrWhiteSpace(s) ? (object)DBNull.Value : s.Trim(); }

        private static SqlCommand Sp(SqlConnection cn, string nombre, int accion)
        {
            var cmd = new SqlCommand(nombre, cn) { CommandType = CommandType.StoredProcedure };
            cmd.Parameters.Add("@accion", SqlDbType.Int).Value = accion;
            return cmd;
        }

        private static SqlCommand Caja(SqlConnection cn, int accion, string cajero)
        {
            var cmd = Sp(cn, "dbo.CAJ_SP_Caja", accion);
            cmd.Parameters.Add("@cajero", SqlDbType.VarChar, 20).Value = cajero;
            cmd.Parameters.Add("@sucursal", SqlDbType.Int).Value = Sesion.Sucursal;     // la caja y sus pendientes son de la sucursal de la sesión
            return cmd;
        }

        // ===== Caja =====

        /// <summary>Caja del usuario hoy, o la de un día anterior que dejó abierta; null si no tiene.</summary>
        public static CajaDto CajaActual(string cajero)
        {
            using (var cn = new SqlConnection(DteRepository.Cn))
            using (var cmd = Caja(cn, 1, cajero))
            {
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    return rd.Read() ? new CajaDto
                    {
                        Id = Num(rd, "Id_Apertura"), Fecha = Dia(Fecha(rd, "FechaApertura")), Abierta = Bit(rd, "Abierta"), Anterior = Ent(rd, "Anterior") == 1,
                        Fondo = Dec(rd, "MontoApertura"), HoraApertura = Hora(Fecha(rd, "FechaApertura2")), HoraCierre = Hora(Fecha(rd, "FechaCierre")),
                        EfectivoEsperado = DecN(rd, "EfectivoEsperado"), EfectivoContado = DecN(rd, "EfectivoContado"),
                        Sobrante = Dec(rd, "Sobrante"), Faltante = Dec(rd, "Faltante"), Observaciones = Txt(rd, "Observaciones")
                    } : null;
            }
        }

        /// <summary>Último cierre del cajero (efectivo contado): se propone como fondo de la caja siguiente. null si nunca cerró.</summary>
        public static UltimoCierreDto UltimoCierre(string cajero)
        {
            using (var cn = new SqlConnection(DteRepository.Cn))
            using (var cmd = Caja(cn, 12, cajero))
            {
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    return rd.Read() ? new UltimoCierreDto
                    {
                        Fecha = Dia(Fecha(rd, "FechaApertura")),
                        HoraCierre = Hora(Fecha(rd, "FechaCierre")),
                        EfectivoContado = Dec(rd, "EfectivoContado")
                    } : null;
            }
        }

        /// <summary>Motivo por el que el usuario no puede cobrar (sin caja abierta hoy), o null.</summary>
        public static string ValidarCajaAbierta(string cajero)
        {
            var c = CajaActual(cajero);
            if (c == null) return "Abra su caja del día en Facturación > Caja antes de cobrar.";
            if (c.Anterior) return "Tiene abierta la caja del " + DateTime.ParseExact(c.Fecha, "yyyy-MM-dd", Inv).ToString("dd/MM/yyyy") + ". Ciérrela y abra la de hoy antes de cobrar.";
            if (!c.Abierta) return "Su caja de hoy está cerrada. No se pueden emitir más documentos hoy.";
            return null;
        }

        public static long Abrir(string cajero, decimal fondo)
        {
            return Escalar(Caja, 2, cajero, p => Monto(p, fondo));
        }

        public static long Cerrar(string cajero, long id, decimal efectivoContado, string observaciones)
        {
            return Escalar(Caja, 4, cajero, p =>
            {
                p.Add("@id", SqlDbType.BigInt).Value = id;
                Monto(p, efectivoContado);
                p.Add("@observaciones", SqlDbType.VarChar, 500).Value = Valor(observaciones);
            });
        }

        public static long Reabrir(string cajero, long id)
        {
            return Escalar(Caja, 5, cajero, p => p.Add("@id", SqlDbType.BigInt).Value = id);
        }

        public static CajaResumenDto Resumen(string cajero, long id)
        {
            var r = new CajaResumenDto { PorForma = new List<CajaTotalFormaDto>() };
            using (var cn = new SqlConnection(DteRepository.Cn))
            using (var cmd = Caja(cn, 3, cajero))
            {
                cmd.Parameters.Add("@id", SqlDbType.BigInt).Value = id;
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                {
                    while (rd.Read())
                        r.PorForma.Add(new CajaTotalFormaDto { Codigo = Txt(rd, "Codigo"), FormaPago = Txt(rd, "FormaPago"), Documentos = Ent(rd, "Documentos"), Total = Dec(rd, "Total") });
                    if (rd.NextResult() && rd.Read())
                    {
                        r.Fondo = Dec(rd, "Fondo"); r.Efectivo = Dec(rd, "Efectivo"); r.Total = Dec(rd, "Total");
                        r.Documentos = Ent(rd, "Documentos"); r.Anulados = Ent(rd, "Anulados");
                        r.Salidas = Dec(rd, "Salidas"); r.CantidadSalidas = Ent(rd, "CantidadSalidas"); r.Tickets = Ent(rd, "Tickets");
                        r.Entradas = Dec(rd, "Entradas"); r.CantidadEntradas = Ent(rd, "CantidadEntradas");
                    }
                }
            }
            return r;
        }

        public static CuadreCajaDto Cuadre(string cajero, long id)
        {
            var r = new CuadreCajaDto { ListaPendientes = new List<CuadrePendienteDto>() };
            using (var cn = new SqlConnection(DteRepository.Cn))
            using (var cmd = Caja(cn, 11, cajero))
            {
                cmd.Parameters.Add("@id", SqlDbType.BigInt).Value = id;
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                {
                    if (rd.Read())
                    {
                        r.Fecha = Dia(Fecha(rd, "Fecha"));
                        r.Documentos = Ent(rd, "Documentos"); r.CajaTotal = Dec(rd, "CajaTotal"); r.Descuentos = Dec(rd, "Descuentos");
                        r.DescuentoTratamientos = Dec(rd, "DescuentoTratamientos"); r.DescuentoCupones = Dec(rd, "DescuentoCupones");
                        r.Cupones = Ent(rd, "Cupones"); r.ValorServicios = Dec(rd, "ValorServicios");
                        r.Pendientes = Ent(rd, "Pendientes"); r.ValorPendientes = Dec(rd, "ValorPendientes");
                    }
                    if (rd.NextResult())
                        while (rd.Read())
                            r.ListaPendientes.Add(new CuadrePendienteDto
                            {
                                IdProcedimiento = Num(rd, "Id_Procedimiento"), IdFactura = Num(rd, "Id_Factura"), Hora = Hora(Fecha(rd, "Final")),
                                Paciente = Txt(rd, "Paciente"), Especialista = Txt(rd, "Especialista"), Servicios = Txt(rd, "Servicios"), Valor = Dec(rd, "Valor")
                            });
                }
            }
            return r;
        }

        // ===== Manejo de efectivo: entradas y salidas =====

        /// <summary>tipo: "E" entrada de efectivo, "S" salida.</summary>
        public static long RegistrarMovimiento(string cajero, long caja, string tipo, decimal monto, string categoria, string motivo, string referencia)
        {
            return Escalar(Caja, 8, cajero, p =>
            {
                p.Add("@id", SqlDbType.BigInt).Value = caja;
                p.Add("@tipo", SqlDbType.Char, 1).Value = tipo == "E" ? "E" : "S";
                Monto(p, monto);
                p.Add("@categoria", SqlDbType.VarChar, 30).Value = Valor(categoria);
                p.Add("@observaciones", SqlDbType.VarChar, 500).Value = Valor(motivo);
                p.Add("@referencia", SqlDbType.VarChar, 50).Value = Valor(referencia);
            });
        }

        public static List<SalidaCajaDto> Salidas(string cajero, long caja)
        {
            var lista = new List<SalidaCajaDto>();
            using (var cn = new SqlConnection(DteRepository.Cn))
            using (var cmd = Caja(cn, 9, cajero))
            {
                cmd.Parameters.Add("@id", SqlDbType.BigInt).Value = caja;
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                        lista.Add(new SalidaCajaDto
                        {
                            Id = Num(rd, "Id_Salida"), Tipo = Txt(rd, "Tipo"), Monto = Dec(rd, "Monto"), Categoria = Txt(rd, "Categoria"), Motivo = Txt(rd, "Motivo"),
                            Referencia = Txt(rd, "Referencia"), Estado = Txt(rd, "Estado"), MotivoAnulacion = Txt(rd, "MotivoAnulacion"),
                            Usuario = Txt(rd, "UsuarioCrea"), Hora = Hora(Fecha(rd, "FechaCrea")),
                            AnuladaPor = Txt(rd, "UsuarioModifica"), HoraAnulacion = Hora(Fecha(rd, "FechaModifica"))
                        });
            }
            return lista;
        }

        public static long AnularSalida(string cajero, long salida, string motivo)
        {
            return Escalar(Caja, 10, cajero, p =>
            {
                p.Add("@texto", SqlDbType.NVarChar, 100).Value = salida.ToString(Inv);
                p.Add("@observaciones", SqlDbType.VarChar, 500).Value = Valor(motivo);
            });
        }

        // ===== Cobro de citas por adelantado =====

        private static SqlCommand Anticipos(SqlConnection cn, int accion, string usuario)
        {
            var cmd = Sp(cn, "dbo.CAJ_SP_Anticipos", accion);
            cmd.Parameters.Add("@usuario", SqlDbType.VarChar, 20).Value = usuario;
            cmd.Parameters.Add("@sucursal", SqlDbType.Int).Value = Sesion.Sucursal;
            return cmd;
        }

        /// <summary>Citas activas desde hoy (30 días) de la sucursal, con su total y si ya se pagaron por adelantado.</summary>
        public static List<CitaPorCobrarDto> CitasPorCobrar(string usuario, string texto)
        {
            var lista = new List<CitaPorCobrarDto>();
            using (var cn = new SqlConnection(DteRepository.Cn))
            using (var cmd = Anticipos(cn, 1, usuario))
            {
                cmd.Parameters.Add("@texto", SqlDbType.NVarChar, 100).Value = Valor(texto);
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                    {
                        var ini = Fecha(rd, "Inicio");
                        lista.Add(new CitaPorCobrarDto
                        {
                            IdCita = Num(rd, "Id_Cita"),
                            Fecha = ini.HasValue ? ini.Value.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture) : "",
                            Hora = ini.HasValue && ini.Value.TimeOfDay != TimeSpan.Zero ? Formato.Hora(ini.Value) : "",
                            IdExpediente = Num(rd, "Id_Expediente"), Paciente = Txt(rd, "Paciente"), Documento = Txt(rd, "Documento"),
                            Celular = Txt(rd, "Celular"), Especialista = Txt(rd, "Especialista"), Estado = Txt(rd, "Estado"),
                            Servicios = Txt(rd, "Servicios"), Total = Dec(rd, "Total"),
                            IdFactura = Num(rd, "IdFactura"), Pagada = rd["Pagada"] != DBNull.Value && Convert.ToBoolean(rd["Pagada"]),
                            SaldoFavor = Dec(rd, "SaldoFavor"),
                            PagoAdelantado = Dec(rd, "PagoAdelantado"), PagosPendientes = Dec(rd, "PagosPendientes")
                        });
                    }
            }
            return lista;
        }

        /// <summary>Crea (o rehace) la factura del anticipo de la cita y devuelve su Id para cobrarla en frm_OpenFactura.aspx.</summary>
        public static long CrearAnticipo(string usuario, long cita)
        {
            using (var cn = new SqlConnection(DteRepository.Cn))
            using (var cmd = Anticipos(cn, 2, usuario))
            {
                cmd.Parameters.Add("@cita", SqlDbType.BigInt).Value = cita;
                cn.Open();
                return Convert.ToInt64(cmd.ExecuteScalar());
            }
        }

        /// <summary>Aplica el saldo a favor más antiguo del paciente a su cita.</summary>
        public static long AplicarSaldo(string usuario, long cita)
        {
            using (var cn = new SqlConnection(DteRepository.Cn))
            using (var cmd = Anticipos(cn, 4, usuario))
            {
                cmd.Parameters.Add("@cita", SqlDbType.BigInt).Value = cita;
                cn.Open();
                return Convert.ToInt64(cmd.ExecuteScalar());
            }
        }

        // ===== Pago adelantado sin cita (monto libre) =====

        /// <summary>Crea la factura del pago adelantado sin cita; se cobra en frm_OpenFactura.aspx.</summary>
        public static long CrearPagoSinCita(string usuario, long expediente, decimal monto, string descripcion)
        {
            using (var cn = new SqlConnection(DteRepository.Cn))
            using (var cmd = Anticipos(cn, 5, usuario))
            {
                cmd.Parameters.Add("@expediente", SqlDbType.BigInt).Value = expediente;
                var m = cmd.Parameters.Add("@monto", SqlDbType.Decimal); m.Precision = 12; m.Scale = 2; m.Value = monto;
                cmd.Parameters.Add("@descripcion", SqlDbType.VarChar, 250).Value = Valor(descripcion);
                cn.Open();
                return Convert.ToInt64(cmd.ExecuteScalar());
            }
        }

        /// <summary>Pagos adelantados con saldo (expediente 0: de la sucursal, filtrados por texto).</summary>
        public static List<PagoAdelantadoDto> PagosAdelantados(string usuario, string texto, long expediente)
        {
            var lista = new List<PagoAdelantadoDto>();
            using (var cn = new SqlConnection(DteRepository.Cn))
            using (var cmd = Anticipos(cn, 6, usuario))
            {
                cmd.Parameters.Add("@texto", SqlDbType.NVarChar, 100).Value = Valor(texto);
                cmd.Parameters.Add("@expediente", SqlDbType.BigInt).Value = expediente;
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                    {
                        var ini = Fecha(rd, "InicioCita");
                        lista.Add(new PagoAdelantadoDto
                        {
                            IdFactura = Num(rd, "Id_Factura"), IdExpediente = Num(rd, "Id_Expediente"), Paciente = Txt(rd, "Paciente"),
                            Documento = Txt(rd, "Documento"), Celular = Txt(rd, "Celular"), Descripcion = Txt(rd, "Descripcion"),
                            Pagado = Dec(rd, "Pagado"), Usado = Dec(rd, "Usado"), Disponible = Dec(rd, "Disponible"),
                            FechaPago = Dia(Fecha(rd, "FechaPago")), IdCita = Num(rd, "Id_Cita"),
                            Cita = ini.HasValue ? Dia(ini) + (ini.Value.TimeOfDay != TimeSpan.Zero ? " " + Formato.Hora(ini.Value) : "") : ""
                        });
                    }
            }
            return lista;
        }

        /// <summary>La cita usará el pago adelantado (factura 0 = el pendiente más antiguo del paciente).</summary>
        public static long UsarPagoAdelantado(string usuario, long cita, long factura)
        {
            using (var cn = new SqlConnection(DteRepository.Cn))
            using (var cmd = Anticipos(cn, 7, usuario))
            {
                cmd.Parameters.Add("@cita", SqlDbType.BigInt).Value = cita;
                cmd.Parameters.Add("@factura", SqlDbType.BigInt).Value = factura;
                cn.Open();
                return Convert.ToInt64(cmd.ExecuteScalar());
            }
        }

        /// <summary>La cita ya no usará el pago adelantado: vuelve a pendiente de agendar.</summary>
        public static long QuitarPagoAdelantado(string usuario, long cita)
        {
            using (var cn = new SqlConnection(DteRepository.Cn))
            using (var cmd = Anticipos(cn, 8, usuario))
            {
                cmd.Parameters.Add("@cita", SqlDbType.BigInt).Value = cita;
                cn.Open();
                return Convert.ToInt64(cmd.ExecuteScalar());
            }
        }

        public static List<SaldoFavorDto> SaldosFavor(string usuario)
        {
            var lista = new List<SaldoFavorDto>();
            using (var cn = new SqlConnection(DteRepository.Cn))
            using (var cmd = Anticipos(cn, 3, usuario))
            {
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                    {
                        var ini = Fecha(rd, "InicioCita");
                        lista.Add(new SaldoFavorDto
                        {
                            IdFactura = Num(rd, "Id_Factura"), IdExpediente = Num(rd, "Id_Expediente"), Paciente = Txt(rd, "Paciente"),
                            Documento = Txt(rd, "Documento"), IdCita = Num(rd, "Id_Cita"),
                            Cita = ini.HasValue ? Dia(ini) + (ini.Value.TimeOfDay != TimeSpan.Zero ? " " + Formato.Hora(ini.Value) : "") : "",
                            EstadoCita = Txt(rd, "EstadoCita"), Total = Dec(rd, "Total"), FechaPago = Dia(Fecha(rd, "FechaPago"))
                        });
                    }
            }
            return lista;
        }

        public static List<PendienteCobroDto> Pendientes(string cajero, DateTime? desde, DateTime? hasta, string texto)
        {
            var lista = new List<PendienteCobroDto>();
            using (var cn = new SqlConnection(DteRepository.Cn))
            using (var cmd = Caja(cn, 6, cajero))
            {
                cmd.Parameters.Add("@desde", SqlDbType.Date).Value = (object)desde ?? DBNull.Value;
                cmd.Parameters.Add("@hasta", SqlDbType.Date).Value = (object)hasta ?? DBNull.Value;
                cmd.Parameters.Add("@texto", SqlDbType.NVarChar, 100).Value = Valor(texto);
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                        lista.Add(new PendienteCobroDto
                        {
                            IdFactura = Num(rd, "Id_factura"), Fecha = Dia(Fecha(rd, "FechaFactura")), Hora = Hora(Fecha(rd, "FinalProcedimiento")),
                            IdExpediente = Num(rd, "Id_Expediente"), Paciente = Txt(rd, "Paciente"), Documento = Txt(rd, "Documento"),
                            Celular = Txt(rd, "Celular"), Especialista = Txt(rd, "Especialista"), Servicios = Txt(rd, "Servicios"),
                            Total = Dec(rd, "Total"), Reemplazo = Ent(rd, "Reemplazo") == 1
                        });
            }
            return lista;
        }

        public static List<DteListaDto> EmitidosCaja(string cajero, long id)
        {
            var lista = new List<DteListaDto>();
            using (var cn = new SqlConnection(DteRepository.Cn))
            using (var cmd = Caja(cn, 7, cajero))
            {
                cmd.Parameters.Add("@id", SqlDbType.BigInt).Value = id;
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                    {
                        var hora = rd["HoraEmision"];
                        lista.Add(new DteListaDto
                        {
                            Id = Num(rd, "Id_Dte"), IdFactura = Num(rd, "Id_Factura_FK"), TipoDte = Txt(rd, "TipoDte"), NumeroControl = Txt(rd, "NumeroControl"),
                            CodigoGeneracion = Txt(rd, "CodigoGeneracion"), Hora = hora == DBNull.Value ? "" : Formato.Hora((TimeSpan)hora),
                            Receptor = Txt(rd, "ReceptorNombre"), Total = Dec(rd, "TotalPagar"), FormaPago = Txt(rd, "FormaPagoTexto"),
                            Estado = Txt(rd, "Estado"), RutaPdf = Txt(rd, "RutaPdf")
                        });
                    }
            }
            return lista;
        }

        // ===== Tickets POS de servicios sin costo (dbo.CAJ_SP_Tickets) =====

        /// <summary>Emite el ticket de una factura con total $0.00 y la marca como cobrada. Las reglas (caja abierta, total cero) las valida el SP.</summary>
        public static TicketPosDto EmitirTicket(long factura, string cajero, string motivo)
        {
            using (var cn = new SqlConnection(DteRepository.Cn))
            using (var cmd = Sp(cn, "dbo.CAJ_SP_Tickets", 1))
            {
                cmd.Parameters.Add("@factura", SqlDbType.BigInt).Value = factura;
                cmd.Parameters.Add("@cajero", SqlDbType.VarChar, 20).Value = cajero;
                cmd.Parameters.Add("@motivo", SqlDbType.VarChar, 100).Value = Valor(motivo);
                cn.Open();
                return LeerTicket(cmd);
            }
        }

        /// <summary>Ticket de una factura (para reimprimir); null si la factura no tiene ticket.</summary>
        public static TicketPosDto TicketDeFactura(long factura)
        {
            using (var cn = new SqlConnection(DteRepository.Cn))
            using (var cmd = Sp(cn, "dbo.CAJ_SP_Tickets", 2))
            {
                cmd.Parameters.Add("@factura", SqlDbType.BigInt).Value = factura;
                cn.Open();
                return LeerTicket(cmd);
            }
        }

        private static TicketPosDto LeerTicket(SqlCommand cmd)
        {
            TicketPosDto t;
            using (var rd = cmd.ExecuteReader())
            {
                if (!rd.Read()) return null;
                t = new TicketPosDto
                {
                    Id = Num(rd, "Id_Ticket"), Numero = Txt(rd, "Numero"), IdFactura = Num(rd, "Id_Factura_FK"), Paciente = Txt(rd, "Paciente"),
                    Documento = Txt(rd, "Documento"), Total = Dec(rd, "Total"), Motivo = Txt(rd, "Motivo"),
                    Cajero = Txt(rd, "Cajero") != "" ? Txt(rd, "Cajero") : Txt(rd, "UsuarioCrea"),
                    Fecha = Formato.FechaHora(Fecha(rd, "FechaCrea"))
                };
                if (rd.NextResult())
                    while (rd.Read()) t.Items.Add(new ItemTicketDto { Descripcion = Txt(rd, "Descripcion"), Valor = Dec(rd, "Valor") });
            }
            var e = DteRepository.ObtenerEmisor();
            if (e != null)
            {
                t.Empresa = string.IsNullOrWhiteSpace(e.NombreComercial) ? e.Nombre : e.NombreComercial;
                t.EmpresaNit = e.Nit; t.EmpresaNrc = e.Nrc; t.EmpresaDireccion = e.Complemento; t.EmpresaTelefono = e.Telefono;
            }
            return t;
        }

        // ===== Anulaciones =====

        public static List<DteListaDto> Documentos(DateTime? desde, DateTime? hasta, string tipoDte, string cajero, string texto, string vista)
        {
            var lista = new List<DteListaDto>();
            using (var cn = new SqlConnection(DteRepository.Cn))
            using (var cmd = Sp(cn, "dbo.FAC_SP_DTE_ANULACIONES", 1))
            {
                cmd.Parameters.Add("@desde", SqlDbType.Date).Value = (object)desde ?? DBNull.Value;
                cmd.Parameters.Add("@hasta", SqlDbType.Date).Value = (object)hasta ?? DBNull.Value;
                cmd.Parameters.Add("@tipoDte", SqlDbType.Char, 2).Value = Valor(tipoDte);
                cmd.Parameters.Add("@cajero", SqlDbType.VarChar, 20).Value = Valor(cajero);
                cmd.Parameters.Add("@texto", SqlDbType.NVarChar, 100).Value = Valor(texto);
                cmd.Parameters.Add("@vista", SqlDbType.VarChar, 10).Value = vista;
                cmd.Parameters.Add("@sucursal", SqlDbType.Int).Value = Sesion.Sucursal;
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                    {
                        var hora = rd["HoraEmision"];
                        lista.Add(new DteListaDto
                        {
                            Id = Num(rd, "Id_Dte"), IdFactura = Num(rd, "Id_Factura_FK"), TipoDte = Txt(rd, "TipoDte"), NumeroControl = Txt(rd, "NumeroControl"),
                            CodigoGeneracion = Txt(rd, "CodigoGeneracion"), Fecha = Dia(Fecha(rd, "FechaEmision")),
                            Hora = hora == DBNull.Value ? "" : Formato.Hora((TimeSpan)hora),
                            Receptor = Txt(rd, "ReceptorNombre"), ReceptorDocumento = Txt(rd, "ReceptorDocumento"), Iva = Dec(rd, "TotalIva"), Total = Dec(rd, "TotalPagar"),
                            FormaPago = Txt(rd, "FormaPago"), Estado = Txt(rd, "Estado"), RutaPdf = Txt(rd, "RutaPdf"), Cajero = Txt(rd, "Cajero"),
                            Ambiente = Txt(rd, "Ambiente"), Transmitido = !string.IsNullOrEmpty(Txt(rd, "SelloRecepcion")),
                            DiasPlazo = Ent(rd, "DiasPlazo"), VencePlazo = Dia(Fecha(rd, "VencePlazo")), DiasRestantes = Ent(rd, "DiasRestantes"),
                            EnPlazo = Bit(rd, "EnPlazo"), FechaAnulacion = Fecha(rd, "FechaAnulacion").HasValue ? Fecha(rd, "FechaAnulacion").Value.ToString("yyyy-MM-ddTHH:mm:ss", Inv) : "",
                            TipoAnulacion = Ent(rd, "TipoAnulacion"), Motivo = Txt(rd, "Motivo"), AnuladoPor = Txt(rd, "AnuladoPor")
                        });
                    }
            }
            return lista;
        }

        public static List<PlazoDto> Plazos()
        {
            var lista = new List<PlazoDto>();
            using (var cn = new SqlConnection(DteRepository.Cn))
            using (var cmd = Sp(cn, "dbo.FAC_SP_DTE_ANULACIONES", 3))
            {
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                        lista.Add(new PlazoDto
                        {
                            TipoDte = Txt(rd, "TipoDte"), Descripcion = Txt(rd, "Descripcion"), Dias = Ent(rd, "Dias"), Usuario = Txt(rd, "UsuarioModifica"),
                            Fecha = Fecha(rd, "FechaModifica").HasValue ? Fecha(rd, "FechaModifica").Value.ToString("yyyy-MM-ddTHH:mm:ss", Inv) : ""
                        });
            }
            return lista;
        }

        public static void GuardarPlazo(string tipoDte, int dias, string usuario)
        {
            using (var cn = new SqlConnection(DteRepository.Cn))
            using (var cmd = Sp(cn, "dbo.FAC_SP_DTE_ANULACIONES", 4))
            {
                cmd.Parameters.Add("@tipoDte", SqlDbType.Char, 2).Value = Valor(tipoDte);
                cmd.Parameters.Add("@dias", SqlDbType.Int).Value = dias;
                cmd.Parameters.Add("@usuario", SqlDbType.VarChar, 20).Value = usuario;
                cn.Open();
                cmd.ExecuteNonQuery();
            }
        }

        public static List<string[]> Cajeros()
        {
            var lista = new List<string[]>();
            using (var cn = new SqlConnection(DteRepository.Cn))
            using (var cmd = Sp(cn, "dbo.FAC_SP_DTE_ANULACIONES", 5))
            {
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read()) lista.Add(new[] { Txt(rd, "Cajero"), Txt(rd, "Nombre") });
            }
            return lista;
        }

        /// <summary>
        /// Registra el evento de invalidación (JSON con la estructura del esquema de anulación de Hacienda, versión 2),
        /// marca el DTE como anulado y, si se anula por error u otro motivo, deja la factura pendiente para emitir el DTE que lo reemplaza.
        /// </summary>
        public static string Anular(AnulacionRequest a, string usuario)
        {
            JObject dte;
            string tipoDte, numeroControl, codigo, sello, ambiente;
            DateTime emision;
            decimal iva;
            using (var cn = new SqlConnection(DteRepository.Cn))
            using (var cmd = new SqlCommand("select TipoDte, NumeroControl, CodigoGeneracion, SelloRecepcion, FechaEmision, TotalIva, Ambiente, JsonDte from FAC_DTE_DOCUMENTOS where Id_Dte = @id", cn))
            {
                cmd.Parameters.Add("@id", SqlDbType.BigInt).Value = a.IdDte;
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                {
                    if (!rd.Read()) throw new ArgumentException("El documento no existe.");
                    tipoDte = Txt(rd, "TipoDte"); numeroControl = Txt(rd, "NumeroControl"); codigo = Txt(rd, "CodigoGeneracion");
                    sello = Txt(rd, "SelloRecepcion"); emision = Convert.ToDateTime(rd["FechaEmision"]); iva = Dec(rd, "TotalIva"); ambiente = Txt(rd, "Ambiente");
                    dte = JObject.Parse(Txt(rd, "JsonDte"));
                }
            }

            var emisor = DteRepository.ObtenerEmisor(DteRepository.SucursalDeDte(a.IdDte));     // establecimiento de la sucursal del DTE
            if (emisor == null) throw new ArgumentException("No hay datos del emisor configurados.");
            var receptor = dte["receptor"] as JObject ?? new JObject();
            bool ccf = tipoDte == TiposDte.CreditoFiscal;
            DateTime ahora = DateTime.Now;
            string codigoEvento = Guid.NewGuid().ToString().ToUpperInvariant();

            var evento = new
            {
                identificacion = new
                {
                    version = 2,
                    ambiente = string.IsNullOrEmpty(ambiente) ? emisor.Ambiente : ambiente,
                    codigoGeneracion = codigoEvento,
                    fecAnula = ahora.ToString("yyyy-MM-dd", Inv),
                    horAnula = ahora.ToString("HH:mm:ss", Inv)
                },
                emisor = new
                {
                    nit = emisor.Nit,
                    nombre = emisor.Nombre,
                    tipoEstablecimiento = emisor.TipoEstablecimiento,
                    nomEstablecimiento = string.IsNullOrEmpty(emisor.NombreComercial) ? emisor.Nombre : emisor.NombreComercial,
                    codEstableMH = Nulo(emisor.CodEstableMH),
                    codEstable = Nulo(emisor.CodEstable),
                    codPuntoVentaMH = Nulo(emisor.CodPuntoVentaMH),
                    codPuntoVenta = Nulo(emisor.CodPuntoVenta),
                    telefono = Nulo(emisor.Telefono),
                    correo = emisor.Correo
                },
                documento = new
                {
                    tipoDte,
                    codigoGeneracion = codigo,
                    selloRecibido = Nulo(sello),
                    numeroControl,
                    fecEmi = emision.ToString("yyyy-MM-dd", Inv),
                    montoIva = iva,
                    codigoGeneracionR = (string)null,     // DTE que lo reemplaza: se emite después, desde la caja
                    tipoDocumento = ccf ? "36" : (string)receptor["tipoDocumento"],
                    numDocumento = ccf ? (string)receptor["nit"] : (string)receptor["numDocumento"],
                    nombre = (string)receptor["nombre"],
                    telefono = (string)receptor["telefono"],
                    correo = (string)receptor["correo"]
                },
                motivo = new
                {
                    tipoAnulacion = a.TipoAnulacion,
                    motivoAnulacion = Nulo(a.Motivo),
                    nombreResponsable = (a.NombreResponsable ?? "").Trim(),
                    tipDocResponsable = a.TipoDocResponsable,
                    numDocResponsable = (a.NumDocResponsable ?? "").Trim(),
                    nombreSolicita = (a.NombreSolicita ?? "").Trim(),
                    tipDocSolicita = a.TipoDocSolicita,
                    numDocSolicita = (a.NumDocSolicita ?? "").Trim()
                }
            };
            string json = JsonConvert.SerializeObject(evento, Formatting.Indented);

            using (var cn = new SqlConnection(DteRepository.Cn))
            using (var cmd = Sp(cn, "dbo.FAC_SP_DTE_ANULACIONES", 2))
            {
                var p = cmd.Parameters;
                p.Add("@usuario", SqlDbType.VarChar, 20).Value = usuario;
                p.Add("@id", SqlDbType.BigInt).Value = a.IdDte;
                p.Add("@tipoAnulacion", SqlDbType.TinyInt).Value = a.TipoAnulacion;
                p.Add("@motivo", SqlDbType.VarChar, 250).Value = Valor(a.Motivo);
                p.Add("@nombreResponsable", SqlDbType.VarChar, 100).Value = Valor(a.NombreResponsable);
                p.Add("@tipoDocResponsable", SqlDbType.Char, 2).Value = Valor(a.TipoDocResponsable);
                p.Add("@numDocResponsable", SqlDbType.VarChar, 20).Value = Valor(a.NumDocResponsable);
                p.Add("@nombreSolicita", SqlDbType.VarChar, 100).Value = Valor(a.NombreSolicita);
                p.Add("@tipoDocSolicita", SqlDbType.Char, 2).Value = Valor(a.TipoDocSolicita);
                p.Add("@numDocSolicita", SqlDbType.VarChar, 20).Value = Valor(a.NumDocSolicita);
                p.Add("@codigoEvento", SqlDbType.Char, 36).Value = codigoEvento;
                p.Add("@json", SqlDbType.NVarChar, -1).Value = json;
                cn.Open();
                cmd.ExecuteNonQuery();
            }
            return codigoEvento;
        }

        private static void Monto(SqlParameterCollection p, decimal valor)
        {
            var m = p.Add("@monto", SqlDbType.Decimal);
            m.Precision = 12; m.Scale = 2; m.Value = Math.Round(valor, 2);
        }

        private static string Nulo(string s) { return string.IsNullOrWhiteSpace(s) ? null : s.Trim(); }

        private static long Escalar(Func<SqlConnection, int, string, SqlCommand> crear, int accion, string cajero, Action<SqlParameterCollection> parametros)
        {
            using (var cn = new SqlConnection(DteRepository.Cn))
            using (var cmd = crear(cn, accion, cajero))
            {
                parametros(cmd.Parameters);
                cn.Open();
                var v = cmd.ExecuteScalar();
                return v == null || v == DBNull.Value ? 0 : Convert.ToInt64(v);
            }
        }
    }
}
