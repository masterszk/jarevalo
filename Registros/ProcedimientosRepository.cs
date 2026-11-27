using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;
using System.Linq;

namespace DPieCenter.Registros
{
    /// <summary>Acceso a dbo.EXP_SP_Procedimientos_Atencion (Registros/sql/EXP_Procedimientos_Atencion.sql).</summary>
    public static class ProcedimientosRepository
    {
        private const string Proc = "dbo.EXP_SP_Procedimientos_Atencion";
        private static readonly CultureInfo Inv = CultureInfo.InvariantCulture;

        private static string Cn
        {
            get { return ConfigurationManager.ConnectionStrings["conexionDiarypro"].ConnectionString; }
        }

        private static SqlCommand Sp(SqlConnection cn, int accion, string usuario)
        {
            var cmd = new SqlCommand(Proc, cn) { CommandType = CommandType.StoredProcedure };
            cmd.Parameters.Add("@accion", SqlDbType.Int).Value = accion;
            cmd.Parameters.Add("@user", SqlDbType.VarChar, 20).Value = (object)usuario ?? DBNull.Value;
            return cmd;
        }

        private static string Txt(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? "" : Convert.ToString(v).Trim(); }
        private static long Num(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? 0 : Convert.ToInt64(v); }
        private static decimal Dec(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? 0 : Convert.ToDecimal(v); }
        private static DateTime? Fecha(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? (DateTime?)null : Convert.ToDateTime(v); }
        private static string Iso(DateTime? d) { return d.HasValue ? d.Value.ToString("yyyy-MM-ddTHH:mm:ss", Inv) : ""; }
        private static string Hora(DateTime? d) { return Formato.Hora(d); }

