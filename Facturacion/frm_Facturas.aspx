<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="frm_Facturas.aspx.cs" Inherits="DPieCenter.Facturacion.frm_Facturas" %>

<link href="assets/css/administracion.css?v=2" rel="stylesheet" />
<link href="assets/css/caja.css?v=1" rel="stylesheet" />

<div class="page-breadcrumb d-flex flex-wrap align-items-center gap-2 mb-3">
	<div class="breadcrumb-title pe-3">Facturación</div>
	<div class="ps-3 d-none d-sm-block">
		<nav aria-label="breadcrumb"><ol class="breadcrumb mb-0 p-0">
			<li class="breadcrumb-item"><a href="javascript:;"><i class="bx bx-wallet"></i></a></li>
			<li class="breadcrumb-item active" aria-current="page">Caja</li>
		</ol></nav>
	</div>
	<div class="ms-auto d-flex align-items-center gap-2" id="cjEstadoChip"></div>
</div>

<div class="cja" id="caja">
	<!-- Estado de la caja: apertura, caja anterior abierta, caja abierta o caja cerrada -->
	<div id="cjPanel"><div class="card radius-10"><div class="card-body text-center text-muted py-5"><div class="spinner-border spinner-border-sm text-primary"></div> Consultando su caja…</div></div></div>

	<!-- Procesos por cobrar y documentos emitidos -->
	<div class="card radius-10 d-none" id="cjListas">
		<div class="card-body">
			<ul class="nav nav-tabs mb-3" role="tablist">
				<li class="nav-item" role="presentation"><button class="nav-link active" data-bs-toggle="tab" data-bs-target="#cjTabPendientes" type="button" role="tab">
					<i class="bx bx-time-five"></i> Pendientes de cobro <span class="badge bg-warning text-dark" id="cjPendCont">0</span></button></li>
				<li class="nav-item" role="presentation"><button class="nav-link" data-bs-toggle="tab" data-bs-target="#cjTabCitas" type="button" role="tab" id="cjTabCitasBtn">
					<i class="bx bx-calendar-check"></i> Citas por adelantado <span class="badge bg-info text-dark d-none" id="cjCitasCont">0</span></button></li>
				<li class="nav-item" role="presentation"><button class="nav-link" data-bs-toggle="tab" data-bs-target="#cjTabEmitidos" type="button" role="tab">
					<i class="bx bx-receipt"></i> Emitidos en esta caja <span class="badge bg-secondary" id="cjEmiCont">0</span></button></li>
				<li class="nav-item" role="presentation"><button class="nav-link" data-bs-toggle="tab" data-bs-target="#cjTabSalidas" type="button" role="tab">
					<i class="bx bx-transfer-alt"></i> Manejo de Efectivo <span class="badge bg-secondary" id="cjSalCont">0</span></button></li>
			</ul>
			<div class="tab-content">
				<div class="tab-pane fade show active" id="cjTabPendientes" role="tabpanel">
					<div class="row g-2 align-items-center mb-3">
						<div class="col-md-5"><input type="search" class="form-control form-control-sm" id="cjBuscar" placeholder="Paciente, documento, celular o N.º de factura" aria-label="Buscar" /></div>
						<div class="col-md d-flex flex-wrap gap-1" id="cjRangos">
							<button type="button" class="btn btn-sm btn-light" data-rango="hoy">Hoy</button>
							<button type="button" class="btn btn-sm btn-light" data-rango="7">7 días</button>
							<button type="button" class="btn btn-sm btn-light" data-rango="30">30 días</button>
							<button type="button" class="btn btn-sm btn-light" data-rango="todo">Todos</button>
						</div>
						<div class="col-md-auto small text-muted" id="cjPendResumen"></div>
					</div>
					<div class="table-responsive">
						<table class="table table-hover align-middle mb-0 ad-tabla">
							<thead class="table-light"><tr><th>Fecha</th><th>Paciente</th><th class="d-none d-lg-table-cell">Servicios</th><th class="d-none d-md-table-cell">Especialista</th><th class="text-end">Total</th><th></th></tr></thead>
							<tbody id="cjPendientes"></tbody>
						</table>
					</div>
					<nav class="d-flex flex-wrap justify-content-between align-items-center gap-2 mt-3" aria-label="Paginación">
						<span class="small text-muted" id="cjPaginaTexto"></span><ul class="pagination pagination-sm mb-0" id="cjPaginas"></ul>
					</nav>
				</div>
				<!-- Cobro de citas por adelantado: se cobra el total de la cita con su factura (DTE).
				     Al atender la cita solo queda por cobrar lo que se agregue. Si se cancela, queda saldo a favor. -->
				<div class="tab-pane fade" id="cjTabCitas" role="tabpanel">
					<div class="row g-2 align-items-center mb-3">
						<div class="col-md-5"><input type="search" class="form-control form-control-sm" id="cjCitasBuscar" placeholder="Paciente, documento o celular" aria-label="Buscar cita" /></div>
						<div class="col-md small text-muted">Busque al paciente para ver sus citas activas de los próximos 30 días. Al cobrar se emite la factura; al atenderla solo se cobra lo que se agregue.</div>
						<div class="col-md-auto"><button type="button" class="btn btn-sm btn-outline-primary" id="cjSinCita"><i class="bx bx-wallet"></i> Cobrar sin cita</button></div>
					</div>
					<div class="d-flex flex-wrap align-items-center gap-2 small mb-2 d-none" id="cjPagosResumen"></div>
					<div class="alert alert-primary small py-2 d-none" id="cjPagos"></div>
					<div class="alert alert-info small py-2 d-none" id="cjSaldos"></div>
					<div class="table-responsive">
						<table class="table table-hover align-middle mb-0 ad-tabla">
							<thead class="table-light"><tr><th>Cita</th><th>Paciente</th><th class="d-none d-lg-table-cell">Servicios</th><th class="d-none d-md-table-cell">Especialista</th><th class="text-end">Total</th><th></th></tr></thead>
							<tbody id="cjCitas"></tbody>
						</table>
					</div>
				</div>
				<div class="tab-pane fade" id="cjTabEmitidos" role="tabpanel">
					<div class="table-responsive">
						<table class="table table-hover align-middle mb-0 ad-tabla">
							<thead class="table-light"><tr><th>Hora</th><th>Documento</th><th>Cliente</th><th class="d-none d-md-table-cell">Forma de pago</th><th class="text-end">Total</th><th class="text-center">Estado</th><th></th></tr></thead>
							<tbody id="cjEmitidos"></tbody>
						</table>
					</div>
				</div>
				<div class="tab-pane fade" id="cjTabSalidas" role="tabpanel">
					<div class="d-flex flex-wrap align-items-center gap-2 mb-2">
						<span class="small text-muted me-auto" id="cjSalResumen"></span>
						<button type="button" class="btn btn-sm btn-outline-success cj-entrada" data-tipo="E"><i class="bx bx-log-in-circle"></i> Entrada de efectivo</button>
						<button type="button" class="btn btn-sm btn-outline-warning cj-sacar" data-tipo="S"><i class="bx bx-log-out-circle"></i> Salida de efectivo</button>
					</div>
					<div class="table-responsive">
						<table class="table table-hover align-middle mb-0 ad-tabla">
							<thead class="table-light"><tr><th>Hora</th><th>Movimiento</th><th>Motivo</th><th class="d-none d-md-table-cell">Referencia</th><th class="text-end">Monto</th><th></th></tr></thead>
							<tbody id="cjSalidas"></tbody>
						</table>
					</div>
				</div>
			</div>
		</div>
	</div>
