<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="frm_ListaCupones.aspx.cs" Inherits="DPieCenter.Registros.frm_ListaCupones" %>

<link href="assets/css/administracion.css?v=2" rel="stylesheet" />
<link href="assets/css/caja.css?v=1" rel="stylesheet" />

<div class="page-breadcrumb d-flex flex-wrap align-items-center gap-2 mb-3">
	<div class="breadcrumb-title pe-3">Registros</div>
	<div class="ps-3 d-none d-sm-block">
		<nav aria-label="breadcrumb"><ol class="breadcrumb mb-0 p-0">
			<li class="breadcrumb-item"><a href="javascript:;"><i class="bx bx-purchase-tag-alt"></i></a></li>
			<li class="breadcrumb-item active" aria-current="page">Cupones de descuento</li>
		</ol></nav>
	</div>
	<div class="ms-auto d-flex gap-2">
		<button type="button" class="btn btn-outline-secondary d-none" id="cpConfigBtn"><i class="bx bx-cog"></i> Configuración</button>
		<button type="button" class="btn btn-primary" id="cpNuevo"><i class="bx bx-plus"></i> Nuevo cupón</button>
	</div>
</div>

<div class="row row-cols-2 row-cols-lg-4 g-3 mb-3">
	<div class="col"><div class="card radius-10 mb-0 cj-kpi cj-kpi-ok"><div class="card-body"><span>Vigentes</span><strong id="cpKPend">—</strong><small>pendientes de usar</small></div></div></div>
	<div class="col"><div class="card radius-10 mb-0 cj-kpi"><div class="card-body"><span>Usados</span><strong id="cpKUsados">—</strong><small>aplicados en caja</small></div></div></div>
	<div class="col"><div class="card radius-10 mb-0 cj-kpi cj-kpi-pend"><div class="card-body"><span>Vencidos</span><strong id="cpKVencidos">—</strong><small>sin usar</small></div></div></div>
	<div class="col"><div class="card radius-10 mb-0 cj-kpi"><div class="card-body"><span>Descuento del mes</span><strong id="cpKMes">—</strong><small id="cpKConfig"></small></div></div></div>
</div>

<div class="card radius-10">
	<div class="card-body">
		<div class="row g-2 mb-3 align-items-center">
			<div class="col-md-5"><input type="search" class="form-control form-control-sm" id="cpBuscar" placeholder="Código, paciente, a quién se entregó o tratamiento" aria-label="Buscar" /></div>
			<div class="col-md">
				<div class="btn-group btn-group-sm flex-wrap" role="group" aria-label="Estado" id="cpEstados">
					<button type="button" class="btn btn-outline-secondary active" data-estado="P">Vigentes</button>
					<button type="button" class="btn btn-outline-secondary" data-estado="U">Usados</button>
					<button type="button" class="btn btn-outline-secondary" data-estado="V">Vencidos</button>
					<button type="button" class="btn btn-outline-secondary" data-estado="A">Anulados</button>
					<button type="button" class="btn btn-outline-secondary" data-estado="">Todos</button>
				</div>
			</div>
			<div class="col-md-auto small text-muted" id="cpConteo"></div>
		</div>
		<div class="table-responsive">
			<table class="table table-hover align-middle mb-0 ad-tabla">
				<thead class="table-light"><tr><th>Código</th><th>Para</th><th>Descuento</th><th class="d-none d-md-table-cell">Vence</th><th>Estado</th><th class="d-none d-lg-table-cell">Creado</th><th></th></tr></thead>
				<tbody id="cpFilas"></tbody>
			</table>
		</div>
		<nav class="d-flex flex-wrap justify-content-between align-items-center gap-2 mt-3" aria-label="Paginación">
			<span class="small text-muted" id="cpPaginaTexto"></span><ul class="pagination pagination-sm mb-0" id="cpPaginas"></ul>
		</nav>
	</div>
</div>

