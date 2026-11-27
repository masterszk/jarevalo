using System.Collections.Generic;

namespace DPieCenter.Registros
{
    // ===== Lista de expedientes (Registros/frm_ListaExpedientes.aspx) =====

    public class ExpedienteFilaDto
    {
        public long Id { get; set; }
        public string Nombres { get; set; }
        public string Apellidos { get; set; }
        public string Documento { get; set; }
        public string TipoDocumento { get; set; }
        public string Registro { get; set; }
        public string Celular { get; set; }
        public string Telefono { get; set; }
        public string Email { get; set; }
        public string Sexo { get; set; }
        public int Pais { get; set; }
        public int PaisTelefono { get; set; }
        public string Edad { get; set; }
        public string FechaNacimiento { get; set; }
        public string Ingreso { get; set; }
        public string UltimaVisita { get; set; }
        public string ProximaCita { get; set; }
        public int Visitas { get; set; }
    }

    public class ListaExpedientesDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public int Total { get; set; }
        public int Pagina { get; set; }
        public int Tamano { get; set; }
        public List<ExpedienteFilaDto> Items { get; set; }
    }

    public class LetraDto
    {
        public string Letra { get; set; }
        public int Cantidad { get; set; }
    }

    public class ResumenExpedientesDto
    {
        public int Total { get; set; }
        public int NuevosMes { get; set; }
        public int ConCitaHoy { get; set; }
        public int Activos90 { get; set; }
    }

    public class ExpedientesInicioDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public List<LetraDto> Letras { get; set; }
        public ResumenExpedientesDto Resumen { get; set; }
    }

    // Procedimiento finalizado del paciente, para asociarlo a un reclamo
    public class ProcedimientoReclamoDto
    {
        public long Id { get; set; }
        public string Fecha { get; set; }
        public long IdEspecialista { get; set; }
        public string Especialista { get; set; }
        public string Tratamientos { get; set; }
    }

    public class ProcedimientosReclamoDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public List<ProcedimientoReclamoDto> Items { get; set; }
    }

    // ===== Alta y edición (mismo formulario en la lista y en la ficha) =====
    public class ExpedienteEditDto
    {
        public long Id { get; set; }
        public string Nombres { get; set; }
        public string Apellidos { get; set; }
        public long TipoDocumento { get; set; }
        public string Documento { get; set; }
        public string Registro { get; set; }
        public string Nacimiento { get; set; }        // yyyy-MM-dd (input date)
        public long Sexo { get; set; }
        /// <summary>Nacionalidad (CAT_PAISES).</summary>
        public int Pais { get; set; }
        /// <summary>País de los teléfonos (código +503...). Los números van sin código, solo dígitos.</summary>
        public int PaisTelefono { get; set; }
        public string Telefono { get; set; }
        public string Celular { get; set; }
        public string Email { get; set; }
        public string PersonaEmergencia { get; set; }
        public string TelefonoEmergencia { get; set; }
        public long Departamento { get; set; }
        public long Municipio { get; set; }
        public string Direccion { get; set; }
        public bool Facebook { get; set; }
        public bool Instagram { get; set; }
        public bool Buscador { get; set; }
        public bool Recomendado { get; set; }
        public bool TikTok { get; set; }
        public bool WhatsApp { get; set; }
        public bool Otros { get; set; }
    }

    // ===== Ficha del paciente (Registros/frm_EditExpediente.aspx) =====
    public class PerfilPacienteDto : ExpedienteEditDto
    {
        public string TipoDocumentoTexto { get; set; }
        public string SexoTexto { get; set; }
        public string PaisTexto { get; set; }
        /// <summary>Pagos adelantados sin cita pendientes de agendar (saldo disponible).</summary>
        public decimal PagosAdelantados { get; set; }
        public string Ubicacion { get; set; }
        public string Edad { get; set; }
        public string Foto { get; set; }
        public string Creado { get; set; }            // "25/08/2026 por cfunes"
        public string Modificado { get; set; }
    }

    public class ResumenPacienteDto
    {
        public int Citas { get; set; }
        public int Atendidas { get; set; }
        public int Canceladas { get; set; }
        public int Procedimientos { get; set; }
        public int Reclamos { get; set; }
        public string UltimaVisita { get; set; }
        public string ProximaCita { get; set; }
    }

    public class FichaPacienteDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public PerfilPacienteDto Perfil { get; set; }
        public ResumenPacienteDto Resumen { get; set; }
    }

    public class CitaPacienteDto
    {
        public long Id { get; set; }
        public string Fecha { get; set; }
        public string Hora { get; set; }
        public string Especialista { get; set; }
        public string TipoCita { get; set; }
        public string Estado { get; set; }
        public string Color { get; set; }             // clase de Bootstrap de CAT_ESTADOSCITAS.Colors
        public string Comentarios { get; set; }
        public string Tratamientos { get; set; }
        public bool Futura { get; set; }
    }

    public class TratamientoPacienteDto
    {
        public string Descripcion { get; set; }
        public decimal Valor { get; set; }
    }

    public class ProcedimientoPacienteDto
    {
        public long Id { get; set; }
        public string Fecha { get; set; }
        public string Horario { get; set; }           // "10:00 - 10:49"
        public string Estado { get; set; }
        public string Especialista { get; set; }
        public string TipoCita { get; set; }
        public string Diagnostico { get; set; }
        public string Resultados { get; set; }
        public string Recomendaciones { get; set; }
        public string Comentarios { get; set; }
        public decimal Total { get; set; }
        public List<TratamientoPacienteDto> Tratamientos { get; set; }
    }

    public class ReclamoPacienteDto
    {
        public long Id { get; set; }
        public string Fecha { get; set; }
        public string Usuario { get; set; }
        public string Especialista { get; set; }
        public long IdProcedimiento { get; set; }
        public string FechaProcedimiento { get; set; }
        public string Reclamo { get; set; }
    }

    public class HistorialPacienteDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public List<CitaPacienteDto> Citas { get; set; }
        public List<ProcedimientoPacienteDto> Procedimientos { get; set; }
        public List<ReclamoPacienteDto> Reclamos { get; set; }
    }
}
