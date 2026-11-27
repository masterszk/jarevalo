<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="frm_TurnosPacientes.aspx.cs" Inherits="DPieCenter.Registros.frm_TurnosPacientes" %>

<!DOCTYPE html>
<html lang="es">
<head>
	<meta charset="utf-8" />
	<meta name="viewport" content="width=device-width, initial-scale=1" />
	<title>Turnos - D' Pie Center</title>
	<link rel="icon" href="../assets/images/logo-dpie.png" type="image/png" />
	<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet" />
	<link href="https://unpkg.com/boxicons@2.1.4/css/boxicons.min.css" rel="stylesheet" />
	<link href="../assets/css/turnos-pacientes.css?v=4" rel="stylesheet" />
</head>
<body>
	<div class="tp" id="turnos" data-especialista="<%: Request.QueryString["esp"] %>" data-sucursal="<%: SucursalPantalla %>">
		<header class="tp-cabecera">
			<img src="../assets/images/logo-dpiecenter-trans.png" alt="D' Pie Center" class="tp-logo" />
			<div class="tp-titulo">
				<h1>Turnos de atención</h1>
				<p id="tpFecha"></p>
			</div>
			<div class="tp-reloj" id="tpReloj" aria-live="off">--:--</div>
			<div class="tp-botones">
				<button type="button" id="tpSonido" class="tp-boton" title="Activar sonido al llamar un paciente"><i class="bx bx-volume-mute"></i></button>
				<button type="button" id="tpPantalla" class="tp-boton" title="Pantalla completa"><i class="bx bx-fullscreen"></i></button>
			</div>
		</header>

		<main class="tp-cuerpo">
			<!-- 70%: videos publicitarios (assets/publicidad) -->
			<section class="tp-publicidad" aria-label="Publicidad">
				<video id="tpVideo" muted playsinline preload="auto"></video>
				<div class="tp-sin-video" id="tpSinVideo">
					<img src="../assets/images/logo-dpiecenter-trans.png" alt="" />
					<p>Cuidamos tus pies</p>
				</div>
			</section>

			<!-- 30%: turnos -->
			<aside class="tp-turnos">
				<section aria-labelledby="tpAtendiendoTitulo">
					<h2 id="tpAtendiendoTitulo"><i class="bx bx-user-voice"></i> Atendiendo</h2>
					<div id="tpAtendiendo" class="tp-tarjetas" aria-live="polite"></div>
				</section>
				<section class="tp-siguientes" aria-labelledby="tpSiguientesTitulo">
					<h2 id="tpSiguientesTitulo"><i class="bx bx-time-five"></i> Próximos turnos</h2>
					<ol id="tpSiguientes" class="tp-lista"></ol>
				</section>
			</aside>
		</main>

		<footer class="tp-pie">
			<span><i class="bx bx-info-circle"></i> Esté atento a su nombre. Si su cita ya pasó, acérquese a recepción.</span>
			<span id="tpEstado" class="tp-estado"></span>
		</footer>
	</div>

	<div class="tp-aviso" id="tpAviso" role="alert" aria-live="assertive">
		<div class="tp-aviso-caja">
			<div class="tp-aviso-titulo">Pase a consulta</div>
			<div class="tp-aviso-nombre" id="tpAvisoNombre"></div>
			<div class="tp-aviso-con" id="tpAvisoCon"></div>
		</div>
	</div>

	<script src="../assets/js/jquery.min.js"></script>
	<script src="../assets/js/turnos-pacientes.js?v=10"></script>
</body>
</html>
