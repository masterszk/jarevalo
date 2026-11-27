using System;
using System.Data.SqlClient;
using System.Globalization;
using System.Web;
using System.Web.Services;

namespace DPieCenter.Registros
{
    /// <summary>
    /// Atención de procedimientos. Cada especialista ve y atiende solo las citas que tiene asignadas:
    /// el especialista se obtiene del usuario (CAT_ESPECIALISTAS.UsaurioSystem), nunca del navegador.
    /// </summary>
    public partial class frm_Procedimientos : System.Web.UI.Page
    {
        // Mensaje de negocio que se muestra tal cual al usuario
        private class AvisoException : Exception { public AvisoException(string m) : base(m) { } }

        private const string SinEspecialista = "Su usuario no está asociado a un especialista activo. Solicite al administrador que lo asigne en el catálogo de especialistas.";

        protected void Page_Load(object sender, EventArgs e)
        {

        }

        // En modo debug se muestra el detalle real; en producción, un mensaje genérico.
        // Los errores de negocio del SP (THROW 50000+) se muestran tal cual.
        private static string Detalle(Exception ex, string generico)
        {
            var sql = ex as SqlException;
            if (sql != null && sql.Number >= 50000) return sql.Message;
            if (ex is AvisoException) return ex.Message;
            System.Diagnostics.Trace.TraceError(generico + ": " + ex);
            bool debug = HttpContext.Current != null && HttpContext.Current.IsDebuggingEnabled;
            return debug ? "[DEBUG] " + ex.GetType().Name + ": " + ex.Message : generico;
        }

        // Usuario y especialista que opera. Lanza AvisoException si el usuario no es especialista.
        private static long Especialista(string user, out string usuario)
        {
            usuario = AgendaService.UsuarioActual(user);
            var esp = ProcedimientosRepository.EspecialistaDeUsuario(usuario);
            if (esp == null) throw new AvisoException(SinEspecialista);
            return esp.Id;
        }

        private static AccionDto Accion(string user, Func<string, long, long> accion, string mensajeOk, string generico)
        {
            try
            {
                string usuario;
                long esp = Especialista(user, out usuario);
                return new AccionDto { Ok = true, Id = accion(usuario, esp), Mensaje = mensajeOk };
            }
            catch (Exception ex) { return new AccionDto { Ok = false, Mensaje = Detalle(ex, generico) }; }
        }

        // ===== Métodos invocados desde assets/js/procedimientos.js =====

        [WebMethod(EnableSession = true)]
        public static AtencionInicioDto Inicio(string user)
        {
            try
            {
                var esp = ProcedimientosRepository.EspecialistaDeUsuario(AgendaService.UsuarioActual(user));
                if (esp == null) return new AtencionInicioDto { Ok = false, Mensaje = SinEspecialista };
                return new AtencionInicioDto
                {
                    Ok = true,
                    EspecialistaUsuario = esp.Id,
                    EspecialistaNombre = esp.Texto,
                    Especialistas = CitasRepository.ObtenerEspecialistas(),
                    Catalogo = CitasRepository.ObtenerTratamientos()
                };
            }
            catch (Exception ex) { return new AtencionInicioDto { Ok = false, Mensaje = Detalle(ex, "No fue posible cargar los catálogos.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static ColaDto ObtenerCola(string user)
        {
            try
            {
                string usuario;
                long esp = Especialista(user, out usuario);
                return new ColaDto
                {
                    Ok = true,
                    HoraServidor = DateTime.Now.ToString("yyyy-MM-ddTHH:mm:ss", CultureInfo.InvariantCulture),
                    Items = ProcedimientosRepository.Cola(esp, Sesion.Sucursal)
                };
            }
            catch (Exception ex) { return new ColaDto { Ok = false, Mensaje = Detalle(ex, "No fue posible cargar la cola del día.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static ProcedimientoDto ObtenerProcedimiento(long procedimiento, string user)
        {
            try
            {
                string usuario;
                long esp = Especialista(user, out usuario);
                var d = ProcedimientosRepository.Procedimiento(procedimiento);
                if (d == null) return new ProcedimientoDto { Ok = false, Mensaje = "El procedimiento no existe." };
                if (d.IdEspecialista != esp) return new ProcedimientoDto { Ok = false, Mensaje = "El procedimiento no está asignado a su usuario." };
                return d;
            }
            catch (Exception ex) { return new ProcedimientoDto { Ok = false, Mensaje = Detalle(ex, "No fue posible cargar el procedimiento.") }; }
        }

        /// <summary>Llama al paciente con más tiempo de espera del especialista.</summary>
        [WebMethod(EnableSession = true)]
        public static AccionDto LlamarSiguiente(string user)
        {
            return Accion(user, (u, esp) =>
            {
                var sig = ProcedimientosRepository.Siguiente(esp);
                if (sig == null) throw new AvisoException("No hay pacientes pendientes en la cola de hoy.");
                return ProcedimientosRepository.Llamar(sig.IdCita, u, esp);
            }, "Paciente llamado a atención.", "No fue posible iniciar la atención.");
        }

        [WebMethod(EnableSession = true)]
        public static AccionDto Llamar(long cita, string user)
        {
            return Accion(user, (u, esp) => ProcedimientosRepository.Llamar(cita, u, esp),
                "Paciente llamado a atención.", "No fue posible iniciar la atención.");
        }

        [WebMethod(EnableSession = true)]
        public static AccionDto AgregarTratamiento(long procedimiento, long tratamiento, string user)
        {
            return Accion(user, (u, esp) => ProcedimientosRepository.AgregarTratamiento(procedimiento, tratamiento, u, esp),
                "Tratamiento agregado.", "No fue posible agregar el tratamiento.");
        }

        [WebMethod(EnableSession = true)]
        public static AccionDto QuitarTratamiento(long procedimiento, long item, string user)
        {
            return Accion(user, (u, esp) => ProcedimientosRepository.QuitarTratamiento(procedimiento, item, u, esp),
                "Tratamiento quitado.", "No fue posible quitar el tratamiento.");
        }

        [WebMethod(EnableSession = true)]
        public static AccionDto GuardarDiagnostico(long procedimiento, string diagnostico, string user)
        {
            return Accion(user, (u, esp) => { ProcedimientosRepository.GuardarDiagnostico(procedimiento, Limpio(diagnostico), u, esp); return procedimiento; },
                "Diagnóstico guardado.", "No fue posible guardar el diagnóstico.");
        }

        [WebMethod(EnableSession = true)]
        public static AccionDto Finalizar(long procedimiento, string diagnostico, string user)
        {
            return Accion(user, (u, esp) => ProcedimientosRepository.Finalizar(procedimiento, Limpio(diagnostico), u, esp),
                "Procedimiento finalizado. La factura quedó pendiente de cobro en Caja.", "No fue posible finalizar el procedimiento.");
        }

        // Reprogramar, cambiar de especialista y cancelar: Facturacion/frm_ProcedimientosCurso.aspx

        private static string Limpio(string s)
        {
            return string.IsNullOrWhiteSpace(s) ? null : s.Trim();
        }
    }
}
