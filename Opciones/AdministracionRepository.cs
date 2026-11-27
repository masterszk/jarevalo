using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;
using System.Web;

namespace DPieCenter.Opciones
{
    // ===== Modelos de la administración del sistema (menú Opciones) =====

    public class RespuestaDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public long Id { get; set; }
    }

    public class ListaDto<T>
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public List<T> Items { get; set; }
    }

    public class ModuloDto
    {
        public long Id { get; set; }
        public string Descripcion { get; set; }
        public string Icono { get; set; }
        public int Orden { get; set; }
        public int Opciones { get; set; }
        public string Usuario { get; set; }
        public string Fecha { get; set; }
    }

    public class OpcionMenuDto
    {
        public long Id { get; set; }
        public long IdModulo { get; set; }
        public string Descripcion { get; set; }
        public string Abreviado { get; set; }
        public string Url { get; set; }
        public int Orden { get; set; }
        public int Grupos { get; set; }
        public string Usuario { get; set; }
        public string Fecha { get; set; }
    }

    public class GrupoDto
    {
        public string Id { get; set; }
        public string Descripcion { get; set; }
        public int Usuarios { get; set; }
        public int Permisos { get; set; }
        public string Usuario { get; set; }
        public string Fecha { get; set; }
    }

    public class PermisoDto
    {
        public long IdModulo { get; set; }
        public string Modulo { get; set; }
        public string Icono { get; set; }
        public long IdOpcion { get; set; }
        public string Opcion { get; set; }
        public string Url { get; set; }
        public bool Tiene { get; set; }
    }

    public class DashboardConfDto
    {
        public long Id { get; set; }
        public string Descripcion { get; set; }
        public string Url { get; set; }
        public string Estado { get; set; }
        public int Usuarios { get; set; }
        public string Usuario { get; set; }
        public string Fecha { get; set; }
    }

    public class UsuarioConfDto
    {
        public string Id { get; set; }
        public string Nombres { get; set; }
        public string Apellidos { get; set; }
        public string IdGrupo { get; set; }
        public string Grupo { get; set; }
        public string Estado { get; set; }
        public string Email { get; set; }
        public string Telefono { get; set; }
        public string Celular { get; set; }
        public string Documento { get; set; }      // DUI o NIT: "Documento emisor" en el PDF del DTE
        public int Caducidad { get; set; }
        public long IdDashboard { get; set; }
        public string Dashboard { get; set; }
        public bool Responsable { get; set; }
        public string UltimoIngreso { get; set; }
        public string CambioClave { get; set; }
        public string Especialista { get; set; }
        public int IdSucursal { get; set; }         // sucursal fija del usuario
        public string Sucursal { get; set; }
        public string Usuario { get; set; }
        public string Fecha { get; set; }
    }

    public class EmpresaDto
    {
        public long Id { get; set; }
        public string Nombre { get; set; }
        public string Propietario { get; set; }
        public string Nrc { get; set; }
        public string Nit { get; set; }
        public string Dui { get; set; }
        public string Telefono { get; set; }
        public string Actividad { get; set; }
        public long Departamento { get; set; }
        public long Municipio { get; set; }
        public string Direccion { get; set; }
        public string Email { get; set; }
        public string Servidor { get; set; }
        public int Puerto { get; set; }
        /// <summary>Solo al guardar: vacío conserva la clave guardada. Nunca se envía al navegador.</summary>
        public string ClaveEmail { get; set; }
        public bool TieneClave { get; set; }
        public string Usuario { get; set; }
        public string Fecha { get; set; }
    }

    public class CatalogoItemDto
    {
        public long Id { get; set; }
        public string Texto { get; set; }
    }

    /// <summary>Validaciones comunes de los WebMethods de administración: sesión y permiso de la opción del menú.</summary>
    public static class AdministracionWeb
    {
        public static string Permiso(string accesoUrl)
        {
            if (!Sesion.Activa) return "La sesión expiró. Vuelva a iniciar sesión.";
            if (!Sesion.EsAdministrador && !Sesion.TieneAcceso(accesoUrl)) return "No tiene permiso para usar esta opción.";
            return null;
        }

        public static string Detalle(Exception ex, string generico)
        {
            var sql = ex as SqlException;
            if (sql != null && sql.Number >= 50000) return sql.Message;
            System.Diagnostics.Trace.TraceError(generico + ": " + ex);
            bool debug = HttpContext.Current != null && HttpContext.Current.IsDebuggingEnabled;
            return debug ? "[DEBUG] " + ex.GetType().Name + ": " + ex.Message : generico;
        }

        public static ListaDto<T> Lista<T>(string url, Func<List<T>> leer, string error)
        {
            string permiso = Permiso(url);
            if (permiso != null) return new ListaDto<T> { Ok = false, Mensaje = permiso };
            try { return new ListaDto<T> { Ok = true, Items = leer() }; }
            catch (Exception ex) { return new ListaDto<T> { Ok = false, Mensaje = Detalle(ex, error) }; }
        }

        public static RespuestaDto Accion(string url, Func<long> hacer, string exito, string error)
        {
            string permiso = Permiso(url);
            if (permiso != null) return new RespuestaDto { Ok = false, Mensaje = permiso };
            try { return new RespuestaDto { Ok = true, Id = hacer(), Mensaje = exito }; }
            catch (Exception ex) { return new RespuestaDto { Ok = false, Mensaje = Detalle(ex, error) }; }
        }
    }

    /// <summary>Acceso a dbo.SYS_SP_Administracion (Opciones/sql/SYS_Administracion.sql).</summary>
    public static class AdministracionRepository
    {
        private static readonly CultureInfo Inv = CultureInfo.InvariantCulture;

        private static string Cn
        {
            get { return ConfigurationManager.ConnectionStrings["conexionDiarypro"].ConnectionString; }
        }

        private static string Txt(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? "" : Convert.ToString(v).Trim(); }
        private static int Ent(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? 0 : Convert.ToInt32(v); }
        private static long Num(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? 0 : Convert.ToInt64(v); }
        private static bool Bit(IDataRecord r, string col) { var v = r[col]; return v != DBNull.Value && Convert.ToBoolean(v); }
        private static string Iso(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? "" : Convert.ToDateTime(v).ToString("yyyy-MM-ddTHH:mm:ss", Inv); }

        private static SqlCommand Sp(SqlConnection cn, int accion, Action<SqlParameterCollection> parametros)
        {
            var cmd = new SqlCommand("SYS_SP_Administracion", cn) { CommandType = CommandType.StoredProcedure };
            cmd.Parameters.Add("@accion", SqlDbType.Int).Value = accion;
            cmd.Parameters.Add("@usuarioSesion", SqlDbType.VarChar, 20).Value = (object)Sesion.Usuario ?? DBNull.Value;
            if (parametros != null) parametros(cmd.Parameters);
            return cmd;
        }

        private static List<T> Leer<T>(int accion, Action<SqlParameterCollection> parametros, Func<IDataRecord, T> fila)
        {
            var lista = new List<T>();
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, accion, parametros))
            {
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read()) lista.Add(fila(rd));
            }
            return lista;
        }

        private static long Escalar(int accion, Action<SqlParameterCollection> parametros)
        {
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, accion, parametros))
            {
                cn.Open();
                var v = cmd.ExecuteScalar();
                return v == null || v == DBNull.Value ? 0 : Convert.ToInt64(v);
            }
        }

        private static object Valor(string s) { return string.IsNullOrWhiteSpace(s) ? (object)DBNull.Value : s.Trim(); }

        // ===== Módulos y opciones =====
        public static List<ModuloDto> Modulos()
        {
            return Leer(10, null, r => new ModuloDto
            {
                Id = Num(r, "Id_Modulo"), Descripcion = Txt(r, "Descripcion"), Icono = Txt(r, "Icono"), Orden = Ent(r, "Orden"),
                Opciones = Ent(r, "Opciones"), Usuario = Txt(r, "Usuario"), Fecha = Iso(r, "Fecha")
            });
        }

        public static long GuardarModulo(ModuloDto m)
        {
            return Escalar(11, p =>
            {
                p.Add("@id", SqlDbType.BigInt).Value = m.Id;
                p.Add("@descripcion", SqlDbType.VarChar, 250).Value = Valor(m.Descripcion);
                p.Add("@icono", SqlDbType.VarChar, 50).Value = Valor(m.Icono);
                p.Add("@orden", SqlDbType.Int).Value = m.Orden;
            });
        }

        public static long EliminarModulo(long id) { return Escalar(12, p => p.Add("@id", SqlDbType.BigInt).Value = id); }

        public static List<OpcionMenuDto> Opciones(long modulo)
        {
            return Leer(20, p => p.Add("@modulo", SqlDbType.BigInt).Value = modulo, r => new OpcionMenuDto
            {
                Id = Num(r, "Id_Opcion"), IdModulo = Num(r, "IdModulo_FK"), Descripcion = Txt(r, "Descripcion"), Abreviado = Txt(r, "Abreviado"),
                Url = Txt(r, "AccesoURL"), Orden = Ent(r, "Orden"), Grupos = Ent(r, "Grupos"), Usuario = Txt(r, "Usuario"), Fecha = Iso(r, "Fecha")
            });
        }

        public static long GuardarOpcion(OpcionMenuDto o)
        {
            return Escalar(21, p =>
            {
                p.Add("@id", SqlDbType.BigInt).Value = o.Id;
                p.Add("@modulo", SqlDbType.BigInt).Value = o.IdModulo;
                p.Add("@descripcion", SqlDbType.VarChar, 250).Value = Valor(o.Descripcion);
                p.Add("@abreviado", SqlDbType.VarChar, 10).Value = Valor(o.Abreviado);
                p.Add("@url", SqlDbType.VarChar, 200).Value = Valor(o.Url);
                p.Add("@orden", SqlDbType.Int).Value = o.Orden;
            });
        }

        public static long EliminarOpcion(long id) { return Escalar(22, p => p.Add("@id", SqlDbType.BigInt).Value = id); }

        // ===== Grupos y permisos =====
        public static List<GrupoDto> Grupos()
        {
            return Leer(30, null, r => new GrupoDto
            {
                Id = Txt(r, "Id_Grupo"), Descripcion = Txt(r, "Descripcion"), Usuarios = Ent(r, "Usuarios"), Permisos = Ent(r, "Permisos"),
                Usuario = Txt(r, "Usuario"), Fecha = Iso(r, "Fecha")
            });
        }

        public static long GuardarGrupo(GrupoDto g, bool nuevo)
        {
            return Escalar(31, p =>
            {
                p.Add("@grupo", SqlDbType.VarChar, 20).Value = Valor(g.Id);
                p.Add("@descripcion", SqlDbType.VarChar, 250).Value = Valor(g.Descripcion);
                p.Add("@nuevo", SqlDbType.Bit).Value = nuevo;
            });
        }

        public static long EliminarGrupo(string grupo) { return Escalar(32, p => p.Add("@grupo", SqlDbType.VarChar, 20).Value = Valor(grupo)); }

        public static List<PermisoDto> Permisos(string grupo)
        {
            return Leer(40, p => p.Add("@grupo", SqlDbType.VarChar, 20).Value = Valor(grupo), r => new PermisoDto
            {
                IdModulo = Num(r, "Id_Modulo"), Modulo = Txt(r, "Modulo"), Icono = Txt(r, "Icono"),
                IdOpcion = Num(r, "Id_Opcion"), Opcion = Txt(r, "Opcion"), Url = Txt(r, "AccesoURL"), Tiene = Bit(r, "Tiene")
            });
        }

        /// <summary>modulo = true: id es un módulo y se aplica a todas sus opciones. Devuelve cuántos permisos quedan al grupo.</summary>
        public static long CambiarPermiso(string grupo, long id, bool modulo, bool valor)
        {
            return Escalar(modulo ? 42 : 41, p =>
            {
                p.Add("@grupo", SqlDbType.VarChar, 20).Value = Valor(grupo);
                p.Add("@id", SqlDbType.BigInt).Value = id;
                p.Add("@valor", SqlDbType.Bit).Value = valor;
            });
        }

        // ===== Dashboards =====
        public static List<DashboardConfDto> Dashboards()
        {
            return Leer(50, null, r => new DashboardConfDto
            {
                Id = Num(r, "Id_Dashboard"), Descripcion = Txt(r, "Descripcion"), Url = Txt(r, "DashboardUrl"), Estado = Txt(r, "Estatus"),
                Usuarios = Ent(r, "Usuarios"), Usuario = Txt(r, "Usuario"), Fecha = Iso(r, "Fecha")
            });
        }

        public static long GuardarDashboard(DashboardConfDto d)
        {
            return Escalar(51, p =>
            {
                p.Add("@id", SqlDbType.BigInt).Value = d.Id;
                p.Add("@descripcion", SqlDbType.VarChar, 250).Value = Valor(d.Descripcion);
                p.Add("@url", SqlDbType.VarChar, 200).Value = Valor(d.Url);
                p.Add("@estado", SqlDbType.Char, 1).Value = Valor(d.Estado);
            });
        }

        public static long EliminarDashboard(long id) { return Escalar(52, p => p.Add("@id", SqlDbType.BigInt).Value = id); }

        // ===== Usuarios =====
        private static UsuarioConfDto Usuario(IDataRecord r)
        {
            return new UsuarioConfDto
            {
                Id = Txt(r, "Id_Usuario"), Nombres = Txt(r, "Nombres"), Apellidos = Txt(r, "Apellidos"), IdGrupo = Txt(r, "Id_Grupo_FK"), Grupo = Txt(r, "Grupo"),
                Estado = Txt(r, "EstatusUsuario"), Email = Txt(r, "Email"), Telefono = Txt(r, "Telefono"), Celular = Txt(r, "Celular"),
                Documento = Txt(r, "Documento"), Caducidad = Ent(r, "CaducidadClave"), IdDashboard = Num(r, "Id_Dashboard_FK"), Dashboard = Txt(r, "Dashboard"),
                Responsable = Bit(r, "Responsable"), UltimoIngreso = Iso(r, "FechaInicioSesion"), CambioClave = Iso(r, "FechaCambioclave"),
                Especialista = Txt(r, "Especialista"), Usuario = Txt(r, "Usuario"), Fecha = Iso(r, "Fecha"),
                IdSucursal = Ent(r, "Id_Sucursal_FK"), Sucursal = Txt(r, "Sucursal")
            };
        }

        public static List<UsuarioConfDto> Usuarios() { return Leer(60, null, Usuario); }

        /// <summary>nuevo = true crea el usuario con la clave temporal indicada (el usuario debe cambiarla al entrar).</summary>
        public static long GuardarUsuario(UsuarioConfDto u, bool nuevo, string claveTemporal)
        {
            return Escalar(62, p =>
            {
                p.Add("@nuevo", SqlDbType.Bit).Value = nuevo;
                p.Add("@idUsuario", SqlDbType.VarChar, 20).Value = Valor(u.Id);
                p.Add("@nombres", SqlDbType.VarChar, 200).Value = Valor(u.Nombres);
                p.Add("@apellidos", SqlDbType.VarChar, 200).Value = Valor(u.Apellidos);
                p.Add("@grupo", SqlDbType.VarChar, 20).Value = Valor(u.IdGrupo);
                p.Add("@email", SqlDbType.VarChar, 100).Value = Valor(u.Email);
                p.Add("@telefono", SqlDbType.VarChar, 20).Value = Valor(u.Telefono);
                p.Add("@celular", SqlDbType.VarChar, 20).Value = Valor(u.Celular);
                p.Add("@documento", SqlDbType.VarChar, 20).Value = Valor(u.Documento);
                p.Add("@caducidad", SqlDbType.Int).Value = u.Caducidad;
                p.Add("@dashboard", SqlDbType.BigInt).Value = u.IdDashboard;
                p.Add("@responsable", SqlDbType.Bit).Value = u.Responsable;
                p.Add("@sucursal", SqlDbType.Int).Value = u.IdSucursal;
                p.Add("@clave", SqlDbType.VarChar, 100).Value = nuevo && !string.IsNullOrWhiteSpace(u.Id) ? (object)Utils.HashClave(claveTemporal, true) : DBNull.Value;
            });
        }

        public static long EstadoUsuario(string usuario, bool activo)
        {
            return Escalar(63, p =>
            {
                p.Add("@idUsuario", SqlDbType.VarChar, 20).Value = Valor(usuario);
                p.Add("@estado", SqlDbType.Char, 1).Value = activo ? "A" : "I";
            });
        }

        /// <summary>La clave pasa a ser la temporal indicada (el login le pide cambiarla).</summary>
        public static long RestablecerClave(string usuario, string claveTemporal)
        {
            return Escalar(64, p =>
            {
                p.Add("@idUsuario", SqlDbType.VarChar, 20).Value = Valor(usuario);
                p.Add("@clave", SqlDbType.VarChar, 100).Value = Utils.HashClave(claveTemporal, true);
            });
        }

        public static long EliminarUsuario(string usuario) { return Escalar(65, p => p.Add("@idUsuario", SqlDbType.VarChar, 20).Value = Valor(usuario)); }

        // ===== Empresa =====
        public static EmpresaDto Empresa()
        {
            var lista = Leer(70, null, r => new EmpresaDto
            {
                Id = Num(r, "Id_Configuracion"), Nombre = Txt(r, "NombreEmpresa"), Propietario = Txt(r, "NombrePropietario"), Nrc = Txt(r, "RegistroIVA"),
                Nit = Txt(r, "NumeroNIT"), Dui = Txt(r, "NumeroDUI"), Telefono = Txt(r, "Telefono"), Actividad = Txt(r, "ActividadEconomica"),
                Departamento = Num(r, "Departamento"), Municipio = Num(r, "Municipio"), Direccion = Txt(r, "Direccion"), Email = Txt(r, "Email"),
                Servidor = Txt(r, "Servidor"), Puerto = Ent(r, "Puerto"), TieneClave = Bit(r, "TieneClave"), Usuario = Txt(r, "Usuario"), Fecha = Iso(r, "Fecha")
            });
            return lista.Count > 0 ? lista[0] : new EmpresaDto();
        }

        public static long GuardarEmpresa(EmpresaDto e)
        {
            return Escalar(71, p =>
            {
                p.Add("@nombreEmpresa", SqlDbType.VarChar, 250).Value = Valor(e.Nombre);
                p.Add("@propietario", SqlDbType.VarChar, 250).Value = Valor(e.Propietario);
                p.Add("@nrc", SqlDbType.VarChar, 20).Value = Valor(e.Nrc);
                p.Add("@nit", SqlDbType.VarChar, 20).Value = Valor(e.Nit);
                p.Add("@dui", SqlDbType.VarChar, 20).Value = Valor(e.Dui);
                p.Add("@telefono", SqlDbType.VarChar, 20).Value = Valor(e.Telefono);
                p.Add("@actividad", SqlDbType.VarChar, 500).Value = Valor(e.Actividad);
                p.Add("@departamento", SqlDbType.BigInt).Value = e.Departamento;
                p.Add("@municipio", SqlDbType.BigInt).Value = e.Municipio;
                p.Add("@direccion", SqlDbType.VarChar, -1).Value = Valor(e.Direccion);
                p.Add("@email", SqlDbType.VarChar, 100).Value = Valor(e.Email);
                p.Add("@servidor", SqlDbType.VarChar, 250).Value = Valor(e.Servidor);
                p.Add("@puerto", SqlDbType.Int).Value = e.Puerto;
                // vacío: el SP conserva la clave guardada. Se guarda cifrada igual que la del correo de los DTE.
                p.Add("@clave", SqlDbType.VarChar, 500).Value = string.IsNullOrEmpty(e.ClaveEmail) ? (object)DBNull.Value : Facturacion.DteCorreo.Cifrar(e.ClaveEmail);
            });
        }

        /// <summary>Cuenta "Correo para envíos (SMTP)" de Opciones > Empresa (Sys_ConfiguracionApp), con la clave descifrada.
        /// Solo para uso en el servidor (recuperación de contraseña); nunca se envía al navegador.</summary>
        public class CorreoSmtp
        {
            public string Empresa, Usuario, Clave, Servidor;
            public int Puerto;
            public bool Completo { get { return !string.IsNullOrWhiteSpace(Usuario) && !string.IsNullOrEmpty(Clave) && !string.IsNullOrWhiteSpace(Servidor) && Puerto > 0; } }
        }

        public static CorreoSmtp CorreoEmpresa()
        {
            using (var cn = new SqlConnection(System.Configuration.ConfigurationManager.ConnectionStrings["conexionDiarypro"].ConnectionString))
            using (var cmd = new SqlCommand("select top 1 NombreEmpresa, Email, ClaveEmail, Servidor, Puerto from dbo.Sys_ConfiguracionApp order by Id_Configuracion", cn))
            {
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                {
                    if (!rd.Read()) return null;
                    return new CorreoSmtp
                    {
                        Empresa = Txt(rd, "NombreEmpresa"),
                        Usuario = Txt(rd, "Email"),
                        Clave = Facturacion.DteCorreo.Descifrar(rd["ClaveEmail"] == DBNull.Value ? null : Convert.ToString(rd["ClaveEmail"])),   // acepta también texto (guardada antes de cifrar)
                        Servidor = Txt(rd, "Servidor"),
                        Puerto = Ent(rd, "Puerto")
                    };
                }
            }
        }

        public static List<CatalogoItemDto> Departamentos()
        {
            return Leer(80, null, r => new CatalogoItemDto { Id = Num(r, "Id"), Texto = Txt(r, "Texto") });
        }

        public static List<CatalogoItemDto> Municipios(long departamento)
        {
            return Leer(81, p => p.Add("@departamento", SqlDbType.BigInt).Value = departamento, r => new CatalogoItemDto { Id = Num(r, "Id"), Texto = Txt(r, "Texto") });
        }
    }
}
