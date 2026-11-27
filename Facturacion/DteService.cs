using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Web;
using iTextSharp.text;
using iTextSharp.text.pdf;
using Newtonsoft.Json;
using QRCoder;

namespace DPieCenter.Facturacion
{
    // Emisión de DTE (Factura 01 / Crédito Fiscal 03) según los esquemas JSON del Ministerio de Hacienda de El Salvador.
    // Genera el JSON, lo registra en FAC_DTE_DOCUMENTOS y crea la representación gráfica en PDF.
    // La firma y la transmisión al MH no se hacen aquí: el documento queda en estado 'G' (generado) sin sello de recepción.
    public static class DteService
    {
        private const decimal TasaIva = 0.13m;
        private static readonly CultureInfo Inv = CultureInfo.InvariantCulture;

        private static decimal R2(decimal v) { return Math.Round(v, 2, MidpointRounding.AwayFromZero); }

        // ===== Cálculo =====
        // Los precios del catálogo incluyen IVA. En la factura (01) se reportan con IVA incluido;
        // en el crédito fiscal (03) se reporta el valor sin IVA y el impuesto se suma en el resumen.
        // Descuentos en montoDescu de cada línea (en valores) y la venta gravada queda neta:
        //  1) el % del tratamiento (Catálogos › Tratamientos, ItemFacturaDto.Descuento);
        //  2) el cupón, sobre lo que queda (a toda la factura o solo a su tratamiento).
        public static List<LineaDte> Lineas(List<ItemFacturaDto> items, string tipoDte, Registros.CuponFacturaDto cupon = null)
        {
            var lineas = new List<LineaDte>();
            int n = 0;
            decimal tasaDescuento = cupon != null && cupon.NoValido == null ? cupon.Porcentaje / 100m : 0m;
            foreach (var i in items)
            {
                var l = new LineaDte { NumItem = ++n, IdTratamiento = i.IdTratamiento, Cantidad = 1, Descripcion = i.Descripcion, MontoDescu = 0 };
                bool conDescuento = tasaDescuento > 0 && (cupon.IdTratamiento == 0 || cupon.IdTratamiento == i.IdTratamiento);
                l.PrecioUni = tipoDte == TiposDte.CreditoFiscal ? R2(i.Valor / (1 + TasaIva)) : i.Valor;
                l.DescuentoTratamiento = DescuentosTratamiento.Monto(l.PrecioUni, i.Descuento);
                l.DescuentoCupon = conDescuento ? R2((l.PrecioUni - l.DescuentoTratamiento) * tasaDescuento) : 0m;
                l.MontoDescu = l.DescuentoTratamiento + l.DescuentoCupon;
                l.VentaGravada = l.PrecioUni - l.MontoDescu;
                l.IvaItem = tipoDte == TiposDte.CreditoFiscal ? R2(l.VentaGravada * TasaIva) : R2(l.VentaGravada / (1 + TasaIva) * TasaIva);
                lineas.Add(l);
            }
            return lineas;
        }

        public static TotalesDto Totales(List<LineaDte> lineas, string tipoDte)
        {
            decimal gravado = lineas.Sum(l => l.VentaGravada), descuento = lineas.Sum(l => l.MontoDescu);
            if (tipoDte == TiposDte.CreditoFiscal)
            {
                decimal iva = R2(gravado * TasaIva);
                return new TotalesDto { Gravado = gravado, Iva = iva, Total = gravado + iva, Descuento = descuento };
            }
            return new TotalesDto { Gravado = gravado, Iva = lineas.Sum(l => l.IvaItem), Total = gravado, Descuento = descuento };
        }

        /// <summary>Asigna a cada servicio el % de descuento vigente de su tratamiento y el monto (IVA incluido).</summary>
        public static List<ItemFacturaDto> ConDescuentos(List<ItemFacturaDto> items)
        {
            var vigentes = DescuentosTratamiento.Vigentes();
            foreach (var i in items)
            {
                i.Descuento = i.IdTratamiento.HasValue ? DescuentosTratamiento.Porcentaje(vigentes, i.IdTratamiento.Value) : 0m;
                i.MontoDescuento = DescuentosTratamiento.Monto(i.Valor, i.Descuento);
            }
            return items;
        }

        // Factura cobrada: el descuento de cada línea y los totales son los que quedaron en el JSON del DTE (no el catálogo actual).
        // En el crédito fiscal el monto del DTE es sin IVA; en pantalla se muestra con IVA incluido.
        private static TotalesDto DescuentosDelDte(List<ItemFacturaDto> items, DteEmitidoDto dte)
        {
            var d = DteRepository.DocumentoParaArchivos(0, dte.CodigoGeneracion);
            if (d == null) return null;
            var j = Newtonsoft.Json.Linq.JObject.Parse(Convert.ToString(d["JsonDte"]));
            bool ccf = (string)j["identificacion"]["tipoDte"] == TiposDte.CreditoFiscal;
            var cuerpo = (Newtonsoft.Json.Linq.JArray)j["cuerpoDocumento"];
            for (int k = 0; k < items.Count && k < cuerpo.Count; k++)
            {
                decimal precio = (decimal)cuerpo[k]["precioUni"], descu = (decimal)cuerpo[k]["montoDescu"];
                items[k].Descuento = precio > 0 && descu > 0 ? Math.Round(100m * descu / precio, 2) : 0m;
                items[k].MontoDescuento = ccf ? R2(descu * (1 + TasaIva)) : descu;
            }
            var res = j["resumen"];
            return new TotalesDto
            {
                Gravado = (decimal)res["totalGravada"], Total = (decimal)res["totalPagar"], Descuento = (decimal)res["totalDescu"],
                Iva = ccf ? (decimal)res["tributos"][0]["valor"] : (decimal)res["totalIva"]
            };
        }

        public static Dictionary<string, TotalesDto> TotalesPorTipo(List<ItemFacturaDto> items, Registros.CuponFacturaDto cupon = null)
        {
            return new Dictionary<string, TotalesDto>
            {
                { TiposDte.Factura, Totales(Lineas(items, TiposDte.Factura, cupon), TiposDte.Factura) },
                { TiposDte.CreditoFiscal, Totales(Lineas(items, TiposDte.CreditoFiscal, cupon), TiposDte.CreditoFiscal) }
            };
        }

        // ===== Consulta de la pantalla =====
        public static FacturaPagoDto ObtenerFactura(long factura, string user)
        {
            var fac = DteRepository.ObtenerFactura(factura);
            if (fac == null) return new FacturaPagoDto { Ok = false, Mensaje = "La factura no existe." };

            var items = DteRepository.ObtenerItems(factura);
            var cupon = fac.Pagada ? null : Registros.CuponesRepository.CuponDeFactura(factura);
            var dte = fac.Pagada ? DteRepository.ObtenerDteDeFactura(factura) : null;
            Dictionary<string, TotalesDto> totales;
            TotalesDto emitido = null;
            if (dte != null)
                try { emitido = DescuentosDelDte(items, dte); }
                catch (Exception ex) { System.Diagnostics.Trace.TraceError("Descuentos del DTE " + dte.CodigoGeneracion + ": " + ex); }
            if (emitido != null)
                totales = new Dictionary<string, TotalesDto> { { dte.TipoDte, emitido } };
            else
            {
                if (!fac.Pagada) ConDescuentos(items);
                totales = TotalesPorTipo(items, cupon);
            }
            return new FacturaPagoDto
            {
                Ok = true,
                Factura = fac,
                Items = items,
                Cupon = cupon,
                Totales = totales,
                Receptor = DteRepository.BuscarReceptor(fac.IdExpediente, null, user),
                Dte = dte,
                Ticket = fac.Pagada ? CajaRepository.TicketDeFactura(factura) : null
            };
        }

        // ===== Validaciones =====
        private static readonly Regex ReNit = new Regex(@"^([0-9]{14}|[0-9]{9})$");
        private static readonly Regex ReNrc = new Regex(@"^[0-9]{1,8}$");
        private static readonly Regex ReActividad = new Regex(@"^[0-9]{2,6}$");
        private static readonly Regex ReDepto = new Regex(@"^(0[1-9]|1[0-4])$");
        private static readonly Regex ReMunicipio = new Regex(@"^[0-9]{2}$");
        private static readonly Regex ReCorreo = new Regex(@"^[^@\s]+@[^@\s]+\.[^@\s]+$");

        private static string Digitos(string s) { return Regex.Replace(s ?? "", "[^0-9]", ""); }
        private static string Nulo(string s) { return string.IsNullOrWhiteSpace(s) ? null : s.Trim(); }

        public static string ValidarReceptor(ReceptorDto r)
        {
            if (r == null) return "Ingrese los datos fiscales del cliente.";
            r.Nit = Digitos(r.Nit);
            r.Nrc = Digitos(r.Nrc);
            r.CodActividad = Digitos(r.CodActividad);
            r.Nombre = (r.Nombre ?? "").Trim();
            r.NombreComercial = Nulo(r.NombreComercial);
            r.DescActividad = (r.DescActividad ?? "").Trim();
            r.CodDepartamento = (r.CodDepartamento ?? "").Trim();
            r.CodMunicipio = (r.CodMunicipio ?? "").Trim();
            r.CodDistrito = Nulo(r.CodDistrito);
            r.Complemento = (r.Complemento ?? "").Trim();
            r.Telefono = Nulo(Digitos(r.Telefono));
            r.Correo = (r.Correo ?? "").Trim();

            if (!ReNit.IsMatch(r.Nit)) return "El NIT debe tener 14 dígitos (o 9 si es DUI).";
            if (!ReNrc.IsMatch(r.Nrc)) return "El NRC debe tener de 1 a 8 dígitos.";
            if (r.Nombre.Length == 0 || r.Nombre.Length > 250) return "Ingrese el nombre o razón social.";
            if (r.NombreComercial != null && r.NombreComercial.Length > 150) return "El nombre comercial no puede superar 150 caracteres.";
            if (!ReActividad.IsMatch(r.CodActividad)) return "Ingrese el código de actividad económica (2 a 6 dígitos).";
            if (r.DescActividad.Length == 0 || r.DescActividad.Length > 150) return "Ingrese la descripción de la actividad económica (máx. 150).";
            if (!ReDepto.IsMatch(r.CodDepartamento)) return "Seleccione el departamento.";
            if (!ReMunicipio.IsMatch(r.CodMunicipio)) return "Seleccione el municipio.";
            if (r.CodDistrito != null && !ReMunicipio.IsMatch(r.CodDistrito)) return "Seleccione el distrito.";
            if (r.Complemento.Length == 0 || r.Complemento.Length > 200) return "Ingrese la dirección (máx. 200 caracteres).";
            if (r.Telefono != null && (r.Telefono.Length < 8 || r.Telefono.Length > 30)) return "El teléfono debe tener al menos 8 dígitos.";
            if (r.Correo.Length > 100 || !ReCorreo.IsMatch(r.Correo)) return "Ingrese un correo electrónico válido.";
            return null;
        }

