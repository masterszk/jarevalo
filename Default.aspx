<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="default.aspx.cs" Inherits="DPieCenter._default" %>

<!doctype html>
<html lang="es" data-bs-theme="light">
<head>
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<link rel="icon" href="assets/images/logo-dpie.png" type="image/png">
	<!--plugins-->
	<link href="assets/plugins/vectormap/jquery-jvectormap-2.0.2.css" rel="stylesheet">
	<link href="assets/plugins/simplebar/css/simplebar.css" rel="stylesheet">
	<link href="https://cdn.jsdelivr.net/npm/flatpickr/dist/flatpickr.min.css" rel="stylesheet" />
	<link href="assets/plugins/perfect-scrollbar/css/perfect-scrollbar.css" rel="stylesheet">
	<link href="assets/plugins/metismenu/css/metisMenu.min.css" rel="stylesheet">
	<link href="assets/plugins/datatable/css/dataTables.bootstrap5.min.css" rel="stylesheet">
	<link rel="stylesheet" href="assets/plugins/notifications/css/lobibox.min.css" />
	<link href="assets/css/pace.min.css" rel="stylesheet"/>
	<script src="assets/js/pace.min.js"></script>
	<link href="assets/css/bootstrap.min.css" rel="stylesheet">
	<link href="assets/css/bootstrap-extended.css" rel="stylesheet">
	<link href="https://fonts.googleapis.com/css2?family=Roboto:wght@400;500&display=swap" rel="stylesheet">
	<link href="assets/sass/app.css" rel="stylesheet">
	<link href="assets/css/icons.css" rel="stylesheet">
	<link href='https://unpkg.com/boxicons@2.1.4/css/boxicons.min.css' rel='stylesheet'>
	<link rel="stylesheet" href="assets/sass/dark-theme.css">
	<link rel="stylesheet" href="assets/sass/semi-dark.css">
	<link rel="stylesheet" href="assets/sass/bordered-theme.css">
	<link href="assets/css/jqueryFileTree.css" rel="stylesheet" />
	<link href="assets/css/sweetalert.min.css" rel="stylesheet" />
	<link href="assets/plugins/fancybox/ekko-lightbox.min.css" rel="stylesheet" />
	<link href="assets/css/jquery-ui-1-8-10.css" rel="stylesheet" />
	<link href="assets/css/principal.css?v=4" rel="stylesheet" />
	<style>
		/* Campana de garantías de servicios (barra superior) */
		#gaCampanaBtn .bx-bell { font-size: 22px; }
		.ga-badge { position: absolute; top: 2px; right: 0; min-width: 18px; height: 18px; padding: 0 5px; border-radius: 9px; background: #dc3545; color: #fff; font-size: 11px; font-weight: 700; line-height: 18px; text-align: center; }
		.ga-menu { width: 380px; max-width: calc(100vw - 24px); }
		.ga-lista { max-height: 380px; overflow-y: auto; }
		.ga-item { padding: 8px 14px; border-bottom: 1px solid rgba(0,0,0,.06); font-size: 13px; }
		.ga-item:last-child { border-bottom: 0; }
		.ga-detalle { display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden; white-space: pre-wrap; }
		@keyframes gaTimbre { 0%,100% { transform: rotate(0); } 20% { transform: rotate(14deg); } 40% { transform: rotate(-12deg); } 60% { transform: rotate(8deg); } 80% { transform: rotate(-4deg); } }
		.ga-sonando .bx-bell { animation: gaTimbre 1s ease-in-out 2; transform-origin: 50% 10%; }
		@media (prefers-reduced-motion: reduce) { .ga-sonando .bx-bell { animation: none; } }
	</style>
	<title>D' Pie Center</title>
</head>

<body>
	<div class="wrapper">
		<!-- Menú lateral -->
		<div class="sidebar-wrapper" data-simplebar="true">
			<div class="sidebar-header">
				<a href="javascript:;" class="d-flex align-items-center gap-2 text-decoration-none" id="prInicioLogo" title="Inicio">
					<img src="assets/images/logo-dpie.png" class="logo-icon pr-logo-icono" alt="D' Pie Center" />
					<img src="assets/images/logo-dpiecenter-clinica.png" class="pr-logo-completo" alt="D' Pie Center - Clínica" />
				</a>
				<div class="mobile-toggle-icon ms-auto"><i class='bx bx-x'></i></div>
			</div>
			<div class="pr-buscar">
				<label for="prBuscarMenu" class="visually-hidden">Buscar en el menú</label>
				<i class="bx bx-search"></i>
				<input type="search" id="prBuscarMenu" class="form-control form-control-sm" placeholder="Buscar opción…" autocomplete="off" />
			</div>
			<ul class="metismenu" id="menu">
				<li>
					<a href="javascript:;" class="menu-opcion" data-url="<%: DashboardUsuario %>" data-titulo="Inicio">
						<div class="parent-icon"><i class="bx bx-home-circle"></i></div>
						<div class="menu-title">Inicio</div>
					</a>
				</li>
				<%=leeModulos(UsuarioActual, Request.QueryString["url"]) %>
			</ul>
			<div class="pr-sin-resultados d-none" id="prSinResultados">Ninguna opción coincide.</div>
		</div>

		<!-- Barra superior -->
		<header>
			<div class="topbar">
				<nav class="navbar navbar-expand gap-2 align-items-center">
					<div class="mobile-toggle-menu d-flex"><i class='bx bx-menu'></i></div>
					<div class="pr-titulo text-truncate" id="prTitulo" aria-live="polite">Dashboard</div>

					<div class="top-menu ms-auto">
						<ul class="navbar-nav align-items-center gap-1">
							<li class="nav-item d-flex align-items-center me-1" title="Sucursal en la que trabaja">
								<i class="bx bx-store-alt text-muted me-1" aria-hidden="true"></i>
								<% if (PuedeCambiarSucursal) { %>
								<label for="prSucursal" class="visually-hidden">Sucursal</label>
								<select id="prSucursal" class="form-select form-select-sm pr-sucursal"><%= OpcionesSucursal %></select>
								<% } else { %>
								<span class="small fw-semibold text-nowrap" id="prSucursalNombre"><%: SucursalActual %></span>
								<% } %>
							</li>
							<!-- Campana: garantías de servicios que el especialista no ha visto (assets/js/campana-garantias.js) -->
							<li class="nav-item dropdown d-none" id="gaCampana">
								<a class="nav-link position-relative" href="javascript:;" id="gaCampanaBtn" data-bs-toggle="dropdown" data-bs-auto-close="outside" aria-expanded="false" title="Garantías de servicios sin ver">
									<i class='bx bx-bell'></i>
									<span class="ga-badge d-none" id="gaCampanaCont">0</span>
								</a>
								<div class="dropdown-menu dropdown-menu-end p-0 ga-menu" aria-labelledby="gaCampanaBtn">
									<div class="d-flex align-items-center gap-2 px-3 py-2 border-bottom">
										<strong class="small">Garantías de servicios</strong>
										<span class="small text-muted ms-auto" id="gaCampanaResumen"></span>
									</div>
									<div id="gaCampanaLista" class="ga-lista"></div>
									<div class="d-flex flex-wrap gap-2 px-3 py-2 border-top" id="gaCampanaPie"></div>
								</div>
							</li>
							<li class="nav-item">
								<a class="nav-link" href="javascript:;" id="prInicio" title="Ir al dashboard"><i class='bx bx-home-alt'></i></a>
							</li>
							<li class="nav-item dark-mode d-none d-sm-flex">
								<a class="nav-link dark-mode-icon" href="javascript:;" title="Modo oscuro"><i class='bx bx-moon'></i></a>
							</li>
						</ul>
					</div>
					<div class="user-box dropdown px-3">
						<input type="hidden" id="idUser" value="<%: UsuarioActual %>" /><input type="hidden" id="prDashboard" value="<%: DashboardUsuario %>" />
						<a class="d-flex align-items-center nav-link dropdown-toggle gap-3 dropdown-toggle-nocaret" href="#" role="button" data-bs-toggle="dropdown" aria-expanded="false">
							<img src="assets/images/user1.png" id="photouser" class="user-img" alt="" onerror="this.src='assets/images/user1.png'">
							<div class="user-info">
								<p class="user-name mb-0" id="nameuser"><%: UsuarioActual %></p>
								<p class="designattion mb-0" id="groupuser"></p>
							</div>
						</a>
						<ul class="dropdown-menu dropdown-menu-end">
							<li class="px-3 py-2 small text-muted border-bottom" id="prUsuarioDetalle"><%: UsuarioActual %></li>
							<li><a class="dropdown-item d-flex align-items-center" href="javascript:;" id="prMenuInicio"><i class="bx bx-home-circle fs-5"></i><span>Dashboard</span></a></li>
							<li><a class="dropdown-item d-flex align-items-center" href="resetPass.aspx"><i class="bx bx-lock fs-5"></i><span>Cambiar contraseña</span></a></li>
							<li><div class="dropdown-divider mb-0"></div></li>
							<li><a class="dropdown-item d-flex align-items-center text-danger" href="javascript:;" id="prSalir"><i class="bx bx-log-out-circle fs-5"></i><span>Cerrar sesión</span></a></li>
						</ul>
					</div>
				</nav>
			</div>
			<div class="pr-progreso" id="prProgreso" aria-hidden="true"></div>
		</header>

		<!-- Contenido (páginas cargadas con AjaxLink) -->
		<div class="page-wrapper">
			<div class="page-content container-xxl" id="content"></div>
		</div>

		<div class="overlay toggle-icon"></div>
		<a href="javaScript:;" class="back-to-top"><i class='bx bxs-up-arrow-alt'></i></a>
		<footer class="page-footer">
			<p class="mb-0">© <span id="prAnio"></span> D' Pie Center · Cuidamos cada paso contigo</p>
		</footer>
	</div>

	<script src="assets/js/bootstrap.bundle.min.js"></script>
	<script src="assets/js/jquery.min.js"></script>
	<script src="assets/js/jquery-ui-1-8-22.js"></script>
	<script src="assets/plugins/simplebar/js/simplebar.min.js"></script>
	<script src="assets/plugins/metismenu/js/metisMenu.min.js"></script>
	<script src="assets/plugins/perfect-scrollbar/js/perfect-scrollbar.js"></script>
	<script src="https://cdn.jsdelivr.net/npm/flatpickr"></script>
	<script src="assets/plugins/datatable/js/jquery.dataTables.min.js"></script>
	<script src="assets/plugins/datatable/js/dataTables.bootstrap5.min.js"></script>
	<script src="assets/plugins/notifications/js/lobibox.min.js"></script>
	<script src="assets/plugins/notifications/js/notifications.min.js"></script>
	<script src="assets/plugins/notifications/js/notification-custom-script.js"></script>
	<script src="assets/js/sweetalert.min.js"></script>
	<script src="assets/js/utiles.js?v=4"></script>
	<script src="assets/plugins/fancybox/ekko-lightbox.min.js"></script>
	<script src="assets/js/jquery.blockUI.js"></script>
	<script src="assets/js/app.js"></script>
	<script src="assets/js/jqueryFileTree.js"></script>
	<script src="assets/js/principal.js?v=7"></script>
	<script src="assets/js/campana-garantias.js?v=1"></script>
</body>

</html>
