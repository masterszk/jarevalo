<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="cat_frmTratamientos.aspx.cs" Inherits="DPieCenter.Catalogos.cat_frmTratamientos" %>

<link href="assets/css/administracion.css?v=2" rel="stylesheet" />

<div id="catalogo"></div>

<script src="assets/js/catalogo.js?v=4"></script>
<script>
	Catalogo.iniciar({
		pagina: 'Catalogos/cat_frmTratamientos.aspx', titulo: 'Tratamientos', singular: 'tratamiento', icono: 'bx-spa', modalGrande: true,
		ayuda: 'El precio y la duración se proponen al registrar procedimientos y citas. Un tratamiento ya usado no se elimina: se inactiva.',
		campos: [
			{ campo: 'Descripcion', etiqueta: 'Nombre', requerido: true, max: 250, col: 'col-md-6' },
			{ campo: 'Duracion', etiqueta: 'Duración (minutos)', tipo: 'numero', requerido: true, min: 0, maxNum: 600, col: 'col-6 col-md-3', defecto: 60,
			  validar: function (v) { return v < 0 || v > 600 ? 'Entre 0 y 600 minutos.' : ''; } },
			{ campo: 'Precio', etiqueta: 'Precio', tipo: 'dinero', requerido: true, col: 'col-6 col-md-3', defecto: '0.00',
			  validar: function (v) { return v < 0 ? 'No puede ser negativo.' : ''; } },
			{ campo: 'Descuento', etiqueta: 'Descuento', tipo: 'porcentaje', col: 'col-6 col-md-3', defecto: '0',
			  ayuda: 'Se aplica al cobrar y se muestra en la factura. 0 = sin descuento.',
			  validar: function (v) { return v < 0 || v >= 100 ? 'Entre 0 y 99.99 %.' : ''; } },
			{ campo: 'Caracteristicas', etiqueta: 'Características', tipo: 'textarea', max: 2000 },
			{ campo: 'Imagen', etiqueta: 'Imagen', tipo: 'imagen' }
		],
		columnas: [
			{ titulo: 'Tratamiento', html: function (x, u) {
				return '<div class="d-flex align-items-center gap-2">' + (x.Imagen ? '<img class="ct-miniatura" src="' + u.esc(x.Imagen) + '" alt="" loading="lazy" onerror="this.style.visibility=\'hidden\'" />' : '')
					+ '<div><div class="fw-medium">' + u.esc(x.Descripcion) + '</div>'
					+ (x.Caracteristicas ? '<div class="ad-ayuda text-truncate" style="max-width:320px">' + u.esc(x.Caracteristicas) + '</div>' : '') + '</div></div>';
			} },
			{ titulo: 'Duración', clase: 'text-end', html: function (x) { return x.Duracion + ' min'; } },
			{ titulo: 'Precio', clase: 'text-end', html: function (x, u) {
				if (!(x.Descuento > 0)) return u.dinero(x.Precio);
				var neto = Math.round((x.Precio - Math.round(x.Precio * x.Descuento) / 100) * 100) / 100;
				return '<span class="text-decoration-line-through text-muted small">' + u.dinero(x.Precio) + '</span> ' + u.dinero(neto)
					+ '<div><span class="badge bg-success">-' + Number(x.Descuento) + ' %</span></div>';
			} }
		]
	});
</script>
