<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="cat_frmEspecialistas.aspx.cs" Inherits="DPieCenter.Catalogos.cat_frmEspecialistas" %>

<link href="assets/css/administracion.css?v=2" rel="stylesheet" />

<div id="catalogo"></div>

<script src="assets/js/catalogo.js?v=3"></script>
<script>
	Catalogo.iniciar({
		pagina: 'Catalogos/cat_frmEspecialistas.aspx', titulo: 'Especialistas', singular: 'especialista', icono: 'bx-plus-medical',
		ayuda: 'Al vincular un usuario del sistema, ese usuario ve solo sus citas en Procedimientos. Un usuario solo puede estar en un especialista activo.',
		campos: [
			{ campo: 'Descripcion', etiqueta: 'Nombre del especialista', requerido: true, max: 250 },
			{ campo: 'UsuarioSistema', etiqueta: 'Usuario del sistema', tipo: 'select', vacio: 'Sin usuario vinculado',
			  opciones: function (ops) { return ops.map(function (o) { var p = o.Texto.split('|'); return { valor: p[0], texto: p[1] + ' (' + p[0] + ')' }; }); } }
		],
		columnas: [
			{ titulo: 'Especialista', html: function (x, u) { return '<span class="fw-medium">' + u.esc(x.Descripcion) + '</span>'; } },
			{ titulo: 'Usuario del sistema', html: function (x, u) {
				return x.UsuarioSistema ? '<i class="bx bx-user"></i> ' + u.esc(x.PadreTexto || x.UsuarioSistema) + ' <span class="ad-url">' + u.esc(x.UsuarioSistema) + '</span>'
					: '<span class="text-muted small">Sin usuario</span>';
			} }
		]
	});
</script>
