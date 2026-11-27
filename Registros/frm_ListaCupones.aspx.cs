using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Globalization;
using System.Web;
using System.Web.Services;

namespace DPieCenter.Registros
{
    /// <summary>
    /// Cupones de descuento con código QR (assets/js/cupones.js). Se imprimen en papel de 80 mm y se aplican en caja
    /// al escanear el QR (Facturacion/frm_OpenFactura.aspx). El porcentaje por defecto y la vigencia se configuran aquí.
    /// </summary>
    public partial class frm_ListaCupones : System.Web.UI.Page
    {
        private const string Url = "Registros/frm_ListaCupones.aspx";

        protected void Page_Load(object sender, EventArgs e)
        {

        }

        public class InicioCuponesDto
        {
            public bool Ok { get; set; }
            public string Mensaje { get; set; }
            public bool EsAdministrador { get; set; }
            public CuponConfigDto Config { get; set; }
            public List<OpcionDto> Tratamientos { get; set; }
            public int Pendientes { get; set; }
            public int Usados { get; set; }
            public int Vencidos { get; set; }
            public decimal DescuentoMes { get; set; }
        }

        public class ListaCuponesDto
        {
            public bool Ok { get; set; }
            public string Mensaje { get; set; }
            public List<CuponDto> Items { get; set; }
        }

        public class RespuestaCuponDto
        {
            public bool Ok { get; set; }
            public string Mensaje { get; set; }
            public long Id { get; set; }
        }

        [WebMethod(EnableSession = true)]
        public static InicioCuponesDto Inicio()
        {
            string permiso = Permiso();
            if (permiso != null) return new InicioCuponesDto { Ok = false, Mensaje = permiso };
            try
            {
                decimal mes;
                var r = CuponesRepository.Resumen(out mes);
                return new InicioCuponesDto
                {
                    Ok = true, EsAdministrador = Sesion.EsAdministrador, Config = CuponesRepository.Configuracion(), Tratamientos = CuponesRepository.Tratamientos(),
                    Pendientes = r[0], Usados = r[1], Vencidos = r[2], DescuentoMes = mes
                };
            }
            catch (Exception ex) { return new InicioCuponesDto { Ok = false, Mensaje = Detalle(ex, "No fue posible cargar los cupones.") }; }
        }

        /// <summary>estado: P pendientes, U usados, A anulados, V vencidos, vacío todos. desde / hasta yyyy-MM-dd.</summary>
        [WebMethod(EnableSession = true)]
        public static ListaCuponesDto Lista(string estado, string texto, string desde, string hasta)
        {
            string permiso = Permiso();
            if (permiso != null) return new ListaCuponesDto { Ok = false, Mensaje = permiso };
            try
            {
                if (texto != null && texto.Length > 100) texto = texto.Substring(0, 100);
                return new ListaCuponesDto { Ok = true, Items = CuponesRepository.Lista(estado, texto, FechaN(desde), FechaN(hasta)) };
            }
            catch (Exception ex) { return new ListaCuponesDto { Ok = false, Mensaje = Detalle(ex, "No fue posible cargar los cupones.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static List<OpcionDto> BuscarPacientes(string texto)
        {
            if (Permiso() != null) return new List<OpcionDto>();
            try { return CuponesRepository.BuscarPacientes(texto); }
            catch (Exception ex) { System.Diagnostics.Trace.TraceError("Cupones.BuscarPacientes: " + ex); return new List<OpcionDto>(); }
        }

        [WebMethod(EnableSession = true)]
        public static RespuestaCuponDto Crear(CuponNuevoDto cupon)
        {
            string permiso = Permiso();
            if (permiso != null) return new RespuestaCuponDto { Ok = false, Mensaje = permiso };
            if (cupon == null) return new RespuestaCuponDto { Ok = false, Mensaje = "No se recibieron los datos." };
            if (cupon.Asignado != null && cupon.Asignado.Length > 150) cupon.Asignado = cupon.Asignado.Substring(0, 150);
            if (cupon.Nota != null && cupon.Nota.Length > 250) cupon.Nota = cupon.Nota.Substring(0, 250);
            try
            {
                long id = CuponesRepository.Crear(cupon, Sesion.Usuario);
                return new RespuestaCuponDto { Ok = true, Id = id, Mensaje = "Cupón creado." };
            }
            catch (Exception ex) { return new RespuestaCuponDto { Ok = false, Mensaje = Detalle(ex, "No fue posible crear el cupón.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static RespuestaCuponDto Anular(long id, string motivo)
        {
            string permiso = Permiso();
            if (permiso != null) return new RespuestaCuponDto { Ok = false, Mensaje = permiso };
            try
            {
                CuponesRepository.Anular(id, motivo, Sesion.Usuario);
                return new RespuestaCuponDto { Ok = true, Id = id, Mensaje = "Cupón anulado." };
            }
            catch (Exception ex) { return new RespuestaCuponDto { Ok = false, Mensaje = Detalle(ex, "No fue posible anular el cupón.") }; }
        }

        /// <summary>Datos y QR del cupón para imprimirlo en papel de 80 mm.</summary>
        [WebMethod(EnableSession = true)]
        public static CuponImpresionDto Imprimir(long id)
        {
            string permiso = Permiso();
            if (permiso != null) return new CuponImpresionDto { Ok = false, Mensaje = permiso };
            try { return CuponesRepository.Impresion(id); }
            catch (Exception ex) { return new CuponImpresionDto { Ok = false, Mensaje = Detalle(ex, "No fue posible preparar el cupón.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static RespuestaCuponDto GuardarConfiguracion(CuponConfigDto config)
        {
            string permiso = Permiso();
            if (permiso != null) return new RespuestaCuponDto { Ok = false, Mensaje = permiso };
            if (!Sesion.EsAdministrador) return new RespuestaCuponDto { Ok = false, Mensaje = "Solo un administrador puede cambiar la configuración de los cupones." };
            if (config == null) return new RespuestaCuponDto { Ok = false, Mensaje = "No se recibieron los datos." };
            if (config.Leyenda != null && config.Leyenda.Length > 250) config.Leyenda = config.Leyenda.Substring(0, 250);
            try
            {
                CuponesRepository.GuardarConfiguracion(config, Sesion.Usuario);
                return new RespuestaCuponDto { Ok = true, Mensaje = "Configuración guardada. Se aplica a los cupones nuevos." };
            }
            catch (Exception ex) { return new RespuestaCuponDto { Ok = false, Mensaje = Detalle(ex, "No fue posible guardar la configuración.") }; }
        }

        private static DateTime? FechaN(string s)
        {
            DateTime d;
            return DateTime.TryParseExact(s ?? "", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out d) ? d : (DateTime?)null;
        }

        private static string Permiso()
        {
            if (!Sesion.Activa) return "La sesión expiró. Vuelva a iniciar sesión.";
            if (!Sesion.EsAdministrador && !Sesion.TieneAcceso(Url)) return "No tiene permiso para administrar cupones.";
            return null;
        }

        private static string Detalle(Exception ex, string generico)
        {
            var sql = ex as SqlException;
            if (sql != null && sql.Number >= 50000) return sql.Message;
            if (ex is ArgumentException) return ex.Message;
            System.Diagnostics.Trace.TraceError("Cupones: " + ex);
            bool debug = HttpContext.Current != null && HttpContext.Current.IsDebuggingEnabled;
            return debug ? "[DEBUG] " + ex.Message : generico;
        }
    }
}
