using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;
using System.Web;
using System.Web.Services;

namespace DPieCenter.Facturacion
{
    /// <summary>
    /// Diagnóstico de la emisión de DTE en el servidor donde corre el sitio (assets/js/diagnostico-dte.js), solo administradores:
    /// scripts SQL instalados, datos del emisor, carpeta de archivos (permiso de escritura), correo (clave legible y prueba de envío),
    /// DTE sin archivos o sin correo (regenerar y reenviar) y los últimos errores registrados.
    /// </summary>
    public partial class frm_DiagnosticoDte : System.Web.UI.Page
    {
        // Objeto de la base de datos → script que lo crea (para saber qué falta ejecutar en producción)
        private static readonly string[,] Objetos =
        {
            { "FAC_DTE_DOCUMENTOS", "Facturacion/sql/FAC_DTE_Estructura.sql" },
            { "FAC_SP_DTE_GUARDAR", "Facturacion/sql/FAC_DTE_Estructura.sql" },
            { "FAC_SP_DTE_EMPRESA", "Facturacion/sql/FAC_DTE_Estructura.sql" },
            { "FAC_SP_DTE_DIAGNOSTICO", "Facturacion/sql/FAC_DTE_Diagnostico.sql" },
            { "CAJ_SP_Caja", "Facturacion/sql/CAJ_Caja_Anulaciones.sql" },
            { "CAJ_SALIDAS", "Facturacion/sql/CAJ_Caja_Anulaciones.sql" },
            { "FAC_SP_DTE_ANULACIONES", "Facturacion/sql/CAJ_Caja_Anulaciones.sql" },
            { "CUP_SP_Cupones", "Registros/sql/CUP_Cupones.sql" },
            { "EXP_SP_Procedimientos_Atencion", "Registros/sql/EXP_Procedimientos_Atencion.sql" },
            { "EXP_SP_Expedientes_Lista", "Registros/sql/EXP_Expedientes_Lista.sql" },
            { "EXP_SP_Expediente_Detalle", "Registros/sql/EXP_Expediente_Detalle.sql" },
            { "REG_SP_Inbound", "Registros/sql/REG_Inbound.sql" },
            { "SUC_SP_Sucursales", "Opciones/sql/SUC_Sucursales.sql" },
            { "REP_SP_Dashboard", "Reportes/sql/REP_Dashboard_Caja.sql" },
            { "REP_SP_Reportes", "Reportes/sql/REP_Reportes.sql" },
            { "REP_SP_DashboardUsuario", "Dashboard/sql/REP_Dashboard_Usuarios.sql" },
            { "SYS_SP_Administracion", "Opciones/sql/SYS_Administracion.sql" },
            { "CAT_SP_Catalogos", "Catalogos/sql/CAT_Catalogos.sql" }
        };

        protected void Page_Load(object sender, EventArgs e)
        {

        }

        public class RevisionDto
        {
            public string Grupo { get; set; }
            public string Nombre { get; set; }
            /// <summary>ok, aviso o error</summary>
            public string Estado { get; set; }
            public string Detalle { get; set; }
            public string Solucion { get; set; }
        }

        public class DiagnosticoDto
        {
            public bool Ok { get; set; }
            public string Mensaje { get; set; }
            public string Servidor { get; set; }
            public string Identidad { get; set; }
            public string Carpeta { get; set; }
            public string Fecha { get; set; }
            public string CorreoAdministrador { get; set; }
            public List<RevisionDto> Revisiones { get; set; }
            public List<Dictionary<string, object>> Pendientes { get; set; }
            public List<Dictionary<string, object>> Eventos { get; set; }
        }

