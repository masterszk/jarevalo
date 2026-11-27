using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;
using System.Web;
using System.Web.Services;
using DPieCenter.Registros;

namespace DPieCenter.Dashboard
{
    /// <summary>
    /// Dashboard de los usuarios asignados (Sys_DashboardInicial 4): su día de trabajo (assets/js/dashboard-usuarios.js).
    /// Si el usuario es un especialista ve solo sus citas y procedimientos; si no, la operación de toda la clínica. Sin montos.
    /// </summary>
    public partial class frm_DashboardUsuarios : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {

        }

        [WebMethod(EnableSession = true)]
        public static DashboardUsuarioDto Datos()
        {
            if (!Sesion.Activa) return new DashboardUsuarioDto { Ok = false, Mensaje = "La sesión expiró. Vuelva a iniciar sesión." };

            try
            {
                string usuario = Sesion.Usuario;
                var esp = ProcedimientosRepository.EspecialistaDeUsuario(usuario);   // el especialista sale de la sesión, no del navegador
                var d = DashboardUsuariosRepository.Datos(esp != null ? esp.Id : 0);
                d.Especialista = esp != null ? esp.Texto : "";
                // meta del mes: el especialista ve su avance; el administrador, el de todos. Recepción no ve montos.
                if (esp != null || Sesion.EsAdministrador)
                {
                    var hoy = DateTime.Today;
                    d.Meta = MetasRepository.AvanceMes(hoy.Year, hoy.Month, esp != null ? esp.Id : 0);
                    // meta sugerida del próximo mes, como referencia para el especialista
                    if (esp != null)
                        try
                        {
                            var sig = hoy.AddMonths(1);
                            d.MetaSugerida = MetasRepository.Sugerencias(sig.Year, sig.Month, esp.Id).De(esp.Id);
                        }
                        catch (Exception ex) { System.Diagnostics.Trace.TraceError("Meta sugerida del dashboard: " + ex); }
                }
                d.Nombre = NombreDe(usuario);
                return d;
            }
            catch (Exception ex) { return new DashboardUsuarioDto { Ok = false, Mensaje = Detalle(ex, "No fue posible cargar el dashboard.") }; }
        }

        private static string NombreDe(string usuario)
        {
            try
            {
                using (SqlProcess sql = new SqlProcess())
                    if (sql.mtdSys_Usuario(usuario, "", "", "", "", "", 0, "", "", "", "", 0, "", false, 13) == "OK" && sql.dtReturn.Rows.Count > 0)
                    {
                        DataRow r = sql.dtReturn.Rows[0];
                        string nombre = Convert.ToString(r["Nombres"]).Trim();
                        if (nombre.Length > 0) return nombre;
                    }
            }
            catch (Exception ex) { System.Diagnostics.Trace.TraceError("DashboardUsuarios.NombreDe: " + ex); }
            return usuario;
        }

