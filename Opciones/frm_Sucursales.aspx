<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="frm_Sucursales.aspx.cs" Inherits="DPieCenter.Opciones.frm_Sucursales" %>

<link href="assets/css/administracion.css?v=2" rel="stylesheet" />

<div class="page-breadcrumb d-flex flex-wrap align-items-center gap-2 mb-3">
	<div class="breadcrumb-title pe-3">Opciones</div>
	<div class="ps-3 d-none d-sm-block">
		<nav aria-label="breadcrumb"><ol class="breadcrumb mb-0 p-0">
			<li class="breadcrumb-item"><a href="javascript:;"><i class="bx bx-store-alt"></i></a></li>
			<li class="breadcrumb-item active" aria-current="page">Sucursales</li>
		</ol></nav>
	</div>
	<div class="ms-auto">
		<button type="button" class="btn btn-primary" id="suNuevo"><i class="bx bx-plus"></i> Nueva sucursal</button>
	</div>
</div>

<div class="alert alert-light border small d-flex gap-2">
	<i class="bx bx-info-circle fs-5"></i>
	<div>
		Cada sucursal tiene su agenda, procedimientos, caja y correlativos de DTE. Los pacientes y los tratamientos se comparten.
		Cada usuario trabaja en la sucursal asignada en <strong>Opciones &rsaquo; Usuarios</strong>; los administradores pueden cambiarla en la barra superior.
	</div>
</div>

<div class="card radius-10">
	<div class="card-body">
		<div class="table-responsive">
			<table class="table table-hover align-middle mb-0">
				<thead class="table-light">
					<tr><th>Sucursal</th><th>Establecimiento DTE</th><th class="text-center">Usuarios</th><th class="text-center">Especialistas</th><th class="text-center">Citas</th><th>Estado</th><th>Modificado</th><th class="text-end"></th></tr>
				</thead>
				<tbody id="suFilas"><tr><td colspan="8" class="text-center text-muted py-4">Cargando…</td></tr></tbody>
			</table>
		</div>
	</div>
</div>

<div class="modal fade" id="suModal" tabindex="-1" aria-labelledby="suModalTitulo" aria-hidden="true">
	<div class="modal-dialog modal-lg modal-dialog-scrollable">
		<form class="modal-content" id="suForm" novalidate>
			<div class="modal-header">
				<h5 class="modal-title" id="suModalTitulo">Sucursal</h5>
				<button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
			</div>
			<div class="modal-body">
				<h6 class="ad-seccion">Datos</h6>
				<div class="row g-3">
					<div class="col-md-3">
						<label for="suCodigo" class="form-label">Código <span class="text-danger">*</span></label>
						<input type="text" class="form-control text-uppercase" id="suCodigo" maxlength="10" required />
					</div>
					<div class="col-md-6">
						<label for="suNombre" class="form-label">Nombre <span class="text-danger">*</span></label>
						<input type="text" class="form-control" id="suNombre" maxlength="100" required />
					</div>
					<div class="col-md-3">
						<label for="suTelefono" class="form-label">Teléfono</label>
						<input type="text" class="form-control" id="suTelefono" maxlength="20" inputmode="tel" />
					</div>
					<div class="col-md-4">
						<label for="suDepto" class="form-label">Departamento</label>
						<select class="form-select" id="suDepto"></select>
					</div>
					<div class="col-md-4">
						<label for="suMunicipio" class="form-label">Municipio</label>
						<select class="form-select" id="suMunicipio"></select>
					</div>
					<div class="col-md-4">
						<label for="suDistrito" class="form-label">Distrito</label>
						<select class="form-select" id="suDistrito"></select>
					</div>
					<div class="col-12">
						<label for="suDireccion" class="form-label">Dirección</label>
						<input type="text" class="form-control" id="suDireccion" maxlength="250" />
					</div>
				</div>

				<h6 class="ad-seccion mt-4">Establecimiento para el DTE</h6>
				<p class="small text-muted mb-2">Van en el número de control (DTE-01-<b>S001P001</b>-…) y en el JSON. Cada sucursal debe tener una combinación distinta.</p>
				<div class="alert alert-light border small py-2 d-none" id="suNotaMatriz">La Casa Matriz emite con los códigos de <strong>Opciones &rsaquo; Empresa &rsaquo; Facturación electrónica</strong>.</div>
				<div class="row g-3">
					<div class="col-6 col-md-3">
						<label for="suEstable" class="form-label">Establecimiento <span class="text-danger">*</span></label>
						<input type="text" class="form-control text-uppercase" id="suEstable" maxlength="4" placeholder="M001" required />
					</div>
					<div class="col-6 col-md-3">
						<label for="suPunto" class="form-label">Punto de venta <span class="text-danger">*</span></label>
						<input type="text" class="form-control text-uppercase" id="suPunto" maxlength="4" placeholder="P001" required />
					</div>
					<div class="col-6 col-md-3">
						<label for="suEstableMH" class="form-label">Establecimiento MH</label>
						<input type="text" class="form-control text-uppercase" id="suEstableMH" maxlength="4" />
					</div>
					<div class="col-6 col-md-3">
						<label for="suPuntoMH" class="form-label">Punto de venta MH</label>
						<input type="text" class="form-control text-uppercase" id="suPuntoMH" maxlength="4" />
					</div>
				</div>

				<h6 class="ad-seccion mt-4">Especialistas que atienden en esta sucursal</h6>
				<div class="row row-cols-1 row-cols-md-2 g-2" id="suEspecialistas"></div>

				<div class="form-check form-switch mt-4">
					<input class="form-check-input" type="checkbox" role="switch" id="suActivo" checked />
					<label class="form-check-label" for="suActivo">Activa</label>
				</div>
			</div>
			<div class="modal-footer">
				<button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Cancelar</button>
				<button type="submit" class="btn btn-primary" id="suGuardar"><i class="bx bx-save"></i> Guardar</button>
			</div>
		</form>
	</div>
</div>

<script src="assets/js/dte-catalogos.js?v=2"></script>
<script src="assets/js/sucursales.js?v=1"></script>
