using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;
using System.IO;
using System.Web;
using DPieCenter.Registros;

namespace DPieCenter.Catalogos
{
    /// <summary>Registro de cualquier catálogo; los campos que no aplican a un catálogo quedan vacíos.</summary>
    public class CatalogoRegistroDto
    {
        public long Id { get; set; }
        public string Descripcion { get; set; }
        public bool Activo { get; set; }
        /// <summary>Cuántos registros lo usan (expedientes, citas, ...). En uso no se puede eliminar.</summary>
        public int Usos { get; set; }
        /// <summary>Departamento del municipio.</summary>
        public long Padre { get; set; }
        /// <summary>Nombre del departamento (municipios) o del usuario vinculado (especialistas).</summary>
        public string PadreTexto { get; set; }
        public string UsuarioSistema { get; set; }
        public string Color { get; set; }
        public bool Procesos { get; set; }
        public bool Cancelada { get; set; }
        public bool Finalizada { get; set; }
        /// <summary>HH:mm</summary>
        public string Hora { get; set; }
        public int Digitos { get; set; }
        public string Formato { get; set; }
        public int Duracion { get; set; }
        public decimal Precio { get; set; }
        /// <summary>Tratamientos: descuento en % (0 = sin descuento).</summary>
        public decimal Descuento { get; set; }
        public string Caracteristicas { get; set; }
        /// <summary>Ruta de la imagen del tratamiento.</summary>
        public string Imagen { get; set; }
        /// <summary>Solo al guardar un tratamiento: imagen nueva en base64 (data URL); "-" quita la imagen; vacío la conserva.</summary>
        public string ImagenNueva { get; set; }
        public string Usuario { get; set; }
        public string Fecha { get; set; }
    }

