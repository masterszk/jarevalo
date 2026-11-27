using System;
using System.Collections.Generic;
using System.Web.Services;

namespace DPieCenter.Opciones
{
    /// <summary>
    /// Datos generales de la empresa (assets/js/conf-empresa.js).
    /// La clave del correo nunca se envía al navegador: al guardar, vacía conserva la guardada.
    /// </summary>
    public partial class form_confEmpresa : System.Web.UI.Page
    {
        private const string Url = "Opciones/form_confEmpresa.aspx";

        protected void Page_Load(object sender, EventArgs e)
        {

        }

        public class InicioEmpresaDto
        {
            public bool Ok { get; set; }
            public string Mensaje { get; set; }
            public EmpresaDto Empresa { get; set; }
            public List<CatalogoItemDto> Departamentos { get; set; }
            public List<CatalogoItemDto> Municipios { get; set; }
        }

        [WebMethod(EnableSession = true)]
        public static InicioEmpresaDto Inicio()
        {
            string permiso = AdministracionWeb.Permiso(Url);
            if (permiso != null) return new InicioEmpresaDto { Ok = false, Mensaje = permiso };
            try
            {
                var e = AdministracionRepository.Empresa();
                return new InicioEmpresaDto
                {
                    Ok = true,
                    Empresa = e,
                    Departamentos = AdministracionRepository.Departamentos(),
                    Municipios = e.Departamento > 0 ? AdministracionRepository.Municipios(e.Departamento) : new List<CatalogoItemDto>()
                };
            }
            catch (Exception ex) { return new InicioEmpresaDto { Ok = false, Mensaje = AdministracionWeb.Detalle(ex, "No fue posible cargar los datos de la empresa.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static ListaDto<CatalogoItemDto> Municipios(long departamento)
        {
            return AdministracionWeb.Lista(Url, () => AdministracionRepository.Municipios(departamento), "No fue posible cargar los municipios.");
        }

        // ===== Facturación electrónica (antes Facturacion/frm_EmpresaDte.aspx; assets/js/empresa-dte.js) =====

        [WebMethod(EnableSession = true)]
        public static Facturacion.EmpresaResultadoDto ObtenerEmpresa(string user)
        {
            string permiso = AdministracionWeb.Permiso(Url);
            if (permiso != null) return new Facturacion.EmpresaResultadoDto { Ok = false, Mensaje = permiso };
            try
            {
                var e = Facturacion.DteRepository.ObtenerEmpresa();
                return new Facturacion.EmpresaResultadoDto { Ok = true, Empresa = e, Mensaje = e == null ? "Aún no hay datos registrados." : "" };
            }
            catch (Exception ex) { return new Facturacion.EmpresaResultadoDto { Ok = false, Mensaje = AdministracionWeb.Detalle(ex, "No fue posible cargar los datos de facturación electrónica.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static Facturacion.EmpresaResultadoDto GuardarEmpresa(Facturacion.EmpresaDteDto empresa)
        {
            string permiso = AdministracionWeb.Permiso(Url);
            if (permiso != null) return new Facturacion.EmpresaResultadoDto { Ok = false, Mensaje = permiso };
            if (empresa == null) return new Facturacion.EmpresaResultadoDto { Ok = false, Mensaje = "No se recibieron los datos." };
            empresa.Usuario = Sesion.Usuario;
            try { return Facturacion.DteService.GuardarEmpresa(empresa); }
            catch (Exception ex) { return new Facturacion.EmpresaResultadoDto { Ok = false, Mensaje = AdministracionWeb.Detalle(ex, "No fue posible guardar los datos de facturación electrónica.") }; }
        }

        // ===== Generador de firma de Hacienda (assets/js/firma-dte.js) =====

        [WebMethod(EnableSession = true)]
        public static Facturacion.FirmadorDto Firmador()
        {
            string permiso = AdministracionWeb.Permiso(Url);
            if (permiso != null) return new Facturacion.FirmadorDto { Ok = false, Mensaje = permiso };
            try { return Facturacion.DteFirmador.Consultar(); }
            catch (Exception ex) { return new Facturacion.FirmadorDto { Ok = false, Mensaje = AdministracionWeb.Detalle(ex, "No fue posible cargar el firmador.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static Facturacion.FirmadorDto GuardarFirmador(Facturacion.FirmadorDto firmador)
        {
            string permiso = AdministracionWeb.Permiso(Url);
            if (permiso != null) return new Facturacion.FirmadorDto { Ok = false, Mensaje = permiso };
            if (firmador == null) return new Facturacion.FirmadorDto { Ok = false, Mensaje = "No se recibieron los datos." };
            if (firmador.Clave != null && firmador.Clave.Length > 200) return new Facturacion.FirmadorDto { Ok = false, Mensaje = "La contraseña es demasiado larga." };
            try
            {
                Facturacion.DteFirmador.Guardar(firmador, Sesion.Usuario);
                var f = Facturacion.DteFirmador.Consultar();
                f.Mensaje = "Datos del firmador guardados.";
                return f;
            }
            catch (Exception ex) { return new Facturacion.FirmadorDto { Ok = false, Mensaje = AdministracionWeb.Detalle(ex, "No fue posible guardar el firmador.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static Facturacion.FirmadorDto ProbarFirmador()
        {
            string permiso = AdministracionWeb.Permiso(Url);
            if (permiso != null) return new Facturacion.FirmadorDto { Ok = false, Mensaje = permiso };
            try { return Facturacion.DteFirmador.Probar(Sesion.Usuario); }
            catch (Exception ex) { return new Facturacion.FirmadorDto { Ok = false, Mensaje = AdministracionWeb.Detalle(ex, "No fue posible probar el firmador.") }; }
        }

        [WebMethod(EnableSession = true)]
        public static RespuestaDto Guardar(EmpresaDto empresa)
        {
            if (empresa == null) return new RespuestaDto { Ok = false, Mensaje = "No se recibieron los datos." };
            return AdministracionWeb.Accion(Url, () => AdministracionRepository.GuardarEmpresa(empresa),
                "Datos de la empresa guardados.", "No fue posible guardar los datos de la empresa.");
        }
    }
}