        private static string Detalle(Exception ex, string generico)
        {
            var sql = ex as SqlException;
            if (sql != null && sql.Number >= 50000) return sql.Message;
            System.Diagnostics.Trace.TraceError("DashboardUsuarios: " + ex);
            bool debug = HttpContext.Current != null && HttpContext.Current.IsDebuggingEnabled;
            return debug ? "[DEBUG] " + ex.Message : generico;
        }
    }

    // ===== Modelos del dashboard de usuarios (Dashboard/frm_DashboardUsuarios.aspx) =====

    public class DashboardUsuarioDto
    {
        public bool Ok { get; set; }
        public string Mensaje { get; set; }
        public string Nombre { get; set; }
        /// <summary>Especialista vinculado al usuario; vacío cuando ve toda la clínica.</summary>
        public string Especialista { get; set; }
        public string Hoy { get; set; }
        public string Actualizado { get; set; }
        public IndicadoresUsuarioDto Indicadores { get; set; }
        public List<CitaUsuarioDto> Agenda { get; set; }
        public List<CitaUsuarioDto> Proximas { get; set; }
        public List<SerieDiaDto> Semana { get; set; }
        public List<SerieDiaDto> Procedimientos30 { get; set; }
        public List<TratamientoConteoDto> Tratamientos { get; set; }
        public List<CumpleanosDto> Cumpleanos { get; set; }
        /// <summary>Garantías de servicios de los últimos 90 días.</summary>
        public List<GarantiaServicioDto> Garantias { get; set; }
        /// <summary>Avance del especialista contra la meta del mes (null si el usuario no es especialista).</summary>
        public MetasMesDto Meta { get; set; }
        /// <summary>Meta sugerida del próximo mes del especialista (referencia).</summary>
        public MetaSugeridaDto MetaSugerida { get; set; }
    }

    public class GarantiaServicioDto
    {
        public long Id { get; set; }
        /// <summary>yyyy-MM-dd</summary>
        public string Fecha { get; set; }
        public string Hora { get; set; }
        public long IdExpediente { get; set; }
        public string Paciente { get; set; }
        public string Celular { get; set; }
        public string Especialista { get; set; }
        /// <summary>yyyy-MM-dd del procedimiento reclamado; vacío si no tiene.</summary>
        public string FechaProcedimiento { get; set; }
        public string Tratamientos { get; set; }
        public string Detalle { get; set; }
        public string Usuario { get; set; }
    }

    public class IndicadoresUsuarioDto
    {
        public int CitasHoy { get; set; }
        public int AtendidasHoy { get; set; }
        public int CanceladasHoy { get; set; }
        public int PorLlegar { get; set; }
        public int EnSala { get; set; }
        public int EnAtencion { get; set; }
        public int ProcedimientosMes { get; set; }
        public int PacientesMes { get; set; }
        public decimal? MinutosPromedio { get; set; }
        public int CitasMes { get; set; }
        public int AtendidasMes { get; set; }
        public int CanceladasMes { get; set; }
        public int ExpedientesMes { get; set; }
    }

    public class CitaUsuarioDto
    {
        public long IdCita { get; set; }
        public long IdExpediente { get; set; }
        /// <summary>yyyy-MM-dd</summary>
        public string Fecha { get; set; }
        /// <summary>HH:mm; vacío si la cita no tiene hora.</summary>
        public string Hora { get; set; }
        public string HoraFin { get; set; }
        public string Paciente { get; set; }
        public string Celular { get; set; }
        public string Especialista { get; set; }
        public string TipoCita { get; set; }
        public string Estado { get; set; }
        public string Color { get; set; }
        public long IdEstado { get; set; }
        /// <summary>S en sala, I en atención, F finalizado; vacío si aún no llega.</summary>
        public string EstadoProcedimiento { get; set; }
        /// <summary>Minutos en sala de espera (solo con EstadoProcedimiento = S).</summary>
        public int? MinutosEspera { get; set; }
    }

    public class SerieDiaDto
    {
        public string Dia { get; set; }
        public int Cantidad { get; set; }
        public int Confirmadas { get; set; }
    }

    public class TratamientoConteoDto
    {
        public string Descripcion { get; set; }
        public int Cantidad { get; set; }
    }

    public class CumpleanosDto
    {
        public long IdExpediente { get; set; }
        public string Paciente { get; set; }
        public string Celular { get; set; }
        public string Cumple { get; set; }
        public int Edad { get; set; }
        public bool EsHoy { get; set; }
    }

    /// <summary>Acceso a dbo.REP_SP_DashboardUsuario (Dashboard/sql/REP_Dashboard_Usuarios.sql).</summary>
    public static class DashboardUsuariosRepository
    {
        private static readonly CultureInfo Inv = CultureInfo.InvariantCulture;

        private static string Cn
        {
            get { return ConfigurationManager.ConnectionStrings["conexionDiarypro"].ConnectionString; }
        }

        private static string Txt(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? "" : Convert.ToString(v).Trim(); }
        private static int Ent(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? 0 : Convert.ToInt32(v); }
        private static long Num(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? 0 : Convert.ToInt64(v); }
        private static DateTime? Fecha(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? (DateTime?)null : Convert.ToDateTime(v); }
        private static string Dia(DateTime? d) { return d.HasValue ? d.Value.ToString("yyyy-MM-dd", Inv) : ""; }
        // Las citas sin hora quedan a las 00:00. Va en 24 h porque la pantalla la compara con la hora actual;
        // dashboard-usuarios.js la muestra en 12 h con hora12()
        private static string Hora(DateTime? d) { return d.HasValue && d.Value.TimeOfDay.TotalMinutes > 0 ? d.Value.ToString("HH:mm", Inv) : ""; }

        /// <summary>especialista = 0: toda la clínica.</summary>
        public static DashboardUsuarioDto Datos(long especialista)
        {
            DateTime ahora = DateTime.Now;
            var d = new DashboardUsuarioDto
            {
                Ok = true,
                Hoy = ahora.ToString("yyyy-MM-dd", Inv),
                Actualizado = Formato.Hora(ahora),
                Indicadores = new IndicadoresUsuarioDto(),
                Agenda = new List<CitaUsuarioDto>(),
                Proximas = new List<CitaUsuarioDto>(),
                Semana = new List<SerieDiaDto>(),
                Procedimientos30 = new List<SerieDiaDto>(),
                Tratamientos = new List<TratamientoConteoDto>(),
                Cumpleanos = new List<CumpleanosDto>(),
                Garantias = new List<GarantiaServicioDto>()
            };

            using (var cn = new SqlConnection(Cn))
            {
                cn.Open();
                Action<int, Action<IDataRecord>> leer = (accion, fila) =>
                {
                    using (var cmd = new SqlCommand("REP_SP_DashboardUsuario", cn) { CommandType = CommandType.StoredProcedure })
                    {
                        cmd.Parameters.Add("@accion", SqlDbType.Int).Value = accion;
                        cmd.Parameters.Add("@especialista", SqlDbType.BigInt).Value = especialista;
                        cmd.Parameters.Add("@sucursal", SqlDbType.Int).Value = Sesion.Sucursal;      // operación de la sucursal en la que trabaja
                        using (var rd = cmd.ExecuteReader())
                            while (rd.Read()) fila(rd);
                    }
                };

                leer(1, r =>
                {
                    var minutos = r["MinutosPromedio"];
                    d.Indicadores = new IndicadoresUsuarioDto
                    {
                        CitasHoy = Ent(r, "CitasHoy"),
                        AtendidasHoy = Ent(r, "AtendidasHoy"),
                        CanceladasHoy = Ent(r, "CanceladasHoy"),
                        PorLlegar = Ent(r, "PorLlegar"),
                        EnSala = Ent(r, "EnSala"),
                        EnAtencion = Ent(r, "EnAtencion"),
                        ProcedimientosMes = Ent(r, "ProcedimientosMes"),
                        PacientesMes = Ent(r, "PacientesMes"),
                        MinutosPromedio = minutos == DBNull.Value ? (decimal?)null : Math.Round(Convert.ToDecimal(minutos), 1),
                        CitasMes = Ent(r, "CitasMes"),
                        AtendidasMes = Ent(r, "AtendidasMes"),
                        CanceladasMes = Ent(r, "CanceladasMes"),
                        ExpedientesMes = Ent(r, "ExpedientesMes")
                    };
                });

                leer(2, r =>
                {
                    var cita = Cita(r);
                    cita.HoraFin = Hora(Fecha(r, "Fin"));
                    cita.TipoCita = Txt(r, "TipoCita");
                    cita.IdEstado = Num(r, "Id_Estado");
                    cita.EstadoProcedimiento = Txt(r, "EstadoProcedimiento");
                    var enSala = Fecha(r, "EnSalaDesde");
                    if (cita.EstadoProcedimiento == "S" && enSala.HasValue)
                        cita.MinutosEspera = Math.Max(0, (int)(ahora - enSala.Value).TotalMinutes);
                    d.Agenda.Add(cita);
                });

                leer(3, r => d.Semana.Add(new SerieDiaDto { Dia = Dia(Fecha(r, "Dia")), Cantidad = Ent(r, "Citas"), Confirmadas = Ent(r, "Confirmadas") }));
                leer(4, r => d.Procedimientos30.Add(new SerieDiaDto { Dia = Dia(Fecha(r, "Dia")), Cantidad = Ent(r, "Procedimientos") }));
                leer(5, r => d.Tratamientos.Add(new TratamientoConteoDto { Descripcion = Txt(r, "Descripcion"), Cantidad = Ent(r, "Cantidad") }));
                leer(6, r => d.Proximas.Add(Cita(r)));
                leer(7, r =>
                {
                    var cumple = Fecha(r, "Cumple");
                    d.Cumpleanos.Add(new CumpleanosDto
                    {
                        IdExpediente = Num(r, "Id_Expediente"),
                        Paciente = Txt(r, "Paciente"),
                        Celular = Txt(r, "Celular"),
                        Cumple = Dia(cumple),
                        Edad = Ent(r, "Edad"),
                        EsHoy = cumple.HasValue && cumple.Value.Date == ahora.Date
                    });
                });
                leer(8, r =>
                {
                    var f = Fecha(r, "Fecha");
                    d.Garantias.Add(new GarantiaServicioDto
                    {
                        Id = Num(r, "Id_Reclamo"),
                        Fecha = Dia(f),
                        Hora = f.HasValue ? Formato.Hora(f.Value) : "",
                        IdExpediente = Num(r, "Id_Expediente"),
                        Paciente = Txt(r, "Paciente"),
                        Celular = Txt(r, "Celular"),
                        Especialista = Txt(r, "Especialista"),
                        FechaProcedimiento = Dia(Fecha(r, "FechaProcedimiento")),
                        Tratamientos = Txt(r, "Tratamientos"),
                        Detalle = Txt(r, "Detalle"),
                        Usuario = Txt(r, "Usuario")
                    });
                });
            }
            return d;
        }

        private static CitaUsuarioDto Cita(IDataRecord r)
        {
            var inicio = Fecha(r, "Inicio");
            return new CitaUsuarioDto
            {
                IdCita = Num(r, "Id_Cita"),
                IdExpediente = Num(r, "Id_Expediente"),
                Fecha = Dia(inicio),
                Hora = Hora(inicio),
                Paciente = Txt(r, "Paciente"),
                Celular = Txt(r, "Celular"),
                Especialista = Txt(r, "Especialista"),
                Estado = Txt(r, "Estado"),
                Color = Txt(r, "Color")
            };
        }
    }
}
