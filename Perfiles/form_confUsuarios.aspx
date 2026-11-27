<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="form_confUsuarios.aspx.cs" Inherits="DPieCenter.Perfiles.form_confUsuarios" %>

<link href="assets/css/administracion.css?v=1" rel="stylesheet" />

<div class="page-breadcrumb d-flex flex-wrap align-items-center gap-2 mb-3">
	<div class="breadcrumb-title pe-3">Opciones</div>
	<div class="ps-3 d-none d-sm-block">
		<nav aria-label="breadcrumb"><ol class="breadcrumb mb-0 p-0">
			<li class="breadcrumb-item"><a href="javascript:;"><i class="bx bx-user-circle"></i></a></li>
			<li class="breadcrumb-item active" aria-current="page">Usuarios del sistema</li>
		</ol></nav>
	</div>
	<div class="ms-auto">
		<button type="button" class="btn btn-primary" id="usNuevo"><i class="bx bx-user-plus"></i> Nuevo usuario</button>
	</div>
</div>

<div id="usuarios" data-usuario="<%: Request.QueryString["user"] %>" data-nuevo="<%: Request.QueryString["nuevo"] %>">
	<div class="row row-cols-2 row-cols-lg-4 g-3 mb-3">
		<div class="col"><div class="card radius-10 mb-0"><div class="card-body"><span class="ad-ayuda">Usuarios activos</span><h4 class="mb-0 ad-titulo" id="usActivos">—</h4></div></div></div>
		<div class="col"><div class="card radius-10 mb-0"><div class="card-body"><span class="ad-ayuda">Inactivos</span><h4 class="mb-0 text-muted" id="usInactivos">—</h4></div></div></div>
		<div class="col"><div class="card radius-10 mb-0"><div class="card-body"><span class="ad-ayuda">Ingresaron hoy</span><h4 class="mb-0 ad-titulo" id="usHoy">—</h4></div></div></div>
		<div class="col"><div class="card radius-10 mb-0"><div class="card-body"><span class="ad-ayuda">Sin ingresar en 30 días</span><h4 class="mb-0 text-warning" id="us30">—</h4></div></div></div>
	</div>

	<div class="card radius-10">
		<div class="card-body">
			<div class="row g-2 mb-3">
				<div class="col-md-5"><input type="search" class="form-control form-control-sm" id="usBuscar" placeholder="Buscar por nombre, usuario o correo" aria-label="Buscar" /></div>
				<div class="col-6 col-md-3"><select class="form-select form-select-sm" id="usFiltroGrupo" aria-label="Grupo"><option value="">Todos los grupos</option></select></div>
				<div class="col-6 col-md-2">
					<select class="form-select form-select-sm" id="usFiltroEstado" aria-label="Estado">
						<option value="">Todos</option><option value="A" selected>Activos</option><option value="I">Inactivos</option>
					</select>
				</div>
				<div class="col-md-2 text-md-end small text-muted align-self-center" id="usConteo"></div>
			</div>
			<div class="table-responsive">
				<table class="table table-hover mb-0 ad-tabla">
					<thead class="table-light">
						<tr><th>Usuario</th><th>Grupo</th><th class="d-none d-lg-table-cell">Dashboard</th><th class="d-none d-md-table-cell">Último ingreso</th><th class="text-center">Estado</th><th><span class="visually-hidden">Acciones</span></th></tr>
					</thead>
					<tbody id="usFilas"></tbody>
				</table>
			</div>
		</div>
	</div>
</div>

<div class="modal fade" id="usModal" tabindex="-1" aria-labelledby="usModalTitulo" aria-hidden="true">
	<div class="modal-dialog modal-lg">
		<div class="modal-content">
			<form id="usForm" novalidate autocomplete="off">
				<div class="modal-header">
					<h5 class="modal-title" id="usModalTitulo">Nuevo usuario</h5>
					<button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
				</div>
				<div class="modal-body">
					<div class="row g-3">
						<div class="col-md-4">
							<label for="usId" class="form-label">Usuario <span class="text-danger">*</span></label>
							<input type="text" class="form-control" id="usId" maxlength="20" placeholder="jperez" required />
							<div class="form-text" id="usIdAyuda">Con este código inicia sesión. Al crearlo se genera una clave temporal que el usuario cambia al entrar.</div>
						</div>
						<div class="col-md-4">
							<label for="usNombres" class="form-label">Nombres <span class="text-danger">*</span></label>
							<input type="text" class="form-control" id="usNombres" maxlength="200" required />
						</div>
						<div class="col-md-4">
							<label for="usApellidos" class="form-label">Apellidos <span class="text-danger">*</span></label>
							<input type="text" class="form-control" id="usApellidos" maxlength="200" required />
						</div>
						<div class="col-md-4">
							<label for="usGrupo" class="form-label">Grupo <span class="text-danger">*</span></label>
							<select class="form-select" id="usGrupo" required></select>
						</div>
						<div class="col-md-4">
							<label for="usSucursal" class="form-label">Sucursal <span class="text-danger">*</span></label>
							<select class="form-select" id="usSucursal" required></select>
						</div>
						<div class="col-md-4">
							<label for="usDashboard" class="form-label">Dashboard al entrar</label>
							<select class="form-select" id="usDashboard"></select>
						</div>
						<div class="col-md-4">
							<label for="usCaducidad" class="form-label">Vigencia de la clave (días) <span class="text-danger">*</span></label>
							<input type="number" class="form-control" id="usCaducidad" min="1" max="999999" required />
						</div>
						<div class="col-md-4">
							<label for="usEmail" class="form-label">Correo electrónico</label>
							<input type="email" class="form-control" id="usEmail" maxlength="100" />
						</div>
						<div class="col-6 col-md-4">
							<label for="usTelefono" class="form-label">Teléfono</label>
							<input type="tel" class="form-control" id="usTelefono" maxlength="20" />
						</div>
						<div class="col-6 col-md-4">
							<label for="usCelular" class="form-label">Celular</label>
							<input type="tel" class="form-control" id="usCelular" maxlength="20" />
						</div>
						<div class="col-md-4">
							<label for="usDocumento" class="form-label">Documento (DUI o NIT)</label>
							<input type="text" class="form-control" id="usDocumento" maxlength="17" inputmode="numeric" placeholder="00000000-0" />
							<div class="form-text">Aparece como responsable del emisor en las facturas que emite.</div>
						</div>
						<div class="col-12">
							<div class="form-check form-switch">
								<input class="form-check-input" type="checkbox" role="switch" id="usResponsable" />
								<label class="form-check-label" for="usResponsable">Es responsable (supervisor)</label>
							</div>
						</div>
						<div class="col-12 small text-muted d-none" id="usInfo"></div>
					</div>
				</div>
				<div class="modal-footer">
					<button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Cancelar</button>
					<button type="submit" class="btn btn-primary" id="usGuardar"><i class="bx bx-save"></i> Guardar</button>
				</div>
			</form>
		</div>
	</div>
</div>

<script src="assets/js/administracion.js?v=2"></script>
<script src="assets/js/conf-usuarios.js?v=4"></script>
