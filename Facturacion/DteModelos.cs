using System.Collections.Generic;

namespace DPieCenter.Facturacion
{
    public static class TiposDte
    {
        public const string Factura = "01";          // Consumidor final
        public const string CreditoFiscal = "03";    // Comprobante de crédito fiscal
    }

    public class ItemFacturaDto
    {
        public long Id { get; set; }
        public long? IdTratamiento { get; set; }
        public string Descripcion { get; set; }
        public decimal Valor { get; set; }           // precio con IVA incluido
        /// <summary>Descuento del tratamiento en % (catálogo; en una factura cobrada, el que quedó en el DTE). 0 = sin descuento.</summary>
        public decimal Descuento { get; set; }
        /// <summary>Monto del descuento del tratamiento sobre Valor (IVA incluido).</summary>
        public decimal MontoDescuento { get; set; }
    }

    public class TotalesDto
    {
        public decimal Gravado { get; set; }
        public decimal Iva { get; set; }
        public decimal Total { get; set; }
        public decimal Descuento { get; set; }       // suma de montoDescu (cupón o descuento manual en %)
    }

    public class ClienteFacturaDto
    {
        public long IdFactura { get; set; }
        public bool Pagada { get; set; }
        public long IdExpediente { get; set; }
        public string Cliente { get; set; }
        public string Documento { get; set; }
        public long? IdTipoDocumento { get; set; }
        public string Celular { get; set; }
        public string Email { get; set; }
        public string Direccion { get; set; }
        /// <summary>Cobro de una cita por adelantado (aún no atendida).</summary>
        public bool Anticipo { get; set; }
        /// <summary>Pago adelantado sin cita (monto libre): la cita queda pendiente de agendar.</summary>
        public bool MontoLibre { get; set; }
        public string CitaInicio { get; set; }        // dd/MM/yyyy hh:mm AM/PM
    }

    public class ReceptorDto
    {
        public long Id { get; set; }
        public string Nit { get; set; }
        public string Nrc { get; set; }
        public string Nombre { get; set; }
        public string NombreComercial { get; set; }
        public string CodActividad { get; set; }
        public string DescActividad { get; set; }
        public string CodDepartamento { get; set; }
        public string CodMunicipio { get; set; }
        public string CodDistrito { get; set; }       // DTE 2.0: antiguo municipio (dte-catalogos.js)
        public string Complemento { get; set; }
        public string Telefono { get; set; }
        public string Correo { get; set; }
    }

    public class DteEmitidoDto
    {
        public long Id { get; set; }
        public string TipoDte { get; set; }
        public string NumeroControl { get; set; }
        public string CodigoGeneracion { get; set; }
        public string UrlPdf { get; set; }
        public string UrlJson { get; set; }
        public string ReceptorNombre { get; set; }
        public decimal Total { get; set; }
        public string CorreoDestino { get; set; }     // último envío por correo
        public string FechaCorreo { get; set; }
    }

