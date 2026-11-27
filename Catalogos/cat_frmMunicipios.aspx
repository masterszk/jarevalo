<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="cat_frmMunicipios.aspx.cs" Inherits="DPieCenter.Catalogos.cat_frmMunicipios" %>

<link href="assets/css/administracion.css?v=2" rel="stylesheet" />

<div id="catalogo"></div>

<script src="assets/js/catalogo.js?v=3"></script>
<script>
	Catalogo.iniciar({
		pagina: 'Catalogos/cat_frmMunicipios.aspx', titulo: 'Municipios', singular: 'municipio', icono: 'bx-map-pin', activable: false, filtroPadre: 'Departamento',
		ayuda: 'Un municipio que ya usan expedientes o los datos de la empresa no se puede eliminar.',
		campos: [
			{ campo: 'Descripcion', etiqueta: 'Nombre', requerido: true, max: 250 },
			{ campo: 'Padre', etiqueta: 'Departamento', tipo: 'select', requerido: true, numerico: true,
			  opciones: function (ops) { return ops.map(function (o) { return { valor: o.Id, texto: o.Texto }; }); } }
		],
		columnas: [
			{ titulo: 'Municipio', html: function (x, u) { return '<span class="fw-medium">' + u.esc(x.Descripcion) + '</span>'; } },
			{ titulo: 'Departamento', html: function (x, u) { return u.esc(x.PadreTexto); } }
		]
	});
</script>
