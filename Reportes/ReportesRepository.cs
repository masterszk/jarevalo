using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;
using System.Linq;

namespace DPieCenter.Reportes
{
    /// <summary>Acceso a dbo.REP_SP_Dashboard y dbo.REP_SP_Caja (Reportes/sql/REP_Dashboard_Caja.sql).</summary>
    public static class ReportesRepository
    {
        private static readonly CultureInfo Inv = CultureInfo.InvariantCulture;
        private static readonly Dictionary<string, string> TiposDte = new Dictionary<string, string> { { "01", "Factura" }, { "03", "Crédito fiscal" }, { "TK", "Ticket POS" } };

        private static string Cn
        {
            get { return ConfigurationManager.ConnectionStrings["conexionDiarypro"].ConnectionString; }
        }

        private static string Txt(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? "" : Convert.ToString(v).Trim(); }
        private static int Ent(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? 0 : Convert.ToInt32(v); }
        private static long Num(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? 0 : Convert.ToInt64(v); }
        private static decimal Dec(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? 0 : Convert.ToDecimal(v); }
        private static decimal? DecN(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? (decimal?)null : Math.Round(Convert.ToDecimal(v), 1); }
        private static DateTime? Fecha(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? (DateTime?)null : Convert.ToDateTime(v); }

        private static SqlCommand Sp(SqlConnection cn, string nombre, int accion)
        {
            var cmd = new SqlCommand(nombre, cn) { CommandType = CommandType.StoredProcedure };
            cmd.Parameters.Add("@accion", SqlDbType.Int).Value = accion;
            return cmd;
        }

        // ===== Dashboard =====