        private static string ValidarEmisor(EmisorDte e)
        {
            if (e == null) return "No hay parámetros de facturación electrónica configurados (tabla FAC_DTE_PARAMETROS).";
            if (!ReNit.IsMatch(e.Nit) || !ReNrc.IsMatch(e.Nrc)) return "El NIT/NRC del emisor no es válido. Revise FAC_DTE_PARAMETROS.";
            if (!ReActividad.IsMatch(e.CodActividad) || e.DescActividad.Length == 0) return "Configure la actividad económica del emisor en FAC_DTE_PARAMETROS.";
            if (!ReDepto.IsMatch(e.CodDepartamento) || !ReMunicipio.IsMatch(e.CodMunicipio)) return "Configure el departamento y municipio del emisor en FAC_DTE_PARAMETROS.";
            return null;
        }

        // Documento del consumidor final según CAT-022 del MH (13 DUI, 03 Pasaporte, 02 Carnet de residente, 37 Otro)
        private static void DocumentoConsumidor(ClienteFacturaDto c, out string tipo, out string numero)
        {
            tipo = null; numero = null;
            string doc = (c.Documento ?? "").Trim();
            if (doc.Length == 0) return;
            switch (c.IdTipoDocumento)
            {
                case 1:
                    string d = Digitos(doc);
                    if (d.Length == 9) { tipo = "13"; numero = d.Substring(0, 8) + "-" + d.Substring(8); }
                    break;
                case 2: tipo = "03"; numero = doc.Length > 20 ? doc.Substring(0, 20) : doc; break;
                case 3: tipo = "02"; numero = doc.Length > 20 ? doc.Substring(0, 20) : doc; break;
                case 5: tipo = "37"; numero = doc.Length > 20 ? doc.Substring(0, 20) : doc; break;     // documento de identidad extranjero: "Otro"
            }
        }

        private static string TelefonoValido(string t) { t = Digitos(t); return t.Length >= 8 && t.Length <= 30 ? t : null; }
        private static string CorreoValido(string c) { c = (c ?? "").Trim(); return c.Length <= 100 && ReCorreo.IsMatch(c) ? c : null; }

        // ===== Servicio sin costo: ticket POS =====
        /// <summary>
        /// Hacienda no recibe DTE con valor cero: si todos los servicios valen $0.00 la caja emite un ticket POS interno
        /// (CAJ_TICKETS), que cierra la factura sin generar JSON, PDF ni correo. Requiere la caja del día abierta.
        /// </summary>
        public static PagoResultadoDto EmitirTicket(long factura, string usuario)
        {
            if (factura <= 0) return Error("Solicitud inválida.");
            string user = Registros.AgendaService.UsuarioActual(usuario);
            string errCaja = CajaRepository.ValidarCajaAbierta(user);
            if (errCaja != null) return Error(errCaja);

            var items = DteRepository.ObtenerItems(factura);
            if (items.Count == 0) return Error("Agregue al menos un servicio a la factura.");
            if (items.Sum(i => i.Valor) != 0) return Error("La factura tiene valor: cóbrela con factura o crédito fiscal.");
            if (Registros.CuponesRepository.CuponDeFactura(factura) != null)
                return Error("El servicio no tiene costo: quite el cupón para que el paciente lo conserve.");

            try
            {
                var t = CajaRepository.EmitirTicket(factura, user, "Servicio sin costo");
                return new PagoResultadoDto { Ok = true, Mensaje = "Servicio sin costo: ticket " + t.Numero + " emitido (no se genera DTE).", Ticket = t };
            }
            catch (SqlException ex) when (ex.Number >= 50000)
            {
                return Error(ex.Message);
            }
        }

        // ===== Pago y emisión =====
        public static PagoResultadoDto Pagar(PagoRequest req)
        {
            if (req == null || req.Factura <= 0) return Error("Solicitud inválida.");
            if (req.TipoDte != TiposDte.Factura && req.TipoDte != TiposDte.CreditoFiscal) return Error("Seleccione el tipo de documento.");

            string user = Registros.AgendaService.UsuarioActual(req.Usuario);
            // Solo se emite DTE con la caja del día del usuario abierta (Facturacion/frm_Facturas.aspx)
            string errCaja = CajaRepository.ValidarCajaAbierta(user);
            if (errCaja != null) return Error(errCaja);
            var formas = DteRepository.ObtenerFormasPago();
            bool combinado = req.Pagos != null && req.Pagos.Count > 0;
            if (!combinado && !formas.Any(f => f.Codigo == req.FormaPago)) return Error("Seleccione la forma de pago.");

            var fac = DteRepository.ObtenerFactura(req.Factura);
            if (fac == null) return Error("La factura no existe.");
            if (fac.Pagada) return Error("La factura ya fue pagada.");

            var items = DteRepository.ObtenerItems(req.Factura);
            if (items.Count == 0) return Error("Agregue al menos un servicio a la factura.");

            // Emisor con el establecimiento de la sucursal de la factura (la de su cita)
            var emisor = DteRepository.ObtenerEmisor(DteRepository.SucursalDeFactura(req.Factura));
            string errEmisor = ValidarEmisor(emisor);
            if (errEmisor != null) return Error(errEmisor);

            bool ccf = req.TipoDte == TiposDte.CreditoFiscal;
            if (ccf)
            {
                string errRec = ValidarReceptor(req.Receptor);
                if (errRec != null) return Error(errRec);
            }

            var cupon = Registros.CuponesRepository.CuponDeFactura(req.Factura);
            if (cupon != null && cupon.NoValido != null) return Error(cupon.NoValido + " Quite el cupón de la factura para cobrar.");

            ConDescuentos(items);    // % de cada tratamiento vigente al cobrar
            var lineas = Lineas(items, req.TipoDte, cupon);
            var tot = Totales(lineas, req.TipoDte);
            if (tot.Total <= 0)
                return Error(items.Sum(i => i.Valor) == 0 ? "Los servicios no tienen costo: no se genera DTE. Emita el ticket POS." : "El total de la factura debe ser mayor a cero.");

            // Pago combinado: una línea por forma; sin Pagos, la forma única de siempre
            var solicitadas = combinado ? req.Pagos
                : new List<PagoLineaDto> { new PagoLineaDto { FormaPago = req.FormaPago, Monto = req.FormaPago == "01" ? req.MontoRecibido : tot.Total, Referencia = req.Referencia } };
            decimal cambio;
            string errPago;
            var pagos = AplicarPagos(solicitadas, formas, tot.Total, out cambio, out errPago);
            if (errPago != null) return Error(errPago);
            decimal recibido = tot.Total + cambio;
            // forma principal (la de mayor monto) y referencias en el documento, para las pantallas que muestran una sola
            var forma = formas.First(f => f.Codigo == pagos.OrderByDescending(p => p.Monto).First().FormaPago);
            string referencia = Nulo(string.Join(", ", pagos.Where(p => p.Referencia != null).Select(p => p.Referencia)));
            if (referencia != null && referencia.Length > 50) referencia = referencia.Substring(0, 50);
            string formaTexto = TextoPagos(pagos);

            string codigoGeneracion = Guid.NewGuid().ToString().ToUpperInvariant();
            DateTime emision = DateTime.Now;
            string letras = NumeroALetras(tot.Total);
            int version = ccf ? emisor.VersionCCF : emisor.VersionFE;
            if (EsDte2(req.TipoDte, version))
            {
                if (!ReMunicipio.IsMatch(emisor.CodDistrito ?? ""))
                    return Error("Configure el distrito del emisor en Opciones > Empresa > Facturación electrónica (requerido por DTE 2.0).");
                if (ccf && !ReMunicipio.IsMatch(req.Receptor.CodDistrito ?? ""))
                    return Error("Seleccione el distrito del cliente en los datos fiscales (requerido por DTE 2.0).");
            }
            string numeroControl, json;
            long idDte;

            string tipoDoc, numDoc;
            DocumentoConsumidor(fac, out tipoDoc, out numDoc);
            string receptorNombre = ccf ? req.Receptor.Nombre : fac.Cliente;
            string receptorDocumento = ccf ? req.Receptor.Nit : numDoc;

            try
            {
                using (var cn = new SqlConnection(DteRepository.Cn))
                {
                    cn.Open();
                    using (var tx = cn.BeginTransaction())
                    {
                        long? idReceptor = ccf ? DteRepository.GuardarReceptor(cn, tx, fac.IdExpediente, req.Receptor, user) : (long?)null;
                        numeroControl = DteRepository.SiguienteNumeroControl(cn, tx, req.TipoDte, user, req.Factura);

                        var dte = ConstruirDte(emisor, req.TipoDte, version, numeroControl, codigoGeneracion, emision,
                                               fac, tipoDoc, numDoc, ccf ? req.Receptor : null, lineas, tot, letras,
                                               pagos, user);
                        json = JsonConvert.SerializeObject(dte, Formatting.Indented);

                        idDte = DteRepository.GuardarDte(cn, tx, req.Factura, req.TipoDte, version, emisor.Ambiente, numeroControl, codigoGeneracion,
                                                         emision, idReceptor, receptorNombre, receptorDocumento, tot, letras,
                                                         forma.Codigo, referencia, recibido, cambio, json, user);
                        foreach (var l in lineas) DteRepository.GuardarDetalle(cn, tx, idDte, l);
                        foreach (var p in pagos) DteRepository.GuardarPago(cn, tx, idDte, p, user);
                        // el cupón registra solo su parte del descuento (no la del tratamiento)
                        if (cupon != null) Registros.CuponesRepository.MarcarUsado(cn, tx, req.Factura, lineas.Sum(l => l.DescuentoCupon), user);
                        tx.Commit();
                    }
                }
            }
            catch (SqlException ex) when (ex.Number >= 50000)
            {
                return Error(ex.Message);   // reglas de negocio lanzadas con THROW desde los SPs
            }

            var resultado = new PagoResultadoDto
            {
                Ok = true,
                Cambio = cambio,
                Mensaje = "Pago registrado. " + (ccf ? "Comprobante de crédito fiscal" : "Factura") + " " + numeroControl + " generado.",
                Dte = new DteEmitidoDto
                {
                    Id = idDte, TipoDte = req.TipoDte, NumeroControl = numeroControl, CodigoGeneracion = codigoGeneracion,
                    ReceptorNombre = receptorNombre, Total = tot.Total
                }
            };

            // Archivos: se arman en memoria; si no se pueden guardar en disco (permisos de IIS), el correo igual se envía
            // y el PDF / JSON se pueden descargar desde DteArchivo.ashx, que los rearma desde el JSON guardado.
            byte[] pdf;
            try
            {
                pdf = GenerarPdf(emisor, req.TipoDte, numeroControl, codigoGeneracion, emision, fac, numDoc, ccf ? req.Receptor : null,
                                 lineas, tot, letras, formaTexto, pagos.Count > 1 ? null : referencia, recibido, cambio, user);
            }
            catch (Exception ex)
            {
                DteRepository.RegistrarEvento(idDte, "Archivos", false, "No se pudo generar el PDF: " + ex, user);
                resultado.Mensaje += " No se pudo generar el PDF: " + ex.Message + ". Revise Facturación > Diagnóstico DTE.";
                return resultado;
            }

            resultado.Dte.UrlPdf = DteArchivos.Url(codigoGeneracion, "pdf");
            resultado.Dte.UrlJson = DteArchivos.Url(codigoGeneracion, "json");
            try
            {
                DteArchivos.Guardar(req.TipoDte, codigoGeneracion, json, pdf);
                DteRepository.GuardarArchivos(idDte, resultado.Dte.UrlPdf, resultado.Dte.UrlJson, user);
                DteRepository.RegistrarEvento(idDte, "Archivos", true, "Guardados en " + DteArchivos.Carpeta(), user);
            }
            catch (Exception ex)
            {
                DteRepository.RegistrarEvento(idDte, "Archivos", false, "No se pudieron guardar en " + DteArchivos.Carpeta()
                    + " (cuenta del sitio: " + DteArchivos.Identidad() + "): " + ex.Message, user);
                resultado.Mensaje += " Los archivos no se pudieron guardar en el servidor (" + ex.Message + "); se envían igual por correo.";
            }

            // Correo al cliente: un fallo no anula el pago; se puede reenviar desde la pantalla.
            if (emisor.EnviarCorreo)
            {
                string destino = CorreoValido(ccf ? req.Receptor.Correo : fac.Email);
                if (destino == null)
                    resultado.Mensaje += " El cliente no tiene correo registrado.";
                else
                {
                    string error = EnviarDte(emisor, resultado.Dte, receptorNombre, destino, tot.Total.ToString("N2", Inv), user, pdf, Encoding.UTF8.GetBytes(json));
                    resultado.Mensaje += error == null ? " Enviado a " + destino + "." : " No se pudo enviar el correo: " + error;
                }
            }
            return resultado;
        }

