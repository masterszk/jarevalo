<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="frm_Expedientes.aspx.cs" Inherits="DPieCenter.Reportes.frm_Expedientes" %>

<link href="assets/css/dashboard.css?v=9" rel="stylesheet" />

<div class="page-breadcrumb d-flex flex-wrap align-items-center gap-2 mb-3 cj-no-imprimir">
	<div class="breadcrumb-title pe-3">Reportes</div>
	<div class="ps-3 d-none d-sm-block">
		<nav aria-label="breadcrumb"><ol class="breadcrumb mb-0 p-0">
			<li class="breadcrumb-item"><a href="javascript:;"><i class="bx bx-folder-open"></i></a></li>
			<li class="breadcrumb-item active" aria-current="page">Expedientes</li>
		</ol></nav>
	</div>
</div>

<div class="cj">
	<!-- Filtros -->
	<div class="card radius-10 cj-no-imprimir">
		<div class="card-body">
			<div class="row g-2 align-items-end" id="rpFiltros">
				<div class="col-6 col-md-3 col-xl-2"><label for="rpDesde" class="form-label small mb-1">Registrados desde</label><input type="date" class="form-control" id="rpDesde" /></div>
				<div class="col-6 col-md-3 col-xl-2"><label for="rpHasta" class="form-label small mb-1">Hasta</label><input type="date" class="form-control" id="rpHasta" /></div>
				<div class="col-md-6 col-xl-2"><label for="rpSexo" class="form-label small mb-1">Sexo</label>
					<select class="form-select" id="rpSexo"><option value="0">Todos</option></select></div>
				<div class="col-md-4 col-xl-2"><label for="rpDepartamento" class="form-label small mb-1">Departamento</label>
					<select class="form-select" id="rpDepartamento"><option value="0">Todos</option></select></div>
				<div class="col-md-4 col-xl-2"><label for="rpFuente" class="form-label small mb-1">¿Cómo nos conoció?</label>
					<select class="form-select" id="rpFuente">
						<option value="0">Todos</option>
						<option value="Facebook">Facebook</option>
						<option value="Instagram">Instagram</option>
						<option value="TikTok">TikTok</option>
						<option value="WhatsApp">WhatsApp</option>
						<option value="Buscador">Buscador web</option>
						<option value="Recomendado">Recomendado</option>
						<option value="Otros">Otros</option>
						<option value="SinDato">Sin dato</option>
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
			<div class="me-auto"><h5 class="mb-0">Reporte de expedientes</h5><div class="text-muted small" id="rpTitulo"></div></div>
			<button type="button" class="btn btn-sm btn-outline-success cj-no-imprimir" id="rpExportar"><i class="bx bx-spreadsheet"></i> Exportar a Excel (CSV)</button>
			<button type="button" class="btn btn-sm btn-outline-secondary cj-no-imprimir" id="rpImprimir"><i class="bx bx-printer"></i> Imprimir</button>
		</div>

		<div class="row row-cols-2 row-cols-lg-5 g-3 mb-3">
			<div class="col"><div class="card radius-10 mb-0 db-kpi"><div class="card-body"><span>Expedientes nuevos</span><strong id="kTotal">—</strong><small>registrados en el periodo</small></div></div></div>
			<div class="col"><div class="card radius-10 mb-0 db-kpi"><div class="card-body"><span>Ya atendidos</span><strong id="kVisitas" class="text-success">—</strong><small id="kVisitasSub"></small></div></div></div>
			<div class="col"><div class="card radius-10 mb-0 db-kpi"><div class="card-body"><span>Recurrentes</span><strong id="kRecurrentes">—</strong><small>con 2 o más visitas</small></div></div></div>
			<div class="col"><div class="card radius-10 mb-0 db-kpi"><div class="card-body"><span>Edad promedio</span><strong id="kEdad">—</strong><small>años</small></div></div></div>
			<div class="col"><div class="card radius-10 mb-0 db-kpi"><div class="card-body"><span>Sin email</span><strong id="kSinEmail" class="text-warning">—</strong><small>no reciben su factura por correo</small></div></div></div>
		</div>

		<div class="row g-3 mb-3">
			<div class="col-md-6 col-xl"><div class="card radius-10 h-100 mb-0"><div class="card-body"><h6 class="db-titulo">Por sexo</h6><ul class="list-group list-group-flush cj-grupo" id="gSexo"></ul></div></div></div>
			<div class="col-md-6 col-xl"><div class="card radius-10 h-100 mb-0"><div class="card-body"><h6 class="db-titulo">Por edad</h6><ul class="list-group list-group-flush cj-grupo" id="gEdad"></ul></div></div></div>
			<div class="col-md-6 col-xl"><div class="card radius-10 h-100 mb-0"><div class="card-body"><h6 class="db-titulo">¿Cómo nos conocieron?</h6><ul class="list-group list-group-flush cj-grupo" id="gFuente"></ul></div></div></div>
			<div class="col-md-6 col-xl"><div class="card radius-10 h-100 mb-0"><div class="card-body"><h6 class="db-titulo">Por departamento</h6><ul class="list-group list-group-flush cj-grupo db-lista-alta" id="gDepartamento"></ul></div></div></div>
			<div class="col-md-6 col-xl"><div class="card radius-10 h-100 mb-0"><div class="card-body"><h6 class="db-titulo">Registrados por</h6><ul class="list-group list-group-flush cj-grupo" id="gUsuario"></ul></div></div></div>
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
<script src="assets/js/reporte-expedientes.js?v=2"></script>
