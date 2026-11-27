<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="frm_OpenFactura.aspx.cs" Inherits="DPieCenter.Facturacion.frm_OpenFactura" %>

<link href="assets/css/pago-factura.css?v=3" rel="stylesheet" />

<!--breadcrumb-->
<div class="page-breadcrumb d-none d-sm-flex align-items-center mb-3">
	<div class="breadcrumb-title pe-3">Facturacion</div>
	<div class="ps-3">
		<nav aria-label="breadcrumb">
			<ol class="breadcrumb mb-0 p-0">
				<li class="breadcrumb-item"><a href="javascript:;"><i class="lni lni-users"></i></a>
				</li>
				<li class="breadcrumb-item active" aria-current="page">Pago de Factura</li>
			</ol>
		</nav>
	</div>
	<div class="ms-auto">
		<span class="badge bg-success d-none" id="lblPagada"><i class="bx bx-check-circle"></i> Pagada</span>
	</div>
</div>

<div class="row pago-factura" id="pagoFactura" data-factura="<%: Request.QueryString["id"] %>">

    <!-- ===== Columna izquierda: documento, forma de pago y teclado ===== -->
    <div class="col-lg-4">

        <div class="card">
            <div class="card-body">
                <h6 class="pago-titulo">Tipo de documento</h6>
                <div class="btn-group w-100" role="group" aria-label="Tipo de documento">
                    <input type="radio" class="btn-check" name="tipoDte" id="tipoFE" value="01" checked />
                    <label class="btn btn-outline-primary" for="tipoFE"><i class="bx bx-user"></i> Consumidor final</label>
                    <input type="radio" class="btn-check" name="tipoDte" id="tipoCCF" value="03" />
                    <label class="btn btn-outline-primary" for="tipoCCF"><i class="bx bx-building"></i> Crédito fiscal</label>
                </div>

                <div class="pago-receptor mt-3">
                    <label class="form-label mb-1" for="cliente">Cliente</label>
                    <input type="text" class="form-control" readonly="readonly" id="cliente" />
                    <div class="pago-fiscal d-none" id="resumenFiscal">
                        <div class="small text-muted" id="txtFiscal">Sin datos fiscales.</div>
                        <button type="button" class="btn btn-sm btn-outline-primary" id="btnDatosFiscales"><i class="bx bx-edit"></i> Datos fiscales</button>
                    </div>
                </div>
            </div>
        </div>

        <!-- Pago combinado: cada clic agrega la forma con lo que falta por cubrir (assets/js/pago-factura.js) -->
        <div class="pago-metodos" aria-label="Agregar forma de pago">
            <button type="button" class="btn btn-outline-dark pago-metodo" data-forma="01">
                <i class="bx bx-money"></i> Efectivo
            </button>
            <button type="button" class="btn btn-outline-dark pago-metodo" data-forma="03" title="Se registra como tarjeta (código 03)">
                <i class="bx bx-credit-card"></i> Tarjeta crédito/débito
            </button>
            <button type="button" class="btn btn-outline-dark pago-metodo" data-forma="05">
                <i class="bx bx-transfer"></i> Transferencias
            </button>
        </div>

        <div class="pago-teclado" aria-label="Teclado de monto recibido">
            <button type="button" class="btn btn-outline-dark" data-tecla="1">1</button>
            <button type="button" class="btn btn-outline-dark" data-tecla="2">2</button>
            <button type="button" class="btn btn-outline-dark" data-tecla="3">3</button>
            <button type="button" class="btn btn-outline-success" data-suma="10">+10</button>
            <button type="button" class="btn btn-outline-dark" data-tecla="4">4</button>
            <button type="button" class="btn btn-outline-dark" data-tecla="5">5</button>
            <button type="button" class="btn btn-outline-dark" data-tecla="6">6</button>
            <button type="button" class="btn btn-outline-success" data-suma="20">+20</button>
            <button type="button" class="btn btn-outline-dark" data-tecla="7">7</button>
            <button type="button" class="btn btn-outline-dark" data-tecla="8">8</button>
            <button type="button" class="btn btn-outline-dark" data-tecla="9">9</button>
            <button type="button" class="btn btn-outline-success" data-suma="50">+50</button>
            <button type="button" class="btn btn-warning" data-accion="exacto" title="Monto exacto">Exacto</button>
            <button type="button" class="btn btn-outline-dark" data-tecla="0">0</button>
            <button type="button" class="btn btn-outline-dark" data-tecla=".">.</button>
            <button type="button" class="btn btn-danger" data-accion="borrar" title="Borrar" aria-label="Borrar"><i class="bx bx-arrow-back"></i></button>
            <button type="button" class="btn btn-outline-secondary pago-limpiar" data-accion="limpiar">Limpiar</button>
        </div>

        <div class="pago-acciones">
            <button type="button" class="btn btn-outline-dark" id="btnRegresar"><i class="bx bx-arrow-back"></i> Regresar</button>
            <button type="button" class="btn btn-primary" id="btnPagar"><i class="bx bx-check"></i> Pagar</button>
        </div>
    </div>

    <!-- ===== Columna derecha: servicios, totales y monto ===== -->
    <div class="col-lg-8">
        <div class="card">
            <div class="card-header bg-transparent d-flex align-items-center">
                <h6 class="mb-0">Servicios</h6>
                <button type="button" class="btn btn-sm btn-success ms-auto" id="btnServicios"><i class="bx bx-plus"></i> Agregar servicio</button>
            </div>
            <div class="card-body">
                <div class="table-responsive">
                    <table class="table table-hover table-striped table-bordered mb-0 pago-items">
                        <thead class="table-dark">
                            <tr>
                                <th>DESCRIPCION</th>
                                <th class="text-end">VALOR</th>
                                <th class="pago-col-accion"><span class="visually-hidden">Quitar</span></th>
                            </tr>
                        </thead>
                        <tbody id="tbItems">
                            <tr><td colspan="3" class="text-center"><div class="spinner-border spinner-border-sm" role="status"></div></td></tr>
                        </tbody>
                        <tfoot>
                            <tr class="pago-descuento d-none" id="filaDescuento">
                                <th class="text-end" id="lblDescuento">Descuento:</th>
                                <th class="text-end" id="totDescuento">0.00</th>
                                <th></th>
                            </tr>
                            <tr>
                                <th class="text-end" id="lblGravado">Total gravado:</th>
                                <th class="text-end" id="totGravado">0.00</th>
                                <th></th>
                            </tr>
                            <tr>
                                <th class="text-end" id="lblIva">IVA 13%:</th>
                                <th class="text-end" id="totIva">0.00</th>
                                <th></th>
                            </tr>
                            <tr class="pago-total">
                                <th class="text-end">Total a pagar:</th>
                                <th class="text-end" id="totPagar">0.00</th>
                                <th></th>
                            </tr>
                        </tfoot>
                    </table>
                </div>
            </div>
        </div>

        <!-- Cupón de descuento: el lector de QR escribe el código y Enter -->
        <div class="card pago-cupon" id="cardCupon">
            <div class="card-body py-2">
                <div class="d-flex align-items-center gap-2" id="cuponEntrada">
                    <i class="bx bx-qr-scan fs-4 text-primary"></i>
                    <input type="text" class="form-control form-control-sm text-uppercase" id="txtCupon" maxlength="12" placeholder="Escanee o escriba el cupón" aria-label="Código del cupón" autocomplete="off" />
                    <button type="button" class="btn btn-sm btn-outline-primary" id="btnAplicarCupon">Aplicar</button>
                    <button type="button" class="btn btn-sm btn-outline-secondary d-none" id="btnCamaraCupon" title="Escanear con la cámara"><i class="bx bx-camera"></i></button>
                </div>
                <div class="d-none" id="cuponAplicado"></div>
                <video class="pago-cupon-video d-none mt-2" id="videoCupon" playsinline muted></video>
            </div>
        </div>

        <div class="card">
            <div class="card-body pago-monto">
                <div class="d-flex justify-content-between align-items-baseline">
                    <div class="text-muted small">Formas de pago <span class="d-none d-md-inline">· el teclado escribe en la línea marcada</span></div>
                    <div class="small text-muted">Pagado: <strong id="lblPagado">0.00</strong></div>
                </div>
                <div class="pago-lineas" id="pagoLineas" aria-live="polite"></div>
                <div class="pago-cambio" id="lblCambio"></div>
            </div>
        </div>

        <div class="alert alert-primary d-none" id="avisoAnticipo" role="status"></div>

        <div class="alert alert-info d-none" id="avisoSinCosto" role="status">
            <i class="bx bx-info-circle"></i> <strong>Servicio sin costo.</strong> Hacienda no recibe DTE con valor $0.00: al confirmar se emite un <strong>ticket POS</strong> (80 mm) que cierra la factura.
        </div>

        <div class="card d-none" id="cardTicket">
            <div class="card-body">
                <h6 class="mb-2"><i class="bx bx-receipt"></i> Ticket POS (servicio sin costo)</h6>
                <div class="small mb-1"><strong>No. Ticket:</strong> <span id="ticketNumero"></span></div>
                <div class="small text-muted mb-3" id="ticketDetalle"></div>
                <button type="button" class="btn btn-sm btn-outline-primary" id="btnImprimirTicket"><i class="bx bx-printer"></i> Imprimir ticket</button>
            </div>
        </div>

        <div class="card d-none" id="cardDte">
            <div class="card-body">
                <h6 class="mb-2"><i class="bx bx-file"></i> Documento tributario electrónico</h6>
                <div class="small mb-1"><strong>No. Control:</strong> <span id="dteNumero"></span></div>
                <div class="small mb-3"><strong>Cód. Generación:</strong> <span id="dteCodigo"></span></div>
                <a class="btn btn-sm btn-outline-primary d-none" id="lnkPdf" target="_blank" rel="noopener"><i class="bx bxs-file-pdf"></i> Ver PDF</a>
                <a class="btn btn-sm btn-outline-secondary d-none" id="lnkJson" target="_blank" rel="noopener" download><i class="bx bx-code-curly"></i> JSON</a>
                <button type="button" class="btn btn-sm btn-outline-dark" id="btnTicketVenta"><i class="bx bx-printer"></i> Imprimir ticket</button>
                <div class="small text-muted mt-3" id="dteCorreo"></div>
                <div class="input-group input-group-sm mt-2">
                    <input type="email" class="form-control" id="txtCorreoDte" maxlength="100" placeholder="correo@cliente.com" aria-label="Correo para enviar el documento" />
                    <button type="button" class="btn btn-outline-primary" id="btnEnviarCorreo"><i class="bx bx-envelope"></i> Enviar</button>
                </div>
            </div>
        </div>
    </div>