        // Envía el PDF y el JSON del DTE; devuelve null si se envió o el motivo del fallo (queda en FAC_DTE_EVENTOS).
        // Si no se pasan los archivos, se leen del disco o se rearman desde el JSON guardado.
        private static string EnviarDte(EmisorDte emisor, DteEmitidoDto dte, string receptor, string correo, string total, string user,
                                        byte[] pdf = null, byte[] json = null)
        {
            string motivo = DteCorreo.Configuracion(emisor);
            if (motivo != null) { DteRepository.RegistrarEvento(dte.Id, "Correo", false, motivo, user); return motivo; }
            try
            {
                pdf = pdf ?? DteArchivos.Leer(dte.TipoDte, dte.CodigoGeneracion, "pdf") ?? ArchivoDesdeJson(dte.CodigoGeneracion, "pdf");
                json = json ?? DteArchivos.Leer(dte.TipoDte, dte.CodigoGeneracion, "json") ?? ArchivoDesdeJson(dte.CodigoGeneracion, "json");
                if (pdf == null || json == null)
                {
                    DteRepository.RegistrarEvento(dte.Id, "Correo", false, "No se encontraron los archivos del documento.", user);
                    return "No se encontraron los archivos del documento.";
                }

                string nombre = "DTE-" + dte.CodigoGeneracion;
                DteCorreo.Enviar(emisor, correo, "Facturación",       // el tipo y número de documento van en el cuerpo
                    DteCorreo.CuerpoDte(emisor, receptor, dte.TipoDte, dte.NumeroControl, dte.CodigoGeneracion, total),
                    Tuple.Create(nombre + ".pdf", pdf), Tuple.Create(nombre + ".json", json));
            }
            catch (Exception ex)
            {
                DteRepository.RegistrarEvento(dte.Id, "Correo", false, "Servidor " + emisor.SmtpServidor + ":" + emisor.SmtpPuerto + " - " + ex.Message, user);
                return ex.Message;
            }
            DteRepository.RegistrarCorreo(dte.Id, correo, user);
            DteRepository.RegistrarEvento(dte.Id, "Correo", true, "Enviado a " + correo, user);
            dte.CorreoDestino = correo;
            dte.FechaCorreo = Formato.FechaHora(DateTime.Now);
            return null;
        }

        public static PagoResultadoDto ReenviarCorreo(long factura, string correo, string user)
        {
            correo = CorreoValido(correo);
            if (correo == null) return Error("Ingrese un correo electrónico válido.");
            var dte = DteRepository.ObtenerDteDeFactura(factura);
            if (dte == null) return Error("La factura no tiene documento electrónico emitido.");

            string error = EnviarDte(DteRepository.ObtenerEmisor(), dte, dte.ReceptorNombre, correo, dte.Total.ToString("N2", Inv), user);
            if (error != null) return Error("No se pudo enviar el correo: " + error);
            return new PagoResultadoDto { Ok = true, Mensaje = "Documento enviado a " + correo + ".", Dte = dte };
        }

        /// <summary>
        /// Vuelve a guardar el PDF y el JSON de un DTE (rearmados desde el JSON guardado) y, si se indica un correo, lo reenvía.
        /// Para los DTE que se emitieron cuando el servidor no podía guardar archivos o enviar correo.
        /// </summary>
        public static PagoResultadoDto RegenerarYEnviar(long idDte, string correo, string user)
        {
            var d = DteRepository.DocumentoParaArchivos(idDte, null);
            if (d == null) return Error("El documento no existe.");
            if (Convert.ToString(d["Estado"]) == "A") return Error("El documento está anulado.");
            string codigo = Convert.ToString(d["CodigoGeneracion"]).Trim(), tipo = Convert.ToString(d["TipoDte"]);
            byte[] pdf = ArchivoDesdeJson(codigo, "pdf"), json = ArchivoDesdeJson(codigo, "json");
            string mensaje;
            try
            {
                DteArchivos.Guardar(tipo, codigo, Encoding.UTF8.GetString(json), pdf);
                DteRepository.GuardarArchivos(idDte, DteArchivos.Url(codigo, "pdf"), DteArchivos.Url(codigo, "json"), user);
                DteRepository.RegistrarEvento(idDte, "Archivos", true, "Regenerados en " + DteArchivos.Carpeta(), user);
                mensaje = "Archivos regenerados.";
            }
            catch (Exception ex)
            {
                DteRepository.RegistrarEvento(idDte, "Archivos", false, "No se pudieron guardar en " + DteArchivos.Carpeta()
                    + " (cuenta del sitio: " + DteArchivos.Identidad() + "): " + ex.Message, user);
                mensaje = "No se pudieron guardar los archivos: " + ex.Message + ".";
            }

            correo = CorreoValido(correo);
            if (correo == null) return new PagoResultadoDto { Ok = true, Mensaje = mensaje };
            var dte = new DteEmitidoDto
            {
                Id = idDte, TipoDte = tipo, NumeroControl = Convert.ToString(d["NumeroControl"]), CodigoGeneracion = codigo,
                ReceptorNombre = Convert.ToString(d["ReceptorNombre"]), Total = Convert.ToDecimal(d["TotalPagar"])
            };
            string error = EnviarDte(DteRepository.ObtenerEmisor(), dte, dte.ReceptorNombre, correo, dte.Total.ToString("N2", Inv), user, pdf, json);
            return new PagoResultadoDto { Ok = error == null, Mensaje = mensaje + (error == null ? " Enviado a " + correo + "." : " No se pudo enviar el correo: " + error), Dte = dte };
        }