        /// <summary>verDinero = false oculta facturación, cobros e ingresos por especialista.</summary>
        public static DashboardDto Dashboard(DateTime desde, DateTime hasta, bool verDinero, int sucursal = 0)
        {
            var d = new DashboardDto
            {
                Ok = true,
                VerDinero = verDinero,
                Desde = desde.ToString("yyyy-MM-dd", Inv),
                Hasta = hasta.ToString("yyyy-MM-dd", Inv),
                CitasPorDia = new List<CitasDiaDto>(),
                Especialistas = new List<EspecialistaDesempenoDto>(),
                Tratamientos = new List<ConteoDto>(),
                EstadosCita = new List<ConteoDto>(),
                Hoy = new List<AgendaHoyDto>(),
                NuevosPorMes = new List<ConteoDto>(),
                Fuentes = new List<ConteoDto>(),
                PacientesCitaDia = new List<PacientesCitaDiaDto>(),
                IngresosFormaPago = new List<IngresoFormaPagoDto>(),
                Garantias = new List<GarantiaEspecialistaDto>()
            };

            using (var cn = new SqlConnection(Cn))
            {
                cn.Open();
                Func<int, SqlCommand> sp = accion =>
                {
                    var cmd = Sp(cn, "dbo.REP_SP_Dashboard", accion);
                    cmd.Parameters.Add("@desde", SqlDbType.Date).Value = desde.Date;
                    cmd.Parameters.Add("@hasta", SqlDbType.Date).Value = hasta.Date;
                    cmd.Parameters.Add("@sucursal", SqlDbType.Int).Value = sucursal;
                    return cmd;
                };

                using (var cmd = sp(1))
                using (var rd = cmd.ExecuteReader())
                    if (rd.Read())
                    {
                        int atendidas = Ent(rd, "CitasAtendidas"), canceladas = Ent(rd, "CitasCanceladas"), procs = Ent(rd, "Procedimientos");
                        decimal facturado = Dec(rd, "Facturado");
                        d.Indicadores = new IndicadoresDto
                        {
                            Pacientes = Ent(rd, "Pacientes"),
                            PacientesNuevos = Ent(rd, "PacientesNuevos"),
                            PacientesAtendidos = Ent(rd, "PacientesAtendidos"),
                            Citas = Ent(rd, "Citas"),
                            CitasAtendidas = atendidas,
                            CitasCanceladas = canceladas,
                            CitasPendientes = Ent(rd, "CitasPendientes"),
                            Asistencia = atendidas + canceladas == 0 ? 0 : Math.Round(100m * atendidas / (atendidas + canceladas), 1),
                            Procedimientos = procs,
                            Facturado = verDinero ? facturado : (decimal?)null,
                            Cobrado = verDinero ? Dec(rd, "Cobrado") : (decimal?)null,
                            TicketPromedio = verDinero && procs > 0 ? Math.Round(facturado / procs, 2) : (decimal?)null,
                            MinutosPromedio = DecN(rd, "MinutosPromedio"),
                            EnAtencion = Ent(rd, "EnAtencion"),
                            EnSala = Ent(rd, "EnSala")
                        };
                    }

                using (var cmd = sp(2))
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                        d.CitasPorDia.Add(new CitasDiaDto
                        {
                            Dia = Fecha(rd, "Dia").Value.ToString("yyyy-MM-dd", Inv),
                            Total = Ent(rd, "Total"),
                            Atendidas = Ent(rd, "Atendidas"),
                            Canceladas = Ent(rd, "Canceladas"),
                            Procedimientos = Ent(rd, "Procedimientos"),
                            Nuevos = Ent(rd, "Nuevos"),
                            Ingresos = verDinero ? Dec(rd, "Ingresos") : (decimal?)null,
                            IngresosEfectivo = verDinero ? Dec(rd, "IngresosEfectivo") : (decimal?)null
                        });

                using (var cmd = sp(8))
                using (var rd = cmd.ExecuteReader())
                    if (rd.Read())
                    {
                        int atendidas = Ent(rd, "CitasAtendidas"), canceladas = Ent(rd, "CitasCanceladas");
                        d.Anterior = new ComparativoDto
                        {
                            Desde = Fecha(rd, "Desde").Value.ToString("yyyy-MM-dd", Inv),
                            Hasta = Fecha(rd, "Hasta").Value.ToString("yyyy-MM-dd", Inv),
                            PacientesNuevos = Ent(rd, "PacientesNuevos"),
                            PacientesAtendidos = Ent(rd, "PacientesAtendidos"),
                            Citas = Ent(rd, "Citas"),
                            CitasAtendidas = atendidas,
                            CitasCanceladas = canceladas,
                            Asistencia = atendidas + canceladas == 0 ? 0 : Math.Round(100m * atendidas / (atendidas + canceladas), 1),
                            Procedimientos = Ent(rd, "Procedimientos"),
                            Facturado = verDinero ? Math.Round(Dec(rd, "Facturado"), 2) : (decimal?)null
                        };
                    }

                using (var cmd = sp(3))
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                        d.Especialistas.Add(new EspecialistaDesempenoDto
                        {
                            Id = Num(rd, "Id_Especialista"),
                            Especialista = Txt(rd, "Especialista"),
                            Activo = rd["Activo"] != DBNull.Value && Convert.ToBoolean(rd["Activo"]),
                            Citas = Ent(rd, "Citas"),
                            Atendidas = Ent(rd, "Atendidas"),
                            Canceladas = Ent(rd, "Canceladas"),
                            Procedimientos = Ent(rd, "Procedimientos"),
                            Pacientes = Ent(rd, "Pacientes"),
                            Facturado = verDinero ? Dec(rd, "Facturado") : (decimal?)null,
                            FacturadoCaja = verDinero ? Dec(rd, "FacturadoCaja") : (decimal?)null,
                            MinutosPromedio = DecN(rd, "MinutosPromedio")
                        });

                using (var cmd = sp(4))
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                        d.Tratamientos.Add(new ConteoDto { Nombre = Txt(rd, "Descripcion"), Cantidad = Ent(rd, "Cantidad"), Total = verDinero ? Dec(rd, "Total") : (decimal?)null });

                using (var cmd = sp(5))
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                        d.EstadosCita.Add(new ConteoDto { Nombre = Txt(rd, "Estado"), Color = Txt(rd, "Color"), Cantidad = Ent(rd, "Cantidad") });

                using (var cmd = sp(6))
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                    {
                        var ini = Fecha(rd, "Inicio");
                        d.Hoy.Add(new AgendaHoyDto
                        {
                            Hora = ini.HasValue && ini.Value.TimeOfDay != TimeSpan.Zero ? Formato.Hora(ini.Value) : "—",
                            Paciente = Txt(rd, "Paciente"),
                            Especialista = Txt(rd, "Especialista"),
                            Estado = Txt(rd, "Estado"),
                            Color = Txt(rd, "Color"),
                            EstadoProcedimiento = Txt(rd, "EstadoProcedimiento")
                        });
                    }

                using (var cmd = sp(7))
                using (var rd = cmd.ExecuteReader())
                {
                    var es = new CultureInfo("es-SV");
                    while (rd.Read())
                    {
                        var mes = Fecha(rd, "Mes").Value;
                        d.NuevosPorMes.Add(new ConteoDto { Nombre = es.TextInfo.ToTitleCase(mes.ToString("MMM yyyy", es).Replace(".", "")), Cantidad = Ent(rd, "Nuevos") });
                    }
                    rd.NextResult();
                    if (rd.Read())
                        foreach (var f in new[] { "Facebook", "Instagram", "TikTok", "WhatsApp", "Buscador", "Recomendado", "Otros", "SinDato" })
                            d.Fuentes.Add(new ConteoDto { Nombre = f == "SinDato" ? "Sin dato" : f == "Buscador" ? "Buscador web" : f, Cantidad = Ent(rd, f) });
                }

                using (var cmd = sp(10))
                using (var rd = cmd.ExecuteReader())
                {
                    while (rd.Read())
                        d.PacientesCitaDia.Add(new PacientesCitaDiaDto
                        {
                            Dia = Fecha(rd, "Dia").Value.ToString("yyyy-MM-dd", Inv),
                            Anteriores = Ent(rd, "Anteriores"),
                            Nuevos = Ent(rd, "Nuevos")
                        });
                    if (rd.NextResult() && rd.Read())
                        d.PacientesCitaPeriodo = new PacientesCitaDiaDto { Dia = "", Anteriores = Ent(rd, "Anteriores"), Nuevos = Ent(rd, "Nuevos") };
                }

                using (var cmd = sp(12))
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                    {
                        var ultima = Fecha(rd, "Ultima");
                        d.Garantias.Add(new GarantiaEspecialistaDto
                        {
                            Especialista = Txt(rd, "Especialista"),
                            Garantias = Ent(rd, "Garantias"),
                            Pacientes = Ent(rd, "Pacientes"),
                            Procedimientos = Ent(rd, "Procedimientos"),
                            Ultima = ultima.HasValue ? ultima.Value.ToString("yyyy-MM-dd", Inv) : ""
                        });
                    }

                if (verDinero)
                {
                    d.Metas = DPieCenter.Registros.MetasRepository.AvanceMes(hasta.Year, hasta.Month, 0);
                    // histórico: ventas contra meta de los últimos 6 meses hasta el mes de "Hasta"
                    try { d.MetasHistorico = DPieCenter.Registros.MetasRepository.Historico(hasta.Year, hasta.Month, 6); }
                    catch (Exception ex) { System.Diagnostics.Trace.TraceError("Histórico de metas: " + ex); }
                }

                if (verDinero)
                    using (var cmd = sp(11))
                    using (var rd = cmd.ExecuteReader())
                        while (rd.Read())
                            d.IngresosFormaPago.Add(new IngresoFormaPagoDto
                            {
                                Dia = Fecha(rd, "Dia").Value.ToString("yyyy-MM-dd", Inv),
                                Codigo = Txt(rd, "Codigo"),
                                FormaPago = Txt(rd, "FormaPago"),
                                Total = Dec(rd, "Total")
                            });
            }
            return d;
        }