</div>

<!-- ===== Modal: agregar servicios ===== -->
<div class="modal fade" id="modalServicios" tabindex="-1" aria-labelledby="tituloServicios" aria-hidden="true">
	<div class="modal-dialog modal-dialog-scrollable modal-lg">
		<div class="modal-content">
			<div class="modal-header">
				<h5 class="modal-title" id="tituloServicios">Agregar servicio</h5>
				<button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
			</div>
			<div class="modal-body">
                <input type="search" class="form-control mb-3" id="txtBuscarServicio" placeholder="Buscar servicio…" aria-label="Buscar servicio" />
                <div class="list-group pago-servicios" id="listaServicios"></div>
			</div>
			<div class="modal-footer">
				<button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cerrar</button>
			</div>
		</div>
	</div>
</div>

<!-- ===== Modal: datos fiscales (crédito fiscal) ===== -->
<div class="modal fade" id="modalReceptor" tabindex="-1" aria-labelledby="tituloReceptor" aria-hidden="true" data-bs-backdrop="static">
	<div class="modal-dialog modal-lg">
		<div class="modal-content">
			<div class="modal-header">
				<h5 class="modal-title" id="tituloReceptor">Datos fiscales del cliente</h5>
				<button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
			</div>
			<div class="modal-body">
                <div class="row g-3">
                    <div class="col-md-6">
                        <label class="form-label" for="recNit">NIT *</label>
                        <div class="input-group">
                            <input type="text" class="form-control" id="recNit" maxlength="17" inputmode="numeric" placeholder="14 dígitos" />
                            <button class="btn btn-outline-secondary" type="button" id="btnBuscarNit" title="Buscar datos guardados"><i class="bx bx-search"></i></button>
                        </div>
                    </div>
                    <div class="col-md-6">
                        <label class="form-label" for="recNrc">NRC *</label>
                        <input type="text" class="form-control" id="recNrc" maxlength="10" inputmode="numeric" />
                    </div>
                    <div class="col-md-6">
                        <label class="form-label" for="recNombre">Nombre o razón social *</label>
                        <input type="text" class="form-control" id="recNombre" maxlength="250" />
                    </div>
                    <div class="col-md-6">
                        <label class="form-label" for="recComercial">Nombre comercial</label>
                        <input type="text" class="form-control" id="recComercial" maxlength="150" />
                    </div>
                    <div class="col-md-3">
                        <label class="form-label" for="recCodAct">Cód. actividad *</label>
                        <input type="text" class="form-control" id="recCodAct" maxlength="6" inputmode="numeric" />
                    </div>
                    <div class="col-md-9">
                        <label class="form-label" for="recDescAct">Actividad económica *</label>
                        <input type="text" class="form-control" id="recDescAct" maxlength="150" />
                    </div>
                    <div class="col-md-4">
                        <label class="form-label" for="recDepto">Departamento *</label>
                        <select class="form-select" id="recDepto"></select>
                    </div>
                    <div class="col-md-4">
                        <label class="form-label" for="recMuni">Municipio *</label>
                        <select class="form-select" id="recMuni"></select>
                    </div>
                    <div class="col-md-4">
                        <label class="form-label" for="recDistrito">Distrito *</label>
                        <select class="form-select" id="recDistrito"></select>
                    </div>
                    <div class="col-12">
                        <label class="form-label" for="recDireccion">Dirección *</label>
                        <input type="text" class="form-control" id="recDireccion" maxlength="200" />
                    </div>
                    <div class="col-md-6">
                        <label class="form-label" for="recTelefono">Teléfono</label>
                        <input type="tel" class="form-control" id="recTelefono" maxlength="30" />
                    </div>
                    <div class="col-md-6">
                        <label class="form-label" for="recCorreo">Correo *</label>
                        <input type="email" class="form-control" id="recCorreo" maxlength="100" />
                    </div>
                </div>
                <div class="text-danger small mt-3" id="recMsg" role="alert"></div>
			</div>
			<div class="modal-footer">
				<button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancelar</button>
				<button type="button" class="btn btn-primary" id="btnAceptarReceptor">Aceptar</button>
			</div>
		</div>
	</div>
</div>

<script src="assets/js/dte-catalogos.js?v=2"></script>
<script src="assets/js/ticket-venta.js?v=1"></script>
<script src="assets/js/pago-factura.js?v=15"></script>