<!-- Nuevo cupón -->
<div class="modal fade" id="cpModal" tabindex="-1" aria-labelledby="cpModalTitulo" aria-hidden="true">
	<div class="modal-dialog">
		<div class="modal-content">
			<form id="cpForm" novalidate autocomplete="off">
				<div class="modal-header">
					<h5 class="modal-title" id="cpModalTitulo">Nuevo cupón de descuento</h5>
					<button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
				</div>
				<div class="modal-body">
					<div class="mb-3 position-relative">
						<label for="cpPaciente" class="form-label">Paciente</label>
						<input type="search" class="form-control" id="cpPaciente" placeholder="Buscar por nombre, documento o celular" />
						<div class="list-group position-absolute w-100 shadow-sm d-none" id="cpPacientes" style="z-index:10;max-height:220px;overflow:auto"></div>
						<div class="form-text" id="cpPacienteAyuda">Si elige un paciente, solo él podrá usar el cupón. Déjelo vacío para un cupón de promoción.</div>
					</div>
					<div class="mb-3">
						<label for="cpAsignado" class="form-label">Entregado a</label>
						<input type="text" class="form-control" id="cpAsignado" maxlength="150" placeholder="Nombre de la persona (obligatorio sin paciente)" />
					</div>
					<div class="mb-3">
						<label for="cpTratamiento" class="form-label">Aplica a</label>
						<select class="form-select" id="cpTratamiento"></select>
					</div>
					<div class="row g-3">
						<div class="col-6">
							<label for="cpPorcentaje" class="form-label">Descuento <span class="text-danger">*</span></label>
							<div class="input-group"><input type="number" class="form-control text-end" id="cpPorcentaje" min="1" step="0.5" /><span class="input-group-text">%</span></div>
							<div class="form-text" id="cpPorcentajeAyuda"></div>
						</div>
						<div class="col-6">
							<label for="cpVence" class="form-label">Válido hasta <span class="text-danger">*</span></label>
							<input type="date" class="form-control" id="cpVence" />
						</div>
					</div>
					<div class="mt-3">
						<label for="cpNota" class="form-label">Nota en el cupón</label>
						<input type="text" class="form-control" id="cpNota" maxlength="250" placeholder="Ejemplo: Promoción Día de la Madre" />
					</div>
					<div class="alert alert-light border small mt-3 mb-0" id="cpEjemplo"></div>
				</div>
				<div class="modal-footer">
					<button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Cancelar</button>
					<button type="submit" class="btn btn-primary" id="cpGuardar"><i class="bx bx-printer"></i> Crear e imprimir</button>
				</div>
			</form>
		</div>
	</div>
</div>

<!-- Configuración (administradores) -->
<div class="modal fade" id="cpModalConfig" tabindex="-1" aria-labelledby="cpConfigTitulo" aria-hidden="true">
	<div class="modal-dialog">
		<div class="modal-content">
			<form id="cpFormConfig" novalidate autocomplete="off">
				<div class="modal-header">
					<h5 class="modal-title" id="cpConfigTitulo">Configuración de cupones</h5>
					<button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
				</div>
				<div class="modal-body">
					<div class="row g-3">
						<div class="col-sm-4">
							<label for="cfPorcentaje" class="form-label">Descuento por defecto</label>
							<div class="input-group"><input type="number" class="form-control text-end" id="cfPorcentaje" min="1" max="100" step="0.5" /><span class="input-group-text">%</span></div>
						</div>
						<div class="col-sm-4">
							<label for="cfMaximo" class="form-label">Descuento máximo</label>
							<div class="input-group"><input type="number" class="form-control text-end" id="cfMaximo" min="1" max="100" step="0.5" /><span class="input-group-text">%</span></div>
						</div>
						<div class="col-sm-4">
							<label for="cfDias" class="form-label">Vigencia</label>
							<div class="input-group"><input type="number" class="form-control text-end" id="cfDias" min="1" max="730" /><span class="input-group-text">días</span></div>
						</div>
						<div class="col-12">
							<label for="cfLeyenda" class="form-label">Texto al pie del cupón</label>
							<textarea class="form-control" id="cfLeyenda" rows="2" maxlength="250"></textarea>
						</div>
					</div>
					<div class="small text-muted mt-2" id="cfModificado"></div>
				</div>
				<div class="modal-footer">
					<button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Cancelar</button>
					<button type="submit" class="btn btn-primary" id="cfGuardar"><i class="bx bx-save"></i> Guardar</button>
				</div>
			</form>
		</div>
	</div>
</div>

<script src="assets/js/cupones.js?v=1"></script>
