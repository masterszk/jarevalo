using System;
using System.Data.SqlClient;
using System.Globalization;
using System.Linq;
using System.Web;
using System.Web.Services;

namespace DPieCenter.Registros
{
    /// <summary>Inbound: llamadas o contactos entrantes (assets/js/inbound.js). El usuario sale de la sesión, no del navegador.</summary>
    public partial class frm_Inbound : System.Web.UI.Page
    {
        private const string Url = "Registros/frm_Inbound.aspx";
        private const int MaxDias = 731;

        protected void Page_Load(object sender, EventArgs e)
        {

        }

        public class ResultadoDto
        {
            public bool Ok { get; set; }
            public string Mensaje { get; set; }
            public long Id { get; set; }
            /// <summary>El teléfono ya existe en un expediente: no se guardó (la pantalla avisa y limpia el formulario).</summary>
            public bool Existe { get; set; }
        }

        public class ArchivoDto
        {
            public bool Ok { get; set; }
            public string Mensaje { get; set; }
            public string Nombre { get; set; }
            public string Tipo { get; set; }
            public string Base64 { get; set; }
        }

        [WebMethod(EnableSession = true)]
        public static InboundListaDto Lista(FiltroInboundDto filtro)
        {
            DateTime? d = null, h = null;
            string error = Permiso() ?? ValidarFiltro(filtro, out d, out h);
            if (error != null) return new InboundListaDto { Ok = false, Mensaje = error };
            try
            {
                return new InboundListaDto
                {
                    Ok = true,
                    Resumen = InboundRepository.Resumen(),
                    Items = InboundRepository.Lista(d, h, filtro.Contesto, filtro.Texto)
                };
            }
            catch (Exception ex) { return new InboundListaDto { Ok = false, Mensaje = Detalle(ex, "No fue posible cargar la lista.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static ResultadoDto Guardar(long id, string telefono, string nombre, bool contesto)
        {
            string error = Permiso();
            if (error != null) return new ResultadoDto { Ok = false, Mensaje = error };
            telefono = new string((telefono ?? "").Where(char.IsDigit).ToArray());     // se aceptan guiones o espacios al escribirlo
            nombre = (nombre ?? "").Trim();
            if (nombre.Length > 150) return new ResultadoDto { Ok = false, Mensaje = "El nombre no puede tener más de 150 caracteres." };
            try
            {
                long nuevo = InboundRepository.Guardar(id, telefono, nombre, contesto, Sesion.Usuario);
                return new ResultadoDto { Ok = true, Id = nuevo, Mensaje = id > 0 ? "Registro actualizado." : "Registro agregado." };
            }
            catch (SqlException ex) when (ex.Number == 50116)
            {
                return new ResultadoDto { Ok = false, Existe = true, Mensaje = ex.Message };
            }
            catch (Exception ex) { return new ResultadoDto { Ok = false, Mensaje = Detalle(ex, "No fue posible guardar.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static ResultadoDto MarcarContesto(long id, bool contesto)
        {
            string error = Permiso();
            if (error != null) return new ResultadoDto { Ok = false, Mensaje = error };
            try
            {
                InboundRepository.MarcarContesto(id, contesto, Sesion.Usuario);
                return new ResultadoDto { Ok = true, Id = id };
            }
            catch (Exception ex) { return new ResultadoDto { Ok = false, Mensaje = Detalle(ex, "No fue posible actualizar.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static ResultadoDto Eliminar(long id)
        {
            string error = Permiso();
            if (error != null) return new ResultadoDto { Ok = false, Mensaje = error };
            try
            {
                InboundRepository.Eliminar(id, Sesion.Usuario);
                return new ResultadoDto { Ok = true, Id = id, Mensaje = "Registro eliminado." };
            }
            catch (Exception ex) { return new ResultadoDto { Ok = false, Mensaje = Detalle(ex, "No fue posible eliminar.") }; }
        }

        /// <summary>Libro de Excel (.xlsx) con la lista filtrada, en base64.</summary>
        [WebMethod(EnableSession = true)]
        public static ArchivoDto Exportar(FiltroInboundDto filtro)
        {
            DateTime? d = null, h = null;
            string error = Permiso() ?? ValidarFiltro(filtro, out d, out h);
            if (error != null) return new ArchivoDto { Ok = false, Mensaje = error };
            try
            {
                var items = InboundRepository.Lista(d, h, filtro.Contesto, filtro.Texto);
                if (items.Count == 0) return new ArchivoDto { Ok = false, Mensaje = "No hay registros para exportar con esos filtros." };

                Func<string, object> fecha = s => string.IsNullOrEmpty(s) ? null : (object)DateTime.ParseExact(s, "yyyy-MM-ddTHH:mm:ss", CultureInfo.InvariantCulture);
                string rango = d.HasValue || h.HasValue
                    ? (d.HasValue ? d.Value.ToString("dd/MM/yyyy") : "inicio") + " al " + (h.HasValue ? h.Value.ToString("dd/MM/yyyy") : "hoy")
                    : "todas las fechas";
                string estado = filtro.Contesto == 1 ? " · contestados" : filtro.Contesto == 0 ? " · pendientes" : "";

                byte[] libro = ExcelXlsx.Crear("Inbound", "Inbound · " + rango + estado + " · " + items.Count + " registros",
                    new[] { "Teléfono", "Nombre cliente", "Contestó", "Paciente registrado", "Usuario crea", "Fecha crea", "Usuario modifica", "Fecha modificación" },
                    items.Select(x => new object[] { x.Telefono, x.NombreCliente, x.Contesto, x.Paciente, x.UsuarioCrea, fecha(x.FechaCrea), x.UsuarioModifica, fecha(x.FechaModificacion) }),
                    new double[] { 14, 34, 11, 32, 15, 18, 17, 19 });

                return new ArchivoDto
                {
                    Ok = true,
                    Nombre = "Inbound_" + DateTime.Now.ToString("yyyyMMdd_HHmm") + ".xlsx",
                    Tipo = ExcelXlsx.TipoMime,
                    Base64 = Convert.ToBase64String(libro)
                };
            }
            catch (Exception ex) { return new ArchivoDto { Ok = false, Mensaje = Detalle(ex, "No fue posible generar el archivo de Excel.") }; }
        }

        private static string Permiso()
        {
            if (!Sesion.Activa) return "La sesión expiró. Vuelva a iniciar sesión.";
            if (!Sesion.TieneAcceso(Url)) return "No tiene permiso para usar Inbound.";
            return null;
        }

        private static string ValidarFiltro(FiltroInboundDto f, out DateTime? desde, out DateTime? hasta)
        {
            desde = hasta = null;
            if (f == null) return "No se recibieron los filtros.";
            DateTime x;
            if (!string.IsNullOrEmpty(f.Desde))
            {
                if (!DateTime.TryParseExact(f.Desde, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out x)) return "La fecha inicial no es válida.";
                desde = x;
            }
            if (!string.IsNullOrEmpty(f.Hasta))
            {
                if (!DateTime.TryParseExact(f.Hasta, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out x)) return "La fecha final no es válida.";
                hasta = x;
            }
            if (desde.HasValue && hasta.HasValue && hasta < desde) return "La fecha final no puede ser anterior a la inicial.";
            if (desde.HasValue && hasta.HasValue && (hasta.Value - desde.Value).TotalDays > MaxDias) return "El rango no puede superar dos años.";
            if (f.Contesto < -1 || f.Contesto > 1) f.Contesto = -1;
            if (f.Texto != null && f.Texto.Length > 100) f.Texto = f.Texto.Substring(0, 100);
            return null;
        }

        private static string Detalle(Exception ex, string generico)
        {
            var sql = ex as SqlException;
            if (sql != null && sql.Number >= 50000) return sql.Message;
            System.Diagnostics.Trace.TraceError("Inbound: " + ex);
            bool debug = HttpContext.Current != null && HttpContext.Current.IsDebuggingEnabled;
            return debug ? "[DEBUG] " + ex.Message : generico;
        }
    }
}
