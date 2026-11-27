<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="recuperarClave.aspx.cs" Inherits="DPieCenter.recuperarClave" %>

<!doctype html>
<html lang="es" data-bs-theme="light">

<head>
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<meta name="robots" content="noindex">
	<link rel="icon" href="assets/images/logo-dpie.png" type="image/png">
	<link rel="stylesheet" href="assets/plugins/notifications/css/lobibox.min.css" />
	<link href="assets/css/bootstrap.min.css" rel="stylesheet">
	<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
	<link href="https://unpkg.com/boxicons@2.1.4/css/boxicons.min.css" rel="stylesheet">
	<link href="assets/css/login.css?v=4" rel="stylesheet">
	<title>Recuperar contraseña - D' Pie Center</title>
</head>

<body>
	<main class="lg">
		<section class="lg-marca d-none d-lg-flex">
			<img src="assets/images/login-images/login-cover.jpg" alt="Clínica D' Pie Center: especialistas en el cuidado y salud de tus pies" class="lg-marca-imagen" />
		</section>

		<section class="lg-panel">
			<div class="lg-tarjeta">
				<div class="text-center mb-4">
					<img src="assets/images/logo-dpiecenter-clinica.png" alt="D' Pie Center - Clínica" class="lg-logo" />
					<h1 class="lg-titulo">Recuperar contraseña</h1>
				</div>

				<ol class="rc-pasos" aria-label="Pasos">
					<li data-paso="1" class="activo"><span>1</span> Usuario</li>
					<li data-paso="2"><span>2</span> Código</li>
					<li data-paso="3"><span>3</span> Contraseña</li>
				</ol>

				<div class="alert d-none" role="alert" id="rcAviso" aria-live="assertive"></div>

				<!-- Paso 1: usuario (el código va al correo registrado en ese usuario) -->
				<form id="rcPaso1" class="rc-paso" novalidate>
					<p class="text-muted small">Escriba su usuario, el mismo con el que inicia sesión. Le enviaremos un código de 6 dígitos al correo registrado en su usuario.</p>
					<div class="mb-4">
						<label for="rcEmail" class="form-label">Usuario</label>
						<div class="input-group">
							<span class="input-group-text"><i class="bx bx-user"></i></span>
							<input type="text" class="form-control" id="rcEmail" autocomplete="username" maxlength="20" spellcheck="false" autocapitalize="off" required>
						</div>
					</div>
					<div class="d-grid">
						<button type="submit" class="btn btn-primary btn-lg lg-entrar" id="rcEnviar">
							<span class="spinner-border spinner-border-sm me-2 d-none" aria-hidden="true"></span><span class="rc-texto">Enviar código</span>
						</button>
					</div>
				</form>

				<!-- Paso 2: código -->
				<form id="rcPaso2" class="rc-paso d-none" novalidate>
					<p class="text-muted small mb-3" id="rcEnviadoA"></p>
					<div class="mb-3">
						<label for="rcCodigo" class="form-label">Código de 6 dígitos</label>
						<input type="text" class="form-control form-control-lg rc-codigo" id="rcCodigo" inputmode="numeric" autocomplete="one-time-code"
							maxlength="6" pattern="\d{6}" placeholder="••••••" required>
						<div class="form-text">El código vence en 10 minutos.</div>
					</div>
					<div class="d-grid mb-3">
						<button type="submit" class="btn btn-primary btn-lg lg-entrar" id="rcValidar">
							<span class="spinner-border spinner-border-sm me-2 d-none" aria-hidden="true"></span><span class="rc-texto">Validar código</span>
						</button>
					</div>
					<div class="d-flex justify-content-between small">
						<a href="javascript:;" id="rcOtroCorreo"><i class="bx bx-arrow-back"></i> Cambiar usuario</a>
						<a href="javascript:;" id="rcReenviar">Reenviar código</a>
					</div>
				</form>

				<!-- Paso 3: nueva contraseña -->
				<form id="rcPaso3" class="rc-paso d-none" novalidate>
					<input type="text" class="d-none" id="rcUsuarioOculto" autocomplete="username" tabindex="-1" aria-hidden="true">
					<div class="mb-3">
						<label for="rcClave" class="form-label">Nueva contraseña</label>
						<div class="input-group">
							<span class="input-group-text"><i class="bx bx-lock-alt"></i></span>
							<input type="password" class="form-control" id="rcClave" autocomplete="new-password" maxlength="50" required>
							<button type="button" class="btn btn-outline-secondary lg-ver rc-ver" data-campo="rcClave" aria-label="Mostrar contraseña" title="Mostrar contraseña"><i class="bx bx-hide"></i></button>
						</div>
						<ul class="rc-reglas" id="rcReglas">
							<li data-regla="largo">Al menos 8 caracteres</li>
							<li data-regla="letra">Letras</li>
							<li data-regla="numero">Números</li>
						</ul>
					</div>
					<div class="mb-4">
						<label for="rcConfirmar" class="form-label">Confirme la contraseña</label>
						<div class="input-group">
							<span class="input-group-text"><i class="bx bx-lock"></i></span>
							<input type="password" class="form-control" id="rcConfirmar" autocomplete="new-password" maxlength="50" required>
							<button type="button" class="btn btn-outline-secondary lg-ver rc-ver" data-campo="rcConfirmar" aria-label="Mostrar contraseña" title="Mostrar contraseña"><i class="bx bx-hide"></i></button>
						</div>
					</div>
					<div class="d-grid">
						<button type="submit" class="btn btn-primary btn-lg lg-entrar" id="rcCambiar">
							<span class="spinner-border spinner-border-sm me-2 d-none" aria-hidden="true"></span><span class="rc-texto">Cambiar contraseña</span>
						</button>
					</div>
				</form>

				<!-- Listo -->
				<div id="rcListo" class="rc-paso d-none text-center">
					<i class="bx bx-check-circle rc-listo-icono"></i>
					<p class="fw-semibold mb-1">Contraseña cambiada</p>
					<p class="text-muted small">Ya puede iniciar sesión con su nueva contraseña.</p>
					<div class="d-grid"><a href="login.aspx" class="btn btn-primary btn-lg lg-entrar rc-boton">Ir a iniciar sesión</a></div>
				</div>

				<p class="text-center mt-4 mb-0" id="rcVolver"><a href="login.aspx"><i class="bx bx-arrow-back"></i> Volver a iniciar sesión</a></p>
				<p class="lg-pie">© <span id="rcAnio"></span> D' Pie Center · Uso exclusivo del personal de la clínica</p>
			</div>
		</section>
	</main>

	<script src="assets/js/bootstrap.bundle.min.js"></script>
	<script src="assets/js/jquery.min.js"></script>
	<script src="assets/js/recuperar-clave.js?v=3"></script>
</body>

</html>
