<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="cat_frmEstadosCitas.aspx.cs" Inherits="DPieCenter.Catalogos.cat_frmEstadosCitas" %>

<link href="assets/css/administracion.css?v=2" rel="stylesheet" />

<div id="catalogo"></div>

<script src="assets/js/catalogo.js?v=3"></script>
<script>
	var sistema = function (x) { return x.Id >= 1 && x.Id <= 7; };
	Catalogo.iniciar({
		pagina: 'Catalogos/cat_frmEstadosCitas.aspx', titulo: 'Estados de las citas', singular: 'estado', icono: 'bx-flag', bloqueado: sistema,
		ayuda: 'Los estados 1 a 7 los usa la agenda y la atención de pacientes: de ellos solo se puede cambiar el nombre y el color.',
		campos: [
			{ campo: 'Descripcion', etiqueta: 'Nombre', requerido: true, max: 250 },
			{ campo: 'Color', etiqueta: 'Color', tipo: 'color', requerido: true, defecto: 'info',
			  colores: [{ valor: 'info', texto: 'Azul' }, { valor: 'primary', texto: 'Turquesa' }, { valor: 'success', texto: 'Verde' }, { valor: 'warning', texto: 'Naranja' }, { valor: 'danger', texto: 'Rojo' }, { valor: 'secondary', texto: 'Gris' }] },
			{ campo: 'Procesos', etiqueta: 'Cita vigente', tipo: 'check', ayuda: 'Cuenta como pendiente en la agenda y en la cola de atención.', soloLectura: sistema },
			{ campo: 'Cancelada', etiqueta: 'Es el estado de cita cancelada', tipo: 'check', soloLectura: sistema },
			{ campo: 'Finalizada', etiqueta: 'Es el estado de cita atendida', tipo: 'check', soloLectura: sistema }
		],
		columnas: [
			{ titulo: '#', clase: 'text-muted', html: function (x) { return x.Id; } },
			{ titulo: 'Estado', html: function (x, u) { return '<span class="badge bg-' + u.esc(x.Color || 'secondary').toLowerCase() + '">' + u.esc(x.Descripcion) + '</span>' + (sistema(x) ? ' <i class="bx bx-lock-alt text-muted" title="Lo usa el sistema"></i>' : ''); } },
			{ titulo: 'Tipo', html: function (x) {
				return x.Cancelada ? '<span class="ad-chip ad-chip-no">Cancelada</span>' : x.Finalizada ? '<span class="ad-chip ad-chip-ok">Atendida</span>'
					: x.Procesos ? '<span class="ad-chip ad-chip-info">Vigente</span>' : '<span class="ad-chip">Cerrada</span>';
			} }
		]
	});
</script>
