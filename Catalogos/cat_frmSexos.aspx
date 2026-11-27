<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="cat_frmSexos.aspx.cs" Inherits="DPieCenter.Catalogos.cat_frmSexos" %>

<link href="assets/css/administracion.css?v=2" rel="stylesheet" />

<div id="catalogo"></div>

<script src="assets/js/catalogo.js?v=3"></script>
<script>
	Catalogo.iniciar({
		pagina: 'Catalogos/cat_frmSexos.aspx', titulo: 'Sexos', singular: 'registro', icono: 'bx-male-female',
		campos: [{ campo: 'Descripcion', etiqueta: 'Descripción', requerido: true, max: 250 }],
		columnas: [{ titulo: 'Sexo', html: function (x, u) { return '<span class="fw-medium">' + u.esc(x.Descripcion) + '</span>'; } }]
	});
</script>
