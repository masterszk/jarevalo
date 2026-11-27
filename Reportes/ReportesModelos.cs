using System.Collections.Generic;

namespace DPieCenter.Reportes
{
    // ===== Dashboard (Dashboard/form_DashboardGeneral.aspx) =====

    public class IndicadoresDto
    {
        public int Pacientes { get; set; }
        public int PacientesNuevos { get; set; }
        public int PacientesAtendidos { get; set; }
        public int Citas { get; set; }
        public int CitasAtendidas { get; set; }
        public int CitasCanceladas { get; set; }
        public int CitasPendientes { get; set; }
        public decimal Asistencia { get; set; }          // % atendidas sobre citas ya pasadas (atendidas + canceladas)
        public int Procedimientos { get; set; }
        public decimal? Facturado { get; set; }          // solo administradores
        public decimal? Cobrado { get; set; }
        public decimal? TicketPromedio { get; set; }
        public decimal? MinutosPromedio { get; set; }
        public int EnAtencion { get; set; }
        public int EnSala { get; set; }
    }

    public class CitasDiaDto
    {
        public string Dia { get; set; }                 // yyyy-MM-dd
        public int Total { get; set; }
        public int Atendidas { get; set; }
        public int Canceladas { get; set; }
        public int Procedimientos { get; set; }
        public int Nuevos { get; set; }                 // expedientes creados ese día
        public decimal? Ingresos { get; set; }          // cobrado en caja ese día (solo administradores)
        public decimal? IngresosEfectivo { get; set; }
    }

    // Mismos indicadores en el periodo anterior de igual duración (para la variación %)
    public class ComparativoDto
    {
        public string Desde { get; set; }
        public string Hasta { get; set; }
        public int PacientesNuevos { get; set; }
        public int PacientesAtendidos { get; set; }
        public int Citas { get; set; }
        public int CitasAtendidas { get; set; }
        public int CitasCanceladas { get; set; }
        public decimal Asistencia { get; set; }
        public int Procedimientos { get; set; }
        public decimal? Facturado { get; set; }
    }

    public class PacienteRecurrenteDto
    {
        public long Id { get; set; }
        public string Paciente { get; set; }
        public string Celular { get; set; }
        public int Visitas { get; set; }                // días distintos con procedimiento finalizado
        public int Procedimientos { get; set; }
        public decimal? Total { get; set; }             // solo administradores
        public string UltimaVisita { get; set; }
        public string PrimeraVisita { get; set; }
        public string Especialista { get; set; }        // el que más lo atendió
    }