        // Ejecuta una acción que devuelve un solo valor (Id).
        // usuarioEsp: especialista del usuario; el SP rechaza citas o procedimientos de otro especialista (0 = sin restricción)
        private static long Escalar(int accion, string usuario, long usuarioEsp, Action<SqlParameterCollection> parametros)
        {
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, accion, usuario))
            {
                cmd.Parameters.Add("@usuarioEsp", SqlDbType.BigInt).Value = usuarioEsp;
                parametros(cmd.Parameters);
                cn.Open();
                var v = cmd.ExecuteScalar();
                return v == null || v == DBNull.Value ? 0 : Convert.ToInt64(v);
            }
        }

        // ===== Consultas =====
        public static OpcionDto EspecialistaDeUsuario(string usuario)
        {
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, 1, usuario))
            {
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    return rd.Read() ? new OpcionDto { Id = Num(rd, "Id_Especialista"), Texto = Txt(rd, "Descripcion") } : null;
            }
        }

        /// <summary>Citas activas de hoy (especialista = 0: todos), con el tiempo de espera y el siguiente de cada especialista.</summary>
        /// <param name="sucursal">0 = todas las sucursales.</param>
        public static List<ColaItemDto> Cola(long especialista, int sucursal)
        {
            var lista = new List<ColaItemDto>();
            DateTime ahora = DateTime.Now;
            DateTime horaActual = DateTime.Today.AddHours(ahora.Hour);
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, 2, null))
            {
                cmd.Parameters.Add("@especialista", SqlDbType.BigInt).Value = especialista;
                cmd.Parameters.Add("@sucursal", SqlDbType.Int).Value = sucursal;
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                    {
                        var inicio = Fecha(rd, "FechaInicio");
                        string estado = Txt(rd, "Estado");
                        var desde = estado == "S" ? (Fecha(rd, "RegistroProcedimiento") ?? inicio) : inicio;
                        var nac = Fecha(rd, "FechaNacimiento");
                        if (nac.HasValue && (nac.Value.Year < 1900 || nac.Value > DateTime.Today)) nac = null;
                        lista.Add(new ColaItemDto
                        {
                            IdCita = Num(rd, "Id_Cita"),
                            Hora = Hora(inicio),
                            HoraFin = Hora(Fecha(rd, "FechaFin")),
                            IdEspecialista = Num(rd, "Id_Especialista"),
                            Especialista = Txt(rd, "Especialista"),
                            EspecialistaCompleto = Txt(rd, "EspecialistaCompleto"),
                            IdExpediente = Num(rd, "Id_Expediente"),
                            Nombres = Txt(rd, "Nombres"),
                            Apellidos = Txt(rd, "Apellidos"),
                            Paciente = (Txt(rd, "Nombres") + " " + Txt(rd, "Apellidos")).Trim(),
                            FechaNacimiento = nac.HasValue ? nac.Value.ToString("dd/MM/yyyy", Inv) : "",
                            Edad = nac.HasValue ? EdadEnAnios(nac.Value).ToString(Inv) : "",
                            TipoCita = Txt(rd, "TipoCita"),
                            EstadoCita = Txt(rd, "EstadoCita"),
                            IdProcedimiento = Num(rd, "Id_Procedimiento"),
                            Estado = estado,
                            InicioAtencion = estado == "I" ? Iso(Fecha(rd, "InicioProcedimiento")) : "",
                            Tratamientos = Txt(rd, "Tratamientos"),
                            // la hora de la cita ya pasó y el paciente no ha sido atendido
                            Atrasada = estado != "I" && inicio.HasValue && inicio.Value < horaActual,
                            Inicio = inicio,
                            EsperaDesde = estado == "I" ? null : desde,
                            EsperaMin = estado != "I" && desde.HasValue && desde.Value < ahora ? (int)(ahora - desde.Value).TotalMinutes : 0
                        });
                    }
            }
            MarcarSiguientes(lista, ahora);
            return lista;
        }

        /// <summary>
        /// Siguiente de cada especialista: el que lleva más tiempo esperando (llegó a sala o ya pasó la hora de su cita).
        /// Si nadie está esperando todavía, el de la cita más próxima.
        /// </summary>
        private static void MarcarSiguientes(List<ColaItemDto> lista, DateTime ahora)
        {
            foreach (var grupo in lista.Where(c => c.Estado != "I").GroupBy(c => c.IdEspecialista))
            {
                var siguiente = grupo.Where(c => c.EsperaDesde.HasValue && c.EsperaDesde.Value <= ahora)
                                     .OrderBy(c => c.EsperaDesde.Value).ThenBy(c => c.Inicio).FirstOrDefault()
                                ?? grupo.OrderBy(c => c.Inicio ?? DateTime.MaxValue).First();
                siguiente.Sigue = true;
            }
        }

        /// <summary>Procedimientos abiertos (en sala o en atención) de todos los especialistas, incluidos los de días anteriores.</summary>
        public static List<ProcedimientoCursoDto> EnCurso(long especialista, int sucursal)
        {
            var lista = new List<ProcedimientoCursoDto>();
            DateTime ahora = DateTime.Now;
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, 14, null))
            {
                cmd.Parameters.Add("@especialista", SqlDbType.BigInt).Value = especialista;
                cmd.Parameters.Add("@sucursal", SqlDbType.Int).Value = sucursal;
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                    {
                        string estado = Txt(rd, "Estado");
                        var cita = Fecha(rd, "FechaInicio");
                        var registro = Fecha(rd, "RegistroProcedimiento");
                        var inicio = Fecha(rd, "InicioProcedimiento");
                        // los procedimientos antiguos guardaban solo la hora de inicio (1900-01-01)
                        if (inicio.HasValue && inicio.Value.Year < 2000)
                            inicio = (registro ?? cita ?? ahora).Date + inicio.Value.TimeOfDay;
                        var desde = estado == "I" ? inicio : (registro ?? cita);
                        var dia = (cita ?? desde ?? ahora).Date;
                        lista.Add(new ProcedimientoCursoDto
                        {
                            IdProcedimiento = Num(rd, "Id_Procedimiento"),
                            IdCita = Num(rd, "Id_Cita"),
                            Estado = estado,
                            Fecha = dia.ToString("dd/MM/yyyy", Inv),
                            DeOtroDia = dia < ahora.Date,
                            HoraCita = cita.HasValue && cita.Value.TimeOfDay != TimeSpan.Zero ? Formato.Hora(cita.Value) : "",
                            InicioAtencion = estado == "I" ? Formato.Hora(inicio) : "",
                            Minutos = desde.HasValue && desde.Value < ahora ? (int)(ahora - desde.Value).TotalMinutes : 0,
                            IdEspecialista = Num(rd, "Id_Especialista"),
                            Especialista = Txt(rd, "Especialista"),
                            IdExpediente = Num(rd, "Id_Expediente"),
                            Paciente = Txt(rd, "Paciente"),
                            Documento = Txt(rd, "Documento"),
                            Celular = Txt(rd, "Celular"),
                            TipoCita = Txt(rd, "TipoCita"),
                            Tratamientos = (int)Num(rd, "Tratamientos"),
                            Detalle = Txt(rd, "Detalle"),
                            Total = Dec(rd, "Total")
                        });
                    }
            }
            return lista;
        }

        /// <summary>El paciente con más tiempo de espera del especialista, o null si no hay pendientes.</summary>
        public static ColaItemDto Siguiente(long especialista)
        {
            return Cola(especialista, Sesion.Sucursal).Where(c => c.Sigue).FirstOrDefault();
        }

        public static ProcedimientoDto Procedimiento(long procedimiento)
        {
            ProcedimientoDto d = null;
            using (var cn = new SqlConnection(Cn))
            {
                cn.Open();
                using (var cmd = Sp(cn, 3, null))
                {
                    cmd.Parameters.Add("@procedimiento", SqlDbType.BigInt).Value = procedimiento;
                    using (var rd = cmd.ExecuteReader())
                        if (rd.Read())
                        {
                            var nac = Fecha(rd, "FechaNacimiento");
                            string estado = Txt(rd, "Estado");
                            d = new ProcedimientoDto
                            {
                                Ok = true,
                                IdProcedimiento = Num(rd, "Id_Procedimiento"),
                                IdCita = Num(rd, "Id_Cita"),
                                IdExpediente = Num(rd, "Id_Expediente"),
                                Estado = estado,
                                InicioAtencion = estado == "I" ? Iso(Fecha(rd, "InicioProcedimiento")) : "",
                                HoraCita = Hora(Fecha(rd, "FechaInicio")) + (Fecha(rd, "FechaFin").HasValue ? " - " + Hora(Fecha(rd, "FechaFin")) : ""),
                                Comentarios = Txt(rd, "Comentarios"),
                                Diagnostico = Txt(rd, "Diagnostico"),
                                IdEspecialista = Num(rd, "Id_Especialista"),
                                Especialista = Txt(rd, "Especialista"),
                                TipoCita = Txt(rd, "TipoCita"),
                                Paciente = Txt(rd, "Paciente"),
                                Documento = Txt(rd, "Documento"),
                                FechaNacimiento = nac.HasValue ? nac.Value.ToString("dd/MM/yyyy", Inv) : "",
                                Edad = nac.HasValue ? EdadEnAnios(nac.Value).ToString(Inv) : "",
                                Sexo = Txt(rd, "Sexo"),
                                Celular = Txt(rd, "Celular"),
                                Email = Txt(rd, "Email"),
                                PersonaEmergencia = Txt(rd, "PersonaEmergencia"),
                                TelefonoEmergencia = Txt(rd, "TelefonoEmergencia"),
                                Direccion = Txt(rd, "Direccion").Trim(' ', ',')
                            };
                        }
                }
                if (d == null) return null;

                d.Tratamientos = new List<TratamientoProcDto>();
                using (var cmd = Sp(cn, 4, null))
                {
                    cmd.Parameters.Add("@procedimiento", SqlDbType.BigInt).Value = procedimiento;
                    using (var rd = cmd.ExecuteReader())
                        while (rd.Read())
                            d.Tratamientos.Add(new TratamientoProcDto
                            {
                                Id = Num(rd, "Id"),
                                IdTratamiento = Num(rd, "Id_Tratamiento"),
                                Descripcion = Txt(rd, "Descripcion"),
                                Valor = Dec(rd, "Valor")
                            });
                }
                // Descuento vigente de cada tratamiento (Catálogos › Tratamientos); el total es lo que se cobrará
                var desc = Facturacion.DescuentosTratamiento.Vigentes();
                foreach (var t in d.Tratamientos)
                {
                    t.Descuento = Facturacion.DescuentosTratamiento.Porcentaje(desc, t.IdTratamiento);
                    t.MontoDescuento = Facturacion.DescuentosTratamiento.Monto(t.Valor, t.Descuento);
                    d.Descuento += t.MontoDescuento;
                    d.Total += t.Valor - t.MontoDescuento;
                }

                d.Historial = new List<HistorialDto>();
                using (var cmd = Sp(cn, 5, null))
                {
                    cmd.Parameters.Add("@expediente", SqlDbType.BigInt).Value = d.IdExpediente;
                    cmd.Parameters.Add("@procedimiento", SqlDbType.BigInt).Value = procedimiento;
                    using (var rd = cmd.ExecuteReader())
                        while (rd.Read())
                        {
                            var f = Fecha(rd, "Fecha");
                            d.Historial.Add(new HistorialDto
                            {
                                IdProcedimiento = Num(rd, "Id_Procedimiento"),
                                Fecha = Formato.FechaHora(f),
                                Especialista = Txt(rd, "Especialista"),
                                Diagnostico = Txt(rd, "Diagnostico"),
                                Tratamientos = Txt(rd, "Tratamientos"),
                                Total = Dec(rd, "Total")
                            });
                        }
                }
            }
            return d;
        }

        private static int EdadEnAnios(DateTime nacimiento)
        {
            var hoy = DateTime.Today;
            int edad = hoy.Year - nacimiento.Year;
            if (nacimiento.Date > hoy.AddYears(-edad)) edad--;
            return Math.Max(edad, 0);
        }

        // ===== Acciones =====
        public static long Llamar(long cita, string usuario, long usuarioEsp)
        {
            return Escalar(6, usuario, usuarioEsp, p => p.Add("@cita", SqlDbType.BigInt).Value = cita);
        }

        public static long AgregarTratamiento(long procedimiento, long tratamiento, string usuario, long usuarioEsp)
        {
            return Escalar(7, usuario, usuarioEsp, p =>
            {
                p.Add("@procedimiento", SqlDbType.BigInt).Value = procedimiento;
                p.Add("@item", SqlDbType.BigInt).Value = tratamiento;
            });
        }

        public static long QuitarTratamiento(long procedimiento, long item, string usuario, long usuarioEsp)
        {
            return Escalar(8, usuario, usuarioEsp, p =>
            {
                p.Add("@procedimiento", SqlDbType.BigInt).Value = procedimiento;
                p.Add("@item", SqlDbType.BigInt).Value = item;
            });
        }

        public static void GuardarDiagnostico(long procedimiento, string diagnostico, string usuario, long usuarioEsp)
        {
            Escalar(9, usuario, usuarioEsp, p =>
            {
                p.Add("@procedimiento", SqlDbType.BigInt).Value = procedimiento;
                p.Add("@texto", SqlDbType.VarChar, -1).Value = (object)diagnostico ?? DBNull.Value;
            });
        }

        /// <summary>Finaliza y devuelve el Id de la factura pendiente de cobro.</summary>
        public static long Finalizar(long procedimiento, string diagnostico, string usuario, long usuarioEsp)
        {
            return Escalar(10, usuario, usuarioEsp, p =>
            {
                p.Add("@procedimiento", SqlDbType.BigInt).Value = procedimiento;
                p.Add("@texto", SqlDbType.VarChar, -1).Value = (object)diagnostico ?? DBNull.Value;
            });
        }

        public static void Cancelar(long procedimiento, string motivo, string usuario, long usuarioEsp)
        {
            Escalar(11, usuario, usuarioEsp, p =>
            {
                p.Add("@procedimiento", SqlDbType.BigInt).Value = procedimiento;
                p.Add("@texto", SqlDbType.VarChar, -1).Value = (object)motivo ?? DBNull.Value;
            });
        }

        public static void CambiarEspecialista(long procedimiento, long especialista, string usuario, long usuarioEsp)
        {
            Escalar(12, usuario, usuarioEsp, p =>
            {
                p.Add("@procedimiento", SqlDbType.BigInt).Value = procedimiento;
                p.Add("@especialista", SqlDbType.BigInt).Value = especialista;
            });
        }

        /// <summary>Reprograma la cita conservando su duración. Devuelve el Id de la nueva cita.</summary>
        public static long Reprogramar(long cita, DateTime inicio, string usuario, long usuarioEsp)
        {
            return Escalar(13, usuario, usuarioEsp, p =>
            {
                p.Add("@cita", SqlDbType.BigInt).Value = cita;
                p.Add("@fechaInicio", SqlDbType.DateTime2).Value = inicio;
            });
        }
    }
}
