<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="frm_Inbound.aspx.cs" Inherits="DPieCenter.Registros.frm_Inbound" %>

<link href="assets/css/inbound.css?v=1" rel="stylesheet" />

<div class="page-breadcrumb d-flex flex-wrap align-items-center gap-2 mb-3">
	<div class="breadcrumb-title pe-3">Registros</div>
	<div class="ps-3 d-none d-sm-block">
		<nav aria-label="breadcrumb"><ol class="breadcrumb mb-0 p-0">
			<li class="breadcrumb-item"><a href="javascript:;"><i class="bx bx-phone-incoming"></i></a></li>
			<li class="breadcrumb-item active" aria-current="page">Inbound</li>
		</ol></nav>
	</div>
</div>

<div class="ib" id="inbound">
	<!-- Indicadores -->
	<div class="row row-cols-2 row-cols-lg-4 g-3 mb-3">
		<div class="col"><div class="card radius-10 mb-0 ib-kpi ib-kpi-pendiente"><div class="card-body"><span>Pendientes de contestar</span><strong id="ibPendientes">—</strong></div></div></div>
		<div class="col"><div class="card radius-10 mb-0 ib-kpi"><div class="card-body"><span>Registrados hoy</span><strong id="ibHoy">—</strong></div></div></div>
		<div class="col"><div class="card radius-10 mb-0 ib-kpi"><div class="card-body"><span>Contestados hoy</span><strong id="ibContestadosHoy" class="text-success">—</strong></div></div></div>
		<div class="col"><div class="card radius-10 mb-0 ib-kpi"><div class="card-body"><span>Este mes</span><strong id="ibMes">—</strong></div></div></div>
	</div>

	<!-- Captura rápida -->
	<div class="card radius-10 ib-captura" id="ibCaptura">
		<div class="card-body">
			<div class="d-flex align-items-center mb-2">
				<h6 class="mb-0" id="ibFormTitulo"><i class="bx bx-plus-circle"></i> Nuevo registro</h6>
				<span class="badge bg-warning text-dark ms-2 d-none" id="ibEditando">Editando</span>
			</div>
			<form id="ibForm" class="row g-2 align-items-end" novalidate autocomplete="off">
				<div class="col-sm-4 col-lg-3">
					<label for="ibTelefono" class="form-label small mb-1">Teléfono <span class="text-danger">*</span></label>
					<div class="input-group">
						<span class="input-group-text"><i class="bx bx-phone"></i></span>
						<input type="tel" class="form-control" id="ibTelefono" maxlength="18" inputmode="numeric" placeholder="7777-7777" required />
					</div>
					<div class="invalid-feedback d-block small" id="ibTelefonoError"></div>
				</div>
				<div class="col-sm-8 col-lg-5">
					<label for="ibNombre" class="form-label small mb-1">Nombre del cliente <span class="text-danger">*</span></label>
					<input type="text" class="form-control" id="ibNombre" maxlength="150" placeholder="Nombre y apellido" required />
					<div class="invalid-feedback d-block small" id="ibNombreError"></div>
				</div>
				<div class="col-sm-4 col-lg-2">
					<div class="form-check form-switch ib-switch-form">
						<input class="form-check-input" type="checkbox" role="switch" id="ibContesto" />
						<label class="form-check-label" for="ibContesto">Ya contestó</label>
					</div>
				</div>
				<div class="col-sm-8 col-lg-2 d-flex gap-2">
					<button type="submit" class="btn btn-primary flex-fill" id="ibGuardar"><i class="bx bx-save"></i> Guardar</button>
					<button type="button" class="btn btn-outline-secondary d-none" id="ibCancelar" title="Cancelar la edición"><i class="bx bx-x"></i></button>
				</div>
				<div class="col-12 small text-muted d-none" id="ibCoincide"></div>
			</form>
		</div>
	</div>

	<!-- Lista -->
	<div class="card radius-10">
		<div class="card-body">
			<div class="row g-2 align-items-end mb-3">
				<div class="col-6 col-md-3 col-xl-2"><label for="ibDesde" class="form-label small mb-1">Desde</label><input type="date" class="form-control form-control-sm" id="ibDesde" /></div>
				<div class="col-6 col-md-3 col-xl-2"><label for="ibHasta" class="form-label small mb-1">Hasta</label><input type="date" class="form-control form-control-sm" id="ibHasta" /></div>
				<div class="col-md-6 col-xl-3">
					<span class="form-label small mb-1 d-block">Estado</span>
					<div class="btn-group btn-group-sm w-100" role="group" aria-label="Estado" id="ibEstados">
						<button type="button" class="btn btn-outline-secondary active" data-contesto="-1">Todos</button>
						<button type="button" class="btn btn-outline-secondary" data-contesto="0">Pendientes</button>
						<button type="button" class="btn btn-outline-secondary" data-contesto="1">Contestados</button>
					</div>
				</div>
				<div class="col-md-6 col-xl-3">
					<label for="ibBuscar" class="form-label small mb-1">Buscar</label>
					<input type="search" class="form-control form-control-sm" id="ibBuscar" placeholder="Teléfono o nombre" />
				</div>
				<div class="col-md-6 col-xl-2 d-flex gap-2">
					<button type="button" class="btn btn-sm btn-success flex-fill" id="ibExportar"><i class="bx bx-spreadsheet"></i> Excel</button>
					<button type="button" class="btn btn-sm btn-outline-secondary" id="ibRefrescar" title="Actualizar"><i class="bx bx-refresh"></i></button>
				</div>
				<div class="col-12 d-flex flex-wrap gap-1" id="ibRapidos">
					<button type="button" class="btn btn-sm btn-light" data-rango="hoy">Hoy</button>
					<button type="button" class="btn btn-sm btn-light" data-rango="7">7 días</button>
					<button type="button" class="btn btn-sm btn-light" data-rango="mes">Este mes</button>
					<button type="button" class="btn btn-sm btn-light" data-rango="anterior">Mes anterior</button>
					<button type="button" class="btn btn-sm btn-light" data-rango="todo">Todo</button>
					<span class="ms-auto small text-muted align-self-center" id="ibConteo"></span>
				</div>
			</div>

			<div class="table-responsive">
				<table class="table table-sm table-hover align-middle mb-0 ib-tabla">
					<thead class="table-light">
						<tr>
							<th>Fecha</th>
							<th>Teléfono</th>
							<th>Nombre del cliente</th>
							<th class="text-center">Contestó</th>
							<th class="d-none d-lg-table-cell">Registró</th>
							<th class="d-none d-xl-table-cell">Última modificación</th>
							<th class="text-end"><span class="visually-hidden">Acciones</span></th>
						</tr>
					</thead>
					<tbody id="ibFilas"></tbody>
				</table>
			</div>
			<nav class="d-flex flex-wrap justify-content-between align-items-center gap-2 mt-3" aria-label="Paginación">
				<span class="small text-muted" id="ibPaginaTexto"></span>
				<ul class="pagination pagination-sm mb-0" id="ibPaginas"></ul>
			</nav>
		</div>
	</div>
</div>

<script src="assets/js/inbound.js?v=4"></script>