    public class FacturaPagoDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public ClienteFacturaDto Factura { get; set; }
        public List<ItemFacturaDto> Items { get; set; } = new List<ItemFacturaDto>();
        public Dictionary<string, TotalesDto> Totales { get; set; } = new Dictionary<string, TotalesDto>();   // por tipo de DTE
        public ReceptorDto Receptor { get; set; }
        public DteEmitidoDto Dte { get; set; }
        public Registros.CuponFacturaDto Cupon { get; set; }   // cupón aplicado (antes de cobrar)
        public TicketPosDto Ticket { get; set; }   // factura sin costo cerrada con ticket POS (no tiene DTE)
    }

    public class OpcionPagoDto
    {
        public string Codigo { get; set; }
        public string Descripcion { get; set; }
    }

    public class ServicioDto
    {
        public long Id { get; set; }
        public string Descripcion { get; set; }
        public decimal Precio { get; set; }
        public int Duracion { get; set; }
        /// <summary>Descuento del tratamiento en % (0 = sin descuento).</summary>
        public decimal Descuento { get; set; }
    }

    public class ServiciosDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public List<ServicioDto> Servicios { get; set; } = new List<ServicioDto>();
    }

    public class ReceptorResultadoDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public ReceptorDto Receptor { get; set; }
    }

    public class PagoRequest
    {
        public long Factura { get; set; }
        public string TipoDte { get; set; }           // "01" o "03"
        public string FormaPago { get; set; }         // CAT-017 (una sola forma; se usa si Pagos viene vacío)
        public string Referencia { get; set; }
        public decimal MontoRecibido { get; set; }
        /// <summary>Pago combinado: una línea por forma de pago. En efectivo, Monto = lo recibido (el cambio sale de ahí).</summary>
        public List<PagoLineaDto> Pagos { get; set; }
        public ReceptorDto Receptor { get; set; }     // obligatorio para crédito fiscal
        public string Usuario { get; set; }           // $('#idUser').val()
    }

    public class PagoLineaDto
    {
        public string FormaPago { get; set; }         // CAT-017: 01 efectivo, 03 tarjeta, 05 transferencia
        public decimal Monto { get; set; }
        public string Referencia { get; set; }
    }

    /// <summary>Línea de pago ya validada: Monto aplicado al total (en efectivo, recibido menos cambio).</summary>
    public class PagoAplicado
    {
        public string FormaPago { get; set; }
        public string Descripcion { get; set; }
        public decimal Monto { get; set; }
        public decimal? Recibido { get; set; }        // solo efectivo
        public string Referencia { get; set; }
    }

    public class PagoResultadoDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public decimal Cambio { get; set; }
        public DteEmitidoDto Dte { get; set; }
        public TicketPosDto Ticket { get; set; }       // servicio sin costo: ticket POS en lugar de DTE
    }

    public class ResultadoDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
    }

    // Datos de la empresa emisora (Opciones/form_confEmpresa.aspx, pestaña Facturación electrónica)
    public class EmpresaDteDto
    {
        public string Ambiente { get; set; }
        public string Nit { get; set; }
        public string Nrc { get; set; }
        public string Nombre { get; set; }
        public string NombreComercial { get; set; }
        public string CodActividad { get; set; }
        public string DescActividad { get; set; }
        public string TipoEstablecimiento { get; set; }
        public string CodDepartamento { get; set; }
        public string CodMunicipio { get; set; }
        public string CodDistrito { get; set; }       // DTE 2.0: antiguo municipio (dte-catalogos.js)
        public string Complemento { get; set; }
        public string Telefono { get; set; }
        public string Correo { get; set; }
        public string CodEstableMH { get; set; }
        public string CodEstable { get; set; }
        public string CodPuntoVentaMH { get; set; }
        public string CodPuntoVenta { get; set; }
        public string SmtpServidor { get; set; }
        public int SmtpPuerto { get; set; }
        public string SmtpUsuario { get; set; }
        public string SmtpClave { get; set; }         // solo al guardar; vacía = no cambia
        public bool EnviarCorreo { get; set; }
        public int VersionFE { get; set; }            // 1 o 2 (DTE 2.0)
        public int VersionCCF { get; set; }           // 3 o 4 (DTE 2.0)
        public bool TieneClave { get; set; }
        public bool TieneLogo { get; set; }
        public string Version { get; set; }           // para refrescar la vista previa del logo
        public string Usuario { get; set; }           // $('#idUser').val()
    }

    public class EmpresaResultadoDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public EmpresaDteDto Empresa { get; set; }
    }

    // ===== Uso interno =====
    public class EmisorDte
    {
        public string Ambiente { get; set; }
        public string Nit { get; set; }
        public string Nrc { get; set; }
        public string Nombre { get; set; }
        public string NombreComercial { get; set; }
        public string CodActividad { get; set; }
        public string DescActividad { get; set; }
        public string TipoEstablecimiento { get; set; }
        public string CodDepartamento { get; set; }
        public string CodMunicipio { get; set; }
        public string CodDistrito { get; set; }       // DTE 2.0: antiguo municipio (dte-catalogos.js)
        public string Complemento { get; set; }
        public string Telefono { get; set; }
        public string Correo { get; set; }
        public string CodEstableMH { get; set; }
        public string CodEstable { get; set; }
        public string CodPuntoVentaMH { get; set; }
        public string CodPuntoVenta { get; set; }
        public int VersionFE { get; set; }
        public int VersionCCF { get; set; }
        public byte[] Logo { get; set; }
        public string SmtpServidor { get; set; }
        public int SmtpPuerto { get; set; }
        public string SmtpUsuario { get; set; }
        public string SmtpClave { get; set; }         // cifrada; ver DteCorreo.Descifrar
        public bool EnviarCorreo { get; set; }
    }

    public class LineaDte
    {
        public int NumItem { get; set; }
        public long? IdTratamiento { get; set; }
        public decimal Cantidad { get; set; }
        public string Descripcion { get; set; }
        public decimal PrecioUni { get; set; }
        public decimal MontoDescu { get; set; }          // DescuentoTratamiento + DescuentoCupon
        public decimal DescuentoTratamiento { get; set; }
        public decimal DescuentoCupon { get; set; }
        public decimal VentaGravada { get; set; }
        public decimal IvaItem { get; set; }
    }
}