        /// <summary>PDF o JSON de un DTE armado desde el JSON guardado en FAC_DTE_DOCUMENTOS (null si el documento no existe).</summary>
        public static byte[] ArchivoDesdeJson(string codigo, string tipo)
        {
            var d = DteRepository.DocumentoParaArchivos(0, codigo);
            if (d == null) return null;
            string jsonTexto = Convert.ToString(d["JsonDte"]);
            if (tipo == "json") return new UTF8Encoding(false).GetBytes(jsonTexto);

            var j = Newtonsoft.Json.Linq.JObject.Parse(jsonTexto);
            var ident = j["identificacion"];
            var rec = j["receptor"];
            var res = j["resumen"];
            string tipoDte = (string)ident["tipoDte"];
            bool ccf = tipoDte == TiposDte.CreditoFiscal;
            DateTime emision = DateTime.ParseExact((string)ident["fecEmi"] + " " + (string)ident["horEmi"], "yyyy-MM-dd HH:mm:ss", Inv);

            var lineas = new List<LineaDte>();
            foreach (var it in (Newtonsoft.Json.Linq.JArray)j["cuerpoDocumento"])
                lineas.Add(new LineaDte
                {
                    NumItem = (int)it["numItem"], Cantidad = (decimal)it["cantidad"], Descripcion = (string)it["descripcion"],
                    PrecioUni = (decimal)it["precioUni"], MontoDescu = (decimal)it["montoDescu"], VentaGravada = (decimal)it["ventaGravada"],
                    IvaItem = it["ivaItem"] != null && it["ivaItem"].Type != Newtonsoft.Json.Linq.JTokenType.Null ? (decimal)it["ivaItem"] : 0m
                });
            decimal iva = ccf ? (decimal)res["tributos"][0]["valor"] : (decimal)res["totalIva"];
            var tot = new TotalesDto { Gravado = (decimal)res["totalGravada"], Iva = iva, Total = (decimal)res["totalPagar"], Descuento = (decimal)res["totalDescu"] };

            var cliente = new ClienteFacturaDto { Cliente = (string)rec["nombre"], Celular = (string)rec["telefono"], Email = (string)rec["correo"] };
            ReceptorDto receptor = null;
            if (ccf)
            {
                var dir = rec["direccion"];
                receptor = new ReceptorDto
                {
                    Nit = (string)rec["nit"], Nrc = (string)rec["nrc"], Nombre = (string)rec["nombre"], NombreComercial = (string)rec["nombreComercial"],
                    DescActividad = (string)rec["descActividad"], Complemento = dir != null && dir.Type == Newtonsoft.Json.Linq.JTokenType.Object ? (string)dir["complemento"] : null,
                    Telefono = (string)rec["telefono"], Correo = (string)rec["correo"]
                };
            }

            return GenerarPdf(DteRepository.ObtenerEmisor(DteRepository.SucursalDeCodigo(codigo)), tipoDte, (string)ident["numeroControl"], (string)ident["codigoGeneracion"], emision,
                              cliente, ccf ? null : (string)rec["numDocumento"], receptor, lineas, tot, (string)res["totalLetras"],
                              Convert.ToString(d["FormaPagoTexto"]), d["ReferenciaPago"] == DBNull.Value ? null : Convert.ToString(d["ReferenciaPago"]),
                              Convert.ToDecimal(d["MontoRecibido"]), Convert.ToDecimal(d["Cambio"]), Convert.ToString(d["UsuarioCrea"]));
        }

        private static PagoResultadoDto Error(string m) { return new PagoResultadoDto { Ok = false, Mensaje = m }; }

        /// <summary>
        /// Valida las líneas de pago y calcula lo aplicado a cada forma (suma = total). Reglas:
        /// tarjeta y transferencia no pueden pasar del total; el efectivo cubre el resto y el cambio sale solo del efectivo.
        /// Las líneas de la misma forma se juntan.
        /// </summary>
        public static List<PagoAplicado> AplicarPagos(IEnumerable<PagoLineaDto> lineas, List<OpcionPagoDto> formas, decimal total, out decimal cambio, out string error)
        {
            cambio = 0; error = null;
            var pagos = new List<PagoAplicado>();
            foreach (var l in lineas ?? Enumerable.Empty<PagoLineaDto>())
            {
                if (l == null) continue;
                var f = formas.FirstOrDefault(x => x.Codigo == (l.FormaPago ?? "").Trim());
                if (f == null) { error = "Seleccione una forma de pago válida."; return null; }
                decimal monto = R2(l.Monto);
                if (monto <= 0) { error = "Cada forma de pago debe tener un monto mayor a cero (" + f.Descripcion + ")."; return null; }
                string refe = Nulo(l.Referencia);
                if (refe != null && refe.Length > 50) refe = refe.Substring(0, 50);
                var ya = pagos.FirstOrDefault(p => p.FormaPago == f.Codigo);
                if (ya != null) { ya.Monto += monto; ya.Referencia = Nulo(string.Join(", ", new[] { ya.Referencia, refe }.Where(r => r != null))); }
                else pagos.Add(new PagoAplicado { FormaPago = f.Codigo, Descripcion = f.Descripcion, Monto = monto, Referencia = refe });
            }
            if (pagos.Count == 0) { error = "Seleccione la forma de pago."; return null; }

            var efectivo = pagos.FirstOrDefault(p => p.FormaPago == "01");
            decimal otros = pagos.Where(p => p.FormaPago != "01").Sum(p => p.Monto);
            if (otros > total) { error = "Tarjeta y transferencia no pueden pasar del total a pagar ($" + total.ToString("N2", Inv) + ")."; return null; }
            decimal recibido = otros + (efectivo == null ? 0 : efectivo.Monto);
            if (recibido < total)
            {
                error = (pagos.Count == 1 && efectivo != null
                    ? "El monto recibido (" + recibido.ToString("N2", Inv) + ") es menor al total a pagar (" + total.ToString("N2", Inv) + ")."
                    : "Falta $" + (total - recibido).ToString("N2", Inv) + " por cubrir del total ($" + total.ToString("N2", Inv) + ").");
                return null;
            }
            if (efectivo != null)
            {
                decimal aplicado = total - otros;
                if (aplicado <= 0) { error = "El total ya está cubierto con tarjeta o transferencia: quite el efectivo."; return null; }
                efectivo.Recibido = efectivo.Monto;
                cambio = efectivo.Monto - aplicado;
                efectivo.Monto = aplicado;
            }
            return pagos.OrderBy(p => p.FormaPago == "01" ? 1 : 0).ThenByDescending(p => p.Monto).ToList();
        }

        /// <summary>"Billetes y monedas" o "Tarjeta Crédito $15.00 + Billetes y monedas $8.90 (Ref. 1234)".</summary>
        public static string TextoPagos(IList<PagoAplicado> pagos)
        {
            if (pagos.Count == 1) return pagos[0].Descripcion;
            return string.Join(" + ", pagos.Select(p => p.Descripcion + " $" + p.Monto.ToString("N2", Inv) + (p.Referencia != null ? " (Ref. " + p.Referencia + ")" : "")));
        }

        // ===== Empresa emisora =====
        private static readonly string[] TiposEstablecimiento = { "01", "02", "04", "07", "20" };   // CAT-009
        private static readonly Regex ReCodigo4 = new Regex(@"^[A-Za-z0-9]{4}$");

        private static string Recortar(string s, int max) { s = (s ?? "").Trim(); return s.Length > max ? s.Substring(0, max) : s; }

        public static string ValidarEmpresa(EmpresaDteDto e, bool tieneClave)
        {
            if (e == null) return "Solicitud inválida.";
            e.Ambiente = (e.Ambiente ?? "").Trim();
            e.Nit = Digitos(e.Nit);
            e.Nrc = Digitos(e.Nrc);
            e.Nombre = Recortar(e.Nombre, 250);
            e.NombreComercial = Recortar(e.NombreComercial, 150);
            e.CodActividad = Digitos(e.CodActividad);
            e.DescActividad = Recortar(e.DescActividad, 150);
            e.TipoEstablecimiento = (e.TipoEstablecimiento ?? "").Trim();
            e.CodDepartamento = (e.CodDepartamento ?? "").Trim();
            e.CodMunicipio = (e.CodMunicipio ?? "").Trim();
            e.CodDistrito = Nulo(e.CodDistrito);
            e.Complemento = Recortar(e.Complemento, 200);
            e.Telefono = Digitos(e.Telefono);
            e.Correo = (e.Correo ?? "").Trim();
            e.CodEstable = (e.CodEstable ?? "").Trim().ToUpperInvariant();
            e.CodPuntoVenta = (e.CodPuntoVenta ?? "").Trim().ToUpperInvariant();
            e.CodEstableMH = Nulo(e.CodEstableMH)?.ToUpperInvariant();
            e.CodPuntoVentaMH = Nulo(e.CodPuntoVentaMH)?.ToUpperInvariant();
            e.SmtpServidor = Nulo(e.SmtpServidor);
            e.SmtpUsuario = Nulo(e.SmtpUsuario);

            if (e.Ambiente != "00" && e.Ambiente != "01") return "Seleccione el ambiente.";
            if (!ReNit.IsMatch(e.Nit)) return "El NIT debe tener 14 o 9 dígitos.";
            if (!ReNrc.IsMatch(e.Nrc)) return "El NRC debe tener de 1 a 8 dígitos.";
            if (e.Nombre.Length == 0) return "Ingrese el nombre o razón social.";
            if (!ReActividad.IsMatch(e.CodActividad)) return "Ingrese el código de actividad económica (CAT-019).";
            if (e.DescActividad.Length == 0) return "Ingrese la descripción de la actividad económica.";
            if (Array.IndexOf(TiposEstablecimiento, e.TipoEstablecimiento) < 0) return "Seleccione el tipo de establecimiento.";
            if (!ReDepto.IsMatch(e.CodDepartamento)) return "Seleccione el departamento.";
            if (!ReMunicipio.IsMatch(e.CodMunicipio)) return "Seleccione el municipio.";
            if (e.CodDistrito == null || !ReMunicipio.IsMatch(e.CodDistrito)) return "Seleccione el distrito (requerido por DTE 2.0).";
            if (e.VersionFE != 0 && e.VersionFE != 1 && e.VersionFE != 2) return "Seleccione la versión del JSON de la factura.";
            if (e.VersionCCF != 0 && e.VersionCCF != 3 && e.VersionCCF != 4) return "Seleccione la versión del JSON del crédito fiscal.";
            if (e.Complemento.Length == 0) return "Ingrese la dirección.";
            if (e.Telefono.Length < 8 || e.Telefono.Length > 30) return "Ingrese un teléfono válido (mínimo 8 dígitos).";
            if (e.Correo.Length > 100 || !ReCorreo.IsMatch(e.Correo)) return "Ingrese un correo electrónico válido para la empresa.";
            if (!ReCodigo4.IsMatch(e.CodEstable)) return "El código de establecimiento debe tener 4 caracteres (ej. M001).";
            if (!ReCodigo4.IsMatch(e.CodPuntoVenta)) return "El código de punto de venta debe tener 4 caracteres (ej. P001).";
            if (e.CodEstableMH != null && !ReCodigo4.IsMatch(e.CodEstableMH)) return "El código de establecimiento MH debe tener 4 caracteres.";
            if (e.CodPuntoVentaMH != null && !ReCodigo4.IsMatch(e.CodPuntoVentaMH)) return "El código de punto de venta MH debe tener 4 caracteres.";

            if (e.SmtpUsuario != null && (e.SmtpUsuario.Length > 100 || !ReCorreo.IsMatch(e.SmtpUsuario))) return "El usuario del correo debe ser una dirección válida.";
            if (e.SmtpPuerto < 0 || e.SmtpPuerto > 65535) return "Puerto SMTP inválido.";
            if (e.EnviarCorreo)
            {
                if (e.SmtpServidor == null || e.SmtpPuerto == 0 || e.SmtpUsuario == null) return "Para enviar correos ingrese servidor, puerto y usuario SMTP.";
                if (!tieneClave && string.IsNullOrEmpty(e.SmtpClave)) return "Ingrese la clave del correo.";
            }
            return null;
        }

