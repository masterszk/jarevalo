<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="frm_repGarantias.aspx.cs" Inherits="DPieCenter.Reportes.frm_repGarantias" %>

<link href="assets/css/dashboard.css?v=9" rel="stylesheet" />

<div class="page-breadcrumb d-flex flex-wrap align-items-center gap-2 mb-3 cj-no-imprimir">
	<div class="breadcrumb-title pe-3">Reportes</div>
	<div class="ps-3 d-none d-sm-block">
		<nav aria-label="breadcrumb"><ol class="breadcrumb mb-0 p-0">
			<li class="breadcrumb-item"><a href="javascript:;"><i class="bx bx-shield-quarter"></i></a></li>
			<li class="breadcrumb-item active" aria-current="page">Garantía de Servicios</li>
		</ol></nav>
	</div>
</div>

<div class="cj">
	<!-- Filtros -->
	<div class="card radius-10 cj-no-imprimir">
		<div class="card-body">
			<div class="row g-2 align-items-end" id="rpFiltros">
				<div class="col-6 col-md-3 col-xl-2"><label for="rpDesde" class="form-label small mb-1">Desde</label><input type="date" class="form-control" id="rpDesde" /></div>
				<div class="col-6 col-md-3 col-xl-2"><label for="rpHasta" class="form-label small mb-1">Hasta</label><input type="date" class="form-control" id="rpHasta" /></div>
				<div class="col-md-6 col-xl-2"><label for="rpEspecialista" class="form-label small mb-1">Especialista</label>
					<select class="form-select" id="rpEspecialista"><option value="0">Todos</option></select></div>
				<div class="col-md-4 col-xl-2"><label for="rpTratamiento" class="form-label small mb-1">Tratamiento</label>
					<select class="form-select" id="rpTratamiento"><option value="0">Todos</option></select></div>
				<div class="col-md-4 col-xl-2"><label for="rpVisto" class="form-label small mb-1">Visto por el especialista</label>
					<select class="form-select" id="rpVisto">
						<option value="0">Todas</option>
						<option value="1">No vistas</option>
						<option value="2">Vistas</option>
					</select></div>
				<div class="col-md-4 col-xl-2"><label for="rpPaciente" class="form-label small mb-1">Paciente</label>
					<input type="search" class="form-control" id="rpPaciente" placeholder="Nombre, documento o celular" /></div>
				<div class="col-12 d-flex flex-wrap gap-2 align-items-center">
					<button type="button" class="btn btn-primary" id="rpConsultar"><i class="bx bx-search"></i> Consultar</button>
					<button type="button" class="btn btn-outline-secondary" id="rpLimpiar"><i class="bx bx-eraser"></i> Quitar filtros</button>
					<div class="ms-auto d-flex flex-wrap gap-1" id="rpRapidos">
						<button type="button" class="btn btn-sm btn-outline-secondary" data-rango="semana">Esta semana</button>
						<button type="button" class="btn btn-sm btn-outline-secondary" data-rango="mes">Este mes</button>
						<button type="button" class="btn btn-sm btn-outline-secondary" data-rango="anterior">Mes anterior</button>
						<button type="button" class="btn btn-sm btn-outline-secondary" data-rango="anio">Este año</button>
					</div>
				</div>
			</div>
		</div>
	</div>

	<div id="rpResultado" class="d-none">
		<div class="d-flex flex-wrap align-items-center gap-2 mb-3">
			<div class="me-auto"><h5 class="mb-0">Garantía de Servicios</h5><div class="text-muted small" id="rpTitulo"></div></div>
			<button type="button" class="btn btn-sm btn-outline-success cj-no-imprimir" id="rpExportar"><i class="bx bx-spreadsheet"></i> Exportar a Excel (CSV)</button>
			<button type="button" class="btn btn-sm btn-outline-secondary cj-no-imprimir" id="rpImprimir"><i class="bx bx-printer"></i> Imprimir</button>
		</div>

		<div class="row row-cols-2 row-cols-lg-5 g-3 mb-3">
			<div class="col"><div class="card radius-10 mb-0 db-kpi"><div class="card-body"><span>Garantías</span><strong id="kGarantias">—</strong><small id="kGarantiasSub"></small></div></div></div>
			<div class="col"><div class="card radius-10 mb-0 db-kpi"><div class="card-body"><span>% sobre procedimientos</span><strong id="kPorcentaje">—</strong><small id="kPorcentajeSub"></small></div></div></div>
			<div class="col"><div class="card radius-10 mb-0 db-kpi"><div class="card-body"><span>Pacientes</span><strong id="kPacientes">—</strong><small>con garantía en el periodo</small></div></div></div>
			<div class="col"><div class="card radius-10 mb-0 db-kpi"><div class="card-body"><span>No vistas</span><strong id="kNoVistas">—</strong><small>por el especialista</small></div></div></div>
			<div class="col"><div class="card radius-10 mb-0 db-kpi"><div class="card-body"><span>Días después del procedimiento</span><strong id="kDias">—</strong><small>promedio hasta registrar la garantía</small></div></div></div>
		</div>

		<div class="row g-3 mb-3">
			<div class="col-lg-5"><div class="card radius-10 h-100 mb-0"><div class="card-body">
				<h6 class="db-titulo">Por especialista</h6>
				<div class="table-responsive">
					<table class="table table-sm align-middle mb-0">
						<thead class="table-light"><tr><th>Especialista</th><th class="text-end">Garantías</th><th class="text-end">Procedimientos</th><th class="text-end">%</th></tr></thead>
						<tbody id="gEspecialistas"></tbody>
					</table>
				</div>
				<div class="small text-muted mt-1">% = garantías registradas en el periodo ÷ procedimientos finalizados en el periodo.</div>
			</div></div></div>
			<div class="col-lg-4"><div class="card radius-10 h-100 mb-0"><div class="card-body"><h6 class="db-titulo">Por tratamiento</h6><ul class="list-group list-group-flush cj-grupo" id="gTratamientos"></ul></div></div></div>
			<div class="col-lg-3"><div class="card radius-10 h-100 mb-0"><div class="card-body"><h6 class="db-titulo">Por semana</h6><ul class="list-group list-group-flush cj-grupo" id="gSemanas"></ul></div></div></div>
		</div>

		<div class="card radius-10">
			<div class="card-body">
				<div class="d-flex flex-wrap align-items-center gap-2 mb-2">
					<h6 class="db-titulo mb-0">Detalle</h6>
					<input type="search" class="form-control form-control-sm ms-auto cj-no-imprimir" id="rpBuscar" placeholder="Buscar en el detalle…" style="max-width:260px" />
				</div>
				<div class="table-responsive">
					<table class="table table-sm table-hover align-middle mb-0 cj-tabla">
						<thead class="table-light" id="rpThead"></thead>
						<tbody id="rpFilas"></tbody>
					</table>
				</div>
				<nav class="d-flex flex-wrap justify-content-between align-items-center gap-2 mt-3 cj-no-imprimir" aria-label="Paginación">
					<span class="small text-muted" id="rpPaginaTexto"></span>
					<ul class="pagination pagination-sm mb-0" id="rpPaginas"></ul>
				</nav>
			</div>
		</div>
	</div>

	<div id="rpVacio" class="card radius-10"><div class="card-body text-center text-muted py-5">
		<div class="spinner-border spinner-border-sm text-primary" role="status"></div> Generando reporte…
	</div></div>
</div>

<script src="assets/js/reportes-comun.js?v=3"></script>
<script src="assets/js/reporte-garantias.js?v=1"></script>