        /// <summary>Top 10 de pacientes con más visitas (mínimo 2) entre desde y hasta.</summary>
        public static List<PacienteRecurrenteDto> TopPacientes(DateTime desde, DateTime hasta, bool verDinero, int sucursal = 0)
        {
            var lista = new List<PacienteRecurrenteDto>();
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, "dbo.REP_SP_Dashboard", 9))
            {
                cmd.Parameters.Add("@desde", SqlDbType.Date).Value = desde.Date;
                cmd.Parameters.Add("@hasta", SqlDbType.Date).Value = hasta.Date;
                    cmd.Parameters.Add("@sucursal", SqlDbType.Int).Value = sucursal;
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                        lista.Add(new PacienteRecurrenteDto
                        {
                            Id = Num(rd, "Id_Expediente"),
                            Paciente = Txt(rd, "Paciente"),
                            Celular = Txt(rd, "Celular"),
                            Visitas = Ent(rd, "Visitas"),
                            Procedimientos = Ent(rd, "Procedimientos"),
                            Total = verDinero ? Dec(rd, "Total") : (decimal?)null,
                            UltimaVisita = Fecha(rd, "UltimaVisita").HasValue ? Fecha(rd, "UltimaVisita").Value.ToString("dd/MM/yyyy", Inv) : "",
                            PrimeraVisita = Fecha(rd, "PrimeraVisita").HasValue ? Fecha(rd, "PrimeraVisita").Value.ToString("dd/MM/yyyy", Inv) : "",
                            Especialista = Txt(rd, "Especialista")
                        });
            }
            return lista;
        }

        // ===== Caja =====

        public static List<CajeroDto> Cajeros()
        {
            var lista = new List<CajeroDto>();
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, "dbo.REP_SP_Caja", 2))
            {
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                        lista.Add(new CajeroDto { Usuario = Txt(rd, "Cajero"), Nombre = Txt(rd, "Nombre") });
            }
            return lista;
        }

        private static void ParametrosCaja(SqlCommand cmd, DateTime desde, DateTime hasta, string cajero, int sucursal)
        {
            cmd.Parameters.Add("@desde", SqlDbType.Date).Value = desde.Date;
            cmd.Parameters.Add("@hasta", SqlDbType.Date).Value = hasta.Date;
                    cmd.Parameters.Add("@sucursal", SqlDbType.Int).Value = sucursal;
            cmd.Parameters.Add("@cajero", SqlDbType.VarChar, 20).Value = string.IsNullOrWhiteSpace(cajero) ? (object)DBNull.Value : cajero.Trim();
        }

        /// <param name="sucursal">0 = todas las sucursales.</param>
        public static CajaReporteDto Caja(DateTime desde, DateTime hasta, string cajero, int sucursal = 0)
        {
            var d = new CajaReporteDto
            {
                Ok = true,
                Desde = desde.ToString("yyyy-MM-dd", Inv),
                Hasta = hasta.ToString("yyyy-MM-dd", Inv),
                Cajero = cajero ?? "",
                Cobros = new List<CobroDto>()
            };
            var pagos = new List<Tuple<long, string, decimal>>();   // Id_Dte, forma de pago, monto

            using (var cn = new SqlConnection(Cn))
            {
                cn.Open();
                using (var cmd = Sp(cn, "dbo.REP_SP_Caja", 1))
                {
                    cmd.Parameters.Add("@desde", SqlDbType.Date).Value = desde.Date;
                    cmd.Parameters.Add("@hasta", SqlDbType.Date).Value = hasta.Date;
                    cmd.Parameters.Add("@sucursal", SqlDbType.Int).Value = sucursal;
                    cmd.Parameters.Add("@cajero", SqlDbType.VarChar, 20).Value = string.IsNullOrWhiteSpace(cajero) ? (object)DBNull.Value : cajero.Trim();
                    using (var rd = cmd.ExecuteReader())
                        while (rd.Read())
                        {
                            var hora = rd["HoraEmision"] == DBNull.Value ? (TimeSpan?)null : (TimeSpan)rd["HoraEmision"];
                            string tipo = Txt(rd, "TipoDte");
                            d.Cobros.Add(new CobroDto
                            {
                                IdDte = Num(rd, "Id_Dte"),
                                IdFactura = Num(rd, "Id_Factura"),
                                Fecha = Fecha(rd, "FechaEmision").Value.ToString("dd/MM/yyyy", Inv),
                                Hora = hora.HasValue ? Formato.Hora(hora.Value) : "",
                                TipoDte = TiposDte.ContainsKey(tipo) ? TiposDte[tipo] : tipo,
                                NumeroControl = Txt(rd, "NumeroControl"),
                                Cliente = Txt(rd, "Cliente"),
                                Paciente = Txt(rd, "Paciente"),
                                FormaPago = Txt(rd, "FormaPagoTexto"),
                                Referencia = Txt(rd, "Referencia"),
                                Gravado = Dec(rd, "Gravado"),
                                Iva = Dec(rd, "Iva"),
                                Total = Dec(rd, "Total"),
                                Anulado = Txt(rd, "Estado") == "A",
                                Cajero = Txt(rd, "Cajero"),
                                CajeroNombre = Txt(rd, "CajeroNombre"),
                                Descuento = Dec(rd, "Descuento"),
                                DescuentoTratamiento = Dec(rd, "DescuentoTratamiento"),
                                DescuentoCupon = Dec(rd, "DescuentoCupon"),
                                Cupon = Txt(rd, "Cupon"),
                                Ticket = tipo == "TK",
                                FechaAnulacion = rd["FechaAnulacion"] == DBNull.Value ? "" : Formato.FechaHora(Convert.ToDateTime(rd["FechaAnulacion"])),
                                MotivoAnulacion = Txt(rd, "MotivoAnulacion"),
                                UsuarioAnula = Txt(rd, "UsuarioAnula")
                            });
                        }
                }

                using (var cmd = Sp(cn, "dbo.REP_SP_Caja", 3))
                {
                    cmd.Parameters.Add("@desde", SqlDbType.Date).Value = desde.Date;
                    cmd.Parameters.Add("@hasta", SqlDbType.Date).Value = hasta.Date;
                    cmd.Parameters.Add("@sucursal", SqlDbType.Int).Value = sucursal;
                    using (var rd = cmd.ExecuteReader())
                        if (rd.Read()) { d.PendientesFacturas = Ent(rd, "Facturas"); d.PendientesTotal = Dec(rd, "Total"); }
                }

                // Líneas de pago de los DTE vigentes (pago combinado): cada forma suma su parte
                using (var cmd = Sp(cn, "dbo.REP_SP_Caja", 6))
                {
                    ParametrosCaja(cmd, desde, hasta, cajero, sucursal);
                    using (var rd = cmd.ExecuteReader())
                        while (rd.Read())
                            pagos.Add(Tuple.Create(Num(rd, "Id_Dte"), Txt(rd, "FormaPago"), Dec(rd, "Monto")));
                }

                d.Cajas = new List<CajaDiaDto>();
                using (var cmd = Sp(cn, "dbo.REP_SP_Caja", 4))
                {
                    ParametrosCaja(cmd, desde, hasta, cajero, sucursal);
                    using (var rd = cmd.ExecuteReader())
                        while (rd.Read())
                        {
                            var cierre = Fecha(rd, "FechaCierre");
                            d.Cajas.Add(new CajaDiaDto
                            {
                                Id = Num(rd, "Id_Apertura"), Fecha = Fecha(rd, "FechaApertura").Value.ToString("dd/MM/yyyy", Inv),
                                Cajero = Txt(rd, "Cajero"), CajeroNombre = Txt(rd, "CajeroNombre"), Fondo = Dec(rd, "Fondo"),
                                Apertura = Formato.Hora(Fecha(rd, "HoraApertura")),
                                Cierre = cierre.HasValue ? cierre.Value.ToString("dd/MM ", Inv) + Formato.Hora(cierre.Value) : "",
                                Abierta = Convert.ToBoolean(rd["Abierta"]), Cobrado = Dec(rd, "Cobrado"), Efectivo = Dec(rd, "Efectivo"),
                                Documentos = Ent(rd, "Documentos"), Tickets = Ent(rd, "Tickets"),
                                Salidas = Dec(rd, "Salidas"), CantidadSalidas = Ent(rd, "CantidadSalidas"),
                                Entradas = Dec(rd, "Entradas"), CantidadEntradas = Ent(rd, "CantidadEntradas"),
                                EfectivoEsperado = Dec(rd, "EfectivoEsperado"),
                                EfectivoContado = rd["EfectivoContado"] == DBNull.Value ? (decimal?)null : Convert.ToDecimal(rd["EfectivoContado"]),
                                Sobrante = Dec(rd, "Sobrante"), Faltante = Dec(rd, "Faltante"), Observaciones = Txt(rd, "Observaciones"),
                                DescuentoTratamientos = Dec(rd, "DescuentoTratamientos"), DescuentoCupones = Dec(rd, "DescuentoCupones")
                            });
                        }
                }

                d.SalidasDetalle = new List<SalidaReporteDto>();
                using (var cmd = Sp(cn, "dbo.REP_SP_Caja", 5))
                {
                    ParametrosCaja(cmd, desde, hasta, cajero, sucursal);
                    using (var rd = cmd.ExecuteReader())
                        while (rd.Read())
                            d.SalidasDetalle.Add(new SalidaReporteDto
                            {
                                Id = Num(rd, "Id_Salida"), Entrada = Txt(rd, "Tipo") == "E", Fecha = Formato.FechaHora(Fecha(rd, "FechaCrea")),
                                CajeroNombre = Txt(rd, "CajeroNombre"), Monto = Dec(rd, "Monto"), Categoria = Txt(rd, "Categoria"),
                                Motivo = Txt(rd, "Motivo"), Referencia = Txt(rd, "Referencia"), Anulada = Txt(rd, "Estado") != "A",
                                MotivoAnulacion = Txt(rd, "MotivoAnulacion")
                            });
                }
            }

            var salidas = d.SalidasDetalle.Where(s => !s.Anulada && !s.Entrada).ToList();
            d.Salidas = salidas.Sum(s => s.Monto);
            d.Entradas = d.SalidasDetalle.Where(s => !s.Anulada && s.Entrada).Sum(s => s.Monto);
            d.PorCategoriaSalida = salidas.GroupBy(s => s.Categoria)
                .Select(g => new TotalGrupoDto { Nombre = g.Key, Documentos = g.Count(), Total = g.Sum(s => s.Monto) })
                .OrderByDescending(g => g.Total).ToList();
            d.Sobrantes = d.Cajas.Sum(c => c.Sobrante);
            d.Faltantes = d.Cajas.Sum(c => c.Faltante);
            d.CajasAbiertas = d.Cajas.Count(c => c.Abierta);

            // Tickets POS (servicios sin costo): se listan y cuentan aparte, no son documentos cobrados
            d.Tickets = d.Cobros.Count(c => c.Ticket);
            var porTipo = d.Cobros.Where(c => !c.Anulado).GroupBy(c => c.TipoDte)
                .Select(g => new TotalGrupoDto { Nombre = g.Key, Documentos = g.Count(), Total = g.Sum(c => c.Total) })
                .OrderByDescending(g => g.Total).ToList();

            // Totales: los anulados se listan pero no suman
            var validos = d.Cobros.Where(c => !c.Anulado && !c.Ticket).ToList();
            d.Descuentos = validos.Sum(c => c.Descuento);
            d.DescuentosTratamientos = validos.Sum(c => c.DescuentoTratamiento);
            d.DescuentosCupones = validos.Sum(c => c.DescuentoCupon);
            d.ConDescuentoTratamiento = validos.Count(c => c.DescuentoTratamiento > 0);
            d.Cupones = validos.Count(c => c.Cupon != "" && c.DescuentoCupon > 0);
            d.Total = validos.Sum(c => c.Total);
            d.Gravado = validos.Sum(c => c.Gravado);
            d.Iva = validos.Sum(c => c.Iva);
            d.Documentos = validos.Count;
            d.TicketPromedio = d.Documentos == 0 ? 0 : Math.Round(d.Total / d.Documentos, 2);
            d.Anulados = d.Cobros.Count(c => c.Anulado);
            d.TotalAnulado = d.Cobros.Where(c => c.Anulado).Sum(c => c.Total);

            Func<Func<CobroDto, string>, List<TotalGrupoDto>> agrupar = clave => validos
                .GroupBy(clave)
                .Select(g => new TotalGrupoDto { Nombre = g.Key, Documentos = g.Count(), Total = g.Sum(c => c.Total) })
                .OrderByDescending(g => g.Total).ToList();

            // Por forma de pago: por línea de pago; un documento combinado cuenta en cada forma que usó
            var vigentes = new HashSet<long>(validos.Select(c => c.IdDte));
            d.PorFormaPago = pagos.Where(p => vigentes.Contains(p.Item1)).GroupBy(p => p.Item2)
                .Select(g => new TotalGrupoDto { Nombre = g.Key, Documentos = g.Select(p => p.Item1).Distinct().Count(), Total = g.Sum(p => p.Item3) })
                .OrderByDescending(g => g.Total).ToList();
            d.PorCajero = agrupar(c => c.CajeroNombre);
            d.PorTipo = porTipo;
            d.PorDia = validos.GroupBy(c => c.Fecha)
                .Select(g => new TotalGrupoDto { Nombre = g.Key, Documentos = g.Count(), Total = g.Sum(c => c.Total) })
                .OrderBy(g => DateTime.ParseExact(g.Nombre, "dd/MM/yyyy", Inv)).ToList();
            return d;
        }
    }
}
