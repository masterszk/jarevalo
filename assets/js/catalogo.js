/* Pantalla genérica de catálogos (menú Catálogos). Cada webform llama a Catalogo.iniciar({...}) con sus campos y columnas;
   este módulo arma la lista, los filtros, el formulario en un modal y las acciones (activar / inactivar y eliminar).
   Los WebMethods de cada página son Lista, Guardar, Estado y Eliminar (Catalogos/CatalogosRepository.cs). */
(function ($) {
    'use strict';

    var POR_PAGINA = 50;
    var SIN_IMAGEN = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="120" height="90"><rect width="120" height="90" fill="#eef2f3"/><text x="60" y="50" font-family="sans-serif" font-size="12" fill="#8aa0a6" text-anchor="middle">Sin imagen</text></svg>');

    function esc(s) { return $('<div/>').text(s == null ? '' : String(s)).html(); }
    function attr(s) { return esc(s).replace(/"/g, '&quot;'); }
    function normalizar(s) { return String(s || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, ''); }
    function fecha(iso) { if (!iso) return ''; var p = iso.split('T'), f = p[0].split('-'); return f[2] + '/' + f[1] + '/' + f[0]; }
    function dinero(n) { return '$ ' + Number(n || 0).toLocaleString('es-SV', { minimumFractionDigits: 2, maximumFractionDigits: 2 }); }

    function iniciar(cfg) {
        var $raiz = $(cfg.raiz || '#catalogo');
        var activable = cfg.activable !== false;
        var state = { items: [], opciones: [], texto: '', estado: activable ? '1' : '', padre: '', pagina: 1, editando: null, imagen: '' };

        function api(metodo, datos) {
            return $.ajax({ type: 'POST', url: cfg.pagina + '/' + metodo, data: JSON.stringify(datos || {}), contentType: 'application/json; charset=utf-8', dataType: 'json' })
                .then(function (r) { return r.d; });
        }
        function falla(xhr) { if (xhr && xhr.statusText !== 'abort') showNotification(1, 'error', 'Error de conexión (HTTP ' + xhr.status + ').'); }
        function error(r) {
            var m = (r && r.Mensaje) || 'No fue posible completar la acción.';
            if (/sesi[oó]n/i.test(m) && typeof mtd_ValidateSession === 'function') { mtd_ValidateSession(); return; }
            showNotification(1, 'warning', m);
        }
        function confirmar(titulo, texto, boton, ok) {
            swal({ title: titulo, text: texto, type: 'warning', showCancelButton: true, confirmButtonText: boton, cancelButtonText: 'Cancelar', confirmButtonColor: '#DD6B55', closeOnConfirm: true },
                function (si) { if (si) ok(); });
        }
        function modal() { return bootstrap.Modal.getOrCreateInstance(document.getElementById('ctModal')); }

        /* ---------- estructura ---------- */
        function armar() {
            var filtroPadre = cfg.filtroPadre ? '<div class="col-6 col-md-3"><select class="form-select form-select-sm" id="ctPadre" aria-label="' + attr(cfg.filtroPadre) + '"><option value="">' + esc(cfg.filtroPadre) + ': todos</option></select></div>' : '';
            var filtroEstado = activable ? '<div class="col-6 col-md-2"><select class="form-select form-select-sm" id="ctEstado" aria-label="Estado"><option value="">Todos</option><option value="1" selected>Activos</option><option value="0">Inactivos</option></select></div>' : '';
            $raiz.html(
                '<div class="page-breadcrumb d-flex flex-wrap align-items-center gap-2 mb-3">'
                + '<div class="breadcrumb-title pe-3">Catálogos</div>'
                + '<div class="ps-3 d-none d-sm-block"><nav aria-label="breadcrumb"><ol class="breadcrumb mb-0 p-0">'
                + '<li class="breadcrumb-item"><a href="javascript:;"><i class="bx ' + attr(cfg.icono || 'bx-list-ul') + '"></i></a></li>'
                + '<li class="breadcrumb-item active" aria-current="page">' + esc(cfg.titulo) + '</li></ol></nav></div>'
                + '<div class="ms-auto"><button type="button" class="btn btn-primary" id="ctNuevo"><i class="bx bx-plus"></i> Nuevo ' + esc(cfg.singular) + '</button></div></div>'
                + '<div class="card radius-10"><div class="card-body">'
                + (cfg.ayuda ? '<p class="ad-ayuda mb-3"><i class="bx bx-info-circle"></i> ' + cfg.ayuda + '</p>' : '')
                + '<div class="row g-2 mb-3 align-items-center">'
                + '<div class="col-md"><input type="search" class="form-control form-control-sm" id="ctBuscar" placeholder="Buscar…" aria-label="Buscar" /></div>'
                + filtroPadre + filtroEstado
                + '<div class="col-md-auto small text-muted" id="ctConteo"></div></div>'
                + '<div class="table-responsive"><table class="table table-hover mb-0 ad-tabla"><thead class="table-light"><tr>'
                + cfg.columnas.map(function (c) { return '<th class="' + (c.clase || '') + '">' + esc(c.titulo) + '</th>'; }).join('')
                + '<th class="text-center d-none d-md-table-cell" title="Registros que lo usan">En uso</th>'
                + (activable ? '<th class="text-center">Estado</th>' : '')
                + '<th class="d-none d-xl-table-cell">Modificado</th><th><span class="visually-hidden">Acciones</span></th></tr></thead>'
                + '<tbody id="ctFilas"></tbody></table></div>'
                + '<nav class="d-flex flex-wrap justify-content-between align-items-center gap-2 mt-3" aria-label="Paginación"><span class="small text-muted" id="ctPaginaTexto"></span><ul class="pagination pagination-sm mb-0" id="ctPaginas"></ul></nav>'
                + '</div></div>'
                + '<div class="modal fade" id="ctModal" tabindex="-1" aria-labelledby="ctModalTitulo" aria-hidden="true"><div class="modal-dialog' + (cfg.modalGrande ? ' modal-lg' : '') + '"><div class="modal-content">'
                + '<form id="ctForm" novalidate autocomplete="off"><div class="modal-header"><h5 class="modal-title" id="ctModalTitulo"></h5>'
                + '<button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button></div>'
                + '<div class="modal-body"><div class="row g-3">' + cfg.campos.map(campoHtml).join('')
                + (activable ? '<div class="col-12"><div class="form-check form-switch"><input class="form-check-input" type="checkbox" role="switch" id="ct_Activo" checked /><label class="form-check-label" for="ct_Activo">Activo</label></div></div>' : '')
                + '<div class="col-12 small text-muted d-none" id="ctInfo"></div></div></div>'
                + '<div class="modal-footer"><button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Cancelar</button>'
                + '<button type="submit" class="btn btn-primary" id="ctGuardar"><i class="bx bx-save"></i> Guardar</button></div></form></div></div></div>');
        }

        function campoHtml(c) {
            var id = 'ct_' + c.campo, req = c.requerido ? ' <span class="text-danger">*</span>' : '', control;
            var extra = (c.max ? ' maxlength="' + c.max + '"' : '') + (c.placeholder ? ' placeholder="' + attr(c.placeholder) + '"' : '');
            if (c.tipo === 'select') control = '<select class="form-select" id="' + id + '"></select>';
            else if (c.tipo === 'textarea') control = '<textarea class="form-control" id="' + id + '" rows="3"' + extra + '></textarea>';
            else if (c.tipo === 'check') return '<div class="' + (c.col || 'col-12') + '"><div class="form-check form-switch"><input class="form-check-input" type="checkbox" role="switch" id="' + id + '" />'
                + '<label class="form-check-label" for="' + id + '">' + esc(c.etiqueta) + '</label>' + (c.ayuda ? '<div class="form-text">' + c.ayuda + '</div>' : '') + '</div></div>';
            else if (c.tipo === 'color') control = '<div class="d-flex flex-wrap gap-2" id="' + id + '" role="radiogroup">' + (c.colores || []).map(function (x) {
                return '<input type="radio" class="btn-check" name="' + id + '" id="' + id + x.valor + '" value="' + x.valor + '" />'
                    + '<label class="btn btn-sm btn-outline-' + x.valor + '" for="' + id + x.valor + '">' + esc(x.texto) + '</label>';
            }).join('') + '</div>';
            else if (c.tipo === 'imagen') control = '<div class="d-flex align-items-center gap-3"><img id="' + id + 'Vista" class="ct-imagen" alt="Imagen" />'
                + '<div><input type="file" class="form-control form-control-sm" id="' + id + '" accept="image/jpeg,image/png,image/gif,image/webp" />'
                + '<button type="button" class="btn btn-sm btn-link text-danger px-0" id="' + id + 'Quitar">Quitar imagen</button>'
                + '<div class="form-text">JPG, PNG o WebP de hasta 15 MB. Se convierte y reduce automáticamente.</div></div></div>';
            else if (c.tipo === 'porcentaje') control = '<div class="input-group"><input type="number" class="form-control text-end" id="' + id + '"' + extra
                + ' step="0.01" min="0" max="99.99" inputmode="decimal" /><span class="input-group-text">%</span></div>';
            else {
                var tipo = c.tipo === 'numero' || c.tipo === 'dinero' ? 'number' : c.tipo === 'hora' ? 'time' : 'text';
                var paso = c.tipo === 'dinero' ? ' step="0.01" min="0"' : c.tipo === 'numero' ? ' step="1"' + (c.min != null ? ' min="' + c.min + '"' : '') + (c.maxNum != null ? ' max="' + c.maxNum + '"' : '') : '';
                control = (c.tipo === 'dinero' ? '<div class="input-group"><span class="input-group-text">$</span>' : '')
                    + '<input type="' + tipo + '" class="form-control' + (c.tipo === 'dinero' || c.tipo === 'numero' ? ' text-end' : '') + '" id="' + id + '"' + extra + paso + ' />'
                    + (c.tipo === 'dinero' ? '</div>' : '');
            }
            return '<div class="' + (c.col || 'col-12') + '"><label for="' + id + '" class="form-label">' + esc(c.etiqueta) + req + '</label>' + control
                + '<div class="invalid-feedback d-block" id="' + id + 'Error"></div>' + (c.ayuda && c.tipo !== 'check' ? '<div class="form-text">' + c.ayuda + '</div>' : '') + '</div>';
        }

        /* ---------- lista ---------- */
        function cargar() {
            $('#ctFilas').html('<tr><td colspan="9" class="text-center py-4"><div class="spinner-border spinner-border-sm text-primary"></div> Cargando…</td></tr>');
            return api('Lista').done(function (r) {
                if (!r.Ok) { error(r); return; }
                state.items = r.Items || [];
                state.opciones = r.Opciones || [];
                if (cfg.filtroPadre) {
                    var v = $('#ctPadre').val();
                    $('#ctPadre').html('<option value="">' + esc(cfg.filtroPadre) + ': todos</option>' + state.opciones.map(function (o) { return '<option value="' + o.Id + '">' + esc(o.Texto) + '</option>'; }).join('')).val(v);
                }
                pintar();
            }).fail(falla);
        }

        function filtrados() {
            var q = normalizar(state.texto);
            return $.grep(state.items, function (x) {
                if (state.estado !== '' && String(x.Activo ? 1 : 0) !== state.estado) return false;
                if (state.padre && String(x.Padre) !== state.padre) return false;
                return !q || normalizar([x.Descripcion, x.PadreTexto, x.UsuarioSistema, x.Formato, x.Hora].join(' ')).indexOf(q) >= 0;
            });
        }

        function pintar() {
            var lista = filtrados(), total = lista.length, paginas = Math.max(1, Math.ceil(total / POR_PAGINA));
            if (state.pagina > paginas) state.pagina = paginas;
            var ini = (state.pagina - 1) * POR_PAGINA, filas = lista.slice(ini, ini + POR_PAGINA);
            var activos = $.grep(state.items, function (x) { return x.Activo; }).length;
            $('#ctConteo').text(total + ' de ' + state.items.length + (activable ? ' · ' + activos + ' activos' : ''));

            $('#ctFilas').html(filas.length ? filas.map(function (x) {
                var enUso = x.Usos > 0, bloqueado = cfg.bloqueado ? cfg.bloqueado(x) : false;   // registros que el sistema necesita
                return '<tr class="' + (activable && !x.Activo ? 'ad-inactivo' : '') + '" data-id="' + x.Id + '">'
                    + cfg.columnas.map(function (c) { return '<td class="' + (c.clase || '') + '">' + c.html(x, { esc: esc, dinero: dinero }) + '</td>'; }).join('')
                    + '<td class="text-center d-none d-md-table-cell"><span class="ad-chip ' + (enUso ? 'ad-chip-info' : '') + '">' + x.Usos + '</span></td>'
                    + (activable ? '<td class="text-center"><span class="ad-chip ' + (x.Activo ? 'ad-chip-ok' : 'ad-chip-no') + '">' + (x.Activo ? 'Activo' : 'Inactivo') + '</span></td>' : '')
                    + '<td class="d-none d-xl-table-cell small text-muted">' + esc(x.Usuario) + ' · ' + esc(fecha(x.Fecha)) + '</td>'
                    + '<td class="ad-acciones">'
                    + '<button type="button" class="btn btn-sm btn-outline-primary ct-editar" title="Editar"><i class="bx bx-edit-alt"></i></button> '
                    + (activable ? '<button type="button" class="btn btn-sm ' + (x.Activo ? 'btn-outline-warning' : 'btn-outline-success') + ' ct-estado" title="' + (bloqueado ? 'Lo usa el sistema' : x.Activo ? 'Inactivar' : 'Activar') + '"'
                        + (bloqueado && x.Activo ? ' disabled' : '') + '><i class="bx ' + (x.Activo ? 'bx-hide' : 'bx-show') + '"></i></button> ' : '')
                    + '<button type="button" class="btn btn-sm btn-outline-danger ct-eliminar" title="' + (bloqueado ? 'Lo usa el sistema' : enUso ? 'En uso: no se puede eliminar' : 'Eliminar') + '"'
                    + (enUso || bloqueado ? ' disabled' : '') + '><i class="bx bx-trash"></i></button>'
                    + '</td></tr>';
            }).join('') : '<tr><td colspan="9" class="text-center text-muted py-4">No hay registros con estos filtros.</td></tr>');

            $('#ctPaginaTexto').text(total > POR_PAGINA ? 'Mostrando ' + (ini + 1) + '–' + Math.min(ini + POR_PAGINA, total) + ' de ' + total : '');
            var $p = $('#ctPaginas').empty();
            if (paginas > 1) {
                var d = Math.max(1, state.pagina - 2), h = Math.min(paginas, d + 4);
                var item = function (n, t, act, des) { return '<li class="page-item' + (act ? ' active' : '') + (des ? ' disabled' : '') + '"><a class="page-link" href="javascript:;" data-pagina="' + n + '">' + t + '</a></li>'; };
                $p.append(item(state.pagina - 1, '‹', false, state.pagina === 1));
                for (var n = d; n <= h; n++) $p.append(item(n, n, n === state.pagina, false));
                $p.append(item(state.pagina + 1, '›', false, state.pagina === paginas));
            }
        }

        function registroDe(el) { var id = +$(el).closest('tr').data('id'); return $.grep(state.items, function (x) { return x.Id === id; })[0]; }

        /* ---------- formulario ---------- */
        function abrir(x) {
            state.editando = x || null;
            state.imagen = '';
            $('#ctForm .is-invalid').removeClass('is-invalid');
            $('#ctForm .invalid-feedback').text('');
            $('#ctModalTitulo').text((x ? 'Editar ' : 'Nuevo ') + cfg.singular);
            $.each(cfg.campos, function (_, c) {
                var $c = $('#ct_' + c.campo), v = x ? x[c.campo] : (c.defecto != null ? c.defecto : '');
                if (c.tipo === 'select') {
                    var ops = typeof c.opciones === 'function' ? c.opciones(state.opciones) : c.opciones || [];
                    $c.html('<option value="">' + esc(c.vacio || 'Seleccione…') + '</option>' + ops.map(function (o) { return '<option value="' + attr(o.valor) + '">' + esc(o.texto) + '</option>'; }).join(''));
                    if (!x && !v && state.padre && c.campo === 'Padre') v = state.padre;
                    $c.val(v != null && v !== 0 ? String(v) : '');
                } else if (c.tipo === 'check') $c.prop('checked', !!v);
                else if (c.tipo === 'color') $('#ct_' + c.campo + String(v || c.defecto || '').toLowerCase()).prop('checked', true);
                else if (c.tipo === 'imagen') { $c.val(''); vistaImagen(x && x.Imagen ? x.Imagen : ''); }
                else $c.val(v != null ? v : '');
                if (c.soloLectura) $c.prop('disabled', !!(x && c.soloLectura(x)));
            });
            $('#ct_Activo').prop('checked', x ? x.Activo : true);
            $('#ctInfo').toggleClass('d-none', !x).html(x ? 'Lo usan ' + x.Usos + ' registros · Modificado por ' + esc(x.Usuario) + ' el ' + esc(fecha(x.Fecha)) + (cfg.notaEdicion ? '<br>' + cfg.notaEdicion(x) : '') : '');
            modal().show();
            setTimeout(function () { $('#ct_' + cfg.campos[0].campo).trigger('focus'); }, 300);
        }

        function vistaImagen(src) {
            var c = $.grep(cfg.campos, function (x) { return x.tipo === 'imagen'; })[0];
            if (!c) return;
            $('#ct_' + c.campo + 'Vista').attr('src', src || SIN_IMAGEN);
            $('#ct_' + c.campo + 'Quitar').toggle(!!src);
        }

        // Lee cualquier imagen que el navegador pueda mostrar y la devuelve como JPEG (data URL), con el lado mayor <= max
        function aJpeg(archivo, max) {
            var d = $.Deferred(), url = (window.URL || window.webkitURL).createObjectURL(archivo), img = new Image();
            img.onload = function () {
                var esc = Math.min(1, max / Math.max(img.naturalWidth, img.naturalHeight));
                var w = Math.max(1, Math.round(img.naturalWidth * esc)), h = Math.max(1, Math.round(img.naturalHeight * esc));
                var cv = document.createElement('canvas'); cv.width = w; cv.height = h;
                var g = cv.getContext('2d'); g.fillStyle = '#fff'; g.fillRect(0, 0, w, h); g.drawImage(img, 0, 0, w, h);
                (window.URL || window.webkitURL).revokeObjectURL(url);
                d.resolve(cv.toDataURL('image/jpeg', 0.9));
            };
            img.onerror = function () { (window.URL || window.webkitURL).revokeObjectURL(url); d.reject(); };
            img.src = url;
            return d.promise();
        }

        function marcar(campo, texto) {
            $('#ct_' + campo).addClass('is-invalid').trigger('focus');
            $('#ct_' + campo + 'Error').text(texto);
            return false;
        }

        function guardar() {
            $('#ctForm .is-invalid').removeClass('is-invalid');
            $('#ctForm .invalid-feedback').text('');
            var d = { Id: state.editando ? state.editando.Id : 0, Activo: activable ? $('#ct_Activo').is(':checked') : true, ImagenNueva: state.imagen };
            for (var i = 0; i < cfg.campos.length; i++) {
                var c = cfg.campos[i], $c = $('#ct_' + c.campo), v;
                if (c.tipo === 'imagen') continue;
                if (c.tipo === 'check') v = $c.is(':checked');
                else if (c.tipo === 'color') v = $('input[name="ct_' + c.campo + '"]:checked').val() || '';
                else if (c.tipo === 'numero') v = $c.val() === '' ? null : parseInt($c.val(), 10);
                else if (c.tipo === 'dinero' || c.tipo === 'porcentaje') v = $c.val() === '' ? null : Math.round(parseFloat($c.val()) * 100) / 100;
                else if (c.tipo === 'select') v = $c.val();
                else v = $.trim($c.val());
                if (c.requerido && (v === '' || v === null || (typeof v === 'number' && isNaN(v)))) return marcar(c.campo, c.tipo === 'select' || c.tipo === 'color' ? 'Seleccione una opción.' : 'Este dato es obligatorio.');
                if (c.validar) { var m = c.validar(v, d); if (m) return marcar(c.campo, m); }
                if (c.tipo === 'select' && c.numerico) v = +v || 0;
                if ((c.tipo === 'numero' || c.tipo === 'dinero' || c.tipo === 'porcentaje') && (v === null || isNaN(v))) v = 0;
                d[c.campo] = v;
            }
            var $b = $('#ctGuardar'), html = $b.html();
            $b.prop('disabled', true).html('<span class="spinner-border spinner-border-sm"></span> Guardando…');
            api('Guardar', { registro: d }).done(function (r) {
                if (!r.Ok) { error(r); return; }
                showNotification(1, 'success', r.Mensaje);
                modal().hide();
                cargar();
            }).fail(falla).always(function () { $b.prop('disabled', false).html(html); });
        }

        /* ---------- eventos ---------- */
        armar();
        $('#ctNuevo').on('click', function () { abrir(null); });
        $('#ctForm').on('submit', function (ev) { ev.preventDefault(); guardar(); });
        $('#ctForm').on('input change', 'input, select, textarea', function () { $(this).removeClass('is-invalid'); $('#' + this.id + 'Error').text(''); });
        $('#ctBuscar').on('input', function () { state.texto = $.trim($(this).val()); state.pagina = 1; pintar(); });
        $('#ctEstado').on('change', function () { state.estado = $(this).val(); state.pagina = 1; pintar(); });
        $('#ctPadre').on('change', function () { state.padre = $(this).val(); state.pagina = 1; pintar(); });
        $('#ctPaginas').on('click', '[data-pagina]', function () {
            var n = +$(this).data('pagina');
            if (n >= 1 && !$(this).parent().hasClass('disabled')) { state.pagina = n; pintar(); }
        });
        $('#ctFilas')
            .on('click', '.ct-editar', function () { abrir(registroDe(this)); })
            .on('click', '.ct-estado', function () {
                var x = registroDe(this), activar = !x.Activo;
                var hacer = function () {
                    api('Estado', { id: x.Id, activo: activar }).done(function (r) {
                        if (!r.Ok) { error(r); return; }
                        showNotification(1, 'success', r.Mensaje);
                        cargar();
                    }).fail(falla);
                };
                if (activar) hacer();
                else confirmar('Inactivar', '¿Inactivar "' + x.Descripcion + '"? Ya no aparecerá en las listas para elegir, pero se conserva en los registros que lo usan.', 'Inactivar', hacer);
            })
            .on('click', '.ct-eliminar', function () {
                var x = registroDe(this);
                confirmar('Eliminar', '¿Eliminar "' + x.Descripcion + '"?', 'Eliminar', function () {
                    api('Eliminar', { id: x.Id }).done(function (r) {
                        if (!r.Ok) { error(r); return; }
                        showNotification(1, 'success', r.Mensaje);
                        cargar();
                    }).fail(falla);
                });
            });

        // Imagen (tratamientos): se envía en base64 y el servidor la reduce
        $.each(cfg.campos, function (_, c) {
            if (c.tipo !== 'imagen') return;
            $('#ct_' + c.campo).on('change', function () {
                var f = this.files && this.files[0];
                if (!f) return;
                var input = this;
                if (f.type && !/^image\//.test(f.type)) { marcar(c.campo, 'El archivo no es una imagen.'); input.value = ''; return; }
                if (f.size > 15 * 1024 * 1024) { marcar(c.campo, 'La imagen no puede superar 15 MB.'); input.value = ''; return; }
                // El servidor solo lee JPG/PNG/GIF/BMP: se convierte aquí a JPEG (WebP, AVIF, etc.) y se reduce a 1600 px
                aJpeg(f, 1600).done(function (dataUrl) { state.imagen = dataUrl; vistaImagen(dataUrl); })
                    .fail(function () { marcar(c.campo, 'No se pudo leer la imagen. Use una foto JPG o PNG.'); input.value = ''; });
            });
            $('#ct_' + c.campo + 'Quitar').on('click', function () { state.imagen = '-'; $('#ct_' + c.campo).val(''); vistaImagen(''); });
        });

        if (typeof mtd_ValidateSession === 'function') mtd_ValidateSession();
        cargar();
    }

    window.Catalogo = { iniciar: iniciar };
})(jQuery);
