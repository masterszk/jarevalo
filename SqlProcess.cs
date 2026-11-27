using System;
using System.Collections;
using System.Data;
using System.Data.SqlClient;
using System.Diagnostics;
using System.Net;
using System.Reflection;
using System.Web;
using iTextSharp.text.pdf.codec.wmf;


namespace DPieCenter
{
    public class SqlProcess : IDisposable
    {
        #region "Variables Privadas"
        LogErrores obj_logErrores = new LogErrores();
        #endregion

        public string Estado = "";

        #region "Propiedades"
        private DataTable _dtReturn;
        private DataTable _dtReturn1;

        public DataTable dtReturn
        {
            get
            {
                return _dtReturn;
            }
            set
            {
                _dtReturn = value;
            }
        }
        public DataTable dtReturn1
        {
            get
            {
                return _dtReturn1;
            }
            set
            {
                _dtReturn1 = value;
            }
        }

        private DataSet _dsReturn;
        public DataSet dsReturn
        {
            get
            {
                return _dsReturn;
            }
            set
            {
                _dsReturn = value;
            }
        }
        #endregion

        //Metodo para extraer la cadena de conexion
        public string mtd_ExtraeConexion()
        {
            try
            {
                return System.Configuration.ConfigurationManager.ConnectionStrings["conexionDiarypro"].ConnectionString;
            }
            catch (Exception ex)
            {
                return ex.ToString();
            }
        }
        private bool mtd_OpcionBaseDeDatos()
        {
            return true;
        }

        #region "Empresa Informacion"
        public string mtdSys_InformacionEmpresa(
            string usuario, long idempresa, string empresa, string abreviado, string logoempresa, string idusuariocreacion, string idusuariomodificacion, string logocliente
            , string logotitulopagina, string titulopagina, string logomenuaplicativo, string imagenfonologin, string imagenfondoaplicativo, string nombresistema
            , string mensajebienvenida, string titulobienvenida, string signomonedalocal, string signomonedadolar, string horainicio, string horafinal
            , bool lunes, bool martes, bool miercoles, bool jueves, bool viernes, bool sabado, bool domingo
            , long accion)
        {

            if (mtd_OpcionBaseDeDatos())
            {
                return SQL_mtdSys_InformacionEmpresa(
                    usuario, idempresa, empresa, abreviado, logoempresa, idusuariocreacion, idusuariomodificacion, logocliente
                    , logotitulopagina, titulopagina, logomenuaplicativo, imagenfonologin, imagenfondoaplicativo, nombresistema
                    , mensajebienvenida, titulobienvenida, signomonedalocal, signomonedadolar, horainicio, horafinal
                    , lunes, martes, miercoles, jueves, viernes, sabado, domingo
                    , accion);
            }
            else
            {
                return ODBC_mtdSys_InformacionEmpresa(
                    usuario, idempresa, empresa, abreviado, logoempresa, idusuariocreacion, idusuariomodificacion, logocliente
                    , logotitulopagina, titulopagina, logomenuaplicativo, imagenfonologin, imagenfondoaplicativo, nombresistema
                    , mensajebienvenida, titulobienvenida, signomonedalocal, signomonedadolar, horainicio, horafinal
                    , lunes, martes, miercoles, jueves, viernes, sabado, domingo
                    , accion);
            }
        }

        //Procedimiento leeEmpresaByUsuario cuando la conexion es con sqlserver

        private string SQL_mtdSys_InformacionEmpresa(
            string usuario, long idempresa, string empresa, string abreviado, string logoempresa, string idusuariocreacion, string idusuariomodificacion, string logocliente
            , string logotitulopagina, string titulopagina, string logomenuaplicativo, string imagenfonologin, string imagenfondoaplicativo, string nombresistema
            , string mensajebienvenida, string titulobienvenida, string signomonedalocal, string signomonedadolar, string horainicio, string horafinal
            , bool lunes, bool martes, bool miercoles, bool jueves, bool viernes, bool sabado, bool domingo
            , long accion)
        {
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("Sys_SP_InfoEmpresa", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@IdEmpresa", idempresa);
            da.SelectCommand.Parameters.AddWithValue("@Empresa", empresa);
            da.SelectCommand.Parameters.AddWithValue("@Abreviado", abreviado);
            da.SelectCommand.Parameters.AddWithValue("@LogoEmpresa", logoempresa);
            da.SelectCommand.Parameters.AddWithValue("@usuarioCreacion", idusuariocreacion);
            da.SelectCommand.Parameters.AddWithValue("@usuarioModificacion", idusuariomodificacion);
            da.SelectCommand.Parameters.AddWithValue("@LogoCliente", logocliente);
            da.SelectCommand.Parameters.AddWithValue("@LogoTituloPagina", logotitulopagina);
            da.SelectCommand.Parameters.AddWithValue("@TituloPagina", titulopagina);
            da.SelectCommand.Parameters.AddWithValue("@LogoMenuAplicativo", logomenuaplicativo);
            da.SelectCommand.Parameters.AddWithValue("@ImagenFonoLogin", imagenfonologin);
            da.SelectCommand.Parameters.AddWithValue("@ImagenFondoAplicativo", imagenfondoaplicativo);
            da.SelectCommand.Parameters.AddWithValue("@NombreSistema", nombresistema);
            da.SelectCommand.Parameters.AddWithValue("@MensajeBienvenida", mensajebienvenida);
            da.SelectCommand.Parameters.AddWithValue("@TituloBienvenida", titulobienvenida);
            da.SelectCommand.Parameters.AddWithValue("@SignoMonedaLocal", signomonedalocal);
            da.SelectCommand.Parameters.AddWithValue("@SignoMonedaDolar", signomonedadolar);
            da.SelectCommand.Parameters.AddWithValue("@HoraInicio", horainicio);
            da.SelectCommand.Parameters.AddWithValue("@HoraFinal", horafinal);
            da.SelectCommand.Parameters.AddWithValue("@Lunes", lunes);
            da.SelectCommand.Parameters.AddWithValue("@Martes", martes);
            da.SelectCommand.Parameters.AddWithValue("@Miercoles", miercoles);
            da.SelectCommand.Parameters.AddWithValue("@Jueves", jueves);
            da.SelectCommand.Parameters.AddWithValue("@Viernes", viernes);
            da.SelectCommand.Parameters.AddWithValue("@Sabado", sabado);
            da.SelectCommand.Parameters.AddWithValue("@Domingo", domingo);
            da.SelectCommand.Parameters.AddWithValue("@Accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;
            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                // Se tiene que pasar ID de usuario cuando no exista -1
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, usuario, e.Message);

                return "no hay datos";
            }

            if (dt != null)
            {

                if (ds.Tables.Count > 1)
                {

                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow Fila = ds.Tables[1].Rows[0];
                        respuestaBD = Fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }

                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow Fila = dt.Rows[0];
                        respuestaBD = Fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }
                }

            }
            else
            {
                respuestaBD = "N&&";
            }

