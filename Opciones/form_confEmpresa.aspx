<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="form_confEmpresa.aspx.cs" Inherits="DPieCenter.Opciones.form_confEmpresa" %>

<link href="assets/css/administracion.css?v=1" rel="stylesheet" />

<div class="page-breadcrumb d-flex flex-wrap align-items-center gap-2 mb-3">
	<div class="breadcrumb-title pe-3">Opciones</div>
	<div class="ps-3 d-none d-sm-block">
		<nav aria-label="breadcrumb"><ol class="breadcrumb mb-0 p-0">
			<li class="breadcrumb-item"><a href="javascript:;"><i class="bx bx-buildings"></i></a></li>
			<li class="breadcrumb-item active" aria-current="page">Datos de la empresa</li>
		</ol></nav>
	</div>
</div>

<ul class="nav nav-tabs mb-3" id="emTabs" role="tablist" data-tab="<%: Request.QueryString["tab"] %>">
	<li class="nav-item" role="presentation"><button class="nav-link active" data-bs-toggle="tab" data-bs-target="#emTabGeneral" type="button" role="tab" data-tab="general"><i class="bx bx-buildings"></i> Datos generales</button></li>
	<li class="nav-item" role="presentation"><button class="nav-link" data-bs-toggle="tab" data-bs-target="#emTabDte" type="button" role="tab" data-tab="dte"><i class="bx bx-receipt"></i> Facturación electrónica</button></li>
	<li class="nav-item" role="presentation"><button class="nav-link" data-bs-toggle="tab" data-bs-target="#emTabFirma" type="button" role="tab" data-tab="firma"><i class="bx bx-key"></i> Firma electrónica (MH)</button></li>
</ul>

<div class="tab-content">
<div class="tab-pane fade show active" id="emTabGeneral" role="tabpanel">
<div class="card radius-10">
	<div class="card-body">
		<form id="emForm" novalidate autocomplete="off">
			<div class="d-flex flex-wrap align-items-center gap-2 mb-2">
				<p class="ad-ayuda mb-0 me-auto"><i class="bx bx-info-circle"></i> Datos generales de la clínica. Los datos del emisor de los DTE están en la pestaña Facturación electrónica.</p>
				<span class="small text-muted" id="emModificado"></span>
			</div>

			<h6 class="ad-seccion">Identificación</h6>
			<div class="row g-3">
				<div class="col-md-6">
					<label for="emNombre" class="form-label">Nombre comercial <span class="text-danger">*</span></label>
					<input type="text" class="form-control" id="emNombre" maxlength="250" required />
				</div>
				<div class="col-md-6">
					<label for="emPropietario" class="form-label">Propietario o razón social <span class="text-danger">*</span></label>
					<input type="text" class="form-control" id="emPropietario" maxlength="250" required />
				</div>
				<div class="col-sm-6 col-md-3">
					<label for="emNrc" class="form-label">NRC <span class="text-danger">*</span></label>
					<input type="text" class="form-control" id="emNrc" maxlength="20" required />
				</div>
				<div class="col-sm-6 col-md-3">
					<label for="emNit" class="form-label">NIT <span class="text-danger">*</span></label>
					<input type="text" class="form-control" id="emNit" maxlength="20" placeholder="0000-000000-000-0" required />
				</div>
				<div class="col-sm-6 col-md-3">
					<label for="emDui" class="form-label">DUI</label>
					<input type="text" class="form-control" id="emDui" maxlength="20" placeholder="00000000-0" />
				</div>
				<div class="col-sm-6 col-md-3">
					<label for="emTelefono" class="form-label">Teléfono</label>
					<input type="tel" class="form-control" id="emTelefono" maxlength="15" />
				</div>
				<div class="col-12">
					<label for="emActividad" class="form-label">Actividad económica</label>
					<input type="text" class="form-control" id="emActividad" maxlength="500" />
				</div>
			</div>

			<h6 class="ad-seccion">Ubicación</h6>
			<div class="row g-3">
				<div class="col-md-4">
					<label for="emDepartamento" class="form-label">Departamento <span class="text-danger">*</span></label>
					<select class="form-select" id="emDepartamento" required></select>
				</div>
				<div class="col-md-4">
					<label for="emMunicipio" class="form-label">Municipio <span class="text-danger">*</span></label>
					<select class="form-select" id="emMunicipio" required></select>
				</div>
				<div class="col-12">
					<label for="emDireccion" class="form-label">Dirección</label>
					<textarea class="form-control" id="emDireccion" rows="2" maxlength="500"></textarea>
				</div>
			</div>

			<h6 class="ad-seccion">Correo para envíos (SMTP)</h6>
			<div class="row g-3">
				<div class="col-md-6">
					<label for="emEmail" class="form-label">Correo</label>
					<input type="email" class="form-control" id="emEmail" maxlength="50" />
				</div>
				<div class="col-md-6">
					<label for="emClave" class="form-label">Clave del correo</label>
					<div class="input-group">
						<input type="password" class="form-control" id="emClave" maxlength="50" autocomplete="new-password" />
						<button type="button" class="btn btn-outline-secondary" id="emVerClave" title="Mostrar u ocultar" aria-label="Mostrar u ocultar la clave"><i class="bx bx-show"></i></button>
					</div>
					<div class="form-text" id="emClaveAyuda"></div>
				</div>
				<div class="col-md-8">
					<label for="emServidor" class="form-label">Servidor</label>
					<input type="text" class="form-control" id="emServidor" maxlength="250" placeholder="smtp.gmail.com" />
				</div>
				<div class="col-md-4">
					<label for="emPuerto" class="form-label">Puerto</label>
					<input type="number" class="form-control" id="emPuerto" min="1" max="65535" placeholder="587" />
				</div>
			</div>

			<div class="d-flex justify-content-end gap-2 mt-4">
				<button type="button" class="btn btn-outline-secondary" id="emDeshacer"><i class="bx bx-undo"></i> Deshacer cambios</button>
				<button type="submit" class="btn btn-primary" id="emGuardar"><i class="bx bx-save"></i> Guardar</button>
			</div>
		</form>
	</div>
