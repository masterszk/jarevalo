<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="frm_Procedimientos.aspx.cs" Inherits="DPieCenter.Registros.frm_Procedimientos" %>

<link href="assets/css/procedimientos.css?v=2" rel="stylesheet" />

<!--breadcrumb-->
<div class="page-breadcrumb d-flex flex-wrap align-items-center gap-2 mb-3">
	<div class="breadcrumb-title pe-3">Procedimientos</div>
	<div class="d-flex align-items-center gap-2 flex-grow-1">
		<span class="badge bg-light text-dark border fs-6 fw-normal" id="paEspecialista"><i class="bx bx-user-pin"></i> <span id="paEspecialistaNombre">…</span></span>
		<span class="text-muted small" id="paActualizado" aria-live="polite"></span>
	</div>
</div>

<div class="row procedimientos" id="procAtencion">
	<div class="col-xl-8">

		<!-- Paciente en atención -->
		<div class="card radius-10">
			<div class="card-body">
				<div id="paVacio" class="pa-vacio text-center py-5">
					<i class="bx bx-user-voice"></i>
					<h5 class="mt-2 mb-1">No hay paciente en atención</h5>
					<p class="text-muted mb-3" id="paVacioTexto">Llame al siguiente paciente de la cola del día.</p>
					<button type="button" class="btn btn-success px-4" id="paLlamarSiguiente" disabled>
						<i class="bx bx-bell"></i> Llamar al siguiente
					</button>
				</div>

				<div id="paActual" class="d-none">
					<div class="d-flex flex-wrap align-items-center gap-3 mb-3">
						<div class="pa-avatar" id="paIniciales" aria-hidden="true"></div>
						<div class="flex-grow-1">
							<h4 class="mb-1" id="paPaciente"></h4>
							<div class="d-flex flex-wrap gap-2 small">
								<span class="badge bg-light text-dark border" id="paTipoCita"></span>
								<span class="badge bg-light text-dark border"><i class="bx bx-time-five"></i> Cita <span id="paHoraCita"></span></span>
								<span class="badge bg-light text-dark border"><i class="bx bx-user-pin"></i> <span id="paEspecialistaActual"></span></span>
							</div>
						</div>
						<div class="text-end">
							<div class="pa-etiqueta">En atención</div>
							<div class="pa-cronometro" id="paCronometro">00:00</div>
						</div>
					</div>

					<div class="row g-2 pa-datos">
						<div class="col-sm-4"><span>Documento</span><strong id="paDocumento"></strong></div>
						<div class="col-sm-4"><span>Fecha de nacimiento</span><strong id="paNacimiento"></strong></div>
						<div class="col-sm-4"><span>Edad</span><strong id="paEdad"></strong></div>
						<div class="col-sm-4"><span>Sexo</span><strong id="paSexo"></strong></div>
						<div class="col-12 d-none" id="paComentariosFila"><span>Comentarios de la cita</span><strong id="paComentarios"></strong></div>
					</div>
				</div>
			</div>
		</div>

		<!-- Detalle -->
		<div class="card radius-10 d-none" id="paDetalle">
			<div class="card-body">
				<ul class="nav nav-tabs nav-primary" role="tablist">
					<li class="nav-item" role="presentation">
						<a class="nav-link active" data-bs-toggle="tab" href="#paTabTratamientos" role="tab" aria-selected="true">
							<i class="bx bx-list-check me-1"></i>Tratamientos
						</a>
					</li>
					<li class="nav-item" role="presentation">
						<a class="nav-link" data-bs-toggle="tab" href="#paTabDiagnostico" role="tab" aria-selected="false">
							<i class="bx bx-notepad me-1"></i>Diagnóstico
						</a>
					</li>
					<li class="nav-item" role="presentation">
						<a class="nav-link" data-bs-toggle="tab" href="#paTabHistorial" role="tab" aria-selected="false">
							<i class="bx bx-history me-1"></i>Historial <span class="badge bg-secondary ms-1" id="paHistorialNum">0</span>
						</a>
					</li>
				</ul>
				<div class="tab-content pt-3">
					<div class="tab-pane fade show active" id="paTabTratamientos" role="tabpanel">
						<div class="d-flex justify-content-end mb-2">
							<button type="button" class="btn btn-sm btn-outline-primary" id="paAgregar"><i class="bx bx-plus"></i> Agregar tratamiento</button>
						</div>
						<div class="table-responsive">
							<table class="table table-sm align-middle mb-0">
								<thead>
									<tr><th>Tratamiento</th><th class="text-end">Precio</th><th class="text-center" style="width:70px;"></th></tr>
								</thead>
								<tbody id="paTratamientos"></tbody>
								<tfoot>
									<tr><th class="text-end">Total</th><th class="text-end" id="paTotal">$ 0.00</th><th></th></tr>
								</tfoot>
							</table>
						</div>
					</div>
					<div class="tab-pane fade" id="paTabDiagnostico" role="tabpanel">
						<label for="paDiagnostico" class="form-label">Diagnóstico, hallazgos y recomendaciones</label>
						<textarea rows="8" class="form-control" id="paDiagnostico" maxlength="4000"></textarea>
						<div class="d-flex align-items-center justify-content-between mt-2">
							<small class="text-muted" id="paDiagEstado">Se guarda automáticamente.</small>
							<button type="button" class="btn btn-sm btn-outline-primary" id="paGuardarDiag"><i class="bx bx-save"></i> Guardar</button>
						</div>
					</div>
					<div class="tab-pane fade" id="paTabHistorial" role="tabpanel">
						<div id="paHistorial"></div>
					</div>
				</div>
			</div>
		</div>
	</div>

	<div class="col-xl-4">
		<!-- Acciones -->
		<div class="card radius-10">
			<div class="card-body">
				<div class="d-grid">
					<button type="button" class="btn btn-success btn-lg" id="paFinalizar" disabled><i class="bx bx-check-circle"></i> Finalizar atención</button>
				</div>
				<p class="small text-muted mt-2 mb-0">Al finalizar se guarda el diagnóstico y la factura queda pendiente de cobro. Luego llame al siguiente paciente con <strong>Llamar al siguiente</strong> o con <strong>Llamar</strong> en la cola.
					Para reprogramar, cambiar de especialista o cancelar: Facturación &rsaquo; Procedimientos.</p>
			</div>
		</div>

		<!-- Cola del día -->
		<div class="card radius-10">
			<div class="card-body">
				<div class="d-flex align-items-center mb-2">
					<h6 class="pa-etiqueta mb-0">Cola de hoy</h6>
					<span class="badge bg-primary ms-2" id="paColaNum">0</span>
					<div class="spinner-border spinner-border-sm text-primary ms-auto d-none" id="paCargando" role="status"><span class="visually-hidden">Cargando…</span></div>
				</div>
				<div id="paCola" class="pa-cola"></div>
			</div>
		</div>
	</div>
</div>

<!-- Catálogo de tratamientos -->
<div class="modal fade" id="paModalCatalogo" tabindex="-1" aria-labelledby="paModalCatalogoTitulo" aria-hidden="true">
	<div class="modal-dialog modal-lg modal-dialog-scrollable">
		<div class="modal-content">
			<div class="modal-header">
				<h5 class="modal-title" id="paModalCatalogoTitulo">Agregar tratamiento</h5>
				<button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
			</div>
			<div class="modal-body">
				<input type="search" class="form-control mb-3" id="paBuscarTratamiento" placeholder="Buscar tratamiento…" aria-label="Buscar tratamiento" />
				<div class="row row-cols-2 row-cols-md-3 g-3" id="paCatalogo"></div>
			</div>
		</div>
	</div>
</div>

<script src="assets/js/procedimientos.js?v=8"></script>
