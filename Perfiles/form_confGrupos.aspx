<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="form_confGrupos.aspx.cs" Inherits="DPieCenter.Perfiles.form_confGrupos" %>

<link href="assets/css/administracion.css?v=1" rel="stylesheet" />

<div class="page-breadcrumb d-flex flex-wrap align-items-center gap-2 mb-3">
	<div class="breadcrumb-title pe-3">Opciones</div>
	<div class="ps-3 d-none d-sm-block">
		<nav aria-label="breadcrumb"><ol class="breadcrumb mb-0 p-0">
			<li class="breadcrumb-item"><a href="javascript:;"><i class="bx bx-group"></i></a></li>
			<li class="breadcrumb-item active" aria-current="page">Grupos de usuarios</li>
		</ol></nav>
	</div>
	<div class="ms-auto">
		<button type="button" class="btn btn-primary" id="grNuevo"><i class="bx bx-plus"></i> Nuevo grupo</button>
	</div>
</div>

<div class="card radius-10">
	<div class="card-body">
		<p class="ad-ayuda mb-3"><i class="bx bx-info-circle"></i> El grupo define qué opciones del menú ve cada usuario. Las opciones de cada grupo se asignan en Permisos.</p>
		<div class="table-responsive">
			<table class="table table-hover mb-0 ad-tabla">
				<thead class="table-light">
					<tr><th>Código</th><th>Descripción</th><th class="text-center">Usuarios</th><th class="text-center">Opciones</th><th class="d-none d-lg-table-cell">Última modificación</th><th><span class="visually-hidden">Acciones</span></th></tr>
				</thead>
				<tbody id="grFilas"></tbody>
			</table>
		</div>
	</div>
</div>

<div class="modal fade" id="grModal" tabindex="-1" aria-labelledby="grModalTitulo" aria-hidden="true">
	<div class="modal-dialog">
		<div class="modal-content">
			<form id="grForm" novalidate autocomplete="off">
				<div class="modal-header">
					<h5 class="modal-title" id="grModalTitulo">Nuevo grupo</h5>
					<button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
				</div>
				<div class="modal-body">
					<div class="mb-3">
						<label for="grCodigo" class="form-label">Código <span class="text-danger">*</span></label>
						<input type="text" class="form-control" id="grCodigo" maxlength="20" placeholder="RECEPCION" required />
						<div class="form-text">Sin espacios: letras, números y guion bajo. No se puede cambiar después.</div>
					</div>
					<div>
						<label for="grDescripcion" class="form-label">Descripción <span class="text-danger">*</span></label>
						<input type="text" class="form-control" id="grDescripcion" maxlength="200" placeholder="Personal de recepción" required />
					</div>
				</div>
				<div class="modal-footer">
					<button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Cancelar</button>
					<button type="submit" class="btn btn-primary" id="grGuardar"><i class="bx bx-save"></i> Guardar</button>
				</div>
			</form>
		</div>
	</div>
</div>

<script src="assets/js/administracion.js?v=2"></script>
<script src="assets/js/conf-grupos.js?v=1"></script>
