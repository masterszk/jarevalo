<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="form_confAccesosObjetos.aspx.cs" Inherits="DPieCenter.Opciones.form_confAccesosObjetos" %>

<link href="assets/css/administracion.css?v=1" rel="stylesheet" />

<div class="page-breadcrumb d-flex flex-wrap align-items-center gap-2 mb-3">
	<div class="breadcrumb-title pe-3">Opciones</div>
	<div class="ps-3 d-none d-sm-block">
		<nav aria-label="breadcrumb"><ol class="breadcrumb mb-0 p-0">
			<li class="breadcrumb-item"><a href="javascript:;"><i class="bx bx-lock-open-alt"></i></a></li>
			<li class="breadcrumb-item active" aria-current="page">Permisos por grupo</li>
		</ol></nav>
	</div>
</div>

<div class="card radius-10" id="permisos" data-grupo="<%: Request.QueryString["grupo"] %>">
	<div class="card-body">
		<div class="d-flex flex-wrap align-items-center gap-2 mb-2">
			<h6 class="ad-titulo mb-0 me-2">Grupo</h6>
			<div class="d-flex flex-wrap gap-1 ad-grupos" id="peGrupos" role="tablist" aria-label="Grupos"></div>
		</div>
		<div class="d-flex flex-wrap align-items-center gap-2">
			<span class="ad-ayuda me-auto" id="peResumen"></span>
			<input type="search" class="form-control form-control-sm" id="peBuscar" placeholder="Buscar opción…" style="max-width:240px" />
		</div>
		<div class="ad-ayuda mt-2"><i class="bx bx-info-circle"></i> Los cambios se guardan al momento. Los usuarios del grupo los verán al recargar la página o al volver a iniciar sesión.</div>
	</div>
</div>

<div class="row g-3" id="peModulos"></div>

<script src="assets/js/administracion.js?v=2"></script>
<script src="assets/js/conf-permisos.js?v=1"></script>
