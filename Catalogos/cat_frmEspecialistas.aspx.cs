using System;
using System.Web.Services;

namespace DPieCenter.Catalogos
{
    /// <summary>Catálogo de especialistas (assets/js/catalogo.js). La lógica común está en CatalogosRepository.cs.</summary>
    public partial class cat_frmEspecialistas : System.Web.UI.Page
    {
        private const string Url = "Catalogos/cat_frmEspecialistas.aspx";
        private const string Catalogo = "especialistas";

        protected void Page_Load(object sender, EventArgs e)
        {

        }

        [WebMethod(EnableSession = true)]
        public static CatalogoListaDto Lista() { return CatalogosWeb.Lista(Url, Catalogo, CatalogosRepository.UsuariosSistema); }

        [WebMethod(EnableSession = true)]
        public static CatalogoRespuestaDto Guardar(CatalogoRegistroDto registro) { return CatalogosWeb.Guardar(Url, Catalogo, registro); }

        [WebMethod(EnableSession = true)]
        public static CatalogoRespuestaDto Estado(long id, bool activo) { return CatalogosWeb.Estado(Url, Catalogo, id, activo); }

        [WebMethod(EnableSession = true)]
        public static CatalogoRespuestaDto Eliminar(long id) { return CatalogosWeb.Eliminar(Url, Catalogo, id); }
    }
}