</div>

</div>

<!-- Facturación electrónica: datos del emisor de los DTE (antes Facturacion/frm_EmpresaDte.aspx) -->
<div class="tab-pane fade" id="emTabDte" role="tabpanel">
<div id="empresaDte">
    <div class="row">
        <div class="col-xl-8">
            <form class="card" id="frmEmpresa" novalidate autocomplete="off">
                <div class="card-body">
                    <h6 class="mb-3"><i class="bx bx-id-card"></i> Datos del emisor</h6>
                    <div class="row g-3">
                        <div class="col-md-8">
                            <label for="empNombre" class="form-label">Nombre o razón social *</label>
                            <input type="text" class="form-control" id="empNombre" maxlength="250" required />
                        </div>
                        <div class="col-md-4">
                            <label for="empComercial" class="form-label">Nombre comercial</label>
                            <input type="text" class="form-control" id="empComercial" maxlength="150" />
                        </div>
                        <div class="col-md-4">
                            <label for="empNit" class="form-label">NIT * <small class="text-muted">(sin guiones)</small></label>
                            <input type="text" class="form-control" id="empNit" maxlength="17" inputmode="numeric" required />
                        </div>
                        <div class="col-md-4">
                            <label for="empNrc" class="form-label">NRC *</label>
                            <input type="text" class="form-control" id="empNrc" maxlength="10" inputmode="numeric" required />
                        </div>
                        <div class="col-md-4">
                            <label for="empTelefono" class="form-label">Teléfono *</label>
                            <input type="tel" class="form-control" id="empTelefono" maxlength="30" required />
                        </div>
                        <div class="col-md-3">
                            <label for="empCodActividad" class="form-label">Cód. actividad *</label>
                            <input type="text" class="form-control" id="empCodActividad" maxlength="6" inputmode="numeric" placeholder="96020" required />
                        </div>
                        <div class="col-md-9">
                            <label for="empDescActividad" class="form-label">Actividad económica *</label>
                            <input type="text" class="form-control" id="empDescActividad" maxlength="150" required />
                        </div>
                        <div class="col-md-6">
                            <label for="empCorreo" class="form-label">Correo de la empresa *</label>
                            <input type="email" class="form-control" id="empCorreo" maxlength="100" required />
                        </div>
                    </div>

                    <hr />
                    <h6 class="mb-3"><i class="bx bx-map"></i> Dirección</h6>
                    <div class="row g-3">
                        <div class="col-md-4">
                            <label for="empDepto" class="form-label">Departamento *</label>
                            <select class="form-select" id="empDepto" required></select>
                        </div>
                        <div class="col-md-4">
                            <label for="empMunicipio" class="form-label">Municipio *</label>
                            <select class="form-select" id="empMunicipio" required></select>
                        </div>
                        <div class="col-md-4">
                            <label for="empDistrito" class="form-label">Distrito *</label>
                            <select class="form-select" id="empDistrito" required></select>
                        </div>
                        <div class="col-12">
                            <label for="empComplemento" class="form-label">Dirección (complemento) *</label>
                            <input type="text" class="form-control" id="empComplemento" maxlength="200" required />
                        </div>
                    </div>

                    <hr />
                    <h6 class="mb-3"><i class="bx bx-store"></i> Establecimiento y ambiente</h6>
                    <div class="row g-3">
                        <div class="col-md-4">
                            <label for="empTipoEst" class="form-label">Tipo de establecimiento *</label>
                            <select class="form-select" id="empTipoEst" required></select>
                        </div>
                        <div class="col-md-4">
                            <label for="empCodEstable" class="form-label">Cód. establecimiento *</label>
                            <input type="text" class="form-control text-uppercase" id="empCodEstable" maxlength="4" placeholder="M001" required />
                        </div>
                        <div class="col-md-4">
                            <label for="empCodPuntoVenta" class="form-label">Cód. punto de venta *</label>
                            <input type="text" class="form-control text-uppercase" id="empCodPuntoVenta" maxlength="4" placeholder="P001" required />
                        </div>
                        <div class="col-md-4">
                            <label for="empAmbiente" class="form-label">Ambiente *</label>
                            <select class="form-select" id="empAmbiente" required>
                                <option value="00">00 · Pruebas</option>
                                <option value="01">01 · Producción</option>
                            </select>
                        </div>
                        <div class="col-md-4">
                            <label for="empCodEstableMH" class="form-label">Cód. establecimiento MH</label>
                            <input type="text" class="form-control text-uppercase" id="empCodEstableMH" maxlength="4" />
                        </div>
                        <div class="col-md-4">
                            <label for="empCodPuntoVentaMH" class="form-label">Cód. punto de venta MH</label>
                            <input type="text" class="form-control text-uppercase" id="empCodPuntoVentaMH" maxlength="4" />
                        </div>
                        <div class="col-md-4">
                            <label for="empVersionFE" class="form-label">Versión JSON factura</label>
                            <select class="form-select" id="empVersionFE">
                                <option value="2">2 · DTE 2.0</option>
                                <option value="1">1 · anterior</option>
                            </select>
                        </div>
                        <div class="col-md-4">
                            <label for="empVersionCCF" class="form-label">Versión JSON crédito fiscal</label>
                            <select class="form-select" id="empVersionCCF">
                                <option value="4">4 · DTE 2.0</option>
                                <option value="3">3 · anterior</option>
                            </select>
                        </div>
                        <div class="col-12 small text-muted">DTE 2.0 (obligatorio desde el 1 de diciembre de 2026): la dirección lleva el distrito y cambia la estructura del emisor y del resumen.</div>
                    </div>

                    <hr />
                    <h6 class="mb-3"><i class="bx bx-envelope"></i> Correo de envío del DTE</h6>
                    <div class="row g-3">
                        <div class="col-12">
                            <div class="form-check form-switch">
                                <input class="form-check-input" type="checkbox" role="switch" id="empEnviarCorreo" />
                                <label class="form-check-label" for="empEnviarCorreo">Enviar el PDF y el JSON al cliente al emitir el documento</label>
                            </div>
                        </div>
                        <div class="col-md-6">
                            <label for="empSmtpServidor" class="form-label">Servidor SMTP</label>
                            <input type="text" class="form-control" id="empSmtpServidor" maxlength="150" />
                        </div>
                        <div class="col-md-2">
                            <label for="empSmtpPuerto" class="form-label">Puerto</label>
                            <input type="number" class="form-control" id="empSmtpPuerto" min="1" max="65535" placeholder="465" />
                        </div>
                        <div class="col-md-4">
                            <label for="empSmtpUsuario" class="form-label">Usuario / remitente</label>
                            <input type="email" class="form-control" id="empSmtpUsuario" maxlength="100" />
                        </div>
                        <div class="col-md-6">
                            <label for="empSmtpClave" class="form-label">Clave</label>
                            <input type="password" class="form-control" id="empSmtpClave" maxlength="200" autocomplete="new-password" />
                            <div class="form-text" id="lblClave"></div>
                        </div>
                    </div>
                </div>
                <div class="card-footer text-end">
                    <button type="submit" class="btn btn-primary" id="btnGuardarEmpresa"><i class="bx bx-check"></i> Guardar</button>
                </div>
            </form>
        </div>

        <div class="col-xl-4">
            <div class="card">
                <div class="card-body">
                    <h6 class="mb-3"><i class="bx bx-image"></i> Logo del DTE</h6>
                    <div class="border rounded d-flex align-items-center justify-content-center p-3 mb-3 bg-light" style="min-height:180px">
                        <img id="imgLogo" alt="Logo de la empresa" class="img-fluid d-none" style="max-height:160px" />
                        <span id="sinLogo" class="text-muted small">Sin logo</span>
                    </div>
                    <label for="fileLogo" class="form-label">Imagen PNG o JPG (máx. 2 MB)</label>
                    <input type="file" class="form-control mb-3" id="fileLogo" accept="image/png,image/jpeg" />
                    <div class="d-flex gap-2">
                        <button type="button" class="btn btn-primary flex-fill" id="btnSubirLogo"><i class="bx bx-upload"></i> Subir logo</button>
                        <button type="button" class="btn btn-outline-danger" id="btnQuitarLogo" title="Quitar logo" aria-label="Quitar logo"><i class="bx bx-trash"></i></button>
                    </div>
                    <p class="small text-muted mt-3 mb-0">Se imprime en la parte superior izquierda del PDF del DTE.</p>
                </div>
            </div>
        </div>
    </div>
