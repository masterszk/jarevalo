<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="frm_Anulaciones.aspx.cs" Inherits="DPieCenter.Facturacion.frm_Anulaciones" %>

<link href="assets/css/administracion.css?v=2" rel="stylesheet" />
<link href="assets/css/caja.css?v=1" rel="stylesheet" />

<div class="page-breadcrumb d-flex flex-wrap align-items-center gap-2 mb-3">
	<div class="breadcrumb-title pe-3">Facturación</div>
	<div class="ps-3 d-none d-sm-block">
		<nav aria-label="breadcrumb"><ol class="breadcrumb mb-0 p-0">
			<li class="breadcrumb-item"><a href="javascript:;"><i class="bx bx-block"></i></a></li>
			<li class="breadcrumb-item active" aria-current="page">Anulaciones de DTE</li>
		</ol></nav>
	</div>
	<div class="ms-auto"><button type="button" class="btn btn-sm btn-outline-secondary d-none" id="anPlazosBtn"><i class="bx bx-cog"></i> Plazos de anulación</button></div>
</div>

<div class="alert alert-light border small d-flex gap-2" id="anAyuda">
	<i class="bx bx-info-circle fs-5"></i>
	<div>
		Solo se pueden anular (invalidar) los documentos dentro del plazo que fija el Ministerio de Hacienda: <span id="anPlazosTexto">…</span>.
		Pasado el plazo, la corrección se hace con una nota de crédito.
		Si anula por <strong>error en la información</strong> u <strong>otro motivo</strong>, la factura vuelve a la caja para emitir el documento que lo reemplaza.
	</div>
</div>

<div class="card radius-10">
	<div class="card-body">
		<ul class="nav nav-pills mb-3 gap-1" id="anVistas" role="tablist">
			<li class="nav-item"><button type="button" class="nav-link active" data-vista="plazo"><i class="bx bx-time-five"></i> En plazo para anular</button></li>
			<li class="nav-item"><button type="button" class="nav-link" data-vista="anulados"><i class="bx bx-block"></i> Anulados</button></li>
			<li class="nav-item"><button type="button" class="nav-link" data-vista="todos"><i class="bx bx-list-ul"></i> Todos</button></li>
		</ul>
		<div class="row g-2 mb-3 align-items-end">
			<div class="col-6 col-md-2"><label for="anDesde" class="form-label small mb-1">Emitidos desde</label><input type="date" class="form-control form-control-sm" id="anDesde" /></div>
			<div class="col-6 col-md-2"><label for="anHasta" class="form-label small mb-1">Hasta</label><input type="date" class="form-control form-control-sm" id="anHasta" /></div>
			<div class="col-6 col-md-2"><label for="anTipo" class="form-label small mb-1">Tipo</label>
				<select class="form-select form-select-sm" id="anTipo"><option value="">Todos</option><option value="01">Factura</option><option value="03">Crédito fiscal</option></select></div>
			<div class="col-6 col-md-2"><label for="anCajero" class="form-label small mb-1">Cajero</label>
				<select class="form-select form-select-sm" id="anCajero"><option value="">Todos</option></select></div>
			<div class="col-md-4"><label for="anBuscar" class="form-label small mb-1">Buscar</label>
				<input type="search" class="form-control form-control-sm" id="anBuscar" placeholder="Cliente, documento, N.º de control, código o factura" /></div>
			<div class="col-12 d-flex flex-wrap gap-1 align-items-center">
				<button type="button" class="btn btn-sm btn-light" data-rango="hoy">Hoy</button>
				<button type="button" class="btn btn-sm btn-light" data-rango="7">7 días</button>
				<button type="button" class="btn btn-sm btn-light" data-rango="mes">Este mes</button>
				<button type="button" class="btn btn-sm btn-light" data-rango="90">90 días</button>
				<button type="button" class="btn btn-sm btn-light" data-rango="todo">Todas las fechas</button>
				<button type="button" class="btn btn-sm btn-link" id="anLimpiar">Quitar filtros</button>
				<span class="ms-auto small text-muted" id="anConteo"></span>
			</div>
		</div>
		<div class="table-responsive">
			<table class="table table-hover align-middle mb-0 ad-tabla">
				<thead class="table-light"><tr><th>Emisión</th><th>Documento</th><th>Cliente</th><th class="text-end">Total</th><th class="d-none d-lg-table-cell">Cajero</th><th>Plazo / estado</th><th></th></tr></thead>
				<tbody id="anFilas"></tbody>
			</table>
		</div>
		<nav class="d-flex flex-wrap justify-content-between align-items-center gap-2 mt-3" aria-label="Paginación">
			<span class="small text-muted" id="anPaginaTexto"></span><ul class="pagination pagination-sm mb-0" id="anPaginas"></ul>
		</nav>
	</div>
