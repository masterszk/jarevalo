using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;

namespace DPieCenter.Registros
{
    /// <summary>Acceso a dbo.EXP_SP_Expedientes_Lista (Registros/sql/EXP_Expedientes_Lista.sql).</summary>
    public static class ExpedientesRepository
    {
        private const string Proc = "dbo.EXP_SP_Expedientes_Lista";
        public const int TamanoPagina = 25;
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
        private static int Ent(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? 0 : Convert.ToInt32(v); }
        private static DateTime? Fecha(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? (DateTime?)null : Convert.ToDateTime(v); }
        private static string Dia(DateTime? d) { return d.HasValue ? d.Value.ToString("dd/MM/yyyy", Inv) : ""; }

        private static string Edad(DateTime? nacimiento)
        {
            if (!nacimiento.HasValue) return "";
            var hoy = DateTime.Today;
            int edad = hoy.Year - nacimiento.Value.Year;
            if (nacimiento.Value.Date > hoy.AddYears(-edad)) edad--;
            return edad < 0 ? "" : edad.ToString(Inv);
        }

        public static ListaExpedientesDto Buscar(string texto, string letra, int pagina, string usuario)
        {
            var d = new ListaExpedientesDto { Ok = true, Pagina = Math.Max(pagina, 1), Tamano = TamanoPagina, Items = new List<ExpedienteFilaDto>() };
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, 1, usuario))
            {
                cmd.Parameters.Add("@texto", SqlDbType.VarChar, 100).Value = string.IsNullOrWhiteSpace(texto) ? (object)DBNull.Value : texto.Trim();
                cmd.Parameters.Add("@letra", SqlDbType.Char, 1).Value = string.IsNullOrWhiteSpace(letra) ? (object)DBNull.Value : letra.Trim().Substring(0, 1);
                cmd.Parameters.Add("@pagina", SqlDbType.Int).Value = d.Pagina;
                cmd.Parameters.Add("@tamano", SqlDbType.Int).Value = TamanoPagina;
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                    {
                        d.Total = Ent(rd, "Total");
                        var nac = Fecha(rd, "FechaNacimiento");
                        var proxima = Fecha(rd, "ProximaCita");
                        d.Items.Add(new ExpedienteFilaDto
                        {
                            Id = Convert.ToInt64(rd["Id_Expediente"]),
                            Nombres = Txt(rd, "Nombres"),
                            Apellidos = Txt(rd, "Apellidos"),
                            Documento = Txt(rd, "Documento"),
                            TipoDocumento = Txt(rd, "TipoDocumento"),
                            Registro = Txt(rd, "Registro"),
                            Celular = Txt(rd, "Celular"),
                            Telefono = Txt(rd, "Telefono"),
                            Email = Txt(rd, "Email"),
                            Sexo = Txt(rd, "Sexo"),
                            Pais = (int)Num(rd, "Id_Pais"),
                            PaisTelefono = (int)Num(rd, "Id_PaisTelefono"),
                            Edad = Edad(nac),
                            FechaNacimiento = Dia(nac),
                            Ingreso = Dia(Fecha(rd, "FechaCrea")),
                            UltimaVisita = Dia(Fecha(rd, "UltimaVisita")),
                            // las citas antiguas no tienen hora (00:00)
                            ProximaCita = proxima.HasValue
                                ? (proxima.Value.TimeOfDay == TimeSpan.Zero ? proxima.Value.ToString("dd/MM/yyyy", Inv) : Formato.FechaHora(proxima.Value)) : "",
                            Visitas = Ent(rd, "Visitas")
                        });
                    }
            }
            return d;
        }

        public static ExpedientesInicioDto Inicio(string usuario)
        {
            var d = new ExpedientesInicioDto { Ok = true, Letras = new List<LetraDto>(), Resumen = new ResumenExpedientesDto() };
            using (var cn = new SqlConnection(Cn))
            {
                cn.Open();
                using (var cmd = Sp(cn, 2, usuario))
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                        d.Letras.Add(new LetraDto { Letra = Txt(rd, "Letra"), Cantidad = Ent(rd, "Cantidad") });

                using (var cmd = Sp(cn, 3, usuario))
                using (var rd = cmd.ExecuteReader())
                    if (rd.Read())
                        d.Resumen = new ResumenExpedientesDto
                        {
                            Total = Ent(rd, "Total"),
                            NuevosMes = Ent(rd, "NuevosMes"),
                            ConCitaHoy = Ent(rd, "ConCitaHoy"),
                            Activos90 = Ent(rd, "Activos90")
                        };
            }
            return d;
        }

        /// <summary>Elimina un expediente sin historial. El SP rechaza (THROW) los que tienen citas, procedimientos, reclamos o datos fiscales.</summary>
        public static void Eliminar(long id, string usuario)
        {
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, 4, usuario))
            {
                cmd.Parameters.Add("@id", SqlDbType.BigInt).Value = id;
                cn.Open();
                cmd.ExecuteScalar();
            }
        }

        public static List<ProcedimientoReclamoDto> ProcedimientosPaciente(long id, string usuario)
        {
            var lista = new List<ProcedimientoReclamoDto>();
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, 5, usuario))
            {
                cmd.Parameters.Add("@id", SqlDbType.BigInt).Value = id;
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                        lista.Add(new ProcedimientoReclamoDto
                        {
                            Id = Convert.ToInt64(rd["Id_Procedimiento"]),
                            Fecha = Dia(Fecha(rd, "Fecha")),
                            IdEspecialista = rd["Id_Especialista"] == DBNull.Value ? 0 : Convert.ToInt64(rd["Id_Especialista"]),
                            Especialista = Txt(rd, "Especialista"),
                            Tratamientos = Txt(rd, "Tratamientos")
                        });
            }
            return lista;
        }

        // ===== Ficha del paciente: dbo.EXP_SP_Expediente_Detalle (Registros/sql/EXP_Expediente_Detalle.sql) =====
        private const string ProcDetalle = "dbo.EXP_SP_Expediente_Detalle";

        private static SqlCommand SpDetalle(SqlConnection cn, int accion, long id, string usuario)
        {
            var cmd = new SqlCommand(ProcDetalle, cn) { CommandType = CommandType.StoredProcedure };
            cmd.Parameters.Add("@accion", SqlDbType.Int).Value = accion;
            cmd.Parameters.Add("@id", SqlDbType.BigInt).Value = id;
            cmd.Parameters.Add("@user", SqlDbType.VarChar, 20).Value = (object)usuario ?? DBNull.Value;
            return cmd;
        }

        private static long Num(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? 0 : Convert.ToInt64(v); }
        private static bool Bit(IDataRecord r, string col) { var v = r[col]; return v != DBNull.Value && Convert.ToBoolean(v); }
        private static decimal Dec(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? 0 : Convert.ToDecimal(v); }

        // Las citas y procedimientos antiguos guardaban solo la hora (1900-01-01) o la fecha sin hora (00:00)
        private static string HoraDe(DateTime? d) { return d.HasValue && d.Value.TimeOfDay != TimeSpan.Zero ? Formato.Hora(d.Value) : ""; }

        private static string Auditoria(DateTime? fecha, string usuario)
        {
            if (!fecha.HasValue) return "";
            return Formato.FechaHora(fecha.Value) + (string.IsNullOrWhiteSpace(usuario) ? "" : " por " + usuario.Trim());
        }

        public static FichaPacienteDto Ficha(long id, string usuario)
        {
            var d = new FichaPacienteDto { Ok = true };
            using (var cn = new SqlConnection(Cn))
            {
                cn.Open();
                using (var cmd = SpDetalle(cn, 1, id, usuario))
                using (var rd = cmd.ExecuteReader())
                    if (rd.Read())
                    {
                        var nac = Fecha(rd, "FechaNacimiento");
                        d.Perfil = new PerfilPacienteDto
                        {
                            Id = id,
                            Nombres = Txt(rd, "Nombres"),
                            Apellidos = Txt(rd, "Apellidos"),
                            TipoDocumento = Num(rd, "Id_TipoDocumento"),
                            TipoDocumentoTexto = Txt(rd, "TipoDocumento"),
                            Documento = Txt(rd, "Documento"),
                            Registro = Txt(rd, "Registro"),
                            Nacimiento = nac.HasValue ? nac.Value.ToString("yyyy-MM-dd", Inv) : "",
                            Edad = Edad(nac),
                            Sexo = Num(rd, "Id_Sexo"),
                            SexoTexto = Txt(rd, "Sexo"),
                            Pais = (int)Num(rd, "Id_Pais"),
                            PaisTexto = Txt(rd, "Pais"),
                            PaisTelefono = (int)Num(rd, "Id_PaisTelefono"),
                            Telefono = Txt(rd, "Telefono"),
                            Celular = Txt(rd, "Celular"),
                            Email = Txt(rd, "Email"),
                            PersonaEmergencia = Txt(rd, "PersonaEmergencia"),
                            TelefonoEmergencia = Txt(rd, "TelefonoEmergencia"),
                            Departamento = Num(rd, "Id_Departamento"),
                            Municipio = Num(rd, "Id_Municipio"),
                            Direccion = Txt(rd, "Direccion"),
                            Ubicacion = Txt(rd, "Ubicacion").Trim(' ', ','),
                            Facebook = Bit(rd, "Facebook"),
                            Instagram = Bit(rd, "Instagram"),
                            Buscador = Bit(rd, "Buscador"),
                            Recomendado = Bit(rd, "Recomendado"),
                            TikTok = Bit(rd, "TikTok"),
                            WhatsApp = Bit(rd, "WhatsApp"),
                            Otros = Bit(rd, "Otros"),
                            Foto = Txt(rd, "Foto"),
                            Creado = Auditoria(Fecha(rd, "FechaCrea"), Txt(rd, "UsuarioCrea")),
                            Modificado = Auditoria(Fecha(rd, "FechaModifica"), Txt(rd, "UsuarioModifica"))
                        };
                    }

                using (var cmd = SpDetalle(cn, 2, id, usuario))
                using (var rd = cmd.ExecuteReader())
                    if (rd.Read())
                    {
                        var proxima = Fecha(rd, "ProximaCita");
                        d.Resumen = new ResumenPacienteDto
                        {
                            Citas = Ent(rd, "Citas"),
                            Atendidas = Ent(rd, "Atendidas"),
                            Canceladas = Ent(rd, "Canceladas"),
                            Procedimientos = Ent(rd, "Procedimientos"),
                            Reclamos = Ent(rd, "Reclamos"),
                            UltimaVisita = Dia(Fecha(rd, "UltimaVisita")),
                            ProximaCita = proxima.HasValue ? (Dia(proxima) + " " + HoraDe(proxima)).Trim() : ""
                        };
                    }
            }
            return d;
        }

        public static HistorialPacienteDto Historial(long id, string usuario)
        {
            var d = new HistorialPacienteDto
            {
                Ok = true,
                Citas = new List<CitaPacienteDto>(),
                Procedimientos = new List<ProcedimientoPacienteDto>(),
                Reclamos = new List<ReclamoPacienteDto>()
            };
            var porId = new Dictionary<long, ProcedimientoPacienteDto>();
            DateTime hoy = DateTime.Today;

            using (var cn = new SqlConnection(Cn))
            {
                cn.Open();
                using (var cmd = SpDetalle(cn, 3, id, usuario))
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                    {
                        var inicio = Fecha(rd, "FechaInicio");
                        string hora = HoraDe(inicio);
                        if (hora == "") hora = Formato.HoraTexto(Txt(rd, "HoraHorario"));
                        string fin = HoraDe(Fecha(rd, "FechaFin"));
                        d.Citas.Add(new CitaPacienteDto
                        {
                            Id = Num(rd, "Id_Cita"),
                            Fecha = Dia(inicio),
                            Hora = hora + (fin != "" && fin != hora ? " - " + fin : ""),
                            Especialista = Txt(rd, "Especialista"),
                            TipoCita = Txt(rd, "TipoCita"),
                            Estado = Txt(rd, "Estado"),
                            Color = Txt(rd, "Color"),
                            Comentarios = Txt(rd, "Comentarios"),
                            Tratamientos = Txt(rd, "Tratamientos"),
                            Futura = inicio.HasValue && inicio.Value.Date >= hoy
                        });
                    }

                using (var cmd = SpDetalle(cn, 4, id, usuario))
                using (var rd = cmd.ExecuteReader())
                {
                    while (rd.Read())
                    {
                        string ini = HoraDe(Fecha(rd, "InicioProcedimiento")), fin = HoraDe(Fecha(rd, "FinalProcedimiento"));
                        var p = new ProcedimientoPacienteDto
                        {
                            Id = Num(rd, "Id_Procedimiento"),
                            Fecha = Dia(Fecha(rd, "Fecha")),
                            Horario = ini + (fin != "" ? " - " + fin : ""),
                            Estado = Txt(rd, "Estado"),
                            Especialista = Txt(rd, "Especialista"),
                            TipoCita = Txt(rd, "TipoCita"),
                            Diagnostico = Txt(rd, "Diagnostico"),
                            Resultados = Txt(rd, "Resultados"),
                            Recomendaciones = Txt(rd, "Recomendaciones"),
                            Comentarios = Txt(rd, "Comentarios"),
                            Tratamientos = new List<TratamientoPacienteDto>()
                        };
                        d.Procedimientos.Add(p);
                        porId[p.Id] = p;
                    }
                    rd.NextResult();
                    while (rd.Read())
                    {
                        ProcedimientoPacienteDto p;
                        if (!porId.TryGetValue(Num(rd, "Id_Procedimiento"), out p)) continue;
                        var t = new TratamientoPacienteDto { Descripcion = Txt(rd, "Descripcion"), Valor = Dec(rd, "Valor") };
                        p.Tratamientos.Add(t);
                        p.Total += t.Valor;
                    }
                }

                using (var cmd = SpDetalle(cn, 5, id, usuario))
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                        d.Reclamos.Add(new ReclamoPacienteDto
                        {
                            Id = Num(rd, "Id_Reclamo"),
                            Fecha = Auditoria(Fecha(rd, "FechaCrea"), null),
                            Usuario = Txt(rd, "Usuario"),
                            Especialista = Txt(rd, "Especialista"),
                            IdProcedimiento = Num(rd, "Id_Procedimiento"),
                            FechaProcedimiento = Dia(Fecha(rd, "FechaProcedimiento")),
                            Reclamo = Txt(rd, "Reclamo")
                        });
            }
            return d;
        }

        /// <summary>foto: data URL JPEG ya normalizada (ExpedientesService.NormalizarFoto); null la quita.</summary>
        public static void GuardarFoto(long id, string foto, string usuario)
        {
            using (var cn = new SqlConnection(Cn))
            using (var cmd = SpDetalle(cn, foto == null ? 7 : 6, id, usuario))
            {
                cmd.Parameters.Add("@foto", SqlDbType.VarChar, -1).Value = (object)foto ?? DBNull.Value;
                cn.Open();
                cmd.ExecuteScalar();
            }
        }
    }
}