        public static EmpresaResultadoDto GuardarEmpresa(EmpresaDteDto e)
        {
            var actual = DteRepository.ObtenerEmpresa();
            string error = ValidarEmpresa(e, actual != null && actual.TieneClave);
            if (error != null) return new EmpresaResultadoDto { Ok = false, Mensaje = error };

            string user = Registros.AgendaService.UsuarioActual(e.Usuario);
            string clave = string.IsNullOrEmpty(e.SmtpClave) ? null : DteCorreo.Cifrar(e.SmtpClave);
            DteRepository.GuardarEmpresa(e, clave, user);
            return new EmpresaResultadoDto { Ok = true, Mensaje = "Datos de la empresa guardados.", Empresa = DteRepository.ObtenerEmpresa() };
        }

        public const int LogoMaxBytes = 2 * 1024 * 1024;

        // Valida la imagen y la normaliza a PNG de máximo 600 px para que el PDF no pese
        public static byte[] NormalizarLogo(byte[] datos, out string error)
        {
            error = null;
            if (datos == null || datos.Length == 0) { error = "Seleccione una imagen."; return null; }
            if (datos.Length > LogoMaxBytes) { error = "La imagen no debe superar 2 MB."; return null; }
            try
            {
                using (var entrada = new MemoryStream(datos))
                using (var img = System.Drawing.Image.FromStream(entrada))
                {
                    if (!img.RawFormat.Equals(System.Drawing.Imaging.ImageFormat.Png) && !img.RawFormat.Equals(System.Drawing.Imaging.ImageFormat.Jpeg))
                    { error = "El logo debe ser PNG o JPG."; return null; }

                    double escala = Math.Min(1.0, 600.0 / Math.Max(img.Width, img.Height));
                    int w = Math.Max(1, (int)(img.Width * escala)), h = Math.Max(1, (int)(img.Height * escala));
                    using (var bmp = new System.Drawing.Bitmap(w, h, System.Drawing.Imaging.PixelFormat.Format32bppArgb))
                    using (var g = System.Drawing.Graphics.FromImage(bmp))
                    using (var salida = new MemoryStream())
                    {
                        g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
                        g.Clear(System.Drawing.Color.Transparent);
                        g.DrawImage(img, 0, 0, w, h);
                        bmp.Save(salida, System.Drawing.Imaging.ImageFormat.Png);
                        return salida.ToArray();
                    }
                }
            }
            catch (ArgumentException)
            {
                error = "El archivo no es una imagen válida.";
                return null;
            }
        }

        /// <summary>DTE 2.0: Factura versión 2 (fe-f-v2) y Crédito Fiscal versión 4 (fe-ccf-v4).</summary>
        public static bool EsDte2(string tipoDte, int version)
        {
            return tipoDte == TiposDte.CreditoFiscal ? version >= 4 : version >= 2;
        }

        // ===== JSON: Factura v1 / v2 y Crédito Fiscal v3 / v4 según la versión configurada en Opciones > Empresa =====
        private static object ConstruirDte(EmisorDte e, string tipoDte, int version, string numeroControl, string codigoGeneracion, DateTime emision,
            ClienteFacturaDto cliente, string tipoDoc, string numDoc, ReceptorDto rec, List<LineaDte> lineas, TotalesDto t, string letras,
            IList<PagoAplicado> formasPago, string user)
        {
            if (EsDte2(tipoDte, version))
                return ConstruirDte2(e, tipoDte, version, numeroControl, codigoGeneracion, emision, cliente, tipoDoc, numDoc, rec, lineas, t, letras, formasPago, user);

            bool ccf = tipoDte == TiposDte.CreditoFiscal;

            var identificacion = new
            {
                version,
                ambiente = e.Ambiente,
                tipoDte,
                numeroControl,
                codigoGeneracion,
                tipoModelo = 1,
                tipoOperacion = 1,
                tipoContingencia = (int?)null,
                motivoContin = (string)null,
                fecEmi = emision.ToString("yyyy-MM-dd", Inv),
                horEmi = emision.ToString("HH:mm:ss", Inv),
                tipoMoneda = "USD"
            };

            var emisor = new
            {
                nit = e.Nit,
                nrc = e.Nrc,
                nombre = e.Nombre,
                codActividad = e.CodActividad,
                descActividad = e.DescActividad,
                nombreComercial = Nulo(e.NombreComercial),
                tipoEstablecimiento = e.TipoEstablecimiento,
                direccion = new { departamento = e.CodDepartamento, municipio = e.CodMunicipio, complemento = e.Complemento },
                telefono = e.Telefono,
                correo = e.Correo,
                codEstableMH = Nulo(e.CodEstableMH),
                codEstable = Nulo(e.CodEstable),
                codPuntoVentaMH = Nulo(e.CodPuntoVentaMH),
                codPuntoVenta = Nulo(e.CodPuntoVenta)
            };

            object receptor;
            if (ccf)
                receptor = new
                {
                    nit = rec.Nit,
                    nrc = rec.Nrc,
                    nombre = rec.Nombre,
                    codActividad = rec.CodActividad,
                    descActividad = rec.DescActividad,
                    nombreComercial = rec.NombreComercial,
                    direccion = new { departamento = rec.CodDepartamento, municipio = rec.CodMunicipio, complemento = rec.Complemento },
                    telefono = rec.Telefono,
                    correo = rec.Correo
                };
            else
                receptor = new
                {
                    tipoDocumento = tipoDoc,
                    numDocumento = numDoc,
                    nrc = (string)null,
                    nombre = cliente.Cliente,
                    codActividad = (string)null,
                    descActividad = (string)null,
                    direccion = (object)null,
                    telefono = TelefonoValido(cliente.Celular),
                    correo = CorreoValido(cliente.Email)
                };

            var cuerpo = lineas.Select(l => ccf
                ? (object)new
                {
                    numItem = l.NumItem, tipoItem = 2, numeroDocumento = (string)null, cantidad = l.Cantidad,
                    codigo = l.IdTratamiento.HasValue ? l.IdTratamiento.Value.ToString(Inv) : null, codTributo = (string)null,
                    uniMedida = 59, descripcion = l.Descripcion, precioUni = l.PrecioUni, montoDescu = l.MontoDescu,
                    ventaNoSuj = 0m, ventaExenta = 0m, ventaGravada = l.VentaGravada, tributos = new[] { "20" },
                    psv = 0m, noGravado = 0m
                }
                : new
                {
                    numItem = l.NumItem, tipoItem = 2, numeroDocumento = (string)null, cantidad = l.Cantidad,
                    codigo = l.IdTratamiento.HasValue ? l.IdTratamiento.Value.ToString(Inv) : null, codTributo = (string)null,
                    uniMedida = 59, descripcion = l.Descripcion, precioUni = l.PrecioUni, montoDescu = l.MontoDescu,
                    ventaNoSuj = 0m, ventaExenta = 0m, ventaGravada = l.VentaGravada, tributos = (string[])null,
                    psv = 0m, noGravado = 0m, ivaItem = l.IvaItem
                }).ToList();

            // una línea por forma de pago (pago combinado); la suma de montoPago = totalPagar
            var pagos = formasPago.Select(p => new { codigo = p.FormaPago, montoPago = p.Monto, referencia = p.Referencia, plazo = (string)null, periodo = (int?)null }).ToArray();

            object resumen;
            if (ccf)
                resumen = new
                {
                    totalNoSuj = 0m, totalExenta = 0m, totalGravada = t.Gravado, subTotalVentas = t.Gravado,
                    descuNoSuj = 0m, descuExenta = 0m, descuGravada = 0m, porcentajeDescuento = 0m, totalDescu = t.Descuento,   // suma de montoDescu de las líneas (cupón)
                    tributos = new[] { new { codigo = "20", descripcion = "Impuesto al Valor Agregado 13%", valor = t.Iva } },
                    subTotal = t.Gravado, ivaPerci1 = 0m, ivaRete1 = 0m, reteRenta = 0m,
                    montoTotalOperacion = t.Total, totalNoGravado = 0m, totalPagar = t.Total, totalLetras = letras,
                    saldoFavor = 0m, condicionOperacion = 1, pagos, numPagoElectronico = (string)null
                };
            else
                resumen = new
                {
                    totalNoSuj = 0m, totalExenta = 0m, totalGravada = t.Gravado, subTotalVentas = t.Gravado,
                    descuNoSuj = 0m, descuExenta = 0m, descuGravada = 0m, porcentajeDescuento = 0m, totalDescu = t.Descuento,   // suma de montoDescu de las líneas (cupón)
                    tributos = (object)null, subTotal = t.Gravado, ivaRete1 = 0m, reteRenta = 0m,
                    montoTotalOperacion = t.Total, totalNoGravado = 0m, totalPagar = t.Total, totalLetras = letras,
                    totalIva = t.Iva, saldoFavor = 0m, condicionOperacion = 1, pagos, numPagoElectronico = (string)null
                };

            return new
            {
                identificacion,
                documentoRelacionado = (object)null,
                emisor,
                receptor,
                otrosDocumentos = (object)null,
                ventaTercero = (object)null,
                cuerpoDocumento = cuerpo,
                resumen,
                extension = Extension(user, ccf ? rec.Nombre : cliente.Cliente, ccf ? rec.Nit : numDoc),
                apendice = new[] { new { campo = "cajero", etiqueta = "Cajero", valor = user } }
            };
        }

