using System;
using System.Web.Services;
using System.Web.UI;
using System.Configuration;

namespace DPieCenter.Registros
{
    public partial class frm_CitasCalendario : Page
    {
        protected string NombreClinica
        {
            get { return ConfigurationManager.AppSettings["NombreClinica"] ?? "Clínica Podológica"; }
        }

        protected void Page_Load(object sender, EventArgs e) { }

        // En modo debug se muestra el detalle real; en producción, un mensaje genérico
        private static string Detalle(Exception ex, string generico)
        {
            System.Diagnostics.Trace.TraceError(generico + ": " + ex);
            bool debug = System.Web.HttpContext.Current != null && System.Web.HttpContext.Current.IsDebuggingEnabled;
            return debug ? "[DEBUG] " + ex.GetType().Name + ": " + ex.Message : generico;
        }

        [WebMethod(EnableSession = true)]
        public static CatalogosDto ObtenerCatalogos()
        {
            try { return AgendaService.ObtenerCatalogos(); }
            catch (Exception ex) { return new CatalogosDto { Ok = false, Mensaje = Detalle(ex, "No fue posible cargar los catálogos.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static CitasSemanaDto ObtenerCitasSemana(string fecha)
        {
            try { return AgendaService.ObtenerCitasSemana(fecha); }
            catch (Exception ex) { return new CitasSemanaDto { Ok = false, Mensaje = Detalle(ex, "No fue posible cargar la agenda.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static DetalleResultadoDto ObtenerCita(long id)
        {
            try { return AgendaService.ObtenerCita(id); }
            catch (Exception ex) { return new DetalleResultadoDto { Ok = false, Mensaje = Detalle(ex, "No fue posible cargar la cita.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static ResultadoDto GuardarCita(CitaUpdateRequest req)
        {
            try { return AgendaService.ActualizarCita(req); }
            catch (Exception ex) { return new ResultadoDto { Ok = false, Mensaje = Detalle(ex, "No fue posible guardar la cita.") }; }
        }

        /// <summary>Botón "Cancelar cita": la cita queda Cancelada y libera la hora y al especialista.</summary>
        [WebMethod(EnableSession = true)]
        public static ResultadoDto CancelarCita(long id, string motivo, string user)
        {
            try { return AgendaService.CancelarCita(id, motivo, user); }
            catch (Exception ex) { return new ResultadoDto { Ok = false, Mensaje = Detalle(ex, "No fue posible cancelar la cita.") }; }
        }

        /// <summary>"Usar pago adelantado": la cita usará el pago adelantado sin cita del paciente (el más antiguo pendiente de agendar).</summary>
        [WebMethod(EnableSession = true)]
        public static ResultadoDto UsarPagoAdelantado(long id)
        {
            return PagoAdelantado(id, false);
        }

        /// <summary>La cita ya no usará el pago adelantado: vuelve a pendiente de agendar.</summary>
        [WebMethod(EnableSession = true)]
        public static ResultadoDto QuitarPagoAdelantado(long id)
        {
            return PagoAdelantado(id, true);
        }

        private static ResultadoDto PagoAdelantado(long id, bool quitar)
        {
            if (!Sesion.Activa) return new ResultadoDto { Ok = false, Mensaje = "La sesión expiró. Vuelva a iniciar sesión." };
            try
            {
                if (quitar) Facturacion.CajaRepository.QuitarPagoAdelantado(Sesion.Usuario, id);
                else Facturacion.CajaRepository.UsarPagoAdelantado(Sesion.Usuario, id, 0);
                return new ResultadoDto
                {
                    Ok = true, CitaId = id,
                    Mensaje = quitar ? "La cita ya no usará el pago adelantado: queda pendiente de agendar."
                                     : "Pago adelantado asignado: al atender la cita se descuenta y solo se cobra la diferencia."
                };
            }
            catch (System.Data.SqlClient.SqlException ex) when (ex.Number >= 50000) { return new ResultadoDto { Ok = false, Mensaje = ex.Message }; }
            catch (Exception ex) { return new ResultadoDto { Ok = false, Mensaje = Detalle(ex, "No fue posible actualizar el pago adelantado.") }; }
        }
    }
}
