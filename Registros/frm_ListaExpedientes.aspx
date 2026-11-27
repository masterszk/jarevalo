<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="frm_ListaExpedientes.aspx.cs" Inherits="DPieCenter.Registros.frm_ListaExpedientes" %>

<link href="assets/css/expedientes.css?v=2" rel="stylesheet" />

<!--breadcrumb-->
<div class="page-breadcrumb d-flex flex-wrap align-items-center gap-2 mb-3">
	<div class="breadcrumb-title pe-3">Registros</div>
	<div class="ps-3 d-none d-sm-block">
		<nav aria-label="breadcrumb">
			<ol class="breadcrumb mb-0 p-0">
				<li class="breadcrumb-item"><a href="javascript:;"><i class="bx bx-folder-open"></i></a></li>
				<li class="breadcrumb-item active" aria-current="page">Expedientes</li>
			</ol>
		</nav>
	</div>
	<div class="ms-auto">
		<button type="button" class="btn btn-primary" id="exNuevo"><i class="bx bx-user-plus"></i> Nuevo expediente</button>
	</div>
</div>

<div class="expedientes" id="expedientes">
	<!-- Indicadores -->
	<div class="row row-cols-2 row-cols-lg-4 g-3 mb-3">
		<div class="col"><div class="card radius-10 mb-0 ex-kpi"><div class="card-body"><span>Pacientes</span><strong id="exTotal">—</strong></div></div></div>
		<div class="col"><div class="card radius-10 mb-0 ex-kpi"><div class="card-body"><span>Nuevos este mes</span><strong id="exNuevosMes">—</strong></div></div></div>
		<div class="col"><div class="card radius-10 mb-0 ex-kpi"><div class="card-body"><span>Con cita hoy</span><strong id="exCitaHoy">—</strong></div></div></div>
		<div class="col"><div class="card radius-10 mb-0 ex-kpi"><div class="card-body"><span>Atendidos en 90 días</span><strong id="exActivos">—</strong></div></div></div>
	</div>

	<div class="card radius-10">
		<div class="card-body">
			<div class="row g-2 align-items-center mb-2">
				<div class="col-lg-6">
					<label for="exBuscar" class="visually-hidden">Buscar paciente</label>
					<div class="input-group">
						<span class="input-group-text"><i class="bx bx-search"></i></span>
						<input type="search" class="form-control" id="exBuscar" autocomplete="off"
							placeholder="Buscar por nombre, apellido, documento, celular o email" />
					</div>
				</div>
				<div class="col-lg-6 text-lg-end small text-muted" id="exResultado" aria-live="polite"></div>
			</div>

			<div class="ex-letras mb-3" id="exLetras" role="group" aria-label="Filtrar por inicial del apellido"></div>

			<div class="table-responsive">
				<table class="table table-hover align-middle mb-0 ex-tabla">
					<thead class="table-light">
						<tr>
							<th>Paciente</th>
							<th class="d-none d-md-table-cell">Contacto</th>
							<th class="d-none d-lg-table-cell">Edad</th>
							<th class="d-none d-lg-table-cell">Última visita</th>
							<th class="d-none d-md-table-cell">Próxima cita</th>
							<th class="text-end" style="width:150px;">Acciones</th>
						</tr>
					</thead>
					<tbody id="exFilas"></tbody>
				</table>
			</div>

			<nav class="d-flex flex-wrap justify-content-between align-items-center gap-2 mt-3" aria-label="Paginación">
				<span class="small text-muted" id="exPaginaTexto"></span>
				<ul class="pagination pagination-sm mb-0" id="exPaginas"></ul>
			</nav>
		</div>
	</div>
</div>

