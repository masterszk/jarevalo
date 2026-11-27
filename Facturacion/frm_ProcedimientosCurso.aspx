<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="frm_ProcedimientosCurso.aspx.cs" Inherits="DPieCenter.Facturacion.frm_ProcedimientosCurso" %>

<link href="assets/css/administracion.css?v=2" rel="stylesheet" />
<link href="assets/css/caja.css?v=1" rel="stylesheet" />

<div class="page-breadcrumb d-flex flex-wrap align-items-center gap-2 mb-3">
	<div class="breadcrumb-title pe-3">Facturación</div>
	<div class="ps-3 d-none d-sm-block">
		<nav aria-label="breadcrumb"><ol class="breadcrumb mb-0 p-0">
			<li class="breadcrumb-item"><a href="javascript:;"><i class="bx bx-plus-medical"></i></a></li>
			<li class="breadcrumb-item active" aria-current="page">Procedimientos en curso</li>
		</ol></nav>
	</div>
	<div class="ms-auto d-flex align-items-center gap-2">
		<span class="small text-muted" id="pcActualizado" aria-live="polite"></span>
		<button type="button" class="btn btn-sm btn-outline-secondary" id="pcRefrescar"><i class="bx bx-refresh"></i> Actualizar</button>
	</div>
</div>

<div class="alert alert-light border small d-flex gap-2">
	<i class="bx bx-info-circle fs-5"></i>
	<div>
		Pacientes en atención o en sala de espera de todos los especialistas, incluidos los que quedaron abiertos de días anteriores.
		Desde <strong>Acciones</strong> puede reprogramar, cambiar de especialista o cancelar. La atención la finaliza el especialista en Registros › Procedimientos.
	</div>
</div>

<div class="card radius-10">
	<div class="card-body">
		<div class="row g-2 mb-3 align-items-end">
			<div class="col-md-4">
				<label for="pcBuscar" class="form-label small mb-1">Buscar</label>
				<input type="search" class="form-control form-control-sm" id="pcBuscar" placeholder="Paciente, documento o tratamiento" />
			</div>
			<div class="col-6 col-md-3">
				<label for="pcEspecialista" class="form-label small mb-1">Especialista</label>
				<select class="form-select form-select-sm" id="pcEspecialista"><option value="">Todos</option></select>
			</div>
			<div class="col-6 col-md-3">
				<label for="pcEstado" class="form-label small mb-1">Estado</label>
				<select class="form-select form-select-sm" id="pcEstado">
					<option value="">En atención y en sala</option>
					<option value="I" selected>En atención</option>
					<option value="S">En sala de espera</option>
				</select>
			</div>
			<div class="col-md-2 text-md-end small text-muted" id="pcConteo"></div>
		</div>

		<div class="table-responsive">
			<table class="table table-hover align-middle mb-0">
				<thead class="table-light">
					<tr>
						<th>Paciente</th>
						<th>Especialista</th>
						<th>Cita</th>
						<th>Estado</th>
						<th>Tratamientos</th>
						<th class="text-end">Total</th>
						<th class="text-end">Acciones</th>
					</tr>
				</thead>
				<tbody id="pcFilas"></tbody>
			</table>
		</div>
	</div>
</div>

<!-- Reprogramar -->
<div class="modal fade" id="pcModalReprogramar" tabindex="-1" aria-labelledby="pcModalReprogramarTitulo" aria-hidden="true">
	<div class="modal-dialog">
		<div class="modal-content">
			<div class="modal-header">
				<h5 class="modal-title" id="pcModalReprogramarTitulo">Reprogramar cita</h5>
				<button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
			</div>
			<div class="modal-body">
				<p class="mb-2 fw-semibold" id="pcRepPaciente"></p>
				<label for="pcNuevaFecha" class="form-label">Nueva fecha y hora</label>
				<div class="input-group">
					<span class="input-group-text"><i class="bx bx-calendar"></i></span>
					<input type="text" class="form-control" id="pcNuevaFecha" placeholder="Seleccione fecha y hora" />
				</div>
				<small class="text-muted d-block mt-2">Se conserva la duración, el especialista y los tratamientos de la cita. Horario de atención: 08:00 AM a 06:00 PM.</small>
			</div>
			<div class="modal-footer">
				<button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cerrar</button>
				<button type="button" class="btn btn-primary" id="pcRepGuardar"><i class="bx bx-check"></i> Reprogramar</button>
			</div>
		</div>
	</div>
</div>

<!-- Cambiar especialista -->
<div class="modal fade" id="pcModalEspecialista" tabindex="-1" aria-labelledby="pcModalEspecialistaTitulo" aria-hidden="true">
	<div class="modal-dialog">
		<div class="modal-content">
			<div class="modal-header">
				<h5 class="modal-title" id="pcModalEspecialistaTitulo">Cambiar especialista</h5>
				<button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
			</div>
			<div class="modal-body">
				<p class="mb-2 fw-semibold" id="pcEspPaciente"></p>
				<label for="pcNuevoEspecialista" class="form-label">Nuevo especialista</label>
				<select class="form-select" id="pcNuevoEspecialista"></select>
			</div>
			<div class="modal-footer">
				<button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cerrar</button>
				<button type="button" class="btn btn-primary" id="pcEspGuardar"><i class="bx bx-check"></i> Guardar</button>
			</div>
		</div>
	</div>
</div>

<script src="assets/js/administracion.js?v=2"></script>
<script src="assets/js/procedimientos-curso.js?v=3"></script>
