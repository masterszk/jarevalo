<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="form_confDashboardInicial.aspx.cs" Inherits="DPieCenter.Opciones.form_confDashboardInicial" %>

<link href="assets/css/administracion.css?v=1" rel="stylesheet" />

<div class="page-breadcrumb d-flex flex-wrap align-items-center gap-2 mb-3">
	<div class="breadcrumb-title pe-3">Opciones</div>
	<div class="ps-3 d-none d-sm-block">
		<nav aria-label="breadcrumb"><ol class="breadcrumb mb-0 p-0">
			<li class="breadcrumb-item"><a href="javascript:;"><i class="bx bx-home-circle"></i></a></li>
			<li class="breadcrumb-item active" aria-current="page">Dashboards de inicio</li>
		</ol></nav>
	</div>
	<div class="ms-auto">
		<button type="button" class="btn btn-primary" id="dbNuevo"><i class="bx bx-plus"></i> Nuevo dashboard</button>
	</div>
</div>

<div class="card radius-10">
	<div class="card-body">
		<p class="ad-ayuda mb-3"><i class="bx bx-info-circle"></i> Es la página que ve cada usuario al iniciar sesión. Se asigna a cada usuario en Usuarios.</p>
		<div class="table-responsive">
			<table class="table table-hover mb-0 ad-tabla">
				<thead class="table-light">
					<tr><th>#</th><th>Descripción</th><th>Página</th><th class="text-center">Usuarios</th><th class="text-center">Estado</th><th class="d-none d-lg-table-cell">Última modificación</th><th><span class="visually-hidden">Acciones</span></th></tr>
				</thead>
				<tbody id="dbFilas"></tbody>
			</table>
		</div>
	</div>
</div>

<div class="modal fade" id="dbModal" tabindex="-1" aria-labelledby="dbModalTitulo" aria-hidden="true">
	<div class="modal-dialog">
		<div class="modal-content">
			<form id="dbForm" novalidate autocomplete="off">
				<div class="modal-header">
					<h5 class="modal-title" id="dbModalTitulo">Nuevo dashboard</h5>
					<button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
				</div>
				<div class="modal-body">
					<div class="mb-3">
						<label for="dbDescripcion" class="form-label">Descripción <span class="text-danger">*</span></label>
						<input type="text" class="form-control" id="dbDescripcion" maxlength="50" required />
					</div>
					<div class="mb-3">
						<label for="dbUrl" class="form-label">Página <span class="text-danger">*</span></label>
						<input type="text" class="form-control" id="dbUrl" maxlength="150" list="dbPaginas" placeholder="Dashboard/pagina.aspx" required />
						<datalist id="dbPaginas"></datalist>
						<div class="form-text" id="dbPaginasAyuda"></div>
					</div>
					<div>
						<span class="form-label d-block">Estado</span>
						<div class="btn-group" role="group" aria-label="Estado">
							<input type="radio" class="btn-check" name="dbEstado" id="dbActivo" value="A" checked />
							<label class="btn btn-outline-success btn-sm" for="dbActivo">Activo</label>
							<input type="radio" class="btn-check" name="dbEstado" id="dbInactivo" value="I" />
							<label class="btn btn-outline-secondary btn-sm" for="dbInactivo">Inactivo</label>
						</div>
					</div>
				</div>
				<div class="modal-footer">
					<button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Cancelar</button>
					<button type="submit" class="btn btn-primary" id="dbGuardar"><i class="bx bx-save"></i> Guardar</button>
				</div>
			</form>
		</div>
	</div>
</div>

<script src="assets/js/administracion.js?v=2"></script>
<script src="assets/js/conf-dashboards.js?v=1"></script>
