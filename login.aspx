<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="login.aspx.cs" Inherits="DPieCenter.login" %>

<!doctype html>
<html lang="es" data-bs-theme="light">

<head>
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<link rel="icon" href="assets/images/logo-dpie.png" type="image/png">
	<link rel="stylesheet" href="assets/plugins/notifications/css/lobibox.min.css" />
	<link href="assets/css/bootstrap.min.css" rel="stylesheet">
	<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
	<link href="https://unpkg.com/boxicons@2.1.4/css/boxicons.min.css" rel="stylesheet">
	<link href="assets/css/login.css?v=4" rel="stylesheet">
	<title>Iniciar sesión - D' Pie Center</title>
</head>

<body>
	<main class="lg">
		<!-- Panel de marca (pantallas grandes) -->
		<!-- La imagen ya trae el logo, el eslogan y los valores de la clínica -->
		<section class="lg-marca d-none d-lg-flex">
			<img src="assets/images/login-images/login-cover.jpg" alt="Clínica D' Pie Center: especialistas en el cuidado y salud de tus pies" class="lg-marca-imagen" />
		</section>

		<!-- Formulario -->
		<section class="lg-panel">
			<div class="lg-tarjeta">
				<div class="text-center mb-4">
					<img src="assets/images/logo-dpiecenter-clinica.png" alt="D' Pie Center - Clínica" class="lg-logo" />
					<h1 class="lg-titulo">Bienvenido</h1>
					<p class="text-muted mb-0">Ingrese con su usuario del sistema</p>
				</div>

				<div class="alert d-none" role="alert" id="lgAviso" aria-live="assertive"></div>

				<form id="lgForm" novalidate autocomplete="on">
					<div class="mb-3">
						<label for="inputEmailAddress" class="form-label">Usuario</label>
						<div class="input-group">
							<span class="input-group-text"><i class="bx bx-user"></i></span>
							<input type="text" class="form-control" id="inputEmailAddress" name="username" autocomplete="username"
								autocapitalize="none" spellcheck="false" maxlength="20" required>
						</div>
					</div>
					<div class="mb-2">
						<label for="inputChoosePassword" class="form-label">Contraseña</label>
						<div class="input-group">
							<span class="input-group-text"><i class="bx bx-lock-alt"></i></span>
							<input type="password" class="form-control" id="inputChoosePassword" name="password" autocomplete="current-password" required>
							<button type="button" class="btn btn-outline-secondary lg-ver" id="lgVerClave" aria-label="Mostrar contraseña" title="Mostrar contraseña"><i class="bx bx-hide"></i></button>
						</div>
						<div class="form-text text-warning d-none" id="lgMayus"><i class="bx bx-error"></i> Bloq Mayús está activado</div>
					</div>
					<div class="d-flex justify-content-between align-items-center mb-4">
						<div class="form-check form-switch">
							<input class="form-check-input" type="checkbox" id="flexSwitchCheckChecked">
							<label class="form-check-label" for="flexSwitchCheckChecked">Recordar usuario</label>
						</div>
						<a href="recuperarClave.aspx">¿Olvidó su contraseña?</a>
					</div>
					<div class="d-grid">
						<button type="submit" id="btnEntrar" class="btn btn-primary btn-lg lg-entrar">
							<span class="spinner-border spinner-border-sm me-2 d-none" role="status" aria-hidden="true"></span>
							<span class="lg-entrar-texto">Entrar</span>
						</button>
					</div>
				</form>

				<p class="lg-pie">© <span id="lgAnio"></span> D' Pie Center · Uso exclusivo del personal de la clínica</p>
			</div>
		</section>
	</main>

	<script src="assets/js/bootstrap.bundle.min.js"></script>
	<script src="assets/js/jquery.min.js"></script>
	<script src="assets/plugins/notifications/js/lobibox.min.js"></script>
	<script src="assets/plugins/notifications/js/notifications.min.js"></script>
	<script src="assets/js/utiles.js"></script>
	<script src="assets/js/login.js?v=1"></script>
</body>

</html>
