<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="frm_DashboardUsuarios.aspx.cs" Inherits="DPieCenter.Dashboard.frm_DashboardUsuarios" %>

<link href="assets/css/dashboard.css?v=9" rel="stylesheet" />
<script src="assets/plugins/apexcharts-bundle/js/apexcharts.min.js"></script>

<div class="db du" id="dashboardUsuario">
	<!-- Saludo y accesos rápidos -->
	<div class="card radius-10 du-saludo">
		<div class="card-body d-flex flex-wrap align-items-center gap-3">
			<div class="me-auto">
				<h4 class="mb-0" id="duSaludo">Mi dashboard</h4>
				<div class="text-muted" id="duAlcance">Cargando…</div>
			</div>
			<div class="d-flex align-items-center gap-2">
				<span class="small text-muted" id="duActualizado"></span>
				<button type="button" class="btn btn-sm btn-outline-secondary" id="duRefrescar" title="Actualizar"><i class="bx bx-refresh"></i></button>
			</div>
		</div>
	</div>

	<!-- Hoy -->
	<h6 class="db-titulo mt-1">Hoy</h6>
	<div class="row row-cols-2 row-cols-md-3 row-cols-xl-6 g-3 mb-3">
		<div class="col"><div class="card radius-10 mb-0 db-kpi"><div class="card-body"><span><i class="bx bx-calendar-check"></i> Citas</span><strong id="kCitasHoy">—</strong><small>programadas para hoy</small></div></div></div>
		<div class="col"><div class="card radius-10 mb-0 db-kpi"><div class="card-body"><span><i class="bx bx-time-five"></i> Por llegar</span><strong id="kPorLlegar">—</strong><small>aún no se registran</small></div></div></div>
		<div class="col"><div class="card radius-10 mb-0 db-kpi du-kpi-sala"><div class="card-body"><span><i class="bx bx-chair"></i> En sala</span><strong id="kEnSala">—</strong><small id="kEnSalaSub">esperando</small></div></div></div>
		<div class="col"><div class="card radius-10 mb-0 db-kpi du-kpi-atencion"><div class="card-body"><span><i class="bx bx-pulse"></i> En atención</span><strong id="kEnAtencion">—</strong><small>ahora mismo</small></div></div></div>
		<div class="col"><div class="card radius-10 mb-0 db-kpi"><div class="card-body"><span><i class="bx bx-check-circle"></i> Atendidas</span><strong id="kAtendidasHoy" class="text-success">—</strong><small id="kAtendidasHoySub"></small></div></div></div>
		<div class="col"><div class="card radius-10 mb-0 db-kpi"><div class="card-body"><span><i class="bx bx-x-circle"></i> Canceladas</span><strong id="kCanceladasHoy" class="text-danger">—</strong><small>de hoy</small></div></div></div>
	</div>

	<div class="row g-3 mb-3">
		<!-- Agenda de hoy -->
		<div class="col-xl-7">
			<div class="card radius-10 h-100 mb-0"><div class="card-body">
				<div class="d-flex align-items-center mb-2">
					<h6 class="db-titulo mb-0">Agenda de hoy</h6>
					<span class="badge rounded-pill bg-light text-dark ms-2" id="duAgendaTotal"></span>
				</div>
				<div id="duAgenda" class="du-agenda"></div>
			</div></div>
		</div>
		<!-- Próximos días -->
		<div class="col-xl-5">
			<div class="card radius-10 h-100 mb-0"><div class="card-body">
				<h6 class="db-titulo">Citas de los próximos 7 días</h6>
				<div id="duGraficoSemana" class="db-grafico-bajo"></div>
				<h6 class="db-titulo mt-3">Próximas citas</h6>
				<div id="duProximas" class="du-lista"></div>
			</div></div>
		</div>
	</div>

	<!-- Meta del mes: solo cuando el usuario es especialista -->
	<div class="card radius-10 mb-3 d-none" id="duMetaCard"><div class="card-body">
		<div class="d-flex flex-wrap align-items-center gap-2 mb-2">
			<h6 class="db-titulo mb-0"><i class="bx bx-target-lock"></i> <span id="duMetaTitulo">Mi meta del mes</span></h6>
			<span class="text-muted small" id="duMetaPeriodo"></span>
		</div>
		<!-- administrador: todos los especialistas -->
		<div id="duMetaTodos" class="d-none"></div>
		<!-- especialista: su avance -->
		<div class="row g-3 align-items-center" id="duMetaUno">
			<div class="col-md-4 col-xl-3"><div id="duGraficoMeta"></div></div>
			<div class="col-md-8 col-xl-5">
				<div class="row row-cols-2 g-2" id="duMetaDatos"></div>
			</div>
			<div class="col-xl-4">
				<div class="small fw-semibold mb-1">Bonificación por escala</div>
				<div id="duMetaEscala" class="du-lista"></div>
			</div>
		</div>
		<div class="small text-muted mt-2">Ventas sin IVA de sus procedimientos facturados este mes (con descuentos). Montos estimados: el bono final lo confirma administración.</div>
	</div></div>

	<!-- Este mes -->
	<h6 class="db-titulo" id="duMesTitulo">Este mes</h6>
	<div class="row row-cols-2 row-cols-lg-4 g-3 mb-3">
		<div class="col"><div class="card radius-10 mb-0 db-kpi"><div class="card-body"><span><i class="bx bx-plus-medical"></i> Procedimientos</span><strong id="kProcMes">—</strong><small>finalizados</small></div></div></div>
		<div class="col"><div class="card radius-10 mb-0 db-kpi"><div class="card-body"><span><i class="bx bx-user-check"></i> Pacientes atendidos</span><strong id="kPacientesMes">—</strong><small id="kPacientesMesSub"></small></div></div></div>
		<div class="col"><div class="card radius-10 mb-0 db-kpi"><div class="card-body"><span><i class="bx bx-stopwatch"></i> Duración promedio</span><strong id="kMinutos">—</strong><small>por procedimiento</small></div></div></div>
		<div class="col"><div class="card radius-10 mb-0 db-kpi"><div class="card-body"><span><i class="bx bx-check-shield"></i> Asistencia</span><strong id="kAsistencia">—</strong><small id="kAsistenciaSub"></small></div></div></div>
	</div>

	<div class="row g-3">
		<div class="col-xl-6">
			<div class="card radius-10 h-100 mb-0"><div class="card-body">
				<h6 class="db-titulo">Procedimientos finalizados · últimos 30 días</h6>
				<div id="duGraficoProc" class="db-grafico"></div>
			</div></div>
		</div>
		<div class="col-md-6 col-xl-3">
			<div class="card radius-10 h-100 mb-0"><div class="card-body">
				<h6 class="db-titulo">Tratamientos del mes</h6>
				<div id="duTratamientos"></div>
			</div></div>
		</div>
		<div class="col-md-6 col-xl-3">
			<div class="card radius-10 h-100 mb-0"><div class="card-body">
				<h6 class="db-titulo"><i class="bx bx-cake"></i> Cumpleaños de la semana</h6>
				<div id="duCumpleanos" class="du-lista"></div>
			</div></div>
		</div>

		<!-- Garantías de servicios: detalle de los últimos 90 días -->
		<div class="col-12">
			<div class="card radius-10 mb-0"><div class="card-body">
				<div class="d-flex flex-wrap align-items-center gap-2 mb-2">
					<h6 class="db-titulo mb-0"><i class="bx bx-shield-quarter"></i> Garantías de servicios</h6>
					<span class="text-muted small">últimos 90 días</span>
					<span class="ms-auto small" id="duGarantiasResumen"></span>
				</div>
				<div class="table-responsive">
					<table class="table table-sm align-middle mb-0 db-tabla">
						<thead class="table-light">
							<tr>
								<th style="width:110px;">Registrada</th>
								<th>Paciente</th>
								<th class="d-none d-md-table-cell">Procedimiento</th>
								<th class="du-esp-col d-none d-lg-table-cell">Especialista</th>
								<th>Detalle</th>
								<th class="d-none d-lg-table-cell">Registró</th>
							</tr>
						</thead>
						<tbody id="duGarantias"></tbody>
					</table>
				</div>
			</div></div>
		</div>
	</div>
</div>

<script src="assets/js/dashboard-usuarios.js?v=11"></script>
