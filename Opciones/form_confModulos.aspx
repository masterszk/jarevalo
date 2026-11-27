<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="form_confModulos.aspx.cs" Inherits="DPieCenter.Opciones.form_confModulos" %>

<link href="assets/css/administracion.css?v=1" rel="stylesheet" />

<div class="page-breadcrumb d-flex flex-wrap align-items-center gap-2 mb-3">
	<div class="breadcrumb-title pe-3">Opciones</div>
	<div class="ps-3 d-none d-sm-block">
		<nav aria-label="breadcrumb"><ol class="breadcrumb mb-0 p-0">
			<li class="breadcrumb-item"><a href="javascript:;"><i class="bx bx-atom"></i></a></li>
			<li class="breadcrumb-item active" aria-current="page">Módulos y opciones del menú</li>
		</ol></nav>
	</div>
	<div class="ms-auto">
		<button type="button" class="btn btn-primary" id="mdNuevoModulo"><i class="bx bx-plus"></i> Nuevo módulo</button>
	</div>
</div>

<div class="alert alert-light border small mb-3">
	<i class="bx bx-info-circle"></i> Cada <strong>módulo</strong> es un grupo del menú lateral y sus <strong>opciones</strong> son las páginas que contiene.
	Para que un grupo de usuarios vea una opción, asígnela en <a href="javascript:;" onclick="AjaxLink('Opciones/form_confAccesosObjetos.aspx')">Permisos</a>.
	Los cambios del menú se ven al recargar la página.
</div>

<div class="row g-3" id="modulos" data-mod="<%: Request.QueryString["mod"] %>">
	<div class="col-lg-5">
		<div class="card radius-10 h-100 mb-0">
			<div class="card-body">
				<h6 class="ad-titulo mb-3">Módulos <span class="text-muted fw-normal small" id="mdTotal"></span></h6>
				<div class="list-group list-group-flush" id="mdLista"></div>
			</div>
		</div>
	</div>
	<div class="col-lg-7">
		<div class="card radius-10 h-100 mb-0">
			<div class="card-body">
				<div class="d-flex flex-wrap align-items-center gap-2 mb-3">
					<span class="ad-icono" id="opIcono"><i class="bx bx-menu"></i></span>
					<div class="me-auto">
						<h6 class="ad-titulo mb-0" id="opTitulo">Opciones</h6>
						<div class="ad-ayuda" id="opSub">Elija un módulo</div>
					</div>
					<button type="button" class="btn btn-sm btn-primary" id="opNueva" disabled><i class="bx bx-plus"></i> Nueva opción</button>
				</div>
				<div class="table-responsive">
					<table class="table table-sm table-hover mb-0 ad-tabla">
						<thead class="table-light">
							<tr><th style="width:60px">Orden</th><th>Opción</th><th class="d-none d-md-table-cell">Página</th><th class="text-center">Grupos</th><th><span class="visually-hidden">Acciones</span></th></tr>
						</thead>
						<tbody id="opFilas"></tbody>
					</table>
				</div>
			</div>
		</div>
	</div>
</div>

<!-- Módulo -->
<div class="modal fade" id="mdModal" tabindex="-1" aria-labelledby="mdModalTitulo" aria-hidden="true">
	<div class="modal-dialog modal-lg">
		<div class="modal-content">
			<form id="mdForm" novalidate autocomplete="off">
				<div class="modal-header">
					<h5 class="modal-title" id="mdModalTitulo">Nuevo módulo</h5>
					<button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
				</div>
				<div class="modal-body">
					<div class="row g-3">
						<div class="col-md-8">
							<label for="mdDescripcion" class="form-label">Nombre <span class="text-danger">*</span></label>
							<input type="text" class="form-control" id="mdDescripcion" maxlength="22" required />
						</div>
						<div class="col-md-4">
							<label for="mdOrden" class="form-label">Orden en el menú <span class="text-danger">*</span></label>
							<input type="number" class="form-control" id="mdOrden" min="1" max="999" required />
						</div>
						<div class="col-12">
							<label for="mdBuscarIcono" class="form-label">Icono <span class="text-danger">*</span></label>
							<div class="d-flex align-items-center gap-2 mb-2">
								<span class="ad-icono" id="mdIconoVista"><i class="bx bx-question-mark"></i></span>
								<input type="hidden" id="mdIcono" />
								<input type="search" class="form-control form-control-sm" id="mdBuscarIcono" placeholder="Buscar icono (por ejemplo: user, calendar, dollar)" />
							</div>
							<div class="ad-iconos" id="mdIconos" role="listbox" aria-label="Iconos"></div>
							<div class="invalid-feedback d-block" id="mdIconoError"></div>
						</div>
					</div>
				</div>
				<div class="modal-footer">
					<button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Cancelar</button>
					<button type="submit" class="btn btn-primary" id="mdGuardar"><i class="bx bx-save"></i> Guardar</button>
				</div>
			</form>
		</div>
	</div>
</div>

<!-- Opción -->
<div class="modal fade" id="opModal" tabindex="-1" aria-labelledby="opModalTitulo" aria-hidden="true">
	<div class="modal-dialog">
		<div class="modal-content">
			<form id="opForm" novalidate autocomplete="off">
				<div class="modal-header">
					<h5 class="modal-title" id="opModalTitulo">Nueva opción</h5>
					<button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
				</div>
				<div class="modal-body">
					<div class="row g-3">
						<div class="col-12">
							<label for="opDescripcion" class="form-label">Nombre en el menú <span class="text-danger">*</span></label>
							<input type="text" class="form-control" id="opDescripcion" maxlength="60" required />
						</div>
						<div class="col-12">
							<label for="opUrl" class="form-label">Página <span class="text-danger">*</span></label>
							<input type="text" class="form-control" id="opUrl" maxlength="200" placeholder="Registros/frm_Pagina.aspx" required />
							<div class="form-text">Carpeta y nombre del webform, como aparece en el proyecto.</div>
						</div>
						<div class="col-sm-4">
							<label for="opOrden" class="form-label">Orden <span class="text-danger">*</span></label>
							<input type="number" class="form-control" id="opOrden" min="1" max="999" required />
						</div>
						<div class="col-sm-3">
							<label for="opAbreviado" class="form-label">Siglas</label>
							<input type="text" class="form-control text-uppercase" id="opAbreviado" maxlength="10" />
						</div>
						<div class="col-sm-5">
							<label for="opModulo" class="form-label">Módulo</label>
							<select class="form-select" id="opModulo"></select>
						</div>
					</div>
				</div>
				<div class="modal-footer">
					<button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Cancelar</button>
					<button type="submit" class="btn btn-primary" id="opGuardar"><i class="bx bx-save"></i> Guardar</button>
				</div>
			</form>
		</div>
	</div>
</div>

<script src="assets/js/iconos-boxicons.js?v=1"></script>
<script src="assets/js/administracion.js?v=2"></script>
<script src="assets/js/conf-modulos.js?v=1"></script>