</div>

<!-- Cierre de caja -->
<div class="modal fade" id="cjModalCierre" tabindex="-1" aria-labelledby="cjCierreTitulo" aria-hidden="true">
	<div class="modal-dialog modal-dialog-scrollable">
		<div class="modal-content">
			<form id="cjFormCierre" class="d-flex flex-column mh-100 overflow-hidden" novalidate autocomplete="off">
				<div class="modal-header">
					<h5 class="modal-title" id="cjCierreTitulo">Cerrar caja</h5>
					<button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
				</div>
				<div class="modal-body">
					<h6 class="ad-seccion">Cobros por forma de pago</h6>
					<div id="cjCierreFormas"></div>
					<h6 class="ad-seccion">Resumen de su caja</h6>
					<div id="cjCuadre"><div class="small text-muted"><span class="spinner-border spinner-border-sm text-primary"></span> Calculando…</div></div>
					<h6 class="ad-seccion">Arqueo del efectivo</h6>
					<div class="d-flex justify-content-between small"><span>Fondo de caja</span><strong id="cjCierreFondo"></strong></div>
					<div class="d-flex justify-content-between small"><span>Cobrado en efectivo</span><strong id="cjCierreEfectivo"></strong></div>
					<div class="d-flex justify-content-between small"><span>Entradas de efectivo</span><strong id="cjCierreEntradas" class="text-success"></strong></div>
					<div class="d-flex justify-content-between small"><span>Salidas de efectivo</span><strong id="cjCierreSalidas" class="text-danger"></strong></div>
					<div class="d-flex justify-content-between border-top pt-2 mt-2"><span>Efectivo que debe haber</span><strong id="cjCierreEsperado" class="ad-titulo"></strong></div>
					<div class="mt-3">
						<label for="cjContado" class="form-label">Efectivo contado <span class="text-danger">*</span></label>
						<div class="input-group"><span class="input-group-text">$</span><input type="number" class="form-control text-end" id="cjContado" min="0" step="0.01" required /></div>
						<div class="mt-2 small" id="cjDiferencia"></div>
					</div>
					<div class="mt-3">
						<label for="cjObservaciones" class="form-label">Observaciones</label>
						<textarea class="form-control" id="cjObservaciones" rows="2" maxlength="500" placeholder="Explique cualquier diferencia"></textarea>
					</div>
					<div class="alert alert-warning small mt-3 mb-0"><i class="bx bx-info-circle"></i> Al cerrar la caja ya no podrá emitir documentos hoy.</div>
				</div>
				<div class="modal-footer">
					<button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Cancelar</button>
					<button type="submit" class="btn btn-danger" id="cjCerrarConfirmar"><i class="bx bx-lock-alt"></i> Cerrar caja</button>
				</div>
			</form>
		</div>
	</div>
