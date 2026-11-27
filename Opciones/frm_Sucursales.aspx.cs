using System;
using System.Collections.Generic;
using System.Web.Services;

namespace DPieCenter.Opciones
{
    /// <summary>
    /// Opciones > Sucursales (assets/js/sucursales.js): datos de cada sucursal, su establecimiento para el DTE
    /// y los especialistas que atienden en ella. Reglas en dbo.SUC_SP_Sucursales (Opciones/sql/SUC_Sucursales.sql).
    /// </summary>
    public partial class frm_Sucursales : System.Web.UI.Page
    {
        private const string Url = "Opciones/frm_Sucursales.aspx";

        protected void Page_Load(object sender, EventArgs e) { }

        [WebMethod(EnableSession = true)]
        public static ListaDto<SucursalDto> Lista()
        {
            return AdministracionWeb.Lista(Url, SucursalesRepository.Lista, "No fue posible cargar las sucursales.");
        }

        [WebMethod(EnableSession = true)]
        public static ListaDto<EspecialistaSucursalDto> Especialistas(int sucursal)
        {
            return AdministracionWeb.Lista(Url, () => SucursalesRepository.Especialistas(sucursal), "No fue posible cargar los especialistas.");
        }

        [WebMethod(EnableSession = true)]
        public static RespuestaDto Guardar(SucursalDto sucursal, List<long> especialistas)
        {
            return AdministracionWeb.Accion(Url, () =>
            {
                long id = SucursalesRepository.Guardar(sucursal, Sesion.Usuario);
                SucursalesRepository.AsignarEspecialistas((int)id, especialistas, Sesion.Usuario);
                return id;
            }, sucursal != null && sucursal.Id > 0 ? "Sucursal actualizada." : "Sucursal creada.", "No fue posible guardar la sucursal.");
        }

        [WebMethod(EnableSession = true)]
        public static RespuestaDto Estado(int id, bool activo)
        {
            return AdministracionWeb.Accion(Url, () => { SucursalesRepository.Estado(id, activo, Sesion.Usuario); return id; },
                activo ? "Sucursal activada." : "Sucursal inactivada.", "No fue posible cambiar el estado.");
        }
    }
}
