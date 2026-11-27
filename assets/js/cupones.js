/* Cupones de descuento – Registros/frm_ListaCupones.aspx
   Crea cupones con código QR, los imprime en papel térmico de 80 mm y los lista con su estado.
   En caja (frm_OpenFactura.aspx) se aplican al escanear el QR, que solo contiene el código (DPC- y 8 letras). */
(function ($) {
    'use strict';

    var URL = 'Registros/frm_ListaCupones.aspx/';
    var POR_PAGINA = 50;
    var ESTADOS = { P: ['Vigente', 'ad-chip-ok'], U: ['Usado', 'ad-chip-info'], V: ['Vencido', 'ad-chip-no'], A: ['Anulado', 'ad-chip'] };
    var state = { inicio: null, items: [], estado: 'P', texto: '', pagina: 1, timer: null, timerPac: null, paciente: null };

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
    function pct(n) { return Number(n || 0).toLocaleString('es-SV', { maximumFractionDigits: 2 }) + ' %'; }
    function titulo(s) { return String(s || '').toLowerCase().replace(/(^|\s)(\S)/g, function (m, a, b) { return a + b.toUpperCase(); }); }
    function dos(n) { return (n < 10 ? '0' : '') + n; }
    function iso(d) { return d.getFullYear() + '-' + dos(d.getMonth() + 1) + '-' + dos(d.getDate()); }
    function fecha(s) { if (!s) return ''; var p = s.substr(0, 10).split('-'); return p[2] + '/' + p[1] + '/' + p[0]; }
    function tratamiento(id) { return $.grep(state.inicio.Tratamientos || [], function (t) { return t.Id === id; })[0]; }

    /* ---------- inicio y lista ---------- */
    function iniciar() {
        return api('Inicio').done(function (r) {
            if (!r.Ok) { error(r); return; }
            state.inicio = r;
            $('#cpKPend').text(r.Pendientes);
            $('#cpKUsados').text(r.Usados);
            $('#cpKVencidos').text(r.Vencidos);
            $('#cpKMes').text(dinero(r.DescuentoMes));
            $('#cpKConfig').text('cupón por defecto: ' + pct(r.Config.PorcentajeDefecto) + ' · ' + r.Config.DiasVigencia + ' días');
            $('#cpConfigBtn').toggleClass('d-none', !r.EsAdministrador);
            $('#cpTratamiento').html('<option value="0">Toda la factura</option>' + (r.Tratamientos || []).map(function (t) {
                var p = t.Texto.split('|');
                return '<option value="' + t.Id + '">' + esc(p[0]) + ' (' + dinero(p[1]) + ')</option>';
            }).join(''));
        }).fail(falla);
    }

    function cargar() {
        $('#cpFilas').html('<tr><td colspan="7" class="text-center py-4"><div class="spinner-border spinner-border-sm text-primary"></div> Cargando…</td></tr>');
        return api('Lista', { estado: state.estado, texto: state.texto, desde: '', hasta: '' }).done(function (r) {
            if (!r.Ok) { error(r); $('#cpFilas').empty(); return; }
            state.items = r.Items || [];
            state.pagina = 1;
            pintar();
        }).fail(falla);
    }

    function pintar() {
        var lista = state.items, paginas = Math.max(1, Math.ceil(lista.length / POR_PAGINA));
        if (state.pagina > paginas) state.pagina = paginas;
        var ini = (state.pagina - 1) * POR_PAGINA, filas = lista.slice(ini, ini + POR_PAGINA);
        $('#cpConteo').text(lista.length + (lista.length === 1 ? ' cupón' : ' cupones'));
        $('#cpFilas').html(filas.length ? filas.map(function (c) {
            var e = ESTADOS[c.Estado] || [c.Estado, ''];
            var detalle = c.Estado === 'U' ? 'Factura ' + c.IdFactura + ' · ' + dinero(c.MontoDescuento) + ' · ' + fecha(c.FechaUso) + ' (' + esc(c.UsuarioUso) + ')'
                : c.Estado === 'A' ? esc(c.MotivoAnulacion)
                    : c.FacturaAplicada ? 'Aplicado a la factura ' + c.FacturaAplicada + ', sin cobrar' : '';
            return '<tr class="' + (c.Estado === 'A' || c.Estado === 'V' ? 'ad-inactivo' : '') + '" data-id="' + c.Id + '">'
                + '<td><span class="ad-url fw-bold">' + esc(c.Codigo) + '</span>' + (c.Nota ? '<div class="ad-ayuda">' + esc(c.Nota) + '</div>' : '') + '</td>'
                + '<td><div class="fw-medium">' + esc(titulo(c.Paciente || c.Asignado)) + '</div><div class="ad-ayuda">' + (c.IdExpediente ? 'Paciente' + (c.Celular ? ' · ' + esc(c.Celular) : '') : 'Promoción · cualquier paciente') + '</div></td>'
                + '<td><span class="fw-bold">' + pct(c.Porcentaje) + '</span><div class="ad-ayuda">' + (c.Tratamiento ? esc(c.Tratamiento) : 'Toda la factura') + '</div></td>'
                + '<td class="d-none d-md-table-cell">' + fecha(c.Vence) + '</td>'
                + '<td><span class="ad-chip ' + e[1] + '">' + e[0] + '</span>' + (detalle ? '<div class="ad-ayuda">' + detalle + '</div>' : '') + '</td>'
                + '<td class="d-none d-lg-table-cell small">' + fecha(c.FechaCrea) + '<div class="ad-ayuda">' + esc(c.UsuarioCrea) + '</div></td>'
                + '<td class="text-end text-nowrap">'
                + (c.Estado === 'P' ? '<button type="button" class="btn btn-sm btn-outline-primary cp-imprimir" title="Imprimir cupón"><i class="bx bx-printer"></i></button> '
                    + '<button type="button" class="btn btn-sm btn-outline-danger cp-anular" title="Anular cupón"><i class="bx bx-block"></i></button>' : '')
                + '</td></tr>';
        }).join('') : '<tr><td colspan="7" class="text-center text-muted py-5">No hay cupones con estos filtros.</td></tr>');

        $('#cpPaginaTexto').text(lista.length > POR_PAGINA ? 'Mostrando ' + (ini + 1) + '–' + Math.min(ini + POR_PAGINA, lista.length) + ' de ' + lista.length : '');
        var $p = $('#cpPaginas').empty();
        if (paginas > 1) {
            var d = Math.max(1, state.pagina - 2), h = Math.min(paginas, d + 4);
            var item = function (n, t, act, des) { return '<li class="page-item' + (act ? ' active' : '') + (des ? ' disabled' : '') + '"><a class="page-link" href="javascript:;" data-pagina="' + n + '">' + t + '</a></li>'; };
            $p.append(item(state.pagina - 1, '‹', false, state.pagina === 1));
            for (var n = d; n <= h; n++) $p.append(item(n, n, n === state.pagina, false));
            $p.append(item(state.pagina + 1, '›', false, state.pagina === paginas));
        }
    }

    /* ---------- nuevo cupón ---------- */
    function abrirNuevo() {
        var cfg = state.inicio.Config, vence = new Date();
        vence.setDate(vence.getDate() + cfg.DiasVigencia);
        state.paciente = null;
        $('#cpForm')[0].reset();
        $('#cpForm .is-invalid').removeClass('is-invalid');
        $('#cpPacientes').addClass('d-none').empty();
        $('#cpTratamiento').val('0');
        $('#cpPorcentaje').val(cfg.PorcentajeDefecto).attr('max', cfg.PorcentajeMaximo);
        $('#cpPorcentajeAyuda').text('Por defecto ' + pct(cfg.PorcentajeDefecto) + ' · máximo ' + pct(cfg.PorcentajeMaximo));
        $('#cpVence').val(iso(vence)).attr('min', iso(new Date()));
        ejemplo();
        bootstrap.Modal.getOrCreateInstance(document.getElementById('cpModal')).show();
        setTimeout(function () { $('#cpPaciente').trigger('focus'); }, 300);
    }

    function ejemplo() {
        var p = parseFloat($('#cpPorcentaje').val()) || 0, t = tratamiento(+$('#cpTratamiento').val());
        if (!t) { $('#cpEjemplo').html('<i class="bx bx-info-circle"></i> Descuenta el <strong>' + pct(p) + '</strong> de toda la factura.'); return; }
        var partes = t.Texto.split('|'), precio = parseFloat(partes[1]) || 0, desc = Math.round(precio * p) / 100;
        $('#cpEjemplo').html('<i class="bx bx-info-circle"></i> En <strong>' + esc(partes[0]) + '</strong> (' + dinero(precio) + '): descuento de <strong>' + dinero(desc) + '</strong>, paga ' + dinero(precio - desc) + '.');
    }

    function buscarPacientes() {
        clearTimeout(state.timerPac);
        var q = $.trim($('#cpPaciente').val());
        state.paciente = null;
        if (q.length < 2) { $('#cpPacientes').addClass('d-none').empty(); return; }
        state.timerPac = setTimeout(function () {
            api('BuscarPacientes', { texto: q }).done(function (lista) {
                $('#cpPacientes').toggleClass('d-none', !lista.length).html(lista.map(function (p) {
                    return '<button type="button" class="list-group-item list-group-item-action small" data-id="' + p.Id + '">' + esc(p.Texto) + '</button>';
                }).join(''));
            });
        }, 300);
    }

    function crear() {
        $('#cpForm .is-invalid').removeClass('is-invalid');
        var cfg = state.inicio.Config, porcentaje = parseFloat($('#cpPorcentaje').val());
        var d = {
            IdExpediente: state.paciente ? state.paciente.Id : 0, Asignado: $.trim($('#cpAsignado').val()), IdTratamiento: +$('#cpTratamiento').val() || 0,
            Porcentaje: porcentaje, Vence: $('#cpVence').val(), Nota: $.trim($('#cpNota').val())
        };
        if (!d.IdExpediente && $.trim($('#cpPaciente').val())) { $('#cpPaciente').addClass('is-invalid').trigger('focus'); showNotification(1, 'warning', 'Elija el paciente de la lista o deje el campo vacío.'); return; }
        if (!d.IdExpediente && !d.Asignado) { $('#cpAsignado').addClass('is-invalid').trigger('focus'); showNotification(1, 'warning', 'Elija un paciente o escriba a quién se entrega el cupón.'); return; }
        if (isNaN(porcentaje) || porcentaje <= 0 || porcentaje > cfg.PorcentajeMaximo) { $('#cpPorcentaje').addClass('is-invalid').trigger('focus'); showNotification(1, 'warning', 'El descuento debe estar entre 1 y ' + pct(cfg.PorcentajeMaximo) + '.'); return; }
        if (!d.Vence || d.Vence < iso(new Date())) { $('#cpVence').addClass('is-invalid').trigger('focus'); showNotification(1, 'warning', 'La fecha no puede ser anterior a hoy.'); return; }
        var $b = $('#cpGuardar').prop('disabled', true), w = ventanaImpresion();
        api('Crear', { cupon: d }).done(function (r) {
            if (!r.Ok) { if (w) w.close(); error(r); return; }
            bootstrap.Modal.getInstance(document.getElementById('cpModal')).hide();
            showNotification(1, 'success', r.Mensaje);
            if (w) imprimir(r.Id, w);
            iniciar(); cargar();
        }).fail(function (xhr) { if (w) w.close(); falla(xhr); }).always(function () { $b.prop('disabled', false); });
    }

    /* ---------- impresión en papel térmico de 80 mm ---------- */
    // La ventana se abre dentro del clic para que el navegador no la bloquee; el contenido llega después
    function ventanaImpresion() {
        var w = window.open('', '_blank', 'width=420,height=720');
        if (!w) { showNotification(1, 'warning', 'Permita las ventanas emergentes para imprimir el cupón.'); return null; }
        w.document.write('<p style="font-family:sans-serif;text-align:center;margin-top:40px">Preparando cupón…</p>');
        return w;
    }

    function imprimir(id, w) {
        w = w || ventanaImpresion();
        if (!w) return;
        api('Imprimir', { id: id }).done(function (c) {
            if (!c.Ok) { w.close(); error(c); return; }
            var base = location.href.replace(/[#?].*$/, '').replace(/[^\/]*$/, '');
            w.document.open();
            w.document.write(ticket(c, base));
            w.document.close();
        }).fail(function (xhr) { w.close(); falla(xhr); });
    }

    function ticket(c, base) {
        return '<!doctype html><html lang="es"><head><meta charset="utf-8"><title>Cupón ' + esc(c.Codigo) + '</title><style>'
            + '@page{size:80mm auto;margin:0}'
            + '*{box-sizing:border-box}html,body{margin:0;padding:0;background:#fff;color:#000}'
            + 'body{width:80mm;font-family:Arial,Helvetica,sans-serif;font-size:11pt;line-height:1.25}'
            + '.t{width:72mm;margin:0 auto;padding:3mm 0 6mm;text-align:center}'
            + '.logo{width:44mm;margin:0 auto 1mm;display:block}'
            + '.raya{border-top:1px dashed #000;margin:2.5mm 0}'
            + '.tit{font-size:12pt;font-weight:bold;letter-spacing:.5mm}'
            + '.pct{font-size:34pt;font-weight:bold;line-height:1;margin:1mm 0}'
            + '.qr{width:46mm;height:46mm;display:block;margin:2mm auto 1mm;image-rendering:pixelated}'
            + '.cod{font-family:"Courier New",monospace;font-size:15pt;font-weight:bold;letter-spacing:.6mm}'
            + '.dato{text-align:left;font-size:10pt;margin:.6mm 0}.dato b{display:inline-block;min-width:20mm}'
            + '.pie{font-size:8.5pt}.nota{font-size:10pt;font-style:italic;margin-top:1mm}'
            + '@media screen{body{margin:10px auto;box-shadow:0 0 6px rgba(0,0,0,.25)}}'
            + '</style></head><body><div class="t">'
            + '<img class="logo" src="' + base + 'assets/images/logo-dpiecenter-clinica.png" alt="D\' Pie Center">'
            + '<div class="raya"></div>'
            + '<div class="tit">CUPÓN DE DESCUENTO</div>'
            + '<div class="pct">' + pct(c.Porcentaje).replace(' ', '') + '</div>'
            + '<div>de descuento en ' + (c.Tratamiento ? '<b>' + esc(c.Tratamiento) + '</b>' : '<b>todos los servicios</b>') + '</div>'
            + (c.Nota ? '<div class="nota">' + esc(c.Nota) + '</div>' : '')
            + '<img class="qr" src="' + c.Qr + '" alt="Código QR">'
            + '<div class="cod">' + esc(c.Codigo) + '</div>'
            + '<div class="raya"></div>'
            + '<div class="dato"><b>Para:</b> ' + esc(titulo(c.Asignado)) + '</div>'
            + '<div class="dato"><b>Válido hasta:</b> ' + fecha(c.Vence) + '</div>'
            + '<div class="dato"><b>Emitido:</b> ' + fecha(c.Emitido) + '</div>'
            + '<div class="raya"></div>'
            + '<div class="pie">' + esc(c.Leyenda || '') + '</div>'
            + '</div><script>'
            + 'function listo(){var i=[].slice.call(document.images);return i.every(function(x){return x.complete;});}'
            + 'function imprimir(){if(!listo()){setTimeout(imprimir,150);return;}setTimeout(function(){window.focus();window.print();},150);}'
            + 'window.onafterprint=function(){window.close();};imprimir();'
            + '<\/script></body></html>';
    }

    /* ---------- anular ---------- */
    function anular(c) {
        swal({
            title: 'Anular cupón', text: c.Codigo + ' · ' + pct(c.Porcentaje) + ' para ' + titulo(c.Paciente || c.Asignado) + '\n\n¿Por qué lo anula?', type: 'input',
            inputPlaceholder: 'Ejemplo: se entregó por error', showCancelButton: true, confirmButtonText: 'Anular cupón', cancelButtonText: 'Cancelar', closeOnConfirm: false
        }, function (motivo) {
            if (motivo === false) return;
            motivo = $.trim(motivo || '');
            if (motivo.length < 5) { swal.showInputError('Indique el motivo (al menos 5 caracteres).'); return false; }
            api('Anular', { id: c.Id, motivo: motivo }).done(function (r) {
                if (!r.Ok) { swal.showInputError(r.Mensaje); return; }
                swal.close();
                showNotification(1, 'success', r.Mensaje);
                iniciar(); cargar();
            }).fail(function (xhr) { swal.close(); falla(xhr); });
        });
    }

    /* ---------- configuración ---------- */
    function abrirConfig() {
        var c = state.inicio.Config;
        $('#cfPorcentaje').val(c.PorcentajeDefecto);
        $('#cfMaximo').val(c.PorcentajeMaximo);
        $('#cfDias').val(c.DiasVigencia);
        $('#cfLeyenda').val(c.Leyenda || '');
        $('#cfModificado').text(c.Usuario ? 'Modificado por ' + c.Usuario + ' el ' + fecha(c.Fecha) : '');
        bootstrap.Modal.getOrCreateInstance(document.getElementById('cpModalConfig')).show();
    }

    function guardarConfig() {
        var d = { PorcentajeDefecto: parseFloat($('#cfPorcentaje').val()), PorcentajeMaximo: parseFloat($('#cfMaximo').val()), DiasVigencia: parseInt($('#cfDias').val(), 10), Leyenda: $.trim($('#cfLeyenda').val()) };
        if (isNaN(d.PorcentajeMaximo) || d.PorcentajeMaximo <= 0 || d.PorcentajeMaximo > 100) { $('#cfMaximo').addClass('is-invalid').trigger('focus'); return; }
        if (isNaN(d.PorcentajeDefecto) || d.PorcentajeDefecto <= 0 || d.PorcentajeDefecto > d.PorcentajeMaximo) { $('#cfPorcentaje').addClass('is-invalid').trigger('focus'); showNotification(1, 'warning', 'El descuento por defecto no puede superar el máximo.'); return; }
        if (isNaN(d.DiasVigencia) || d.DiasVigencia < 1 || d.DiasVigencia > 730) { $('#cfDias').addClass('is-invalid').trigger('focus'); return; }
        api('GuardarConfiguracion', { config: d }).done(function (r) {
            if (!r.Ok) { error(r); return; }
            bootstrap.Modal.getInstance(document.getElementById('cpModalConfig')).hide();
            showNotification(1, 'success', r.Mensaje);
            iniciar();
        }).fail(falla);
    }

    /* ---------- eventos ---------- */
    $('#cpNuevo').on('click', function () { if (state.inicio) abrirNuevo(); });
    $('#cpConfigBtn').on('click', abrirConfig);
    $('#cpForm').on('submit', function (ev) { ev.preventDefault(); crear(); });
    $('#cpFormConfig').on('submit', function (ev) { ev.preventDefault(); guardarConfig(); });
    $('#cpForm, #cpFormConfig').on('input change', 'input, select, textarea', function () { $(this).removeClass('is-invalid'); });
    $('#cpPorcentaje, #cpTratamiento').on('input change', ejemplo);
    $('#cpPaciente').on('input', buscarPacientes);
    $('#cpPacientes').on('click', '[data-id]', function () {
        state.paciente = { Id: +$(this).data('id'), Texto: $(this).text() };
        $('#cpPaciente').val(state.paciente.Texto);
        if (!$.trim($('#cpAsignado').val())) $('#cpAsignado').val(titulo(state.paciente.Texto.split(' · ')[0]));
        $('#cpPacientes').addClass('d-none').empty();
    });
    $('#cpEstados').on('click', '[data-estado]', function () {
        $('#cpEstados .btn').removeClass('active'); $(this).addClass('active');
        state.estado = String($(this).data('estado'));
        cargar();
    });
    $('#cpBuscar').on('input', function () { clearTimeout(state.timer); var v = $.trim($(this).val()); state.timer = setTimeout(function () { state.texto = v; cargar(); }, 350); });
    $('#cpPaginas').on('click', '[data-pagina]', function () {
        var n = +$(this).data('pagina');
        if (n >= 1 && !$(this).parent().hasClass('disabled')) { state.pagina = n; pintar(); }
    });
    $('#cpFilas')
        .on('click', '.cp-imprimir', function () { imprimir(+$(this).closest('tr').data('id')); })
        .on('click', '.cp-anular', function () { var id = +$(this).closest('tr').data('id'); anular($.grep(state.items, function (c) { return c.Id === id; })[0]); });

    if (typeof mtd_ValidateSession === 'function') mtd_ValidateSession();
    iniciar().done(cargar);
})(jQuery);
