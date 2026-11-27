using System;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using System.Web;
using System.Web.Services;

namespace DPieCenter.Registros
{
    public partial class frm_ListaExpedientes : System.Web.UI.Page
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

        // ===== Lista (assets/js/expedientes.js) =====

        [WebMethod(EnableSession = true)]
        public static ExpedientesInicioDto Inicio(string user)
        {
            try { return ExpedientesRepository.Inicio(AgendaService.UsuarioActual(user)); }
            catch (Exception ex) { return new ExpedientesInicioDto { Ok = false, Mensaje = Detalle(ex, "No fue posible cargar el resumen de expedientes.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static ListaExpedientesDto Buscar(string texto, string letra, int pagina, string user)
        {
            try { return ExpedientesRepository.Buscar(texto, letra, pagina, AgendaService.UsuarioActual(user)); }
            catch (Exception ex) { return new ListaExpedientesDto { Ok = false, Mensaje = Detalle(ex, "No fue posible buscar los expedientes.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static AccionDto Eliminar(long id, string user)
        {
            try
            {
                ExpedientesRepository.Eliminar(id, AgendaService.UsuarioActual(user));
                return new AccionDto { Ok = true, Id = id, Mensaje = "Expediente eliminado." };
            }
            catch (Exception ex) { return new AccionDto { Ok = false, Mensaje = Detalle(ex, "No fue posible eliminar el expediente.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static ProcedimientosReclamoDto ProcedimientosPaciente(long id, string user)
        {
            try { return new ProcedimientosReclamoDto { Ok = true, Items = ExpedientesRepository.ProcedimientosPaciente(id, AgendaService.UsuarioActual(user)) }; }
            catch (Exception ex) { return new ProcedimientosReclamoDto { Ok = false, Mensaje = Detalle(ex, "No fue posible cargar los procedimientos del paciente.") }; }
        }

        /// <summary>Registra un reclamo sobre un procedimiento del paciente; el especialista es el que lo atendió.</summary>
        [WebMethod(EnableSession = true)]
        public static AccionDto GuardarReclamo(long expediente, long procedimiento, string reclamo, string user)
        {
            try
            {
                reclamo = (reclamo ?? "").Trim();
                if (reclamo.Length == 0) return new AccionDto { Ok = false, Mensaje = "Describa la Garantía de Servicios." };
                if (reclamo.Length > 2500) return new AccionDto { Ok = false, Mensaje = "La Garantía de Servicios no puede superar 2500 caracteres." };

                string usuario = AgendaService.UsuarioActual(user);
                var proc = ExpedientesRepository.ProcedimientosPaciente(expediente, usuario).FirstOrDefault(p => p.Id == procedimiento);
                if (proc == null) return new AccionDto { Ok = false, Mensaje = "Seleccione un procedimiento del paciente." };

                using (SqlProcess sqlProccess = new SqlProcess())
                {
                    string resp = sqlProccess.mtdEXP_Reclamos(0, expediente, proc.IdEspecialista, procedimiento, reclamo, usuario, 1);
                    return resp == "OK"
                        ? new AccionDto { Ok = true, Mensaje = "La Garantía de Servicios fue registrada." }
                        : new AccionDto { Ok = false, Mensaje = "No fue posible registrar la Garantía de Servicios." };
                }
            }
            catch (Exception ex) { return new AccionDto { Ok = false, Mensaje = Detalle(ex, "No fue posible registrar la Garantía de Servicios.") }; }
        }

        // ===== Alta de expediente =====

        // Mismas reglas que la edición de la ficha (ExpedientesService)
        [WebMethod(EnableSession = true)]
        public static AccionDto Guardar(ExpedienteEditDto expediente, string user)
        {
            try
            {
                string error = ExpedientesService.Guardar(expediente, 1, AgendaService.UsuarioActual(user));
                return error == null
                    ? new AccionDto { Ok = true, Mensaje = "Expediente registrado." }
                    : new AccionDto { Ok = false, Mensaje = error };
            }
            catch (Exception ex) { return new AccionDto { Ok = false, Mensaje = Detalle(ex, "No fue posible registrar el expediente.") }; }
        }

        // ===== Catálogos del formulario de alta =====

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
