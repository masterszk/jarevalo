using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;
using System.Linq;

namespace DPieCenter.Registros
{
    public static class CitasRepository
    {
        private static string Cn
        {
            get { return ConfigurationManager.ConnectionStrings["conexionDiarypro"].ConnectionString; }
        }

        // ===== Agenda tipo calendario (procedimientos almacenados existentes) =====
        private static readonly CultureInfo Inv = CultureInfo.InvariantCulture;

        // Catálogos: cada SP recibe @accion = 1. Los nombres de SP y columnas son fijos (no vienen del usuario).
        private static List<OpcionDto> ObtenerOpciones(string sp, string colId, string colTexto, int? sucursal = null)
        {
            var lista = new List<OpcionDto>();
            using (var cn = new SqlConnection(Cn))
            using (var cmd = new SqlCommand(sp, cn) { CommandType = CommandType.StoredProcedure })
            {
                cmd.Parameters.Add("@accion", SqlDbType.Int).Value = 1;
                if (sucursal.HasValue) cmd.Parameters.Add("@sucursal", SqlDbType.Int).Value = sucursal.Value;
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                {
                    int oId = rd.GetOrdinal(colId), oTexto = rd.GetOrdinal(colTexto);
                    while (rd.Read())
                        lista.Add(new OpcionDto
                        {
                            Id = Convert.ToInt64(rd.GetValue(oId)),
                            Texto = rd.IsDBNull(oTexto) ? "" : Convert.ToString(rd.GetValue(oTexto)).Trim()
                        });
                }
            }
            return lista;
        }

        /// <summary>Especialistas que atienden en la sucursal de la sesión (CAT_ESPECIALISTAS_SUCURSALES).</summary>
        public static List<OpcionDto> ObtenerEspecialistas() { return ObtenerOpciones("dbo.EXP_SP_Especialistas", "IdProfesional", "Profesional", Sesion.Sucursal); }
        public static List<OpcionDto> ObtenerCatTiposCita() { return ObtenerOpciones("dbo.EXP_SP_TiposCitas", "IdTipoCita", "TipoCita"); }
        public static List<OpcionDto> ObtenerEstadosCita() { return ObtenerOpciones("dbo.EXP_SP_EstadoCitas", "IdEstado", "Estado"); }

        // EXP_SP_Citas_Agendadas @acc = 1  ->  Id, FechaInicio, Profesional, TipoCita
        // Sin rango: citas desde hoy. Con rango [desde, hasta): incluye días pasados (semana del calendario).
        // sucursal: -1 = la de la sesión, 0 = todas (choques de un profesional, que no puede estar en dos sucursales a la vez).
        public static List<CitaAgendadaRaw> ObtenerCitasAgendadas(DateTime? desde = null, DateTime? hasta = null, int sucursal = -1)
        {
            var lista = new List<CitaAgendadaRaw>();
            using (var cn = new SqlConnection(Cn))
            using (var cmd = new SqlCommand("dbo.EXP_SP_Citas_Agendadas", cn) { CommandType = CommandType.StoredProcedure })
            {
                cmd.Parameters.Add("@acc", SqlDbType.Int).Value = 1;
                cmd.Parameters.Add("@sucursal", SqlDbType.Int).Value = sucursal < 0 ? Sesion.Sucursal : sucursal;
                if (desde.HasValue)
                {
                    cmd.Parameters.Add("@desde", SqlDbType.DateTime2).Value = desde.Value;
                    cmd.Parameters.Add("@hasta", SqlDbType.DateTime2).Value = (object)hasta ?? DBNull.Value;
                }
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                {
                    int oId = rd.GetOrdinal("Id"), oIni = rd.GetOrdinal("FechaInicio"),
                        oProf = rd.GetOrdinal("Profesional"), oTipo = rd.GetOrdinal("TipoCita"), oPac = -1;
                    for (int i = 0; i < rd.FieldCount; i++) if (rd.GetName(i) == "Paciente") oPac = i;   // EXP_Citas_Agendadas.sql
                    while (rd.Read())
                    {
                        if (rd.IsDBNull(oIni)) continue;
                        lista.Add(new CitaAgendadaRaw
                        {
                            Id = Convert.ToInt64(rd.GetValue(oId)),
                            Inicio = Convert.ToDateTime(rd.GetValue(oIni)),
                            Profesional = rd.IsDBNull(oProf) ? "" : Convert.ToString(rd.GetValue(oProf)).Trim(),
                            TipoCita = rd.IsDBNull(oTipo) ? "" : Convert.ToString(rd.GetValue(oTipo)).Trim(),
                            Paciente = oPac < 0 || rd.IsDBNull(oPac) ? "" : Convert.ToString(rd.GetValue(oPac)).Trim()
                        });
                    }
                }
            }
            return lista;
        }

