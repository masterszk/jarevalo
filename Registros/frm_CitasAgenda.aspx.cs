using System;
using System.Collections.Generic;
using System.Configuration;
using System.Globalization;
using System.Linq;
using System.Web.Services;
using System.Web.UI;

namespace DPieCenter.Registros
{
    public partial class frm_CitasAgenda : Page
    {
        protected string NombreClinica
        {
            get { return ConfigurationManager.AppSettings["NombreClinica"] ?? "DPie Center"; }
        }

        protected void Page_Load(object sender, EventArgs e) { }

        // ===== Métodos invocados por jQuery $.ajax (frm_CitasAgenda.aspx/NombreMetodo) =====

        [WebMethod(EnableSession = true)]
        public static List<TipoCitaDto> ObtenerTiposCita(string user)
        {
            return AgendaService.ObtenerTiposCita(user);
        }

        [WebMethod]
        public static List<ProfesionalDto> ObtenerProfesionales()
        {
            return CitasRepository.ObtenerProfesionales();
        }

        [WebMethod]
        public static List<TratamientoDto> ObtenerTratamientos()
        {
            return CitasRepository.ObtenerTratamientos();
        }

        [WebMethod]
        public static SemanaDto ObtenerSemana(string fecha, int profesionalId, int duracionMin, int tipoCitaId)
        {
            DateTime f;
            if (!DateTime.TryParseExact(fecha, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out f))
                f = DateTime.Today;

            return AgendaService.ObtenerSemana(f, profesionalId, duracionMin, tipoCitaId == AgendaService.TipoExpressId);
        }

        [WebMethod(EnableSession = true)]
        public static BusquedaDto BuscarPacientes(int tipo, string termino, string user)
        {
            try
            {
                return AgendaService.BuscarPacientes(tipo, termino, user);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Trace.TraceError("BuscarPacientes: " + ex);
                // Con <compilation debug="true"> se muestra el detalle real para diagnosticar; en producción, mensaje genérico
                bool debug = System.Web.HttpContext.Current != null && System.Web.HttpContext.Current.IsDebuggingEnabled;
                return new BusquedaDto
                {
                    Ok = false,
                    Mensaje = debug ? "[DEBUG] " + ex.GetType().Name + ": " + ex.Message
                                   : "No fue posible realizar la búsqueda. Intente nuevamente."
                };
            }
        }

        [WebMethod(EnableSession = true)]
        public static ResultadoDto CrearCita(CitaRequest req)
        {
            try
            {
                return AgendaService.CrearCita(req);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Trace.TraceError("CrearCita: " + ex);
                return new ResultadoDto { Ok = false, Mensaje = "No fue posible registrar la cita. Intente nuevamente." };
            }
        }
    }
}
