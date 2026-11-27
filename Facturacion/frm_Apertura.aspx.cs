using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using System.Web.Services;
using System.Data;
using System.Collections;
using System.Data.SqlClient;

namespace DPieCenter.Facturacion
{
    public partial class frm_Apertura : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {

        }

        [WebMethod]
        public static string mtd_LeeAperturas(string user, int accion)
        {
            string respuestaSql = "", mensajeRespuesta = "";
            
            try
            {
                using (SqlProcess sqlProccess = new SqlProcess())
                {
                    respuestaSql = sqlProccess.mtdCAJ_Aperturas(0,"","","","","",0,user, accion);
                    if (respuestaSql == "OK")
                    {
                        mensajeRespuesta = "OK||";

                        foreach (DataRow Reg in sqlProccess.dtReturn.Rows)
                        {
                            mensajeRespuesta += Reg[0].ToString() + "||";
                            mensajeRespuesta += Reg[1].ToString() + "||";
                            mensajeRespuesta += Reg[2].ToString() + "||";
                            mensajeRespuesta += Reg[3].ToString() + "||";
                            mensajeRespuesta += Reg[4].ToString() + "||";
                            mensajeRespuesta += Reg[5].ToString() + "||";
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                mensajeRespuesta = "ERROR||Se ha producido un error, si el problema persiste, por favor comunicarse \ncon el administrador del sistema: " + ex.Message;
            }
            return mensajeRespuesta;
        }

        [WebMethod]
        public static string mtd_LeeDatostto(string cita, int accion)
        {
            string respuestaSql = "", mensajeRespuesta = "";
            double total = 0;
            string btnAnular = "";

            try
            {
                using (SqlProcess sqlProccess = new SqlProcess())
                {
                    respuestaSql = sqlProccess.mtdREP_ReporteProcedimientos(cita, "", "", "", "", -1, -1, accion);
                    if (respuestaSql == "OK")
                    {
                        mensajeRespuesta = "OK||";

                        foreach (DataRow Reg in sqlProccess.dtReturn.Rows)
                        {
                            if (Reg[2].ToString() == "1")
                                btnAnular = "<a href=\"javascript:void(0)\" class=\"mb-0 text-danger\" title=\"Anula el Registro\" onclick=\"showConfirmAnulacion('" + Reg[3].ToString() + "',2,'" + cita + "')\"><i class=\"bx bxs-message-square-x\"></i></a>";
                            else
                                btnAnular = "<a href=\"javascript:void(0)\" class=\"mb-0 text-success\" title=\"Activa el Registro\" onclick=\"showConfirmAnulacion('" + Reg[3].ToString() + "',1,'" + cita + "')\"><i class=\"bx bxs-check-circle\"></i></a>";

                            mensajeRespuesta += "<tr>" +
                                                    "<td>" + Reg[0].ToString() + "</td>" +
                                                    "<td class=\"text-center\">" + string.Format("{0:#,#0.00}", Convert.ToDouble(Reg[1].ToString())) + "</td>" +
                                                    "<td class=\"text-center\">" + btnAnular + "</td>" +
                                                "</tr>";

                            total += Convert.ToDouble(Reg[1].ToString());
                        }
                        mensajeRespuesta += "</tbody>";
                        mensajeRespuesta += "<tfooter>";
                        mensajeRespuesta += "   <tr>";
                        mensajeRespuesta += "   <th class=\"text-center\">Total</th>";
                        mensajeRespuesta += "   <th class=\"text-center\">" + string.Format("{0:#,#0.00}", total) + "</th>";
                        mensajeRespuesta += "   <th class=\"text-center\"></th>";
                        mensajeRespuesta += "   </tr>";
                        mensajeRespuesta += "</tfooter>";
                    }
                }
            }
            catch (Exception ex)
            {
                mensajeRespuesta = "ERROR||Se ha producido un error, si el problema persiste, por favor comunicarse \ncon el administrador del sistema: " + ex.Message;
            }
            return mensajeRespuesta;
        }
    }
}