        // EXP_SP_CitasViewData @cita bigint
        public static CitaDetalleDto ObtenerDetalle(long cita)
        {
            using (var cn = new SqlConnection(Cn))
            using (var cmd = new SqlCommand("dbo.EXP_SP_CitasViewData", cn) { CommandType = CommandType.StoredProcedure })
            {
                cmd.Parameters.Add("@cita", SqlDbType.BigInt).Value = cita;
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                {
                    if (!rd.Read()) return null;
                    var ini = Convert.ToDateTime(rd.GetValue(rd.GetOrdinal("FechaInicio")));
                    var fin = Convert.ToDateTime(rd.GetValue(rd.GetOrdinal("FechaFin")));
                    var detalle = new CitaDetalleDto
                    {
                        Id = Largo(rd, "Id"),
                        Paciente = Col(rd, "Paciente"),
                        Documento = Col(rd, "Documento"),
                        Email = Col(rd, "Email"),
                        Celular = Col(rd, "Celular"),
                        Edad = Col(rd, "Edad"),
                        Direccion = Col(rd, "Direccion"),
                        Especialista = Col(rd, "Especialista"),
                        TipoCita = Col(rd, "TipoCita"),
                        Estado = Col(rd, "Estado"),
                        Fecha = ini.ToString("yyyy-MM-dd", Inv),
                        Hora = ini.ToString("HH:mm", Inv),
                        HoraFin = fin.ToString("HH:mm", Inv),
                        DuracionMin = (int)Math.Round((fin - ini).TotalMinutes),
                        IdEspecialista = Largo(rd, "Id_Especialista"),
                        IdTipoCita = Largo(rd, "Id_TipoCita"),
                        IdEstado = Largo(rd, "Id_Estado")
                    };
                    if (rd.NextResult())
                        while (rd.Read())
                        {
                            var t = new TratamientoCitaDto
                            {
                                Tratamiento = Col(rd, "Tratamiento"),
                                Valor = rd.IsDBNull(rd.GetOrdinal("Valor")) ? 0 : Convert.ToDecimal(rd.GetValue(rd.GetOrdinal("Valor"))),
                                Descuento = rd.IsDBNull(rd.GetOrdinal("Descuento")) ? 0 : Convert.ToDecimal(rd.GetValue(rd.GetOrdinal("Descuento")))
                            };
                            t.MontoDescuento = Facturacion.DescuentosTratamiento.Monto(t.Valor, t.Descuento);
                            detalle.Tratamientos.Add(t);
                        }
                    if (rd.NextResult() && rd.Read())
                    {
                        detalle.AnticipoFactura = Convert.ToInt64(rd["IdFactura"]);
                        detalle.AnticipoMonto = rd["Monto"] == DBNull.Value ? 0 : Convert.ToDecimal(rd["Monto"]);
                        detalle.AnticipoFecha = rd["FechaPago"] == DBNull.Value ? "" : Convert.ToDateTime(rd["FechaPago"]).ToString("dd/MM/yyyy", Inv);
                        detalle.AnticipoLibre = rd["MontoLibre"] != DBNull.Value && Convert.ToBoolean(rd["MontoLibre"]);
                    }
                    // pagos adelantados sin cita del paciente pendientes de agendar
                    if (rd.NextResult() && rd.Read())
                        detalle.PagosPendientes = rd["PagosPendientes"] == DBNull.Value ? 0 : Convert.ToDecimal(rd["PagosPendientes"]);
                    return detalle;
                }
            }
        }

