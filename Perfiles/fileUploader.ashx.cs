using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace DPieCenter.Perfiles
{
    /// <summary>
    /// Descripción breve de fileUploader
    /// </summary>
    public class fileUploader : IHttpHandler
    {

        public void ProcessRequest(HttpContext context)
        {
            context.Response.ContentType = "text/plain";
            context.Response.Write("Hola a todos");
        }

        public bool IsReusable
        {
            get
            {
                return false;
            }
        }
    }
}