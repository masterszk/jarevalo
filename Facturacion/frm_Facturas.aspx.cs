using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Globalization;
using System.Linq;
using System.Web;
using System.Web.Services;

namespace DPieCenter.Facturacion
{
    /// <summary>
    /// Caja del día por usuario (assets/js/caja.js): abrir la caja, cobrar los procesos finalizados (emitir el DTE en
    /// frm_OpenFactura.aspx) y cerrarla con el arqueo del efectivo. El cajero siempre es el usuario de la sesión.
    /// </summary>
    public partial class frm_Facturas : System.Web.UI.Page
    {
        private const string Url = "Facturacion/frm_Facturas.aspx";

        protected void Page_Load(object sender, EventArgs e)
        {

        }

        public class EstadoCajaDto
        {
            public bool Ok { get; set; }
            public string Mensaje { get; set; }
            public string Hoy { get; set; }
            public bool EsAdministrador { get; set; }
            public CajaDto Caja { get; set; }
            public CajaResumenDto Resumen { get; set; }
            /// <summary>Solo sin caja abierta: último cierre, para proponer el fondo.</summary>
            public UltimoCierreDto UltimoCierre { get; set; }
        }

        public class ListaCajaDto<T>
        {
            public bool Ok { get; set; }
            public string Mensaje { get; set; }
            public List<T> Items { get; set; }
        }

        public class RespuestaCajaDto
        {
            public bool Ok { get; set; }
            public string Mensaje { get; set; }
        }

