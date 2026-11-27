<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="frm_Publicidad.aspx.cs" Inherits="DPieCenter.Opciones.frm_Publicidad" %>

<link href="assets/css/administracion.css?v=2" rel="stylesheet" />
<link href="assets/css/publicidad.css?v=1" rel="stylesheet" />

<div class="page-breadcrumb d-flex flex-wrap align-items-center gap-2 mb-3">
	<div class="breadcrumb-title pe-3">Opciones</div>
	<div class="ps-3 d-none d-sm-block">
		<nav aria-label="breadcrumb"><ol class="breadcrumb mb-0 p-0">
			<li class="breadcrumb-item"><a href="javascript:;"><i class="bx bx-movie-play"></i></a></li>
			<li class="breadcrumb-item active" aria-current="page">Videos de turnos</li>
		</ol></nav>
	</div>
	<div class="ms-auto">
		<a class="btn btn-sm btn-outline-secondary" href="Registros/frm_TurnosPacientes.aspx" target="_blank" rel="noopener"><i class="bx bx-tv"></i> Abrir pantalla de turnos</a>
	</div>
</div>

<div class="alert alert-light border small d-flex gap-2">
	<i class="bx bx-info-circle fs-5"></i>
	<div>
		Los videos se reproducen en bucle, en el orden de esta lista, en la parte izquierda de la pantalla de turnos.
		Los cambios llegan a la pantalla en unos 10 segundos, sin recargarla.
		Formatos: <strong>.mp4</strong> (H.264) o <strong>.webm</strong>, hasta <strong id="pbMax">300</strong> MB. Recomendado 1920×1080 o 1280×720, sin audio o con volumen bajo.
	</div>
</div>

<div class="row g-3">
	<div class="col-lg-4">
		<div class="card radius-10 h-100">
			<div class="card-body">
				<h6 class="mb-3">Agregar video</h6>
				<label class="pb-zona" id="pbZona" for="pbArchivo">
					<i class="bx bx-cloud-upload"></i>
					<span class="fw-semibold">Arrastre el video aquí</span>
					<span class="small text-muted">o haga clic para seleccionarlo</span>
					<input type="file" id="pbArchivo" accept="video/mp4,video/webm,.mp4,.webm" class="visually-hidden" />
				</label>
				<div class="pb-progreso d-none" id="pbProgreso" aria-live="polite">
					<div class="d-flex justify-content-between small mb-1"><span id="pbArchivoNombre" class="text-truncate me-2"></span><span id="pbPorcentaje">0%</span></div>
					<div class="progress" style="height:8px"><div class="progress-bar" id="pbBarra" role="progressbar" style="width:0%" aria-valuemin="0" aria-valuemax="100"></div></div>
					<button type="button" class="btn btn-sm btn-link text-danger px-0 mt-1" id="pbCancelar">Cancelar</button>
				</div>
			</div>
		</div>
	</div>
	<div class="col-lg-8">
		<div class="card radius-10 h-100">
			<div class="card-body">
				<div class="d-flex align-items-center mb-3">
					<h6 class="mb-0">Videos en la pantalla</h6>
					<span class="ms-auto small text-muted" id="pbConteo"></span>
				</div>
				<div id="pbLista" class="pb-lista" aria-live="polite"></div>
			</div>
		</div>
	</div>
</div>

<!-- Vista previa -->
<div class="modal fade" id="pbModalVer" tabindex="-1" aria-labelledby="pbModalVerTitulo" aria-hidden="true">
	<div class="modal-dialog modal-lg modal-dialog-centered">
		<div class="modal-content">
			<div class="modal-header">
				<h5 class="modal-title text-truncate" id="pbModalVerTitulo">Vista previa</h5>
				<button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
			</div>
			<div class="modal-body p-0 bg-black">
				<video id="pbVideoVer" class="w-100 d-block" controls playsinline preload="metadata"></video>
			</div>
		</div>
	</div>
</div>

<script src="assets/js/publicidad.js?v=2"></script>