    public class CatalogoListaDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public List<CatalogoRegistroDto> Items { get; set; }
        /// <summary>Opciones para los combos de la página (departamentos o usuarios del sistema).</summary>
        public List<OpcionDto> Opciones { get; set; }
    }

    public class CatalogoRespuestaDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public long Id { get; set; }
    }

    /// <summary>WebMethods comunes de las páginas de catálogos: sesión, permiso de la opción del menú y acceso a CAT_SP_Catalogos.</summary>
    public static class CatalogosWeb
    {
        private const int LadoImagen = 900;
        private const string CarpetaImagenes = "Catalogos/uploadtratamientos/";

        private static string Permiso(string url)
        {
            if (!Sesion.Activa) return "La sesión expiró. Vuelva a iniciar sesión.";
            if (!Sesion.EsAdministrador && !Sesion.TieneAcceso(url)) return "No tiene permiso para usar este catálogo.";
            return null;
        }

        private static string Detalle(Exception ex, string generico)
        {
            var sql = ex as SqlException;
            if (sql != null && sql.Number >= 50000) return sql.Message;
            if (ex is ArgumentException) return ex.Message;
            System.Diagnostics.Trace.TraceError(generico + ": " + ex);
            bool debug = HttpContext.Current != null && HttpContext.Current.IsDebuggingEnabled;
            return debug ? "[DEBUG] " + ex.GetType().Name + ": " + ex.Message : generico;
        }

        public static CatalogoListaDto Lista(string url, string catalogo, Func<List<OpcionDto>> opciones = null)
        {
            string permiso = Permiso(url);
            if (permiso != null) return new CatalogoListaDto { Ok = false, Mensaje = permiso };
            try
            {
                return new CatalogoListaDto
                {
                    Ok = true,
                    Items = CatalogosRepository.Lista(catalogo),
                    Opciones = opciones != null ? opciones() : new List<OpcionDto>()
                };
            }
            catch (Exception ex) { return new CatalogoListaDto { Ok = false, Mensaje = Detalle(ex, "No fue posible cargar el catálogo.") }; }
        }

        public static CatalogoRespuestaDto Guardar(string url, string catalogo, CatalogoRegistroDto r)
        {
            string permiso = Permiso(url);
            if (permiso != null) return new CatalogoRespuestaDto { Ok = false, Mensaje = permiso };
            if (r == null) return new CatalogoRespuestaDto { Ok = false, Mensaje = "No se recibieron los datos." };
            string archivo = null;
            try
            {
                string imagen = null;     // NULL: el SP conserva la imagen guardada
                if (catalogo == "tratamientos" && !string.IsNullOrEmpty(r.ImagenNueva))
                    imagen = r.ImagenNueva == "-" ? "-" : (archivo = GuardarImagen(r.ImagenNueva));
                long id = CatalogosRepository.Guardar(catalogo, r, Sesion.Usuario, imagen);
                return new CatalogoRespuestaDto { Ok = true, Id = id, Mensaje = r.Id > 0 ? "Registro actualizado." : "Registro agregado." };
            }
            catch (Exception ex)
            {
                // si el SP rechazó los datos, la imagen que se acababa de guardar sobra
                if (archivo != null) try { File.Delete(HttpContext.Current.Server.MapPath("~/" + archivo)); } catch (IOException) { }
                return new CatalogoRespuestaDto { Ok = false, Mensaje = Detalle(ex, "No fue posible guardar.") };
            }
        }

        public static CatalogoRespuestaDto Estado(string url, string catalogo, long id, bool activo)
        {
            string permiso = Permiso(url);
            if (permiso != null) return new CatalogoRespuestaDto { Ok = false, Mensaje = permiso };
            try
            {
                CatalogosRepository.Accion(catalogo, 4, id, activo, Sesion.Usuario);
                return new CatalogoRespuestaDto { Ok = true, Id = id, Mensaje = activo ? "Registro activado." : "Registro inactivado." };
            }
            catch (Exception ex) { return new CatalogoRespuestaDto { Ok = false, Mensaje = Detalle(ex, "No fue posible cambiar el estado.") }; }
        }

        public static CatalogoRespuestaDto Eliminar(string url, string catalogo, long id)
        {
            string permiso = Permiso(url);
            if (permiso != null) return new CatalogoRespuestaDto { Ok = false, Mensaje = permiso };
            try
            {
                CatalogosRepository.Accion(catalogo, 3, id, false, Sesion.Usuario);
                return new CatalogoRespuestaDto { Ok = true, Id = id, Mensaje = "Registro eliminado." };
            }
            catch (Exception ex) { return new CatalogoRespuestaDto { Ok = false, Mensaje = Detalle(ex, "No fue posible eliminar.") }; }
        }

        /// <summary>Reduce la imagen a JPEG de 900 px como máximo y la guarda en Catalogos/uploadtratamientos. Devuelve la ruta relativa.</summary>
        private static string GuardarImagen(string base64)
        {
            byte[] jpeg = ExpedientesService.ImagenJpeg(base64, LadoImagen);
            string nombre = "img_" + DateTime.Now.ToString("ddMMyyyy_HHmmss", CultureInfo.InvariantCulture) + "_" + Guid.NewGuid().ToString("N").Substring(0, 6) + ".jpg";
            string carpeta = HttpContext.Current.Server.MapPath("~/" + CarpetaImagenes);
            Directory.CreateDirectory(carpeta);
            File.WriteAllBytes(Path.Combine(carpeta, nombre), jpeg);
            return CarpetaImagenes + nombre;
        }
    }

    /// <summary>Acceso a dbo.CAT_SP_Catalogos (Catalogos/sql/CAT_Catalogos.sql).</summary>
    public static class CatalogosRepository
    {
        private static string Cn
        {
            get { return ConfigurationManager.ConnectionStrings["conexionDiarypro"].ConnectionString; }
        }

        private static string Txt(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? "" : Convert.ToString(v).Trim(); }
        private static int Ent(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? 0 : Convert.ToInt32(v); }
        private static long Num(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? 0 : Convert.ToInt64(v); }
        private static bool Bit(IDataRecord r, string col) { var v = r[col]; return v != DBNull.Value && Convert.ToBoolean(v); }
        private static object Valor(string s) { return string.IsNullOrWhiteSpace(s) ? (object)DBNull.Value : s.Trim(); }

        private static SqlCommand Sp(SqlConnection cn, string catalogo, int accion)
        {
            var cmd = new SqlCommand("CAT_SP_Catalogos", cn) { CommandType = CommandType.StoredProcedure };
            cmd.Parameters.Add("@catalogo", SqlDbType.VarChar, 30).Value = catalogo;
            cmd.Parameters.Add("@accion", SqlDbType.Int).Value = accion;
            return cmd;
        }

        public static List<CatalogoRegistroDto> Lista(string catalogo)
        {
            var lista = new List<CatalogoRegistroDto>();
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, catalogo, 1))
            {
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                {
                    bool conDescuento = catalogo == "tratamientos";     // solo la lista de tratamientos trae la columna Descuento
                    while (rd.Read())
                    {
                        var hora = rd["Hora"];
                        var fecha = rd["Fecha"];
                        lista.Add(new CatalogoRegistroDto
                        {
                            Id = Num(rd, "Id"), Descripcion = Txt(rd, "Descripcion"), Activo = Bit(rd, "Activo"), Usos = Ent(rd, "Usos"),
                            Padre = Num(rd, "Padre"), PadreTexto = Txt(rd, "PadreTexto"), UsuarioSistema = Txt(rd, "UsuarioSistema"),
                            Color = Txt(rd, "Color"), Procesos = Bit(rd, "Procesos"), Cancelada = Bit(rd, "Cancelada"), Finalizada = Bit(rd, "Finalizada"),
                            Hora = hora == DBNull.Value ? "" : ((TimeSpan)hora).ToString(@"hh\:mm"),
                            Digitos = Ent(rd, "Digitos"), Formato = Txt(rd, "Formato"), Duracion = Ent(rd, "Duracion"),
                            Precio = rd["Precio"] == DBNull.Value ? 0 : Convert.ToDecimal(rd["Precio"]),
                            Caracteristicas = Txt(rd, "Caracteristicas"), Imagen = Txt(rd, "Imagen"), Usuario = Txt(rd, "Usuario"),
                            Fecha = fecha == DBNull.Value ? "" : Convert.ToDateTime(fecha).ToString("yyyy-MM-ddTHH:mm:ss", CultureInfo.InvariantCulture),
                            Descuento = conDescuento && rd["Descuento"] != DBNull.Value ? Convert.ToDecimal(rd["Descuento"]) : 0
                        });
                    }
                }
            }
            return lista;
        }

        /// <summary>imagen: ruta nueva, "-" para quitarla o null para conservarla.</summary>
        public static long Guardar(string catalogo, CatalogoRegistroDto r, string usuario, string imagen)
        {
            TimeSpan hora;
            bool conHora = TimeSpan.TryParseExact(r.Hora ?? "", @"hh\:mm", CultureInfo.InvariantCulture, out hora);
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, catalogo, 2))
            {
                var p = cmd.Parameters;
                p.Add("@usuario", SqlDbType.VarChar, 20).Value = (object)usuario ?? DBNull.Value;
                p.Add("@id", SqlDbType.BigInt).Value = r.Id;
                p.Add("@descripcion", SqlDbType.VarChar, 250).Value = Valor(r.Descripcion);
                p.Add("@activo", SqlDbType.Bit).Value = r.Activo;
                p.Add("@padre", SqlDbType.BigInt).Value = r.Padre;
                p.Add("@usuarioSistema", SqlDbType.VarChar, 20).Value = Valor(r.UsuarioSistema);
                p.Add("@color", SqlDbType.VarChar, 20).Value = Valor(r.Color);
                p.Add("@procesos", SqlDbType.Bit).Value = r.Procesos;
                p.Add("@cancelada", SqlDbType.Bit).Value = r.Cancelada;
                p.Add("@finalizada", SqlDbType.Bit).Value = r.Finalizada;
                p.Add("@hora", SqlDbType.Time).Value = conHora ? (object)hora : DBNull.Value;
                p.Add("@digitos", SqlDbType.Int).Value = r.Digitos;
                p.Add("@formato", SqlDbType.VarChar, 20).Value = Valor(r.Formato);
                p.Add("@duracion", SqlDbType.Int).Value = r.Duracion;
                var precio = p.Add("@precio", SqlDbType.Decimal);
                precio.Precision = 10; precio.Scale = 2; precio.Value = Math.Round(r.Precio, 2);
                p.Add("@caracteristicas", SqlDbType.VarChar, -1).Value = Valor(r.Caracteristicas);
                p.Add("@imagen", SqlDbType.VarChar, 300).Value = (object)imagen ?? DBNull.Value;
                var desc = p.Add("@descuento", SqlDbType.Decimal);
                desc.Precision = 5; desc.Scale = 2; desc.Value = Math.Round(r.Descuento, 2);
                cn.Open();
                var v = cmd.ExecuteScalar();
                return v == null || v == DBNull.Value ? 0 : Convert.ToInt64(v);
            }
        }

        /// <summary>accion 3 eliminar, 4 activar / inactivar.</summary>
        public static void Accion(string catalogo, int accion, long id, bool activo, string usuario)
        {
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, catalogo, accion))
            {
                cmd.Parameters.Add("@usuario", SqlDbType.VarChar, 20).Value = (object)usuario ?? DBNull.Value;
                cmd.Parameters.Add("@id", SqlDbType.BigInt).Value = id;
                cmd.Parameters.Add("@activo", SqlDbType.Bit).Value = activo;
                cn.Open();
                cmd.ExecuteNonQuery();
            }
        }

        /// <summary>Agrega los tipos de comprobante del catálogo CAT-002 de Hacienda que falten. Devuelve cuántos agregó.</summary>
        public static long CargarCat002(string usuario)
        {
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, "tiposfactura", 5))
            {
                cmd.Parameters.Add("@usuario", SqlDbType.VarChar, 20).Value = (object)usuario ?? DBNull.Value;
                cn.Open();
                var v = cmd.ExecuteScalar();
                return v == null || v == DBNull.Value ? 0 : Convert.ToInt64(v);
            }
        }

        /// <summary>Departamentos para el combo de municipios.</summary>
        public static List<OpcionDto> Departamentos()
        {
            var lista = new List<OpcionDto>();
            foreach (var d in Lista("departamentos")) lista.Add(new OpcionDto { Id = d.Id, Texto = d.Descripcion });
            return lista;
        }

        /// <summary>Usuarios activos del sistema para vincularlos a un especialista (Texto = "usuario|nombre").</summary>
        public static List<OpcionDto> UsuariosSistema()
        {
            var lista = new List<OpcionDto>();
            using (var cn = new SqlConnection(Cn))
            using (var cmd = new SqlCommand("select Id_Usuario, LTRIM(RTRIM(ISNULL(Nombres, '') + ' ' + ISNULL(Apellidos, ''))) as Nombre from Sys_Usuarios where EstatusUsuario = 'A' order by Nombres, Apellidos", cn))
            {
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read()) lista.Add(new OpcionDto { Id = 0, Texto = Txt(rd, "Id_Usuario") + "|" + Txt(rd, "Nombre") });
            }
            return lista;
        }
    }
}