</div>

<!-- Manejo de efectivo: entrada o salida -->
<div class="modal fade" id="cjModalSalida" tabindex="-1" aria-labelledby="cjSalidaTitulo" aria-hidden="true">
	<div class="modal-dialog">
		<div class="modal-content">
			<form id="cjFormSalida" novalidate autocomplete="off">
				<div class="modal-header">
					<h5 class="modal-title" id="cjSalidaTitulo">Salida de efectivo</h5>
					<button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
				</div>
				<div class="modal-body">
					<div class="btn-group w-100 mb-3" role="group" aria-label="Tipo de movimiento">
						<input type="radio" class="btn-check" name="cjMovTipo" id="cjMovEntrada" value="E" autocomplete="off">
						<label class="btn btn-outline-success" for="cjMovEntrada"><i class="bx bx-log-in-circle"></i> Entrada de efectivo</label>
						<input type="radio" class="btn-check" name="cjMovTipo" id="cjMovSalida" value="S" autocomplete="off">
						<label class="btn btn-outline-warning" for="cjMovSalida"><i class="bx bx-log-out-circle"></i> Salida de efectivo</label>
					</div>
					<div class="alert alert-light border small py-2 d-flex justify-content-between"><span>Efectivo disponible en la caja</span><strong id="cjSalDisponible"></strong></div>
					<div class="row g-3">
						<div class="col-sm-5">
							<label for="cjSalMonto" class="form-label">Monto <span class="text-danger">*</span></label>
							<div class="input-group"><span class="input-group-text">$</span><input type="number" class="form-control text-end" id="cjSalMonto" min="0.01" step="0.01" required /></div>
						</div>
						<div class="col-sm-7">
							<label for="cjSalCategoria" class="form-label" id="cjSalCategoriaLbl">Tipo de salida <span class="text-danger">*</span></label>
							<select class="form-select" id="cjSalCategoria" required></select>
						</div>
						<div class="col-12">
							<label for="cjSalMotivo" class="form-label">Motivo <span class="text-danger">*</span></label>
							<textarea class="form-control" id="cjSalMotivo" rows="2" maxlength="250" placeholder="Ejemplo: compra de agua y café para la sala de espera" required></textarea>
							<div class="form-text"><span id="cjSalMotivoCont">0</span>/250</div>
						</div>
						<div class="col-12">
							<label for="cjSalReferencia" class="form-label">Referencia</label>
							<input type="text" class="form-control" id="cjSalReferencia" maxlength="50" placeholder="N.º de factura del proveedor, boleta de depósito…" />
						</div>
					</div>
				</div>
				<div class="modal-footer">
					<button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Cancelar</button>
					<button type="submit" class="btn btn-warning" id="cjSalGuardar"><i class="bx bx-log-out-circle"></i> Registrar salida</button>
				</div>
			</form>
		</div>
	</div>
