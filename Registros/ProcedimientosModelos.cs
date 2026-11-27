using System;
using System.Collections.Generic;

namespace DPieCenter.Registros
{
    // ===== Atención de procedimientos (Registros/frm_Procedimientos.aspx) =====

    // Cita de la cola del día. Estado del procedimiento: '' sin llegar | S en espera | I en atención
    public class ColaItemDto
    {
        public long IdCita { get; set; }
        public string Hora { get; set; }
        public string HoraFin { get; set; }
        public long IdEspecialista { get; set; }
        public string Especialista { get; set; }
        public long IdExpediente { get; set; }
        public string Paciente { get; set; }
        public string Nombres { get; set; }
        public string Apellidos { get; set; }
        /// <summary>Nombre completo del especialista (el de su usuario), para el audio de la pantalla de turnos.</summary>
        public string EspecialistaCompleto { get; set; }
        /// <summary>dd/MM/yyyy (vacío si no tiene). No se envía a la pantalla pública de turnos.</summary>
        public string FechaNacimiento { get; set; }
        public string Edad { get; set; }
        public string TipoCita { get; set; }
        public string EstadoCita { get; set; }
        public long IdProcedimiento { get; set; }
        public string Estado { get; set; }
        public string InicioAtencion { get; set; }     // ISO yyyy-MM-ddTHH:mm:ss, para el cronómetro
        public string Tratamientos { get; set; }
        public bool Atrasada { get; set; }
        public int EsperaMin { get; set; }            // minutos esperando (desde la llegada a sala o la hora de la cita)
        public bool Sigue { get; set; }               // el de mayor tiempo de espera de su especialista

        // En sala ('S'): desde que se registró; sin llegar: desde la hora de la cita
        [System.Web.Script.Serialization.ScriptIgnore]
        public DateTime? EsperaDesde { get; set; }

        [System.Web.Script.Serialization.ScriptIgnore]
        public DateTime? Inicio { get; set; }
    }

    public class ColaDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public string HoraServidor { get; set; }
        public List<ColaItemDto> Items { get; set; }
    }

    public class TratamientoProcDto
    {
        public long Id { get; set; }
        public long IdTratamiento { get; set; }
        public string Descripcion { get; set; }
        public decimal Valor { get; set; }
        public decimal Descuento { get; set; }          // % vigente del tratamiento (0 = sin descuento)
        public decimal MontoDescuento { get; set; }
    }

    public class HistorialDto
    {
        public long IdProcedimiento { get; set; }
        public string Fecha { get; set; }
        public string Especialista { get; set; }
        public string Diagnostico { get; set; }
        public string Tratamientos { get; set; }
        public decimal Total { get; set; }
    }

    public class ProcedimientoDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public long IdProcedimiento { get; set; }
        public long IdCita { get; set; }
        public long IdExpediente { get; set; }
        public string Estado { get; set; }
        public string InicioAtencion { get; set; }
        public string HoraCita { get; set; }
        public string Comentarios { get; set; }
        public string Diagnostico { get; set; }
        public long IdEspecialista { get; set; }
        public string Especialista { get; set; }
        public string TipoCita { get; set; }
        public string Paciente { get; set; }
        public string Documento { get; set; }
        public string FechaNacimiento { get; set; }
        public string Edad { get; set; }
        public string Sexo { get; set; }
        public string Celular { get; set; }
        public string Email { get; set; }
        public string PersonaEmergencia { get; set; }
        public string TelefonoEmergencia { get; set; }
        public string Direccion { get; set; }
        public decimal Total { get; set; }              // con descuentos
        public decimal Descuento { get; set; }          // suma de los descuentos de los tratamientos
        public List<TratamientoProcDto> Tratamientos { get; set; }
        public List<HistorialDto> Historial { get; set; }
    }

    public class AtencionInicioDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public long EspecialistaUsuario { get; set; }
        public string EspecialistaNombre { get; set; }
        public List<OpcionDto> Especialistas { get; set; }
        public List<TratamientoDto> Catalogo { get; set; }
    }

    public class AccionDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public long Id { get; set; }
    }

    // ===== Procedimientos en curso de todos los especialistas (Facturacion/frm_ProcedimientosCurso.aspx) =====
    public class ProcedimientoCursoDto
    {
        public long IdProcedimiento { get; set; }
        public long IdCita { get; set; }
        public string Estado { get; set; }               // I en atención | S en sala
        public string Fecha { get; set; }                // dd/MM/yyyy de la cita
        public bool DeOtroDia { get; set; }              // quedó abierto desde un día anterior
        public string HoraCita { get; set; }             // 02:30 PM
        public string InicioAtencion { get; set; }       // 02:35 PM; vacío si sigue en sala
        public int Minutos { get; set; }                 // en atención: desde que inició; en sala: desde que llegó
        public long IdEspecialista { get; set; }
        public string Especialista { get; set; }
        public long IdExpediente { get; set; }
        public string Paciente { get; set; }
        public string Documento { get; set; }
        public string Celular { get; set; }
        public string TipoCita { get; set; }
        public int Tratamientos { get; set; }
        public string Detalle { get; set; }              // tratamientos del procedimiento
        public decimal Total { get; set; }
    }

    public class ProcedimientosCursoDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public string Actualizado { get; set; }          // 02:30:15 PM
        public List<ProcedimientoCursoDto> Items { get; set; }
        public List<OpcionDto> Especialistas { get; set; }
    }

    // ===== Pantalla de turnos para pacientes (Registros/frm_TurnosPacientes.aspx) =====
    // Solo nombre y la inicial del apellido: la pantalla está a la vista de la sala de espera.
    public class TurnoDto
    {
        public long Clave { get; set; }
        public string Paciente { get; set; }
        public string Especialista { get; set; }
        public string Hora { get; set; }
        public string Estado { get; set; }      // I en atención | S en sala | P programado
        public bool Sigue { get; set; }         // el de mayor tiempo de espera de su especialista
        /// <summary>Texto que se lee en voz alta al llamar: nombre completo del paciente y del especialista.</summary>
        public string Anuncio { get; set; }
    }

    public class TurnosDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public string HoraServidor { get; set; }
        public List<TurnoDto> Atendiendo { get; set; }
        public List<TurnoDto> Siguientes { get; set; }
        public List<string> Videos { get; set; }        // URLs relativas de assets/publicidad
        /// <summary>Si cambia, la pantalla se recarga sola para usar la versión nueva.</summary>
        public string Version { get; set; }
    }
}
