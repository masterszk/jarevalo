<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="cat_TiposCitas.aspx.cs" Inherits="DPieCenter.Catalogos.cat_TiposCitas" %>

<link href="assets/css/administracion.css?v=2" rel="stylesheet" />

<div id="catalogo"></div>

<script src="assets/js/catalogo.js?v=3"></script>
<script>
	Catalogo.iniciar({
		pagina: 'Catalogos/cat_TiposCitas.aspx', titulo: 'Tipos de cita', singular: 'tipo de cita', icono: 'bx-category',
		campos: [{ campo: 'Descripcion', etiqueta: 'Nombre', requerido: true, max: 200 }],
		columnas: [{ titulo: 'Tipo de cita', html: function (x, u) { return '<span class="fw-medium">' + u.esc(x.Descripcion) + '</span>'; } }]
	});
</script>
