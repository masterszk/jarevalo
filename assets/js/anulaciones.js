/* Anulaciones de DTE – Facturacion/frm_Anulaciones.aspx
   Lista los documentos emitidos con su plazo de anulación (FAC_DTE_PLAZOSINVALIDACION) y registra el evento de invalidación. */
(function ($) {
    'use strict';

    var URL = 'Facturacion/frm_Anulaciones.aspx/';
    var POR_PAGINA = 50;
    var TIPOS_DOC = [{ v: '13', t: 'DUI' }, { v: '36', t: 'NIT' }, { v: '03', t: 'Pasaporte' }, { v: '02', t: 'Carnet de residente' }, { v: '37', t: 'Otro' }];
    var TIPOS_ANULACION = { 1: 'Error en la información', 2: 'Rescindir la operación', 3: 'Otro motivo' };
    var state = { inicio: null, items: [], vista: 'plazo', pagina: 1, timer: null, actual: null };

    /* ---------- utilidades ---------- */
    function api(metodo, datos) {
        return $.ajax({ type: 'POST', url: URL + metodo, data: JSON.stringify(datos || {}), contentType: 'application/json; charset=utf-8', dataType: 'json' })
            .then(function (r) { return r.d; });
    }
    function falla(xhr) { if (xhr && xhr.statusText !== 'abort') showNotification(1, 'error', 'Error de conexión (HTTP ' + xhr.status + ').'); }
    function error(r) {
        var m = (r && r.Mensaje) || 'No fue posible completar la acción.';
        if (/sesi[oó]n/i.test(m) && typeof mtd_ValidateSession === 'function') { mtd_ValidateSession(); return; }
        showNotification(1, 'warning', m);
    }
    function esc(s) { return $('<div/>').text(s == null ? '' : String(s)).html(); }
    function dinero(n) { return '$ ' + Number(n || 0).toLocaleString('es-SV', { minimumFractionDigits: 2, maximumFractionDigits: 2 }); }
    function titulo(s) { return String(s || '').toLowerCase().replace(/(^|\s)(\S)/g, function (m, a, b) { return a + b.toUpperCase(); }); }
    function dos(n) { return (n < 10 ? '0' : '') + n; }
    function iso(d) { return d.getFullYear() + '-' + dos(d.getMonth() + 1) + '-' + dos(d.getDate()); }
    function fecha(s) { if (!s) return ''; var p = s.substr(0, 10).split('-'); return p[2] + '/' + p[1] + '/' + p[0]; }
    function tipoDte(t) { return t === '03' ? 'Crédito fiscal' : t === '01' ? 'Factura' : 'DTE ' + t; }

    /* ---------- inicio ---------- */
    function iniciar() {
        $('.an-tipodoc').html(TIPOS_DOC.map(function (x) { return '<option value="' + x.v + '">' + x.t + '</option>'; }).join(''));
        api('Inicio').done(function (r) {
            if (!r.Ok) { error(r); return; }
            state.inicio = r;
            $('#anCajero').html('<option value="">Todos</option>' + (r.Cajeros || []).map(function (c) {
                return '<option value="' + esc(c[0]) + '">' + esc(c[1] || c[0]) + '</option>';
            }).join(''));
            pintarPlazos();
            $('#anPlazosBtn').toggleClass('d-none', !r.EsAdministrador);
            rango('90');
        }).fail(falla);
    }

    function pintarPlazos() {
        var p = state.inicio.Plazos || [];
        $('#anPlazosTexto').html(p.map(function (x) { return '<strong>' + esc(x.Descripcion) + '</strong> ' + x.Dias + (x.Dias === 1 ? ' día' : ' días'); }).join(' · '));
        $('#anPlazosLista').html(p.map(function (x) {
            return '<div class="d-flex align-items-center gap-2 mb-2"><span class="flex-fill">' + esc(x.Descripcion) + (x.Usuario ? '<div class="ad-ayuda">Cambiado por ' + esc(x.Usuario) + ' el ' + fecha(x.Fecha) + '</div>' : '') + '</span>'
                + '<div class="input-group input-group-sm" style="width:150px"><input type="number" class="form-control text-end an-dias" min="0" max="365" value="' + x.Dias + '" data-tipo="' + x.TipoDte + '" aria-label="Días" />'
                + '<span class="input-group-text">días</span></div>'
                + '<button type="button" class="btn btn-sm btn-primary an-guardar-plazo" data-tipo="' + x.TipoDte + '"><i class="bx bx-save"></i></button></div>';
        }).join(''));
    }

    /* ---------- lista ---------- */
    function rango(r) {
        var hoy = new Date(), d = new Date(hoy);
        if (r === 'todo') { $('#anDesde, #anHasta').val(''); }
        else {
            if (r === '7') d.setDate(hoy.getDate() - 6);
            else if (r === '90') d.setDate(hoy.getDate() - 89);
            else if (r === 'mes') d = new Date(hoy.getFullYear(), hoy.getMonth(), 1);
            $('#anDesde').val(iso(d)); $('#anHasta').val(iso(hoy));
        }
        $('[data-rango]').removeClass('active btn-primary').addClass('btn-light').filter('[data-rango="' + r + '"]').removeClass('btn-light').addClass('active btn-primary');
        cargar();
    }

    function cargar() {
        var d = $('#anDesde').val(), h = $('#anHasta').val();
        if (d && h && h < d) { showNotification(1, 'warning', 'La fecha final no puede ser anterior a la inicial.'); return; }
        $('#anFilas').html('<tr><td colspan="7" class="text-center py-4"><div class="spinner-border spinner-border-sm text-primary"></div> Cargando…</td></tr>');
        api('Lista', { filtro: { Desde: d, Hasta: h, TipoDte: $('#anTipo').val(), Cajero: $('#anCajero').val(), Texto: $.trim($('#anBuscar').val()), Vista: state.vista } }).done(function (r) {
            if (!r.Ok) { error(r); $('#anFilas').empty(); return; }
            state.items = r.Items || [];
            state.pagina = 1;
            pintar();
        }).fail(falla);
    }

    function plazoHtml(x) {
        if (x.Estado === 'A') return '<span class="ad-chip ad-chip-no">Anulado</span><div class="ad-ayuda">' + fecha(x.FechaAnulacion) + ' · ' + esc(TIPOS_ANULACION[x.TipoAnulacion] || '') + '</div>'
            + (x.Motivo ? '<div class="ad-ayuda text-truncate" style="max-width:220px" title="' + esc(x.Motivo) + '">' + esc(x.Motivo) + '</div>' : '')
            + '<div class="ad-ayuda">por ' + esc(x.AnuladoPor) + '</div>';
        if (!x.EnPlazo) return '<span class="an-plazo an-plazo-vencido">Plazo vencido</span><div class="ad-ayuda">venció el ' + fecha(x.VencePlazo) + '</div>';
        var urgente = x.DiasRestantes <= 1;
        return '<span class="an-plazo ' + (urgente ? 'an-plazo-urgente' : 'an-plazo-ok') + '">' + (x.DiasRestantes === 0 ? 'Vence hoy' : 'Quedan ' + x.DiasRestantes + (x.DiasRestantes === 1 ? ' día' : ' días')) + '</span>'
            + '<div class="ad-ayuda">hasta el ' + fecha(x.VencePlazo) + '</div>';
    }

    function pintar() {
        var lista = state.items, paginas = Math.max(1, Math.ceil(lista.length / POR_PAGINA));
        if (state.pagina > paginas) state.pagina = paginas;
        var ini = (state.pagina - 1) * POR_PAGINA, filas = lista.slice(ini, ini + POR_PAGINA);
        var total = lista.reduce(function (a, x) { return a + (x.Estado === 'A' ? 0 : x.Total); }, 0);
        $('#anConteo').text(lista.length + (lista.length === 1 ? ' documento' : ' documentos') + (state.vista !== 'anulados' ? ' · ' + dinero(total) : ''));

        $('#anFilas').html(filas.length ? filas.map(function (x) {
            return '<tr class="' + (x.Estado === 'A' ? 'ad-inactivo' : '') + '" data-id="' + x.Id + '">'
                + '<td class="text-nowrap">' + fecha(x.Fecha) + '<div class="ad-ayuda">' + esc(x.Hora) + '</div></td>'
                + '<td><div class="fw-medium">' + tipoDte(x.TipoDte) + (x.Ambiente === '00' ? ' <span class="ad-chip" title="Ambiente de pruebas de Hacienda">Pruebas</span>' : '') + '</div>'
                + '<div class="ad-url">' + esc(x.NumeroControl) + '</div><div class="ad-url text-truncate" style="max-width:240px" title="Código de generación">' + esc(x.CodigoGeneracion) + '</div></td>'
                + '<td>' + esc(titulo(x.Receptor)) + '<div class="ad-ayuda">' + esc(x.ReceptorDocumento) + ' · factura ' + x.IdFactura + '</div></td>'
                + '<td class="text-end fw-medium text-nowrap">' + dinero(x.Total) + '<div class="ad-ayuda">IVA ' + dinero(x.Iva) + '</div></td>'
                + '<td class="d-none d-lg-table-cell small">' + esc(x.Cajero) + '</td>'
                + '<td>' + plazoHtml(x) + '</td>'
                + '<td class="text-end text-nowrap">'
                + (x.RutaPdf ? '<a class="btn btn-sm btn-outline-secondary" target="_blank" rel="noopener" href="' + esc(x.RutaPdf) + '" title="Ver PDF"><i class="bx bxs-file-pdf"></i></a> ' : '')
                + (x.Estado !== 'A' ? '<button type="button" class="btn btn-sm btn-outline-danger an-anular"' + (x.EnPlazo ? '' : ' disabled title="Fuera del plazo de anulación"') + '><i class="bx bx-block"></i> Anular</button>' : '')
                + '</td></tr>';
        }).join('') : '<tr><td colspan="7" class="text-center text-muted py-5">'
            + (state.vista === 'plazo' ? 'No hay documentos dentro del plazo de anulación con estos filtros.' : 'No hay documentos con estos filtros.') + '</td></tr>');

        $('#anPaginaTexto').text(lista.length > POR_PAGINA ? 'Mostrando ' + (ini + 1) + '–' + Math.min(ini + POR_PAGINA, lista.length) + ' de ' + lista.length : '');
        var $p = $('#anPaginas').empty();
        if (paginas > 1) {
            var d = Math.max(1, state.pagina - 2), h = Math.min(paginas, d + 4);
            var item = function (n, t, act, des) { return '<li class="page-item' + (act ? ' active' : '') + (des ? ' disabled' : '') + '"><a class="page-link" href="javascript:;" data-pagina="' + n + '">' + t + '</a></li>'; };
            $p.append(item(state.pagina - 1, '‹', false, state.pagina === 1));
            for (var n = d; n <= h; n++) $p.append(item(n, n, n === state.pagina, false));
            $p.append(item(state.pagina + 1, '›', false, state.pagina === paginas));
        }
    }

    /* ---------- anular ---------- */
    function abrir(x) {
        state.actual = x;
        $('#anForm .is-invalid').removeClass('is-invalid');
        $('#anModalTitulo').text('Anular ' + tipoDte(x.TipoDte).toLowerCase() + ' ' + x.NumeroControl.slice(-6));
        $('#anResumen').html('<div class="d-flex flex-wrap justify-content-between gap-2"><div><strong>' + tipoDte(x.TipoDte) + '</strong> ' + esc(x.NumeroControl)
            + '<div class="ad-url">' + esc(x.CodigoGeneracion) + '</div></div><div class="text-end"><strong>' + dinero(x.Total) + '</strong><div class="ad-ayuda">emitido el ' + fecha(x.Fecha) + ' ' + esc(x.Hora) + '</div></div></div>'
            + '<div class="mt-1">' + esc(titulo(x.Receptor)) + ' · ' + esc(x.ReceptorDocumento) + '</div>'
            + '<div class="mt-1 text-' + (x.DiasRestantes <= 1 ? 'warning' : 'success') + '"><i class="bx bx-time-five"></i> Puede anularse hasta el ' + fecha(x.VencePlazo) + '.</div>');
        $('input[name="anTipoAnulacion"][value="1"]').prop('checked', true).trigger('change');
        $('#anMotivo').val('');
        $('#anRespNombre').val(state.inicio.NombreUsuario || '');
        $('#anRespTipo').val('13'); $('#anRespNum').val('');
        $('#anSolNombre').val(titulo(x.Receptor));
        var doc = String(x.ReceptorDocumento || ''), soloNum = doc.replace(/\D/g, '');
        $('#anSolTipo').val(x.TipoDte === '03' || soloNum.length === 14 ? '36' : '13');
        $('#anSolNum').val(doc);
        bootstrap.Modal.getOrCreateInstance(document.getElementById('anModal')).show();
        setTimeout(function () { $('#anRespNum').trigger('focus'); }, 300);
    }

    function marcar(id, texto) { $('#' + id).addClass('is-invalid').trigger('focus'); if (texto) showNotification(1, 'warning', texto); return false; }

    function anular() {
        $('#anForm .is-invalid').removeClass('is-invalid');
        var x = state.actual, tipo = +$('input[name="anTipoAnulacion"]:checked').val();
        var d = {
            IdDte: x.Id, TipoAnulacion: tipo, Motivo: $.trim($('#anMotivo').val()),
            NombreResponsable: $.trim($('#anRespNombre').val()), TipoDocResponsable: $('#anRespTipo').val(), NumDocResponsable: $.trim($('#anRespNum').val()),
            NombreSolicita: $.trim($('#anSolNombre').val()), TipoDocSolicita: $('#anSolTipo').val(), NumDocSolicita: $.trim($('#anSolNum').val())
        };
        if (tipo === 3 && d.Motivo.length < 5) return marcar('anMotivo', 'Describa el motivo de la anulación.');
        if (!d.NombreResponsable) return marcar('anRespNombre', 'Ingrese el nombre del responsable.');
        if (!d.NumDocResponsable) return marcar('anRespNum', 'Ingrese el documento del responsable.');
        if (!d.NombreSolicita) return marcar('anSolNombre', 'Ingrese el nombre de quien solicita.');
        if (!d.NumDocSolicita) return marcar('anSolNum', 'Ingrese el documento de quien solicita.');

        swal({
            title: '¿Anular el documento?', text: tipoDte(x.TipoDte) + ' ' + x.NumeroControl + ' por ' + dinero(x.Total) + '.\nEsta acción no se puede deshacer.',
            type: 'warning', showCancelButton: true, confirmButtonText: 'Sí, anular', cancelButtonText: 'Cancelar', confirmButtonColor: '#DD6B55', closeOnConfirm: true
        }, function (ok) {
            if (!ok) return;
            var $b = $('#anConfirmar').prop('disabled', true);
            api('Anular', { anulacion: d }).done(function (r) {
                if (!r.Ok) { error(r); return; }
                bootstrap.Modal.getInstance(document.getElementById('anModal')).hide();
                swal({ title: 'Documento anulado', text: r.Mensaje + '\nEvento de invalidación: ' + r.CodigoEvento, type: 'success' });
                cargar();
            }).fail(falla).always(function () { $b.prop('disabled', false); });
        });
    }

    /* ---------- eventos ---------- */
    $('#anVistas').on('click', '[data-vista]', function () {
        $('#anVistas .nav-link').removeClass('active'); $(this).addClass('active');
        state.vista = $(this).data('vista');
        cargar();
    });
    $('[data-rango]').on('click', function () { rango(String($(this).data('rango'))); });
    $('#anDesde, #anHasta').on('change', function () { $('[data-rango]').removeClass('active btn-primary').addClass('btn-light'); cargar(); });
    $('#anTipo, #anCajero').on('change', cargar);
    $('#anBuscar').on('input', function () { clearTimeout(state.timer); state.timer = setTimeout(cargar, 350); });
    $('#anLimpiar').on('click', function () { $('#anTipo, #anCajero').val(''); $('#anBuscar').val(''); rango('90'); });
    $('#anPaginas').on('click', '[data-pagina]', function () {
        var n = +$(this).data('pagina');
        if (n >= 1 && !$(this).parent().hasClass('disabled')) { state.pagina = n; pintar(); }
    });
    $('#anFilas').on('click', '.an-anular', function () {
        var id = +$(this).closest('tr').data('id');
        abrir($.grep(state.items, function (x) { return x.Id === id; })[0]);
    });
    $('input[name="anTipoAnulacion"]').on('change', function () {
        var otro = $('input[name="anTipoAnulacion"]:checked').val() === '3';
        $('#anMotivoReq').toggleClass('d-none', !otro);
        $('#anMotivo').attr('placeholder', otro ? 'Obligatorio: describa el motivo' : 'Opcional');
    });
    $('#anForm').on('submit', function (ev) { ev.preventDefault(); anular(); });
    $('#anForm').on('input', 'input, textarea', function () { $(this).removeClass('is-invalid'); });
    $('#anPlazosBtn').on('click', function () { bootstrap.Modal.getOrCreateInstance(document.getElementById('anModalPlazos')).show(); });
    $('#anPlazosLista').on('click', '.an-guardar-plazo', function () {
        var tipo = $(this).data('tipo'), dias = parseInt($('.an-dias[data-tipo="' + tipo + '"]').val(), 10);
        if (isNaN(dias) || dias < 0 || dias > 365) { showNotification(1, 'warning', 'El plazo debe estar entre 0 y 365 días.'); return; }
        api('GuardarPlazo', { tipoDte: String(tipo), dias: dias }).done(function (r) {
            if (!r.Ok) { error(r); return; }
            showNotification(1, 'success', r.Mensaje);
            $.each(state.inicio.Plazos, function (_, p) { if (p.TipoDte === String(tipo)) p.Dias = dias; });
            pintarPlazos();
            cargar();
        }).fail(falla);
    });

    if (typeof mtd_ValidateSession === 'function') mtd_ValidateSession();
    iniciar();
})(jQuery);
