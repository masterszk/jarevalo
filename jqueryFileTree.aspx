<%@ Page Language="C#" AutoEventWireup="true" %>

<%
    //
    // jQuery File Tree ASP Connector
    //
    // Version 1.0
    //
    // Copyright (c)2008 Andrew Sweeny
    // asweeny@fit.edu
    // 24 March 2008
    //

    string dir;

    /* Se define un arreglo que permite agregar funcionalidad, restringiendo unicamente 
     * las extensiones que se desean mostrar en el arbol de directorios*/
    //    string[] extensionesPermitidas = new string[] { ".aspx", ".css", ".js" };
    string[] extensionesPermitidas = new string[] { ".aspx" };
    /*Se agrega variable para controlar si se muestran unicamente los directorrios*/
    Boolean onlyFolder = Convert.ToBoolean(Request.Form["onlyFolder"]);

    // Seguridad: solo administradores y solo dentro de la carpeta del sitio (antes listaba cualquier carpeta del servidor, p. ej. C:\)
    if (!DPieCenter.Sesion.Activa || !DPieCenter.Sesion.EsAdministrador) {
        Response.StatusCode = 403;
        Response.End();
        return;
    }
    string raiz = System.IO.Path.GetFullPath(HttpContext.Current.Server.MapPath("~/"));
    if (!raiz.EndsWith("\\")) raiz += "\\";

    try {
        if(Request.Form["dir"] == null || Request.Form["dir"].Length <= 0)
            dir = raiz;
        else
            dir = Server.UrlDecode(Request.Form["dir"]);

        string completo = System.IO.Path.GetFullPath(dir);
        if (!completo.EndsWith("\\")) completo += "\\";
        if (!completo.StartsWith(raiz, StringComparison.OrdinalIgnoreCase)) {
            Response.StatusCode = 403;
            Response.End();
            return;
        }

        System.IO.DirectoryInfo di = new System.IO.DirectoryInfo(dir);
        Response.Write("<ul class=\"jqueryFileTree\" style=\"display: none;\">\n");
        foreach (System.IO.DirectoryInfo di_child in di.GetDirectories())
            Response.Write("\t<li class=\"directory collapsed\"><a href=\"#\" rel=\"" + dir + di_child.Name + "/\">" + di_child.Name + "</a></li>\n");
        foreach (System.IO.FileInfo fi in di.GetFiles())
        {
            string ext = "";
            if (fi.Extension.Length > 1) {
                string encontrado = Array.Find(extensionesPermitidas, p => p.Equals(fi.Extension));
                if (encontrado != null)
                {
                    ext = fi.Extension.Substring(1).ToLower();
                    if (!onlyFolder)
                    {
                        Response.Write("\t<li class=\"file ext_" + ext + "\"><a href=\"#\" rel=\"" + dir + fi.Name + "\">" + fi.Name + "</a></li>\n");
                    }
                    else {
                        //Do Nothing
                    }
                }
            }
        }
        Response.Write("</ul>");
    } catch (Exception ex) {
        Response.Write(ex.Message);
    }
 %>