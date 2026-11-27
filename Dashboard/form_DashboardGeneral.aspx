<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="form_DashboardGeneral.aspx.cs" Inherits="DPieCenter.Dashboard.form_DashboardGeneral" %>

<link href="assets/css/dashboard.css?v=9" rel="stylesheet" />
<script src="assets/plugins/apexcharts-bundle/js/apexcharts.min.js"></script>

<div class="db" id="dashboard">
	<!-- Encabezado y periodo -->
	<div class="d-flex flex-wrap align-items-center gap-2 mb-3">
		<div class="me-auto">
			<h4 class="mb-0">Dashboard de indicadores</h4>
			<div class="text-muted small" id="dbRango"></div>
		</div>
		<div class="btn-group btn-group-sm flex-wrap" role="group" aria-label="Periodo" id="dbPeriodos">
			<button type="button" class="btn btn-outline-primary" data-periodo="hoy">Hoy</button>
			<button type="button" class="btn btn-outline-primary" data-periodo="7">7 días</button>
			<button type="button" class="btn btn-outline-primary active" data-periodo="mes">Este mes</button>
			<button type="button" class="btn btn-outline-primary" data-periodo="anterior">Mes anterior</button>
			<button type="button" class="btn btn-outline-primary" data-periodo="90">90 días</button>
			<button type="button" class="btn btn-outline-primary" data-periodo="comparativo" title="Mes actual contra el mes anterior o el mismo mes del año anterior"><i class="bx bx-git-compare"></i> Comparativo</button>
		</div>
		<div class="d-flex align-items-center gap-1">
			<label for="dbDesde" class="visually-hidden">Desde</label>
			<input type="date" class="form-control form-control-sm" id="dbDesde" />
			<span class="text-muted small">a</span>
			<label for="dbHasta" class="visually-hidden">Hasta</label>
			<input type="date" class="form-control form-control-sm" id="dbHasta" />
			<button type="button" class="btn btn-sm btn-primary" id="dbAplicar" title="Aplicar rango"><i class="bx bx-search"></i></button>
			<button type="button" class="btn btn-sm btn-outline-secondary" id="dbRefrescar" title="Actualizar"><i class="bx bx-refresh"></i></button>
		</div>
	</div>

	<!-- Comparativo: mes actual contra el mes anterior o contra el mismo mes del año anterior -->
	<div id="dbComparativo" class="d-none">
		<div class="card radius-10 mb-3"><div class="card-body">
			<div class="d-flex flex-wrap align-items-center gap-2 mb-3">
				<div class="btn-group btn-group-sm" role="group" aria-label="Comparar contra" id="dbCmpTipo">
					<button type="button" class="btn btn-outline-secondary active" data-cmp="mes">Mes actual vs mes anterior</button>
					<button type="button" class="btn btn-outline-secondary" data-cmp="anio">Mes actual vs mismo mes del año anterior</button>
				</div>
				<div class="form-check form-switch ms-md-2 mb-0" title="Compara el mes actual hasta hoy contra los mismos días del otro mes">
					<input class="form-check-input" type="checkbox" id="dbCmpMismosDias" checked>
					<label class="form-check-label small" for="dbCmpMismosDias">Mismos días (al día de hoy)</label>
				</div>
				<span class="ms-auto small text-muted" id="dbCmpRango"></span>
			</div>
			<div class="table-responsive">
				<table class="table table-sm align-middle mb-0 db-tabla db-cmp-tabla">
					<thead class="table-light">
						<tr>
							<th>Indicador</th>
							<th class="text-end" id="dbCmpCol1">Mes actual</th>
							<th class="text-end" id="dbCmpCol2">Comparado</th>
							<th class="text-end">Diferencia</th>
							<th class="text-end">Variación</th>
						</tr>
					</thead>
					<tbody id="dbCmpFilas"></tbody>
				</table>
			</div>
		</div></div>
		<div class="row g-3 mb-3">
			<div class="col-xl-6 db-dinero">
				<div class="card radius-10 h-100 mb-0"><div class="card-body">
					<h6 class="db-titulo">Ingresos acumulados por día del mes</h6>
					<div id="dbCmpIngresos" class="db-grafico"></div>
				</div></div>
			</div>
			<div class="col-xl-6">
				<div class="card radius-10 h-100 mb-0"><div class="card-body">
					<h6 class="db-titulo">Procedimientos acumulados por día del mes</h6>
					<div id="dbCmpProc" class="db-grafico"></div>
				</div></div>
			</div>
			<div class="col-12">
				<div class="card radius-10 mb-0"><div class="card-body">
					<h6 class="db-titulo">Citas y expedientes nuevos por día del mes</h6>
					<div id="dbCmpCitas" class="db-grafico"></div>
				</div></div>
			</div>
		</div>
	</div>

	<div id="dbNormal">
	<!-- KPI principales: valor, variación contra el periodo anterior y tendencia diaria -->
	<div class="row row-cols-1 row-cols-sm-2 row-cols-xl-4 g-3 mb-3">
		<div class="col"><div class="card radius-10 mb-0 db-kpi db-kpi-grande"><div class="card-body">
			<div class="d-flex align-items-start">
				<span class="db-kpi-icono db-c-lila"><i class="bx bx-user-plus"></i></span>
				<div class="ms-auto text-end"><span>Expedientes nuevos</span><strong id="kNuevos">—</strong></div>
			</div>
			<div class="d-flex align-items-center justify-content-between mt-1"><small id="kNuevosSub"></small><span class="db-delta" id="kNuevosDelta"></span></div>
			<div id="sparkNuevos" class="db-spark"></div>
		</div></div></div>
		<div class="col"><div class="card radius-10 mb-0 db-kpi db-kpi-grande"><div class="card-body">
			<div class="d-flex align-items-start">
				<span class="db-kpi-icono db-c-acento"><i class="bx bx-calendar"></i></span>
				<div class="ms-auto text-end"><span>Citas</span><strong id="kCitas">—</strong></div>
			</div>
			<div class="d-flex align-items-center justify-content-between mt-1"><small id="kCitasSub"></small><span class="db-delta" id="kCitasDelta"></span></div>
			<div id="sparkCitas" class="db-spark"></div>
		</div></div></div>
		<div class="col"><div class="card radius-10 mb-0 db-kpi db-kpi-grande"><div class="card-body">
			<div class="d-flex align-items-start">
				<span class="db-kpi-icono db-c-exito"><i class="bx bx-plus-medical"></i></span>
				<div class="ms-auto text-end"><span>Procedimientos</span><strong id="kProc">—</strong></div>
			</div>
			<div class="d-flex align-items-center justify-content-between mt-1"><small id="kProcSub"></small><span class="db-delta" id="kProcDelta"></span></div>
			<div id="sparkProc" class="db-spark"></div>
		</div></div></div>
		<div class="col"><div class="card radius-10 mb-0 db-kpi db-kpi-grande"><div class="card-body">
			<div class="d-flex align-items-start">
				<span class="db-kpi-icono db-c-ambar"><i class="bx bx-check-shield"></i></span>
				<div class="ms-auto text-end"><span>Asistencia</span><strong id="kAsistencia">—</strong></div>
			</div>
			<div class="d-flex align-items-center justify-content-between mt-1"><small id="kAsistenciaSub"></small><span class="db-delta" id="kAsistenciaDelta"></span></div>
			<div class="progress db-asistencia mt-2" title="Atendidas sobre atendidas + canceladas"><div class="progress-bar" id="kAsistenciaBarra"></div></div>
		</div></div></div>
	</div>

	<!-- KPI secundarios -->
	<div class="row row-cols-2 row-cols-lg-4 g-3 mb-3">
		<div class="col"><div class="card radius-10 mb-0 db-kpi"><div class="card-body">
			<span><i class="bx bx-folder-open"></i> Pacientes registrados</span><strong id="kPacientes">—</strong><small id="kPacientesSub"></small>
		</div></div></div>
		<div class="col db-dinero"><div class="card radius-10 mb-0 db-kpi"><div class="card-body">
			<span><i class="bx bx-dollar-circle"></i> Facturado</span><strong id="kFacturado">—</strong><small id="kFacturadoSub"></small>
		</div></div></div>
		<div class="col db-dinero"><div class="card radius-10 mb-0 db-kpi"><div class="card-body">
			<span><i class="bx bx-wallet"></i> Cobrado en caja</span><strong id="kCobrado">—</strong><small id="kCobradoSub"></small>
		</div></div></div>
		<div class="col"><div class="card radius-10 mb-0 db-kpi db-kpi-ahora"><div class="card-body">
			<span><i class="bx bx-pulse"></i> Ahora</span><strong id="kAhora">—</strong><small id="kAhoraSub"></small>
		</div></div></div>
	</div>

	<div class="row g-3">
		<!-- Ingresos diarios (solo administradores) -->
		<div class="col-12 db-dinero">
			<div class="card radius-10 mb-0"><div class="card-body">
				<div class="d-flex flex-wrap align-items-center gap-2 mb-1">
					<h6 class="db-titulo mb-0">Ingresos diarios</h6>
					<span class="text-muted small">cobrado en caja (documentos vigentes)</span>
					<span class="ms-auto small" id="dbIngresosResumen"></span>
				</div>
				<div id="dbGraficoIngresos" class="db-grafico"></div>
			</div></div>
		</div>

		<!-- Metas de ventas por especialista: mes de la fecha final (solo administradores) -->
		<div class="col-12 db-dinero">
			<div class="card radius-10 mb-0"><div class="card-body">
				<div class="d-flex flex-wrap align-items-center gap-2 mb-1">
					<h6 class="db-titulo mb-0"><i class="bx bx-target-lock"></i> Metas de ventas por especialista</h6>
					<span class="text-muted small" id="dbMetasPeriodo"></span>
					<span class="ms-auto small" id="dbMetasResumen"></span>
				</div>
				<div id="dbGraficoMetas" class="db-grafico"></div>
				<div id="dbMetasDetalle" class="d-flex flex-wrap gap-3 small mt-1"></div>
			</div></div>
		</div>

		<!-- Metas por mes: ventas sin IVA contra la meta de cada especialista, últimos 6 meses (solo administradores) -->
		<div class="col-12 db-dinero">
			<div class="card radius-10 mb-0"><div class="card-body">
				<div class="d-flex flex-wrap align-items-center gap-2 mb-1">
					<h6 class="db-titulo mb-0"><i class="bx bx-line-chart"></i> Metas por mes</h6>
					<span class="text-muted small">ventas sin IVA contra la meta de cada especialista · últimos 6 meses hasta la fecha final</span>
					<select class="form-select form-select-sm ms-auto" id="dbHistEspecialista" style="max-width:220px" aria-label="Especialista"></select>
				</div>
				<div id="dbGraficoMetasHist" class="db-grafico"></div>
				<div id="dbMetasHistNota" class="small text-muted mt-1"></div>
			</div></div>
		</div>

		<!-- Expedientes nuevos -->
		<div class="col-xl-8">
			<div class="card radius-10 h-100 mb-0"><div class="card-body">
				<h6 class="db-titulo">Pacientes nuevos por día</h6>
				<div id="dbGraficoNuevosDia" class="db-grafico"></div>
			</div></div>
		</div>
		<div class="col-xl-4">
			<div class="card radius-10 h-100 mb-0"><div class="card-body">
				<h6 class="db-titulo">Expedientes nuevos por mes</h6>
				<div id="dbGraficoNuevos" class="db-grafico-bajo"></div>
				<h6 class="db-titulo mt-3">¿Cómo nos conocieron? <span class="text-muted fw-normal">(nuevos del periodo)</span></h6>
				<div id="dbFuentes" class="d-flex flex-wrap gap-2"></div>
			</div></div>
		</div>

		<!-- Pacientes con cita: expedientes de meses anteriores vs nuevos del mes -->
		<div class="col-12">
			<div class="card radius-10 mb-0"><div class="card-body">
				<div class="d-flex flex-wrap align-items-center gap-2 mb-1">
					<h6 class="db-titulo mb-0">Pacientes con cita por día</h6>
					<span class="text-muted small">antiguos: expediente de meses anteriores · nuevos: expediente creado en el mes de la cita (sin canceladas ni anuladas)</span>
					<span class="ms-auto small" id="dbPacCitaResumen"></span>
				</div>
				<div id="dbGraficoPacCita" class="db-grafico"></div>
			</div></div>
		</div>

		<!-- Citas -->
		<div class="col-xl-8">
			<div class="card radius-10 h-100 mb-0"><div class="card-body">
				<h6 class="db-titulo">Citas por día</h6>
				<div id="dbGraficoCitas" class="db-grafico"></div>
			</div></div>
		</div>
		<div class="col-xl-4">
			<div class="card radius-10 h-100 mb-0"><div class="card-body">
				<h6 class="db-titulo">Citas por estado</h6>
				<div id="dbGraficoEstados" class="db-grafico"></div>
			</div></div>
		</div>

		<!-- Procedimientos -->
		<div class="col-xl-8">
			<div class="card radius-10 h-100 mb-0"><div class="card-body">
				<h6 class="db-titulo">Procedimientos finalizados por día</h6>
				<div id="dbGraficoProc" class="db-grafico"></div>
			</div></div>
		</div>
		<div class="col-xl-4">
			<div class="card radius-10 h-100 mb-0"><div class="card-body">
				<h6 class="db-titulo">Tratamientos más realizados</h6>
				<div id="dbTratamientos"></div>
			</div></div>
		</div>

		<!-- Top 10 pacientes recurrentes -->
		<div class="col-12">
			<div class="card radius-10 mb-0"><div class="card-body">
				<div class="d-flex flex-wrap align-items-center gap-2 mb-2">
					<h6 class="db-titulo mb-0">Top 10 pacientes recurrentes</h6>
					<span class="text-muted small" id="dbTopRango"></span>
					<div class="btn-group btn-group-sm ms-auto" role="group" aria-label="Alcance del top" id="dbTopAlcance">
						<button type="button" class="btn btn-outline-secondary" data-alcance="periodo">Periodo</button>
						<button type="button" class="btn btn-outline-secondary active" data-alcance="12m">12 meses</button>
						<button type="button" class="btn btn-outline-secondary" data-alcance="todo">Todo</button>
					</div>
				</div>
				<div class="row g-3">
					<div class="col-xl-5"><div id="dbGraficoTop" class="db-grafico-top"></div></div>
					<div class="col-xl-7">
						<div class="table-responsive">
							<table class="table table-sm table-hover align-middle mb-0 db-tabla">
								<thead class="table-light">
									<tr>
										<th>#</th>
										<th>Paciente</th>
										<th class="text-end">Visitas</th>
										<th class="text-end d-none d-md-table-cell">Proced.</th>
										<th class="d-none d-lg-table-cell">Última visita</th>
										<th class="d-none d-lg-table-cell">Especialista</th>
										<th class="text-end db-dinero">Total</th>
									</tr>
								</thead>
								<tbody id="dbTop"></tbody>
							</table>
						</div>
					</div>
				</div>
			</div></div>
		</div>

		<!-- Especialistas y agenda -->
		<div class="col-xl-8">
			<div class="card radius-10 h-100 mb-0"><div class="card-body">
				<h6 class="db-titulo">Especialistas</h6>
				<div class="table-responsive">
					<table class="table table-sm align-middle mb-0 db-tabla db-tabla-esp">
						<thead class="table-light">
							<tr>
								<th>Especialista</th>
								<th class="text-end">Citas</th>
								<th class="text-end">Atendidas</th>
								<th class="text-end d-none d-md-table-cell">Canceladas</th>
								<th class="text-end">Proced.</th>
								<th class="text-end d-none d-md-table-cell">Pacientes</th>
								<th class="text-end d-none d-lg-table-cell">Min. prom.</th>
								<th class="text-end db-dinero" title="Valor de los tratamientos de los procedimientos finalizados">Valor<br />procedimientos</th>
								<th class="text-end db-dinero" title="Cobrado en caja con IVA">Facturado<br />Caja</th>
							</tr>
						</thead>
						<tbody id="dbEspecialistas"></tbody>
						<tfoot id="dbEspecialistasTotal" class="table-light fw-semibold"></tfoot>
					</table>
				</div>
			</div></div>
		</div>
		<div class="col-xl-4">
			<div class="card radius-10 h-100 mb-0"><div class="card-body">
				<div class="d-flex align-items-center mb-2">
					<h6 class="db-titulo mb-0">Agenda de hoy</h6>
					<a href="javascript:;" class="ms-auto small" onclick="AjaxLink('Registros/frm_CitasCalendario.aspx')">Ver agenda</a>
				</div>
				<div id="dbHoy" class="db-hoy"></div>
			</div></div>
		</div>

		<!-- Garantías de servicios por especialista (registradas en el periodo) -->
		<div class="col-12">
			<div class="card radius-10 mb-0"><div class="card-body">
				<div class="d-flex flex-wrap align-items-center gap-2 mb-2">
					<h6 class="db-titulo mb-0"><i class="bx bx-shield-quarter"></i> Garantías de servicios por especialista</h6>
					<span class="text-muted small">registradas en el periodo · % sobre sus procedimientos finalizados del periodo</span>
					<span class="ms-auto small" id="dbGarantiasResumen"></span>
				</div>
				<div class="table-responsive">
					<table class="table table-sm align-middle mb-0 db-tabla">
						<thead class="table-light">
							<tr>
								<th>Especialista</th>
								<th class="text-end">Garantías</th>
								<th class="text-end d-none d-md-table-cell">Pacientes</th>
								<th class="text-end">% de proced.</th>
								<th class="d-none d-md-table-cell">Última</th>
							</tr>
						</thead>
						<tbody id="dbGarantias"></tbody>
					</table>
				</div>
			</div></div>
		</div>
	</div>
	</div><!-- /dbNormal -->
</div>

<script src="assets/js/dashboard.js?v=22"></script>
