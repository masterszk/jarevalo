<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="frm_EditExpediente.aspx.cs" Inherits="DPieCenter.Registros.frm_EditExpediente" %>

<link href="assets/css/expedientes.css?v=2" rel="stylesheet" />

<!--breadcrumb-->
<div class="page-breadcrumb d-flex flex-wrap align-items-center gap-2 mb-3">
	<div class="breadcrumb-title pe-3">
		<a href="javascript:;" id="fiVolver" title="Volver a expedientes" aria-label="Volver a expedientes"><i class="bx bx-arrow-back"></i></a>
		Expedientes
	</div>
	<div class="ps-3 d-none d-sm-block">
		<nav aria-label="breadcrumb">
			<ol class="breadcrumb mb-0 p-0">
				<li class="breadcrumb-item"><a href="javascript:;"><i class="bx bx-folder-open"></i></a></li>
				<li class="breadcrumb-item active" aria-current="page">Ficha del paciente</li>
			</ol>
		</nav>
	</div>
	<div class="ms-auto d-flex align-items-center gap-2">
		<span class="badge bg-warning text-dark d-none" id="fiSinGuardar"><i class="bx bx-edit"></i> Cambios sin guardar</span>
		<button type="button" class="btn btn-primary" id="fiGuardar" disabled><i class="bx bx-save"></i> Guardar cambios</button>
	</div>
</div>

<div class="row ficha" id="ficha" data-id="<%: Request.QueryString["id"] %>">
	<!-- Perfil -->
	<div class="col-xl-4">
		<div class="card radius-10">
			<div class="card-body text-center">
				<div class="fi-foto mx-auto">
					<img id="fiFoto" alt="Foto del paciente" class="d-none" />
					<div class="fi-iniciales" id="fiIniciales" aria-hidden="true"></div>
					<label class="fi-foto-cambiar" for="fiArchivo" title="Cambiar foto"><i class="bx bx-camera"></i><span class="visually-hidden">Cambiar foto</span></label>
					<input type="file" id="fiArchivo" accept="image/*" class="d-none" />
				</div>
				<button type="button" class="btn btn-link btn-sm text-danger d-none" id="fiQuitarFoto">Quitar foto</button>

				<h4 class="mt-2 mb-1" id="fiNombre">…</h4>
				<div class="text-muted small" id="fiDocumento"></div>
				<div class="d-flex justify-content-center flex-wrap gap-1 mt-2" id="fiEtiquetas"></div>

				<div class="d-flex justify-content-center gap-2 mt-3" id="fiContacto">
					<a class="btn btn-sm btn-outline-secondary" id="fiLlamar" href="#" title="Llamar"><i class="bx bx-phone"></i></a>
					<a class="btn btn-sm btn-outline-success" id="fiWhatsapp" href="#" target="_blank" rel="noopener" title="WhatsApp"><i class="bx bxl-whatsapp"></i></a>
					<a class="btn btn-sm btn-outline-primary" id="fiCorreo" href="#" title="Enviar correo"><i class="bx bx-envelope"></i></a>
				</div>
			</div>
			<ul class="list-group list-group-flush fi-datos">
				<li class="list-group-item"><span>Celular</span><strong id="fiCelular">—</strong></li>
				<li class="list-group-item"><span>Email</span><strong id="fiEmail" class="text-break">—</strong></li>
				<li class="list-group-item"><span>Emergencia</span><strong id="fiEmergencia">—</strong></li>
				<li class="list-group-item"><span>Ubicación</span><strong id="fiUbicacion">—</strong></li>
				<li class="list-group-item"><span>Última visita</span><strong id="fiUltima">—</strong></li>
				<li class="list-group-item"><span>Próxima cita</span><strong id="fiProxima">—</strong></li>
			</ul>
			<div class="card-footer small text-muted">
				<div>Registrado: <span id="fiCreado">—</span></div>
				<div id="fiModificadoFila">Última modificación: <span id="fiModificado">—</span></div>
			</div>
		</div>

		<div class="card radius-10">
			<div class="card-body">
				<h6 class="ex-seccion mb-3">Resumen</h6>
				<div class="row row-cols-3 g-2 text-center fi-resumen">
					<div class="col"><strong id="fiCitas">0</strong><span>Citas</span></div>
					<div class="col"><strong id="fiAtendidas" class="text-success">0</strong><span>Atendidas</span></div>
					<div class="col"><strong id="fiCanceladas" class="text-danger">0</strong><span>Canceladas</span></div>
					<div class="col"><strong id="fiProcedimientos">0</strong><span>Procedimientos</span></div>
					<div class="col"><strong id="fiReclamos" class="text-warning">0</strong><span>Garantía de Servicios</span></div>
				</div>
			</div>
		</div>
	</div>

	<!-- Datos e historial -->
	<div class="col-xl-8">
		<div class="card radius-10">
			<div class="card-body">
				<ul class="nav nav-tabs nav-primary" role="tablist">
					<li class="nav-item" role="presentation">
						<a class="nav-link active" data-bs-toggle="tab" href="#fiTabDatos" role="tab" aria-selected="true"><i class="bx bx-id-card me-1"></i>Datos personales</a>
					</li>
					<li class="nav-item" role="presentation">
						<a class="nav-link" data-bs-toggle="tab" href="#fiTabCitas" role="tab" aria-selected="false"><i class="bx bx-calendar me-1"></i>Citas <span class="badge bg-secondary ms-1" id="fiNumCitas">0</span></a>
					</li>
					<li class="nav-item" role="presentation">
						<a class="nav-link" data-bs-toggle="tab" href="#fiTabProc" role="tab" aria-selected="false"><i class="bx bx-plus-medical me-1"></i>Procedimientos <span class="badge bg-secondary ms-1" id="fiNumProc">0</span></a>
					</li>
					<li class="nav-item" role="presentation">
						<a class="nav-link" data-bs-toggle="tab" href="#fiTabReclamos" role="tab" aria-selected="false"><i class="bx bx-comment-error me-1"></i>Garantía de Servicios <span class="badge bg-secondary ms-1" id="fiNumReclamos">0</span></a>
					</li>
				</ul>

				<div class="tab-content pt-3">
					<!-- Datos personales -->
					<div class="tab-pane fade show active" id="fiTabDatos" role="tabpanel">
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

							<div class="col-12 d-flex justify-content-end gap-2 border-top pt-3">
								<button type="button" class="btn btn-outline-secondary" id="fiDescartar" disabled>Descartar cambios</button>
								<button type="button" class="btn btn-primary" id="fiGuardar2" disabled><i class="bx bx-save"></i> Guardar cambios</button>
							</div>
						</form>
					</div>

					<!-- Citas -->
					<div class="tab-pane fade" id="fiTabCitas" role="tabpanel">
						<div id="fiListaCitas"></div>
					</div>

					<!-- Procedimientos -->
					<div class="tab-pane fade" id="fiTabProc" role="tabpanel">
						<div class="accordion" id="fiListaProc"></div>
					</div>

					<!-- Reclamos -->
					<div class="tab-pane fade" id="fiTabReclamos" role="tabpanel">
						<div id="fiListaReclamos"></div>
					</div>
				</div>
			</div>
		</div>
	</div>
</div>

<script src="assets/js/expediente-form.js?v=5"></script>
<script src="assets/js/expediente-ficha.js?v=5"></script>