<!-- Nuevo expediente -->
<div class="modal fade" id="modalExpediente" tabindex="-1" aria-labelledby="exModalTitulo" aria-hidden="true">
	<div class="modal-dialog modal-lg modal-dialog-scrollable">
		<div class="modal-content">
			<div class="modal-header">
				<h5 class="modal-title" id="exModalTitulo">Nuevo expediente</h5>
				<button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
			</div>
			<div class="modal-body">
				<form class="row g-3" id="exForm" novalidate autocomplete="off">
					<div class="col-12"><h6 class="ex-seccion">Datos personales</h6></div>
					<div class="col-md-6">
						<label for="nombres" class="form-label">Nombres <span class="text-danger">*</span></label>
						<input type="text" class="form-control" id="nombres" maxlength="200" required>
					</div>
					<div class="col-md-6">
						<label for="apellidos" class="form-label">Apellidos <span class="text-danger">*</span></label>
						<input type="text" class="form-control" id="apellidos" maxlength="200" required>
					</div>
					<div class="col-md-4">
						<label for="tipodoc" class="form-label">Tipo de documento <span class="text-danger">*</span></label>
						<select class="form-select" id="tipodoc" required>
							<option value="-1">--Seleccione una opción--</option>
						</select>
					</div>
					<div class="col-md-4">
						<label for="documento" class="form-label">Documento <span class="text-danger" id="docRequerido">*</span></label>
						<input type="text" class="form-control" id="documento" maxlength="20">
						<div class="form-text" id="docAyuda"></div>
					</div>
					<div class="col-md-4">
						<label for="registro" class="form-label">NRC</label>
						<input type="text" class="form-control" id="registro" maxlength="50">
					</div>
					<div class="col-md-4">
						<label for="nacimiento" class="form-label">Fecha de nacimiento <span class="text-danger">*</span></label>
						<input type="date" class="form-control" id="nacimiento" required>
						<div class="form-text" id="edadAyuda"></div>
					</div>
					<div class="col-md-4">
						<label for="sexo" class="form-label">Sexo <span class="text-danger">*</span></label>
						<select class="form-select" id="sexo" required>
							<option value="-1">--Seleccione una opción--</option>
						</select>
					</div>
					<div class="col-md-4">
						<label for="nacionalidad" class="form-label">Nacionalidad <span class="text-danger">*</span></label>
						<select class="form-select" id="nacionalidad" required></select>
					</div>

					<div class="col-12"><h6 class="ex-seccion">Contacto</h6></div>
					<div class="col-md-4">
						<label for="paisTel" class="form-label">País de los teléfonos</label>
						<select class="form-select" id="paisTel"></select>
						<div class="form-text" id="telAyuda"></div>
					</div>
					<div class="col-md-4">
						<label for="celular" class="form-label">Celular <span class="text-danger">*</span></label>
						<div class="input-group"><span class="input-group-text ex-prefijo">+503</span><input type="tel" class="form-control" maxlength="20" inputmode="tel" id="celular" required></div>
					</div>
					<div class="col-md-4">
						<label for="telefono" class="form-label">Teléfono</label>
						<div class="input-group"><span class="input-group-text ex-prefijo">+503</span><input type="tel" class="form-control" maxlength="20" inputmode="tel" id="telefono"></div>
					</div>
					<div class="col-md-4">
						<label for="email" class="form-label">Email <span class="text-danger">*</span></label>
						<input type="email" class="form-control" id="email" maxlength="100" required>
					</div>
					<div class="col-md-4">
						<label for="emerNombre" class="form-label">Contacto de emergencia <span class="text-danger">*</span></label>
						<input type="text" class="form-control" id="emerNombre" maxlength="500" required>
					</div>
					<div class="col-md-4">
						<label for="emerTelefono" class="form-label">Tel. emergencia <span class="text-danger">*</span></label>
						<div class="input-group"><span class="input-group-text ex-prefijo">+503</span><input type="tel" class="form-control" maxlength="20" inputmode="tel" id="emerTelefono" required></div>
					</div>

					<div class="col-12"><h6 class="ex-seccion">Dirección</h6></div>
					<div class="col-md-6">
						<label for="departamento" class="form-label">Departamento <span class="text-danger">*</span></label>
						<select class="form-select" id="departamento">
							<option value="-1">--Seleccione una opción--</option>
						</select>
					</div>
					<div class="col-md-6">
						<label for="municipio" class="form-label">Municipio <span class="text-danger">*</span></label>
						<select class="form-select" id="municipio" required>
							<option value="-1">--Seleccione una opción--</option>
						</select>
					</div>
					<div class="col-12">
						<label for="direccion" class="form-label">Dirección <span class="text-danger">*</span></label>
						<input type="text" class="form-control" id="direccion" maxlength="500" required>
					</div>

					<div class="col-12"><h6 class="ex-seccion">¿Cómo nos conoció?</h6></div>
					<div class="col-12 d-flex flex-wrap gap-4">
						<div class="form-check"><input class="form-check-input" type="checkbox" id="facebook"><label class="form-check-label" for="facebook">Facebook</label></div>
						<div class="form-check"><input class="form-check-input" type="checkbox" id="instagram"><label class="form-check-label" for="instagram">Instagram</label></div>
						<div class="form-check"><input class="form-check-input" type="checkbox" id="tiktok"><label class="form-check-label" for="tiktok">TikTok</label></div>
						<div class="form-check"><input class="form-check-input" type="checkbox" id="whatsapp"><label class="form-check-label" for="whatsapp">WhatsApp</label></div>
						<div class="form-check"><input class="form-check-input" type="checkbox" id="buscador"><label class="form-check-label" for="buscador">Buscador web</label></div>
						<div class="form-check"><input class="form-check-input" type="checkbox" id="recomendado"><label class="form-check-label" for="recomendado">Recomendado</label></div>
						<div class="form-check"><input class="form-check-input" type="checkbox" id="otros"><label class="form-check-label" for="otros">Otros</label></div>
					</div>
				</form>
			</div>
			<div class="modal-footer">
				<button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancelar</button>
				<button type="button" class="btn btn-primary" id="btnSave"><i class="bx bx-save"></i> Guardar</button>
			</div>
		</div>
	</div>
</div>

<!-- Reclamo -->
<div class="modal fade" id="modalReclamos" tabindex="-1" aria-labelledby="exReclamoTitulo" aria-hidden="true">
	<div class="modal-dialog">
		<div class="modal-content">
			<div class="modal-header">
				<h5 class="modal-title" id="exReclamoTitulo">Registrar Garantía de Servicios</h5>
				<button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
			</div>
			<div class="modal-body">
				<p class="mb-3"><i class="bx bx-user"></i> <strong id="reclamoPaciente"></strong></p>
				<label for="procedimiento02" class="form-label">Procedimiento <span class="text-danger">*</span></label>
				<select class="form-select" id="procedimiento02"></select>
				<div class="form-text mb-3" id="reclamoEspecialista"></div>
				<label for="reclamo" class="form-label">Garantía de Servicios <span class="text-danger">*</span></label>
				<textarea rows="6" id="reclamo" class="form-control" maxlength="2500"></textarea>
				<div class="form-text text-end"><span id="reclamoCuenta">0</span> / 2500</div>
			</div>
			<div class="modal-footer">
				<button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancelar</button>
				<button type="button" class="btn btn-primary" id="btnReclamo"><i class="bx bx-check"></i> Guardar</button>
			</div>
		</div>
	</div>
</div>

<script src="assets/js/expediente-form.js?v=5"></script>
<script src="assets/js/expedientes.js?v=5"></script>