        // v1 / v3: responsables de la entrega y la recepción (los mismos que imprime el PDF)
        private static object Extension(string user, string receptor, string docReceptor)
        {
            string nombre, documento;
            ResponsableEmisor(user, out nombre, out documento);
            Func<string, int, string> corto = (s, max) => string.IsNullOrWhiteSpace(s) ? null : (s.Trim().Length > max ? s.Trim().Substring(0, max) : s.Trim());
            return new
            {
                nombEntrega = corto(nombre, 100),
                docuEntrega = corto(documento, 25),
                nombRecibe = corto(receptor, 100),
                docuRecibe = corto(docReceptor, 25),
                observaciones = (string)null,
                placaVehiculo = (string)null
            };
        }

        /// <summary>
        /// DTE 2.0 (Normativa de Cumplimiento DTE 2.0, mayo 2026): mismo formato del ejemplo de factura v2 aceptado por el MH.
        /// Cambios frente a v1/v3: la dirección lleva "distrito"; el emisor ya no envía tipoEstablecimiento, codEstableMH ni codPuntoVentaMH;
        /// el resumen usa ivaRete (e ivaPerci en CCF) en lugar de ivaRete1/ivaPerci1, ya no lleva reteRenta y agrega observaciones;
        /// no hay nodo "extension".
        /// </summary>
        private static object ConstruirDte2(EmisorDte e, string tipoDte, int version, string numeroControl, string codigoGeneracion, DateTime emision,
            ClienteFacturaDto cliente, string tipoDoc, string numDoc, ReceptorDto rec, List<LineaDte> lineas, TotalesDto t, string letras,
            IList<PagoAplicado> formasPago, string user)
        {
            bool ccf = tipoDte == TiposDte.CreditoFiscal;

            var identificacion = new
            {
                version,
                ambiente = e.Ambiente,
                tipoDte,
                numeroControl,
                codigoGeneracion,
                tipoModelo = 1,
                tipoOperacion = 1,
                tipoContingencia = (int?)null,
                motivoContin = (string)null,
                fecEmi = emision.ToString("yyyy-MM-dd", Inv),
                horEmi = emision.ToString("HH:mm:ss", Inv),
                tipoMoneda = "USD"
            };

            var emisor = new
            {
                nit = e.Nit,
                nrc = e.Nrc,
                nombre = e.Nombre,
                codActividad = e.CodActividad,
                descActividad = e.DescActividad,
                nombreComercial = Nulo(e.NombreComercial),
                direccion = new { departamento = e.CodDepartamento, municipio = e.CodMunicipio, complemento = e.Complemento, distrito = e.CodDistrito },
                telefono = e.Telefono,
                correo = e.Correo,
                codEstable = Nulo(e.CodEstable),
                codPuntoVenta = Nulo(e.CodPuntoVenta)
            };

            object receptor;
            if (ccf)
                receptor = new
                {
                    nit = rec.Nit,
                    nrc = rec.Nrc,
                    nombre = rec.Nombre,
                    codActividad = rec.CodActividad,
                    descActividad = rec.DescActividad,
                    nombreComercial = rec.NombreComercial,
                    direccion = new { departamento = rec.CodDepartamento, municipio = rec.CodMunicipio, complemento = rec.Complemento, distrito = rec.CodDistrito },
                    telefono = rec.Telefono,
                    correo = rec.Correo
                };
            else
                receptor = new
                {
                    tipoDocumento = tipoDoc,
                    numDocumento = numDoc,
                    nrc = (string)null,
                    nombre = cliente.Cliente,
                    codActividad = (string)null,
                    descActividad = (string)null,
                    direccion = (object)null,       // consumidor final: sin dirección
                    telefono = TelefonoValido(cliente.Celular),
                    correo = CorreoValido(cliente.Email)
                };

            // Igual que en v1/v3: el CCF no lleva ivaItem; la factura sí (IVA incluido en el precio)
            var cuerpo = lineas.Select(l => ccf
                ? (object)new
                {
                    numItem = l.NumItem, tipoItem = 2, numeroDocumento = (string)null, cantidad = l.Cantidad,
                    codigo = l.IdTratamiento.HasValue ? l.IdTratamiento.Value.ToString(Inv) : null, codTributo = (string)null,
                    uniMedida = 59, descripcion = l.Descripcion, precioUni = l.PrecioUni, montoDescu = l.MontoDescu,
                    ventaNoSuj = 0m, ventaExenta = 0m, ventaGravada = l.VentaGravada, tributos = new[] { "20" },
                    psv = 0m, noGravado = 0m
                }
                : new
                {
                    numItem = l.NumItem, tipoItem = 2, numeroDocumento = (string)null, cantidad = l.Cantidad,
                    codigo = l.IdTratamiento.HasValue ? l.IdTratamiento.Value.ToString(Inv) : null, codTributo = (string)null,
                    uniMedida = 59, descripcion = l.Descripcion, precioUni = l.PrecioUni, montoDescu = l.MontoDescu,
                    ventaNoSuj = 0m, ventaExenta = 0m, ventaGravada = l.VentaGravada, tributos = (string[])null,
                    psv = 0m, noGravado = 0m, ivaItem = l.IvaItem
                }).ToList();

            // una línea por forma de pago (pago combinado); la suma de montoPago = totalPagar
            var pagos = formasPago.Select(p => new { codigo = p.FormaPago, montoPago = p.Monto, plazo = (string)null, referencia = p.Referencia, periodo = (int?)null }).ToArray();

            object resumen;
            if (ccf)
                resumen = new
                {
                    totalNoSuj = 0m, totalExenta = 0m, totalGravada = t.Gravado, subTotalVentas = t.Gravado,
                    descuNoSuj = 0m, descuExenta = 0m, descuGravada = 0m, porcentajeDescuento = 0m, totalDescu = t.Descuento,
                    tributos = new[] { new { codigo = "20", descripcion = "Impuesto al Valor Agregado 13%", valor = t.Iva } },
                    subTotal = t.Gravado, ivaPerci = 0m, ivaRete = 0m,
                    montoTotalOperacion = t.Total, totalNoGravado = 0m, totalPagar = t.Total, totalLetras = letras,
                    saldoFavor = 0m, condicionOperacion = 1, pagos, numPagoElectronico = (string)null, observaciones = (string)null
                };
            else
                resumen = new
                {
                    totalNoSuj = 0m, totalExenta = 0m, totalGravada = t.Gravado, subTotalVentas = t.Gravado,
                    descuNoSuj = 0m, descuExenta = 0m, descuGravada = 0m, porcentajeDescuento = 0m, totalDescu = t.Descuento,
                    tributos = new object[0], subTotal = t.Gravado, ivaRete = 0m,
                    montoTotalOperacion = t.Total, totalNoGravado = 0m, totalPagar = t.Total, totalLetras = letras,
                    totalIva = t.Iva, saldoFavor = 0m, observaciones = (string)null, condicionOperacion = 1, pagos, numPagoElectronico = (string)null
                };

            return new
            {
                identificacion,
                documentoRelacionado = (object)null,
                emisor,
                receptor,
                otrosDocumentos = (object)null,
                ventaTercero = (object)null,
                cuerpoDocumento = cuerpo,
                resumen,
                apendice = new[] { new { campo = "cajero", etiqueta = "Cajero", valor = user } }
            };
        }

        /// <summary>
        /// JSON de muestra (no se guarda ni se transmite) para revisar la estructura de cada tipo de DTE con la versión indicada.
        /// </summary>
        public static string JsonMuestra(EmisorDte e, string tipoDte, int version, ClienteFacturaDto cliente, string tipoDoc, string numDoc,
            ReceptorDto rec, List<LineaDte> lineas, TotalesDto t, string user)
        {
            string numero = "DTE-" + tipoDte + "-" + (e.CodEstable ?? "M001") + (e.CodPuntoVenta ?? "P001") + "-000000000000000";
            var dte = ConstruirDte(e, tipoDte, version, numero, "00000000-0000-0000-0000-000000000000", DateTime.Now,
                                   cliente, tipoDoc, numDoc, rec, lineas, t, NumeroALetras(t.Total),
                                   new List<PagoAplicado> { new PagoAplicado { FormaPago = "01", Descripcion = "Billetes y monedas", Monto = t.Total } }, user);
            return JsonConvert.SerializeObject(dte, Formatting.Indented);
        }

        // ===== Representación gráfica (PDF) =====
        private static readonly BaseColor Oscuro = new BaseColor(33, 37, 41);
        private static readonly BaseColor Gris = new BaseColor(108, 117, 125);
        private static readonly BaseColor Linea = new BaseColor(222, 226, 230);
        private static readonly BaseColor Fondo = new BaseColor(248, 249, 250);

        private static Font F(float size, int style = Font.NORMAL, BaseColor color = null)
        {
            return FontFactory.GetFont(FontFactory.HELVETICA, BaseFont.CP1252, BaseFont.NOT_EMBEDDED, size, style, color ?? Oscuro);
        }