        // EXP_SP_CitaUpdate @cita, @profesional, @estado, @fechainicio, @fechafinal, @user
        /// <param name="estado">null: lo decide el SP (Reprogramada si cambia la fecha u hora; si no, el actual).</param>
        public static void ActualizarCita(long cita, long profesional, long? estado, DateTime inicio, DateTime fin, string usuario)
        {
            using (var cn = new SqlConnection(Cn))
            using (var cmd = new SqlCommand("dbo.EXP_SP_CitaUpdate", cn) { CommandType = CommandType.StoredProcedure })
            {
                cmd.Parameters.Add("@cita", SqlDbType.BigInt).Value = cita;
                cmd.Parameters.Add("@profesional", SqlDbType.BigInt).Value = profesional;
                cmd.Parameters.Add("@estado", SqlDbType.BigInt).Value = estado.HasValue ? (object)estado.Value : DBNull.Value;
                cmd.Parameters.Add("@fechainicio", SqlDbType.DateTime2).Value = inicio;
                cmd.Parameters.Add("@fechafinal", SqlDbType.DateTime2).Value = fin;
                cmd.Parameters.Add("@user", SqlDbType.VarChar, 20).Value = usuario;
                cn.Open();
                cmd.ExecuteNonQuery();
            }
        }

        /// <summary>Cancela la cita (EXP_SP_CitaCancelar): libera la hora y al especialista. Devuelve el saldo a favor que queda (anticipo pagado).</summary>
        public static decimal CancelarCita(long cita, string motivo, string usuario)
        {
            using (var cn = new SqlConnection(Cn))
            using (var cmd = new SqlCommand("dbo.EXP_SP_CitaCancelar", cn) { CommandType = CommandType.StoredProcedure })
            {
                cmd.Parameters.Add("@cita", SqlDbType.BigInt).Value = cita;
                cmd.Parameters.Add("@motivo", SqlDbType.VarChar, 250).Value = (object)motivo ?? DBNull.Value;
                cmd.Parameters.Add("@user", SqlDbType.VarChar, 20).Value = usuario;
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    return rd.Read() && rd["SaldoFavor"] != DBNull.Value ? Convert.ToDecimal(rd["SaldoFavor"]) : 0m;
            }
        }

        private static long Largo(IDataRecord r, string nombre)
        {
            int o;
            try { o = r.GetOrdinal(nombre); } catch (IndexOutOfRangeException) { return 0; }
            return r.IsDBNull(o) ? 0 : Convert.ToInt64(r.GetValue(o));
        }



        // ===== Tipos de cita con el SP existente EXP_SP_ListaTiposCitas =====
        // @accion = 1 para listar (ajuste aquí si su SP usa otro valor). Resultado: [Id], [TipoCita]
        private const int AccionListarTiposCita = 1;

        public static List<TipoCitaDto> ObtenerTiposCita(string usuario)
        {
            var lista = new List<TipoCitaDto>();
            using (var cn = new SqlConnection(Cn))
            using (var cmd = new SqlCommand("dbo.EXP_SP_ListaTiposCitas", cn) { CommandType = CommandType.StoredProcedure })
            {
                cmd.Parameters.Add("@user", SqlDbType.VarChar, 20).Value = usuario;
                cmd.Parameters.Add("@accion", SqlDbType.Int).Value = AccionListarTiposCita;
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                {
                    int oId = rd.GetOrdinal("Id"), oTipo = rd.GetOrdinal("TipoCita");
                    while (rd.Read())
                        lista.Add(new TipoCitaDto
                        {
                            Id = Convert.ToInt32(rd.GetValue(oId)),
                            TipoCita = rd.IsDBNull(oTipo) ? "" : Convert.ToString(rd.GetValue(oTipo)).Trim()
                        });
                }
            }
            return lista;
        }

        // ===== Búsqueda de pacientes con el SP existente =====
        // @accion: 1 = por nombre, 2 = por documento (ajuste aquí si su SP usa otros valores)
        public static List<PacienteDto> BuscarPacientes(int tipo, string termino, string usuario)
        {
            var lista = new List<PacienteDto>();
            using (var cn = new SqlConnection(Cn))
            using (var cmd = new SqlCommand("dbo.EXP_SP_CitasBuscaExp", cn) { CommandType = CommandType.StoredProcedure })
            {
                cmd.Parameters.Add("@documento", SqlDbType.VarChar, 20).Value = tipo == 2 ? termino : "";
                cmd.Parameters.Add("@paciente", SqlDbType.VarChar, 250).Value = tipo == 1 ? termino : "";
                cmd.Parameters.Add("@user", SqlDbType.VarChar, 20).Value = usuario;
                cmd.Parameters.Add("@accion", SqlDbType.Int).Value = tipo;
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                    {
                        // Nombres de columna posibles del resultado del SP: ajuste esta lista a sus columnas reales
                        var p = new PacienteDto
                        {
                            Codigo    = rd.GetInt64(0),
                            Nombre    = rd.GetString(1),
                            Documento = rd.GetString(2),
                            Celular  = rd.GetString(3)
                        };
                        lista.Add(p);
                    }
            }
            return lista;
        }

