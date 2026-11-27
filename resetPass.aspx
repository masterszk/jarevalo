<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="resetPass.aspx.cs" Inherits="DPieCenter.resetPass" %>

<!DOCTYPE html>
<html lang="en" data-bs-theme="light">

<head>
	<!-- Required meta tags -->
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<!--favicon-->
	<link rel="icon" href="assets/images/favicon-32x32.png" type="image/png">
	<!-- loader-->
	<link href="assets/css/pace.min.css" rel="stylesheet">
	<script src="assets/js/pace.min.js"></script>
	<!-- Bootstrap CSS -->
	<link href="assets/css/bootstrap.min.css" rel="stylesheet">
	<link href="assets/css/bootstrap-extended.css" rel="stylesheet">
	<link href="https://fonts.googleapis.com/css2?family=Roboto:wght@400;500&display=swap" rel="stylesheet">
	<link href="assets/sass/app.css" rel="stylesheet">
	<link rel="stylesheet" href="assets/sass/dark-theme.css">
	<link href="assets/css/icons.css" rel="stylesheet">
	<title>DPie</title>
</head>

<body>
	<!-- wrapper -->
	<div class="wrapper">
		<div class="authentication-reset-password d-flex align-items-center justify-content-center">
		 <div class="container">
			<div class="row row-cols-1 row-cols-lg-2 row-cols-xl-3">
				<div class="col mx-auto">
					<div class="card">
						<div class="card-body">
							<div class="p-4">
								<div class="mb-4 text-center">
									<img src="assets/images/logo-de-pie.jpg" width="120" alt="" />
								</div>
								<div class="text-start mb-4">
									<h5 class="">Cree una contraseña nueva</h5>
									<p class="mb-0">Su contraseña es la inicial o ya venció. Escriba una contraseña nueva para continuar.</p>
										<div class="alert d-none small mt-3 mb-0" id="rpAviso" role="alert"></div>
								</div>
								<div class="mb-3 mt-4">
									<label class="form-label">Contraseña nueva</label>
									<div class="input-group" id="show_hide_password">
										<input type="password" class="form-control border-end-0" id="inputChoosePassword" placeholder="Mínimo 8 caracteres" autocomplete="new-password" maxlength="50">
										<a href="javascript:;" class="input-group-text bg-transparent" id="rpVer" aria-label="Mostrar contraseña"><i class="bx bx-hide"></i></a>
									</div>
									<div class="form-text">Al menos 8 caracteres y distinta de su usuario.</div>
								</div>
								<div class="mb-4">
									<label class="form-label">Confirme contraseña</label>
									<input type="password" class="form-control" id="confpass" placeholder="Escríbala de nuevo" autocomplete="new-password" maxlength="50" />
								</div>
								<div class="d-grid gap-2">
									<button type="button" id="btnCambiar" class="btn btn-primary">Cambiar contraseña</button> 
									<a href="login.aspx" class="btn btn-light"><i class='bx bx-arrow-back mr-1'></i>Regresar al Inicio de Sesion</a>
								</div>
							</div>
						</div>
					</div>
				</div>
			</div>
		  </div>
		</div>
	</div>
	<!-- end wrapper -->

	<!-- Bootstrap JS -->
	<script src="assets/js/bootstrap.bundle.min.js"></script>
	<!--plugins-->
	<script src="assets/js/jquery.min.js"></script>
	<script src="assets/plugins/simplebar/js/simplebar.min.js"></script>
	<script src="assets/plugins/metismenu/js/metisMenu.min.js"></script>
	<script src="assets/plugins/perfect-scrollbar/js/perfect-scrollbar.js"></script>
	<!--Password show & hide js -->

    <!--notification js -->
	<script src="assets/plugins/notifications/js/lobibox.min.js"></script>
	<script src="assets/plugins/notifications/js/notifications.min.js"></script>

    <!--app JS-->
	<script src="assets/js/utiles.js?v=4"></script>


</body>
	<script type="text/javascript">
		(function ($) {
			'use strict';
			var enviando = false;

			function aviso(tipo, texto) {
				$('#rpAviso').removeClass('d-none alert-danger alert-warning alert-success').addClass('alert-' + tipo).text(texto);
			}

			function cambiar() {
				if (enviando) return;
				var nueva = $('#inputChoosePassword').val(), conf = $('#confpass').val();
				// mismas reglas que el servidor, para avisar antes de enviar
				if (!nueva) { aviso('warning', 'Ingrese la contraseña nueva.'); $('#inputChoosePassword').trigger('focus'); return; }
				if (nueva.length < 8) { aviso('warning', 'La contraseña debe tener al menos 8 caracteres.'); $('#inputChoosePassword').trigger('focus'); return; }
				if (!conf) { aviso('warning', 'Confirme la contraseña nueva.'); $('#confpass').trigger('focus'); return; }
				if (nueva !== conf) { aviso('warning', 'La confirmación no coincide con la contraseña nueva. Escríbalas de nuevo.'); $('#confpass').val('').trigger('focus'); return; }

				enviando = true;
				var $b = $('#btnCambiar').prop('disabled', true).text('Guardando…');
				$.ajax({
					type: 'POST',
					url: 'resetPass.aspx/mtd_ChangePass',
					data: JSON.stringify({ newpass: nueva, conpass: conf, accion: '1' }),
					contentType: 'application/json; charset=utf-8',
					dataType: 'json'
				}).done(function (r) {
					var p = String(r.d || '').split('||');
					if (p[0] === 'OK') {
						aviso('success', 'Contraseña cambiada. Entre de nuevo con su usuario y la contraseña nueva.');
						$b.text('Listo');
						setTimeout(function () { window.location.replace(p[1] || 'login.aspx'); }, 2500);
						return;
					}
					aviso('danger', p[1] || p[0] || 'No fue posible cambiar la contraseña.');
					enviando = false; $b.prop('disabled', false).text('Cambiar contraseña');
				}).fail(function (xhr) {
					enviando = false; $b.prop('disabled', false).text('Cambiar contraseña');
					if (xhr.status !== 401) aviso('danger', 'No hay conexión con el servidor (HTTP ' + xhr.status + '). Intente de nuevo.');
				});
			}

			$('#btnCambiar').on('click', cambiar);
			$('#inputChoosePassword, #confpass').on('keydown', function (ev) { if (ev.key === 'Enter') { ev.preventDefault(); cambiar(); } })
				.on('input', function () { $('#rpAviso').addClass('d-none'); });
			$('#rpVer').on('click', function () {
				var $c = $('#inputChoosePassword'), ver = $c.attr('type') === 'password';
				$c.attr('type', ver ? 'text' : 'password');
				$('#confpass').attr('type', ver ? 'text' : 'password');
				$(this).attr('aria-label', ver ? 'Ocultar contraseña' : 'Mostrar contraseña').find('i').toggleClass('bx-hide', !ver).toggleClass('bx-show', ver);
			});
			$('#inputChoosePassword').trigger('focus');
		})(jQuery);
    </script>
</html>
