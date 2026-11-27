<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="cat_frmHorarios.aspx.cs" Inherits="DPieCenter.Catalogos.cat_frmHorarios" %>

<link href="assets/css/administracion.css?v=2" rel="stylesheet" />

<div id="catalogo"></div>

<script src="assets/js/catalogo.js?v=3"></script>
<script>
	Catalogo.iniciar({
		pagina: 'Catalogos/cat_frmHorarios.aspx', titulo: 'Horarios', singular: 'horario', icono: 'bx-time-five',
		ayuda: 'Horas que se ofrecen para las citas antiguas. Las citas nuevas guardan su hora de inicio y fin.',
		campos: [
			{ campo: 'Hora', etiqueta: 'Hora', tipo: 'hora', requerido: true, col: 'col-6' },
			{ campo: 'Descripcion', etiqueta: 'Texto a mostrar', requerido: true, max: 250, col: 'col-6', placeholder: '08:00' }
		],
		columnas: [
			{ titulo: 'Hora', html: function (x, u) { return '<span class="fw-medium">' + u.esc(x.Hora) + '</span>'; } },
			{ titulo: 'Texto', html: function (x, u) { return u.esc(x.Descripcion); } }
		]
	});
	$('#catalogo').on('change', '#ct_Hora', function () { if (!$.trim($('#ct_Descripcion').val())) $('#ct_Descripcion').val($(this).val()); });
</script>
