<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="frm_Metas.aspx.cs" Inherits="DPieCenter.Registros.frm_Metas" %>

<link href="assets/css/administracion.css?v=2" rel="stylesheet" />
<link href="assets/css/caja.css?v=1" rel="stylesheet" />

<div class="page-breadcrumb d-flex flex-wrap align-items-center gap-2 mb-3">
	<div class="breadcrumb-title pe-3">Registros</div>
	<div class="ps-3 d-none d-sm-block">
		<nav aria-label="breadcrumb"><ol class="breadcrumb mb-0 p-0">
			<li class="breadcrumb-item"><a href="javascript:;"><i class="bx bx-target-lock"></i></a></li>
			<li class="breadcrumb-item active" aria-current="page">Metas por especialista</li>
		</ol></nav>
	</div>
	<div class="ms-auto d-flex flex-wrap align-items-center gap-2">
		<div class="input-group" style="width:auto;">
			<button type="button" class="btn btn-outline-secondary" id="mtMesAnt" title="Mes anterior" aria-label="Mes anterior"><i class="bx bx-chevron-left"></i></button>
			<select class="form-select" id="mtFiltroMes" aria-label="Mes" style="max-width:150px;"></select>
			<input type="number" class="form-control" id="mtFiltroAnio" min="2020" max="2100" aria-label="Año" style="max-width:95px;" />
			<button type="button" class="btn btn-outline-secondary" id="mtMesSig" title="Mes siguiente" aria-label="Mes siguiente"><i class="bx bx-chevron-right"></i></button>
		</div>
		<button type="button" class="btn btn-primary" id="mtNueva"><i class="bx bx-plus"></i> Asignar meta</button>
	</div>
</div>