        private static string Col(IDataRecord r, params string[] nombres)
        {
            foreach (var n in nombres)
            {
                int o;
                try { o = r.GetOrdinal(n); } catch (IndexOutOfRangeException) { continue; }
                if (!r.IsDBNull(o)) return Convert.ToString(r.GetValue(o)).Trim();
            }
            return "";
        }

        private static string Trunc(string s, int max)
        {
            if (string.IsNullOrEmpty(s)) return null;
            return s.Length > max ? s.Substring(0, max) : s;
        }

        /// <summary>Profesionales para agendar: los que atienden en la sucursal de la sesión.</summary>
        public static List<ProfesionalDto> ObtenerProfesionales()
        {
            return ObtenerEspecialistas().Select(e => new ProfesionalDto { Id = e.Id, Profesional = e.Texto }).ToList();
        }

        public static List<TratamientoDto> ObtenerTratamientos(IEnumerable<int> ids = null)
        {
            var lista = new List<TratamientoDto>();
            var idList = ids == null ? null : ids.ToList();
            using (var cn = new SqlConnection(Cn))
            using (var cmd = new SqlCommand { Connection = cn })
            {
                var sql = "select " +
                    " Id_Tratamientos [Id]" +
                    ",Descripcion [Tratamiento]" +
                    ",Duracion [DuracionMin]" +
                    ",cast(isnull(Precio,0) as decimal(10,2)) [Precio]" +
                    ",isnull(Imagen, 'mainCatalogos/uploadtratamientos/6629.png_860.png') [Imagen]" +
                    ",Descuento" +
                    " from CAT_TRATAMIENTOS" +
                    " where IsActivo = 1";
                if (idList != null)
                {
                    var ps = new List<string>();
                    for (int i = 0; i < idList.Count; i++)
                    {
                        ps.Add("@p" + i);
                        cmd.Parameters.Add("@p" + i, SqlDbType.BigInt).Value = idList[i];
                    }
                    sql += " AND Id_Tratamientos IN (" + string.Join(",", ps) + ")";
                }
                sql += " ORDER BY Id_Tratamientos";
                cmd.CommandText = sql;
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                {
                    while (rd.Read())
                        lista.Add(new TratamientoDto { Id = rd.GetInt64(0), Tratamiento = rd.GetString(1),DuracionMin = rd.GetInt32(2), Precio = rd.GetDecimal(3), Imagen = rd.GetString(4), Descuento = rd.GetDecimal(5) });
                }
            }
            return lista;
        }

        /// <summary>Citas que ocupan horario (no canceladas ni cobradas). Con cobradas = true: las ya cobradas en caja (horas liberadas).</summary>
        public static List<RangoOcupado> ObtenerOcupados(long profesionalId, DateTime desde, DateTime hasta, bool cobradas = false)
        {
            var lista = new List<RangoOcupado>();
            using (var cn = new SqlConnection(Cn))
            using (var cmd = new SqlCommand("dbo.EXP_SP_ListaFechasAgendadas", cn) { CommandType = CommandType.StoredProcedure })
            {
                cmd.Parameters.Add("@profesional", SqlDbType.BigInt).Value = profesionalId;
                cmd.Parameters.Add("@desde", SqlDbType.DateTime2).Value = desde;
                cmd.Parameters.Add("@hasta", SqlDbType.DateTime2).Value = hasta;
                cmd.Parameters.Add("@cobradas", SqlDbType.Bit).Value = cobradas;
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                        lista.Add(new RangoOcupado { Inicio = rd.GetDateTime(0), Fin = rd.GetDateTime(1) });
            }
            return lista;
        }

