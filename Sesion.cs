using System;
using System.Collections;
using System.Web;

namespace DPieCenter
{
    /// <summary>
    /// Datos de la sesión creada en login.aspx (Session["dpsesion"] = [usuario, grupo, foto]).
    /// Para decidir permisos en el servidor, en lugar de confiar en el usuario que envía el navegador.
    /// </summary>
    public static class Sesion
    {
        public const string GrupoAdministradores = "Administradores";

        private static ArrayList Datos
        {
            get
            {
                var ctx = HttpContext.Current;
                return ctx == null || ctx.Session == null ? null : ctx.Session["dpsesion"] as ArrayList;
            }
        }

        public static bool Activa { get { return Datos != null && Datos.Count > 0; } }
        public static string Usuario { get { return Activa ? Convert.ToString(Datos[0]) : null; } }
        public static string Grupo { get { return Activa && Datos.Count > 1 ? Convert.ToString(Datos[1]) : null; } }
        public static string Foto { get { return Activa && Datos.Count > 2 ? Convert.ToString(Datos[2]) : null; } }

        public static bool EsAdministrador
        {
            get { return string.Equals(Grupo, GrupoAdministradores, StringComparison.OrdinalIgnoreCase); }
        }

        // ===== Sucursal =====
        // Cada usuario tiene una sucursal fija (Sys_Usuarios.Id_Sucursal_FK). Los administradores pueden cambiar
        // la sucursal en la que trabajan durante la sesión (barra superior). Se lee de la base una vez por sesión.
        private const string ClaveSucursal = "dpsucursal", ClaveSucursalNombre = "dpsucursalnombre";

        /// <summary>Sucursal en la que trabaja el usuario (0 si no hay sesión).</summary>
        public static int Sucursal
        {
            get
            {
                if (!Activa) return 0;
                var s = HttpContext.Current.Session;
                if (!(s[ClaveSucursal] is int)) CargarSucursal(null);
                return s[ClaveSucursal] is int ? (int)s[ClaveSucursal] : 0;
            }
        }

        public static string SucursalNombre
        {
            get { return Sucursal > 0 ? Convert.ToString(HttpContext.Current.Session[ClaveSucursalNombre]) : ""; }
        }

        /// <summary>Solo administradores: trabaja en otra sucursal durante esta sesión. false si la sucursal no existe o está inactiva.</summary>
        public static bool CambiarSucursal(int sucursal)
        {
            if (!Activa || !EsAdministrador) return false;
            return CargarSucursal(sucursal);
        }

        /// <summary>
        /// Sucursal para filtrar consultas y reportes: el administrador puede pedir cualquiera (0 = todas);
        /// los demás usuarios siempre ven la suya.
        /// </summary>
        public static int SucursalFiltro(int solicitada)
        {
            return EsAdministrador ? Math.Max(0, solicitada) : Sucursal;
        }

        /// <summary>Quita de la sesión los permisos y la sucursal guardados (al entrar o salir).</summary>
        public static void LimpiarCache()
        {
            var ctx = HttpContext.Current;
            if (ctx == null || ctx.Session == null) return;
            var claves = new System.Collections.Generic.List<string>();
            foreach (string k in ctx.Session.Keys) if (k.StartsWith("dpacceso:") || k.StartsWith(ClaveSucursal)) claves.Add(k);
            foreach (var k in claves) ctx.Session.Remove(k);
        }

        private static bool CargarSucursal(int? elegida)
        {
            using (var cn = new System.Data.SqlClient.SqlConnection(System.Configuration.ConfigurationManager.ConnectionStrings["conexionDiarypro"].ConnectionString))
            using (var cmd = new System.Data.SqlClient.SqlCommand(elegida.HasValue
                ? "select Id_Sucursal, Nombre from CAT_SUCURSALES where Id_Sucursal = @id and IsActivo = 1"
                : "select top 1 s.Id_Sucursal, s.Nombre from CAT_SUCURSALES as s " +
                  "left join Sys_Usuarios as u on u.Id_Sucursal_FK = s.Id_Sucursal and u.Id_Usuario = @usuario " +
                  "order by case when u.Id_Usuario is not null then 0 else 1 end, s.EsMatriz desc", cn))
            {
                cmd.Parameters.Add("@id", System.Data.SqlDbType.Int).Value = elegida ?? 0;
                cmd.Parameters.Add("@usuario", System.Data.SqlDbType.VarChar, 20).Value = Usuario ?? "";
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                {
                    if (!rd.Read()) return false;
                    var s = HttpContext.Current.Session;
                    s[ClaveSucursal] = Convert.ToInt32(rd[0]);
                    s[ClaveSucursalNombre] = Convert.ToString(rd[1]);
                    return true;
                }
            }
        }

        /// <summary>
        /// true si el grupo del usuario tiene en el menú la opción con esa URL (Sys_Opciones + Sys_Permisos).
        /// Así un WebMethod respeta los mismos permisos que el menú, aunque lo llamen directamente.
        /// </summary>
        public static bool TieneAcceso(string accesoUrl)
        {
            if (!Activa || string.IsNullOrWhiteSpace(Grupo)) return false;
            var ctx = HttpContext.Current;
            string clave = "dpacceso:" + accesoUrl.ToLowerInvariant();
            if (ctx.Session[clave] is bool) return (bool)ctx.Session[clave];

            bool permitido;
            using (var cn = new System.Data.SqlClient.SqlConnection(System.Configuration.ConfigurationManager.ConnectionStrings["conexionDiarypro"].ConnectionString))
            using (var cmd = new System.Data.SqlClient.SqlCommand(
                "select count(*) from Sys_Opciones as o inner join Sys_Permisos as p on p.IdOpcion_FK = o.Id_Opcion " +
                "where p.IdGrupo_FK = @grupo and o.AccesoURL = @url", cn))
            {
                cmd.Parameters.Add("@grupo", System.Data.SqlDbType.VarChar, 50).Value = Grupo;
                cmd.Parameters.Add("@url", System.Data.SqlDbType.VarChar, 300).Value = accesoUrl;
                cn.Open();
                permitido = Convert.ToInt32(cmd.ExecuteScalar()) > 0;
            }
            ctx.Session[clave] = permitido;     // se recalcula en la próxima sesión
            return permitido;
        }
    }
}
