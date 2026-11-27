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

namespace DPieCenter.Registros
{
    public partial class frm_ListaProcedimientos : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {

        }

        [WebMethod]
        public static string mtd_LeeCitasVigentesHoy(string user, int accion)
        {
            string respuestaSql = "", mensajeRespuesta = "";
            string valores = "", procedmientos="", finaliza="", cancelar="";
            int c = 0;

            try {
                using (SqlProcess sqlProccess = new SqlProcess())
                {
                    respuestaSql = sqlProccess.mtdEXP_CitasVigentes(user, accion);
                    if (respuestaSql == "OK")
                    {
                        mensajeRespuesta = "OK||";
                        foreach (DataRow Reg in sqlProccess.dtReturn.Rows)
                        {
                            valores = string.Format("'{0}','{1}','{2}'", Reg[0].ToString(), Reg[9].ToString(), 1);
                            procedmientos = string.Format("'{0}','{1}','{2}'", Reg[0].ToString(), user, 6);
                            finaliza = string.Format("'{0}'", Reg[0].ToString());
                            cancelar = string.Format("'{0}','{1}'", Reg[0].ToString(), user);


                            if (c == 0)
                            {
                                mensajeRespuesta += "<div class=\"col\">";
                                mensajeRespuesta += "   <div class=\"card radius-10 bg-success\" style=\"height:160px;\">";
                                mensajeRespuesta += "       <div class=\"card-body\">";
                                mensajeRespuesta += "           <div class=\"d-flex align-items-center\">";
                                mensajeRespuesta += "               <div>";
                                mensajeRespuesta += "                   <p class=\"mb-0 text-white\">" + Reg[2].ToString() + "</p>";
                                mensajeRespuesta += "                   <h4 class=\"my-1 text-white\">" + Reg[1].ToString() + "</h4>";
                                mensajeRespuesta += "                   <a class=\"text-white dropdown-toggle dropdown-toggle-nocaret\" href=\"javascript:;\" data-bs-toggle=\"dropdown\">";
                                mensajeRespuesta += "                       <i class='bx bxs-down-arrow align-middle'></i> Ver detalle";
                                mensajeRespuesta += "                   </a>";
                                mensajeRespuesta += "                   <ul class=\"dropdown-menu dropdown-menu-end\">";
                                mensajeRespuesta += mtd_LeeProcesosByCita(Convert.ToInt64(Reg[0].ToString()));
                                mensajeRespuesta += "                   </ul>";
                                mensajeRespuesta += "               </div>";
                                mensajeRespuesta += "               <div class=\"dropdown ms-auto\"> ";
                                mensajeRespuesta += "                   <a href = \"javascript:;\" class=\"dropdown-toggle-nocaret more-options dropdown-toggle\" data-bs-toggle=\"dropdown\"> ";
                                mensajeRespuesta += "                       <i class='bx bx-dots-vertical-rounded'></i>";
                                mensajeRespuesta += "                   </a>";
                                mensajeRespuesta += "                   <ul class=\"dropdown-menu\" > ";
                                mensajeRespuesta += "                       <li><a class=\"dropdown-item\" href=\"javascript:;\" onclick=\"mtd_OpenModal('modalReprogramar');mtd_ReprogramaCita(" + valores + ");\"> Reprogramar</a></li>";
                                mensajeRespuesta += "                       <li><a class=\"dropdown-item\" href =\"javascript:;\" onclick=\"mtd_OpenModal('modalPrecedimientos');mtd_LeeTratamientos(" + procedmientos + ");\"> Procedimientos</a></li>";
                                mensajeRespuesta += "                       <li><a class=\"dropdown-item\" href =\"javascript:;\" onclick=\"mtd_ProcessCancelar(" + cancelar + ");\"> Cancelar</a></li>";
                                mensajeRespuesta += "                       <li><hr class=\"dropdown-divider\" ></li>";
                                mensajeRespuesta += "                       <li><a class=\"dropdown-item\" href=\"javascript:;\" onclick=\"mtd_AsigaValoresProccess("+ finaliza + ");mtd_OpenModal('modalFinalizacion');\"> Finalizar</a></li>";
                                mensajeRespuesta += "                   </ul>";
                                mensajeRespuesta += "               </div>";
                                mensajeRespuesta += "           </div>";
                                mensajeRespuesta += "       </div>";
                                mensajeRespuesta += "   </div>";
                                mensajeRespuesta += "</div>";

                                c++;
                            }
                            else if (c == 1)
                            {
                                mensajeRespuesta += "<div class=\"col\">";
                                mensajeRespuesta += "   <div class=\"card radius-10 bg-info\" style=\"height:160px;\">";
                                mensajeRespuesta += "       <div class=\"card-body\">";
                                mensajeRespuesta += "           <div class=\"d-flex align-items-center\">";
                                mensajeRespuesta += "               <div>";
                                mensajeRespuesta += "                   <p class=\"mb-0 text-white\">" + Reg[2].ToString() + "</p>";
                                mensajeRespuesta += "                   <h4 class=\"my-1 text-white\">" + Reg[1].ToString() + "</h4>";
                                mensajeRespuesta += "                   <a class=\"text-white dropdown-toggle dropdown-toggle-nocaret\" href=\"javascript:;\" data-bs-toggle=\"dropdown\">";
                                mensajeRespuesta += "                       <i class='bx bxs-down-arrow align-middle'></i> Ver detalle";
                                mensajeRespuesta += "                   </a>";
                                mensajeRespuesta += "                   <ul class=\"dropdown-menu dropdown-menu-end\">";
                                mensajeRespuesta += mtd_LeeProcesosByCita(Convert.ToInt64(Reg[0].ToString()));
                                mensajeRespuesta += "                   </ul>";
                                mensajeRespuesta += "               </div>";
                                mensajeRespuesta += "               <div class=\"dropdown ms-auto\"> ";
                                mensajeRespuesta += "                   <a href = \"javascript:;\" class=\"dropdown-toggle-nocaret more-options dropdown-toggle\" data-bs-toggle=\"dropdown\"> ";
                                mensajeRespuesta += "                       <i class='bx bx-dots-vertical-rounded'></i>";
                                mensajeRespuesta += "                   </a>";
                                mensajeRespuesta += "                   <ul class=\"dropdown-menu\" > ";
                                mensajeRespuesta += "                       <li><a class=\"dropdown-item\" href=\"javascript:;\" onclick=\"mtd_OpenModal('modalReprogramar');mtd_ReprogramaCita(" + valores + ");\"> Reprogramar</a></li>";
                                mensajeRespuesta += "                       <li><a class=\"dropdown-item\" href =\"javascript:;\" onclick=\"mtd_OpenModal('modalPrecedimientos');mtd_LeeTratamientos(" + procedmientos + ");\"> Procedimientos</a></li>";
                                mensajeRespuesta += "                       <li><a class=\"dropdown-item\" href =\"javascript:;\" onclick=\"mtd_ProcessCancelar(" + cancelar + ");\"> Cancelar</a></li>";
                                mensajeRespuesta += "                       <li><hr class=\"dropdown-divider\" ></li>";
                                mensajeRespuesta += "                       <li><a class=\"dropdown-item\" href=\"javascript:;\" onclick=\"mtd_AsigaValoresProccess(" + finaliza + ");mtd_OpenModal('modalFinalizacion');\"> Finalizar</a></li>";
                                mensajeRespuesta += "                   </ul>";
                                mensajeRespuesta += "               </div>";
                                mensajeRespuesta += "           </div>";
                                mensajeRespuesta += "       </div>";
                                mensajeRespuesta += "   </div>";
                                mensajeRespuesta += "</div>";
                                c++;
                            }
                            else {
                                mensajeRespuesta += "<div class=\"col\">";
                                mensajeRespuesta += "   <div class=\"card radius-10\" style=\"height:160px;\">";
                                mensajeRespuesta += "       <div class=\"card-body\">";
                                mensajeRespuesta += "           <div class=\"d-flex align-items-center\">";
                                mensajeRespuesta += "               <div>";
                                mensajeRespuesta += "                   <p class=\"mb-0 text-black\">" + Reg[2].ToString() + "</p>";
                                mensajeRespuesta += "                   <h4 class=\"my-1 text-black\">" + Reg[1].ToString() + "</h4>";
                                mensajeRespuesta += "                   <a class=\"text-black dropdown-toggle dropdown-toggle-nocaret\" href=\"javascript:;\" data-bs-toggle=\"dropdown\">";
                                mensajeRespuesta += "                       <i class='bx bxs-down-arrow align-middle'></i> Ver detalle";
                                mensajeRespuesta += "                   </a>";
                                mensajeRespuesta += "                   <ul class=\"dropdown-menu dropdown-menu-end\">";
                                mensajeRespuesta += mtd_LeeProcesosByCita(Convert.ToInt64(Reg[0].ToString()));
                                mensajeRespuesta += "                   </ul>";
                                mensajeRespuesta += "               </div>";
                                mensajeRespuesta += "               <div class=\"dropdown ms-auto\"> ";
                                mensajeRespuesta += "                   <a href = \"javascript:;\" class=\"dropdown-toggle-nocaret more-options dropdown-toggle\" data-bs-toggle=\"dropdown\"> ";
                                mensajeRespuesta += "                       <i class='bx bx-dots-vertical-rounded'></i>";
                                mensajeRespuesta += "                   </a>";
                                mensajeRespuesta += "                   <ul class=\"dropdown-menu\" > ";
                                mensajeRespuesta += "                       <li><a class=\"dropdown-item\" href=\"javascript:;\" onclick=\"mtd_OpenModal('modalReprogramar');mtd_ReprogramaCita(" + valores + ");\"> Reprogramar</a></li>";
                                mensajeRespuesta += "                       <li><a class=\"dropdown-item\" href =\"javascript:;\" onclick=\"mtd_OpenModal('modalPrecedimientos');mtd_LeeTratamientos(" + procedmientos + ");\"> Procedimientos</a></li>";
                                mensajeRespuesta += "                       <li><a class=\"dropdown-item\" href =\"javascript:;\" onclick=\"mtd_ProcessCancelar(" + cancelar + ");\"> Cancelar</a></li>";
                                mensajeRespuesta += "                       <li><hr class=\"dropdown-divider\" ></li>";
                                mensajeRespuesta += "                       <li><a class=\"dropdown-item\" href=\"javascript:;\" onclick=\"mtd_AsigaValoresProccess(" + finaliza + ");mtd_OpenModal('modalFinalizacion');\"> Finalizar</a></li>";
                                mensajeRespuesta += "                   </ul>";
                                mensajeRespuesta += "               </div>";
                                mensajeRespuesta += "           </div>";
                                mensajeRespuesta += "       </div>";
                                mensajeRespuesta += "   </div>";
                                mensajeRespuesta += "</div>";
                            }
                        }
                    }
                    else
                    {
                        mensajeRespuesta = respuestaSql;
                        mensajeRespuesta = mensajeRespuesta.Replace("\r", "");
                        mensajeRespuesta = mensajeRespuesta.Replace("\n", "");
                        mensajeRespuesta = mensajeRespuesta.Replace("'", "");
                        mensajeRespuesta = "ERROR||" + mensajeRespuesta;
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
        public static string mtd_LeeProcesosByCita(long cita)
        {
            string respuestaSql = "", mensajeRespuesta = "";

            try
            {
                using (SqlProcess sqlProccess = new SqlProcess())
                {
                    respuestaSql = sqlProccess.mtdEXP_CitasByExpediente(0, cita, 3);
                    if (respuestaSql == "OK")
                    {
                        foreach (DataRow Reg in sqlProccess.dtReturn.Rows)
                        {
                            mensajeRespuesta += "<li><a class=\"dropdown-item d-flex align-items-center py-2\" href=\"javascript:;\">" + Reg[0].ToString() + "</a></li>";
                        }
                    }
                    else
                    {
                        mensajeRespuesta = respuestaSql;
                        mensajeRespuesta = mensajeRespuesta.Replace("\r", "");
                        mensajeRespuesta = mensajeRespuesta.Replace("\n", "");
                        mensajeRespuesta = mensajeRespuesta.Replace("'", "");
                        mensajeRespuesta = "ERROR||" + mensajeRespuesta;
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
        public static string mtd_LeeTiposCitas(long accion)
        {
            string sql = "", mensaje = "";
            try
            {
                using (SqlProcess sqlProccess = new SqlProcess())
                {
                    sql = sqlProccess.mtdCAT_TiposCitas(0, "", "0", "", accion);

                    mensaje = "OK||<option value=\"-1\">--Seleccione una opcion--</option>";
                    foreach (DataRow Reg in sqlProccess.dtReturn.Rows)
                    {
                        mensaje += "<option value=\"" + Reg[0].ToString() + "\">" + Reg[1].ToString() + "</option>";
                    }
                }

            }
            catch (Exception ex)
            {
                mensaje = "Se ha producido un error, si el problema persiste, por favor comunicarse \ncon el administrador del sistema: " + ex.Message;
            }

            return mensaje;
        }

        [WebMethod]
        public static string mtd_LeeHorarios(long tipocita, long especialista, string fecha)
        {
            string respuestaSql = "", mensajeRespuesta = "";
            DateTime fec;
            fec = Convert.ToDateTime(fecha);
            fecha = fec.ToString("yyyyMMdd");

            try
            {
                using (SqlProcess sqlProccess = new SqlProcess())
                {
                    respuestaSql = sqlProccess.mtdCAT_HorariosByCitas(tipocita, especialista, fecha,2);
                    if (respuestaSql == "OK")
                    {
                        mensajeRespuesta = "OK||<option value=\"-1\">--Seleccione una opcion--</option>";
                        foreach (DataRow Reg in sqlProccess.dtReturn.Rows)
                        {
                            mensajeRespuesta += "<option value=\"" + Reg[0].ToString() + "\">" + Reg[1].ToString() + "</option>";
                        }
                    }
                    else
                    {
                        mensajeRespuesta = respuestaSql;
                        mensajeRespuesta = mensajeRespuesta.Replace("\r", "");
                        mensajeRespuesta = mensajeRespuesta.Replace("\n", "");
                        mensajeRespuesta = mensajeRespuesta.Replace("'", "");
                        mensajeRespuesta = "ERROR||" + mensajeRespuesta;
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
        public static string mtd_LeeEstatus(int accion)
        {
            string respuestaSql = "", mensajeRespuesta = "";

            try
            {
                using (SqlProcess sqlProccess = new SqlProcess())
                {
                    respuestaSql = sqlProccess.mtdCAT_EstadosCitas(0, "", "", "", 0, 0, 0, 0, "", accion);
                    if (respuestaSql == "OK")
                    {
                        mensajeRespuesta = "OK||<option value=\"-1\">--Seleccione una opcion--</option>";
                        foreach (DataRow Reg in sqlProccess.dtReturn.Rows)
                        {
                            mensajeRespuesta += "<option value=\"" + Reg[0].ToString() + "\">" + Reg[1].ToString() + "</option>";
                        }
                    }
                    else
                    {
                        mensajeRespuesta = respuestaSql;
                        mensajeRespuesta = mensajeRespuesta.Replace("\r", "");
                        mensajeRespuesta = mensajeRespuesta.Replace("\n", "");
                        mensajeRespuesta = mensajeRespuesta.Replace("'", "");
                        mensajeRespuesta = "ERROR||" + mensajeRespuesta;
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
        public static string mtd_LeeEspecialista(int accion)
        {
            string respuestaSql = "", mensajeRespuesta = "";

            try
            {
                using (SqlProcess sqlProccess = new SqlProcess())
                {
                    respuestaSql = sqlProccess.mtdCAT_Especialistas(0, "", "", "", accion);
                    if (respuestaSql == "OK")
                    {
                        mensajeRespuesta = "OK||<option value=\"-1\">--Seleccione una opcion--</option>";
                        foreach (DataRow Reg in sqlProccess.dtReturn.Rows)
                        {
                            mensajeRespuesta += "<option value=\""+ Reg[0].ToString() + "\">" + Reg[1].ToString() + "</option>";
                        }
                    }
                    else
                    {
                        mensajeRespuesta = respuestaSql;
                        mensajeRespuesta = mensajeRespuesta.Replace("\r", "");
                        mensajeRespuesta = mensajeRespuesta.Replace("\n", "");
                        mensajeRespuesta = mensajeRespuesta.Replace("'", "");
                        mensajeRespuesta = "ERROR||" + mensajeRespuesta;
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
        public static string mtd_ReprogramaCita(long id, int accion) {
            string respuestaSql = "", mensajeRespuesta = "";

            try
            {
                using (SqlProcess sqlProccess = new SqlProcess())
                {
                    respuestaSql = sqlProccess.mtdEXP_ReprogramaCitas(id, accion);
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
                            mensajeRespuesta += Reg[6].ToString() + "||";
                            mensajeRespuesta += Reg[7].ToString();
                        }
                    }
                    else
                    {
                        mensajeRespuesta = respuestaSql;
                        mensajeRespuesta = mensajeRespuesta.Replace("\r", "");
                        mensajeRespuesta = mensajeRespuesta.Replace("\n", "");
                        mensajeRespuesta = mensajeRespuesta.Replace("'", "");
                        mensajeRespuesta = "ERROR||" + mensajeRespuesta;
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
        public static string mtd_SaveReprogramaCita(long id, long cita, long especialista, long estatus, string fecha, string hora
            , string horariofin, string tipocita, string comentario, string user, int accion)
        {
            string respuestaSql = "", mensajeRespuesta = "";

            try
            {
                DateTime fec = Convert.ToDateTime(fecha);
                fecha = fec.ToString("yyyyMMdd");

                using (SqlProcess sqlProccess = new SqlProcess())
                {
                    respuestaSql = sqlProccess.mtdEXP_CitasReprograma(id, cita, especialista, estatus, fecha, hora, horariofin, tipocita, comentario, user, accion);
                    if (respuestaSql == "OK")
                        mensajeRespuesta = "OK||La informacion fue almacenada satisfactoriamente.";
                    else
                    {
                        mensajeRespuesta = respuestaSql;
                        mensajeRespuesta = mensajeRespuesta.Replace("\r", "");
                        mensajeRespuesta = mensajeRespuesta.Replace("\n", "");
                        mensajeRespuesta = mensajeRespuesta.Replace("'", "");
                        mensajeRespuesta = "ERROR||" + mensajeRespuesta;
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
        public static string mtd_LeeTratamientosByProccess(long cita, string user, int accion)
        {
            string respuestaSql = "", mensajeRespuesta = "";
            double total = 0;

            try
            {
                using (SqlProcess sqlProccess = new SqlProcess())
                {
                    respuestaSql = sqlProccess.mtdEXP_LeeProcedimientos(cita, accion);
                    if (respuestaSql == "OK")
                    {
                        mensajeRespuesta = "OK||";
                        foreach (DataRow Reg in sqlProccess.dtReturn.Rows)
                        {
                            mensajeRespuesta += "<div class=\"row border mx-0 mb-3 py-2 radius-10 cursor-pointer\">";
                            mensajeRespuesta += "    <div class=\"col-sm-6\">";
                            mensajeRespuesta += "        <div class=\"d-flex align-items-center\">";
                            mensajeRespuesta += "	        <div class=\"ms-2\">";
                            mensajeRespuesta += "                <h6 class=\"mb-1\" > " + Reg[1].ToString() + "</h6>";
                            mensajeRespuesta += "            </div>";
                            mensajeRespuesta += "        </div>";
                            mensajeRespuesta += "    </div>";
                            mensajeRespuesta += "    <div class=\"col-sm-4\">";
                            mensajeRespuesta += "        <h6 class=\"mb-1\" >$" + string.Format("{0:#,#0.00}", Convert.ToDouble(Reg[3].ToString())) + "</h6>";
                            mensajeRespuesta += "        <p class=\"mb-0\" > cantidad: <span>" + Reg[2].ToString() + "</span></p>";
                            mensajeRespuesta += "    </div>";
                            mensajeRespuesta += "    <div class=\"col-sm-2\">";
                            mensajeRespuesta += "      <a href=\"#\" onclick=\"mtd_SaveTtoByProccess('" + cita + "','" + Reg[0].ToString() + "','" + user + "', 3);\"> <i class=\"text-danger bx bx-trash\"></i></a>";
                            mensajeRespuesta += "    </div>";
                            mensajeRespuesta += "</div>";

                            total += Convert.ToDouble(Reg[3].ToString());
                        }

                        mensajeRespuesta += "||" + string.Format("{0:#,#0.00}", Convert.ToDouble(total));
                    }
                    else
                    {
                        mensajeRespuesta = respuestaSql;
                        mensajeRespuesta = mensajeRespuesta.Replace("\r", "");
                        mensajeRespuesta = mensajeRespuesta.Replace("\n", "");
                        mensajeRespuesta = mensajeRespuesta.Replace("'", "");
                        mensajeRespuesta = "ERROR||" + mensajeRespuesta;
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
        public static string mtd_LeeTratamientos(long cita, string user, long accion)
        {
            string respuestaSql = "", mensaje = "";
            try
            {
                using (SqlProcess sqlProccess = new SqlProcess())
                {
                    respuestaSql = sqlProccess.mtdCAT_Tratamientos(0, "", "0", "0", "", "", "", "", accion);
                    if (respuestaSql == "OK")
                    {
                        mensaje = "OK||";
                        foreach (DataRow Reg in sqlProccess.dtReturn.Rows)
                        {
                            mensaje += "<div class=\"col\">";
                            mensaje += "    <a href=\"#\" onclick=\"mtd_SaveTtoByProccess(" + cita + ", " + Reg[0].ToString() + ", '" + user + "', 1);\">";
                            mensaje += "        <div class=\"card\" style=\"height:250px;\">";
                            mensaje += "	        <img src=\"" + Reg[6].ToString() + "\" style=\"width:100%;height:140px;\" class=\"card-img-top\" alt =\"...\">";
                            mensaje += "		    <div class=\"card-body\">";
                            mensaje += "		        <h6 class=\"card-title cursor-pointer\">" + Reg[1].ToString() + "</h6>";
                            mensaje += "			    <div class=\"clearfix\">";
                            mensaje += "			        <p class=\"mb-0 float-start\"><strong>" + Reg[2].ToString() + "</strong> min</p>";
                            mensaje += "		            <p class=\"mb-0 float-end fw-bold\" ><span>$" + string.Format("{0:#,#0.00}", Convert.ToDouble(Reg[3].ToString())) + "</span></p>";
                            mensaje += "                </div>";
                            mensaje += "            </div>";
                            mensaje += "        </div>";
                            mensaje += "    </a>";
                            mensaje += "</div>";
                        }
                    }
                }

            }
            catch (Exception ex)
            {
                mensaje = "ERROR||Se ha producido un error, si el problema persiste, por favor comunicarse \ncon el administrador del sistema: " + ex.Message;
            }

            return mensaje;
        }

        [WebMethod]
        public static string mtd_SaveTtoByProccess(long cita, long tratamiento, string user, int accion)
        {
            string respuestaSql = "", mensajeRespuesta = "";
            try
            {
                using (SqlProcess sqlProccess = new SqlProcess())
                {
                    respuestaSql = sqlProccess.mtdEXP_TratamientosByProccess(cita, tratamiento, user, accion);
                    if (respuestaSql == "OK") 
                        mensajeRespuesta = "OK||La informacion fue almacenada satisfactoriamente.";
                    else
                        mensajeRespuesta = "ERROR||Ocurrio un error al momento de almacenar la informacion.";
                }

            }
            catch (Exception ex)
            {
                mensajeRespuesta = "ERROR||Se ha producido un error, si el problema persiste, por favor comunicarse \ncon el administrador del sistema: " + ex.Message;
            }

            return mensajeRespuesta;
        }

        [WebMethod]
        public static string mtd_DeleteByTratamientos(long id, int accion)
        {
            string respuestaSql = "", mensajeRespuesta = "";

            try
            {
                using (SqlProcess sqlProccess = new SqlProcess())
                {
                    respuestaSql = sqlProccess.mtdEXP_ReprogramaCitas(id, accion);
                    if (respuestaSql == "OK")
                        mensajeRespuesta = "OK||La informacion fue eliminada satisfactoriamente.";
                    else
                    {
                        mensajeRespuesta = respuestaSql;
                        mensajeRespuesta = mensajeRespuesta.Replace("\r", "");
                        mensajeRespuesta = mensajeRespuesta.Replace("\n", "");
                        mensajeRespuesta = mensajeRespuesta.Replace("'", "");
                        mensajeRespuesta = "ERROR||" + mensajeRespuesta;
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
        public static string mtd_FinishedProcess(long id, long cita, string diagnostico, string resultado, string recomendacion, string user, int accion)
        {
            string respuestaSql = "", mensajeRespuesta = "";
            try
            {
                using (SqlProcess sqlProccess = new SqlProcess())
                {
                    respuestaSql = sqlProccess.mtdEXP_ProcessUpdate(id, cita, diagnostico, resultado, recomendacion, user, accion);
                    if (respuestaSql == "OK")
                        mensajeRespuesta = "OK||La informacion fue almacenada satisfactoriamente.";
                    else
                        mensajeRespuesta = "ERROR||Ocurrio un error al momento de almacenar la informacion.";
                }
            }
            catch (Exception ex)
            {
                mensajeRespuesta = "ERROR||Se ha producido un error, si el problema persiste, por favor comunicarse \ncon el administrador del sistema: " + ex.Message;
            }

            return mensajeRespuesta;
        }

        [WebMethod]
        public static string mtd_AsigaValoresProccess(long cita)
        {
            string respuestaSql = "", mensajeRespuesta = "";
            int c = 0;

            try
            {
                using (SqlProcess sqlProccess = new SqlProcess())
                {
                    respuestaSql = sqlProccess.mtdEXP_ProcessUpdate(0, cita, "", "", "", "", 5);
                    if (respuestaSql == "OK")
                    {
                        mensajeRespuesta = "OK||"+ sqlProccess.dtReturn.Rows.Count;
                        foreach (DataRow Reg in sqlProccess.dtReturn.Rows)
                        {
                            mensajeRespuesta += "||" + Reg[0].ToString();
                            mensajeRespuesta += "||" + Reg[1].ToString();
                            mensajeRespuesta += "||" + Reg[2].ToString();
                            mensajeRespuesta += "||" + Reg[3].ToString();
                        }
                    }
                    else
                    {
                        mensajeRespuesta = respuestaSql;
                        mensajeRespuesta = mensajeRespuesta.Replace("\r", "");
                        mensajeRespuesta = mensajeRespuesta.Replace("\n", "");
                        mensajeRespuesta = mensajeRespuesta.Replace("'", "");
                        mensajeRespuesta = "ERROR||" + mensajeRespuesta;
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
        public static string mtd_LeeCitasFinalizadas(string user, int accion)
        {
            string respuestaSql = "", mensajeRespuesta = "";
            
            try
            {
                using (SqlProcess sqlProccess = new SqlProcess())
                {
                    respuestaSql = sqlProccess.mtdEXP_CitasVigentes(user, accion);
                    if (respuestaSql == "OK")
                    {
                        mensajeRespuesta = "OK||";
                        foreach (DataRow Reg in sqlProccess.dtReturn.Rows)
                        {
                            mensajeRespuesta += "<div class=\"col\">";
                            mensajeRespuesta += "   <div class=\"card radius-10\" style=\"height:160px;\">";
                            mensajeRespuesta += "       <div class=\"card-body\">";
                            mensajeRespuesta += "           <div class=\"d-flex align-items-center\">";
                            mensajeRespuesta += "               <div>";
                            mensajeRespuesta += "                   <p class=\"mb-0 text-black\">" + Reg[2].ToString() + "</p>";
                            mensajeRespuesta += "                   <h4 class=\"my-1 text-black\">" + Reg[1].ToString() + "</h4>";
                            mensajeRespuesta += "                   <a class=\"text-black dropdown-toggle dropdown-toggle-nocaret\" href=\"javascript:;\" data-bs-toggle=\"dropdown\">";
                            mensajeRespuesta += "                       <i class='bx bxs-down-arrow align-middle'></i> Ver detalle";
                            mensajeRespuesta += "                   </a>";
                            mensajeRespuesta += "                   <ul class=\"dropdown-menu dropdown-menu-end\">";
                            mensajeRespuesta += mtd_LeeProcesosByCita(Convert.ToInt64(Reg[0].ToString()));
                            mensajeRespuesta += "                   </ul>";
                            mensajeRespuesta += "               </div>";
                            mensajeRespuesta += "               <div class=\"dropdown ms-auto\"> ";
                            mensajeRespuesta += "                   <a href = \"javascript:;\" class=\"dropdown-toggle-nocaret more-options dropdown-toggle\" data-bs-toggle=\"dropdown\"> ";
                            mensajeRespuesta += "                       <i class='bx bx-dots-vertical-rounded'></i>";
                            mensajeRespuesta += "                   </a>";
                            mensajeRespuesta += "                   <ul class=\"dropdown-menu\" > ";
                            mensajeRespuesta += "                       <li><a class=\"dropdown-item\" href=\"javascript:;\" onclick=\"mtd_AsigaValoresProccess(" + Reg[0].ToString() + ");mtd_OpenModal('modalFinalizacion');\"> Finalizar</a></li>";
                            mensajeRespuesta += "                   </ul>";
                            mensajeRespuesta += "               </div>";
                            mensajeRespuesta += "           </div>";
                            mensajeRespuesta += "       </div>";
                            mensajeRespuesta += "   </div>";
                            mensajeRespuesta += "</div>";
                        }
                    }
                    else
                    {
                        mensajeRespuesta = respuestaSql;
                        mensajeRespuesta = mensajeRespuesta.Replace("\r", "");
                        mensajeRespuesta = mensajeRespuesta.Replace("\n", "");
                        mensajeRespuesta = mensajeRespuesta.Replace("'", "");
                        mensajeRespuesta = "ERROR||" + mensajeRespuesta;
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
        public static string mtd_ProcessCancelar(long cita, string user)
        {
            string respuestaSql = "", mensajeRespuesta = "";
            try
            {
                using (SqlProcess sqlProccess = new SqlProcess())
                {
                    respuestaSql = sqlProccess.mtdEXP_ProccessCancelar(cita, user);
                    if (respuestaSql == "OK")
                        mensajeRespuesta = "OK||La informacion fue almacenada satisfactoriamente.";
                    else
                        mensajeRespuesta = "ERROR||Ocurrio un error al momento de almacenar la informacion.";
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