</div>

<!-- Pago adelantado sin cita: monto libre; la cita queda pendiente de agendar -->
<div class="modal fade" id="cjModalSinCita" tabindex="-1" aria-labelledby="cjSinCitaTitulo" aria-hidden="true">
	<div class="modal-dialog">
		<div class="modal-content">
			<form id="cjSinCitaForm" novalidate autocomplete="off">
				<div class="modal-header">
					<h5 class="modal-title" id="cjSinCitaTitulo"><i class="bx bx-wallet"></i> Cobrar sin cita</h5>
					<button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
				</div>
				<div class="modal-body">
					<p class="small text-muted">El paciente paga ahora un monto libre y su cita queda <strong>pendiente de agendar</strong>. Al crear la cita use <strong>Usar pago adelantado</strong>: al atenderla se descuenta y solo se cobra la diferencia. Si sobra, queda para su siguiente cita.</p>
					<label for="cjSinCitaBuscar" class="form-label">Paciente <span class="text-danger">*</span></label>
					<input type="search" class="form-control" id="cjSinCitaBuscar" placeholder="Nombre, documento o celular" />
					<div class="list-group mt-1" id="cjSinCitaResultados"></div>
					<div class="alert alert-light border py-2 mt-2 d-none" id="cjSinCitaPaciente"></div>
					<div class="row g-3 mt-1">
						<div class="col-sm-5">
							<label for="cjSinCitaMonto" class="form-label">Monto <span class="text-danger">*</span></label>
							<div class="input-group"><span class="input-group-text">$</span><input type="number" class="form-control text-end" id="cjSinCitaMonto" min="0.01" step="0.01" /></div>
						</div>
						<div class="col-sm-7">
							<label for="cjSinCitaDesc" class="form-label">Descripción en la factura</label>
							<input type="text" class="form-control" id="cjSinCitaDesc" maxlength="250" placeholder="Pago adelantado de servicios podológicos" />
						</div>
					</div>
				</div>
				<div class="modal-footer">
					<button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Cancelar</button>
					<button type="submit" class="btn btn-primary" id="cjSinCitaCobrar"><i class="bx bx-receipt"></i> Ir a cobrar</button>
				</div>
			</form>
		</div>
	</div>
</div>

<script src="assets/js/ticket-venta.js?v=1"></script>
<script src="assets/js/caja.js?v=13"></script>