<div id="metas">
	<div class="alert alert-light border small py-2 mb-3">
		<i class="bx bx-info-circle text-primary"></i>
		Cada especialista tiene su propia meta por mes. Al cambiar una meta se guarda una <strong>versión nueva</strong> y la anterior queda en el historial.
		Si un mes no tiene cambios, su meta se <strong>genera automáticamente</strong> con la del mes anterior.
	</div>

	<!-- Metas del mes por especialista -->
	<div class="card radius-10 mb-3">
		<div class="card-body">
			<div class="d-flex flex-wrap align-items-center gap-2 mb-2">
				<h6 class="mb-0">Metas de <span id="mtPeriodo">—</span></h6>
				<span class="small text-muted" id="mtResumen"></span>
				<button type="button" class="btn btn-sm btn-outline-primary ms-auto d-none" id="mtCambiarSel"><i class="bx bx-edit"></i> Cambiar seleccionados</button>
			</div>
			<div class="table-responsive">
				<table class="table table-hover align-middle mb-0 ad-tabla">
					<thead class="table-light"><tr>
						<th style="width:32px;"><input type="checkbox" class="form-check-input" id="mtSelTodos" aria-label="Seleccionar todos" /></th>
						<th>Especialista</th>
						<th class="text-end">Meta</th>
						<th class="text-end" title="Promedio de los últimos meses × factor del mes × crecimiento">Sugerida</th>
						<th class="text-end d-none d-md-table-cell">Salario base</th>
						<th class="text-end d-none d-md-table-cell">Mínimo</th>
						<th class="text-end d-none d-lg-table-cell">Bono alcance</th>
						<th class="d-none d-lg-table-cell">Escala</th>
						<th>Origen</th>
						<th class="d-none d-xl-table-cell">Último cambio</th>
						<th></th>
					</tr></thead>
					<tbody id="mtLista"></tbody>
				</table>
			</div>
		</div>
	</div>

	<!-- Meta sugerida: factores por mes del año -->
	<div class="card radius-10 mb-3">
		<div class="card-body">
			<div class="d-flex flex-wrap align-items-center gap-2">
				<h6 class="mb-0"><i class="bx bx-bulb text-warning"></i> Meta sugerida según el mes del año</h6>
				<span class="small text-muted" id="mtSugResumen"></span>
				<button type="button" class="btn btn-sm btn-outline-secondary ms-auto" data-bs-toggle="collapse" data-bs-target="#mtSugConfig" aria-expanded="false" aria-controls="mtSugConfig"><i class="bx bx-cog"></i> Factores por mes</button>
			</div>
			<div class="small text-muted mt-1">Meta sugerida = promedio de ventas sin IVA de los últimos <span id="mtSugMeses">3</span> meses × factor del mes × (1 + crecimiento), redondeada. El mes en curso se cuenta con su proyección al cierre. Es una referencia: no cambia la meta hasta que la guarde.</div>
			<div class="collapse" id="mtSugConfig">
				<form id="mtSugForm" class="mt-3" novalidate autocomplete="off">
					<div class="row row-cols-3 row-cols-md-6 g-2" id="mtFactores"></div>
					<div class="row g-2 align-items-end mt-1">
						<div class="col-6 col-md-3">
							<label for="mtCrecimiento" class="form-label small mb-1">Crecimiento sobre el promedio</label>
							<div class="input-group input-group-sm"><input type="number" class="form-control text-end" id="mtCrecimiento" min="-50" max="100" step="0.5" /><span class="input-group-text">%</span></div>
						</div>
						<div class="col-6 col-md-3">
							<label for="mtRedondeo" class="form-label small mb-1">Redondear a</label>
							<select class="form-select form-select-sm" id="mtRedondeo">
								<option value="1">$1</option><option value="10">$10</option><option value="25">$25</option><option value="50">$50</option><option value="100">$100</option>
							</select>
						</div>
						<div class="col-md-6 text-md-end">
							<span class="small text-muted me-2" id="mtSugModificado"></span>
							<button type="submit" class="btn btn-sm btn-primary" id="mtSugGuardar"><i class="bx bx-save"></i> Guardar factores</button>
						</div>
					</div>
					<div class="form-text">Factor 1.00 = un mes normal; 1.15 = se vende 15 % más; 0.85 = 15 % menos. Los valores iniciales son supuestos (cuesta de enero, Día de la Madre, vacaciones agostinas, Black Month, Navidad): ajústelos con la experiencia de la clínica.</div>
				</form>
			</div>
		</div>
	</div>

	<!-- Avance -->
	<div class="card radius-10">
		<div class="card-body">
			<div class="d-flex flex-wrap align-items-center gap-2 mb-2">
				<h6 class="mb-0">Avance del mes</h6>
				<span class="small text-muted" id="mtAvancePeriodo"></span>
			</div>
			<div class="table-responsive">
				<table class="table table-sm align-middle mb-0 ad-tabla">
					<thead class="table-light"><tr>
						<th>Especialista</th>
						<th class="text-end d-none d-md-table-cell">Ventas con IVA</th>
						<th class="text-end">Ventas sin IVA</th>
						<th class="text-end d-none d-sm-table-cell">Meta</th>
						<th style="min-width:140px;">Avance</th>
						<th class="text-end" title="Comisión escalonada: cada rango paga su % por la parte de las ventas que cae en él">Bono estimado</th>
						<th class="text-end" title="Bono por cumplir la meta (0 si no la cumple)">Bono por meta</th>
						<th class="text-end d-none d-lg-table-cell">Total estimado</th>
					</tr></thead>
					<tbody id="mtAvance"></tbody>
				</table>
			</div>
			<div class="small text-muted mt-2">Ventas sin IVA: facturas y créditos fiscales vigentes del mes de los procedimientos de cada especialista, con descuentos. Bono estimado: comisión escalonada — cada rango de la escala paga su % por la parte de las ventas sin IVA que cae en él (desde el mínimo para comisionar) y se suman, más el bono fijo de la escala alcanzada. Bono por meta: el bono por cumplir la meta, o 0 si no se cumple. Total estimado: bono estimado + bono por meta (no incluye el salario base).</div>
		</div>
	</div>
</div>

