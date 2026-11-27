<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="frm_repCaja.aspx.cs" Inherits="DPieCenter.Reportes.frm_repCaja" %>

<link href="assets/css/dashboard.css?v=9" rel="stylesheet" />

<!--breadcrumb-->
<div class="page-breadcrumb d-flex flex-wrap align-items-center gap-2 mb-3 cj-no-imprimir">
	<div class="breadcrumb-title pe-3">Reportes</div>
	<div class="ps-3 d-none d-sm-block">
		<nav aria-label="breadcrumb">
			<ol class="breadcrumb mb-0 p-0">
				<li class="breadcrumb-item"><a href="javascript:;"><i class="bx bx-receipt"></i></a></li>
				<li class="breadcrumb-item active" aria-current="page">Caja</li>
			</ol>
		</nav>
	</div>
</div>

<div class="cj" id="caja">
	<!-- Filtros -->
	<div class="card radius-10 cj-no-imprimir">
		<div class="card-body">
			<div class="row g-2 align-items-end">
				<div class="col-6 col-md-3 col-xl-2">
					<label for="cjDesde" class="form-label small mb-1">Desde</label>
					<input type="date" class="form-control" id="cjDesde" />
				</div>
				<div class="col-6 col-md-3 col-xl-2">
					<label for="cjHasta" class="form-label small mb-1">Hasta</label>
					<input type="date" class="form-control" id="cjHasta" />
				</div>
				<div class="col-md-3 col-xl-2 d-none" id="cjSucursalCol">
					<label for="cjSucursal" class="form-label small mb-1">Sucursal</label>
					<select class="form-select" id="cjSucursal"><option value="0">Todas las sucursales</option></select>
				</div>
				<div class="col-md-3 col-xl-2">
					<label for="cjCajero" class="form-label small mb-1">Cajero</label>
					<select class="form-select" id="cjCajero"><option value="">Todos los cajeros</option></select>
				</div>
				<div class="col-md-3 col-xl-2 d-grid">
					<button type="button" class="btn btn-primary" id="cjConsultar"><i class="bx bx-search"></i> Consultar</button>
				</div>
				<div class="col-xl-3 d-flex flex-wrap gap-1 justify-content-xl-end" id="cjRapidos" aria-label="Rangos rápidos">
					<button type="button" class="btn btn-sm btn-outline-secondary" data-rango="hoy">Hoy</button>
					<button type="button" class="btn btn-sm btn-outline-secondary" data-rango="ayer">Ayer</button>
					<button type="button" class="btn btn-sm btn-outline-secondary" data-rango="semana">Esta semana</button>
					<button type="button" class="btn btn-sm btn-outline-secondary" data-rango="mes">Este mes</button>
					<button type="button" class="btn btn-sm btn-outline-secondary" data-rango="anterior">Mes anterior</button>
				</div>
			</div>
		</div>
	</div>

	<div id="cjResultado" class="d-none">
		<div class="d-flex flex-wrap align-items-center gap-2 mb-3">
			<div class="me-auto">
				<h5 class="mb-0">Reporte de caja</h5>
				<div class="text-muted small" id="cjTitulo"></div>
			</div>
			<button type="button" class="btn btn-sm btn-danger cj-no-imprimir" id="cjPdf"><i class="bx bxs-file-pdf"></i> Cierre de caja (PDF)</button>
			<button type="button" class="btn btn-sm btn-outline-success cj-no-imprimir" id="cjExportar"><i class="bx bx-spreadsheet"></i> Exportar a Excel</button>
		</div>

		<!-- Totales -->
		<div class="row row-cols-2 row-cols-lg-5 g-3 mb-3">
			<div class="col"><div class="card radius-10 mb-0 db-kpi"><div class="card-body"><span>Total cobrado</span><strong id="cjTotal">—</strong><small id="cjTotalSub"></small></div></div></div>
			<div class="col"><div class="card radius-10 mb-0 db-kpi"><div class="card-body"><span>Documentos</span><strong id="cjDocs">—</strong><small id="cjDocsSub"></small></div></div></div>
			<div class="col"><div class="card radius-10 mb-0 db-kpi"><div class="card-body"><span>Ticket promedio</span><strong id="cjTicket">—</strong><small>por documento</small></div></div></div>
			<div class="col"><div class="card radius-10 mb-0 db-kpi"><div class="card-body"><span>Anulados</span><strong id="cjAnulados" class="text-danger">—</strong><small id="cjAnuladosSub"></small></div></div></div>
			<div class="col"><div class="card radius-10 mb-0 db-kpi"><div class="card-body"><span>Pendiente de cobro</span><strong id="cjPendiente" class="text-warning">—</strong><small id="cjPendienteSub"></small></div></div></div>
		</div>
		<div class="row row-cols-2 row-cols-lg-4 g-3 mb-3">
			<div class="col"><div class="card radius-10 mb-0 db-kpi"><div class="card-body"><span>Manejo de efectivo</span><strong id="cjSalidas">—</strong><small id="cjSalidasSub"></small></div></div></div>
			<div class="col"><div class="card radius-10 mb-0 db-kpi"><div class="card-body"><span>Arqueo (sobrante / faltante)</span><strong id="cjArqueo">—</strong><small id="cjArqueoSub"></small></div></div></div>
			<div class="col"><div class="card radius-10 mb-0 db-kpi"><div class="card-body"><span>Descuentos (tratamientos y cupones)</span><strong id="cjDescuentos">—</strong><small id="cjDescuentosSub"></small></div></div></div>
			<div class="col"><div class="card radius-10 mb-0 db-kpi"><div class="card-body"><span>Tickets sin costo</span><strong id="cjTickets">—</strong><small>servicios $0.00 (sin DTE)</small></div></div></div>
		</div>

		<!-- Resúmenes -->
		<div class="row g-3 mb-3">
			<div class="col-md-6 col-xl-3"><div class="card radius-10 cj-alto mb-0"><div class="card-body">
				<h6 class="db-titulo">Por forma de pago</h6>
				<ul class="list-group list-group-flush cj-grupo cj-scroll" id="cjPorForma"></ul>
				<div class="cj-grupo-total d-none" id="cjPorFormaTotal"></div>
			</div></div></div>
			<div class="col-md-6 col-xl-3"><div class="card radius-10 cj-alto mb-0"><div class="card-body">
				<h6 class="db-titulo">Por cajero</h6><ul class="list-group list-group-flush cj-grupo cj-scroll" id="cjPorCajero"></ul>
			</div></div></div>
			<div class="col-md-6 col-xl-3"><div class="card radius-10 cj-alto mb-0"><div class="card-body">
				<h6 class="db-titulo">Por tipo de documento</h6><ul class="list-group list-group-flush cj-grupo cj-scroll" id="cjPorTipo"></ul>
			</div></div></div>
			<div class="col-md-6 col-xl-3"><div class="card radius-10 cj-alto mb-0"><div class="card-body">
				<div class="cj-cabecera">
					<h6 class="db-titulo mb-0">Por día</h6>
					<button type="button" class="btn btn-sm btn-outline-success cj-no-imprimir cj-xlsx" data-xlsx="dia" data-texto-corto="1" title="Descargar en Excel (.xlsx)" aria-label="Descargar Por día en Excel"><i class="bx bx-download"></i></button>
				</div>
				<ul class="list-group list-group-flush cj-grupo cj-scroll" id="cjPorDia"></ul>
			</div></div></div>
		</div>

		<!-- Cajas diarias: apertura, cierre y arqueo -->
		<div class="card radius-10 cj-alto">
			<div class="card-body">
				<div class="cj-cabecera">
					<h6 class="db-titulo mb-0">Aperturas y cierres de caja</h6>
					<button type="button" class="btn btn-sm btn-outline-success cj-no-imprimir cj-xlsx" data-xlsx="cajas" data-texto-corto="1" title="Descargar en Excel (.xlsx)" aria-label="Descargar Aperturas y cierres de caja en Excel"><i class="bx bx-download"></i></button>
				</div>
				<div class="table-responsive cj-scroll">
					<table class="table table-sm table-hover align-middle mb-0 cj-tabla">
						<thead class="table-light">
							<tr>
								<th>Fecha</th>
								<th>Cajero</th>
								<th>Horario</th>
								<th class="text-end">Fondo</th>
								<th class="text-end">Cobrado</th>
								<th class="text-end">Efectivo</th>
								<th class="text-end">Entradas / salidas</th>
								<th class="text-end">Esperado</th>
								<th class="text-end">Contado</th>
								<th class="text-end">Diferencia</th>
								<th>Observaciones</th>
							</tr>
						</thead>
						<tbody id="cjCajas"></tbody>
					</table>
				</div>
			</div>
		</div>

		<div class="row g-3 mb-3">
			<div class="col-xl-7"><div class="card radius-10 cj-alto mb-0"><div class="card-body">
				<div class="d-flex flex-wrap align-items-center gap-2 mb-2">
					<h6 class="db-titulo mb-0">Manejo de efectivo</h6>
					<div class="small text-muted ms-auto" id="cjPorCategoria"></div>
					<button type="button" class="btn btn-sm btn-outline-success cj-no-imprimir cj-xlsx" data-xlsx="efectivo" data-texto-corto="1" title="Descargar en Excel (.xlsx)" aria-label="Descargar Manejo de efectivo en Excel"><i class="bx bx-download"></i></button>
				</div>
				<div class="table-responsive cj-scroll">
					<table class="table table-sm align-middle mb-0 cj-tabla">
						<thead class="table-light"><tr><th>Fecha</th><th>Cajero</th><th>Movimiento</th><th>Motivo</th><th class="text-end">Monto</th></tr></thead>
						<tbody id="cjSalidasFilas"></tbody>
					</table>
				</div>
			</div></div></div>
			<div class="col-xl-5"><div class="card radius-10 cj-alto mb-0"><div class="card-body">
				<h6 class="db-titulo">Anulaciones de DTE</h6>
				<div class="table-responsive cj-scroll">
					<table class="table table-sm align-middle mb-0 cj-tabla">
						<thead class="table-light"><tr><th>Documento</th><th>Anulado</th><th>Motivo</th><th class="text-end">Total</th></tr></thead>
						<tbody id="cjAnulaciones"></tbody>
					</table>
				</div>
			</div></div></div>
		</div>

		<!-- Detalle -->
		<div class="card radius-10">
			<div class="card-body">
				<div class="d-flex flex-wrap align-items-center gap-2 mb-2">
					<h6 class="db-titulo mb-0">Detalle de cobros</h6>
					<div class="form-check form-switch ms-auto cj-no-imprimir">
						<input class="form-check-input" type="checkbox" id="cjVerAnulados" checked>
						<label class="form-check-label small" for="cjVerAnulados">Mostrar anulados</label>
					</div>
					<button type="button" class="btn btn-sm btn-outline-success cj-no-imprimir cj-xlsx" data-xlsx="detalle" data-texto-corto="1" title="Descargar en Excel (.xlsx)" aria-label="Descargar Detalle de cobros en Excel"><i class="bx bx-download"></i></button>
				</div>
				<div class="table-responsive">
					<table class="table table-sm table-hover align-middle mb-0 cj-tabla">
						<thead class="table-light">
							<tr>
								<th>Fecha</th>
								<th>Documento</th>
								<th>Cliente</th>
								<th>Forma de pago</th>
								<th>Cajero</th>
								<th class="text-end">Gravado</th>
								<th class="text-end">IVA</th>
								<th class="text-end">Total</th>
								<th></th>
							</tr>
						</thead>
						<tbody id="cjFilas"></tbody>
						<tfoot class="table-light">
							<tr>
								<th colspan="5" class="text-end">Total (sin anulados)</th>
								<th class="text-end" id="cjPieGravado"></th>
								<th class="text-end" id="cjPieIva"></th>
								<th class="text-end" id="cjPieTotal"></th>
								<th></th>
							</tr>
						</tfoot>
					</table>
				</div>
			</div>
		</div>
	</div>

	<div id="cjVacio" class="card radius-10"><div class="card-body text-center text-muted py-5">
		<i class="bx bx-receipt fs-1 d-block mb-2"></i>Seleccione un rango de fechas y presione <strong>Consultar</strong>.
	</div></div>
</div>

<script src="assets/js/excel-reportes.js?v=1"></script>
<script src="assets/js/reporte-caja.js?v=10"></script>