    public class TopPacientesDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public bool VerDinero { get; set; }
        public string Alcance { get; set; }
        public string Desde { get; set; }
        public string Hasta { get; set; }
        public List<PacienteRecurrenteDto> Pacientes { get; set; }
    }

    public class EspecialistaDesempenoDto
    {
        public long Id { get; set; }
        public string Especialista { get; set; }
        public bool Activo { get; set; }
        public int Citas { get; set; }
        public int Atendidas { get; set; }
        public int Canceladas { get; set; }
        public int Procedimientos { get; set; }
        public int Pacientes { get; set; }
        public decimal? Facturado { get; set; }       // procedimientos finalizados (valor de los tratamientos)
        public decimal? FacturadoCaja { get; set; }   // cobrado en caja sin IVA
        public decimal? MinutosPromedio { get; set; }
    }

    public class ConteoDto
    {
        public string Nombre { get; set; }
        public string Color { get; set; }
        public int Cantidad { get; set; }
        public decimal? Total { get; set; }
    }

    public class AgendaHoyDto
    {
        public string Hora { get; set; }
        public string Paciente { get; set; }
        public string Especialista { get; set; }
        public string Estado { get; set; }
        public string Color { get; set; }
        public string EstadoProcedimiento { get; set; }
    }

    public class DashboardDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public bool VerDinero { get; set; }
        public string Desde { get; set; }
        public string Hasta { get; set; }
        public IndicadoresDto Indicadores { get; set; }
        public ComparativoDto Anterior { get; set; }
        public List<CitasDiaDto> CitasPorDia { get; set; }
        public List<EspecialistaDesempenoDto> Especialistas { get; set; }
        public List<ConteoDto> Tratamientos { get; set; }
        public List<ConteoDto> EstadosCita { get; set; }
        public List<AgendaHoyDto> Hoy { get; set; }
        public List<ConteoDto> NuevosPorMes { get; set; }
        public List<ConteoDto> Fuentes { get; set; }
        public List<PacientesCitaDiaDto> PacientesCitaDia { get; set; }
        public PacientesCitaDiaDto PacientesCitaPeriodo { get; set; }   // pacientes distintos del rango
        public List<IngresoFormaPagoDto> IngresosFormaPago { get; set; } // solo administradores
        public List<GarantiaEspecialistaDto> Garantias { get; set; }     // garantías de servicios del rango por especialista
        public DPieCenter.Registros.MetasMesDto Metas { get; set; }      // avance contra la meta del mes de "Hasta" (solo administradores)
        public DPieCenter.Registros.MetasHistoricoDto MetasHistorico { get; set; }   // ventas contra meta, últimos 6 meses (solo administradores)
    }

    public class GarantiaEspecialistaDto
    {
        public string Especialista { get; set; }
        public int Garantias { get; set; }
        public int Pacientes { get; set; }
        public int Procedimientos { get; set; }         // finalizados del especialista en el rango
        public string Ultima { get; set; }              // yyyy-MM-dd
    }

    // Pacientes con cita en el día: expediente creado en meses anteriores vs en el mes de la cita
    public class PacientesCitaDiaDto
    {
        public string Dia { get; set; }                 // yyyy-MM-dd (vacío en el total del periodo)
        public int Anteriores { get; set; }
        public int Nuevos { get; set; }
    }

    public class IngresoFormaPagoDto
    {
        public string Dia { get; set; }                 // yyyy-MM-dd
        public string Codigo { get; set; }
        public string FormaPago { get; set; }
        public decimal Total { get; set; }
    }

    // ===== Reporte de caja (Reportes/frm_repCaja.aspx) =====

    public class CobroDto
    {
        public long IdDte { get; set; }
        public long IdFactura { get; set; }
        public string Fecha { get; set; }               // dd/MM/yyyy
        public string Hora { get; set; }
        public string TipoDte { get; set; }             // Factura | Crédito fiscal
        public string NumeroControl { get; set; }
        public string Cliente { get; set; }
        public string Paciente { get; set; }
        public string FormaPago { get; set; }
        public string Referencia { get; set; }
        public decimal Gravado { get; set; }
        public decimal Iva { get; set; }
        public decimal Total { get; set; }
        public bool Anulado { get; set; }
        public string Cajero { get; set; }
        public string CajeroNombre { get; set; }
        public decimal Descuento { get; set; }          // total de descuentos del documento (como en el DTE)
        public decimal DescuentoTratamiento { get; set; }   // por el % del tratamiento
        public decimal DescuentoCupon { get; set; }         // por cupón
        public string Cupon { get; set; }
        public bool Ticket { get; set; }                 // ticket POS de servicio sin costo (no es DTE)
        public string FechaAnulacion { get; set; }      // dd/MM/yyyy hh:mm AM/PM
        public string MotivoAnulacion { get; set; }
        public string UsuarioAnula { get; set; }
    }

    /// <summary>Apertura y cierre de una caja diaria con su arqueo.</summary>
    public class CajaDiaDto
    {
        public long Id { get; set; }
        public string Fecha { get; set; }               // dd/MM/yyyy
        public string Cajero { get; set; }
        public string CajeroNombre { get; set; }
        public decimal Fondo { get; set; }
        public string Apertura { get; set; }            // hh:mm AM/PM
        public string Cierre { get; set; }              // dd/MM hh:mm AM/PM; vacío si sigue abierta
        public bool Abierta { get; set; }
        public decimal Cobrado { get; set; }
        public decimal Efectivo { get; set; }
        public int Documentos { get; set; }
        public int Tickets { get; set; }
        public decimal Salidas { get; set; }
        public int CantidadSalidas { get; set; }
        public decimal Entradas { get; set; }
        public int CantidadEntradas { get; set; }
        public decimal EfectivoEsperado { get; set; }
        public decimal? EfectivoContado { get; set; }
        public decimal Sobrante { get; set; }
        public decimal Faltante { get; set; }
        public string Observaciones { get; set; }
        public decimal DescuentoTratamientos { get; set; }  // descuentos de la caja (IVA incluido, como en su cierre)
        public decimal DescuentoCupones { get; set; }
    }

    /// <summary>Movimiento de efectivo (manejo de efectivo): entrada o salida.</summary>
    public class SalidaReporteDto
    {
        public long Id { get; set; }
        public bool Entrada { get; set; }
        public string Fecha { get; set; }               // dd/MM/yyyy hh:mm AM/PM
        public string CajeroNombre { get; set; }
        public decimal Monto { get; set; }
        public string Categoria { get; set; }
        public string Motivo { get; set; }
        public string Referencia { get; set; }
        public bool Anulada { get; set; }
        public string MotivoAnulacion { get; set; }
    }

    public class TotalGrupoDto
    {
        public string Nombre { get; set; }
        public int Documentos { get; set; }
        public decimal Total { get; set; }
    }

    public class CajaReporteDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public string Desde { get; set; }
        public string Hasta { get; set; }
        public string Cajero { get; set; }
        public decimal Total { get; set; }              // sin anulados
        public decimal Gravado { get; set; }
        public decimal Iva { get; set; }
        public int Documentos { get; set; }
        public decimal TicketPromedio { get; set; }
        public int Anulados { get; set; }
        public decimal TotalAnulado { get; set; }
        public int PendientesFacturas { get; set; }
        public decimal PendientesTotal { get; set; }
        public List<TotalGrupoDto> PorFormaPago { get; set; }
        public List<TotalGrupoDto> PorCajero { get; set; }
        public List<TotalGrupoDto> PorDia { get; set; }
        public List<TotalGrupoDto> PorTipo { get; set; }
        public List<CobroDto> Cobros { get; set; }
        // Caja diaria
        public List<CajaDiaDto> Cajas { get; set; }
        public List<SalidaReporteDto> SalidasDetalle { get; set; }
        public decimal Salidas { get; set; }            // salidas activas
        public decimal Entradas { get; set; }           // entradas activas
        public decimal Sobrantes { get; set; }
        public decimal Faltantes { get; set; }
        public int CajasAbiertas { get; set; }
        public decimal Descuentos { get; set; }         // tratamientos + cupones (sin anulados)
        public decimal DescuentosTratamientos { get; set; }
        public decimal DescuentosCupones { get; set; }
        public int ConDescuentoTratamiento { get; set; }  // documentos con descuento por tratamiento
        public int Cupones { get; set; }
        public int Tickets { get; set; }                 // tickets POS sin costo
        public List<TotalGrupoDto> PorCategoriaSalida { get; set; }
    }

    public class CajeroDto
    {
        public string Usuario { get; set; }
        public string Nombre { get; set; }
    }

    // ===== Reportes de citas, procedimientos y expedientes =====

    public class FiltroReporteDto
    {
        public string Desde { get; set; }            // yyyy-MM-dd
        public string Hasta { get; set; }
        public long Especialista { get; set; }
        public long Estado { get; set; }
        public long TipoCita { get; set; }
        public long Tratamiento { get; set; }
        public long Sexo { get; set; }
        public long Departamento { get; set; }
        public string Fuente { get; set; }
        public string Paciente { get; set; }
        public int Sucursal { get; set; }            // 0 = todas (solo administradores; los demás ven su sucursal)
        public long FormaPago { get; set; }          // código CAT-017 como número (1 = '01'); 0 = todas
    }

    // ===== Reporte de caja por especialista (Reportes/frm_repCajaEspecialistas.aspx) =====
    public class CobroEspecialistaDto
    {
        public long Id { get; set; }
        /// <summary>true: DTE cobrado en el periodo (suma al cobrado). false: pago adelantado aplicado (solo suma a la venta sin IVA).</summary>
        public bool Cobro { get; set; }
        public string Fecha { get; set; }               // dd/MM/yyyy hh:mm AM/PM
        public string Tipo { get; set; }                // Factura | Crédito fiscal | Pago adelantado aplicado
        public string Documento { get; set; }           // número de control
        public long IdExpediente { get; set; }
        public string Paciente { get; set; }
        public string DocumentoPaciente { get; set; }
        public string FormaPago { get; set; }
        public decimal Gravado { get; set; }
        public decimal Iva { get; set; }
        public decimal Total { get; set; }              // cobrado con IVA
        public decimal SinIva { get; set; }
        public string Origen { get; set; }              // Procedimiento | Pago adelantado de cita | Pago adelantado sin cita | Pago adelantado aplicado
        public string Especialista { get; set; }
        public long IdEspecialista { get; set; }
        public long IdProcedimiento { get; set; }
        public string FechaAtencion { get; set; }
        public string Tratamientos { get; set; }
        public string Cajero { get; set; }
        public string Sucursal { get; set; }
    }

    public class CajaEspecialistaDto
    {
        public string Especialista { get; set; }
        public int Documentos { get; set; }
        public int Pacientes { get; set; }
        public decimal Cobrado { get; set; }            // con IVA
        public decimal Iva { get; set; }
        public decimal SinIva { get; set; }             // cobrado sin IVA + pagos adelantados aplicados (como las metas)
        public decimal Adelantos { get; set; }          // pagos adelantados aplicados (sin IVA)
        public decimal Porcentaje { get; set; }         // del cobrado total
        /// <summary>Cobrado con IVA por forma de pago (Nombre = forma de pago).</summary>
        public List<TotalGrupoDto> PorFormaPago { get; set; }
        public long IdEspecialista { get; set; }
        /// <summary>Meta de ventas sin IVA del mes de la fecha final (null: sin meta).</summary>
        public decimal? Meta { get; set; }
        /// <summary>Comisión escalonada + bono de escala + bono por alcance, con las ventas sin IVA del periodo y la meta de cada mes.</summary>
        public decimal Comision { get; set; }
        /// <summary>% de la escala alcanzada (mes de la fecha final).</summary>
        public decimal PorcentajeEscala { get; set; }
        public decimal BonoAlcance { get; set; }
        /// <summary>La meta del mes de la fecha final no tiene escalas de comisión.</summary>
        public bool SinEscalas { get; set; }
        /// <summary>"749.00 × 12 % = 89.88 + ..." (cálculo de la comisión).</summary>
        public string DetalleComision { get; set; }
    }

    public class ReporteCajaEspecialistasDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public string Desde { get; set; }
        public string Hasta { get; set; }
        public decimal Cobrado { get; set; }
        public decimal Iva { get; set; }
        public decimal SinIva { get; set; }
        public decimal Adelantos { get; set; }
        public int Documentos { get; set; }
        public int Pacientes { get; set; }
        public decimal TicketPromedio { get; set; }
        /// <summary>Meta activa del mes de la fecha final: suma de las metas de los especialistas del reporte.</summary>
        public decimal MetaMes { get; set; }
        /// <summary>"Noviembre 2026"</summary>
        public string MetaPeriodo { get; set; }
        /// <summary>Ventas sin IVA de ese mes (dentro del periodo) / MetaMes × 100.</summary>
        public decimal MetaAvance { get; set; }
        public int MetaEspecialistas { get; set; }
        public decimal Comision { get; set; }
        /// <summary>Formas de pago con cobros, en orden (columnas de la tabla por especialista).</summary>
        public List<string> FormasPago { get; set; }
        public List<CajaEspecialistaDto> PorEspecialista { get; set; }
        public List<TotalGrupoDto> PorFormaPago { get; set; }
        public List<TotalGrupoDto> PorDia { get; set; }
        public List<CobroEspecialistaDto> Items { get; set; }
    }

    // ===== Reporte de Garantía de Servicios (Reportes/frm_repGarantias.aspx) =====
    public class GarantiaReporteDto
    {
        public long Id { get; set; }
        public string Fecha { get; set; }               // dd/MM/yyyy hh:mm
        public string FechaIso { get; set; }            // yyyy-MM-dd (agrupar por día)
        public string Usuario { get; set; }
        public string Modificada { get; set; }
        public string Garantia { get; set; }
        public long IdEspecialista { get; set; }
        public string Especialista { get; set; }
        public long IdExpediente { get; set; }
        public string Paciente { get; set; }
        public string Documento { get; set; }
        public string Celular { get; set; }
        public long IdProcedimiento { get; set; }
        public string FechaProcedimiento { get; set; }
        /// <summary>Días entre el procedimiento y el registro de la garantía.</summary>
        public int? DiasDesdeProcedimiento { get; set; }
        public string Tratamientos { get; set; }
        public bool Visto { get; set; }
        public string VistoDetalle { get; set; }        // "cfunes · 18/11/2026 05:10 PM"
        public string Sucursal { get; set; }
    }

    public class GarantiaEspecialistaReporteDto
    {
        public string Especialista { get; set; }
        public int Garantias { get; set; }
        public int Procedimientos { get; set; }
        /// <summary>Garantías / procedimientos finalizados del periodo × 100.</summary>
        public decimal Porcentaje { get; set; }
        public int NoVistas { get; set; }
    }

    public class ReporteGarantiasDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public string Desde { get; set; }
        public string Hasta { get; set; }
        public int Garantias { get; set; }
        public int Pacientes { get; set; }
        public int NoVistas { get; set; }
        public int Procedimientos { get; set; }
        public decimal Porcentaje { get; set; }
        /// <summary>Promedio de días entre el procedimiento y la garantía.</summary>
        public decimal? DiasPromedio { get; set; }
        public List<GarantiaEspecialistaReporteDto> PorEspecialista { get; set; }
        public List<TotalGrupoDto> PorTratamiento { get; set; }
        public List<TotalGrupoDto> PorSemana { get; set; }
        public List<GarantiaReporteDto> Items { get; set; }
    }

    public class CatalogosReporteDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public List<Opciones.CatalogoItemDto> Sucursales { get; set; }    // solo para administradores (pueden ver todas)
        public int SucursalActual { get; set; }
        public List<Registros.OpcionDto> Especialistas { get; set; }
        public List<Registros.OpcionDto> Estados { get; set; }
        public List<Registros.OpcionDto> TiposCita { get; set; }
        public List<Registros.OpcionDto> Tratamientos { get; set; }
        public List<Registros.OpcionDto> Sexos { get; set; }
        public List<Registros.OpcionDto> Departamentos { get; set; }
        public List<Registros.OpcionDto> FormasPago { get; set; }      // solo el reporte de caja por especialista
    }

    public class CitaReporteDto
    {
        public long Id { get; set; }
        public string Fecha { get; set; }
        public string Hora { get; set; }
        public long IdExpediente { get; set; }
        public string Paciente { get; set; }
        public string Documento { get; set; }
        public string Celular { get; set; }
        public string TipoCita { get; set; }
        public string Especialista { get; set; }
        public string Estado { get; set; }
        public string Color { get; set; }
        public string Tratamientos { get; set; }
        public decimal Valor { get; set; }
        public string Comentarios { get; set; }
        public string CreadoPor { get; set; }
        public string Creado { get; set; }
    }

    public class ReporteCitasDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public string Desde { get; set; }
        public string Hasta { get; set; }
        public int Total { get; set; }
        public int Atendidas { get; set; }
        public int Canceladas { get; set; }
        public int Pendientes { get; set; }
        public decimal Asistencia { get; set; }       // % atendidas sobre atendidas + canceladas
        public decimal ValorAtendidas { get; set; }
        public decimal ValorTotal { get; set; }
        public List<TotalGrupoDto> PorEstado { get; set; }
        public List<TotalGrupoDto> PorEspecialista { get; set; }
        public List<TotalGrupoDto> PorTipo { get; set; }
        public List<TotalGrupoDto> PorDiaSemana { get; set; }
        public List<CitaReporteDto> Items { get; set; }
    }

    public class ProcedimientoReporteDto
    {
        public long Id { get; set; }
        public string Fecha { get; set; }
        public string Horario { get; set; }
        public int? Minutos { get; set; }
        public long IdExpediente { get; set; }
        public string Paciente { get; set; }
        public string Documento { get; set; }
        public string Especialista { get; set; }
        public string TipoCita { get; set; }
        public string Tratamientos { get; set; }
        public int Cantidad { get; set; }
        public decimal Total { get; set; }
        public string Diagnostico { get; set; }
        public string Factura { get; set; }           // Cobrada | Pendiente | Sin factura
        public long IdFactura { get; set; }
        public string Usuario { get; set; }
    }

    public class ReporteProcedimientosDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public string Desde { get; set; }
        public string Hasta { get; set; }
        public int Procedimientos { get; set; }
        public int Pacientes { get; set; }
        public int Tratamientos { get; set; }
        public decimal Total { get; set; }
        public decimal TicketPromedio { get; set; }
        public decimal? MinutosPromedio { get; set; }
        public decimal Cobrado { get; set; }
        public decimal Pendiente { get; set; }
        public List<TotalGrupoDto> PorEspecialista { get; set; }
        public List<TotalGrupoDto> PorTratamiento { get; set; }
        public List<TotalGrupoDto> PorDia { get; set; }
        public List<ProcedimientoReporteDto> Items { get; set; }
    }

    public class ExpedienteReporteDto
    {
        public long Id { get; set; }
        public string Registro { get; set; }
        public string Documento { get; set; }
        public string Paciente { get; set; }
        public string Edad { get; set; }
        public string Sexo { get; set; }
        public string Celular { get; set; }
        public string Email { get; set; }
        public string Ubicacion { get; set; }
        public string Fuentes { get; set; }
        public int Visitas { get; set; }
        public string UltimaVisita { get; set; }
        public string RegistradoPor { get; set; }
    }

    public class ReporteExpedientesDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public string Desde { get; set; }
        public string Hasta { get; set; }
        public int Total { get; set; }
        public int ConVisitas { get; set; }
        public int Recurrentes { get; set; }          // 2 o más visitas
        public decimal? EdadPromedio { get; set; }
        public int SinEmail { get; set; }
        public List<TotalGrupoDto> PorSexo { get; set; }
        public List<TotalGrupoDto> PorEdad { get; set; }
        public List<TotalGrupoDto> PorFuente { get; set; }
        public List<TotalGrupoDto> PorDepartamento { get; set; }
        public List<TotalGrupoDto> PorUsuario { get; set; }
        public List<ExpedienteReporteDto> Items { get; set; }
    }

    // ===== Pacientes por procedimientos y citas (Reportes/frm_repPacientesActividad.aspx) =====
    public class PacienteActividadDto
    {
        public int Posicion { get; set; }                // 1 = el de más procedimientos
        public long Id { get; set; }
        public string Paciente { get; set; }
        public string Documento { get; set; }
        public string Celular { get; set; }
        public string Edad { get; set; }
        public int Procedimientos { get; set; }          // finalizados en el rango
        public int Visitas { get; set; }                 // días distintos con procedimiento
        public decimal Valor { get; set; }               // tratamientos de los procedimientos (con descuento del tratamiento)
        public string UltimoProcedimiento { get; set; }
        public int Citas { get; set; }                   // sin anuladas
        public int Atendidas { get; set; }
        public int Canceladas { get; set; }
        public string UltimaCita { get; set; }
    }

    public class ReportePacientesActividadDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public string Desde { get; set; }
        public string Hasta { get; set; }
        public int Pacientes { get; set; }
        public int Procedimientos { get; set; }
        public int Citas { get; set; }
        public int Canceladas { get; set; }
        public decimal Valor { get; set; }
        public int Recurrentes { get; set; }             // 2 o más procedimientos
        public int SoloCitas { get; set; }               // con citas pero sin procedimientos
        public List<TotalGrupoDto> PorProcedimientos { get; set; }   // cuántos pacientes tuvieron 1, 2, 3+ procedimientos
        public List<PacienteActividadDto> Items { get; set; }
    }
}
