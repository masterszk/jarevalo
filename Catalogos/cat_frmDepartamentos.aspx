<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="cat_frmDepartamentos.aspx.cs" Inherits="DPieCenter.Catalogos.cat_frmDepartamentos" %>

<link href="assets/css/administracion.css?v=2" rel="stylesheet" />

<div id="catalogo"></div>

<script src="assets/js/catalogo.js?v=3"></script>
<script>
	Catalogo.iniciar({
		pagina: 'Catalogos/cat_frmDepartamentos.aspx', titulo: 'Departamentos', singular: 'departamento', icono: 'bx-map', activable: false,
		ayuda: 'Un departamento con municipios no se puede eliminar.',
		campos: [{ campo: 'Descripcion', etiqueta: 'Nombre', requerido: true, max: 250 }],
		columnas: [{ titulo: 'Departamento', html: function (x, u) { return '<span class="fw-medium">' + u.esc(x.Descripcion) + '</span>'; } }]
	});
</script>
