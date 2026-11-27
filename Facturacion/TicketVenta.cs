using System;
using System.Collections.Generic;
using System.Data;
using System.Globalization;
using Newtonsoft.Json.Linq;

namespace DPieCenter.Facturacion
{
    /// <summary>Línea del ticket de venta (como quedó en el DTE).</summary>
    public class ItemTicketVentaDto
    {
        public string Descripcion { get; set; }
        public decimal Cantidad { get; set; }
        public decimal Precio { get; set; }
        /// <summary>Descuento de la línea (tratamiento + cupón).</summary>
        public decimal Descuento { get; set; }
        public decimal Total { get; set; }
    }

    /// <summary>
    /// Ticket de 80 mm de lo facturado: se imprime siempre al cobrar y se puede reimprimir.
    /// Comprobante interno: el documento fiscal es el DTE (factura o crédito fiscal) indicado en el ticket.
    /// </summary>
    public class TicketVentaDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public long IdFactura { get; set; }
        public string Documento { get; set; }          // Factura | Comprobante de crédito fiscal
        public bool CreditoFiscal { get; set; }
        public string NumeroControl { get; set; }
        public string CodigoGeneracion { get; set; }
        public string Fecha { get; set; }              // dd/MM/yyyy hh:mm AM/PM
        public string Cliente { get; set; }
        public string ClienteDocumento { get; set; }
        public List<ItemTicketVentaDto> Items { get; set; } = new List<ItemTicketVentaDto>();
        public decimal Subtotal { get; set; }          // antes de descuentos (como en el DTE)
        public decimal Descuento { get; set; }
        public decimal Gravado { get; set; }
        public decimal Iva { get; set; }
        public decimal Total { get; set; }
        public string FormaPago { get; set; }
        public string Referencia { get; set; }
        public decimal Recibido { get; set; }
        public decimal Cambio { get; set; }
        public string Cajero { get; set; }
        public bool Anulado { get; set; }
        // Encabezado (emisor)
        public string Empresa { get; set; }
        public string EmpresaNit { get; set; }
        public string EmpresaNrc { get; set; }
        public string EmpresaDireccion { get; set; }
        public string EmpresaTelefono { get; set; }
    }

    public static class TicketVenta
    {
        private static readonly CultureInfo Inv = CultureInfo.InvariantCulture;

        private static decimal Dec(JToken t) { return t == null || t.Type == JTokenType.Null ? 0m : t.Value<decimal>(); }
        private static string Txt(DataRow r, string c) { return r.Table.Columns.Contains(c) && r[c] != DBNull.Value ? Convert.ToString(r[c]).Trim() : ""; }

        /// <summary>Ticket del DTE vigente de la factura; Ok = false si la factura aún no tiene DTE.</summary>
        public static TicketVentaDto DeFactura(long factura)
        {
            var dte = DteRepository.ObtenerDteDeFactura(factura);
            if (dte == null) return new TicketVentaDto { Ok = false, Mensaje = "La factura aún no tiene documento emitido." };
            var d = DteRepository.DocumentoParaArchivos(dte.Id, null);
            if (d == null) return new TicketVentaDto { Ok = false, Mensaje = "No se encontró el documento emitido." };

            var j = JObject.Parse(Txt(d, "JsonDte"));
            bool ccf = Txt(d, "TipoDte") == TiposDte.CreditoFiscal;
            var t = new TicketVentaDto
            {
                Ok = true,
                IdFactura = factura,
                CreditoFiscal = ccf,
                Documento = ccf ? "Comprobante de crédito fiscal" : "Factura",
                NumeroControl = Txt(d, "NumeroControl"),
                CodigoGeneracion = Txt(d, "CodigoGeneracion"),
                Cliente = Txt(d, "ReceptorNombre"),
                FormaPago = Txt(d, "FormaPagoTexto"),
                Referencia = Txt(d, "ReferenciaPago"),
                Recibido = d["MontoRecibido"] == DBNull.Value ? 0 : Convert.ToDecimal(d["MontoRecibido"]),
                Cambio = d["Cambio"] == DBNull.Value ? 0 : Convert.ToDecimal(d["Cambio"]),
                Cajero = Txt(d, "UsuarioCrea"),
                Anulado = Txt(d, "Estado") == "A"
            };
            var rec = j["receptor"];
            if (rec != null && rec.Type == JTokenType.Object)
                t.ClienteDocumento = (string)(rec["nit"] ?? rec["numDocumento"]) ?? "";

            if (d["FechaEmision"] != DBNull.Value)
            {
                DateTime fecha = Convert.ToDateTime(d["FechaEmision"]).Date;
                if (d["HoraEmision"] is TimeSpan) fecha += (TimeSpan)d["HoraEmision"];
                t.Fecha = Formato.FechaHora(fecha);
            }

            foreach (var l in (JArray)j["cuerpoDocumento"])
            {
                decimal cant = Dec(l["cantidad"]), precio = Dec(l["precioUni"]), descu = Dec(l["montoDescu"]);
                t.Items.Add(new ItemTicketVentaDto
                {
                    Descripcion = (string)l["descripcion"],
                    Cantidad = cant,
                    Precio = precio,
                    Descuento = descu,
                    Total = Dec(l["ventaGravada"])
                });
                t.Subtotal += cant * precio;
            }
            var res = j["resumen"];
            t.Descuento = Dec(res["totalDescu"]);
            t.Gravado = Dec(res["totalGravada"]);
            t.Total = Dec(res["totalPagar"]);
            var tributos = res["tributos"] as JArray;
            t.Iva = ccf ? (tributos != null && tributos.Count > 0 ? Dec(tributos[0]["valor"]) : 0m) : Dec(res["totalIva"]);

            var e = DteRepository.ObtenerEmisor(DteRepository.SucursalDeFactura(factura));
            if (e != null)
            {
                t.Empresa = string.IsNullOrWhiteSpace(e.NombreComercial) ? e.Nombre : e.NombreComercial;
                t.EmpresaNit = e.Nit; t.EmpresaNrc = e.Nrc; t.EmpresaDireccion = e.Complemento; t.EmpresaTelefono = e.Telefono;
            }
            return t;
        }
    }
}