        private static PdfPCell Celda(Phrase p, int align = Element.ALIGN_LEFT, float padding = 3, int border = Rectangle.NO_BORDER)
        {
            return new PdfPCell(p) { HorizontalAlignment = align, Padding = padding, Border = border, BorderColor = Linea };
        }

        private static Phrase Par(string etiqueta, string valor, float size = 8.5f)
        {
            var p = new Phrase();
            p.Add(new Chunk(etiqueta + " ", F(size, Font.BOLD)));
            p.Add(new Chunk(valor ?? "", F(size)));
            return p;
        }

        private static PdfPTable Seccion(string titulo, float ancho = 100)
        {
            var t = new PdfPTable(1) { WidthPercentage = ancho, SpacingBefore = 8 };
            t.AddCell(new PdfPCell(new Phrase(titulo, F(8.5f, Font.BOLD, BaseColor.WHITE))) { BackgroundColor = Oscuro, Padding = 4, Border = Rectangle.NO_BORDER });
            return t;
        }

        private static string Dinero(decimal v) { return v.ToString("#,##0.00", Inv); }

        // "Responsable por parte de Emisor": el usuario que emitió el documento (nombre completo y documento de Opciones > Usuarios)
        private static void ResponsableEmisor(string usuario, out string nombre, out string documento)
        {
            nombre = (usuario ?? "").Trim(); documento = "";
            if (nombre.Length == 0) return;
            try
            {
                using (var cn = new SqlConnection(DteRepository.Cn))
                using (var cmd = new SqlCommand("SELECT * FROM dbo.Sys_Usuarios WHERE Id_Usuario = @u", cn))   // * : la columna Documento llega con SYS_Administracion.sql
                {
                    cmd.Parameters.Add("@u", System.Data.SqlDbType.VarChar, 25).Value = nombre;
                    cn.Open();
                    using (var rd = cmd.ExecuteReader())
                    {
                        if (!rd.Read()) return;
                        string n = (Convert.ToString(rd["Nombres"]) + " " + Convert.ToString(rd["Apellidos"])).Trim();
                        if (n.Length > 0) nombre = n.ToUpperInvariant();
                        for (int i = 0; i < rd.FieldCount; i++)
                            if (rd.GetName(i) == "Documento" && !rd.IsDBNull(i)) documento = Convert.ToString(rd.GetValue(i)).Trim();
                    }
                }
            }
            catch (SqlException) { }
        }

        // Un logo dañado no debe impedir el PDF
        private static Image Logo(byte[] datos)
        {
            if (datos == null || datos.Length == 0) return null;
            try { return Image.GetInstance(datos); }
            catch (Exception ex) { System.Diagnostics.Trace.TraceWarning("Logo DTE inválido: " + ex.Message); return null; }
        }

