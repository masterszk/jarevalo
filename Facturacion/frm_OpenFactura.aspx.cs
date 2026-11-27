using System;
using System.Collections.Generic;
using System.Web;
using System.Web.Services;

namespace DPieCenter.Facturacion
{
    public partial class frm_OpenFactura : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {

        }

        // En modo debug se muestra el detalle real; en producción, un mensaje genérico
        private static string Detalle(Exception ex, string generico)
        {
            System.Diagnostics.Trace.TraceError(generico + ": " + ex);
            bool debug = HttpContext.Current != null && HttpContext.Current.IsDebuggingEnabled;
            return debug ? "[DEBUG] " + ex.GetType().Name + ": " + ex.Message : generico;
        }

        // ===== Métodos invocados desde assets/js/pago-factura.js =====

        [WebMethod(EnableSession = true)]
        public static FacturaPagoDto ObtenerFactura(long factura, string user)
        {
            try { return DteService.ObtenerFactura(factura, Registros.AgendaService.UsuarioActual(user)); }
            catch (Exception ex) { return new FacturaPagoDto { Ok = false, Mensaje = Detalle(ex, "No fue posible cargar la factura.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static List<OpcionPagoDto> ObtenerFormasPago()
        {
            return DteRepository.ObtenerFormasPago();
        }

        [WebMethod(EnableSession = true)]
        public static ServiciosDto ObtenerServicios(string user)
        {
            try { return new ServiciosDto { Ok = true, Servicios = DteRepository.ObtenerServicios(Registros.AgendaService.UsuarioActual(user)) }; }
            catch (Exception ex) { return new ServiciosDto { Ok = false, Mensaje = Detalle(ex, "No fue posible cargar los servicios.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static FacturaPagoDto AgregarServicio(long factura, long servicio, string user)
        {
            try
            {
                string u = Registros.AgendaService.UsuarioActual(user);
                DteRepository.AgregarServicio(factura, servicio, u);
                return DteService.ObtenerFactura(factura, u);
            }
            catch (System.Data.SqlClient.SqlException ex) when (ex.Number >= 50000) { return new FacturaPagoDto { Ok = false, Mensaje = ex.Message }; }
            catch (Exception ex) { return new FacturaPagoDto { Ok = false, Mensaje = Detalle(ex, "No fue posible agregar el servicio.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static FacturaPagoDto QuitarServicio(long factura, long detalle, string user)
        {
            try
            {
                string u = Registros.AgendaService.UsuarioActual(user);
                DteRepository.QuitarServicio(factura, detalle, u);
                return DteService.ObtenerFactura(factura, u);
            }
            catch (System.Data.SqlClient.SqlException ex) when (ex.Number >= 50000) { return new FacturaPagoDto { Ok = false, Mensaje = ex.Message }; }
            catch (Exception ex) { return new FacturaPagoDto { Ok = false, Mensaje = Detalle(ex, "No fue posible quitar el servicio.") }; }
        }

        /// <summary>Aplica el cupón escaneado (código del QR) a la factura y devuelve la factura con el descuento.</summary>
        [WebMethod(EnableSession = true)]
        public static FacturaPagoDto AplicarCupon(long factura, string codigo, string user)
        {
            try
            {
                string u = Registros.AgendaService.UsuarioActual(user);
                codigo = (codigo ?? "").Trim().ToUpperInvariant();
                if (!System.Text.RegularExpressions.Regex.IsMatch(codigo, "^DPC-[A-Z]{8}$"))
                    return new FacturaPagoDto { Ok = false, Mensaje = "El código no es un cupón válido (DPC- y 8 letras)." };
                Registros.CuponesRepository.AplicarAFactura(codigo, factura, u);
                return DteService.ObtenerFactura(factura, u);
            }
            catch (System.Data.SqlClient.SqlException ex) when (ex.Number >= 50000) { return new FacturaPagoDto { Ok = false, Mensaje = ex.Message }; }
            catch (Exception ex) { return new FacturaPagoDto { Ok = false, Mensaje = Detalle(ex, "No fue posible aplicar el cupón.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static FacturaPagoDto QuitarCupon(long factura, string user)
        {
            try
            {
                string u = Registros.AgendaService.UsuarioActual(user);
                Registros.CuponesRepository.QuitarDeFactura(factura, u);
                return DteService.ObtenerFactura(factura, u);
            }
            catch (Exception ex) { return new FacturaPagoDto { Ok = false, Mensaje = Detalle(ex, "No fue posible quitar el cupón.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static ReceptorResultadoDto BuscarReceptor(string nit, string user)
        {
            try
            {
                string n = System.Text.RegularExpressions.Regex.Replace(nit ?? "", "[^0-9]", "");
                if (n.Length != 9 && n.Length != 14) return new ReceptorResultadoDto { Ok = false, Mensaje = "Ingrese un NIT de 14 dígitos (o DUI de 9)." };
                var r = DteRepository.BuscarReceptor(null, n, Registros.AgendaService.UsuarioActual(user));
                return new ReceptorResultadoDto { Ok = r != null, Receptor = r, Mensaje = r == null ? "No hay datos guardados para ese NIT." : "" };
            }
            catch (Exception ex) { return new ReceptorResultadoDto { Ok = false, Mensaje = Detalle(ex, "No fue posible buscar el NIT.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static PagoResultadoDto PagarFactura(PagoRequest req)
        {
            try { return DteService.Pagar(req); }
            catch (Exception ex)
            {
                // en producción (sin debug) el mensaje es genérico: el error real queda en Facturación > Diagnóstico DTE
                DteRepository.RegistrarEvento(0, "Pago", false, "Factura " + (req != null ? req.Factura : 0) + ": " + ex, Sesion.Usuario);
                return new PagoResultadoDto { Ok = false, Mensaje = Detalle(ex, "No fue posible registrar el pago. El detalle quedó en Facturación > Diagnóstico DTE.") };
            }
        }

        /// <summary>Servicios sin costo: cierra la factura con un ticket POS en lugar de DTE.</summary>
        [WebMethod(EnableSession = true)]
        public static PagoResultadoDto EmitirTicket(long factura, string user)
        {
            try { return DteService.EmitirTicket(factura, user); }
            catch (Exception ex)
            {
                DteRepository.RegistrarEvento(0, "Ticket", false, "Factura " + factura + ": " + ex, Sesion.Usuario);
                return new PagoResultadoDto { Ok = false, Mensaje = Detalle(ex, "No fue posible emitir el ticket.") };
            }
        }

        /// <summary>Ticket de 80 mm de lo facturado (DTE de la factura): se imprime al cobrar y se puede reimprimir.</summary>
        [WebMethod(EnableSession = true)]
        public static TicketVentaDto TicketVentaFactura(long factura)
        {
            if (!Sesion.Activa) return new TicketVentaDto { Ok = false, Mensaje = "La sesión expiró. Vuelva a iniciar sesión." };
            try { return TicketVenta.DeFactura(factura); }
            catch (Exception ex) { return new TicketVentaDto { Ok = false, Mensaje = Detalle(ex, "No fue posible preparar el ticket.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static PagoResultadoDto EnviarCorreo(long factura, string correo, string user)
        {
            try { return DteService.ReenviarCorreo(factura, correo, Registros.AgendaService.UsuarioActual(user)); }
            catch (Exception ex) { return new PagoResultadoDto { Ok = false, Mensaje = Detalle(ex, "No fue posible enviar el correo.") }; }
        }
    }
}