</div>

<!-- Anular -->
<div class="modal fade" id="anModal" tabindex="-1" aria-labelledby="anModalTitulo" aria-hidden="true">
	<div class="modal-dialog modal-lg">
		<div class="modal-content">
			<form id="anForm" novalidate autocomplete="off">
				<div class="modal-header">
					<h5 class="modal-title" id="anModalTitulo">Anular documento</h5>
					<button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
				</div>
				<div class="modal-body">
					<div class="border rounded p-2 mb-3 small" id="anResumen"></div>

					<h6 class="ad-seccion">Tipo de anulación</h6>
					<div class="d-flex flex-column gap-2" id="anTipos">
						<label class="form-check"><input class="form-check-input" type="radio" name="anTipoAnulacion" value="1" checked />
							<span class="form-check-label"><strong>Error en la información</strong> <span class="text-muted">— se emitirá un documento nuevo que lo reemplaza.</span></span></label>
						<label class="form-check"><input class="form-check-input" type="radio" name="anTipoAnulacion" value="2" />
							<span class="form-check-label"><strong>Rescindir la operación</strong> <span class="text-muted">— la venta se cancela y no se emite otro documento.</span></span></label>
						<label class="form-check"><input class="form-check-input" type="radio" name="anTipoAnulacion" value="3" />
							<span class="form-check-label"><strong>Otro motivo</strong> <span class="text-muted">— describa el motivo; se emitirá un documento nuevo.</span></span></label>
					</div>
					<div class="mt-2">
						<label for="anMotivo" class="form-label">Motivo <span class="text-danger d-none" id="anMotivoReq">*</span></label>
						<textarea class="form-control" id="anMotivo" rows="2" maxlength="250"></textarea>
						<div class="invalid-feedback" id="anMotivoError"></div>
					</div>

					<div class="row g-3">
						<div class="col-md-6">
							<h6 class="ad-seccion">Responsable de la anulación</h6>
							<label for="anRespNombre" class="form-label small">Nombre <span class="text-danger">*</span></label>
							<input type="text" class="form-control form-control-sm mb-2" id="anRespNombre" maxlength="100" />
							<div class="row g-2">
								<div class="col-5"><label for="anRespTipo" class="form-label small">Documento</label>
									<select class="form-select form-select-sm an-tipodoc" id="anRespTipo"></select></div>
								<div class="col-7"><label for="anRespNum" class="form-label small">Número <span class="text-danger">*</span></label>
									<input type="text" class="form-control form-control-sm" id="anRespNum" maxlength="20" /></div>
							</div>
						</div>
						<div class="col-md-6">
							<h6 class="ad-seccion">Quién solicita la anulación</h6>
							<label for="anSolNombre" class="form-label small">Nombre <span class="text-danger">*</span></label>
							<input type="text" class="form-control form-control-sm mb-2" id="anSolNombre" maxlength="100" />
							<div class="row g-2">
								<div class="col-5"><label for="anSolTipo" class="form-label small">Documento</label>
									<select class="form-select form-select-sm an-tipodoc" id="anSolTipo"></select></div>
								<div class="col-7"><label for="anSolNum" class="form-label small">Número <span class="text-danger">*</span></label>
									<input type="text" class="form-control form-control-sm" id="anSolNum" maxlength="20" /></div>
							</div>
						</div>
					</div>
				</div>
				<div class="modal-footer">
					<button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Cancelar</button>
					<button type="submit" class="btn btn-danger" id="anConfirmar"><i class="bx bx-block"></i> Anular documento</button>
				</div>
			</form>
		</div>
	</div>
</div>

<!-- Plazos (administradores) -->
<div class="modal fade" id="anModalPlazos" tabindex="-1" aria-labelledby="anPlazosTitulo" aria-hidden="true">
	<div class="modal-dialog">
		<div class="modal-content">
			<div class="modal-header">
				<h5 class="modal-title" id="anPlazosTitulo">Plazos de anulación</h5>
				<button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
			</div>
			<div class="modal-body">
				<p class="small text-muted">Días desde la emisión en que Hacienda permite invalidar cada tipo de documento. Actualícelos si cambia el Manual Funcional del sistema de transmisión.</p>
				<div id="anPlazosLista"></div>
			</div>
		</div>
	</div>
</div>

<script src="assets/js/anulaciones.js?v=1"></script>