            return respuestaBD;

        }
        //Procedimiento leeEmpresaByUsuario cuando la conexion es con odbc

        private string ODBC_mtdSys_InformacionEmpresa(
            string usuario, long idempresa, string empresa, string abreviado, string logoempresa, string idusuariocreacion, string idusuariomodificacion, string logocliente
            , string logotitulopagina, string titulopagina, string logomenuaplicativo, string imagenfonologin, string imagenfondoaplicativo, string nombresistema
            , string mensajebienvenida, string titulobienvenida, string signomonedalocal, string signomonedadolar, string horainicio, string horafinal
            , bool lunes, bool martes, bool miercoles, bool jueves, bool viernes, bool sabado, bool domingo
            , long accion)
        {

            return "no activa";
        }
        #endregion

        #region "Registro AjaxLink"
        public string mtdSys_AjaxLink(long idAjaxLink, string Usuario, string AjaxLink, int Accion)
        {
            if (mtd_OpcionBaseDeDatos())
            {
                return SQL_mtdSys_AjaxLink(idAjaxLink, Usuario, AjaxLink, Accion);
            }
            else
            {
                return ODBC_mtdSys_AjaxLink(idAjaxLink, Usuario, AjaxLink, Accion);
            }
        }
        private string SQL_mtdSys_AjaxLink(long idAjaxLink, string Usuario, string AjaxLink, int Accion)
        {
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("Sys_SP_AjaxLink", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@Id_AjaxLink", idAjaxLink);
            da.SelectCommand.Parameters.AddWithValue("@Id_Usuario", Usuario);
            da.SelectCommand.Parameters.AddWithValue("@AjaxLink", AjaxLink);
            da.SelectCommand.Parameters.AddWithValue("@Accion", Accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();

            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {

                if (ds.Tables.Count > 1)
                {

                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow Fila = ds.Tables[1].Rows[0];
                        respuestaBD = Fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }

                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }
                }

            }
            else
            {
                respuestaBD = "N&&";
            }

            return respuestaBD;
        }
        private string ODBC_mtdSys_AjaxLink(long idAjaxLink, string Usuario, string AjaxLink, int Accion)
        {
            return "no activa";
        }
        #endregion

        #region "Registro Usuario"
        public string mtdSys_Usuario(string idusuario, string idgrupofk, string nombres, string apellidos
            , string estatususuario, string claveacceso, int caducidadclave, string fotoperfil, string telefono
            , string email, long iddashboardfk, long tipotrabajo, string usuario, long accion)
        {
            if (mtd_OpcionBaseDeDatos())
            {
                return SQL_mtdSys_Usuario(idusuario, idgrupofk, nombres, apellidos
            , estatususuario, claveacceso, caducidadclave, fotoperfil, telefono
            , email, iddashboardfk, tipotrabajo, usuario, accion);
            }
            else
            {
                return ODBC_mtdSys_Usuario(idusuario, idgrupofk, nombres, apellidos
            , estatususuario, claveacceso, caducidadclave, fotoperfil, telefono
            , email, iddashboardfk, tipotrabajo, usuario, accion);
            }
        }
        // Procedimiento registroUsuario conexion con sqlserver
        private string SQL_mtdSys_Usuario(string idusuario, string idgrupofk, string nombres, string apellidos
            , string estatususuario, string claveacceso, int caducidadclave, string fotoperfil, string telefono
            , string email, long iddashboardfk, long tipotrabajo, string usuario, long accion)
        {
            string respuestaBD = "";

            SqlDataAdapter da = new SqlDataAdapter("Sys_SP_Usuarios", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@IdUsuario", idusuario);
            da.SelectCommand.Parameters.AddWithValue("@IdGrupoFK", idgrupofk);
            da.SelectCommand.Parameters.AddWithValue("@Nombres", nombres);
            da.SelectCommand.Parameters.AddWithValue("@Apellidos", apellidos);
            da.SelectCommand.Parameters.AddWithValue("@EstatusUsuario", estatususuario);
            da.SelectCommand.Parameters.AddWithValue("@ClaveAcceso", claveacceso);
            da.SelectCommand.Parameters.AddWithValue("@CaducidadClave", caducidadclave);
            da.SelectCommand.Parameters.AddWithValue("@FotoPerfil", fotoperfil);
            da.SelectCommand.Parameters.AddWithValue("@Telefono", telefono);
            da.SelectCommand.Parameters.AddWithValue("@Email", email);
            da.SelectCommand.Parameters.AddWithValue("@IdDashboardFK", iddashboardfk);
            da.SelectCommand.Parameters.AddWithValue("@IdTipoTrabajo", tipotrabajo);
            da.SelectCommand.Parameters.AddWithValue("@Usuario", usuario);
            da.SelectCommand.Parameters.AddWithValue("@Accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();

            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {

                if (ds.Tables.Count > 1)
                {

                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow Fila = ds.Tables[1].Rows[0];
                        respuestaBD = Fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }

                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }
                }

            }
            else
            {
                respuestaBD = "N&&";
            }

            return respuestaBD;
        }
        // Procedimiento registroUsuario conexion con sqlserver
        private string ODBC_mtdSys_Usuario(string idusuario, string idgrupofk, string nombres, string apellidos
            , string estatususuario, string claveacceso, int caducidadclave, string fotoperfil, string telefono
            , string email, long iddashboardfk, long tipotrabajo, string usuario, long accion)
        {
            return "no activa";
        }
        #endregion

        #region "Informacion Grupos"
        public string mtdSys_InformacionGrupos(string id_grupo, string descripcion, string user, long accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdSys_InformacionGrupos(id_grupo, descripcion, user, accion);
            else
                return ODBC_mtdSys_InformacionGrupos(id_grupo, descripcion, user, accion);
        }
        private string SQL_mtdSys_InformacionGrupos(string id_grupo, string descripcion, string user, long accion)
        {
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("Sys_SP_Grupos", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@Id_Grupo", id_grupo);
            da.SelectCommand.Parameters.AddWithValue("@Descripcion", descripcion);
            da.SelectCommand.Parameters.AddWithValue("@Id_UsuarioCrea_FK", user);
            da.SelectCommand.Parameters.AddWithValue("@Id_UsuarioModifica_FK", user);
            da.SelectCommand.Parameters.AddWithValue("@Accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {

                if (ds.Tables.Count > 1)
                {

                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }

                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }
                }

            }
            else
            {
                respuestaBD = "N&&";
            }

            return respuestaBD;

        }
        private string ODBC_mtdSys_InformacionGrupos(string id_grupo, string descripcion, string user, long accion)
        {
            return "no activa";
        }

        #endregion

        #region "Cerrar Sesion del Sistema"
        public string mtdSys_CerrarSesion(string idusuario, string fecha, long accion)
        {
            if (mtd_OpcionBaseDeDatos())
            {
                return SQL_mtdSys_CerrarSesion(idusuario, fecha, accion);
            }
            else
            {
                return ODBC_mtdSys_CerrarSesion(idusuario, fecha, accion);
            }
        }
        private string SQL_mtdSys_CerrarSesion(string idusuario, string fecha, long accion)
        {
            string respuestaBD = "";

            SqlDataAdapter da = new SqlDataAdapter("Sys_SP_UsuarioCierreSesion", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@IdUsuario", idusuario);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();

            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {

                if (ds.Tables.Count > 1)
                {

                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow Fila = ds.Tables[1].Rows[0];
                        respuestaBD = Fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }

                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }
                }

            }
            else
            {
                respuestaBD = "N&&";
            }

            return respuestaBD;
        }
        private string ODBC_mtdSys_CerrarSesion(string idusuario, string fecha, long accion)
        {
            return "no activa";
        }
        #endregion

        #region "Registro de Sesiones del Usuario"
        public string mtdSys_SesionesUsuarios(string idusuario, string origen, int estado, long accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdSys_SesionesUsuarios(idusuario, origen, estado, accion);
            else
                return ODBC_mtdSys_SesionesUsuarios(idusuario, origen, estado, accion);
        }
        private string SQL_mtdSys_SesionesUsuarios(string idusuario, string origen, int estado, long accion)
        {
            string respuestaBD = "";

            SqlDataAdapter da = new SqlDataAdapter("Sys_SP_UsusariosInicioSesiones", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@Usuario", idusuario);
            da.SelectCommand.Parameters.AddWithValue("@Origen", origen);
            da.SelectCommand.Parameters.AddWithValue("@Estado", estado);
            da.SelectCommand.Parameters.AddWithValue("@Accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();

            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {

                if (ds.Tables.Count > 1)
                {

                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow Fila = ds.Tables[1].Rows[0];
                        respuestaBD = Fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }

            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdSys_SesionesUsuarios(string idusuario, string origen, int estado, long accion)
        {
            return "no activa";
        }
        #endregion

        #region "Acceso Opciones"
        public string mtdSys_AccesoOpciones(string usuario, long modulo)
        {
            if (mtd_OpcionBaseDeDatos())
            {
                return SQL_mtdSys_AccesoOpciones(usuario, modulo);
            }
            else
            {
                return ODBC_mtdSys_AccesoOpciones(usuario, modulo);
            }

        }
        private string SQL_mtdSys_AccesoOpciones(string usuario, long modulo)
        {
            string respuesta = "";
            SqlDataAdapter da = new SqlDataAdapter("Sys_SP_AccesoOpciones", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@usuario", usuario);
            da.SelectCommand.Parameters.AddWithValue("@Modulo", modulo);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;
            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }
            if (dt != null)
            {

                if (ds.Tables.Count > 1)
                {

                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuesta = fila[0].ToString();
                    }
                    else
                    {
                        respuesta = "N&&";
                    }

                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuesta = fila[0].ToString();
                    }
                    else
                    {
                        respuesta = "N&&";
                    }
                }

            }
            else
            {
                respuesta = "N&&";
            }

            return respuesta;

        }

        private string ODBC_mtdSys_AccesoOpciones(string usuario, long modulo)
        {
            return "no activa";
        }
        #endregion

        #region "Acceso Modulos"
        public string mtdSys_AccesoModulos(string usuario, long aplicativo)
        {
            if (mtd_OpcionBaseDeDatos())
            {
                return SQL_mtdSys_AccesoModulos(usuario, aplicativo);
            }
            else
            {
                return ODBC_mtdSys_AccesoModulos(usuario, aplicativo);
            }

        }
        private string SQL_mtdSys_AccesoModulos(string usuario, long aplicativo)
        {
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("Sys_SP_AccesoModulos", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@usuario", usuario);
            da.SelectCommand.Parameters.AddWithValue("@Aplicativo", aplicativo);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;
            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }
            if (dt != null)
            {

                if (ds.Tables.Count > 1)
                {

                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }

                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }
                }

            }
            else
            {
                respuestaBD = "N&&";
            }

            return respuestaBD;

        }

        private string ODBC_mtdSys_AccesoModulos(string usuario, long aplicativo)
        {
            return "no activa";
        }
        #endregion

        #region "Acceso Aplicativos"
        public string mtdSys_AccesoAplicativos(string grupo)
        {
            if (mtd_OpcionBaseDeDatos())
            {
                return SQL_mtdSys_AccesoAplicativos(grupo);
            }
            else
            {
                return ODBC_mtdSys_AccesoAplicativos(grupo);
            }

        }
        private string SQL_mtdSys_AccesoAplicativos(string grupo)
        {

            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("Sys_SP_AccesoAplicativos", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@grupo", grupo);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;
            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {

                if (ds.Tables.Count > 1)
                {

                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }

                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }
                }

            }
            else
            {
                respuestaBD = "N&&";
            }

            return respuestaBD;
        }

        private string ODBC_mtdSys_AccesoAplicativos(string grupo)
        {
            return "no activa";
        }
        #endregion

        #region "Sys Configuracion APP"
        public string mtdSys_ConfiguracionApp(long id_configuracion, bool isactivo,/* string descripcion,*/  long accion)
        {
            if (mtd_OpcionBaseDeDatos())
            {
                return SQL_mtdSys_ConfiguracionApp(id_configuracion, isactivo,/* descripcion, estatus,*/ accion);
            }
            else
            {
                return ODBC_mtdSys_ConfiguracionApp(id_configuracion, isactivo,/*descripcion, estatus,*/ accion);
            }

        }
        private string SQL_mtdSys_ConfiguracionApp(long id_configuracion, bool isactivo,/* string descripcion, bool estatus, */long accion)
        {

            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("Sys_SP_ConfiguracionApp", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@Id_Configuracion", id_configuracion);
            da.SelectCommand.Parameters.AddWithValue("@IsActivo", isactivo);
            //da.SelectCommand.Parameters.AddWithValue("@Estatus", estatus);
            da.SelectCommand.Parameters.AddWithValue("@Accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;
            DataSet ds = new DataSet();
            DataTable dt = new DataTable();

            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {

                if (ds.Tables.Count > 1)
                {

                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }

                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }
                }
            }
            else
            {
                respuestaBD = "N&&";
            }

            return respuestaBD;

        }
        private string ODBC_mtdSys_ConfiguracionApp(long id_configuracion, bool isactivo,/* string descripcion, bool estatus, */long accion)
        {
            return "no activa";
        }

        #endregion

        #region "Sys Configuracion APP"
        public string mtdSys_ConfiguracionAppV2(long id, string empresa, string propietario, string nrc, string nit
            , string documento, string telefono, string actividad, long departamento, long municipio, string direccion
            , string email, string claveemail, string servidor, int puerto, string logo, string user, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
            {
                return SQL_mtdSys_ConfiguracionAppV2(id, empresa, propietario, nrc, nit
                                                    , documento, telefono, actividad, departamento, municipio, direccion
                                                    , email, claveemail, servidor, puerto, logo, user, accion);
            }
            else
            {
                return ODBC_mtdSys_ConfiguracionAppV2(id, empresa, propietario, nrc, nit
                                                    , documento, telefono, actividad, departamento, municipio, direccion
                                                    , email, claveemail, servidor, puerto, logo, user, accion);
            }

        }
        private string SQL_mtdSys_ConfiguracionAppV2(long id, string empresa, string propietario, string nrc, string nit
            , string documento, string telefono, string actividad, long departamento, long municipio, string direccion
            , string email, string claveemail, string servidor, int puerto, string logo, string user, int accion)
        {

            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("Sys_SP_ConfiguracionAppV2", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@idConfiguracion", id);
            da.SelectCommand.Parameters.AddWithValue("@nombreEmpresa", empresa);
            da.SelectCommand.Parameters.AddWithValue("@nombrePropietario", propietario);
            da.SelectCommand.Parameters.AddWithValue("@registroIVA", nrc);
            da.SelectCommand.Parameters.AddWithValue("@numeroNIT", nit);
            da.SelectCommand.Parameters.AddWithValue("@numeroDUI", documento);
            da.SelectCommand.Parameters.AddWithValue("@telefono", telefono);
            da.SelectCommand.Parameters.AddWithValue("@actividad", actividad);
            da.SelectCommand.Parameters.AddWithValue("@departamento", departamento);
            da.SelectCommand.Parameters.AddWithValue("@municipio", municipio);
            da.SelectCommand.Parameters.AddWithValue("@direccion", direccion);
            da.SelectCommand.Parameters.AddWithValue("@correo", email);
            da.SelectCommand.Parameters.AddWithValue("@clave", claveemail);
            da.SelectCommand.Parameters.AddWithValue("@servidor", servidor);
            da.SelectCommand.Parameters.AddWithValue("@puerto", puerto);
            da.SelectCommand.Parameters.AddWithValue("@logo", logo);
            da.SelectCommand.Parameters.AddWithValue("@usuario", user);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;
            DataSet ds = new DataSet();
            DataTable dt = new DataTable();

            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {

                if (ds.Tables.Count > 1)
                {

                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }

                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }
                }
            }
            else
            {
                respuestaBD = "N&&";
            }

            return respuestaBD;

        }
        private string ODBC_mtdSys_ConfiguracionAppV2(long id, string empresa, string propietario, string nrc, string nit
            , string documento, string telefono, string actividad, long departamento, long municipio, string direccion
            , string email, string claveemail, string servidor, int puerto, string logo, string user, int accion)
        {
            return "no activa";
        }

        #endregion

        #region "Registro Usuario"
        public string mtdSys_Usuario(string idusuario, string idgrupofk, string nombres, string apellidos, string estatususuario, string claveacceso
            , int caducidadclave, string fotoperfil, string telefono, string celular, string email, long iddashboardfk, string usuario, bool responsable, long accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdSys_Usuario(idusuario, idgrupofk, nombres, apellidos, estatususuario, claveacceso, caducidadclave
                    , fotoperfil, telefono, celular, email, iddashboardfk, usuario, responsable, accion);
            else
                return ODBC_mtdSys_Usuario(idusuario, idgrupofk, nombres, apellidos, estatususuario, claveacceso, caducidadclave
                    , fotoperfil, telefono, celular, email, iddashboardfk, usuario, responsable, accion);
        }
        // Procedimiento registroUsuario conexion con sqlserver
        private string SQL_mtdSys_Usuario(string idusuario, string idgrupofk, string nombres, string apellidos, string estatususuario, string claveacceso
            , int caducidadclave, string fotoperfil, string telefono, string celular, string email, long iddashboardfk, string usuario, bool responsable, long accion)
        {
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("Sys_SP_Usuarios", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@IdUsuario", idusuario);
            da.SelectCommand.Parameters.AddWithValue("@IdGrupoFK", idgrupofk);
            da.SelectCommand.Parameters.AddWithValue("@Nombres", nombres);
            da.SelectCommand.Parameters.AddWithValue("@Apellidos", apellidos);
            da.SelectCommand.Parameters.AddWithValue("@EstatusUsuario", estatususuario);
            da.SelectCommand.Parameters.AddWithValue("@ClaveAcceso", claveacceso);
            da.SelectCommand.Parameters.AddWithValue("@CaducidadClave", caducidadclave);
            da.SelectCommand.Parameters.AddWithValue("@FotoPerfil", fotoperfil);
            da.SelectCommand.Parameters.AddWithValue("@Telefono", telefono);
            da.SelectCommand.Parameters.AddWithValue("@Celular", celular);
            da.SelectCommand.Parameters.AddWithValue("@Email", email);
            da.SelectCommand.Parameters.AddWithValue("@IdDashboardFK", iddashboardfk);
            da.SelectCommand.Parameters.AddWithValue("@Usuario", usuario);
            da.SelectCommand.Parameters.AddWithValue("@Responsable", responsable);
            da.SelectCommand.Parameters.AddWithValue("@Accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();

            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow Fila = ds.Tables[1].Rows[0];
                        respuestaBD = Fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        // Procedimiento registroUsuario conexion con sqlserver
        private string ODBC_mtdSys_Usuario(string idusuario, string idgrupofk, string nombres, string apellidos, string estatususuario, string claveacceso
            , int caducidadclave, string fotoperfil, string telefono, string celular, string email, long iddashboardfk, string usuario, bool responsable, long accion)
        {
            return "no activa";
        }
        #endregion

        #region "Cambio de Contraseña"
        public string mtdSys_ChangePass(string user, string newpass, string accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdSys_ChangePass(user, newpass, accion);
            else
                return ODBC_mtdSys_ChangePass(user, newpass, accion);
        }
        private string SQL_mtdSys_ChangePass(string user, string newpass, string accion)
        {
            //string u = GetUsuarioSesion();
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("Sys_SP_CambioContrasena", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@user", user);
            da.SelectCommand.Parameters.AddWithValue("@newpass", newpass);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {

                if (ds.Tables.Count > 1)
                {

                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }

                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }
                }

            }
            else
            {
                respuestaBD = "N&&";
            }

            return respuestaBD;
        }
        private string ODBC_mtdSys_ChangePass(string user, string newpass, string accion)
        {
            return "no activa";
        }

        #endregion


        #region "Modulos"
        public string mtdSys_Modulos(long id_modulo, string descripcion, string icono, long idaplicativo_fk, string id_usuariocrea_fk, string id_usuariomodifica_fk, long orden, long accion)
        {
            if (mtd_OpcionBaseDeDatos())
            {
                return SQL_mtdSys_Modulos(id_modulo, descripcion, icono, idaplicativo_fk, id_usuariocrea_fk, id_usuariomodifica_fk, orden, accion);
            }
            else
            {
                return ODBC_mtdSys_Modulos(id_modulo, descripcion, icono, idaplicativo_fk, id_usuariocrea_fk, id_usuariomodifica_fk, orden, accion);
            }

        }
        private string SQL_mtdSys_Modulos(long id_modulo, string descripcion, string icono, long idaplicativo_fk, string id_usuariocrea_fk, string id_usuariomodifica_fk, long orden, long accion)
        {
            //string u = GetUsuarioSesion();
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("Sys_SP_Modulos", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@Id_Modulo", id_modulo);
            da.SelectCommand.Parameters.AddWithValue("@Descripcion", descripcion);
            da.SelectCommand.Parameters.AddWithValue("@Icono", icono);
            da.SelectCommand.Parameters.AddWithValue("@IdAplicativo_FK", idaplicativo_fk);
            da.SelectCommand.Parameters.AddWithValue("@Id_UsuarioCrea_FK", id_usuariocrea_fk);
            da.SelectCommand.Parameters.AddWithValue("@Id_UsuarioModifica_FK", id_usuariomodifica_fk);
            da.SelectCommand.Parameters.AddWithValue("@Orden", orden);
            da.SelectCommand.Parameters.AddWithValue("@Accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {

                if (ds.Tables.Count > 1)
                {

                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }

                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }
                }

            }
            else
            {
                respuestaBD = "N&&";
            }

            return respuestaBD;
        }
        private string ODBC_mtdSys_Modulos(long id_modulo, string descripcion, string icono, long idaplicativo_fk, string id_usuariocrea_fk, string id_usuariomodifica_fk, long orden, long accion)
        {
            return "no activa";
        }

        #endregion

        #region "Opciones"
        public string mtdSys_Opciones(long id_opcion, string descripcion, string abreviado, string accesoURL, long idmodulo_fk, string user, long orden, long accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdSys_Opciones(id_opcion, descripcion, abreviado, accesoURL, idmodulo_fk, user, orden, accion);
            else
                return ODBC_mtdSys_Opciones(id_opcion, descripcion, abreviado, accesoURL, idmodulo_fk, user, orden, accion);

        }
        private string SQL_mtdSys_Opciones(long id_opcion, string descripcion, string abreviado, string accesoURL, long idmodulo_fk, string user, long orden, long accion)
        {
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("Sys_SP_Opciones", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@Id_Opcion", id_opcion);
            da.SelectCommand.Parameters.AddWithValue("@Descripcion", descripcion);
            da.SelectCommand.Parameters.AddWithValue("@Abreviado", abreviado);
            da.SelectCommand.Parameters.AddWithValue("@AccesoURL", accesoURL);
            da.SelectCommand.Parameters.AddWithValue("@IdModulo_FK", idmodulo_fk);
            da.SelectCommand.Parameters.AddWithValue("@Id_UsuarioCrea_FK", user);
            da.SelectCommand.Parameters.AddWithValue("@Id_UsuarioModifica_FK", user);
            da.SelectCommand.Parameters.AddWithValue("@Orden", orden);
            da.SelectCommand.Parameters.AddWithValue("@Accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {

                if (ds.Tables.Count > 1)
                {

                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }

                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }
                }

            }
            else
            {
                respuestaBD = "N&&";
            }

            return respuestaBD;
        }
        private string ODBC_mtdSys_Opciones(long id_opcion, string descripcion, string abreviado, string accesoURL, long idmodulo_fk, string user, long orden, long accion)
        {
            return "no activa";
        }

        #endregion

        #region "Aplicativos"
        public string mtdSys_Aplicativos(long id_aplicativo, string descripcion, string icono, string accesourl, string user, long orden, long accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdSys_Aplicativos(id_aplicativo, descripcion, icono, accesourl, user, orden, accion);
            else
                return ODBC_mtdSys_Aplicativos(id_aplicativo, descripcion, icono, accesourl, user, orden, accion);
        }


        private string SQL_mtdSys_Aplicativos(long id_aplicativo, string descripcion, string icono, string accesourl, string user, long orden, long accion)
        {

            string respuestaBD = "";

            SqlDataAdapter da = new SqlDataAdapter("Sys_SP_Aplicativos", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@Id_Aplicativo", id_aplicativo);
            da.SelectCommand.Parameters.AddWithValue("@Descripcion", descripcion);
            da.SelectCommand.Parameters.AddWithValue("@Icono", icono);
            da.SelectCommand.Parameters.AddWithValue("@AccesoURL", accesourl);
            da.SelectCommand.Parameters.AddWithValue("@Id_UsuarioCrea_FK", user);
            da.SelectCommand.Parameters.AddWithValue("@Id_UsuarioModifica_FK", user);
            da.SelectCommand.Parameters.AddWithValue("@Orden", orden);
            da.SelectCommand.Parameters.AddWithValue("@Accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();

            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {

                if (ds.Tables.Count > 1)
                {

                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }

                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }
                }

            }
            else
            {
                respuestaBD = "N&&";
            }

            return respuestaBD;
        }
        private string ODBC_mtdSys_Aplicativos(long id_aplicativo, string descripcion, string icono, string accesourl, string user, long orden, long accion)
        {
            return "no activa";
        }

        #endregion

        #region "Permisos"
        public string mtdSys_Permisos(long id_permiso, long idaplicativo_fk, long idmodulo_fk, long idopcion_fk, string idgrupo_fk, string user, long accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdSys_Permisos(id_permiso, idaplicativo_fk, idmodulo_fk, idopcion_fk, idgrupo_fk, user, accion);
            else
                return ODBC_mtdSys_Permisos(id_permiso, idaplicativo_fk, idmodulo_fk, idopcion_fk, idgrupo_fk, user, accion);
        }
        private string SQL_mtdSys_Permisos(long id_permiso, long idaplicativo_fk, long idmodulo_fk, long idopcion_fk, string idgrupo_fk, string user, long accion)
        {
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("Sys_SP_Permisos", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@Id_Permiso", id_permiso);
            da.SelectCommand.Parameters.AddWithValue("@IdAplicativo_FK", idaplicativo_fk);
            da.SelectCommand.Parameters.AddWithValue("@IdModulo_FK", idmodulo_fk);
            da.SelectCommand.Parameters.AddWithValue("@IdOpcion_FK", idopcion_fk);
            da.SelectCommand.Parameters.AddWithValue("@IdGrupo_FK", idgrupo_fk);
            da.SelectCommand.Parameters.AddWithValue("@Id_UsuarioCrea_FK", user);
            da.SelectCommand.Parameters.AddWithValue("@Id_UsuarioModifica_FK", user);
            da.SelectCommand.Parameters.AddWithValue("@Accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {

                if (ds.Tables.Count > 1)
                {

                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }

                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }
                }

            }
            else
            {
                respuestaBD = "N&&";
            }

            return respuestaBD;

        }
        private string ODBC_mtdSys_Permisos(long id_permiso, long idaplicativo_fk, long idmodulo_fk, long idopcion_fk, string idgrupo_fk, string user, long accion)
        {
            return "no activa";
        }

        #endregion

        #region "AccesoObjetos"
        public string mtdSys_AccesoObjetos(string idgrupo_fk)
        {
            if (mtd_OpcionBaseDeDatos())
            {
                return SQL_mtdSys_AccesoObjetos(idgrupo_fk);
            }
            else
            {
                return ODBC_mtdSys_AccesoObjetos(idgrupo_fk);
            }

        }
        private string SQL_mtdSys_AccesoObjetos(string idgrupo_fk)
        {

            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("Sys_SP_AccesoObjetos", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@grupo", idgrupo_fk);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {

                if (ds.Tables.Count > 1)
                {

                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }

                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }
                }

            }
            else
            {
                respuestaBD = "N&&";
            }

            return respuestaBD;

        }
        private string ODBC_mtdSys_AccesoObjetos(string idgrupo_fk)
        {
            return "no activa";
        }

        #endregion

        #region "Log Errores"
        protected string mtd_GetIPAddress()
        {
            System.Web.HttpContext context = System.Web.HttpContext.Current;
            string ipAddress = context.Request.ServerVariables["HTTP_X_FORWARDED_FOR"];

            if (!string.IsNullOrEmpty(ipAddress))
            {
                string[] addresses = ipAddress.Split(',');
                if (addresses.Length != 0)
                {
                    return addresses[0];
                }
            }

            return context.Request.ServerVariables["REMOTE_ADDR"];
        }

        public string mtdSys_LogErrores(long id_usuario, string funcion, string usuarioid, string exception)
        {
            if (mtd_OpcionBaseDeDatos())
            {
                return SQL_mtdSys_LogErrores(id_usuario, funcion, usuarioid, exception);
            }
            else
            {
                return ODBC_mtdSys_LogErrores(id_usuario, funcion, usuarioid, exception);
            }

        }
        private string SQL_mtdSys_LogErrores(long id_usuario, string funcion, string usuarioid, string exception)
        {
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("Sys_SP_SaveLogException", mtd_ExtraeConexion());
            string ip = mtd_GetIPAddress();
            System.Web.HttpContext context = System.Web.HttpContext.Current;
            string hostname = context.Request.ServerVariables["REMOTE_HOST"].ToString();

            da.SelectCommand.Parameters.AddWithValue("@User", id_usuario);
            da.SelectCommand.Parameters.AddWithValue("@Function", funcion);
            da.SelectCommand.Parameters.AddWithValue("@NombreEquipo", hostname);
            da.SelectCommand.Parameters.AddWithValue("@Exception", exception);
            da.SelectCommand.Parameters.AddWithValue("@IpAddress", ip);
            da.SelectCommand.Parameters.AddWithValue("@UsuarioID", usuarioid);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;
            DataSet ds = new DataSet();
            DataTable dt = new DataTable();

            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return e.Message;
            }

            if (dt != null)
            {

                if (ds.Tables.Count > 1)
                {

                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }

                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }
                }
            }
            else
            {
                respuestaBD = "N&&";
            }

            return respuestaBD;

        }
        private string ODBC_mtdSys_LogErrores(long id_usuario, string funcion, string exception, string usuarioid)
        {
            return "no activa";
        }
        #endregion

        #region "LogAccess 1"
        public string mtdSys_LogAccess(string sessionid, string browser, string os, string ip_server, string ip_cliente, string estado)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdSys_LogAccess(sessionid, browser, os, ip_server, ip_cliente, estado);
            else
                return ODBC_mtdSys_LogAccess(sessionid, browser, os, ip_server, ip_cliente, estado);
        }
        public string mtd_GetIPAddress1()
        {
            IPHostEntry ipHostInfo = Dns.GetHostEntry(Dns.GetHostName()); // `Dns.Resolve()` method is deprecated.
            IPAddress ipAddress = ipHostInfo.AddressList[0];

            return ipAddress.ToString();
        }

        public string mtd_InformacionBrowser()
        {
            string browserDetails = string.Empty;
            HttpBrowserCapabilities browser = System.Web.HttpContext.Current.Request.Browser;
            browserDetails =
                    "Name = " + browser.Browser + "," +
                    "Type = " + browser.Type + ","
                    + "Version = " + browser.Version + ","
                    + "Major Version = " + browser.MajorVersion + ","
                    + "Minor Version = " + browser.MinorVersion + ","
                    + "Platform = " + browser.Platform + ","
                    + "Is Beta = " + browser.Beta + ","
                    + "Is Crawler = " + browser.Crawler + ","
                    + "Is AOL = " + browser.AOL + ","
                    + "Is Win16 = " + browser.Win16 + ","
                    + "Is Win32 = " + browser.Win32 + ","
                    + "Supports Frames = " + browser.Frames + ","
                    + "Supports Tables = " + browser.Tables + ","
                    + "Supports Cookies = " + browser.Cookies + ","
                    + "Supports VBScript = " + browser.VBScript + ","
                    + "Supports JavaScript = " + "," +
                    browser.EcmaScriptVersion.ToString() + ","
                    + "Supports Java Applets = " + browser.JavaApplets + ","
                    + "Supports ActiveX Controls = " + browser.ActiveXControls
                    + ","
                    + "Supports JavaScript Version = " + browser["JavaScriptVersion"];
            return browserDetails;
        }


        private string SQL_mtdSys_LogAccess(string sessionid, string browser, string os, string ip_server, string ip_cliente, string estado)
        {
            //string ip = HttpContext.Current.Request.UserHostAddress;
            string ip = mtd_GetIPAddress();
            string ipserver = mtd_GetIPAddress1();
            string respuestaBD = "";
            string browsers = mtd_InformacionBrowser().ToString();
            SqlDataAdapter da = new SqlDataAdapter("Sys_SP_SaveLogAccess", mtd_ExtraeConexion());
            string OS = "";
            try
            {
                OS = System.Web.HttpContext.Current.Request.UserAgent.ToLower();
            }
            catch (Exception e)
            {

            }
            string session = "No existe";
            try
            {
                session = System.Web.HttpContext.Current.Session.SessionID;
            }
            catch (Exception e)
            {

            }
            da.SelectCommand.Parameters.AddWithValue("@SessionID", session);
            da.SelectCommand.Parameters.AddWithValue("@Browser", browsers);
            da.SelectCommand.Parameters.AddWithValue("@OS", os);
            da.SelectCommand.Parameters.AddWithValue("@IP_Server", ipserver);
            da.SelectCommand.Parameters.AddWithValue("@IP_Cliente", ip);
            da.SelectCommand.Parameters.AddWithValue("@Estado", estado);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;
            DataSet ds = new DataSet();
            DataTable dt = new DataTable();

            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return e.Message;
            }

            if (dt != null)
            {

                if (ds.Tables.Count > 1)
                {

                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }

                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }
                }
            }
            else
            {
                respuestaBD = "N&&";
            }

            return respuestaBD;

        }
        private string ODBC_mtdSys_LogAccess(string sessionid, string browser, string os, string ip_server, string ip_cliente, string estado)
        {
            return "no activa";
        }

        #endregion

        #region "Informacion DashboardInicial"
        public string mtdSys_DashboardInicial(long id_dashboard, string descripcion, string dashboardurl, string estatus, string user, long accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdSys_DashboardInicial(id_dashboard, descripcion, dashboardurl, estatus, user, accion);
            else
                return ODBC_mtdSys_DashboardInicial(id_dashboard, descripcion, dashboardurl, estatus, user, accion);
        }
        private string SQL_mtdSys_DashboardInicial(long id_dashboard, string descripcion, string dashboardurl, string estatus, string user, long accion)
        {
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("Sys_SP_DashboardInicial", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@Id_Dashboard", id_dashboard);
            da.SelectCommand.Parameters.AddWithValue("@Descripcion", descripcion);
            da.SelectCommand.Parameters.AddWithValue("@DashboardUrl", dashboardurl);
            da.SelectCommand.Parameters.AddWithValue("@Estatus", estatus);
            da.SelectCommand.Parameters.AddWithValue("@Id_UsuarioCrea_FK", user);
            da.SelectCommand.Parameters.AddWithValue("@Id_UsuarioModifica_FK", user);
            da.SelectCommand.Parameters.AddWithValue("@Accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {

                if (ds.Tables.Count > 1)
                {

                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }

                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }
                }

            }
            else
            {
                respuestaBD = "N&&";
            }

            return respuestaBD;
        }

        private string ODBC_mtdSys_DashboardInicial(long id_dashboard, string descripcion, string dashboardurl, string estatus, string user, long accion)
        {
            return "no activa";
        }

        #endregion

        #region "Informacion Agencia"
        public string mtdSys_InformacionAgencia(long id_agencia, string descripcion, string estatus, string user, long accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdSys_InformacionAgencia(id_agencia, descripcion, estatus, user, accion);
            else
                return ODBC_mtdSys_InformacionAgencia(id_agencia, descripcion, estatus, user, accion);
        }
        private string SQL_mtdSys_InformacionAgencia(long id_agencia, string descripcion, string estatus, string user, long accion)
        {
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("Sys_SP_Agencias", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@Id_Agencia", id_agencia);
            da.SelectCommand.Parameters.AddWithValue("@Descripcion", descripcion);
            da.SelectCommand.Parameters.AddWithValue("@Estatus", estatus);
            da.SelectCommand.Parameters.AddWithValue("@Id_UsuarioCrea_FK", user);
            da.SelectCommand.Parameters.AddWithValue("@Id_UsuarioModifica_FK", user);
            da.SelectCommand.Parameters.AddWithValue("@Accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {

                if (ds.Tables.Count > 1)
                {

                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }

                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }
                }

            }
            else
            {
                respuestaBD = "N&&";
            }

            return respuestaBD;
        }
        private string ODBC_mtdSys_InformacionAgencia(long id_agencia, string descripcion, string estatus, string user, long accion)
        {
            return "no activa";
        }

        #endregion

        #region "Tipos de Trabajo"
        public string mtdSys_TiposTrabajos(long id, string descripcion, string estado, string usuario, long accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdSys_TiposTrabajos(id, descripcion, estado, usuario, accion);
            else
                return ODBC_mtdSys_TiposTrabajos(id, descripcion, estado, usuario, accion);
        }
        private string SQL_mtdSys_TiposTrabajos(long id, string descripcion, string estado, string usuario, long accion)
        {
            //string u = mtd_GetUsuarioSesion();;
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("Sys_SP_TiposTrabajos", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@IdTipoTrabajo", id);
            da.SelectCommand.Parameters.AddWithValue("@Descripcion", descripcion);
            da.SelectCommand.Parameters.AddWithValue("@Estatus", estado);
            da.SelectCommand.Parameters.AddWithValue("@Usuario", usuario);
            da.SelectCommand.Parameters.AddWithValue("@Accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {

                if (ds.Tables.Count > 1)
                {

                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }

                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }
                }

            }
            else
            {
                respuestaBD = "N&&";
            }

            return respuestaBD;
        }
        private string ODBC_mtdSys_TiposTrabajos(long id, string descripcion, string estado, string usuario, long accion)
        {
            return "no activa";
        }

        #endregion

        #region "Catalogo Departamentos"
        public string mtdCAT_Departamentos(long id, string descripcion, string estado, string usuario, long accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdCAT_Departamentos(id, descripcion, estado, usuario, accion);
            else
                return ODBC_mtdCAT_Departamentos(id, descripcion, estado, usuario, accion);
        }
        private string SQL_mtdCAT_Departamentos(long id, string descripcion, string estado, string usuario, long accion)
        {
            //string u = mtd_GetUsuarioSesion();;
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("CAT_SP_Departamentos", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@id", id);
            da.SelectCommand.Parameters.AddWithValue("@descripcion", descripcion);
            da.SelectCommand.Parameters.AddWithValue("@estado", estado);
            da.SelectCommand.Parameters.AddWithValue("@usuario", usuario);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdCAT_Departamentos(long id, string descripcion, string estado, string usuario, long accion)
        {
            return "no activa";
        }

        #endregion

        #region "Catalogo Municipios"
        public string mtdCAT_Municipios(long id, string descripcion, string departamento, string usuario, long accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdCAT_Municipios(id, descripcion, departamento, usuario, accion);
            else
                return ODBC_mtdCAT_Municipios(id, descripcion, departamento, usuario, accion);
        }
        private string SQL_mtdCAT_Municipios(long id, string descripcion, string departamento, string usuario, long accion)
        {
            //string u = mtd_GetUsuarioSesion();;
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("CAT_SP_Municipios", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@id", id);
            da.SelectCommand.Parameters.AddWithValue("@descripcion", descripcion);
            da.SelectCommand.Parameters.AddWithValue("@departamento", departamento);
            da.SelectCommand.Parameters.AddWithValue("@usuario", usuario);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdCAT_Municipios(long id, string descripcion, string departamento, string usuario, long accion)
        {
            return "no activa";
        }

        #endregion

        #region "Catalogo Sexos"
        public string mtdCAT_Sexos(long id, string descripcion, string estado, string usuario, long accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdCAT_Sexos(id, descripcion, estado, usuario, accion);
            else
                return ODBC_mtdCAT_Sexos(id, descripcion, estado, usuario, accion);
        }
        private string SQL_mtdCAT_Sexos(long id, string descripcion, string estado, string usuario, long accion)
        {
            //string u = mtd_GetUsuarioSesion();;
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("CAT_SP_Sexos", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@id", id);
            da.SelectCommand.Parameters.AddWithValue("@descripcion", descripcion);
            da.SelectCommand.Parameters.AddWithValue("@activo", estado);
            da.SelectCommand.Parameters.AddWithValue("@usuario", usuario);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdCAT_Sexos(long id, string descripcion, string estado, string usuario, long accion)
        {
            return "no activa";
        }

        #endregion

        #region "Catalogo Especialistas"
        public string mtdCAT_Especialistas(long id, string descripcion, string estado, string usuario, long accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdCAT_Especialistas(id, descripcion, estado, usuario, accion);
            else
                return ODBC_mtdCAT_Especialistas(id, descripcion, estado, usuario, accion);
        }
        private string SQL_mtdCAT_Especialistas(long id, string descripcion, string estado, string usuario, long accion)
        {
            //string u = mtd_GetUsuarioSesion();;
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("CAT_SP_Especialistas", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@id", id);
            da.SelectCommand.Parameters.AddWithValue("@descripcion", descripcion);
            da.SelectCommand.Parameters.AddWithValue("@activo", estado);
            da.SelectCommand.Parameters.AddWithValue("@usuario", usuario);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdCAT_Especialistas(long id, string descripcion, string estado, string usuario, long accion)
        {
            return "no activa";
        }

        #endregion

        #region "Catalogo Estados Citas"
        public string mtdCAT_EstadosCitas(long id, string descripcion, string estado, string color, int action
            , int proceso, int cancelada, int finalizada, string usuario, long accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdCAT_EstadosCitas(id, descripcion, estado, color, action, proceso, cancelada, finalizada, usuario, accion);
            else
                return ODBC_mtdCAT_EstadosCitas(id, descripcion, estado, color, action, proceso, cancelada, finalizada, usuario, accion);
        }
        private string SQL_mtdCAT_EstadosCitas(long id, string descripcion, string estado, string color, int action
            , int proceso, int cancelada, int finalizada, string usuario, long accion)
        {
            //string u = mtd_GetUsuarioSesion();;
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("CAT_SP_EstadosCitas", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@id", id);
            da.SelectCommand.Parameters.AddWithValue("@descripcion", descripcion);
            da.SelectCommand.Parameters.AddWithValue("@activo", estado);
            da.SelectCommand.Parameters.AddWithValue("@color", color);
            da.SelectCommand.Parameters.AddWithValue("@action", action);
            da.SelectCommand.Parameters.AddWithValue("@proceso", proceso);
            da.SelectCommand.Parameters.AddWithValue("@cancelada", cancelada);
            da.SelectCommand.Parameters.AddWithValue("@finalizada", finalizada);
            da.SelectCommand.Parameters.AddWithValue("@usuario", usuario);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdCAT_EstadosCitas(long id, string descripcion, string estado, string color, int action
            , int proceso, int cancelada, int finalizada, string usuario, long accion)
        {
            return "no activa";
        }

        #endregion

        #region "Catalogo Horarios"
        public string mtdCAT_Horarios(long id, string descripcion, string estado, string usuario, long accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdCAT_Horarios(id, descripcion, estado, usuario, accion);
            else
                return ODBC_mtdCAT_Horarios(id, descripcion, estado, usuario, accion);
        }
        private string SQL_mtdCAT_Horarios(long id, string descripcion, string estado, string usuario, long accion)
        {
            //string u = mtd_GetUsuarioSesion();;
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("CAT_SP_Horarios", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@id", id);
            da.SelectCommand.Parameters.AddWithValue("@descripcion", descripcion);
            da.SelectCommand.Parameters.AddWithValue("@activo", estado);
            da.SelectCommand.Parameters.AddWithValue("@usuario", usuario);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdCAT_Horarios(long id, string descripcion, string estado, string usuario, long accion)
        {
            return "no activa";
        }

        #endregion

        #region "Catalogo Tipos de Facturas"
        public string mtdCAT_TiposFacturas(long id, string codigo, string descripcion, string estado, string usuario, long accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdCAT_TiposFacturas(id, codigo, descripcion, estado, usuario, accion);
            else
                return ODBC_mtdCAT_TiposFacturas(id, codigo, descripcion, estado, usuario, accion);
        }
        private string SQL_mtdCAT_TiposFacturas(long id, string codigo, string descripcion, string estado, string usuario, long accion)
        {
            //string u = mtd_GetUsuarioSesion();;
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("CAT_SP_TIPOSFACTURAS", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@id", id);
            da.SelectCommand.Parameters.AddWithValue("@codigo", codigo);
            da.SelectCommand.Parameters.AddWithValue("@descripcion", descripcion);
            da.SelectCommand.Parameters.AddWithValue("@estatus", estado);
            da.SelectCommand.Parameters.AddWithValue("@usuario", usuario);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdCAT_TiposFacturas(long id, string codigo, string descripcion, string estado, string usuario, long accion)
        {
            return "no activa";
        }

        #endregion

        #region "Catalogo Tratamientos"
        public string mtdCAT_Tratamientos(long id, string descripcion, string duracion, string precio, string estado, string caracteristica, string imagen, string usuario, long accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdCAT_Tratamientos(id, descripcion, duracion, precio, estado, caracteristica, imagen, usuario, accion);
            else
                return ODBC_mtdCAT_Tratamientos(id, descripcion, duracion, precio, estado, caracteristica, imagen, usuario, accion);
        }
        private string SQL_mtdCAT_Tratamientos(long id, string descripcion, string duracion, string precio, string estado, string caracteristica, string imagen, string usuario, long accion)
        {
            //string u = mtd_GetUsuarioSesion();;
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_SP_ListaTratamientosAgenda", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@id", id);
            da.SelectCommand.Parameters.AddWithValue("@descripcion", descripcion);
            da.SelectCommand.Parameters.AddWithValue("@duracion", duracion);
            da.SelectCommand.Parameters.AddWithValue("@precio", precio);
            da.SelectCommand.Parameters.AddWithValue("@activo", estado);
            da.SelectCommand.Parameters.AddWithValue("@caracteristica", caracteristica);
            da.SelectCommand.Parameters.AddWithValue("@imagen", imagen);
            da.SelectCommand.Parameters.AddWithValue("@user", usuario);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdCAT_Tratamientos(long id, string descripcion, string duracion, string precio, string estado, string caracteristica, string imagen, string usuario, long accion)
        {
            return "no activa";
        }

        #endregion

        #region "Catalogo Tipos de Documentos"
        public string mtdCAT_TiposDocumentos(long id, string descripcion, string estado, string usuario, long accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdCAT_TiposDocumentos(id, descripcion, estado, usuario, accion);
            else
                return ODBC_mtdCAT_TiposDocumentos(id, descripcion, estado, usuario, accion);
        }
        private string SQL_mtdCAT_TiposDocumentos(long id, string descripcion, string estado, string usuario, long accion)
        {
            //string u = mtd_GetUsuarioSesion();;
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("CAT_SP_TIPOSDOCUMENTOS", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@id", id);
            da.SelectCommand.Parameters.AddWithValue("@descripcion", descripcion);
            da.SelectCommand.Parameters.AddWithValue("@estatus", estado);
            da.SelectCommand.Parameters.AddWithValue("@user", usuario);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdCAT_TiposDocumentos(long id, string descripcion, string estado, string usuario, long accion)
        {
            return "no activa";
        }

        #endregion

        #region "Registro -- Expedientes"
        public string mtdREG_Expedientes(long id, string nombres, string apellidos, string tipodoc
            , string documento, string registro, string nacimiento, string telefono
            , string celular, string email, string teleemergencia, string contacemergencia
            , long municipio, string direccion, long sexo, int facebook, int instagram, int buscador, int recomendado
            , string user, long accion, int tiktok = 0, int whatsapp = 0, int otros = 0, int pais = 0, int paisTelefono = 0)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdREG_Expedientes(id, nombres, apellidos, tipodoc, documento, registro, nacimiento, telefono
            , celular, email, teleemergencia, contacemergencia, municipio, direccion, sexo, facebook, instagram, buscador, recomendado
            , user, accion, tiktok, whatsapp, otros, pais, paisTelefono);
            else
                return ODBC_mtdREG_Expedientes(id, nombres, apellidos, tipodoc, documento, registro, nacimiento, telefono
            , celular, email, teleemergencia, contacemergencia, municipio, direccion, sexo, facebook, instagram, buscador, recomendado
            , user, accion);
        }
        private string SQL_mtdREG_Expedientes(long id, string nombres, string apellidos, string tipodoc
            , string documento, string registro, string nacimiento, string telefono
            , string celular, string email, string teleemergencia, string contacemergencia
            , long municipio, string direccion, long sexo, int facebook, int instagram, int buscador, int recomendado
            , string user, long accion, int tiktok, int whatsapp, int otros, int pais, int paisTelefono)
        {
            //string u = mtd_GetUsuarioSesion();;
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_SP_Expedientes", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@id", id);
            da.SelectCommand.Parameters.AddWithValue("@documento", documento);
            da.SelectCommand.Parameters.AddWithValue("@nombres", nombres);
            da.SelectCommand.Parameters.AddWithValue("@apellidos", apellidos);
            da.SelectCommand.Parameters.AddWithValue("@nacimiento", nacimiento);
            da.SelectCommand.Parameters.AddWithValue("@telefono", telefono);
            da.SelectCommand.Parameters.AddWithValue("@celular", celular);
            da.SelectCommand.Parameters.AddWithValue("@email", email);
            da.SelectCommand.Parameters.AddWithValue("@emergencia", contacemergencia);
            da.SelectCommand.Parameters.AddWithValue("@telefonoemer", teleemergencia);
            da.SelectCommand.Parameters.AddWithValue("@municipio", municipio);
            da.SelectCommand.Parameters.AddWithValue("@direccion", direccion);
            da.SelectCommand.Parameters.AddWithValue("@sexo", sexo);
            da.SelectCommand.Parameters.AddWithValue("@tipodoc", tipodoc);
            da.SelectCommand.Parameters.AddWithValue("@registro", registro);
            da.SelectCommand.Parameters.AddWithValue("@facebook", facebook);
            da.SelectCommand.Parameters.AddWithValue("@instagram", instagram);
            da.SelectCommand.Parameters.AddWithValue("@buscador", buscador);
            da.SelectCommand.Parameters.AddWithValue("@recomendado", recomendado);
            da.SelectCommand.Parameters.AddWithValue("@tiktok", tiktok);
            da.SelectCommand.Parameters.AddWithValue("@whatsapp", whatsapp);
            da.SelectCommand.Parameters.AddWithValue("@otros", otros);
            da.SelectCommand.Parameters.AddWithValue("@pais", pais);
            da.SelectCommand.Parameters.AddWithValue("@paisTelefono", paisTelefono);
            da.SelectCommand.Parameters.AddWithValue("@usuario", user);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdREG_Expedientes(long id, string nombres, string apellidos, string tipodoc
            , string documento, string registro, string nacimiento, string telefono
            , string celular, string email, string teleemergencia, string contacemergencia
            , long municipio, string direccion, long sexo, int facebook, int instagram, int buscador, int recomendado
            , string user, long accion)
        {
            return "no activa";
        }

        #endregion

        #region "Catalogo Tipos de Citas"
        public string mtdCAT_TiposCitas(long id, string descripcion, string estado, string usuario, long accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdCAT_TiposCitas(id, descripcion, estado, usuario, accion);
            else
                return ODBC_mtdCAT_TiposCitas(id, descripcion, estado, usuario, accion);
        }
        private string SQL_mtdCAT_TiposCitas(long id, string descripcion, string estado, string usuario, long accion)
        {
            //string u = mtd_GetUsuarioSesion();;
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("CAT_SP_TiposCitas", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@id", id);
            da.SelectCommand.Parameters.AddWithValue("@descripcion", descripcion);
            da.SelectCommand.Parameters.AddWithValue("@activo", estado);
            da.SelectCommand.Parameters.AddWithValue("@usuario", usuario);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdCAT_TiposCitas(long id, string descripcion, string estado, string usuario, long accion)
        {
            return "no activa";
        }

        #endregion

        #region "System Auto Registro Usuario"
        public string mtdSYS_AutoRegistroUsuario(string user, string nombres, string apellidos, string telefono, string email, string clave, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdSYS_AutoRegistroUsuario(user, nombres, apellidos, telefono, email, clave, accion);
            else
                return ODBC_mtdSYS_AutoRegistroUsuario(user, nombres, apellidos, telefono, email, clave, accion);
        }
        private string SQL_mtdSYS_AutoRegistroUsuario(string user, string nombres, string apellidos, string telefono, string email, string clave, int accion)
        {
            //string u = mtd_GetUsuarioSesion();;
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("Sys_SP_RegisterUsuarios", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@usuario", user);
            da.SelectCommand.Parameters.AddWithValue("@nombres", nombres);
            da.SelectCommand.Parameters.AddWithValue("@apellidos", apellidos);
            da.SelectCommand.Parameters.AddWithValue("@telefono", telefono);
            da.SelectCommand.Parameters.AddWithValue("@email", email);
            da.SelectCommand.Parameters.AddWithValue("@clave", clave);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);

            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdSYS_AutoRegistroUsuario(string user, string nombres, string apellidos, string telefono, string email, string clave, int accion)
        {
            return "no activa";
        }

        #endregion

        #region "System Genera Codigo Activacion"
        public string mtdSYS_CodeActivated(string user, string telefono, string email, string codigo, int duracion, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdSYS_CodeActivated(user, telefono, email, codigo, duracion, accion);
            else
                return ODBC_mtdSYS_CodeActivated(user, telefono, email, codigo, duracion, accion);
        }
        private string SQL_mtdSYS_CodeActivated(string user, string telefono, string email, string codigo, int duracion, int accion)
        {
            //string u = mtd_GetUsuarioSesion();;
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("Sys_SP_CodeActivated", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@usuario", user);
            da.SelectCommand.Parameters.AddWithValue("@email", email);
            da.SelectCommand.Parameters.AddWithValue("@telefono", telefono);
            da.SelectCommand.Parameters.AddWithValue("@codigo", codigo);
            da.SelectCommand.Parameters.AddWithValue("@duracion", duracion);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);

            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdSYS_CodeActivated(string user, string telefono, string email, string codigo, int duracion, int accion)
        {
            return "no activa";
        }

        #endregion

        #region "Expedientes Registro Citas"
        public string mtdEXP_RegistroCitas(long id, long expediente, long horario, long horariofin, long tipocita
            , long especialista, long tratamiento, long estado, string comentario, string fecha, string user, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdEXP_RegistroCitas(id, expediente, horario, horariofin, tipocita, especialista, tratamiento, estado, comentario, fecha, user, accion);
            else
                return ODBC_mtdEXP_RegistroCitas(id, expediente, horario, horariofin, tipocita, especialista, tratamiento, estado, comentario, fecha, user, accion);
        }
        private string SQL_mtdEXP_RegistroCitas(long id, long expediente, long horario, long horariofin, long tipocita
            , long especialista, long tratamiento, long estado, string comentario, string fecha, string user, int accion)
        {
            //string u = mtd_GetUsuarioSesion();;
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_SP_Citas", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@id", id);
            da.SelectCommand.Parameters.AddWithValue("@expediente", expediente);
            da.SelectCommand.Parameters.AddWithValue("@horario", horario);
            da.SelectCommand.Parameters.AddWithValue("@especialista", especialista);
            da.SelectCommand.Parameters.AddWithValue("@tratamiento", tratamiento);
            da.SelectCommand.Parameters.AddWithValue("@estado", estado); 
            da.SelectCommand.Parameters.AddWithValue("@comentarios", comentario);
            da.SelectCommand.Parameters.AddWithValue("@fecha", fecha);
            da.SelectCommand.Parameters.AddWithValue("@tipocita", tipocita);
            da.SelectCommand.Parameters.AddWithValue("@horariofin", horariofin);
            da.SelectCommand.Parameters.AddWithValue("@usuario", user);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);

            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdEXP_RegistroCitas(long id, long expediente, long horario, long horariofin, long tipocita
            , long especialista, long tratamiento, long estado, string comentario, string fecha, string user, int accion)
        {
            return "no activa";
        }

        #endregion

        #region "Expedientes Citas Vigentes"
        public string mtdEXP_CitasVigentes(string user, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdEXP_CitasVigentes(user, accion);
            else
                return ODBC_mtdEXP_CitasVigentes(user, accion);
        }
        private string SQL_mtdEXP_CitasVigentes(string user, int accion)
        {
            //string u = mtd_GetUsuarioSesion();;
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_SP_CitasVigentes", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@user", user);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);

            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdEXP_CitasVigentes(string user, int accion)
        {
            return "no activa";
        }

        #endregion

        #region "Expedientes Citas update"
        public string mtdEXP_CitasUpdate(long id, long especialista, long estatus, string fecha, string hora, string comentario, string user, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdEXP_CitasUpdate(id, especialista, estatus, fecha, hora, comentario, user, accion);
            else
                return ODBC_mtdEXP_CitasUpdate(id, especialista, estatus, fecha, hora, comentario, user, accion);
        }
        private string SQL_mtdEXP_CitasUpdate(long id, long especialista, long estatus, string fecha, string hora, string comentario, string user, int accion)
        {
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_SP_CitasUpdate", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@id", id);
            da.SelectCommand.Parameters.AddWithValue("@especialista", especialista);
            da.SelectCommand.Parameters.AddWithValue("@estatus", estatus);
            da.SelectCommand.Parameters.AddWithValue("@fecha", fecha);
            da.SelectCommand.Parameters.AddWithValue("@hora", hora);
            da.SelectCommand.Parameters.AddWithValue("@comentario", comentario);
            da.SelectCommand.Parameters.AddWithValue("@usuario", user);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);

            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdEXP_CitasUpdate(long id, long especialista, long estatus, string fecha, string hora, string comentario, string user, int accion)
        {
            return "no activa";
        }

        #endregion

        #region "Rutas Carga Archivos"
        public string mtdSys_RutasCargaArchivos(int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdSys_RutasCargaArchivos(accion);
            else
                return ODBC_mtdSys_RutasCargaArchivos(accion);
        }
        private string SQL_mtdSys_RutasCargaArchivos(int accion)
        {
            //string u = mtd_GetUsuarioSesion();
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("Sys_SP_RutasCargaArchivos", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return e.Message;
            }

            if (dt != null)
            {

                if (ds.Tables.Count > 1)
                {

                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }

                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }
                }

            }
            else
            {
                respuestaBD = "N&&";
            }

            return respuestaBD;

        }
        private string ODBC_mtdSys_RutasCargaArchivos(int accion)
        {
            return "no activa";
        }

        #endregion

        #region "Citas Agrega Tratamientos"
        public string mtdCIT_AgregaTratamientos(long id, long cita, long tratamiento, string user, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdCIT_AgregaTratamientos(id, cita, tratamiento, user, accion);
            else
                return ODBC_mtdCIT_AgregaTratamientos(id, cita, tratamiento, user, accion);
        }
        private string SQL_mtdCIT_AgregaTratamientos(long id, long cita, long tratamiento, string user, int accion)
        {
            //string u = mtd_GetUsuarioSesion();
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_SP_CITASTRATAMIENTOS", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@id", id);
            da.SelectCommand.Parameters.AddWithValue("@cita", cita);
            da.SelectCommand.Parameters.AddWithValue("@tratamiento", tratamiento);
            da.SelectCommand.Parameters.AddWithValue("@usuario", user);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return e.Message;
            }

            if (dt != null)
            {

                if (ds.Tables.Count > 1)
                {

                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }

                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }
                }

            }
            else
            {
                respuestaBD = "N&&";
            }

            return respuestaBD;

        }
        private string ODBC_mtdCIT_AgregaTratamientos(long id, long cita, long tratamiento, string user, int accion)
        {
            return "no activa";
        }

        #endregion

        #region "Expedientes Citas"
        public string mtdEXP_ExpedientesCitas(long id, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdCIT_AgregaTratamientos(id, accion);
            else
                return ODBC_mtdCIT_AgregaTratamientos(id, accion);
        }
        private string SQL_mtdCIT_AgregaTratamientos(long id, int accion)
        {
            //string u = mtd_GetUsuarioSesion();
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_ExpedienteCitas", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@id", id);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return e.Message;
            }

            if (dt != null)
            {

                if (ds.Tables.Count > 1)
                {

                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }

                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                    {
                        respuestaBD = "N&&";
                    }
                }

            }
            else
            {
                respuestaBD = "N&&";
            }

            return respuestaBD;

        }
        private string ODBC_mtdCIT_AgregaTratamientos(long id, int accion)
        {
            return "no activa";
        }

        #endregion

        #region "Expedientes Crea Procedimientos"
        public string mtdEXP_CreaProcedimientos(long cita, string usuario, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdEXP_CreaProcedimientos(cita, usuario, accion);
            else
                return ODBC_mtdEXP_CreaProcedimientos(cita, usuario, accion);
        }
        private string SQL_mtdEXP_CreaProcedimientos(long cita, string usuario, int accion)
        {
            //string u = mtd_GetUsuarioSesion();
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_SP_ProcedimientosCrea", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@cita", cita);
            da.SelectCommand.Parameters.AddWithValue("@usuario", usuario);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return e.Message;
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdEXP_CreaProcedimientos(long cita, string usuario, int accion)
        {
            return "no activa";
        }

        #endregion

        #region "Expedientes Procedimiento Tratamientos"
        public string mtdEXP_ProcessTratamientos(long id, long procedimiento, long tratamiento, string usuario, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdEXP_ProcessTratamientos(id, procedimiento, tratamiento, usuario, accion);
            else
                return ODBC_mtdEXP_ProcessTratamientos(id, procedimiento, tratamiento, usuario, accion);
        }
        private string SQL_mtdEXP_ProcessTratamientos(long id, long procedimiento, long tratamiento, string usuario, int accion)
        {
            //string u = mtd_GetUsuarioSesion();
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_SP_Tratamientos", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@id", id);
            da.SelectCommand.Parameters.AddWithValue("@process", procedimiento);
            da.SelectCommand.Parameters.AddWithValue("@tratamiento", tratamiento);
            da.SelectCommand.Parameters.AddWithValue("@usuario", usuario);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return e.Message;
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdEXP_ProcessTratamientos(long id, long procedimiento, long tratamiento, string usuario, int accion)
        {
            return "no activa";
        }

        #endregion
        
        #region "Expedientes Procedimiento Actualiza"
        public string mtdEXP_ProcessUpdate(long id, long cita, string diagnostico, string resultados, string recomendacion, string usuario, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdEXP_ProcessUpdate(id, cita, diagnostico, resultados, recomendacion, usuario, accion);
            else
                return ODBC_mtdEXP_ProcessUpdate(id, cita, diagnostico, resultados, recomendacion, usuario, accion);
        }
        private string SQL_mtdEXP_ProcessUpdate(long id, long cita, string diagnostico, string resultados, string recomendacion, string usuario, int accion)
        {
            //string u = mtd_GetUsuarioSesion();
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_SP_ProcedimientosUpdate", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@id", id);
            da.SelectCommand.Parameters.AddWithValue("@cita", cita);
            da.SelectCommand.Parameters.AddWithValue("@diagnostico", diagnostico);
            da.SelectCommand.Parameters.AddWithValue("@resultado", resultados);
            da.SelectCommand.Parameters.AddWithValue("@recomendacion", recomendacion);
            da.SelectCommand.Parameters.AddWithValue("@usuario", usuario);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return e.Message;
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdEXP_ProcessUpdate(long id, long cita, string diagnostico, string resultados, string recomendacion, string usuario, int accion)
        {
            return "no activa";
        }

        #endregion

        #region "Expedientes Parametro InvoiceV1"
        public string mtdEXP_ParametroInvoicev1(long id)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdEXP_ParametroInvoicev1(id);
            else
                return ODBC_mtdEXP_ParametroInvoicev1(id);
        }
        private string SQL_mtdEXP_ParametroInvoicev1(long id)
        {
            //string u = mtd_GetUsuarioSesion();
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_SP_PARAMETROINVOICEV1", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@id", id);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return e.Message;
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdEXP_ParametroInvoicev1(long id)
        {
            return "no activa";
        }

        #endregion

        #region "Expedientes - Citas por Expediente"
        public string mtdEXP_CitasByExpediente(long expediente, long cita, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdEXP_CitasByExpediente(expediente, cita, accion);
            else
                return ODBC_mtdEXP_CitasByExpediente(expediente, cita, accion);
        }
        private string SQL_mtdEXP_CitasByExpediente(long expediente, long cita, int accion)
        {
            //string u = mtd_GetUsuarioSesion();
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_SP_ExpedientesCitas", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@exp", expediente);
            da.SelectCommand.Parameters.AddWithValue("@cita", cita);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return e.Message;
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdEXP_CitasByExpediente(long expediente, long cita, int accion)
        {
            return "no activa";
        }

        #endregion

        #region "Expedientes Busqueda"
        public string mtdEXP_ExpedienteBusca(string cliente, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdEXP_ExpedienteBusca(cliente, accion);
            else
                return ODBC_mtdEXP_ExpedienteBusca(cliente, accion);
        }
        private string SQL_mtdEXP_ExpedienteBusca(string cliente, int accion)
        {
            //string u = mtd_GetUsuarioSesion();
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_SP_ExpedienteBuscar", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@cliente", cliente);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return e.Message;
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdEXP_ExpedienteBusca(string cliente, int accion)
        {
            return "no activa";
        }

        #endregion

        #region "Reportes - Reporte Citas"
        public string mtdREP_ReporteCitas(string cliente, string fdesde, string hdesde, string fhasta, string hhasta, long especialista, long estatus, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdREP_ReporteCitas(cliente, fdesde, hdesde, fhasta, hhasta, especialista, estatus, accion);
            else
                return ODBC_mtdREP_ReporteCitas(cliente, fdesde, hdesde, fhasta, hhasta, especialista, estatus, accion);
        }
        private string SQL_mtdREP_ReporteCitas(string cliente, string fdesde, string hdesde, string fhasta, string hhasta, long especialista, long estatus, int accion)
        {
            //string u = mtd_GetUsuarioSesion();
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("REP_SP_ReporteCitas", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@cliente", cliente);
            da.SelectCommand.Parameters.AddWithValue("@fdesde", fdesde);
            da.SelectCommand.Parameters.AddWithValue("@hdesde", hdesde);
            da.SelectCommand.Parameters.AddWithValue("@fhasta", fhasta);
            da.SelectCommand.Parameters.AddWithValue("@hhasta", hhasta);
            da.SelectCommand.Parameters.AddWithValue("@especialista", especialista);
            da.SelectCommand.Parameters.AddWithValue("@estatus", estatus);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return e.Message;
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdREP_ReporteCitas(string cliente, string fdesde, string hdesde, string fhasta, string hhasta, long especialista, long estatus, int accion)
        {
            return "no activa";
        }

        #endregion

        #region "Reportes - Reporte Procedimientos"
        public string mtdREP_ReporteProcedimientos(string cliente, string fdesde, string hdesde, string fhasta, string hhasta, long especialista, long estatus, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdREP_ReporteProcedimientos(cliente, fdesde, hdesde, fhasta, hhasta, especialista, estatus, accion);
            else
                return ODBC_mtdREP_ReporteProcedimientos(cliente, fdesde, hdesde, fhasta, hhasta, especialista, estatus, accion);
        }
        private string SQL_mtdREP_ReporteProcedimientos(string cliente, string fdesde, string hdesde, string fhasta, string hhasta, long especialista, long estatus, int accion)
        {
            //string u = mtd_GetUsuarioSesion();
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("REP_SP_ReporteProcedimientos", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@cliente", cliente);
            da.SelectCommand.Parameters.AddWithValue("@fdesde", fdesde);
            da.SelectCommand.Parameters.AddWithValue("@hdesde", hdesde);
            da.SelectCommand.Parameters.AddWithValue("@fhasta", fhasta);
            da.SelectCommand.Parameters.AddWithValue("@hhasta", hhasta);
            da.SelectCommand.Parameters.AddWithValue("@especialista", especialista);
            da.SelectCommand.Parameters.AddWithValue("@estatus", estatus);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return e.Message;
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdREP_ReporteProcedimientos(string cliente, string fdesde, string hdesde, string fhasta, string hhasta, long especialista, long estatus, int accion)
        {
            return "no activa";
        }

        #endregion

        #region "Expediente - Crea Citas Temporales"
        public string mtdEXP_CreaCitasTemporales(long id, long exp, long tto, string user, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdEXP_CreaCitasTemporales(id, exp, tto, user, accion);
            else
                return ODBC_mtdEXP_CreaCitasTemporales(id, exp, tto, user, accion);
        }
        private string SQL_mtdEXP_CreaCitasTemporales(long id, long exp, long tto, string user, int accion)
        {
            //string u = mtd_GetUsuarioSesion();
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_SP_EXPEDIENTETRATAMIENTOS", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@id", id);
            da.SelectCommand.Parameters.AddWithValue("@exp", exp);
            da.SelectCommand.Parameters.AddWithValue("@tramto", tto);
            da.SelectCommand.Parameters.AddWithValue("@usuario", user);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return e.Message;
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdEXP_CreaCitasTemporales(long id, long exp, long tto, string user, int accionn)
        {
            return "no activa";
        }

        #endregion

        #region "Expediente - Valida Procedimientos"
        public string mtdEXP_ValidaProcedimientos(long exp, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdEXP_ValidaProcedimientos(exp, accion);
            else
                return ODBC_mtdEXP_ValidaProcedimientos(exp, accion);
        }
        private string SQL_mtdEXP_ValidaProcedimientos(long exp, int accion)
        {
            //string u = mtd_GetUsuarioSesion();
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_SP_ValidaProcedimiento", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@id", exp);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return e.Message;
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdEXP_ValidaProcedimientos(long exp, int accionn)
        {
            return "no activa";
        }

        #endregion

        #region "Expediente - Reprograma Citas"
        public string mtdEXP_ReprogramaCitas(long id, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdEXP_ReprogramaCitas(id, accion);
            else
                return ODBC_mtdEXP_ReprogramaCitas(id, accion);
        }
        private string SQL_mtdEXP_ReprogramaCitas(long id, int accion)
        {
            //string u = mtd_GetUsuarioSesion();
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_SP_REPROGRAMACITAS", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@id", id);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return e.Message;
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdEXP_ReprogramaCitas(long id, int accionn)
        {
            return "no activa";
        }

        #endregion
        
        #region "Expediente - Tratamientos By Proccess"
        public string mtdEXP_TratamientosByProccess(long cita, long tratamiento, string user, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdEXP_TratamientosByProccess(cita, tratamiento, user, accion);
            else
                return ODBC_mtdEXP_TratamientosByProccess(cita, tratamiento, user, accion);
        }
        private string SQL_mtdEXP_TratamientosByProccess(long cita, long tratamiento, string user, int accion)
        {
            //string u = mtd_GetUsuarioSesion();
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_SP_TratamientosByProccess", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@cita", cita);
            da.SelectCommand.Parameters.AddWithValue("@tratamiento", tratamiento);
            da.SelectCommand.Parameters.AddWithValue("@user", user);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return e.Message;
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdEXP_TratamientosByProccess(long cita, long tratamiento, string user, int accion)
        {
            return "no activa";
        }

        #endregion

        #region "Expediente - Tratamientos By Citas"
        public string mtdEXP_TratamientosByCitas(long cita, long tratamiento, string user, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdEXP_TratamientosByCitas(cita, tratamiento, user, accion);
            else
                return ODBC_mtdEXP_TratamientosByCitas(cita, tratamiento, user, accion);
        }
        private string SQL_mtdEXP_TratamientosByCitas(long cita, long tratamiento, string user, int accion)
        {
            //string u = mtd_GetUsuarioSesion();
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_SP_TratamientosByCita", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@cita", cita);
            da.SelectCommand.Parameters.AddWithValue("@tratamiento", tratamiento);
            da.SelectCommand.Parameters.AddWithValue("@user", user);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return e.Message;
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdEXP_TratamientosByCitas(long cita, long tratamiento, string user, int accion)
        {
            return "no activa";
        }

        #endregion

        #region "Expediente Resumen Expediente"
        public string mtdEXP_ResumenExpediente(long id)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdEXP_ResumenExpediente(id);
            else
                return ODBC_mtdEXP_ResumenExpediente(id);
        }
        private string SQL_mtdEXP_ResumenExpediente(long id)
        {
            //string u = mtd_GetUsuarioSesion();;
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_SP_ResumenExpediente", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@id", id);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdEXP_ResumenExpediente(long id)
        {
            return "no activa";
        }

        #endregion

        #region "Expediente Cupones"
        public string mtdEXP_Cupones(long id, string codigo, string asignado, long expediente
            , long tratamiento, int estado, string cupon, string user, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdEXP_Cupones(id, codigo, asignado, expediente, tratamiento, estado, cupon, user, accion);
            else
                return ODBC_mtdEXP_Cupones(id, codigo, asignado, expediente, tratamiento, estado, cupon, user, accion);
        }
        private string SQL_mtdEXP_Cupones(long id, string codigo, string asignado, long expediente
            , long tratamiento, int estado, string cupon, string user, int accion)
        {
            //string u = mtd_GetUsuarioSesion();;
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_SP_CUPONES", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@id", id);
            da.SelectCommand.Parameters.AddWithValue("@codigo", codigo);
            da.SelectCommand.Parameters.AddWithValue("@asigando", asignado);
            da.SelectCommand.Parameters.AddWithValue("@expediente", expediente);
            da.SelectCommand.Parameters.AddWithValue("@tratamiento", tratamiento);
            da.SelectCommand.Parameters.AddWithValue("@estatus", estado);
            da.SelectCommand.Parameters.AddWithValue("@rutaarchivo", cupon);
            da.SelectCommand.Parameters.AddWithValue("@usuario", user);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdEXP_Cupones(long id, string codigo, string asignado, long expediente
            , long tratamiento, int estado, string cupon, string user, int accion)
        {
            return "no activa";
        }

        #endregion

        #region "Expediente Busca Expediente x nombres"
        public string mtdEXP_BuscaExpByNames(string nombres)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdEXP_BuscaExpByNames(nombres);
            else
                return ODBC_mtdEXP_BuscaExpByNames(nombres);
        }
        private string SQL_mtdEXP_BuscaExpByNames(string nombres)
        {
            //string u = mtd_GetUsuarioSesion();;
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_SP_BUSCAPACIENTES", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@paciente", nombres);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdEXP_BuscaExpByNames(string nombres)
        {
            return "no activa";
        }

        #endregion

        #region "Expediente Anula Tratamientos"
        public string mtdEXP_AnulaTratamientos(long id, long cita, string user, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdEXP_AnulaTratamientos(id, cita, user, accion);
            else
                return ODBC_mtdEXP_AnulaTratamientos(id, cita, user, accion);
        }
        private string SQL_mtdEXP_AnulaTratamientos(long id, long cita, string user, int accion)
        {
            //string u = mtd_GetUsuarioSesion();;
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_SP_ANULATTO", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@id", id);
            da.SelectCommand.Parameters.AddWithValue("@cita", cita);
            da.SelectCommand.Parameters.AddWithValue("@usuario", user);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdEXP_AnulaTratamientos(long id, long cita, string user, int accion)
        {
            return "no activa";
        }

        #endregion

        #region "System Rutas de Cargas"
        public string mtSys_RutasCargas(int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtSys_RutasCargas(accion);
            else
                return ODBC_mtSys_RutasCargas(accion);
        }
        private string SQL_mtSys_RutasCargas(int accion)
        {
            //string u = mtd_GetUsuarioSesion();;
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("Sys_SP_RutasCargas", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtSys_RutasCargas(int accion)
        {
            return "no activa";
        }

        #endregion

        #region "Expedientes Citas Reprograma"
        public string mtdEXP_CitasReprograma(long id, long cita, long especialista, long estatus, string fecha, string hora, string horariofin, string tipocita, string comentario, string user, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdEXP_CitasReprograma(id, cita, especialista, estatus, fecha, hora, horariofin, tipocita, comentario, user, accion);
            else
                return ODBC_mtdEXP_CitasReprograma(id, cita, especialista, estatus, fecha, hora, horariofin, tipocita, comentario, user, accion);
        }
        private string SQL_mtdEXP_CitasReprograma(long id, long cita, long especialista, long estatus, string fecha, string hora, string horariofin, string tipocita, string comentario, string user, int accion)
        {
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_SP_PROCEDIMIENTOSREPROGRAN", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@id", id);
            da.SelectCommand.Parameters.AddWithValue("@cita", cita);
            da.SelectCommand.Parameters.AddWithValue("@especialista", especialista);
            da.SelectCommand.Parameters.AddWithValue("@estatus", estatus);
            da.SelectCommand.Parameters.AddWithValue("@fecha", fecha);
            da.SelectCommand.Parameters.AddWithValue("@hora", hora);
            da.SelectCommand.Parameters.AddWithValue("@horariofin", horariofin);
            da.SelectCommand.Parameters.AddWithValue("@tipocita", tipocita);
            da.SelectCommand.Parameters.AddWithValue("@comentario", comentario);
            da.SelectCommand.Parameters.AddWithValue("@usuario", user);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);

            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdEXP_CitasReprograma(long id, long cita, long especialista, long estatus, string fecha, string hora, string horariofin, string tipocita, string comentario, string user, int accion)
        {
            return "no activa";
        }

        #endregion

        #region "Expediente - Lee Procedimientos"
        public string mtdEXP_LeeProcedimientos(long id, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdEXP_LeeProcedimientos(id, accion);
            else
                return ODBC_mtdEXP_LeeProcedimientos(id, accion);
        }
        private string SQL_mtdEXP_LeeProcedimientos(long id, int accion)
        {
            //string u = mtd_GetUsuarioSesion();
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_SP_LEEPROCEDIMIENTOS", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@id", id);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return e.Message;
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdEXP_LeeProcedimientos(long id, int accionn)
        {
            return "no activa";
        }

        #endregion

        #region "Expediente - Proccess Cancelar"
        public string mtdEXP_ProccessCancelar(long cita, string  user)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdEXP_ProccessCancelar(cita, user);
            else
                return ODBC_mtdEXP_ProccessCancelar(cita, user);
        }
        private string SQL_mtdEXP_ProccessCancelar(long cita, string user)
        {
            //string u = mtd_GetUsuarioSesion();
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_SP_PROCCESSCANCELA", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@cita", cita);
            da.SelectCommand.Parameters.AddWithValue("@usuario", user);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return e.Message;
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdEXP_ProccessCancelar(long cita, string user)
        {
            return "no activa";
        }

        #endregion

        #region "Expediente - Expediente Lista"
        public string mtdEXP_ExpedienteLista(string letra, string user, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdEXP_ExpedienteLista(letra, user, accion);
            else
                return ODBC_mtdEXP_ExpedienteLista(letra, user, accion);
        }
        private string SQL_mtdEXP_ExpedienteLista(string letra, string user, int accion)
        {
            //string u = mtd_GetUsuarioSesion();;
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_SP_ExpedientesByAlbethic", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@letra", letra);
            da.SelectCommand.Parameters.AddWithValue("@user", user);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdEXP_ExpedienteLista(string letra, string user, int accion)
        {
            return "no activa";
        }

        #endregion

        #region "Expediente - Search Expediente"
        public string mtdEXP_SearchExpediente(string documento, string nombres, string apellidos, string celular, string user, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdEXP_SearchExpediente(documento, nombres, apellidos, celular, user, accion);
            else
                return ODBC_mtdEXP_SearchExpediente(documento, nombres, apellidos, celular, user, accion);
        }
        private string SQL_mtdEXP_SearchExpediente(string documento, string nombres, string apellidos, string celular, string user, int accion)
        {
            //string u = mtd_GetUsuarioSesion();;
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_SP_SearchExpedientes", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@documento", documento);
            da.SelectCommand.Parameters.AddWithValue("@nombres", nombres);
            da.SelectCommand.Parameters.AddWithValue("@apellidos", apellidos);
            da.SelectCommand.Parameters.AddWithValue("@celular", celular);
            da.SelectCommand.Parameters.AddWithValue("@user", user);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdEXP_SearchExpediente(string documento, string nombres, string apellidos, string celular, string user, int accion)
        {
            return "no activa";
        }

        #endregion

        #region "Expediente - Procedimientos Expediente"
        public string mtdEXP_ProcedimientosExpediente(long expediente, long procedimiento, string user, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdEXP_ProcedimientosExpediente(expediente, procedimiento, user, accion);
            else
                return ODBC_mtdEXP_ProcedimientosExpediente(expediente, procedimiento, user, accion);
        }
        private string SQL_mtdEXP_ProcedimientosExpediente(long expediente,long procedimiento, string user, int accion)
        {
            //string u = mtd_GetUsuarioSesion();;
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_SP_ProcedimientosExpediente", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@expediente", expediente);
            da.SelectCommand.Parameters.AddWithValue("@procedimiento", procedimiento);
            da.SelectCommand.Parameters.AddWithValue("@user", user);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return "no hay datos";
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdEXP_ProcedimientosExpediente(long expediente, long procedimiento, string user, int accion)
        {
            return "no activa";
        }

        #endregion

        #region "Reportes - Expedientes"
        public string mtdREP_Expedientes(string desde, string hasta, long sexo, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdREP_Expedientes(desde, hasta, sexo, accion);
            else
                return ODBC_mtdREP_Expedientes(desde, hasta, sexo, accion);
        }
        private string SQL_mtdREP_Expedientes(string desde, string hasta, long sexo, int accion)
        {
            //string u = mtd_GetUsuarioSesion();
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("REP_SP_Expedientes", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@fechainicio", desde);
            da.SelectCommand.Parameters.AddWithValue("@fechafinal", hasta);
            da.SelectCommand.Parameters.AddWithValue("@sexo", sexo);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return e.Message;
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdREP_Expedientes(string desde, string hasta, long sexo, int accion)
        {
            return "no activa";
        }

        #endregion

        #region "Caja - Aperturas"
        public string mtdCAJ_Aperturas(long id, string fecha, string monto, string sobrante, string faltante
            , string cajero, int estatus, string user, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdCAJ_Aperturas(id, fecha, monto, sobrante, faltante, cajero, estatus, user, accion);
            else
                return ODBC_mtdCAJ_Aperturas(id, fecha, monto, sobrante, faltante, cajero, estatus, user, accion);
        }
        private string SQL_mtdCAJ_Aperturas(long id, string fecha, string monto, string sobrante, string faltante
            , string cajero, int estatus, string user, int accion)
        {
            //string u = mtd_GetUsuarioSesion();
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("CAJ_SP_APETURTACAJA", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@id", id);
            da.SelectCommand.Parameters.AddWithValue("@fecha", fecha);
            da.SelectCommand.Parameters.AddWithValue("@monto", monto);
            da.SelectCommand.Parameters.AddWithValue("@sobrante", sobrante);
            da.SelectCommand.Parameters.AddWithValue("@faltante", faltante);
            da.SelectCommand.Parameters.AddWithValue("@cajero", cajero);
            da.SelectCommand.Parameters.AddWithValue("@estatus", estatus);
            da.SelectCommand.Parameters.AddWithValue("@usuario", user);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return e.Message;
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdCAJ_Aperturas(long id, string fecha, string monto, string sobrante, string faltante
            , string cajero, int estatus, string user, int accion)
        {
            return "no activa";
        }

        #endregion

        #region "Caja - Facturas"
        public string mtdCAJ_Facturas(long id, int estado, string user, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdCAJ_Facturas(id, estado, user, accion);
            else
                return ODBC_mtdCAJ_Facturas(id, estado, user, accion);
        }
        private string SQL_mtdCAJ_Facturas(long id, int estado, string user, int accion)
        {
            //string u = mtd_GetUsuarioSesion();
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_SP_FACTURAS", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@factura", id);
            da.SelectCommand.Parameters.AddWithValue("@estado", estado);
            da.SelectCommand.Parameters.AddWithValue("@usuario", user);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return e.Message;
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdCAJ_Facturas(long id, int estado, string user, int accion)
        {
            return "no activa";
        }

        #endregion

        #region "Caja - Consulta Expediente"
        public string mtdCAJ_ConsultaExpediente(long id, string user)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdCAJ_ConsultaExpediente(id,  user);
            else
                return ODBC_mtdCAJ_ConsultaExpediente(id,  user);
        }
        private string SQL_mtdCAJ_ConsultaExpediente(long id, string user)
        {
            //string u = mtd_GetUsuarioSesion();
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_CONSULTACLIENTE", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@id", id);
            da.SelectCommand.Parameters.AddWithValue("@usuario", user);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return e.Message;
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdCAJ_ConsultaExpediente(long id,string user)
        {
            return "no activa";
        }

        #endregion

        #region "Catalogos - Horarios By Citas"
        public string mtdCAT_HorariosByCitas(long tipocita, long especialista, string fecha, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdCAT_HorariosByCitas(tipocita, especialista, fecha, accion);
            else
                return ODBC_mtdCAT_HorariosByCitas(tipocita, especialista, fecha, accion);
        }
        private string SQL_mtdCAT_HorariosByCitas(long tipocita, long especialista, string fecha, int accion)
        {
            //string u = mtd_GetUsuarioSesion();
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("CAT_SP_HorariosByCitas", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@tipocita", tipocita);
            da.SelectCommand.Parameters.AddWithValue("@especialista", especialista); 
            da.SelectCommand.Parameters.AddWithValue("@fecha", fecha);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return e.Message;
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdCAT_HorariosByCitas(long tipocita, long especialista, string fecha, int accion)
        {
            return "no activa";
        }

        #endregion

        #region "Repcion - Cliente Llamadas"
        public string mtdREC_ClientesLlamadas(long id, string cliente, string telefono, string comentario, string user, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdCAJ_Aperturas(id, cliente, telefono, comentario, user, accion);
            else
                return ODBC_mtdCAJ_Aperturas(id, cliente, telefono, comentario, user, accion);
        }
        private string SQL_mtdCAJ_Aperturas(long id, string cliente, string telefono, string comentario, string user, int accion)
        {
            //string u = mtd_GetUsuarioSesion();
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("REC_SP_CLIENTES", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@id", id);
            da.SelectCommand.Parameters.AddWithValue("@cliente", cliente);
            da.SelectCommand.Parameters.AddWithValue("@telefono", telefono);
            da.SelectCommand.Parameters.AddWithValue("@comentario", comentario);
            da.SelectCommand.Parameters.AddWithValue("@user", user);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return e.Message;
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdCAJ_Aperturas(long id, string cliente, string telefono, string comentario, string user, int accion)
        {
            return "no activa";
        }

        #endregion

        #region "Expediente - Procesos V2"
        public string mtdEXP_ProcesosV2(long exp, long cita, long process, long item, string user, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdEXP_ProcesosV2(exp, cita, process, item, user, accion);
            else
                return ODBC_mtdEXP_ProcesosV2(exp, cita, process, item, user, accion);
        }
        private string SQL_mtdEXP_ProcesosV2(long exp, long cita, long process, long item, string user, int accion)
        {
            //string u = mtd_GetUsuarioSesion();
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_SP_GetProcess", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@exp", exp);
            da.SelectCommand.Parameters.AddWithValue("@cita", cita);
            da.SelectCommand.Parameters.AddWithValue("@process", process);
            da.SelectCommand.Parameters.AddWithValue("@item", item);
            da.SelectCommand.Parameters.AddWithValue("@user", user);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return e.Message;
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdEXP_ProcesosV2(long exp, long cita, long process, long item, string user, int accion)
        {
            return "no activa";
        }

        #endregion

        #region "Expediente - ListaTratamientos"
        public string mtdEXP_ListaTratamientos(long exp, long process, long item, string user, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdEXP_ListaTratamientos(exp, process, item, user, accion);
            else
                return ODBC_mtdEXP_ListaTratamientos(exp, process, item, user, accion);
        }
        private string SQL_mtdEXP_ListaTratamientos(long exp, long process, long item, string user, int accion)
        {
            //string u = mtd_GetUsuarioSesion();
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_SP_ListaTratamientos", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@exp", exp);
            da.SelectCommand.Parameters.AddWithValue("@process", process);
            da.SelectCommand.Parameters.AddWithValue("@item", item);
            da.SelectCommand.Parameters.AddWithValue("@user", user);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return e.Message;
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdEXP_ListaTratamientos(long exp, long process, long item, string user, int accion)
        {
            return "no activa";
        }

        #endregion

        #region "Expediente - Citas Process Update"
        public string mtdEXP_CitasProcessUpdate(long exp, long cita, long process, string fecha, string hora, long tipo, string user, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdEXP_CitasProcessUpdate(exp, cita, process, fecha, hora, tipo, user, accion);
            else
                return ODBC_mtdEXP_CitasProcessUpdate(exp, cita, process, fecha, hora, tipo, user, accion);
        }
        private string SQL_mtdEXP_CitasProcessUpdate(long exp, long cita, long process, string fecha, string hora, long tipo, string user, int accion)
        {
            //string u = mtd_GetUsuarioSesion();
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_SP_CitaProcessUpdate", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@exp", exp);
            da.SelectCommand.Parameters.AddWithValue("@cita", cita);
            da.SelectCommand.Parameters.AddWithValue("@process", process);
            da.SelectCommand.Parameters.AddWithValue("@fecha", fecha);
            da.SelectCommand.Parameters.AddWithValue("@hora", hora);
            da.SelectCommand.Parameters.AddWithValue("@tipo", tipo);
            da.SelectCommand.Parameters.AddWithValue("@user", user);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return e.Message;
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdEXP_CitasProcessUpdate(long exp, long cita, long process, string fecha, string hora, long tipo, string user, int accion)
        {
            return "no activa";
        }

        #endregion

        #region "Expediente - Citas Process Estados"
        public string mtdEXP_CitasProcessEstados(long cita, long process, long estado, string user, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdEXP_CitasProcessEstados(cita, process, estado, user, accion);
            else
                return ODBC_mtdEXP_CitasProcessEstados(cita, process, estado, user, accion);
        }
        private string SQL_mtdEXP_CitasProcessEstados(long cita, long process, long estado, string user, int accion)
        {
            //string u = mtd_GetUsuarioSesion();
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_SP_EstatusUpdate", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@cita", cita);
            da.SelectCommand.Parameters.AddWithValue("@process", process);
            da.SelectCommand.Parameters.AddWithValue("@estado", estado);
            da.SelectCommand.Parameters.AddWithValue("@user", user);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return e.Message;
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdEXP_CitasProcessEstados(long cita, long process, long estado, string user, int accion)
        {
            return "no activa";
        }

        #endregion
        
        #region "Expediente -Process Especialista"
        public string mtdEXP_ProcessEspecialista(long process, long especialista, string user, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdEXP_ProcessEspecialista(process, especialista, user, accion);
            else
                return ODBC_mtdEXP_ProcessEspecialista(process, especialista, user, accion);
        }
        private string SQL_mtdEXP_ProcessEspecialista(long process, long especialista, string user, int accion)
        {
            //string u = mtd_GetUsuarioSesion();
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_SP_ProcessProfetionalUpdate", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@process", process);
            da.SelectCommand.Parameters.AddWithValue("@especialista", especialista);
            da.SelectCommand.Parameters.AddWithValue("@user", user);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return e.Message;
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdEXP_ProcessEspecialista(long process, long especialista, string user, int accion)
        {
            return "no activa";
        }

        #endregion

        #region "Expediente - Reclamos"
        public string mtdEXP_Reclamos(long id, long expediente, long especialista, long procedimiento, string reclamo, string user,  int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdEXP_Reclamos(id, expediente, especialista, procedimiento, reclamo, user,  accion);
            else
                return ODBC_mtdEXP_Reclamos(id, expediente, especialista, procedimiento, reclamo, user,  accion);
        }
        private string SQL_mtdEXP_Reclamos(long id, long expediente, long especialista, long procedimiento, string reclamo, string user,  int accion)
        {
            //string u = mtd_GetUsuarioSesion();
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_SP_Reclamos", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@id", id); 
            da.SelectCommand.Parameters.AddWithValue("@expediente", expediente);
            da.SelectCommand.Parameters.AddWithValue("@especialista", especialista);
            da.SelectCommand.Parameters.AddWithValue("@procedimiento", procedimiento);
            da.SelectCommand.Parameters.AddWithValue("@reclamo", reclamo);
            da.SelectCommand.Parameters.AddWithValue("@user", user);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return e.Message;
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdEXP_Reclamos(long id, long expediente, long especialista, long procedimiento, string reclamo, string user, int accion)
        {
            return "no activa";
        }

        #endregion

        #region "Expediente - Procedimientos by Especialista"
        public string mtdEXP_ProcedimientosByEspecialista(long especialista, string user, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdEXP_ProcedimientosByEspecialista(especialista, user, accion);
            else
                return ODBC_mtdEXP_ProcedimientosByEspecialista(especialista, user, accion);
        }
        private string SQL_mtdEXP_ProcedimientosByEspecialista(long especialista, string user, int accion)
        {
            //string u = mtd_GetUsuarioSesion();
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_SP_ProcedimientosByEspecialista", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@especialista", especialista);
            da.SelectCommand.Parameters.AddWithValue("@usuario", user);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return e.Message;
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdEXP_ProcedimientosByEspecialista(long especialista, string user, int accion)
        {
            return "no activa";
        }

        #endregion

        #region "Expediente - Lista Tratamientos Agendados"
        public string mtdEXP_ListaTratamientosAgendados(long id, string user, int accion)
        {
            if (mtd_OpcionBaseDeDatos())
                return SQL_mtdEXP_ListaTratamientosAgendados(id, user, accion);
            else
                return ODBC_mtdEXP_ListaTratamientosAgendados(id, user, accion);
        }
        private string SQL_mtdEXP_ListaTratamientosAgendados(long id, string user, int accion)
        {
            //string u = mtd_GetUsuarioSesion();
            string respuestaBD = "";
            SqlDataAdapter da = new SqlDataAdapter("EXP_SP_ListaTratamientosAgenda", mtd_ExtraeConexion());
            da.SelectCommand.Parameters.AddWithValue("@id", id);
            da.SelectCommand.Parameters.AddWithValue("@user", user);
            da.SelectCommand.Parameters.AddWithValue("@accion", accion);
            da.SelectCommand.CommandType = System.Data.CommandType.StoredProcedure;

            DataSet ds = new DataSet();
            DataTable dt = new DataTable();
            try
            {
                da.Fill(ds);
                dt = ds.Tables[0];
                _dtReturn = dt;
            }
            catch (Exception e)
            {
                StackTrace stackTrace = new StackTrace();
                StackFrame stackFrame = stackTrace.GetFrame(1);
                MethodBase methodBase = stackFrame.GetMethod();
                obj_logErrores.SaveLogError(LogErrores.TipoError.BaseDeDatos, -1, methodBase.Name, "", e.Message);
                return e.Message;
            }

            if (dt != null)
            {
                if (ds.Tables.Count > 1)
                {
                    if (ds.Tables[1].Rows.Count > 0)
                    {
                        DataRow fila = ds.Tables[1].Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
                else
                {
                    if (dt.Rows.Count > 0)
                    {
                        DataRow fila = dt.Rows[0];
                        respuestaBD = fila[0].ToString();
                    }
                    else
                        respuestaBD = "N&&";
                }
            }
            else
                respuestaBD = "N&&";

            return respuestaBD;
        }
        private string ODBC_mtdEXP_ListaTratamientosAgendados(long id, string user, int accion)
        {
            return "no activa";
        }

        #endregion



        public void Dispose()
        {
            throw new NotImplementedException();
        }

        void IDisposable.Dispose()
        {
            // throw new NotImplementedException();
            obj_logErrores = null;
        }
    }
}