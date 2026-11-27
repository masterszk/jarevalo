/* Formulario del expediente, compartido por la lista (alta) y la ficha (edición).
   Usa los IDs del formulario (#nombres, #apellidos, ...) y los catálogos de la página indicada en opciones.url.
   window.ExpedienteForm.crear({ url: 'Registros/frm_X.aspx/', form: '#exForm' }) */
(function ($) {
    'use strict';

    var TIPO_DUI = '1', TIPO_PASAPORTE = '2', TIPO_RESIDENTE = '3', TIPO_NA = '4', TIPO_EXTRANJERO = '5';     // CAT_TIPOSDOCUMENTOS
    var VACIO = '<option value="-1">--Seleccione una opción--</option>';

    function soloDigitos(s) { return String(s || '').replace(/\D/g, ''); }
    function escHtml(s) { return $('<div>').text(s == null ? '' : String(s)).html(); }

    /* Máscaras de CAT_PAISES: # = dígito, A = letra, * = letra o dígito; lo demás se escribe tal cual.
       Se aplica mientras se escribe: los separadores se agregan solos. */
    function aplicarMascara(valor, mascara) {
        var limpio = String(valor || '').toUpperCase().replace(/[^A-Z0-9Ñ]/g, ''), r = '', i = 0;
        for (var k = 0; k < mascara.length && i < limpio.length; k++) {
            var m = mascara.charAt(k), c = limpio.charAt(i);
            if (m === '#' || m === 'A' || m === '*') {
                var ok = m === '#' ? /\d/.test(c) : m === 'A' ? /[A-ZÑ]/.test(c) : true;
                if (!ok) { i++; k--; continue; }        // se descarta el carácter que no corresponde
                r += c; i++;
            } else r += m;
        }
        return r;
    }
    function regexMascara(mascara) {
        var r = '^';
        for (var k = 0; k < mascara.length; k++) {
            var m = mascara.charAt(k);
            r += m === '#' ? '\\d' : m === 'A' ? '[A-ZÑ]' : m === '*' ? '[A-Z0-9]' : m.replace(/[.*+?^${}()|[\]\\\-]/g, '\\$&');
        }
        return new RegExp(r + '$');
    }
    function ejemplo(mascara) { return String(mascara || '').replace(/#/g, '0').replace(/\*/g, 'X'); }

    // Teléfono con el formato de su país: "7000-0000" (sin código) o "+1 (305) 555-0100" (con código)
    function formatoTelefono(pais, numero, conCodigo) {
        var d = soloDigitos(numero);
        if (!d) return '';
        var t = pais && pais.MascaraTelefono ? aplicarMascara(d, pais.MascaraTelefono) : d;
        if (pais && pais.MascaraTelefono && soloDigitos(t).length < d.length) t = d;      // no cabe en la máscara: sin formato
        return conCodigo && pais ? '+' + pais.Codigo + ' ' + t : t;
    }
    function edadDe(iso) {
        if (!iso) return '';
        var n = new Date(iso + 'T00:00:00'), h = new Date(), edad = h.getFullYear() - n.getFullYear();
        if (h < new Date(h.getFullYear(), n.getMonth(), n.getDate())) edad--;
        return edad >= 0 ? edad + ' años' : '';
    }

    function crear(opciones) {
        var url = opciones.url, $form = $(opciones.form);
        var paises = [], porId = {}, sv = null, telManual = false;

        function pais(id) { return porId[String(id)] || sv; }
        function paisSel() { return pais($('#nacionalidad').val()); }
        function paisTelSel() { return pais($('#paisTel').val()); }

        function api(metodo, datos) {
            return $.ajax({
                type: 'POST',
                url: url + metodo,
                data: JSON.stringify(datos || {}),
                contentType: 'application/json; charset=utf-8',
                dataType: 'json'
            }).then(function (r) { return r.d; });
        }

        // Las respuestas de los catálogos son "OK||<option>..." o "ERROR||mensaje"
        function opcionesEn($sel, metodo, datos) {
            return api(metodo, datos).then(function (r) {
                var p = String(r || '').split('||');
                if (p[0] === 'OK') $sel.html(p[1]);
                else showNotification(1, 'error', p[1] || 'No fue posible cargar el catálogo.');
            });
        }

        function cargarPaises() {
            return api('Paises').then(function (l) {
                paises = l || []; porId = {};
                $.each(paises, function (_, p) { porId[String(p.Id)] = p; if (p.Iso2 === 'SV') sv = p; });
                sv = sv || paises[0] || null;
                $('#nacionalidad').html(paises.map(function (p) { return '<option value="' + p.Id + '">' + escHtml(p.Nombre) + '</option>'; }).join(''));
                $('#paisTel').html(paises.map(function (p) { return '<option value="' + p.Id + '">' + escHtml(p.Nombre) + ' (+' + escHtml(p.Codigo) + ')</option>'; }).join(''));
                if (sv) $('#nacionalidad, #paisTel').val(String(sv.Id));
            });
        }

        function cargarCatalogos() {
            return $.when(
                opcionesEn($('#tipodoc'), 'mtd_LeeTiposDocumentos', { accion: 6 }),
                opcionesEn($('#sexo'), 'mtd_leeSexo', { accion: 4 }),
                opcionesEn($('#departamento'), 'mtd_leeDepartamentos', { accion: 4 }),
                cargarPaises()).then(function () { ajustarNacionalidad(); ajustarTelefonos(); });
        }

        function cargarMunicipios(departamento, seleccion) {
            if (!departamento || String(departamento) === '-1') { $('#municipio').html(VACIO); return $.Deferred().resolve().promise(); }
            return opcionesEn($('#municipio'), 'mtd_leeMunicipios', { departamento: String(departamento), accion: 6 })
                .then(function () { if (seleccion) $('#municipio').val(String(seleccion)); });
        }

        /* ---------- documento según el tipo y la nacionalidad ---------- */
        // Máscara del documento: DUI, documento de identidad del país (si tiene formato) o null (libre)
        function mascaraDocumento() {
            var tipo = $('#tipodoc').val(), p = paisSel();
            if (tipo === TIPO_DUI) return '########-#';
            if (tipo === TIPO_EXTRANJERO && p && p.MascaraDocumento) return p.MascaraDocumento;
            return null;
        }

        function formatearDocumento(v) {
            var tipo = $('#tipodoc').val(), m = mascaraDocumento();
            if (m) return aplicarMascara(v, m);
            v = String(v || '').toUpperCase();
            if (tipo === TIPO_PASAPORTE) return v.replace(/[^A-Z0-9]/g, '').substr(0, 20);
            if (tipo === TIPO_RESIDENTE) return v.replace(/[^A-Z0-9-]/g, '').substr(0, 20);
            return v.replace(/[^A-Z0-9 .-]/g, '').substr(0, 20);
        }

        function ajustarTipoDocumento() {
            var tipo = $('#tipodoc').val(), $d = $('#documento'), p = paisSel();
            var sinDocumento = tipo === TIPO_NA, m = mascaraDocumento();
            $d.prop('disabled', sinDocumento).attr('maxlength', m ? m.length : 20)
                .attr('placeholder', m ? ejemplo(m) : '');
            if (sinDocumento) $d.val(''); else if ($d.val()) $d.val(formatearDocumento($d.val()));
            $('#docRequerido').toggle(!sinDocumento);
            var nombre = p && p.DocumentoNombre ? p.DocumentoNombre : 'Documento de identidad';
            $('#docAyuda').text(
                tipo === TIPO_DUI ? 'Formato: 00000000-0'
                : tipo === TIPO_EXTRANJERO ? nombre + (p ? ' de ' + p.Nombre : '') + (m ? ' · formato: ' + ejemplo(m) : ' · letras y números')
                : tipo === TIPO_PASAPORTE ? 'Pasaporte: letras y números, sin espacios ni guiones'
                : tipo === TIPO_RESIDENTE ? 'Carné de residente: letras, números y guiones'
                : sinDocumento ? 'El paciente no tiene documento.' : '');
        }

        // El DUI es solo para salvadoreños; para otra nacionalidad se usa el documento de su país, pasaporte o carné
        function ajustarNacionalidad() {
            var p = paisSel(), salvadoreno = !p || p.Iso2 === 'SV', $t = $('#tipodoc');
            var tipo = $t.find('option:selected').val();       // antes de deshabilitar opciones (una opción deshabilitada no da valor)
            $t.find('option[value="' + TIPO_DUI + '"]').prop('hidden', !salvadoreno).prop('disabled', !salvadoreno);
            var $ext = $t.find('option[value="' + TIPO_EXTRANJERO + '"]');
            $ext.prop('hidden', salvadoreno).prop('disabled', salvadoreno)
                .text((p && p.DocumentoNombre ? p.DocumentoNombre : 'Documento de identidad') + (p && !salvadoreno ? ' (' + p.Nombre + ')' : ''));
            if (salvadoreno && tipo === TIPO_EXTRANJERO) $t.val(TIPO_DUI);
            if (!salvadoreno && tipo === TIPO_DUI) $t.val(TIPO_PASAPORTE);
            if (!telManual && p) $('#paisTel').val(String(p.Id));        // los teléfonos siguen a la nacionalidad
            ajustarTipoDocumento();
            ajustarTelefonos();
        }

        /* ---------- teléfonos según el país ---------- */
        function ajustarTelefonos() {
            var p = paisTelSel();
            if (!p) return;
            var m = p.MascaraTelefono, largo = p.TelefonoMin === p.TelefonoMax ? p.TelefonoMin + ' dígitos' : 'de ' + p.TelefonoMin + ' a ' + p.TelefonoMax + ' dígitos';
            $('.ex-prefijo').text('+' + p.Codigo);
            $('#celular, #telefono, #emerTelefono').each(function () {
                $(this).attr('maxlength', m ? Math.max(m.length, p.TelefonoMax) : p.TelefonoMax)
                    .attr('placeholder', m ? ejemplo(m) : '')
                    .val(formatoTelefono(p, $(this).val()));
            });
            $('#telAyuda').text(largo + (m ? ' · ' + ejemplo(m) : ''));
        }

        function telefonoValido(v, p) { var d = soloDigitos(v); return d.length >= p.TelefonoMin && d.length <= p.TelefonoMax; }

        function limpiar() {
            $form[0].reset();
            $form.find('.is-invalid').removeClass('is-invalid');
            $('#tipodoc, #sexo, #departamento').val('-1');
            $('#municipio').html(VACIO);
            $('#edadAyuda, #docAyuda').text('');
            telManual = false;
            if (sv) $('#nacionalidad, #paisTel').val(String(sv.Id));
            ajustarNacionalidad();
        }

        // Llena el formulario con un PerfilPacienteDto / ExpedienteEditDto. Espera a que carguen los municipios.
        function llenar(e) {
            $('#nombres').val(e.Nombres);
            $('#apellidos').val(e.Apellidos);
            var nac = pais(e.Pais), tel = pais(e.PaisTelefono || e.Pais);
            if (nac) $('#nacionalidad').val(String(nac.Id));
            if (tel) $('#paisTel').val(String(tel.Id));
            telManual = !!(nac && tel && nac.Id !== tel.Id);
            $('#tipodoc').val(String(e.TipoDocumento || -1));
            ajustarNacionalidad();
            $('#documento').val(e.Documento);
            $('#registro').val(e.Registro);
            $('#nacimiento').val(e.Nacimiento);
            $('#edadAyuda').text(edadDe(e.Nacimiento));
            $('#sexo').val(String(e.Sexo || -1));
            $('#celular').val(formatoTelefono(tel, e.Celular));
            $('#telefono').val(formatoTelefono(tel, e.Telefono));
            $('#email').val(e.Email);
            $('#emerNombre').val(e.PersonaEmergencia);
            $('#emerTelefono').val(formatoTelefono(tel, e.TelefonoEmergencia));
            $('#departamento').val(String(e.Departamento || -1));
            $('#direccion').val(e.Direccion);
            $('#facebook').prop('checked', !!e.Facebook);
            $('#instagram').prop('checked', !!e.Instagram);
            $('#buscador').prop('checked', !!e.Buscador);
            $('#recomendado').prop('checked', !!e.Recomendado);
            $('#tiktok').prop('checked', !!e.TikTok);
            $('#whatsapp').prop('checked', !!e.WhatsApp);
            $('#otros').prop('checked', !!e.Otros);
            return cargarMunicipios(e.Departamento, e.Municipio);
        }

        function datos(id) {
            return {
                Id: id || 0,
                Nombres: $.trim($('#nombres').val()),
                Apellidos: $.trim($('#apellidos').val()),
                TipoDocumento: parseInt($('#tipodoc').val(), 10) || 0,
                Documento: $.trim($('#documento').val()),
                Registro: $.trim($('#registro').val()),
                Nacimiento: $('#nacimiento').val(),
                Sexo: parseInt($('#sexo').val(), 10) || 0,
                Pais: parseInt($('#nacionalidad').val(), 10) || 0,
                PaisTelefono: parseInt($('#paisTel').val(), 10) || 0,
                Celular: soloDigitos($('#celular').val()),
                Telefono: soloDigitos($('#telefono').val()),
                Email: $.trim($('#email').val()),
                PersonaEmergencia: $.trim($('#emerNombre').val()),
                TelefonoEmergencia: soloDigitos($('#emerTelefono').val()),
                Departamento: parseInt($('#departamento').val(), 10) || 0,
                Municipio: parseInt($('#municipio').val(), 10) || 0,
                Direccion: $.trim($('#direccion').val()),
                Facebook: $('#facebook').is(':checked'),
                Instagram: $('#instagram').is(':checked'),
                Buscador: $('#buscador').is(':checked'),
                Recomendado: $('#recomendado').is(':checked'),
                TikTok: $('#tiktok').is(':checked'),
                WhatsApp: $('#whatsapp').is(':checked'),
                Otros: $('#otros').is(':checked')
            };
        }

        // Para detectar cambios sin guardar
        function huella() { return JSON.stringify(datos(0)); }

        function marcar(id, mensaje) {
            var $c = $('#' + id).addClass('is-invalid');
            // si el campo está en una pestaña oculta se muestra antes de enfocarlo
            var $tab = $c.closest('.tab-pane');
            if ($tab.length && !$tab.hasClass('active')) $('[href="#' + $tab.attr('id') + '"]').tab('show');
            $c.trigger('focus');
            showNotification(1, 'warning', mensaje);
            return false;
        }

        function validar() {
            $form.find('.is-invalid').removeClass('is-invalid');
            var tipo = $('#tipodoc').val(), doc = $.trim($('#documento').val());
            var email = $.trim($('#email').val()), nac = $('#nacimiento').val();

            if (!$.trim($('#nombres').val())) return marcar('nombres', 'Ingrese los <strong>nombres</strong> del paciente.');
            if (!$.trim($('#apellidos').val())) return marcar('apellidos', 'Ingrese los <strong>apellidos</strong> del paciente.');
            var p = paisSel(), pt = paisTelSel(), m = mascaraDocumento();
            if (!p) return marcar('nacionalidad', 'Seleccione la <strong>nacionalidad</strong>.');
            if (tipo === '-1' || !tipo) return marcar('tipodoc', 'Seleccione el <strong>tipo de documento</strong>.');
            if (tipo !== TIPO_NA && !doc) return marcar('documento', 'Ingrese el <strong>documento</strong> (o elija el tipo N/A).');
            if (tipo === TIPO_DUI && !/^\d{8}-\d$/.test(doc)) return marcar('documento', 'El <strong>DUI</strong> debe tener el formato 00000000-0.');
            if (tipo === TIPO_PASAPORTE && !/^[A-Z0-9]{5,20}$/.test(doc)) return marcar('documento', 'El <strong>pasaporte</strong> debe tener de 5 a 20 letras o números.');
            if (tipo === TIPO_RESIDENTE && !/^[A-Z0-9][A-Z0-9-]{3,19}$/.test(doc)) return marcar('documento', 'El <strong>carné de residente</strong> debe tener de 4 a 20 letras, números o guiones.');
            if (tipo === TIPO_EXTRANJERO && m && !regexMascara(m).test(doc))
                return marcar('documento', 'El <strong>' + escHtml(p.DocumentoNombre || 'documento') + '</strong> de ' + escHtml(p.Nombre) + ' debe tener el formato ' + escHtml(ejemplo(m)) + '.');
            if (tipo === TIPO_EXTRANJERO && !m && !/^[A-Z0-9][A-Z0-9 .-]{2,19}$/.test(doc)) return marcar('documento', 'El <strong>documento</strong> debe tener de 3 a 20 letras o números.');
            if (!nac) return marcar('nacimiento', 'Ingrese la <strong>fecha de nacimiento</strong>.');
            if (new Date(nac + 'T00:00:00') > new Date()) return marcar('nacimiento', 'La <strong>fecha de nacimiento</strong> no puede ser futura.');
            if ($('#sexo').val() === '-1') return marcar('sexo', 'Seleccione el <strong>sexo</strong>.');
            var largo = pt.TelefonoMin === pt.TelefonoMax ? pt.TelefonoMin + ' dígitos' : 'de ' + pt.TelefonoMin + ' a ' + pt.TelefonoMax + ' dígitos';
            var de = ' de ' + escHtml(pt.Nombre) + ' (+' + escHtml(pt.Codigo) + ') debe tener ' + largo + '.';
            if (!telefonoValido($('#celular').val(), pt)) return marcar('celular', 'El <strong>celular</strong>' + de);
            if ($('#telefono').val() && !telefonoValido($('#telefono').val(), pt)) return marcar('telefono', 'El <strong>teléfono</strong>' + de);
            if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return marcar('email', 'Ingrese un <strong>email</strong> válido.');
            if (!$.trim($('#emerNombre').val())) return marcar('emerNombre', 'Ingrese el <strong>contacto de emergencia</strong>.');
            if (!telefonoValido($('#emerTelefono').val(), pt)) return marcar('emerTelefono', 'El <strong>teléfono de emergencia</strong>' + de);
            if ($('#municipio').val() === '-1' || !$('#municipio').val()) return marcar('municipio', 'Seleccione el <strong>municipio</strong>.');
            if (!$.trim($('#direccion').val())) return marcar('direccion', 'Ingrese la <strong>dirección</strong>.');
            return true;
        }

        /* ---------- formato mientras se escribe ---------- */
        $('#tipodoc').on('change', ajustarTipoDocumento);
        $('#nacionalidad').on('change', ajustarNacionalidad);
        $('#paisTel').on('change', function () { telManual = $(this).val() !== $('#nacionalidad').val(); ajustarTelefonos(); });
        $('#documento').on('input', function () { $(this).val(formatearDocumento($(this).val())); });
        $('#celular, #telefono, #emerTelefono').on('input', function () {
            var p = paisTelSel();
            $(this).val(p ? formatoTelefono(p, soloDigitos($(this).val()).substr(0, p.TelefonoMax)) : soloDigitos($(this).val()));
        });
        $('#registro').on('input', function () { $(this).val($(this).val().toUpperCase()); });
        $('#nacimiento').on('change', function () { $('#edadAyuda').text(edadDe($(this).val())); });
        $('#departamento').on('change', function () { cargarMunicipios($(this).val()); });
        $form.on('input change', '.is-invalid', function () { $(this).removeClass('is-invalid'); });

        return {
            api: api,
            cargarCatalogos: cargarCatalogos,
            limpiar: limpiar,
            llenar: llenar,
            datos: datos,
            huella: huella,
            validar: validar,
            pais: pais,
            /* "+503 7000-0000" con el formato del país (idPais de CAT_PAISES) */
            telefono: function (idPais, numero) { return formatoTelefono(pais(idPais), numero, true); }
        };
    }

    window.ExpedienteForm = { crear: crear, soloDigitos: soloDigitos, formatoTelefono: formatoTelefono };

})(jQuery);