</div>
</div>

<!-- Firma electrónica: generador de firma (firmador) de Hacienda -->
<div class="tab-pane fade" id="emTabFirma" role="tabpanel">
<div class="row g-3" id="firmaDte">
	<div class="col-xl-7">
		<form class="card radius-10 h-100 mb-0" id="frmFirmador" novalidate autocomplete="off">
			<div class="card-body">
				<h6 class="ad-seccion">Generador de firma (firmador de Hacienda)</h6>
				<div class="row g-3">
					<div class="col-12">
						<label for="fiUrl" class="form-label">Dirección del firmador <span class="text-danger">*</span></label>
						<input type="url" class="form-control" id="fiUrl" maxlength="250" placeholder="http://localhost:8113/firmardocumento/" />
						<div class="form-text">Servicio <em>svfe-api-firmador</em> instalado en el servidor (o en la red). Debe ser accesible desde el servidor del sistema.</div>
					</div>
					<div class="col-md-6">
						<label for="fiNit" class="form-label">NIT del certificado <span class="text-danger">*</span></label>
						<input type="text" class="form-control" id="fiNit" maxlength="17" inputmode="numeric" />
						<div class="form-text" id="fiNitAyuda">Sin guiones. Normalmente es el NIT del emisor.</div>
					</div>
					<div class="col-md-6">
						<label for="fiClave" class="form-label">Contraseña de la llave privada <span class="text-danger">*</span></label>
						<div class="input-group">
							<input type="password" class="form-control" id="fiClave" maxlength="200" autocomplete="new-password" />
							<button type="button" class="btn btn-outline-secondary" id="fiVerClave" title="Mostrar u ocultar" aria-label="Mostrar u ocultar la contraseña"><i class="bx bx-show"></i></button>
						</div>
						<div class="form-text" id="fiClaveAyuda"></div>
					</div>
				</div>
				<div class="alert alert-light border small mt-3 mb-0" id="fiUltima"></div>
			</div>
			<div class="card-footer d-flex flex-wrap gap-2 justify-content-end">
				<button type="button" class="btn btn-outline-primary" id="fiProbar"><i class="bx bx-test-tube"></i> Probar firma</button>
				<button type="submit" class="btn btn-primary" id="fiGuardar"><i class="bx bx-save"></i> Guardar</button>
			</div>
		</form>
	</div>
	<div class="col-xl-5">
		<div class="card radius-10 h-100 mb-0">
			<div class="card-body small">
				<h6 class="ad-seccion">Qué pide Hacienda</h6>
				<ol class="ps-3 mb-3">
					<li>Descargar el certificado de firma electrónica (archivo <code>.crt</code> con el NIT del emisor) desde el portal de facturación electrónica de Hacienda.</li>
					<li>Instalar el <strong>firmador</strong> que entrega Hacienda (<em>svfe-api-firmador</em>) y copiar el certificado en su carpeta de certificados.</li>
					<li>Indicar aquí la dirección del firmador, el NIT y la contraseña de la llave privada que se definió al generar el certificado.</li>
					<li>Usar <strong>Probar firma</strong>: el firmador debe devolver un documento firmado.</li>
				</ol>
				<p class="text-muted mb-1">El firmador recibe el JSON del DTE con <code>nit</code>, <code>activo</code> y <code>passwordPri</code>, y devuelve el documento firmado (JWS) que luego se transmite a Hacienda para obtener el sello de recepción.</p>
				<p class="text-muted mb-0">La contraseña se guarda cifrada y nunca se muestra en pantalla.</p>
			</div>
		</div>
	</div>
</div>
</div>
</div>

<script src="assets/js/administracion.js?v=2"></script>
<script src="assets/js/conf-empresa.js?v=2"></script>
<script src="assets/js/dte-catalogos.js?v=2"></script>
<script src="assets/js/empresa-dte.js?v=6"></script>
<script src="assets/js/firma-dte.js?v=1"></script>
