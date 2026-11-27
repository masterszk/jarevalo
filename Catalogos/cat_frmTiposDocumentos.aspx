<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="cat_frmTiposDocumentos.aspx.cs" Inherits="DPieCenter.Catalogos.cat_frmTiposDocumentos" %>

<link href="assets/css/administracion.css?v=2" rel="stylesheet" />

<div id="catalogo"></div>

<script src="assets/js/catalogo.js?v=3"></script>
<script>
	Catalogo.iniciar({
		pagina: 'Catalogos/cat_frmTiposDocumentos.aspx', titulo: 'Tipos de documento', singular: 'tipo de documento', icono: 'bx-id-card',
		campos: [
			{ campo: 'Descripcion', etiqueta: 'Nombre', requerido: true, max: 100 },
			{ campo: 'Digitos', etiqueta: 'Cantidad de caracteres', tipo: 'numero', min: 0, maxNum: 30, col: 'col-6', defecto: 0, ayuda: '0 = sin límite.',
			  validar: function (v) { return v !== null && (v < 0 || v > 30) ? 'Entre 0 y 30.' : ''; } },
			{ campo: 'Formato', etiqueta: 'Formato', max: 20, col: 'col-6', placeholder: 'XXXXXXXX-X', ayuda: 'X representa cada dígito.' }
		],
		columnas: [
			{ titulo: 'Documento', html: function (x, u) { return '<span class="fw-medium">' + u.esc(x.Descripcion) + '</span>'; } },
			{ titulo: 'Formato', html: function (x, u) { return x.Formato && x.Formato !== 'X' ? '<span class="ad-url">' + u.esc(x.Formato) + '</span>' : '<span class="text-muted small">Libre</span>'; } },
			{ titulo: 'Caracteres', clase: 'text-end', html: function (x) { return x.Digitos || '—'; } }
		]
	});
</script>
