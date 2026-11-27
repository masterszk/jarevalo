/* Sesión expirada: el servidor (Seguridad/AccesoModule.cs) responde 401 a las llamadas AJAX sin sesión -> volver al login */
(function () {
	if (!window.jQuery) return;
	var avisado = false;
	$(document).ajaxError(function (e, xhr) {
		if (!xhr || xhr.status !== 401 || avisado) return;
		avisado = true;
		var ir = function () { window.location.href = 'login.aspx'; };
		if (window.swal) { swal({ title: 'Sesión expirada', text: 'Vuelva a iniciar sesión.', type: 'warning' }, ir); }
		else { ir(); }
	});
})();

function isTextoVacio(texto, campo) {

	var valid = {
		'message': '<strong>' + campo + '</strong> es requerido.',
		'respuesta': texto != '' ? true : false
	}

	return valid;
}

function isSelectedValid(elementID, valorNoValido, campo) {

	var valid = {
		'message': '<strong>' + campo + '</strong> es requerido.',
		'respuesta': $('#' + elementID + ' option:selected').val() != valorNoValido ? true : false
	}

	return valid;

}

function isGreaterThan(elemento, valorAComparar, campo) {

	var valid = {
		'message': '<strong>' + campo + '</strong> debe ser mayor que ' + valorAComparar,
		'respuesta': elemento > valorAComparar ? true : false
	}

	return valid;
}

function isLessThan(elemento, valorAComparar, campo) {

	var valid = {
		'message': '<strong>' + campo + '</strong> debe ser menor que ' + valorAComparar,
		'respuesta': elemento < valorAComparar ? true : false
	}

	return valid;
}

function bloquearPantallaCompleta(mensaje) {
	$.blockUI({
		css: { border: 'none', backgroundColor: 'transparent', color: '#FFF', left: '40%' },
		overlayCSS: { backgroundColor: '#42A1C4', opacity: 0.7 },
		message: '<h3>' + mensaje + ' por favor espere...</h3>'
	});
}

/* Horas en formato de 12 horas para mostrar en pantalla (los valores que se envían al servidor siguen en 24 h).
   hora12('14:30') → '02:30 PM'; también convierte las horas dentro de un texto ('31/10/2026 14:30' → '31/10/2026 02:30 PM').
   Las fechas ISO (2026-10-31T14:30:00) no se tocan. */
function hora12(texto) {
	if (texto == null) return '';
	return String(texto).replace(/\b([01]\d|2[0-3]):([0-5]\d)(:[0-5]\d)?\b(?!\s*[AaPp]\.?\s?[Mm])/g, function (_, h, m, s) {
		h = +h;
		var sufijo = h < 12 ? 'AM' : 'PM';
		h = h % 12 || 12;
		return (h < 10 ? '0' : '') + h + ':' + m + (s || '') + ' ' + sufijo;
	});
}

/* Hora de un objeto Date en 12 horas: horaDe(new Date()) → '02:30 PM'; con segundos → '02:30:15 PM' */
function horaDe(d, conSegundos) {
	var dos = function (n) { return (n < 10 ? '0' : '') + n; };
	return hora12(dos(d.getHours()) + ':' + dos(d.getMinutes()) + (conSegundos ? ':' + dos(d.getSeconds()) : ''));
}

function getFirstDay() {
	var date = new Date();
	var y = date.getFullYear();
	var m = date.getMonth();
	var d = date.getDate();

	var firstDay = new Date(y, m, d);
	return firstDay;
}
function showNotification(position, type, message) {
	var pos;
	var icon;

	// lobibox.min.js busca los sonidos en /sounds/, que no existe
	if (window.Lobibox && Lobibox.notify && Lobibox.notify.DEFAULTS) Lobibox.notify.DEFAULTS.soundPath = 'assets/plugins/notifications/sounds/';

	//type { 'default', 'info', 'success', 'warning', 'error' }

	if (position == 1) 
		pos = 'top right';
	else if (position == 2) 
		pos = 'top center';
	else if (position == 3) 
		pos = 'top left';
	else if (position == 4) 
		pos = 'bottom right';
	else if (position == 5) 
		pos = 'bottom left';

	if (type == 'info')
		icon = 'bx bx-info-circle';
	else if (type == 'warning')
		icon = 'bx bx-error';
	else if (type == 'error')
		icon = 'bx bx-x-circle';
	else if (type == 'success')
		icon = 'bx bx-check-circle';



	Lobibox.notify(type, {
		pauseDelayOnHover: true,
		continueDelayOnInactiveTab: false,
		position: pos,
		icon: icon,
		msg: message
	});
}

function showConfirmElimina() {
	swal({
		title: 'Confirmar eliminacion',
		text: 'Desea eliminar el elemento seleccionado?',
		type: 'warning',
		showCancelButton: true,
		confirmButtonText: 'Confirmar',
		cancelButtonText: 'Cancelar',
		confirmButtonColor: "#DD6B55",
		cancelButtonClass: "btn btn-block btn-default",
		buttonsStyling: false
	}, function (isConfirm) {
		if (isConfirm)
			mtd_Eliminar();
	});
}

function showConfirmEliminaById(id) {
	swal({
		title: 'Confirmar eliminacion',
		text: 'Desea eliminar el elemento seleccionado?',
		type: 'warning',
		showCancelButton: true,
		confirmButtonText: 'Confirmar',
		cancelButtonText: 'Cancelar',
		confirmButtonColor: "#DD6B55",
		cancelButtonClass: "btn btn-block btn-default",
		buttonsStyling: false
	}, function (isConfirm) {
		if (isConfirm)
			mtd_Eliminar(id,3);
	});
}

function showConfirmAnulacion(id, accion, cita) {
	swal({
		title: 'Confirmar Anulacion',
		text: 'Desea anular el elemento seleccionado?',
		type: 'warning',
		showCancelButton: true,
		confirmButtonText: 'Confirmar',
		cancelButtonText: 'Cancelar',
		confirmButtonColor: "#DD6B55",
		cancelButtonClass: "btn btn-block btn-default",
		buttonsStyling: false
	}, function (isConfirm) {
		if (isConfirm)
			mtd_AnulaTto(id, accion, cita)
	});
}

