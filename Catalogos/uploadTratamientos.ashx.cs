using System.Web;

namespace DPieCenter.Catalogos
{
    /// <summary>
    /// Ya no se usa: las imágenes de los tratamientos se suben desde cat_frmTratamientos.aspx (WebMethod Guardar),
    /// que exige sesión y reduce la imagen. Este manejador aceptaba archivos sin sesión, por eso ahora los rechaza.
    /// </summary>
    public class uploadTratamientos : IHttpHandler
    {
        public void ProcessRequest(HttpContext context)
        {
            context.Response.StatusCode = 410;
            context.Response.ContentType = "text/plain";
            context.Response.Write("Error||La carga de imágenes se hace desde Catálogos > Tratamientos.");
        }

        public bool IsReusable
        {
            get { return true; }
        }
    }
}
