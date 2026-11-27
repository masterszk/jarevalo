using System;
using System.Data;
using System.Data.SqlClient;
using System.Web;
using System.Web.SessionState;

namespace DPieCenter.Facturacion
{
    /// <summary>
    /// Descarga el PDF o el JSON de un DTE: DteArchivo.ashx?c={código de generación}&amp;t=pdf|json.
    /// Exige sesión; si el archivo no está en disco (por ejemplo, no se pudo guardar al emitirlo) se arma desde el JSON guardado.
    /// </summary>
    public class DteArchivo : IHttpHandler, IRequiresSessionState
    {
        public void ProcessRequest(HttpContext context)
        {
            if (!Sesion.Activa) { context.Response.StatusCode = 401; context.Response.Write("La sesión expiró. Vuelva a iniciar sesión."); return; }
            string codigo = (context.Request.QueryString["c"] ?? "").Trim().ToUpperInvariant();
            string tipo = (context.Request.QueryString["t"] ?? "pdf").Trim().ToLowerInvariant();
            if (!DteArchivos.CodigoValido(codigo) || (tipo != "pdf" && tipo != "json")) { context.Response.StatusCode = 400; return; }

            string tipoDte = null;
            using (var cn = new SqlConnection(DteRepository.Cn))
            using (var cmd = new SqlCommand("select TipoDte from FAC_DTE_DOCUMENTOS where CodigoGeneracion = @c", cn))
            {
                cmd.Parameters.Add("@c", SqlDbType.Char, 36).Value = codigo;
                cn.Open();
                tipoDte = cmd.ExecuteScalar() as string;
            }
            if (tipoDte == null) { context.Response.StatusCode = 404; context.Response.Write("El documento no existe."); return; }

            byte[] datos = DteArchivos.Leer(tipoDte, codigo, tipo) ?? DteService.ArchivoDesdeJson(codigo, tipo);
            if (datos == null) { context.Response.StatusCode = 404; context.Response.Write("No se encontró el archivo del documento."); return; }

            context.Response.ContentType = tipo == "pdf" ? "application/pdf" : "application/json";
            context.Response.AddHeader("Content-Disposition", (tipo == "pdf" ? "inline" : "attachment") + "; filename=DTE-" + codigo + "." + tipo);
            context.Response.Cache.SetCacheability(HttpCacheability.Private);
            context.Response.BinaryWrite(datos);
        }

        public bool IsReusable { get { return true; } }
    }
}
