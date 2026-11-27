using System;
using System.Collections.Generic;

namespace DPieCenter.Registros
{
    public class ProfesionalDto
    {
        public long Id { get; set; }
        public string Profesional { get; set; }
    }

    public class TratamientoDto
    {
        public long Id { get; set; }
        public string Tratamiento { get; set; }
        public int DuracionMin { get; set; }
        public decimal Precio { get; set; }
        public string Imagen { get; set; }
        /// <summary>Descuento del tratamiento en % (Catálogos › Tratamientos); 0 = sin descuento.</summary>
        public decimal Descuento { get; set; }
    }

    public class SlotDto
    {
        public string Hora { get; set; }          // "HH:mm"
        public bool Disponible { get; set; }
    }

    public class DiaDto
    {
        public string Fecha { get; set; }         // "yyyy-MM-dd"
        public List<SlotDto> Slots { get; set; } = new List<SlotDto>();
    }

    public class SemanaDto
    {
        public string Lunes { get; set; }
        public int DuracionMin { get; set; }
        public List<DiaDto> Dias { get; set; } = new List<DiaDto>();
    }

    public class TipoCitaDto
    {
        public long Id { get; set; }
        public string TipoCita { get; set; }
    }

    public class PacienteDto
    {
        public long Codigo { get; set; }       // identificador del expediente (según el SP)
        public string Nombre { get; set; }
        public string Documento { get; set; }
        public string Celular { get; set; }
    }

    public class BusquedaDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public List<PacienteDto> Pacientes { get; set; } = new List<PacienteDto>();
    }

    public class CitaRequest
    {
        public long ProfesionalId { get; set; }
        public long TipoCitaId { get; set; }
        public string Fecha { get; set; }         // "yyyy-MM-dd"
        public string Hora { get; set; }          // "HH:mm"
        public List<int> TratamientoIds { get; set; }
        public long PacienteCodigo { get; set; }
        public string Documento { get; set; }
        public string PacienteNombre { get; set; }
        public string Notas { get; set; }
        public string Usuario { get; set; }       // $('#idUser').val()
    }

    public class ResultadoDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public long CitaId { get; set; }
        public decimal Total { get; set; }
    }

    // ===== Agenda tipo calendario =====
    public class OpcionDto
    {
        public long Id { get; set; }
        public string Texto { get; set; }
    }

    public class CatalogosDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public List<OpcionDto> Profesionales { get; set; } = new List<OpcionDto>();
        public List<OpcionDto> Tipos { get; set; } = new List<OpcionDto>();
        public List<OpcionDto> Estados { get; set; } = new List<OpcionDto>();
    }

    public class CitaAgendadaDto
    {
        public long Id { get; set; }
        public string Fecha { get; set; }         // "yyyy-MM-dd"
        public string Hora { get; set; }          // "HH:mm"
        public string Profesional { get; set; }   // filtro del calendario
        public string TipoCita { get; set; }
        public string Paciente { get; set; }      // texto visible de la cita
    }

    public class CitasSemanaDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public string Lunes { get; set; }
        public List<CitaAgendadaDto> Citas { get; set; } = new List<CitaAgendadaDto>();
    }

    public class CitaDetalleDto
    {
        public long Id { get; set; }
        public string Paciente { get; set; }
        public string Documento { get; set; }
        public string Email { get; set; }
        public string Celular { get; set; }
        public string Edad { get; set; }
        public string Direccion { get; set; }
        public string Especialista { get; set; }
        public string TipoCita { get; set; }
        public string Estado { get; set; }
        public string Fecha { get; set; }         // "yyyy-MM-dd"
        public string Hora { get; set; }          // "HH:mm"
        public string HoraFin { get; set; }       // "HH:mm"
        public int DuracionMin { get; set; }
        public long IdEspecialista { get; set; }
        public long IdTipoCita { get; set; }
        public long IdEstado { get; set; }
        public string HoraCierre { get; set; }    // "17:00" o "18:00" (Express)
        /// <summary>Tratamientos de la cita, solo para consulta en el modal (no se modifican desde ahí).</summary>
        public List<TratamientoCitaDto> Tratamientos { get; set; } = new List<TratamientoCitaDto>();
        /// <summary>Pago por adelantado en caja (0 si no tiene). Se conserva al cambiar fecha, hora o profesional.</summary>
        public long AnticipoFactura { get; set; }
        public decimal AnticipoMonto { get; set; }
        /// <summary>El anticipo es un pago adelantado sin cita (monto libre) que se usará en esta cita; AnticipoMonto = su saldo.</summary>
        public bool AnticipoLibre { get; set; }
        /// <summary>Pagos adelantados sin cita del paciente pendientes de agendar (para "Usar pago adelantado").</summary>
        public decimal PagosPendientes { get; set; }
        public string AnticipoFecha { get; set; }   // dd/MM/yyyy
    }

    public class TratamientoCitaDto
    {
        public string Tratamiento { get; set; }
        public decimal Valor { get; set; }
        public decimal Descuento { get; set; }          // % vigente del tratamiento (0 = sin descuento)
        public decimal MontoDescuento { get; set; }
    }

    public class DetalleResultadoDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public CitaDetalleDto Cita { get; set; }
    }

    public class CitaUpdateRequest
    {
        public long Cita { get; set; }
        public long Profesional { get; set; }
        public long Estado { get; set; }
        public string Fecha { get; set; }         // "yyyy-MM-dd"
        public string Hora { get; set; }          // "HH:mm"
        public string Usuario { get; set; }       // $('#idUser').val()
    }

    // Uso interno (no se envía al cliente)
    public class CitaAgendadaRaw
    {
        public long Id { get; set; }
        public DateTime Inicio { get; set; }
        public string Profesional { get; set; }
        public string TipoCita { get; set; }
        public string Paciente { get; set; }
    }


    // Uso interno (no se envía al cliente)
    public class RangoOcupado
    {
        public DateTime Inicio { get; set; }
        public DateTime Fin { get; set; }
    }
}
