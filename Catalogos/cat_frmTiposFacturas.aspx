<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="cat_frmTiposFacturas.aspx.cs" Inherits="DPieCenter.Catalogos.cat_frmTiposFacturas" %>

<link href="assets/css/administracion.css?v=2" rel="stylesheet" />

<div id="catalogo"></div>

<script src="assets/js/catalogo.js?v=3"></script>
<script>
	(function () {
		// Catálogo CAT-002 de Hacienda (tipos de documento tributario electrónico)
		var CAT002 = { '01': 1, '03': 1, '04': 1, '05': 1, '06': 1, '07': 1, '08': 1, '09': 1, '11': 1, '14': 1, '15': 1 };
		Catalogo.iniciar({
			pagina: 'Catalogos/cat_frmTiposFacturas.aspx', titulo: 'Tipos de comprobante', singular: 'tipo de comprobante', icono: 'bx-receipt',
			ayuda: 'Tipos de documento tributario electrónico del catálogo CAT-002 de Hacienda. La caja emite <strong>01 Factura</strong> y <strong>03 Crédito fiscal</strong>; '
				+ 'esos no se pueden inactivar. Un tipo con documentos emitidos no se elimina ni cambia de código.',
			bloqueado: function (x) { return x.Formato === '01' || x.Formato === '03'; },
			campos: [
				{ campo: 'Formato', etiqueta: 'Código de Hacienda (CAT-002)', requerido: true, max: 2, col: 'col-sm-4', placeholder: '01',
				  validar: function (v) { return /^\d{2}$/.test(v) ? '' : 'Dos dígitos, por ejemplo 01.'; } },
				{ campo: 'Descripcion', etiqueta: 'Nombre', requerido: true, max: 200, col: 'col-sm-8' }
			],
			columnas: [
				{ titulo: 'Código', html: function (x, u) { return '<span class="ad-url fw-bold">' + u.esc(x.Formato) + '</span>'; } },
				{ titulo: 'Tipo de comprobante', html: function (x, u) {
					return '<span class="fw-medium">' + u.esc(x.Descripcion) + '</span>'
						+ (x.Digitos === 1 ? ' <span class="ad-chip ad-chip-info" title="La caja emite este tipo">Lo emite la caja</span>' : '')
						+ (CAT002[x.Formato] ? '' : ' <span class="ad-chip ad-chip-no" title="Este código no existe en el catálogo CAT-002 de Hacienda">No es de CAT-002</span>');
				} }
			]
		});

		// Botón para agregar los tipos oficiales que falten
		var $b = $('<button type="button" class="btn btn-outline-secondary"><i class="bx bx-download"></i> Cargar CAT-002</button>')
			.attr('title', 'Agrega los tipos del catálogo CAT-002 de Hacienda que no estén registrados');
		$('#ctNuevo').before($b).parent().addClass('d-flex gap-2');
		$b.on('click', function () {
			$b.prop('disabled', true);
			$.ajax({ type: 'POST', url: 'Catalogos/cat_frmTiposFacturas.aspx/CargarCat002', data: '{}', contentType: 'application/json; charset=utf-8', dataType: 'json' })
				.done(function (r) {
					showNotification(1, r.d.Ok ? 'success' : 'warning', r.d.Mensaje);
					if (r.d.Ok) $('#ctBuscar').val('').trigger('input'), AjaxLink('Catalogos/cat_frmTiposFacturas.aspx', { historial: false });
				})
				.always(function () { $b.prop('disabled', false); });
		});
	})();
</script>