        /// <summary>Crea la cita de forma atómica. Devuelve 0 si el horario ya fue tomado.</summary>
        public static long CrearCita(CitaRequest req, DateTime inicio, DateTime fin, decimal total, List<TratamientoDto> tratamientos
            , PacienteDto pac, TipoCitaDto tipo, string usuario, bool sinValidarChoque = false)
        {
            using (var cn = new SqlConnection(Cn))
            {
                
                cn.Open();
                using (var tx = cn.BeginTransaction(IsolationLevel.Serializable))
                {
                    try
                    {
                        int choques;
                        using (var cmd = new SqlCommand("dbo.EXP_SP_ListaNumCitas", cn, tx) { CommandType = CommandType.StoredProcedure })
                        {
                            cmd.Parameters.Add("@profesional", SqlDbType.BigInt).Value = req.ProfesionalId;
                            cmd.Parameters.Add("@desde", SqlDbType.DateTime2).Value = inicio;
                            cmd.Parameters.Add("@hasta", SqlDbType.DateTime2).Value = fin;
                            choques = (int)cmd.ExecuteScalar();
                        }
                        if (choques > 0 && !sinValidarChoque) { tx.Rollback(); return 0; }

                        long citaId;
                        using (var cmd = new SqlCommand("dbo.EXP_SP_Citas_V2", cn, tx) { CommandType = CommandType.StoredProcedure })
                        {
                            cmd.Parameters.Add("@expediente", SqlDbType.BigInt).Value = pac.Codigo;
                            cmd.Parameters.Add("@tipocita", SqlDbType.BigInt).Value = tipo.Id;
                            cmd.Parameters.Add("@especialista", SqlDbType.BigInt).Value = req.ProfesionalId;
                            cmd.Parameters.Add("@fechaInicio", SqlDbType.DateTime2).Value = inicio;
                            cmd.Parameters.Add("@fechaFin", SqlDbType.DateTime2).Value = fin;
                            cmd.Parameters.Add("@comentarios", SqlDbType.VarChar, 300).Value = (object)req.Notas ?? DBNull.Value;
                            cmd.Parameters.Add("@user", SqlDbType.VarChar, 20).Value = Trunc(usuario, 20);
                            cmd.Parameters.Add("@sucursal", SqlDbType.Int).Value = Sesion.Sucursal;     // la cita es de la sucursal de la sesión
                            citaId = (long)cmd.ExecuteScalar();
                        }

                        foreach (var t in tratamientos)
                        {
                            using (var cmd = new SqlCommand("dbo.EXP_SP_CitasTratamientos_V2", cn, tx) { CommandType = CommandType.StoredProcedure })
                            {
                                cmd.Parameters.Add("@cita", SqlDbType.BigInt).Value = citaId;
                                cmd.Parameters.Add("@tratamiento", SqlDbType.BigInt).Value = t.Id;
                                var pPr = cmd.Parameters.Add("@precio", SqlDbType.Decimal);
                                pPr.Precision = 10; pPr.Scale = 2; pPr.Value = t.Precio;
                                cmd.Parameters.Add("@duracion", SqlDbType.Int).Value = t.DuracionMin;
                                cmd.Parameters.Add("@user", SqlDbType.VarChar, 20).Value = Trunc(usuario, 20);
                                cmd.ExecuteNonQuery();
                            }
                        }

                        // Cita en la hora en curso: se abre el procedimiento con los tratamientos recién guardados
                        using (var cmd = new SqlCommand("dbo.EXP_SP_Citas_ProcedimientoEnCurso", cn, tx) { CommandType = CommandType.StoredProcedure })
                        {
                            cmd.Parameters.Add("@cita", SqlDbType.BigInt).Value = citaId;
                            cmd.Parameters.Add("@user", SqlDbType.VarChar, 20).Value = Trunc(usuario, 20);
                            cmd.ExecuteNonQuery();
                        }
                        tx.Commit();
                        return citaId;
                    }
                    catch
                    {
                        tx.Rollback();
                        throw;
                    }
                }
            }
        }

        /// <summary>Devuelve la fecha final del procedimiento.</summary>
        public static DateTime GetFechafinal(DateTime inicio, int minutos)
        {
            using (var cn = new SqlConnection(Cn))
            {
                cn.Open();
                DateTime fechaFinal;
                using (var cmd = new SqlCommand("dbo.EXP_SP_GetFechaFinal", cn) { CommandType = CommandType.StoredProcedure })
                {
                    cmd.Parameters.Add("@inicio", SqlDbType.DateTime2).Value = inicio;
                    cmd.Parameters.Add("@minute", SqlDbType.Int).Value = minutos;
                    fechaFinal = (DateTime)cmd.ExecuteScalar();
                }
                return DateTime.MinValue;
            }
        }
    }
}