        [WebMethod(EnableSession = true)]
        public static DiagnosticoDto Revisar()
        {
            string permiso = Permiso();
            if (permiso != null) return new DiagnosticoDto { Ok = false, Mensaje = permiso };
            var d = new DiagnosticoDto
            {
                Ok = true, Servidor = Environment.MachineName, Identidad = DteArchivos.Identidad(),
                Fecha = DateTime.Now.ToString("dd/MM/yyyy ", CultureInfo.InvariantCulture) + Formato.HoraSegundos(DateTime.Now), Revisiones = new List<RevisionDto>()
            };
            var r = d.Revisiones;

            // 1. Base de datos: objetos de los scripts
            var faltan = new List<string>();
            var scripts = new SortedSet<string>();
            try
            {
                using (var cn = new SqlConnection(DteRepository.Cn))
                {
                    cn.Open();
                    r.Add(new RevisionDto { Grupo = "Base de datos", Nombre = "Conexión", Estado = "ok", Detalle = cn.DataSource + " / " + cn.Database });
                    for (int i = 0; i < Objetos.GetLength(0); i++)
                        using (var cmd = new SqlCommand("select OBJECT_ID(@o)", cn))
                        {
                            cmd.Parameters.Add("@o", SqlDbType.NVarChar, 128).Value = "dbo." + Objetos[i, 0];
                            if (cmd.ExecuteScalar() == DBNull.Value) { faltan.Add(Objetos[i, 0]); scripts.Add(Objetos[i, 1]); }
                        }
                    using (var cmd = new SqlCommand("select COL_LENGTH('dbo.CAJ_FACTURAS', 'Id_Cupon_FK')", cn))
                        if (cmd.ExecuteScalar() == DBNull.Value) { faltan.Add("CAJ_FACTURAS.Id_Cupon_FK"); scripts.Add("Registros/sql/CUP_Cupones.sql"); }
                }
                r.Add(faltan.Count == 0
                    ? new RevisionDto { Grupo = "Base de datos", Nombre = "Scripts instalados", Estado = "ok", Detalle = "Están todos los procedimientos y tablas de los scripts." }
                    : new RevisionDto
                    {
                        Grupo = "Base de datos", Nombre = "Scripts instalados", Estado = "error",
                        Detalle = "Faltan: " + string.Join(", ", faltan), Solucion = "Ejecute en esta base de datos: " + string.Join(", ", scripts)
                    });
            }
            catch (Exception ex)
            {
                r.Add(new RevisionDto { Grupo = "Base de datos", Nombre = "Conexión", Estado = "error", Detalle = ex.Message, Solucion = "Revise la cadena de conexión conexionDiarypro del Web.config." });
                return d;
            }

            // 2. Emisor
            EmisorDte emisor = null;
            try { emisor = DteRepository.ObtenerEmisor(); } catch (Exception ex) { r.Add(new RevisionDto { Grupo = "Emisor", Nombre = "Datos de la empresa", Estado = "error", Detalle = ex.Message }); }
            if (emisor != null)
            {
                bool completo = !string.IsNullOrWhiteSpace(emisor.Nit) && !string.IsNullOrWhiteSpace(emisor.Nrc) && !string.IsNullOrWhiteSpace(emisor.CodActividad)
                                && !string.IsNullOrWhiteSpace(emisor.CodDepartamento) && !string.IsNullOrWhiteSpace(emisor.CodMunicipio);
                r.Add(new RevisionDto
                {
                    Grupo = "Emisor", Nombre = "Datos de la empresa", Estado = completo ? "ok" : "error",
                    Detalle = emisor.Nombre + " · NIT " + emisor.Nit + " · NRC " + emisor.Nrc, Solucion = completo ? null : "Complete los datos en Opciones > Datos de la empresa > Facturación electrónica."
                });
                r.Add(new RevisionDto
                {
                    Grupo = "Emisor", Nombre = "Ambiente", Estado = emisor.Ambiente == "01" ? "ok" : "aviso",
                    Detalle = emisor.Ambiente == "01" ? "01 · Producción" : emisor.Ambiente + " · Pruebas",
                    Solucion = emisor.Ambiente == "01" ? null : "Los DTE se están emitiendo en ambiente de pruebas (00)."
                });
                r.Add(new RevisionDto
                {
                    Grupo = "Emisor", Nombre = "Transmisión a Hacienda", Estado = "aviso",
                    Detalle = "El sistema genera el JSON y el PDF pero no firma ni transmite los DTE al Ministerio de Hacienda (no obtiene el sello de recepción).",
                    Solucion = "Para que los DTE sean válidos fiscalmente hay que firmarlos con el certificado y transmitirlos a la API de Hacienda."
                });
            }
            else r.Add(new RevisionDto { Grupo = "Emisor", Nombre = "Datos de la empresa", Estado = "error", Detalle = "No hay datos del emisor (FAC_DTE_PARAMETROS).", Solucion = "Configúrelos en Opciones > Datos de la empresa > Facturación electrónica." });

            // 3. Archivos
            d.Carpeta = DteArchivos.Carpeta();
            string escritura = DteArchivos.PruebaEscritura();
            r.Add(new RevisionDto
            {
                Grupo = "Archivos", Nombre = "Carpeta de los PDF y JSON", Estado = escritura == null ? "ok" : "error",
                Detalle = d.Carpeta + (DteArchivos.CarpetaPersonalizada ? " (configurada en DteCarpetaArchivos)" : " (por defecto)") + (escritura == null ? " · se puede escribir" : " · " + escritura),
                Solucion = escritura == null ? null
                    : "En el servidor, dé permiso de Modificar sobre esa carpeta a la cuenta \"" + d.Identidad + "\" (IIS > grupo de aplicaciones), o indique en Web.config (DteCarpetaArchivos) una carpeta con permiso. Mientras tanto los correos salen igual y los PDF se rearman al descargarlos."
            });

            // 4. Correo
            if (emisor != null)
            {
                string formato = DteCorreo.FormatoClave(emisor.SmtpClave), motivo = DteCorreo.Configuracion(emisor);
                d.CorreoAdministrador = emisor.Correo;
                r.Add(new RevisionDto
                {
                    Grupo = "Correo", Nombre = "Envío automático", Estado = emisor.EnviarCorreo ? "ok" : "aviso",
                    Detalle = emisor.EnviarCorreo ? "Activado" : "Desactivado: los DTE no se envían al emitirlos.", Solucion = emisor.EnviarCorreo ? null : "Actívelo en Opciones > Datos de la empresa > Facturación electrónica."
                });
                r.Add(new RevisionDto
                {
                    Grupo = "Correo", Nombre = "Servidor SMTP", Estado = motivo == null ? "ok" : "error",
                    Detalle = (emisor.SmtpServidor ?? "—") + ":" + emisor.SmtpPuerto + " · usuario " + (emisor.SmtpUsuario ?? "—") + " · clave " + formato
                              + (motivo == null ? " (legible)" : ""),
                    Solucion = motivo
                });
                r.Add(new RevisionDto
                {
                    Grupo = "Correo", Nombre = "Llave de cifrado (Web.config)", Estado = DteCorreo.TieneLlavePortable ? "ok" : "aviso",
                    Detalle = DteCorreo.TieneLlavePortable ? "DteClaveCifrado configurada: la clave guardada sirve en cualquier servidor con este Web.config."
                                                           : "Sin DteClaveCifrado: la clave solo se puede leer en el equipo donde se guardó.",
                    Solucion = DteCorreo.TieneLlavePortable
                        ? (formato == "dpapi" ? "La clave actual se guardó con el método anterior: ingrésela de nuevo en Opciones > Datos de la empresa > Facturación electrónica para guardarla con la llave." : null)
                        : "Copie al Web.config del servidor la misma llave DteClaveCifrado del proyecto."
                });
            }

            // 5. DTE pendientes y eventos
            try
            {
                d.Pendientes = Filas(DteRepository.Diagnostico(3));
                d.Eventos = Filas(DteRepository.Diagnostico(2));
            }
            catch (Exception ex) { d.Pendientes = new List<Dictionary<string, object>>(); d.Eventos = new List<Dictionary<string, object>>(); d.Mensaje = ex.Message; }
            return d;
        }

