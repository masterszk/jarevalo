using System;
using System.IO;
using System.Web;
using System.Web.SessionState;
using Newtonsoft.Json;

namespace DPieCenter.Facturacion
{
    // GET: devuelve el logo de la empresa (FAC_DTE_PARAMETROS.Logo)
    // POST (multipart, sesión activa): campo "logo" = archivo PNG/JPG; campo "quitar" = 1 elimina el logo; campo "user" = $('#idUser').val()
    public class LogoEmpresa : IHttpHandler, IRequiresSessionState
    {
        public bool IsReusable { get { return false; } }

        public void ProcessRequest(HttpContext context)
        {
            if (context.Request.HttpMethod == "POST") Subir(context);
            else Mostrar(context);
        }

        private static void Mostrar(HttpContext context)
        {
            string tipo;
            byte[] logo = DteRepository.ObtenerLogo(out tipo);
            if (logo == null)
            {
                context.Response.StatusCode = 404;
                return;
            }
            context.Response.ContentType = string.IsNullOrEmpty(tipo) ? "image/png" : tipo;
            context.Response.Cache.SetCacheability(HttpCacheability.NoCache);
            context.Response.BinaryWrite(logo);
        }

        private static void Subir(HttpContext context)
        {
            var resultado = new ResultadoDto();
            try
            {
                if (context.Session["dpsesion"] == null)
                {
                    context.Response.StatusCode = 401;
                    resultado.Mensaje = "La sesión expiró. Ingrese de nuevo.";
                }
                else if (!Sesion.TieneAcceso("Opciones/form_confEmpresa.aspx"))
                {
                    context.Response.StatusCode = 403;
                    resultado.Mensaje = "No tiene permiso para cambiar el logo de la empresa.";
                }
                else
                {
                    string user = Registros.AgendaService.UsuarioActual(context.Request.Form["user"]);
                    if (context.Request.Form["quitar"] == "1")
                    {
                        DteRepository.GuardarLogo(null, null, user);
                        resultado.Ok = true;
                        resultado.Mensaje = "Logo eliminado.";
                    }
                    else
                    {
                        var archivo = context.Request.Files["logo"];
                        string error = null;
                        byte[] png = null;
                        if (archivo != null && archivo.ContentLength > DteService.LogoMaxBytes)
                            error = "La imagen no debe superar 2 MB.";
                        else
                        {
                            byte[] datos = null;
                            if (archivo != null)
                                using (var ms = new MemoryStream())
                                {
                                    archivo.InputStream.CopyTo(ms);
                                    datos = ms.ToArray();
                                }
                            png = DteService.NormalizarLogo(datos, out error);
                        }
                        if (error != null) resultado.Mensaje = error;
                        else
                        {
                            DteRepository.GuardarLogo(png, "image/png", user);
                            resultado.Ok = true;
                            resultado.Mensaje = "Logo actualizado. Se usará en los próximos DTE.";
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Trace.TraceError("Logo empresa: " + ex);
                resultado.Ok = false;
                resultado.Mensaje = context.IsDebuggingEnabled ? "[DEBUG] " + ex.Message : "No fue posible guardar el logo.";
            }
            context.Response.ContentType = "application/json";
            context.Response.Write(JsonConvert.SerializeObject(resultado));
        }
    }
}
