/* Opciones > Videos de turnos (Opciones/frm_Publicidad.aspx) contra Opciones/Publicidad.ashx */
(function ($) {
    'use strict';

    var URL = 'Opciones/Publicidad.ashx', maxMb = 300, envio = null;

    function esc(s) { return $('<div>').text(s == null ? '' : String(s)).html(); }

    function aviso(tipo, texto) {
        if (window.Lobibox) Lobibox.notify(tipo, { msg: texto, position: 'top right', sound: false, delay: 3500, size: 'mini' });
        else if (window.swal) swal({ title: '', text: texto, type: tipo === 'error' ? 'error' : 'success' });
        else alert(texto);
    }

    function pintar(r) {
        if (!r.Ok && !r.Videos) { $('#pbLista').html('<div class="pb-vacio text-danger">' + esc(r.Mensaje) + '</div>'); return; }
        maxMb = r.MaxMb || maxMb; $('#pbMax').text(maxMb);
        var v = r.Videos || [];
        $('#pbConteo').text(v.length ? v.length + (v.length === 1 ? ' video' : ' videos') : '');
        if (!v.length) {
            $('#pbLista').html('<div class="pb-vacio"><i class="bx bx-movie"></i><div>No hay videos. La pantalla de turnos muestra el logo de la clínica.</div></div>');
            return;
        }
        $('#pbLista').html(v.map(function (x, i) {
            return '<div class="pb-item" data-nombre="' + esc(x.Nombre) + '">' +
                '<span class="pb-orden">' + (i + 1) + '</span>' +
                '<button type="button" class="pb-mini" data-accion="ver" title="Vista previa" aria-label="Vista previa de ' + esc(x.Titulo) + '">' +
                    '<video src="' + esc(x.Url) + '#t=1" preload="metadata" muted playsinline tabindex="-1"></video><i class="bx bx-play-circle"></i></button>' +
                '<div class="pb-info"><div class="fw-semibold text-truncate" title="' + esc(x.Nombre) + '">' + esc(x.Titulo) + '</div>' +
                    '<div class="small text-muted">' + esc(x.Tamano) + ' · ' + esc(x.Fecha) + '</div></div>' +
                '<div class="btn-group btn-group-sm ms-auto" role="group">' +
                    '<button type="button" class="btn btn-outline-secondary" data-accion="mover" data-dir="-1" title="Subir" aria-label="Subir"' + (i === 0 ? ' disabled' : '') + '><i class="bx bx-chevron-up"></i></button>' +
                    '<button type="button" class="btn btn-outline-secondary" data-accion="mover" data-dir="1" title="Bajar" aria-label="Bajar"' + (i === v.length - 1 ? ' disabled' : '') + '><i class="bx bx-chevron-down"></i></button>' +
                    '<button type="button" class="btn btn-outline-danger" data-accion="eliminar" title="Eliminar" aria-label="Eliminar"><i class="bx bx-trash"></i></button>' +
                '</div></div>';
        }).join(''));
    }

    function cargar() {
        $.ajax({ url: URL, type: 'GET', dataType: 'json', cache: false })
            .done(pintar)
            .fail(function (x) { pintar(x.responseJSON || { Ok: false, Mensaje: 'No fue posible cargar los videos.' }); });
    }

    function enviar(datos) {
        return $.ajax({ url: URL, type: 'POST', data: datos, dataType: 'json' })
            .done(function (r) { if (r.Mensaje) aviso(r.Ok ? 'success' : 'error', r.Mensaje); pintar(r); })
            .fail(function (x) { aviso('error', (x.responseJSON && x.responseJSON.Mensaje) || 'No fue posible completar la operación.'); });
    }

    /* ---------- subir ---------- */
    function subir(archivo) {
        if (!archivo || envio) return;
        var ext = (archivo.name.split('.').pop() || '').toLowerCase();
        if (ext !== 'mp4' && ext !== 'webm') { aviso('error', 'Solo se aceptan videos .mp4 o .webm.'); return; }
        if (archivo.size > maxMb * 1024 * 1024) { aviso('error', 'El video no debe superar ' + maxMb + ' MB.'); return; }

        var fd = new FormData();
        fd.append('accion', 'subir');
        fd.append('video', archivo);
        $('#pbArchivoNombre').text(archivo.name);
        $('#pbPorcentaje').text('0%'); $('#pbBarra').css('width', '0%');
        $('#pbProgreso').removeClass('d-none'); $('#pbZona').addClass('ocupado');

        envio = new XMLHttpRequest();
        envio.open('POST', URL);
        envio.responseType = 'json';
        envio.upload.onprogress = function (e) {
            if (!e.lengthComputable) return;
            var p = Math.round(e.loaded * 100 / e.total);
            $('#pbPorcentaje').text(p < 100 ? p + '%' : 'Guardando…'); $('#pbBarra').css('width', p + '%');
        };
        envio.onload = function () {
            var r = envio.response || { Ok: false, Mensaje: 'No fue posible subir el video (HTTP ' + envio.status + ').' };
            aviso(r.Ok ? 'success' : 'error', r.Mensaje || (r.Ok ? 'Video agregado.' : 'No fue posible subir el video.'));
            if (r.Videos) pintar(r);
            terminar();
        };
        envio.onerror = function () { aviso('error', 'Se perdió la conexión al subir el video.'); terminar(); };
        envio.onabort = function () { aviso('info', 'Carga cancelada.'); terminar(); };
        envio.send(fd);
    }

    function terminar() {
        envio = null;
        $('#pbProgreso').addClass('d-none'); $('#pbZona').removeClass('ocupado arrastre');
        $('#pbArchivo').val('');
    }

    $('#pbArchivo').on('change', function () { subir(this.files[0]); });
    $('#pbCancelar').on('click', function () { if (envio) envio.abort(); });

    $('#pbZona')
        .on('dragover dragenter', function (e) { e.preventDefault(); if (!envio) $(this).addClass('arrastre'); })
        .on('dragleave dragend', function () { $(this).removeClass('arrastre'); })
        .on('drop', function (e) {
            e.preventDefault(); $(this).removeClass('arrastre');
            var f = e.originalEvent.dataTransfer && e.originalEvent.dataTransfer.files;
            if (f && f.length) subir(f[0]);
        });

    /* ---------- lista ---------- */
    $('#pbLista').on('click', '[data-accion]', function () {
        var $b = $(this), $i = $b.closest('.pb-item'), nombre = $i.data('nombre');
        var accion = $b.data('accion');
        if (accion === 'ver') {
            var src = $i.find('video').attr('src').replace(/#.*$/, '');
            $('#pbModalVerTitulo').text($i.find('.pb-info .fw-semibold').text());
            $('#pbVideoVer').attr('src', src);
            if (window.mtd_OpenModal) mtd_OpenModal('pbModalVer'); else bootstrap.Modal.getOrCreateInstance(document.getElementById('pbModalVer')).show();
        } else if (accion === 'mover') {
            $i.find('button').prop('disabled', true);
            enviar({ accion: 'mover', nombre: nombre, direccion: $b.data('dir') });
        } else if (accion === 'eliminar') {
            var titulo = $i.find('.pb-info .fw-semibold').text();
            var borrar = function () { enviar({ accion: 'eliminar', nombre: nombre }); };
            if (window.swal) swal({ title: '¿Eliminar el video?', text: titulo + ' dejará de verse en la pantalla de turnos.', type: 'warning',
                showCancelButton: true, confirmButtonText: 'Eliminar', cancelButtonText: 'Cancelar', confirmButtonColor: '#dc3545' },
                function (ok) { if (ok) borrar(); });
            else if (confirm('¿Eliminar ' + titulo + '?')) borrar();
        }
    });

    $('#pbModalVer').on('hidden.bs.modal', function () { var v = document.getElementById('pbVideoVer'); v.pause(); v.removeAttribute('src'); v.load(); });

    cargar();
})(jQuery);