        /// <summary>Envía un correo de prueba (sin adjuntos) con la configuración SMTP guardada.</summary>
        [WebMethod(EnableSession = true)]
        public static RevisionDto ProbarCorreo(string correo)
        {
            string permiso = Permiso();
            if (permiso != null) return new RevisionDto { Estado = "error", Detalle = permiso };
            correo = (correo ?? "").Trim();
            if (!System.Text.RegularExpressions.Regex.IsMatch(correo, @"^[^@\s]+@[^@\s]+\.[^@\s]+$")) return new RevisionDto { Estado = "error", Detalle = "Ingrese un correo válido." };
            var emisor = DteRepository.ObtenerEmisor();
            if (emisor == null) return new RevisionDto { Estado = "error", Detalle = "No hay datos del emisor configurados." };
            try
            {
                DteCorreo.Enviar(emisor, correo, "Prueba de correo - D' Pie Center",
                    "<p>Este es un correo de prueba enviado desde el servidor <strong>" + HttpUtility.HtmlEncode(Environment.MachineName)
                    + "</strong> el " + Formato.FechaHora(DateTime.Now) + ".</p><p>Si lo recibe, el envío de los DTE por correo está funcionando.</p>");
                DteRepository.RegistrarEvento(0, "Prueba", true, "Correo de prueba enviado a " + correo, Sesion.Usuario);
                return new RevisionDto { Estado = "ok", Detalle = "Correo de prueba enviado a " + correo + ". Revise también la carpeta de spam." };
            }
            catch (Exception ex)
            {
                DteRepository.RegistrarEvento(0, "Prueba", false, "Servidor " + emisor.SmtpServidor + ":" + emisor.SmtpPuerto + " - " + ex.Message, Sesion.Usuario);
                return new RevisionDto { Estado = "error", Detalle = ex.Message, Solucion = "Revise servidor, puerto, usuario y clave; y que el hosting permita conexiones salientes a ese puerto." };
            }
        }

