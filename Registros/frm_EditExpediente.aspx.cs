using System;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using System.Web;
using System.Web.Services;

namespace DPieCenter.Registros
{
    /// <summary>Ficha del paciente: datos personales, foto e historial (citas, procedimientos y reclamos).</summary>
    public partial class frm_EditExpediente : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {

        }

        // En modo debug se muestra el detalle real; en producción, un mensaje genérico.
        // Los errores de negocio del SP (THROW 50000+) se muestran tal cual.
        private static string Detalle(Exception ex, string generico)
        {
            var sql = ex as SqlException;
            if (sql != null && sql.Number >= 50000) return sql.Message;
            System.Diagnostics.Trace.TraceError(generico + ": " + ex);
            bool debug = HttpContext.Current != null && HttpContext.Current.IsDebuggingEnabled;
            return debug ? "[DEBUG] " + ex.GetType().Name + ": " + ex.Message : generico;
        }

        // ===== Métodos invocados desde assets/js/expediente-ficha.js =====

        [WebMethod(EnableSession = true)]
        public static FichaPacienteDto Ficha(long id, string user)
        {
            try
            {
                var usuario = AgendaService.UsuarioActual(user);
                var f = ExpedientesRepository.Ficha(id, usuario);
                // pagos adelantados sin cita pendientes de agendar (Caja › Cobrar sin cita)
                if (f.Perfil != null)
                    try { f.Perfil.PagosAdelantados = Facturacion.CajaRepository.PagosAdelantados(usuario, null, id).Where(p => p.IdCita == 0).Sum(p => p.Disponible); }
                    catch (Exception ex) { System.Diagnostics.Trace.TraceError("Pagos adelantados de la ficha: " + ex); }
                return f;
            }
            catch (Exception ex) { return new FichaPacienteDto { Ok = false, Mensaje = Detalle(ex, "No fue posible cargar el expediente.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static HistorialPacienteDto Historial(long id, string user)
        {
            try { return ExpedientesRepository.Historial(id, AgendaService.UsuarioActual(user)); }
            catch (Exception ex) { return new HistorialPacienteDto { Ok = false, Mensaje = Detalle(ex, "No fue posible cargar el historial.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static AccionDto Guardar(ExpedienteEditDto expediente, string user)
        {
            try
            {
                if (expediente == null || expediente.Id <= 0) return new AccionDto { Ok = false, Mensaje = "Expediente no válido." };
                string error = ExpedientesService.Guardar(expediente, 2, AgendaService.UsuarioActual(user));
                return error == null
                    ? new AccionDto { Ok = true, Id = expediente.Id, Mensaje = "Datos del paciente actualizados." }
                    : new AccionDto { Ok = false, Mensaje = error };
            }
            catch (Exception ex) { return new AccionDto { Ok = false, Mensaje = Detalle(ex, "No fue posible guardar los datos del paciente.") }; }
        }

        /// <summary>foto: data URL o base64 de la imagen elegida; se valida y reduce en el servidor.</summary>
        [WebMethod(EnableSession = true)]
        public static AccionDto GuardarFoto(long id, string foto, string user)
        {
            try
            {
                string normalizada = ExpedientesService.NormalizarFoto(foto);
                ExpedientesRepository.GuardarFoto(id, normalizada, AgendaService.UsuarioActual(user));
                return new AccionDto { Ok = true, Id = id, Mensaje = normalizada };
            }
            catch (ArgumentException ex) { return new AccionDto { Ok = false, Mensaje = ex.Message }; }
            catch (Exception ex) { return new AccionDto { Ok = false, Mensaje = Detalle(ex, "No fue posible guardar la foto.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static AccionDto QuitarFoto(long id, string user)
        {
            try
            {
                ExpedientesRepository.GuardarFoto(id, null, AgendaService.UsuarioActual(user));
                return new AccionDto { Ok = true, Id = id, Mensaje = "Foto eliminada." };
            }
            catch (Exception ex) { return new AccionDto { Ok = false, Mensaje = Detalle(ex, "No fue posible quitar la foto.") }; }
        }

        // ===== Catálogos del formulario (assets/js/expediente-form.js) =====

        private static string Opciones(Func<SqlProcess, string> consulta)
        {
            try
            {
                using (SqlProcess sqlProccess = new SqlProcess())
                {
                    consulta(sqlProccess);
                    string mensaje = "OK||<option value=\"-1\">--Seleccione una opción--</option>";
                    foreach (DataRow Reg in sqlProccess.dtReturn.Rows)
                        mensaje += "<option value=\"" + HttpUtility.HtmlAttributeEncode(Reg[0].ToString()) + "\">" + HttpUtility.HtmlEncode(Reg[1].ToString()) + "</option>";
                    return mensaje;
                }
            }
            catch (Exception ex)
            {
                return "ERROR||" + Detalle(ex, "No fue posible cargar el catálogo.");
            }
        }

        [WebMethod]
        public static string mtd_leeDepartamentos(long accion)
        {
            return Opciones(s => s.mtdCAT_Departamentos(0, "", "", "", accion));
        }

        [WebMethod]
        public static string mtd_leeMunicipios(string departamento, long accion)
        {
            return Opciones(s => s.mtdCAT_Municipios(0, "", departamento, "", accion));
        }

        [WebMethod]
        public static string mtd_leeSexo(long accion)
        {
            return Opciones(s => s.mtdCAT_Sexos(0, "", "0", "", accion));
        }

        [WebMethod]
        public static string mtd_LeeTiposDocumentos(long accion)
        {
            return Opciones(s => s.mtdCAT_TiposDocumentos(0, "", "0", "", accion));
        }

        /// <summary>Países con el formato de teléfono y documento (nacionalidad y teléfonos).</summary>
        [WebMethod]
        public static System.Collections.Generic.List<PaisDto> Paises() { return PaisesRepository.Lista(); }
    }
}
