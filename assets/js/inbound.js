/* Inbound – Registros/frm_Inbound.aspx (jQuery + WebMethods)
   Captura rápida de teléfono y nombre del cliente; en la lista se marca si ya contestó y se exporta a Excel (.xlsx). */
(function ($) {
    'use strict';

    var URL = 'Registros/frm_Inbound.aspx/';
    var POR_PAGINA = 50, ESPERA_BUSQUEDA_MS = 300;
    var CLAVE_RANGO = 'dpie.inbound.rango';

    var state = {
        contesto: -1,
        texto: '',
        items: [],
        pagina: 1,
        editando: 0,
        guardando: false,
        consulta: 0,
        timer: null
    };

    /* ---------- utilidades ---------- */
    function api(metodo, datos) {
        return $.ajax({
            type: 'POST',
            url: URL + metodo,
            data: JSON.stringify(datos || {}),
            contentType: 'application/json; charset=utf-8',
            dataType: 'json'
        }).then(function (r) { return r.d; });
    }
    function falla(xhr) { if (xhr.statusText !== 'abort') showNotification(1, 'error', 'Error de conexión (HTTP ' + xhr.status + ').'); }
    function sesion(msg) { if (/sesi[oó]n/i.test(msg || '') && typeof mtd_ValidateSession === 'function') { mtd_ValidateSession(); return true; } return false; }
    function esc(s) { return $('<div/>').text(s == null ? '' : String(s)).html(); }
    function titulo(s) { return String(s || '').toLowerCase().replace(/(^|\s)(\S)/g, function (m, a, b) { return a + b.toUpperCase(); }); }
    function digitos(s) { return String(s || '').replace(/\D/g, ''); }
    function dos(n) { return (n < 10 ? '0' : '') + n; }
    function iso(d) { return d.getFullYear() + '-' + dos(d.getMonth() + 1) + '-' + dos(d.getDate()); }
    function fechaHora(s) {
        if (!s) return '';
        var p = s.split('T'), f = p[0].split('-');
        return f[2] + '/' + f[1] + '/' + f[0] + ' ' + hora12((p[1] || '').substr(0, 5));
    }
    function relativa(s) {
        if (!s) return '';
        var d = new Date(s.replace('T', ' ').replace(/-/g, '/')), min = Math.round((Date.now() - d) / 60000);
        if (min < 1) return 'hace un momento';
        if (min < 60) return 'hace ' + min + ' min';
        if (min < 1440 && new Date().getDate() === d.getDate()) return 'hoy ' + horaDe(d);
        return fechaHora(s);
    }
    // 77778888 → 7777-8888
    function formatoTel(t) { t = digitos(t); return t.length === 8 ? t.substr(0, 4) + '-' + t.substr(4) : t; }
    function leer(c) { try { return localStorage.getItem(c); } catch (e) { return null; } }
    function guardar(c, v) { try { localStorage.setItem(c, v); } catch (e) { } }

    function rango(r) {
        var hoy = new Date(), d = new Date(hoy), h = new Date(hoy);
        if (r === '7') d.setDate(hoy.getDate() - 6);
        else if (r === 'mes') d = new Date(hoy.getFullYear(), hoy.getMonth(), 1);
        else if (r === 'anterior') { d = new Date(hoy.getFullYear(), hoy.getMonth() - 1, 1); h = new Date(hoy.getFullYear(), hoy.getMonth(), 0); }
        else if (r === 'todo') return { desde: '', hasta: '' };
        return { desde: iso(d), hasta: iso(h) };
    }
    function filtro() {
        return { Desde: $('#ibDesde').val() || '', Hasta: $('#ibHasta').val() || '', Contesto: state.contesto, Texto: state.texto };
    }

    /* ---------- lista ---------- */
    function cargar() {
        var id = ++state.consulta;
        $('#ibFilas').html('<tr><td colspan="7" class="text-center py-4"><div class="spinner-border spinner-border-sm text-primary" role="status"></div> Cargando…</td></tr>');
        api('Lista', { filtro: filtro() }).done(function (r) {
            if (id !== state.consulta) return;
            if (!r.Ok) { if (!sesion(r.Mensaje)) showNotification(1, 'error', r.Mensaje); $('#ibFilas').empty(); return; }
            resumen(r.Resumen);
            state.items = r.Items || [];
            pintar();
        }).fail(falla);
    }

    function resumen(s) {
        if (!s) return;
        $('#ibPendientes').text(s.Pendientes);
        $('#ibHoy').text(s.Hoy);
        $('#ibContestadosHoy').text(s.ContestadosHoy);
        $('#ibMes').text(s.Mes);
        $('.ib-kpi-pendiente').toggleClass('ib-alerta', s.Pendientes > 0);
    }

    function pintar() {
        var total = state.items.length, paginas = Math.max(1, Math.ceil(total / POR_PAGINA));
        if (state.pagina > paginas) state.pagina = paginas;
        var ini = (state.pagina - 1) * POR_PAGINA, filas = state.items.slice(ini, ini + POR_PAGINA);
        var pendientes = $.grep(state.items, function (x) { return !x.Contesto; }).length;
        $('#ibConteo').text(total ? total + (total === 1 ? ' registro' : ' registros') + ' · ' + pendientes + ' pendientes' : '');

        if (!total) {
            $('#ibFilas').html('<tr><td colspan="7" class="text-center text-muted py-5"><i class="bx bx-phone-off fs-3 d-block mb-1"></i>No hay registros con estos filtros.</td></tr>');
        } else {
            $('#ibFilas').html(filas.map(function (x) {
                var tel = digitos(x.Telefono), wa = tel.length === 8 ? '503' + tel : tel;
                return '<tr class="' + (x.Contesto ? 'ib-contesto' : 'ib-pendiente') + (x.Id === state.editando ? ' table-warning' : '') + '" data-id="' + x.Id + '">'
                    + '<td class="text-nowrap"><span title="' + esc(fechaHora(x.FechaCrea)) + '">' + esc(relativa(x.FechaCrea)) + '</span></td>'
                    + '<td class="text-nowrap"><a href="tel:' + esc(tel) + '" class="ib-tel">' + esc(formatoTel(x.Telefono)) + '</a>'
                    + ' <a class="text-success ms-1" target="_blank" rel="noopener" title="WhatsApp" href="https://wa.me/' + esc(wa) + '"><i class="bx bxl-whatsapp"></i></a></td>'
                    + '<td><span class="fw-medium">' + esc(x.NombreCliente) + '</span>'
                    + (x.IdExpediente ? '<br><span class="small text-muted"><i class="bx bx-user"></i> Paciente: ' + esc(titulo(x.Paciente)) + '</span>' : '')
                    + '</td>'
                    + '<td class="text-center"><div class="form-check form-switch d-inline-block mb-0">'
                    + '<input class="form-check-input ib-marcar" type="checkbox" role="switch" aria-label="Contestó" ' + (x.Contesto ? 'checked' : '') + ' />'
                    + '</div><div class="small ' + (x.Contesto ? 'text-success' : 'text-warning') + '">' + (x.Contesto ? 'Contestó' : 'Pendiente') + '</div></td>'
                    + '<td class="d-none d-lg-table-cell small">' + esc(x.UsuarioCrea) + '</td>'
                    + '<td class="d-none d-xl-table-cell small text-muted">' + (x.FechaModificacion ? esc(x.UsuarioModifica) + ' · ' + esc(fechaHora(x.FechaModificacion)) : '—') + '</td>'
                    + '<td class="text-end text-nowrap">'
                    + '<button type="button" class="btn btn-sm btn-outline-primary ib-editar" title="Editar"><i class="bx bx-edit-alt"></i></button> '
                    + '<button type="button" class="btn btn-sm btn-outline-danger ib-eliminar" title="Eliminar"><i class="bx bx-trash"></i></button>'
                    + '</td></tr>';
            }).join(''));
        }

        $('#ibPaginaTexto').text(total > POR_PAGINA ? 'Mostrando ' + (ini + 1) + '–' + Math.min(ini + POR_PAGINA, total) + ' de ' + total : '');
        var $p = $('#ibPaginas').empty();
        if (paginas > 1) {
            var desdeP = Math.max(1, state.pagina - 2), hastaP = Math.min(paginas, desdeP + 4);
            var item = function (n, t, activo, deshabilitado) {
                return '<li class="page-item' + (activo ? ' active' : '') + (deshabilitado ? ' disabled' : '') + '"><a class="page-link" href="javascript:;" data-pagina="' + n + '">' + t + '</a></li>';
            };
            $p.append(item(state.pagina - 1, '‹', false, state.pagina === 1));
            for (var n = desdeP; n <= hastaP; n++) $p.append(item(n, n, n === state.pagina, false));
            $p.append(item(state.pagina + 1, '›', false, state.pagina === paginas));
        }
    }

    function porId(id) { return $.grep(state.items, function (x) { return x.Id === id; })[0]; }

    /* ---------- captura ---------- */
    function limpiarErrores() { $('#ibTelefono, #ibNombre').removeClass('is-invalid'); $('#ibTelefonoError, #ibNombreError').text(''); }
    function error(campo, texto) { $('#' + campo).addClass('is-invalid'); $('#' + campo + 'Error').text(texto); }

    function validar() {
        limpiarErrores();
        var tel = digitos($('#ibTelefono').val()), nombre = $.trim($('#ibNombre').val()), ok = true;
        if (!tel) { error('ibTelefono', 'Ingrese el teléfono.'); ok = false; }
        else if (tel.length < 8 || tel.length > 15) { error('ibTelefono', 'Debe tener de 8 a 15 dígitos.'); ok = false; }
        if (!nombre) { error('ibNombre', 'Ingrese el nombre del cliente.'); ok = false; }
        else if (nombre.length < 3) { error('ibNombre', 'El nombre es muy corto.'); ok = false; }
        if (!ok) $('#ibForm .is-invalid').first().trigger('focus');
        return ok;
    }

    function nuevo() {
        state.editando = 0;
        $('#ibForm')[0].reset();
        limpiarErrores();
        $('#ibFormTitulo').html('<i class="bx bx-plus-circle"></i> Nuevo registro');
        $('#ibEditando, #ibCancelar, #ibCoincide').addClass('d-none');
        $('#ibCaptura').removeClass('ib-modo-editar');
        $('#ibFilas tr.table-warning').removeClass('table-warning');
    }

    function editar(x) {
        state.editando = x.Id;
        limpiarErrores();
        $('#ibTelefono').val(formatoTel(x.Telefono));
        $('#ibNombre').val(x.NombreCliente);
        $('#ibContesto').prop('checked', x.Contesto);
        $('#ibFormTitulo').html('<i class="bx bx-edit-alt"></i> Editar registro');
        $('#ibEditando, #ibCancelar').removeClass('d-none');
        $('#ibCaptura').addClass('ib-modo-editar');
        $('#ibFilas tr').removeClass('table-warning').filter('[data-id="' + x.Id + '"]').addClass('table-warning');
        $('html, body').animate({ scrollTop: $('#ibCaptura').offset().top - 80 }, 200);
        $('#ibNombre').trigger('focus');
    }

    function guardarRegistro() {
        if (state.guardando || !validar()) return;
        state.guardando = true;
        var $b = $('#ibGuardar').prop('disabled', true).html('<span class="spinner-border spinner-border-sm"></span> Guardando…');
        var id = state.editando, contesto = $('#ibContesto').is(':checked');
        api('Guardar', { id: id, telefono: digitos($('#ibTelefono').val()), nombre: $.trim($('#ibNombre').val()), contesto: contesto }).done(function (r) {
            if (!r.Ok) {
                if (r.Existe) {
                    // el teléfono ya es de un paciente: no se guarda y se deja el formulario listo para otro registro
                    nuevo();
                    swal({ title: 'Ya existe en expediente', text: r.Mensaje, type: 'warning', confirmButtonText: 'Aceptar' },
                        function () { setTimeout(function () { $('#ibTelefono').trigger('focus'); }, 50); });
                    return;
                }
                if (sesion(r.Mensaje)) return;
                if (/tel[eé]fono/i.test(r.Mensaje)) error('ibTelefono', r.Mensaje); else if (/nombre/i.test(r.Mensaje)) error('ibNombre', r.Mensaje);
                showNotification(1, 'warning', r.Mensaje);
                return;
            }
            showNotification(1, 'success', r.Mensaje);
            // al editar, el estado "contestó" se guarda aparte (acción 4) para dejar registro de quién lo cambió
            var previo = id ? porId(id) : null;
            if (previo && previo.Contesto !== contesto) api('MarcarContesto', { id: id, contesto: contesto }).always(cargar);
            else cargar();
            nuevo();
            $('#ibTelefono').trigger('focus');
        }).fail(falla).always(function () {
            state.guardando = false;
            $b.prop('disabled', false).html('<i class="bx bx-save"></i> Guardar');
        });
    }

    // Aviso si el teléfono ya está en la lista cargada
    function revisarTelefono() {
        var tel = digitos($('#ibTelefono').val());
        var previo = tel.length >= 8 ? $.grep(state.items, function (x) { return digitos(x.Telefono) === tel && x.Id !== state.editando; })[0] : null;
        $('#ibCoincide').toggleClass('d-none', !previo)
            .html(previo ? '<i class="bx bx-info-circle"></i> Este teléfono ya se registró ' + esc(relativa(previo.FechaCrea)) + ' como <strong>' + esc(previo.NombreCliente) + '</strong>'
                + (previo.Contesto ? ' (contestó).' : ' (pendiente).') : '');
    }

    /* ---------- acciones de la lista ---------- */
    function marcar($chk) {
        var id = +$chk.closest("tr").data("id"), valor = $chk.is(':checked');
        $chk.prop('disabled', true);
        api('MarcarContesto', { id: id, contesto: valor }).done(function (r) {
            if (!r.Ok) { if (!sesion(r.Mensaje)) showNotification(1, 'warning', r.Mensaje); $chk.prop('checked', !valor); return; }
            showNotification(1, 'success', valor ? 'Marcado como contestado.' : 'Marcado como pendiente.');
            cargar();
        }).fail(function (xhr) { $chk.prop('checked', !valor); falla(xhr); }).always(function () { $chk.prop('disabled', false); });
    }

    function eliminar(x) {
        swal({
            title: 'Eliminar registro',
            text: '¿Eliminar el registro de ' + x.NombreCliente + ' (' + formatoTel(x.Telefono) + ')?',
            type: 'warning',
            showCancelButton: true,
            confirmButtonText: 'Eliminar',
            cancelButtonText: 'Cancelar',
            confirmButtonColor: '#DD6B55',
            closeOnConfirm: true
        }, function (ok) {
            if (!ok) return;
            api('Eliminar', { id: x.Id }).done(function (r) {
                if (!r.Ok) { if (!sesion(r.Mensaje)) showNotification(1, 'warning', r.Mensaje); return; }
                showNotification(1, 'success', r.Mensaje);
                if (state.editando === x.Id) nuevo();
                cargar();
            }).fail(falla);
        });
    }

    function exportar() {
        var $b = $('#ibExportar').prop('disabled', true).html('<span class="spinner-border spinner-border-sm"></span> Generando…');
        api('Exportar', { filtro: filtro() }).done(function (r) {
            if (!r.Ok) { if (!sesion(r.Mensaje)) showNotification(1, 'warning', r.Mensaje); return; }
            var bin = atob(r.Base64), bytes = new Uint8Array(bin.length);
            for (var i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
            var url = window.URL.createObjectURL(new Blob([bytes], { type: r.Tipo }));
            var a = document.createElement('a');
            a.href = url; a.download = r.Nombre;
            document.body.appendChild(a); a.click(); document.body.removeChild(a);
            setTimeout(function () { window.URL.revokeObjectURL(url); }, 2000);
        }).fail(falla).always(function () {
            $b.prop('disabled', false).html('<i class="bx bx-spreadsheet"></i> Excel');
        });
    }

    /* ---------- eventos ---------- */
    $('#ibForm').on('submit', function (ev) { ev.preventDefault(); guardarRegistro(); });
    $('#ibCancelar').on('click', nuevo);
    $('#ibTelefono').on('input', function () {
        // deja escribir con guion pero solo números
        var t = $(this).val().replace(/[^\d\- ]/g, '');
        if (t !== $(this).val()) $(this).val(t);
        $(this).removeClass('is-invalid'); $('#ibTelefonoError').text('');
        revisarTelefono();
    }).on('blur', function () { var t = digitos($(this).val()); if (t.length === 8) $(this).val(formatoTel(t)); });
    $('#ibNombre').on('input', function () { $(this).removeClass('is-invalid'); $('#ibNombreError').text(''); })
        .on('blur', function () { var v = $.trim($(this).val()); if (v && (v === v.toUpperCase() || v === v.toLowerCase())) $(this).val(titulo(v)); });
    $('#ibForm').on('keydown', function (ev) { if (ev.key === 'Escape' && state.editando) nuevo(); });

    $('#ibEstados').on('click', '[data-contesto]', function () {
        $('#ibEstados .btn').removeClass('active'); $(this).addClass('active');
        state.contesto = +$(this).data('contesto'); state.pagina = 1; cargar();
    });
    $('#ibRapidos').on('click', '[data-rango]', function () {
        var r = rango($(this).data('rango'));
        $('#ibDesde').val(r.desde); $('#ibHasta').val(r.hasta);
        $('#ibRapidos [data-rango]').removeClass('active'); $(this).addClass('active');
        guardar(CLAVE_RANGO, $(this).data('rango'));
        state.pagina = 1; cargar();
    });
    $('#ibDesde, #ibHasta').on('change', function () {
        var d = $('#ibDesde').val(), h = $('#ibHasta').val();
        if (d && h && h < d) { showNotification(1, 'warning', 'La fecha final no puede ser anterior a la inicial.'); return; }
        $('#ibRapidos [data-rango]').removeClass('active');
        state.pagina = 1; cargar();
    });
    $('#ibBuscar').on('input', function () {
        clearTimeout(state.timer);
        var v = $.trim($(this).val());
        state.timer = setTimeout(function () { state.texto = /^[\d\- ]+$/.test(v) ? digitos(v) : v; state.pagina = 1; cargar(); }, ESPERA_BUSQUEDA_MS);
    });
    $('#ibRefrescar').on('click', cargar);
    $('#ibExportar').on('click', exportar);
    $('#ibPaginas').on('click', '[data-pagina]', function () {
        var n = +$(this).data('pagina');
        if (n >= 1 && !$(this).parent().hasClass('disabled')) { state.pagina = n; pintar(); }
    });
    $('#ibFilas')
        .on('change', '.ib-marcar', function () { marcar($(this)); })
        .on('click', '.ib-editar', function () { var x = porId(+$(this).closest('tr').data('id')); if (x) editar(x); })
        .on('click', '.ib-eliminar', function () { var x = porId(+$(this).closest('tr').data('id')); if (x) eliminar(x); });

    /* ---------- inicio ---------- */
    if (typeof mtd_ValidateSession === 'function') mtd_ValidateSession();
    var inicial = leer(CLAVE_RANGO) || 'hoy';
    $('#ibRapidos [data-rango="' + inicial + '"]').trigger('click');
    $('#ibTelefono').trigger('focus');

})(jQuery);