        /// <summary>Regenera los archivos de un DTE y, si se indica un correo, lo reenvía.</summary>
        [WebMethod(EnableSession = true)]
        public static PagoResultadoDto Regenerar(long id, string correo)
        {
            string permiso = Permiso();
            if (permiso != null) return new PagoResultadoDto { Ok = false, Mensaje = permiso };
            try { return DteService.RegenerarYEnviar(id, correo, Sesion.Usuario); }
            catch (Exception ex)
            {
                DteRepository.RegistrarEvento(id, "Archivos", false, "Regenerar: " + ex, Sesion.Usuario);
                return new PagoResultadoDto { Ok = false, Mensaje = "No fue posible regenerar: " + ex.Message };
            }
        }

        private static List<Dictionary<string, object>> Filas(DataTable t)
        {
            var lista = new List<Dictionary<string, object>>();
            foreach (DataRow f in t.Rows)
            {
                var d = new Dictionary<string, object>();
                foreach (DataColumn c in t.Columns)
                {
                    object v = f[c];
                    d[c.ColumnName] = v == DBNull.Value ? null
                        : v is DateTime ? ((DateTime)v).ToString("yyyy-MM-ddTHH:mm:ss", CultureInfo.InvariantCulture)
                        : v is TimeSpan ? Formato.Hora((TimeSpan)v)
                        : v;
                }
                lista.Add(d);
            }
            return lista;
        }

        private static string Permiso()
        {
            if (!Sesion.Activa) return "La sesión expiró. Vuelva a iniciar sesión.";
            if (!Sesion.EsAdministrador) return "Solo los administradores pueden ver el diagnóstico.";
            return null;
        }
    }
}
