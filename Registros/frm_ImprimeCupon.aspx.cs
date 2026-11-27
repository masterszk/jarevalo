using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace DPieCenter.Registros
{
    public partial class frm_ImprimeCupon : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            mtd_ImprimeCupon(Request.QueryString["id"]);
        }

        private void mtd_ImprimeCupon(string id) {

            string respuestaSql = "", mensajeRespuesta = "";

            //printCupon report = new printCupon();
            //PdfExportOptions pdfOptions = report.ExportOptions.Pdf;
            try
            {
                //    // Specify the pages to export.
                //    pdfOptions.PageRange = "1";

                //    // Specify the quality of exported images.
                //    pdfOptions.ConvertImagesToJpeg = false;
                //    pdfOptions.ImageQuality = PdfJpegImageQuality.Medium;

                //    // Specify the PDF/A-compatibility.
                //    pdfOptions.PdfACompatibility = PdfACompatibility.PdfA3b;

                //    // Specify the document options.
                //    pdfOptions.DocumentOptions.Application = "DPie Center Application";
                //    pdfOptions.DocumentOptions.Author = "DPie Center";
                //    pdfOptions.DocumentOptions.Keywords = "DPie Center, Reporting, PDF";
                //    pdfOptions.DocumentOptions.Producer = Environment.UserName.ToString();
                //    pdfOptions.DocumentOptions.Subject = "Document Subject";
                //    pdfOptions.DocumentOptions.Title = "Document Title";

                //    // Check the validity of PDF export options 
                //    // and return a list of any detected inconsistencies.
                //    IList<string> result = pdfOptions.Validate();
                //    if (result.Count > 0)
                //        Console.WriteLine(String.Join(Environment.NewLine, result));
                //    else
                //    {
                //        report.CreateDocument();
                //        report.ExportToPdf("cupon_" + id + ".pdf", pdfOptions);

                //}
            }
            catch (Exception ex)
            {
                mensajeRespuesta = "ERROR||Se ha producido un error, si el problema persiste, por favor comunicarse \ncon el administrador del sistema: " + ex.Message;
            }
        }
    }
}