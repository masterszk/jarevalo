using System;
using System.Globalization;
using System.Web.Services;
using DPieCenter.Opciones;
using DPieCenter.Registros;

namespace DPieCenter.Facturacion
{
    /// <summary>
    /// Procedimientos en curso de todos los especialistas (assets/js/procedimientos-curso.js):
    /// reprogramar, cambiar de especialista y cancelar. La atención solo la finaliza el especialista (Registros/frm_Procedimientos.aspx).
    /// Las reglas (procedimiento abierto, horario libre, tratamientos) las valida dbo.EXP_SP_Procedimientos_Atencion.
    /// </summary>
    public partial class frm_ProcedimientosCurso : System.Web.UI.Page
    {
        private const string Url = "Facturacion/frm_ProcedimientosCurso.aspx";
        private const long SinRestriccion = 0;   // @usuarioEsp = 0: cualquier especialista

        protected void Page_Load(object sender, EventArgs e)
        {

        }

        private static AccionDto Accion(Func<string, long> accion, string mensajeOk, string generico)
        {
            string permiso = AdministracionWeb.Permiso(Url);
            if (permiso != null) return new AccionDto { Ok = false, Mensaje = permiso };
            try { return new AccionDto { Ok = true, Id = accion(Sesion.Usuario), Mensaje = mensajeOk }; }
            catch (Exception ex) { return new AccionDto { Ok = false, Mensaje = AdministracionWeb.Detalle(ex, generico) }; }
        }

        [WebMethod(EnableSession = true)]
        public static ProcedimientosCursoDto Lista()
        {
            string permiso = AdministracionWeb.Permiso(Url);
            if (permiso != null) return new ProcedimientosCursoDto { Ok = false, Mensaje = permiso };
            try
            {
                return new ProcedimientosCursoDto
                {
                    Ok = true,
                    Actualizado = Formato.HoraSegundos(DateTime.Now),
                    Items = ProcedimientosRepository.EnCurso(0, Sesion.Sucursal),    // los de la sucursal en la que trabaja
                    Especialistas = CitasRepository.ObtenerEspecialistas()
                };
            }
            catch (Exception ex) { return new ProcedimientosCursoDto { Ok = false, Mensaje = AdministracionWeb.Detalle(ex, "No fue posible cargar los procedimientos en curso.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static AccionDto CambiarEspecialista(long procedimiento, long especialista)
        {
            if (especialista <= 0) return new AccionDto { Ok = false, Mensaje = "Seleccione el especialista." };
            return Accion(u => { ProcedimientosRepository.CambiarEspecialista(procedimiento, especialista, u, SinRestriccion); return procedimiento; },
                "Especialista cambiado.", "No fue posible cambiar el especialista.");
        }

        [WebMethod(EnableSession = true)]
        public static AccionDto Cancelar(long procedimiento, string motivo)
        {
            motivo = (motivo ?? "").Trim();
            if (motivo.Length < 5) return new AccionDto { Ok = false, Mensaje = "Escriba el motivo de la cancelación (al menos 5 caracteres)." };
            if (motivo.Length > 250) motivo = motivo.Substring(0, 250);
            return Accion(u => { ProcedimientosRepository.Cancelar(procedimiento, motivo, u, SinRestriccion); return procedimiento; },
                "La atención y la cita fueron canceladas.", "No fue posible cancelar.");
        }

        /// <summary>fecha con formato yyyy-MM-dd HH:mm (valor de flatpickr). Debe caer dentro del horario de atención.</summary>
        [WebMethod(EnableSession = true)]
        public static AccionDto Reprogramar(long cita, string fecha)
        {
            DateTime inicio;
            if (!DateTime.TryParseExact((fecha ?? "").Trim(), "yyyy-MM-dd HH:mm", CultureInfo.InvariantCulture, DateTimeStyles.None, out inicio))
                return new AccionDto { Ok = false, Mensaje = "Seleccione una fecha y hora válidas." };

            TimeSpan apertura, cierre;
            AgendaService.Horario(inicio.DayOfWeek, false, out apertura, out cierre);
            if (inicio.TimeOfDay < apertura || inicio.TimeOfDay >= cierre)
                return new AccionDto { Ok = false, Mensaje = "La hora debe estar entre " + Formato.Hora(apertura) + " y " + Formato.Hora(cierre) + "." };

            return Accion(u => ProcedimientosRepository.Reprogramar(cita, inicio, u, SinRestriccion),
                "Cita reprogramada para el " + Formato.FechaHora(inicio) + ".", "No fue posible reprogramar la cita.");
        }
    }
}