<!-- Asignar / cambiar / ver meta -->
<div class="modal fade" id="mtModal" tabindex="-1" aria-labelledby="mtModalTitulo" aria-hidden="true">
	<div class="modal-dialog modal-lg modal-dialog-scrollable">
		<div class="modal-content">
			<form id="mtForm" novalidate autocomplete="off">
				<div class="modal-header">
					<h5 class="modal-title" id="mtModalTitulo">Asignar meta</h5>
					<button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
				</div>
				<div class="modal-body">
					<div class="alert small py-2" id="mtAviso"></div>
					<div class="mb-3" id="mtEspBloque">
						<div class="d-flex align-items-center mb-1">
							<label class="form-label mb-0">Especialistas <span class="text-danger">*</span></label>
							<button type="button" class="btn btn-link btn-sm ms-auto py-0" id="mtEspTodos">Todos</button>
							<button type="button" class="btn btn-link btn-sm py-0" id="mtEspNinguno">Ninguno</button>
						</div>
						<div class="border rounded-3 p-2 d-flex flex-wrap gap-3" id="mtEspLista"></div>
					</div>
					<div class="row g-3">
						<div class="col-sm-4">
							<label for="mtMes" class="form-label">Mes <span class="text-danger">*</span></label>
							<select class="form-select" id="mtMes"></select>
						</div>
						<div class="col-sm-3">
							<label for="mtAnio" class="form-label">Año <span class="text-danger">*</span></label>
							<input type="number" class="form-control" id="mtAnio" min="2020" max="2100" />
						</div>
						<div class="col-sm-5">
							<label for="mtMeta" class="form-label">Meta mensual (ventas sin IVA) <span class="text-danger">*</span></label>
							<div class="input-group"><span class="input-group-text">$</span><input type="number" class="form-control text-end" id="mtMeta" min="0" step="0.01" /></div>
						</div>
						<div class="col-12 d-none" id="mtSugBloque">
							<div class="alert alert-warning small py-2 mb-0 d-flex flex-wrap align-items-center gap-2">
								<i class="bx bx-bulb"></i>
								<div class="me-auto"><strong>Meta sugerida: <span id="mtSugValor"></span></strong><div class="text-muted" id="mtSugDetalle"></div></div>
								<button type="button" class="btn btn-sm btn-warning" id="mtUsarSugerida">Usar sugerida</button>
							</div>
						</div>
						<div class="col-sm-4">
							<label for="mtSalario" class="form-label">Salario base</label>
							<div class="input-group"><span class="input-group-text">$</span><input type="number" class="form-control text-end" id="mtSalario" min="0" step="0.01" /></div>
						</div>
						<div class="col-sm-4">
							<label for="mtMinimo" class="form-label">Mínimo para comisionar</label>
							<div class="input-group"><span class="input-group-text">$</span><input type="number" class="form-control text-end" id="mtMinimo" min="0" step="0.01" /></div>
						</div>
						<div class="col-sm-4">
							<label for="mtBono" class="form-label">Bono por cumplir la meta</label>
							<div class="input-group"><span class="input-group-text">$</span><input type="number" class="form-control text-end" id="mtBono" min="0" step="0.01" /></div>
						</div>
					</div>

					<div class="d-flex align-items-center mt-4 mb-2">
						<h6 class="mb-0">Bonificación por escala</h6>
						<button type="button" class="btn btn-sm btn-outline-primary ms-auto" id="mtAgregarEscala"><i class="bx bx-plus"></i> Agregar rango</button>
					</div>
					<div class="table-responsive">
						<table class="table table-sm align-middle mb-1">
							<thead class="table-light"><tr><th>Desde ($)</th><th>Hasta ($)</th><th>% sobre la diferencia</th><th>Bono fijo ($)</th><th></th></tr></thead>
							<tbody id="mtEscalaForm"></tbody>
						</table>
					</div>
					<div class="form-text">Deje "Hasta" vacío en el último rango para indicar "en adelante". El % se aplica a la diferencia entre las ventas sin IVA del mes y el mínimo para comisionar.</div>

					<div class="mt-3">
						<label for="mtObs" class="form-label">Motivo del cambio / observaciones</label>
						<input type="text" class="form-control" id="mtObs" maxlength="500" />
					</div>
					<div class="small text-muted mt-2" id="mtAuditoria"></div>
				</div>
				<div class="modal-footer">
					<button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Cerrar</button>
					<button type="button" class="btn btn-outline-primary d-none" id="mtUsarBase"><i class="bx bx-copy"></i> Usar como base</button>
					<button type="submit" class="btn btn-primary" id="mtGuardar"><i class="bx bx-save"></i> Guardar</button>
				</div>
			</form>
		</div>
	</div>
</div>

<!-- Historial de un especialista -->
<div class="modal fade" id="mtHistModal" tabindex="-1" aria-labelledby="mtHistTitulo" aria-hidden="true">
	<div class="modal-dialog modal-xl modal-dialog-scrollable">
		<div class="modal-content">
			<div class="modal-header">
				<h5 class="modal-title" id="mtHistTitulo">Historial de metas</h5>
				<button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
			</div>
			<div class="modal-body">
				<div class="table-responsive">
					<table class="table table-sm table-hover align-middle mb-0 ad-tabla">
						<thead class="table-light"><tr>
							<th>Mes</th><th class="text-end">Meta</th><th class="text-end d-none d-md-table-cell">Salario</th>
							<th class="text-end d-none d-md-table-cell">Mínimo</th><th class="text-end d-none d-lg-table-cell">Bono alcance</th>
							<th>Origen</th><th>Estado</th><th class="d-none d-lg-table-cell">Registrada</th><th class="d-none d-lg-table-cell">Reemplazada</th><th></th>
						</tr></thead>
						<tbody id="mtHistorial"></tbody>
					</table>
				</div>
			</div>
		</div>
	</div>
</div>

<script src="assets/js/metas.js?v=5"></script>