        public static byte[] GenerarPdf(EmisorDte e, string tipoDte, string numeroControl, string codigoGeneracion, DateTime emision,
            ClienteFacturaDto cliente, string numDoc, ReceptorDto rec, List<LineaDte> lineas, TotalesDto t, string letras,
            string formaPago, string referencia, decimal recibido, decimal cambio, string user)
        {
            bool ccf = tipoDte == TiposDte.CreditoFiscal;
            using (var ms = new MemoryStream())
            {
                var doc = new Document(PageSize.LETTER, 30, 30, 30, 30);
                PdfWriter.GetInstance(doc, ms);
                doc.Open();

                // Encabezado: logo a la izquierda y título centrado en la página
                var tit = new PdfPTable(3) { WidthPercentage = 100, SpacingAfter = 8 };
                tit.SetWidths(new float[] { 22, 56, 22 });
                var celdaLogo = new PdfPCell { Border = Rectangle.NO_BORDER, VerticalAlignment = Element.ALIGN_MIDDLE };
                Image logo = Logo(e.Logo);
                if (logo != null)
                {
                    logo.ScaleToFit(110, 70);
                    celdaLogo.AddElement(logo);
                }
                tit.AddCell(celdaLogo);
                var titulo = new PdfPCell { Border = Rectangle.NO_BORDER, VerticalAlignment = Element.ALIGN_MIDDLE };
                titulo.AddElement(new Paragraph(ccf ? "COMPROBANTE DE CRÉDITO FISCAL" : "FACTURA", F(15, Font.BOLD)) { Alignment = Element.ALIGN_CENTER });
                titulo.AddElement(new Paragraph("DOCUMENTO TRIBUTARIO ELECTRÓNICO", F(8, Font.NORMAL, Gris)) { Alignment = Element.ALIGN_CENTER });
                tit.AddCell(titulo);
                tit.AddCell(new PdfPCell { Border = Rectangle.NO_BORDER });
                doc.Add(tit);

                var enc = new PdfPTable(2) { WidthPercentage = 100 };
                enc.SetWidths(new float[] { 55, 45 });

                var em = new PdfPTable(1);
                em.AddCell(Celda(new Phrase(string.IsNullOrEmpty(e.NombreComercial) ? e.Nombre : e.NombreComercial, F(12, Font.BOLD))));
                if (!string.IsNullOrEmpty(e.NombreComercial)) em.AddCell(Celda(new Phrase(e.Nombre, F(8.5f))));
                em.AddCell(Celda(new Phrase("NIT: " + e.Nit + " · NRC: " + e.Nrc, F(8.5f))));
                em.AddCell(Celda(Par("Actividad Económica:", e.DescActividad)));
                em.AddCell(Celda(new Phrase(e.Complemento, F(8.5f))));
                em.AddCell(Celda(new Phrase("Tel: " + e.Telefono + " · " + e.Correo, F(8.5f))));
                enc.AddCell(new PdfPCell(em) { Border = Rectangle.NO_BORDER });

                var id = new PdfPTable(1);
                id.AddCell(Celda(new Phrase("Cód. Generación:", F(8, Font.BOLD, Gris))));
                id.AddCell(Celda(new Phrase(codigoGeneracion, F(8.5f))));
                id.AddCell(Celda(new Phrase("No. Control:", F(8, Font.BOLD, Gris))));
                id.AddCell(Celda(new Phrase(numeroControl, F(8.5f))));
                id.AddCell(Celda(new Phrase("Sello de Recepción MH:", F(8, Font.BOLD, Gris))));
                id.AddCell(Celda(new Phrase("Pendiente de transmisión", F(8.5f, Font.ITALIC, Gris))));
                id.AddCell(Celda(new Phrase("Fecha emisión: " + emision.ToString("yyyy-MM-dd", Inv) + " · Hora: " + Formato.HoraSegundos(emision), F(8.5f))));
                if (e.Ambiente != "01") id.AddCell(Celda(new Phrase("AMBIENTE DE PRUEBAS - SIN VALIDEZ TRIBUTARIA", F(8, Font.BOLD, new BaseColor(220, 53, 69)))));
                enc.AddCell(new PdfPCell(id) { Border = Rectangle.BOX, BorderColor = Linea, BackgroundColor = Fondo, Padding = 4 });
                doc.Add(enc);

                // Receptor + QR
                var recT = new PdfPTable(2) { WidthPercentage = 100, SpacingBefore = 8 };
                recT.SetWidths(new float[] { 78, 22 });
                var datos = new PdfPTable(1);
                datos.AddCell(new PdfPCell(new Phrase("RECEPTOR", F(8.5f, Font.BOLD, BaseColor.WHITE))) { BackgroundColor = Oscuro, Padding = 4, Border = Rectangle.NO_BORDER });
                if (ccf)
                {
                    datos.AddCell(Celda(new Phrase(rec.Nombre, F(10, Font.BOLD))));
                    if (!string.IsNullOrEmpty(rec.NombreComercial)) datos.AddCell(Celda(new Phrase(rec.NombreComercial, F(8.5f))));
                    datos.AddCell(Celda(new Phrase("NIT: " + rec.Nit + " · NRC: " + rec.Nrc, F(8.5f))));
                    datos.AddCell(Celda(Par("Actividad Económica:", rec.DescActividad)));
                    datos.AddCell(Celda(new Phrase(rec.Complemento, F(8.5f))));
                    datos.AddCell(Celda(new Phrase("Tel: " + (rec.Telefono ?? "—") + " · " + rec.Correo, F(8.5f))));
                }
                else
                {
                    datos.AddCell(Celda(new Phrase(cliente.Cliente, F(10, Font.BOLD))));
                    if (numDoc != null) datos.AddCell(Celda(Par("Documento:", numDoc)));
                    string contacto = string.Join(" · ", new[] { TelefonoValido(cliente.Celular), CorreoValido(cliente.Email) }.Where(x => x != null));
                    if (contacto.Length > 0) datos.AddCell(Celda(new Phrase("Tel: " + contacto, F(8.5f))));
                }
                recT.AddCell(new PdfPCell(datos) { Border = Rectangle.BOX, BorderColor = Linea });

                string urlConsulta = "https://admin.factura.gob.sv/consultaPublica?ambiente=" + e.Ambiente + "&codGen=" + codigoGeneracion + "&fechaEmi=" + emision.ToString("yyyy-MM-dd", Inv);
                var qr = new PdfPTable(1);
                using (var gen = new QRCodeGenerator())
                using (var data = gen.CreateQrCode(urlConsulta, QRCodeGenerator.ECCLevel.M))
                {
                    var img = iTextSharp.text.Image.GetInstance(new PngByteQRCode(data).GetGraphic(6));
                    img.ScaleToFit(90, 90);
                    qr.AddCell(new PdfPCell(img) { Border = Rectangle.NO_BORDER, HorizontalAlignment = Element.ALIGN_CENTER, Padding = 2 });
                }
                qr.AddCell(Celda(new Phrase("Verifica en\nadmin.factura.gob.sv/consultaPublica", F(6.5f, Font.NORMAL, Gris)), Element.ALIGN_CENTER, 1));
                recT.AddCell(new PdfPCell(qr) { Border = Rectangle.BOX, BorderColor = Linea, VerticalAlignment = Element.ALIGN_MIDDLE });
                doc.Add(recT);

                // Detalle
                doc.Add(Seccion("DETALLE"));
                // La columna de descuento solo aparece si algún servicio lo tiene (tratamiento con descuento o cupón)
                bool conDescuento = lineas.Any(l => l.MontoDescu > 0);
                var det = new PdfPTable(conDescuento ? 6 : 5) { WidthPercentage = 100 };
                det.SetWidths(conDescuento ? new float[] { 5, 8, 51, 12, 10, 14 } : new float[] { 5, 8, 61, 12, 14 });
                foreach (var h in conDescuento ? new[] { "#", "Cant.", "Descripción", "P. Unit.", "Desc.", "Total" } : new[] { "#", "Cant.", "Descripción", "P. Unit.", "Total" })
                    det.AddCell(new PdfPCell(new Phrase(h, F(8, Font.BOLD))) { BackgroundColor = Fondo, BorderColor = Linea, Padding = 4, HorizontalAlignment = h == "Descripción" ? Element.ALIGN_LEFT : Element.ALIGN_RIGHT });
                foreach (var l in lineas)
                {
                    det.AddCell(Celda(new Phrase(l.NumItem.ToString(Inv), F(8.5f)), Element.ALIGN_RIGHT, 4, Rectangle.BOTTOM_BORDER));
                    det.AddCell(Celda(new Phrase(l.Cantidad.ToString("0.##", Inv), F(8.5f)), Element.ALIGN_RIGHT, 4, Rectangle.BOTTOM_BORDER));
                    det.AddCell(Celda(new Phrase(l.Descripcion, F(8.5f)), Element.ALIGN_LEFT, 4, Rectangle.BOTTOM_BORDER));
                    det.AddCell(Celda(new Phrase(Dinero(l.PrecioUni), F(8.5f)), Element.ALIGN_RIGHT, 4, Rectangle.BOTTOM_BORDER));
                    if (conDescuento)
                        det.AddCell(Celda(new Phrase(l.MontoDescu > 0 ? "-" + Dinero(l.MontoDescu) : "", F(8.5f)), Element.ALIGN_RIGHT, 4, Rectangle.BOTTOM_BORDER));
                    det.AddCell(Celda(new Phrase(Dinero(l.VentaGravada), F(8.5f)), Element.ALIGN_RIGHT, 4, Rectangle.BOTTOM_BORDER));
                }
                doc.Add(det);

                // Resumen (formato de la representación gráfica del MH): letras, condición y observaciones a la izquierda; montos a la derecha
                var pie = new PdfPTable(2) { WidthPercentage = 100, SpacingBefore = 8 };
                pie.SetWidths(new float[] { 42, 58 });

                var izq = new PdfPTable(2);
                izq.SetWidths(new float[] { 46, 54 });
                Action<string, string> dato = (k, v) =>
                {
                    izq.AddCell(new PdfPCell(new Phrase(k, F(8, Font.BOLD))) { Border = Rectangle.NO_BORDER, PaddingTop = 2, PaddingBottom = 3, PaddingLeft = 0 });
                    izq.AddCell(new PdfPCell(new Phrase(v ?? "", F(8))) { Border = Rectangle.NO_BORDER, PaddingTop = 2, PaddingBottom = 3 });
                };
                dato("Valor en Letras:", letras);
                dato("Condición de la Operación:", "CONTADO");                 // condicionOperacion = 1
                dato("Forma de Pago:", formaPago + (!string.IsNullOrWhiteSpace(referencia) ? " (Ref. " + referencia + ")" : ""));
                dato("Observaciones:", "");
                pie.AddCell(new PdfPCell(izq) { Border = Rectangle.NO_BORDER, PaddingRight = 10 });

                var der = new PdfPTable(2);
                der.SetWidths(new float[] { 80, 20 });
                Action<string, decimal, bool> fila = (k, v, fuerte) =>
                {
                    var fk = F(8, Font.BOLD); var fv = F(fuerte ? 9 : 8, fuerte ? Font.BOLD : Font.NORMAL);
                    der.AddCell(new PdfPCell(new Phrase(k, fk)) { HorizontalAlignment = Element.ALIGN_RIGHT, Border = Rectangle.NO_BORDER, PaddingTop = 1.5f, PaddingBottom = 2.5f });
                    der.AddCell(new PdfPCell(new Phrase("$" + Dinero(v), fv)) { HorizontalAlignment = Element.ALIGN_RIGHT, Border = Rectangle.NO_BORDER, PaddingTop = 1.5f, PaddingBottom = 2.5f });
                };
                // Factura (01): precios con IVA incluido, el IVA no se detalla. Crédito fiscal (03): el IVA se suma al subtotal
                fila("Sumatoria de ventas", t.Gravado, false);
                fila("Monto global Desc. Rebajas y otros a ventas no sujetas", 0m, false);
                fila("Monto global Desc. Rebajas y otros a ventas exentas", 0m, false);
                fila("Monto global Desc. Rebajas y otros a ventas gravadas", 0m, false);
                fila("Sub-Total", t.Gravado, false);
                if (ccf)
                {
                    fila("IVA 13%", t.Iva, false);
                    fila("IVA Percibido", 0m, false);
                }
                else fila("IVA Retenido", 0m, false);           // ivaRete1 = 0
                if (t.Descuento > 0) fila("Total Descuento", t.Descuento, false);
                fila("Total No Afectas (Cta. Ajena)", 0m, false);
                fila("Monto Total de la Operación", t.Total, true);
                pie.AddCell(new PdfPCell(der) { Border = Rectangle.NO_BORDER });
                doc.Add(pie);

                // Responsables
                string respReceptor = ccf ? rec.Nombre : cliente.Cliente;
                string docReceptor = ccf ? rec.Nit : numDoc;
                var resp = new PdfPTable(4) { WidthPercentage = 100, SpacingBefore = 10 };
                resp.SetWidths(new float[] { 29, 33, 17, 21 });
                Action<string, string, string, string> linea = (k1, v1, k2, v2) =>
                {
                    resp.AddCell(new PdfPCell(new Phrase(k1, F(8, Font.BOLD))) { Border = Rectangle.BOTTOM_BORDER, BorderColor = Linea, Padding = 4 });
                    resp.AddCell(new PdfPCell(new Phrase(v1 ?? "", F(8))) { Border = Rectangle.BOTTOM_BORDER, BorderColor = Linea, Padding = 4 });
                    resp.AddCell(new PdfPCell(new Phrase(k2, F(8, Font.BOLD))) { Border = Rectangle.BOTTOM_BORDER, BorderColor = Linea, Padding = 4 });
                    resp.AddCell(new PdfPCell(new Phrase(v2 ?? "", F(8))) { Border = Rectangle.BOTTOM_BORDER, BorderColor = Linea, Padding = 4 });
                };
                string respEmisor, docEmisor;
                ResponsableEmisor(user, out respEmisor, out docEmisor);
                linea("Responsable por parte de Emisor:", respEmisor, "Documento emisor:", docEmisor);
                linea("Responsable por parte del Receptor:", respReceptor, "Documento receptor:", docReceptor);
                doc.Add(resp);

                doc.Add(new Paragraph("Documento Tributario Electrónico. La autenticidad puede verificarse en admin.factura.gob.sv/consultaPublica usando el Código de Generación y la fecha de emisión.",
                    F(7, Font.NORMAL, Gris)) { SpacingBefore = 10, Alignment = Element.ALIGN_CENTER });

                doc.Close();
                return ms.ToArray();
            }
        }

        // ===== Total en letras: "CIENTO NOVENTA 00/100 DOLARES" =====
        public static string NumeroALetras(decimal valor)
        {
            valor = R2(Math.Abs(valor));
            long entero = (long)Math.Floor(valor);
            int centavos = (int)((valor - entero) * 100);
            return (entero == 0 ? "CERO" : Letras(entero)) + " " + centavos.ToString("00", Inv) + "/100 DOLARES";
        }

        private static readonly string[] Unidades = { "", "UNO", "DOS", "TRES", "CUATRO", "CINCO", "SEIS", "SIETE", "OCHO", "NUEVE",
            "DIEZ", "ONCE", "DOCE", "TRECE", "CATORCE", "QUINCE", "DIECISEIS", "DIECISIETE", "DIECIOCHO", "DIECINUEVE",
            "VEINTE", "VEINTIUNO", "VEINTIDOS", "VEINTITRES", "VEINTICUATRO", "VEINTICINCO", "VEINTISEIS", "VEINTISIETE", "VEINTIOCHO", "VEINTINUEVE" };
        private static readonly string[] Decenas = { "", "", "", "TREINTA", "CUARENTA", "CINCUENTA", "SESENTA", "SETENTA", "OCHENTA", "NOVENTA" };
        private static readonly string[] Centenas = { "", "CIENTO", "DOSCIENTOS", "TRESCIENTOS", "CUATROCIENTOS", "QUINIENTOS", "SEISCIENTOS", "SETECIENTOS", "OCHOCIENTOS", "NOVECIENTOS" };

        private static string Letras(long n)
        {
            if (n == 0) return "";
            if (n < 30) return Unidades[n];
            if (n < 100) return Decenas[n / 10] + (n % 10 > 0 ? " Y " + Unidades[n % 10] : "");
            if (n == 100) return "CIEN";
            if (n < 1000) return (Centenas[n / 100] + " " + Letras(n % 100)).Trim();
            if (n < 1000000)
            {
                long miles = n / 1000;
                return ((miles == 1 ? "MIL" : Apocope(Letras(miles)) + " MIL") + " " + Letras(n % 1000)).Trim();
            }
            long millones = n / 1000000;
            return ((millones == 1 ? "UN MILLON" : Apocope(Letras(millones)) + " MILLONES") + " " + Letras(n % 1000000)).Trim();
        }

        // "VEINTIUNO MIL" -> "VEINTIUN MIL", "TREINTA Y UNO MIL" -> "TREINTA Y UN MIL"
        private static string Apocope(string s) { return s.EndsWith("UNO") ? s.Substring(0, s.Length - 1) : s; }
    }
}