        [WebMethod(EnableSession = true)]
        public static EstadoCajaDto Estado()
        {
            string permiso = Permiso();
            if (permiso != null) return new EstadoCajaDto { Ok = false, Mensaje = permiso };
            try
            {
                var caja = CajaRepository.CajaActual(Sesion.Usuario);
                return new EstadoCajaDto
                {
                    Ok = true,
                    Hoy = DateTime.Today.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture),
                    EsAdministrador = Sesion.EsAdministrador,
                    Caja = caja,
                    Resumen = caja != null ? CajaRepository.Resumen(Sesion.Usuario, caja.Id) : null,
                    UltimoCierre = caja == null ? CajaRepository.UltimoCierre(Sesion.Usuario) : null
                };
            }
            catch (Exception ex) { return new EstadoCajaDto { Ok = false, Mensaje = Detalle(ex, "No fue posible consultar la caja.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static RespuestaCajaDto Abrir(decimal fondo)
        {
            return Accion(() => CajaRepository.Abrir(Sesion.Usuario, fondo), "Caja abierta. Ya puede cobrar.");
        }

        [WebMethod(EnableSession = true)]
        public static RespuestaCajaDto Cerrar(long id, decimal efectivoContado, string observaciones)
        {
            if (observaciones != null && observaciones.Length > 500) observaciones = observaciones.Substring(0, 500);
            return Accion(() => CajaRepository.Cerrar(Sesion.Usuario, id, efectivoContado, observaciones), "Caja cerrada.");
        }

        public class CuadreRespuestaDto
        {
            public bool Ok { get; set; }
            public string Mensaje { get; set; }
            public CuadreCajaDto Cuadre { get; set; }
        }

        /// <summary>Datos del cierre de la caja del usuario y aviso de procedimientos del día pendientes de facturar.</summary>
        [WebMethod(EnableSession = true)]
        public static CuadreRespuestaDto Cuadre(long id)
        {
            string permiso = Permiso();
            if (permiso != null) return new CuadreRespuestaDto { Ok = false, Mensaje = permiso };
            try { return new CuadreRespuestaDto { Ok = true, Cuadre = CajaRepository.Cuadre(Sesion.Usuario, id) }; }
            catch (Exception ex) { return new CuadreRespuestaDto { Ok = false, Mensaje = Detalle(ex, "No fue posible calcular el cuadre con los procedimientos.") }; }
        }

        /// <summary>Solo administradores: reabre la caja cerrada de hoy de quien la está viendo.</summary>
        [WebMethod(EnableSession = true)]
        public static RespuestaCajaDto Reabrir(long id)
        {
            if (Sesion.Activa && !Sesion.EsAdministrador) return new RespuestaCajaDto { Ok = false, Mensaje = "Solo un administrador puede reabrir la caja." };
            return Accion(() => CajaRepository.Reabrir(Sesion.Usuario, id), "Caja reabierta.");
        }

        /// <summary>desde / hasta yyyy-MM-dd (vacíos = sin límite).</summary>
        [WebMethod(EnableSession = true)]
        public static ListaCajaDto<PendienteCobroDto> Pendientes(string desde, string hasta, string texto)
        {
            string permiso = Permiso();
            if (permiso != null) return new ListaCajaDto<PendienteCobroDto> { Ok = false, Mensaje = permiso };
            try
            {
                if (texto != null && texto.Length > 100) texto = texto.Substring(0, 100);
                return new ListaCajaDto<PendienteCobroDto> { Ok = true, Items = CajaRepository.Pendientes(Sesion.Usuario, FechaN(desde), FechaN(hasta), texto) };
            }
            catch (Exception ex) { return new ListaCajaDto<PendienteCobroDto> { Ok = false, Mensaje = Detalle(ex, "No fue posible cargar los pendientes.") }; }
        }

        // ===== Cobro de citas por adelantado =====

        public class AnticipoRespuestaDto
        {
            public bool Ok { get; set; }
            public string Mensaje { get; set; }
            public long IdFactura { get; set; }
        }

        /// <summary>Citas activas de los próximos 30 días de la sucursal para cobrar por adelantado.</summary>
        [WebMethod(EnableSession = true)]
        public static ListaCajaDto<CitaPorCobrarDto> CitasPorCobrar(string texto)
        {
            string permiso = Permiso();
            if (permiso != null) return new ListaCajaDto<CitaPorCobrarDto> { Ok = false, Mensaje = permiso };
            try
            {
                if (texto != null && texto.Length > 100) texto = texto.Substring(0, 100);
                return new ListaCajaDto<CitaPorCobrarDto> { Ok = true, Items = CajaRepository.CitasPorCobrar(Sesion.Usuario, texto) };
            }
            catch (Exception ex) { return new ListaCajaDto<CitaPorCobrarDto> { Ok = false, Mensaje = Detalle(ex, "No fue posible cargar las citas.") }; }
        }

        /// <summary>Crea la factura del anticipo de la cita; el cobro y el DTE se hacen en frm_OpenFactura.aspx. Requiere la caja abierta.</summary>
        [WebMethod(EnableSession = true)]
        public static AnticipoRespuestaDto CobrarCita(long cita)
        {
            string permiso = Permiso();
            if (permiso != null) return new AnticipoRespuestaDto { Ok = false, Mensaje = permiso };
            try
            {
                string errCaja = CajaRepository.ValidarCajaAbierta(Sesion.Usuario);
                if (errCaja != null) return new AnticipoRespuestaDto { Ok = false, Mensaje = errCaja };
                return new AnticipoRespuestaDto { Ok = true, IdFactura = CajaRepository.CrearAnticipo(Sesion.Usuario, cita) };
            }
            catch (Exception ex) { return new AnticipoRespuestaDto { Ok = false, Mensaje = Detalle(ex, "No fue posible preparar el cobro de la cita.") }; }
        }

        /// <summary>Aplica el saldo a favor del paciente (anticipo de una cita cancelada) a esta cita.</summary>
        [WebMethod(EnableSession = true)]
        public static RespuestaCajaDto AplicarSaldo(long cita)
        {
            return Accion(() => CajaRepository.AplicarSaldo(Sesion.Usuario, cita), "Saldo a favor aplicado: la cita queda pagada por adelantado.");
        }

        // ===== Pago adelantado sin cita (monto libre): la cita queda pendiente de agendar =====

        /// <summary>Pacientes por nombre, documento o celular (mínimo 2 caracteres), para cobrarles un pago adelantado.</summary>
        [WebMethod(EnableSession = true)]
        public static ListaCajaDto<PacienteCajaDto> BuscarPacientes(string texto)
        {
            string permiso = Permiso();
            if (permiso != null) return new ListaCajaDto<PacienteCajaDto> { Ok = false, Mensaje = permiso };
            texto = (texto ?? "").Trim();
            if (texto.Length < 2) return new ListaCajaDto<PacienteCajaDto> { Ok = true, Items = new System.Collections.Generic.List<PacienteCajaDto>() };
            if (texto.Length > 100) texto = texto.Substring(0, 100);
            try
            {
                var r = Registros.ExpedientesRepository.Buscar(texto, null, 1, Sesion.Usuario);
                return new ListaCajaDto<PacienteCajaDto>
                {
                    Ok = true,
                    Items = r.Items.Take(10).Select(e => new PacienteCajaDto
                    {
                        Id = e.Id, Nombre = (e.Nombres + " " + e.Apellidos).Trim(), Documento = e.Documento, Celular = e.Celular
                    }).ToList()
                };
            }
            catch (Exception ex) { return new ListaCajaDto<PacienteCajaDto> { Ok = false, Mensaje = Detalle(ex, "No fue posible buscar pacientes.") }; }
        }

        /// <summary>Crea el pago adelantado sin cita por un monto libre; el cobro y el DTE se hacen en frm_OpenFactura.aspx. Requiere la caja abierta.</summary>
        [WebMethod(EnableSession = true)]
        public static AnticipoRespuestaDto CobrarSinCita(long expediente, decimal monto, string descripcion)
        {
            string permiso = Permiso();
            if (permiso != null) return new AnticipoRespuestaDto { Ok = false, Mensaje = permiso };
            if (expediente <= 0) return new AnticipoRespuestaDto { Ok = false, Mensaje = "Seleccione el paciente." };
            monto = Math.Round(monto, 2, MidpointRounding.AwayFromZero);
            if (monto <= 0) return new AnticipoRespuestaDto { Ok = false, Mensaje = "Escriba el monto del pago." };
            try
            {
                string errCaja = CajaRepository.ValidarCajaAbierta(Sesion.Usuario);
                if (errCaja != null) return new AnticipoRespuestaDto { Ok = false, Mensaje = errCaja };
                if (descripcion != null && descripcion.Length > 250) descripcion = descripcion.Substring(0, 250);
                return new AnticipoRespuestaDto { Ok = true, IdFactura = CajaRepository.CrearPagoSinCita(Sesion.Usuario, expediente, monto, descripcion) };
            }
            catch (Exception ex) { return new AnticipoRespuestaDto { Ok = false, Mensaje = Detalle(ex, "No fue posible preparar el pago adelantado.") }; }
        }

        /// <summary>Pagos adelantados con saldo de la sucursal (texto: paciente).</summary>
        [WebMethod(EnableSession = true)]
        public static ListaCajaDto<PagoAdelantadoDto> PagosAdelantados(string texto)
        {
            string permiso = Permiso();
            if (permiso != null) return new ListaCajaDto<PagoAdelantadoDto> { Ok = false, Mensaje = permiso };
            try
            {
                if (texto != null && texto.Length > 100) texto = texto.Substring(0, 100);
                return new ListaCajaDto<PagoAdelantadoDto> { Ok = true, Items = CajaRepository.PagosAdelantados(Sesion.Usuario, texto, 0) };
            }
            catch (Exception ex) { return new ListaCajaDto<PagoAdelantadoDto> { Ok = false, Mensaje = Detalle(ex, "No fue posible cargar los pagos adelantados.") }; }
        }

        /// <summary>La cita usará el pago adelantado más antiguo del paciente.</summary>
        [WebMethod(EnableSession = true)]
        public static RespuestaCajaDto UsarPagoAdelantado(long cita)
        {
            return Accion(() => CajaRepository.UsarPagoAdelantado(Sesion.Usuario, cita, 0), "Pago adelantado asignado: al atender la cita se descuenta y solo se cobra la diferencia.");
        }

        [WebMethod(EnableSession = true)]
        public static RespuestaCajaDto QuitarPagoAdelantado(long cita)
        {
            return Accion(() => CajaRepository.QuitarPagoAdelantado(Sesion.Usuario, cita), "La cita ya no usará el pago adelantado: queda pendiente de agendar.");
        }

        [WebMethod(EnableSession = true)]
        public static ListaCajaDto<SaldoFavorDto> SaldosFavor()
        {
            string permiso = Permiso();
            if (permiso != null) return new ListaCajaDto<SaldoFavorDto> { Ok = false, Mensaje = permiso };
            try { return new ListaCajaDto<SaldoFavorDto> { Ok = true, Items = CajaRepository.SaldosFavor(Sesion.Usuario) }; }
            catch (Exception ex) { return new ListaCajaDto<SaldoFavorDto> { Ok = false, Mensaje = Detalle(ex, "No fue posible cargar los saldos a favor.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static ListaCajaDto<DteListaDto> Emitidos(long id)
        {
            string permiso = Permiso();
            if (permiso != null) return new ListaCajaDto<DteListaDto> { Ok = false, Mensaje = permiso };
            try { return new ListaCajaDto<DteListaDto> { Ok = true, Items = CajaRepository.EmitidosCaja(Sesion.Usuario, id) }; }
            catch (Exception ex) { return new ListaCajaDto<DteListaDto> { Ok = false, Mensaje = Detalle(ex, "No fue posible cargar los documentos.") }; }
        }

        /// <summary>
        /// Entrada (tipo E: Reposición de fondo, Cambio (sencillo), Préstamo u Otro) o salida (tipo S: Gasto, Pago a proveedor,
        /// Depósito bancario, Retiro u Otro) de efectivo en la caja abierta de hoy.
        /// </summary>
        [WebMethod(EnableSession = true)]
        public static RespuestaCajaDto MovimientoEfectivo(long id, string tipo, decimal monto, string categoria, string motivo, string referencia)
        {
            if (motivo != null && motivo.Length > 250) return new RespuestaCajaDto { Ok = false, Mensaje = "El motivo no puede tener más de 250 caracteres." };
            if (referencia != null && referencia.Length > 50) referencia = referencia.Substring(0, 50);
            bool entrada = tipo == "E";
            return Accion(() => CajaRepository.RegistrarMovimiento(Sesion.Usuario, id, entrada ? "E" : "S", monto, categoria, motivo, referencia),
                (entrada ? "Entrada" : "Salida") + " de $" + monto.ToString("N2", CultureInfo.InvariantCulture) + " registrada.");
        }

        [WebMethod(EnableSession = true)]
        public static ListaCajaDto<SalidaCajaDto> Salidas(long id)
        {
            string permiso = Permiso();
            if (permiso != null) return new ListaCajaDto<SalidaCajaDto> { Ok = false, Mensaje = permiso };
            try { return new ListaCajaDto<SalidaCajaDto> { Ok = true, Items = CajaRepository.Salidas(Sesion.Usuario, id) }; }
            catch (Exception ex) { return new ListaCajaDto<SalidaCajaDto> { Ok = false, Mensaje = Detalle(ex, "No fue posible cargar el manejo de efectivo.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static RespuestaCajaDto AnularSalida(long salida, string motivo)
        {
            return Accion(() => CajaRepository.AnularSalida(Sesion.Usuario, salida, motivo), "Movimiento anulado. El efectivo de la caja se recalculó.");
        }

        private static RespuestaCajaDto Accion(Func<long> hacer, string exito)
        {
            string permiso = Permiso();
            if (permiso != null) return new RespuestaCajaDto { Ok = false, Mensaje = permiso };
            try { hacer(); return new RespuestaCajaDto { Ok = true, Mensaje = exito }; }
            catch (Exception ex) { return new RespuestaCajaDto { Ok = false, Mensaje = Detalle(ex, "No fue posible completar la acción.") }; }
        }

        private static DateTime? FechaN(string s)
        {
            DateTime d;
            return DateTime.TryParseExact(s ?? "", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out d) ? d : (DateTime?)null;
        }

        private static string Permiso()
        {
            if (!Sesion.Activa) return "La sesión expiró. Vuelva a iniciar sesión.";
            if (!Sesion.EsAdministrador && !Sesion.TieneAcceso(Url)) return "No tiene permiso para usar la caja.";
            return null;
        }

        private static string Detalle(Exception ex, string generico)
        {
            var sql = ex as SqlException;
            if (sql != null && sql.Number >= 50000) return sql.Message;
            System.Diagnostics.Trace.TraceError("Caja: " + ex);
            bool debug = HttpContext.Current != null && HttpContext.Current.IsDebuggingEnabled;
            return debug ? "[DEBUG] " + ex.Message : generico;
        }
    }
}
