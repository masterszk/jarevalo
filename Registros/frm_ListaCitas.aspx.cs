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
    public partial class frm_ListaCitas : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {

        }

        [WebMethod]
        public static string mtd_LeeCitasVigentesHoy(string user, int accion)
        {
            string respuestaSql = "", mensajeRespuesta = "";
            string btnEdit = "";
            string valores = "";

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
                            valores = string.Format("'{0}','{1}','{2}'", Reg[0].ToString(), 5, 1);

                            mensajeRespuesta += "<div class=\"col\">";
                            mensajeRespuesta += "   <div class=\"card radius-10\" style=\"width:270px;height:160px;\">";
                            mensajeRespuesta += "       <div class=\"card-body\"> ";
                            mensajeRespuesta += "           <div class=\"text-center\" > ";
                            mensajeRespuesta += "               <div class=\"widgets-icons rounded-circle mx-auto bg-light-success text-success mb-3\" >";
                            mensajeRespuesta += "                   <a href=\"javascript:;\" onclick=\"mtd_OpenModal('modalCita');mtd_LeeCita(" + valores + ");\" ><i class='bx bx-calendar-edit'></i></a>";
                            mensajeRespuesta += "               </div>";
                            mensajeRespuesta += "               <h5 class=\"my-1\">" + Reg[2].ToString() + "</h5><span style=\"font-size:smaller;\"> (" + Reg[10].ToString() + "min)</span>";
                            mensajeRespuesta += "               <p class=\"mb-0 text-secondary\">" + Reg[1].ToString() + "</p>";
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
        public static string mtd_LeeCitasVigentesTomorrow(string user, int accion)
        {
            string respuestaSql = "", mensajeRespuesta = "";
            string btnEdit = "", btnDel = "", btnCitas = "";
            string valores = "", estado = "", edit = "";
            string citas = "";

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
                            valores = string.Format("'{0}','{1}','{2}'", Reg[0].ToString(), 5,2);

                            //edit = "AjaxLink('Registros/frm_EditExpediente.aspx?id=" + Reg[0].ToString() + "')";
                            //citas = "mtd_SaveTtoByExpediente(0, 0, 0, '" + user + "', 0);mtd_LeeTratamientos(" + Reg[0].ToString() + ", '" + user + "', 6);mtd_OpenModal('modalCitas');";


                            btnEdit = "<button title=\"Edita Expediente\" class=\"btn btn-outline-dark\" onclick=\"" + edit + "\"><i class=\"bx bx-edit-alt\"></i> </button>";
                            btnCitas = "<button title=\"Programar Cita\" class=\"btn btn-outline-success\" onclick=\"" + citas + "\"><i class=\"bx bx-calendar\"></i> </button>";
                            btnDel = "<button title=\"Elimina Registro\" class=\"btn btn-outline-danger\" onclick=\"showConfirmElimina(); mtd_AsignaValores(" + valores + ");\"><i class=\"bx bx-trash\"></i></button>";

                            mensajeRespuesta += "<div class=\"col\"> ";
                            mensajeRespuesta += "   <div class=\"card radius-10\"  style=\"width:270px; height:146px;\">";
                            mensajeRespuesta += "       <div class=\"card-body\" > ";
                            mensajeRespuesta += "           <div class=\"d-flex align-items-center\" >";
                            mensajeRespuesta += "               <div>";
                            mensajeRespuesta += "                   <p class=\"mb-0 text-secondary\"> " + Reg[1].ToString() + "</p>";
                            mensajeRespuesta += "                   <h4 class=\"my-1\" >" + Reg[2].ToString() + "</h4><span style=\"font-size:smaller;\"> (" + Reg[10].ToString() + "min)</span>";
                            mensajeRespuesta += "                   <p class=\"mb -0 font-13 text-success\"><i class='bx bxs-user align-middle'></i>" + Reg[3].ToString() + "</p>";
                            mensajeRespuesta += "               </div>";
                            mensajeRespuesta += "               <div class=\"widgets-icons bg-light-info text-info ms-auto\">";
                            mensajeRespuesta += "                   <a href=\"javascript:;\" onclick=\"mtd_OpenModal('modalCita');mtd_LeeCita(" + valores + ");\" ><i class='bx bx-calendar-edit'></i></a>";
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
        public static string mtd_LeeCitasVigentesFuture(string user, int accion)
        {
            string respuestaSql = "", mensajeRespuesta = "";
            string btnEdit = "", btnDel = "", btnCitas = "";
            string valores = "", estado = "", edit = "";
            string citas = "";

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
                            valores = string.Format("'{0}','{1}','{2}'", Reg[0].ToString(), 5, 3);
                            //edit = "AjaxLink('Registros/frm_EditExpediente.aspx?id=" + Reg[0].ToString() + "')";
                            //citas = "mtd_SaveTtoByExpediente(0, 0, 0, '" + user + "', 0);mtd_LeeTratamientos(" + Reg[0].ToString() + ", '" + user + "', 6);mtd_OpenModal('modalCitas');";


                            //btnEdit = "<button title=\"Edita Expediente\" class=\"btn btn-outline-dark\" onclick=\"" + edit + "\"><i class=\"bx bx-edit-alt\"></i> </button>";
                            //btnCitas = "<button title=\"Programar Cita\" class=\"btn btn-outline-success\" onclick=\"" + citas + "\"><i class=\"bx bx-calendar\"></i> </button>";
                            //btnDel = "<button title=\"Elimina Registro\" class=\"btn btn-outline-danger\" onclick=\"showConfirmElimina(); mtd_AsignaValores(" + valores + ");\"><i class=\"bx bx-trash\"></i></button>";

                            mensajeRespuesta += "<div class=\"col\" >";
                            mensajeRespuesta += "   <div class=\"card radius-10\" style=\"width:270px; height:98px;\">";
                            mensajeRespuesta += "       <div class=\"card-body\" > ";
                            mensajeRespuesta += "           <div class=\"d-flex align-items-center\"> ";
                            mensajeRespuesta += "               <div>";
                            mensajeRespuesta += "                   <p class=\"mb-0\" >" + Reg[1].ToString() + "</p>";
                            mensajeRespuesta += "                   <h5 class=\"mb-0\" >" + Reg[6].ToString() +" "+ Reg[2].ToString() + "</h5>";
                            mensajeRespuesta += "               </div>";
                            mensajeRespuesta += "               <div class=\"dropdown ms-auto\"> ";
                            mensajeRespuesta += "                   <a href = \"javascript:;\" class=\"dropdown-toggle-nocaret more-options dropdown-toggle\" data-bs-toggle=\"dropdown\"> ";
                            mensajeRespuesta += "                       <i class='bx bx-dots-vertical-rounded'></i>";
                            mensajeRespuesta += "                   </a>";
                            mensajeRespuesta += "                   <ul class=\"dropdown-menu\" > ";
                            mensajeRespuesta += "                       <li><a class=\"dropdown-item\" href=\"javascript:;\" onclick=\"mtd_OpenModal('modalCita');mtd_LeeCita(" + valores + ");\"  > Editar</a></li>";
                            //mensajeRespuesta += "                       <li><a class=\"dropdown-item\" href =\"javascript:;\" > Another action</a></li>";
                            //mensajeRespuesta += "                       <li><hr class=\"dropdown-divider\" ></li>";
                            //mensajeRespuesta += "                       <li><a class=\"dropdown-item\" href=\"javascript:;\" > Something else here</a></li>";
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
        public static string mtd_LeeCita(long id, int accion, int ind)
        {
            string respuestaSql = "", mensajeRespuesta = "";

            try
            {
                using (SqlProcess sqlProccess = new SqlProcess())
                {
                    respuestaSql = sqlProccess.mtdEXP_RegistroCitas(id, 0, 0, 0, 0, 0, 0, 0, "", "", "", accion);
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
                            mensajeRespuesta += Reg[6].ToString();
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
        public static string mtd_LeeEspecialistas(long accion)
        {
            string sql = "", mensaje = "";
            try
            {
                using (SqlProcess sqlProccess = new SqlProcess())
                {
                    sql = sqlProccess.mtdCAT_Especialistas(0, "", "0", "", accion);

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
            string sql = "", mensaje = "";
            DateTime fec = Convert.ToDateTime(fecha);
            fecha = fec.ToString("yyyyMMdd");


            try
            {
                using (SqlProcess sqlProccess = new SqlProcess())
                {
                    sql = sqlProccess.mtdCAT_HorariosByCitas(tipocita, especialista, fecha, 2);

                    mensaje = "OK||<option value=\"-1\">--Seleccione una opcion--</option>";
                    foreach (DataRow Reg in sqlProccess.dtReturn.Rows)
                    {
                        mensaje += "<option value=\"" + Reg[0].ToString() + "\">" + Reg[1].ToString() + "</option>";
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
        public static string mtd_LeeEstatus(long accion)
        {
            string sql = "", mensaje = "";

            try
            {
                using (SqlProcess sqlProccess = new SqlProcess())
                {
                    sql = sqlProccess.mtdCAT_EstadosCitas(0, "", "", "", 0, 0, 0, 0, "", accion);

                    mensaje = "OK||<option value=\"-1\">--Seleccione una opcion--</option>";
                    foreach (DataRow Reg in sqlProccess.dtReturn.Rows)
                    {
                        mensaje += "<option value=\"" + Reg[0].ToString() + "\">" + Reg[1].ToString() + "</option>";
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
        public static string mtd_SaveCita(long id, long expediente, long horario, long horariofin, long tipocita
            , long especialista, long tratamiento, long estado, string comentario, string fecha, string user, int accion)
        {
            string sql = "", mensaje = "";
            try
            {
                DateTime fec = Convert.ToDateTime(fecha);
                fecha = fec.ToString("yyyyMMdd");

                using (SqlProcess sqlProccess = new SqlProcess())
                {
                    sql = sqlProccess.mtdEXP_RegistroCitas(id, expediente, horario, horariofin, tipocita, especialista, tratamiento, estado, comentario, fecha, user, accion);
                    if (sql == "OK")
                        mensaje = "OK||La cita fue modificada satisfactoriamente";
                    else
                        mensaje = "ERROR||Ocurrio un error al momento de crear el registro.";
                }

            }
            catch (Exception ex)
            {
                mensaje = "ERROR||Se ha producido un error, si el problema persiste, por favor comunicarse \ncon el administrador del sistema: " + ex.Message;
            }

            return mensaje;
        }
    }
}