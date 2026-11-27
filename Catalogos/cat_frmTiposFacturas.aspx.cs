using System;
using System.Web.Services;

namespace DPieCenter.Catalogos
{
    /// <summary>
    /// Tipos de comprobante (catálogo CAT-002 de Hacienda) con assets/js/catalogo.js. El código de Hacienda viaja en el campo Formato.
    /// La caja emite 01 (factura) y 03 (crédito fiscal): esos no se pueden inactivar ni eliminar.
    /// </summary>
    public partial class cat_frmTiposFacturas : System.Web.UI.Page
    {
        private const string Url = "Catalogos/cat_frmTiposFacturas.aspx";
        private const string Catalogo = "tiposfactura";

        protected void Page_Load(object sender, EventArgs e)
        {

        }

        [WebMethod(EnableSession = true)]
        public static CatalogoListaDto Lista() { return CatalogosWeb.Lista(Url, Catalogo); }

        [WebMethod(EnableSession = true)]
        public static CatalogoRespuestaDto Guardar(CatalogoRegistroDto registro) { return CatalogosWeb.Guardar(Url, Catalogo, registro); }

        [WebMethod(EnableSession = true)]
        public static CatalogoRespuestaDto Estado(long id, bool activo) { return CatalogosWeb.Estado(Url, Catalogo, id, activo); }

        [WebMethod(EnableSession = true)]
        public static CatalogoRespuestaDto Eliminar(long id) { return CatalogosWeb.Eliminar(Url, Catalogo, id); }

        /// <summary>Agrega los tipos del catálogo CAT-002 de Hacienda que no estén registrados.</summary>
        [WebMethod(EnableSession = true)]
        public static CatalogoRespuestaDto CargarCat002()
        {
            if (!Sesion.Activa) return new CatalogoRespuestaDto { Ok = false, Mensaje = "La sesión expiró. Vuelva a iniciar sesión." };
            if (!Sesion.EsAdministrador && !Sesion.TieneAcceso(Url)) return new CatalogoRespuestaDto { Ok = false, Mensaje = "No tiene permiso para usar este catálogo." };
            try
            {
                long n = CatalogosRepository.CargarCat002(Sesion.Usuario);
                return new CatalogoRespuestaDto { Ok = true, Id = n, Mensaje = n == 0 ? "Ya están todos los tipos del catálogo CAT-002." : "Se agregaron " + n + " tipos del catálogo CAT-002." };
            }
            catch (Exception ex)
            {
                System.Diagnostics.Trace.TraceError("CargarCat002: " + ex);
                return new CatalogoRespuestaDto { Ok = false, Mensaje = "No fue posible cargar el catálogo." };
            }
        }
    }
}
