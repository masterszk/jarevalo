<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="frm_repCajaEspecialistas.aspx.cs" Inherits="DPieCenter.Reportes.frm_repCajaEspecialistas" %>

<link href="assets/css/dashboard.css?v=9" rel="stylesheet" />

<div class="page-breadcrumb d-flex flex-wrap align-items-center gap-2 mb-3 cj-no-imprimir">
	<div class="breadcrumb-title pe-3">Reportes</div>
	<div class="ps-3 d-none d-sm-block">
		<nav aria-label="breadcrumb"><ol class="breadcrumb mb-0 p-0">
			<li class="breadcrumb-item"><a href="javascript:;"><i class="bx bx-receipt"></i></a></li>
			<li class="breadcrumb-item active" aria-current="page">Caja por especialista</li>
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
				<div class="col-md-4 col-xl-2"><label for="rpFormaPago" class="form-label small mb-1">Forma de pago</label>
					<select class="form-select" id="rpFormaPago"><option value="0">Todas</option></select></div>
				<div class="col-md-4 col-xl-2"><label for="rpPaciente" class="form-label small mb-1">Paciente</label>
					<input type="search" class="form-control" id="rpPaciente" placeholder="Nombre, documento o celular" /></div>
				<div class="col-12 d-flex flex-wrap gap-2 align-items-center">
					<button type="button" class="btn btn-primary" id="rpConsultar"><i class="bx bx-search"></i> Consultar</button>
					<button type="button" class="btn btn-outline-secondary" id="rpLimpiar"><i class="bx bx-eraser"></i> Quitar filtros</button>
					<div class="ms-auto d-flex flex-wrap gap-1" id="rpRapidos">
						<button type="button" class="btn btn-sm btn-outline-secondary" data-rango="hoy">Hoy</button>
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
			<div class="me-auto"><h5 class="mb-0">Caja por especialista</h5><div class="text-muted small" id="rpTitulo"></div></div>
			<button type="button" class="btn btn-sm btn-outline-danger cj-no-imprimir" id="rpPdf"><i class="bx bxs-file-pdf"></i> Descargar PDF</button>
			<button type="button" class="btn btn-sm btn-outline-success cj-no-imprimir" id="rpExportar"><i class="bx bx-spreadsheet"></i> Exportar a Excel</button>
			<button type="button" class="btn btn-sm btn-outline-secondary cj-no-imprimir" id="rpImprimir"><i class="bx bx-printer"></i> Imprimir</button>
		</div>

		<div class="row row-cols-2 row-cols-lg-5 g-3 mb-3">
			<div class="col"><div class="card radius-10 mb-0 db-kpi"><div class="card-body"><span>Total cobrado</span><strong id="kCobrado">—</strong><small id="kCobradoSub"></small></div></div></div>
			<div class="col"><div class="card radius-10 mb-0 db-kpi"><div class="card-body"><span>Ventas sin IVA</span><strong id="kSinIva">—</strong><small id="kSinIvaSub"></small></div></div></div>
			<div class="col"><div class="card radius-10 mb-0 db-kpi"><div class="card-body"><span id="kComisionTitulo">Comisión</span><strong id="kComision">—</strong><small id="kComisionSub"></small></div></div></div>
			<div class="col"><div class="card radius-10 mb-0 db-kpi"><div class="card-body"><span>Pacientes</span><strong id="kPacientes">—</strong><small>con cobros en el periodo</small></div></div></div>
			<div class="col"><div class="card radius-10 mb-0 db-kpi"><div class="card-body"><span>Ticket promedio</span><strong id="kTicket">—</strong><small>por documento</small></div></div></div>
		</div>

		<!-- Resumen por especialista -->
		<div class="card radius-10">
			<div class="card-body">
				<h6 class="db-titulo">Por especialista</h6>
				<div class="table-responsive">
					<table class="table table-sm align-middle mb-0 cj-tabla db-tabla-esp">
						<thead class="table-light" id="ceThead"></thead>
						<tbody id="ceFilas"></tbody>
						<tfoot class="table-light fw-semibold" id="cePie"></tfoot>
					</table>
				</div>
				<div class="small text-muted mt-2" id="ceNota">
					Cobrado: DTE vigentes emitidos en el periodo, asignados al especialista que atendió el procedimiento.
					Sin IVA: factura ÷ 1.13 y crédito fiscal por su venta gravada, el mismo cálculo de las metas.
					Comisión: esquema de bono de Registros › Metas (comisión por escala + bono de escala + bono por cumplir la meta)
					con las ventas sin IVA del periodo y la meta de cada mes; si el periodo no es el mes completo, es la comisión de lo vendido en esas fechas.
				</div>
			</div>
		</div>

		<div class="row g-3 mb-3">
			<div class="col-lg-6"><div class="card radius-10 cj-alto mb-0"><div class="card-body">
				<h6 class="db-titulo">Por forma de pago</h6>
				<ul class="list-group list-group-flush cj-grupo cj-scroll" id="ceFormas"></ul>
				<div class="cj-grupo-total d-none" id="ceFormasTotal"></div>
			</div></div></div>
			<div class="col-lg-6"><div class="card radius-10 cj-alto mb-0"><div class="card-body">
				<div class="cj-cabecera">
					<h6 class="db-titulo mb-0">Por día</h6>
					<button type="button" class="btn btn-sm btn-outline-success cj-no-imprimir cj-xlsx" data-xlsx="dia" data-texto-corto="1" title="Descargar en Excel (.xlsx)" aria-label="Descargar Por día en Excel"><i class="bx bx-download"></i></button>
				</div>
				<ul class="list-group list-group-flush cj-grupo cj-scroll" id="ceDias"></ul>
				<div class="cj-grupo-total d-none" id="ceDiasTotal"></div>
			</div></div></div>
		</div>

		<div class="card radius-10">
			<div class="card-body">
				<div class="d-flex flex-wrap align-items-center gap-2 mb-2">
					<h6 class="db-titulo mb-0">Detalle de cobros</h6>
					<input type="search" class="form-control form-control-sm ms-auto cj-no-imprimir" id="rpBuscar" placeholder="Buscar en el detalle…" style="max-width:260px" />
					<button type="button" class="btn btn-sm btn-outline-success cj-no-imprimir cj-xlsx" data-xlsx="detalle" data-texto-corto="1" title="Descargar en Excel (.xlsx)" aria-label="Descargar Detalle de cobros en Excel"><i class="bx bx-download"></i></button>
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

<script src="assets/js/reportes-comun.js?v=4"></script>
<script src="assets/js/excel-reportes.js?v=1"></script>
<script src="assets/js/reporte-caja-especialistas.js?v=6"></script>
