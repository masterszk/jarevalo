<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="frm_DiagnosticoDte.aspx.cs" Inherits="DPieCenter.Facturacion.frm_DiagnosticoDte" %>

<link href="assets/css/administracion.css?v=2" rel="stylesheet" />

<div class="page-breadcrumb d-flex flex-wrap align-items-center gap-2 mb-3">
	<div class="breadcrumb-title pe-3">Facturación</div>
	<div class="ps-3 d-none d-sm-block">
		<nav aria-label="breadcrumb"><ol class="breadcrumb mb-0 p-0">
			<li class="breadcrumb-item"><a href="javascript:;"><i class="bx bx-first-aid"></i></a></li>
			<li class="breadcrumb-item active" aria-current="page">Diagnóstico DTE</li>
		</ol></nav>
	</div>
	<div class="ms-auto"><button type="button" class="btn btn-outline-primary" id="dgRevisar"><i class="bx bx-refresh"></i> Revisar de nuevo</button></div>
</div>

<div class="alert alert-light border small" id="dgServidor">Revisando el servidor…</div>

<div class="card radius-10">
	<div class="card-body">
		<h6 class="ad-titulo mb-3">Revisión</h6>
		<div class="table-responsive">
			<table class="table align-middle mb-0 ad-tabla">
				<thead class="table-light"><tr><th style="width:36px"></th><th>Qué se revisa</th><th>Resultado</th></tr></thead>
				<tbody id="dgRevisiones"></tbody>
			</table>
		</div>
	</div>
</div>

<div class="card radius-10">
	<div class="card-body">
		<h6 class="ad-titulo mb-2">Probar el correo</h6>
		<p class="ad-ayuda">Envía un correo de prueba con la configuración guardada, desde este servidor.</p>
		<div class="input-group" style="max-width:520px">
			<input type="email" class="form-control" id="dgCorreo" placeholder="correo@ejemplo.com" aria-label="Correo para la prueba" />
			<button type="button" class="btn btn-primary" id="dgProbar"><i class="bx bx-send"></i> Enviar prueba</button>
		</div>
		<div class="mt-2 small" id="dgResultadoCorreo"></div>
	</div>
</div>

<div class="card radius-10">
	<div class="card-body">
		<h6 class="ad-titulo mb-2">Documentos sin archivos o sin correo <span class="text-muted fw-normal small">(últimos 90 días)</span></h6>
		<div class="table-responsive">
			<table class="table table-sm align-middle mb-0 ad-tabla">
				<thead class="table-light"><tr><th>Emisión</th><th>Documento</th><th>Cliente</th><th>Archivos</th><th>Correo</th><th class="d-none d-lg-table-cell">Último error</th><th></th></tr></thead>
				<tbody id="dgPendientes"></tbody>
			</table>
		</div>
	</div>
</div>

<div class="card radius-10">
	<div class="card-body">
		<h6 class="ad-titulo mb-2">Últimos eventos</h6>
		<div class="table-responsive">
			<table class="table table-sm align-middle mb-0 ad-tabla">
				<thead class="table-light"><tr><th>Fecha</th><th>Etapa</th><th>Documento</th><th>Resultado</th><th class="d-none d-md-table-cell">Usuario / servidor</th></tr></thead>
				<tbody id="dgEventos"></tbody>
			</table>
		</div>
	</div>
</div>

<script src="assets/js/diagnostico-dte.js?v=2"></script>
