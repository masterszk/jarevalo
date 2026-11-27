using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;
using System.Linq;
using DPieCenter.Registros;

namespace DPieCenter.Reportes
{
    /// <summary>Reportes de citas, procedimientos y expedientes: dbo.REP_SP_Reportes (Reportes/sql/REP_Reportes.sql).</summary>
    public static class ReportesDetalleRepository
    {
        private static readonly CultureInfo Inv = CultureInfo.InvariantCulture;
        private static readonly CultureInfo Es = new CultureInfo("es-SV");

        private static string Cn
        {
            get { return ConfigurationManager.ConnectionStrings["conexionDiarypro"].ConnectionString; }
        }

        private static string Txt(IDataRecord r, string c) { var v = r[c]; return v == DBNull.Value ? "" : Convert.ToString(v).Trim(); }
        private static long Num(IDataRecord r, string c) { var v = r[c]; return v == DBNull.Value ? 0 : Convert.ToInt64(v); }
        private static decimal Dec(IDataRecord r, string c) { var v = r[c]; return v == DBNull.Value ? 0 : Convert.ToDecimal(v); }
        private static bool Bit(IDataRecord r, string c) { var v = r[c]; return v != DBNull.Value && Convert.ToBoolean(v); }
        private static DateTime? Fecha(IDataRecord r, string c) { var v = r[c]; return v == DBNull.Value ? (DateTime?)null : Convert.ToDateTime(v); }
        private static string Dia(DateTime? d) { return d.HasValue ? d.Value.ToString("dd/MM/yyyy", Inv) : ""; }
        private static string Hora(DateTime? d) { return d.HasValue && d.Value.TimeOfDay != TimeSpan.Zero ? Formato.Hora(d.Value) : ""; }

        private static SqlCommand Sp(SqlConnection cn, int accion, FiltroReporteDto f, DateTime desde, DateTime hasta)
        {
            var cmd = new SqlCommand("dbo.REP_SP_Reportes", cn) { CommandType = CommandType.StoredProcedure, CommandTimeout = 60 };
            cmd.Parameters.Add("@accion", SqlDbType.Int).Value = accion;
            cmd.Parameters.Add("@desde", SqlDbType.Date).Value = desde.Date;
            cmd.Parameters.Add("@hasta", SqlDbType.Date).Value = hasta.Date;
            cmd.Parameters.Add("@especialista", SqlDbType.BigInt).Value = Math.Max(0, f.Especialista);
            cmd.Parameters.Add("@estado", SqlDbType.BigInt).Value = Math.Max(0, f.Estado);
            cmd.Parameters.Add("@tipoCita", SqlDbType.BigInt).Value = Math.Max(0, f.TipoCita);
            cmd.Parameters.Add("@tratamiento", SqlDbType.BigInt).Value = Math.Max(0, f.Tratamiento);
            cmd.Parameters.Add("@sexo", SqlDbType.BigInt).Value = Math.Max(0, f.Sexo);
            cmd.Parameters.Add("@departamento", SqlDbType.BigInt).Value = Math.Max(0, f.Departamento);
            cmd.Parameters.Add("@fuente", SqlDbType.VarChar, 20).Value = string.IsNullOrWhiteSpace(f.Fuente) ? (object)DBNull.Value : f.Fuente.Trim();
            cmd.Parameters.Add("@paciente", SqlDbType.VarChar, 100).Value = string.IsNullOrWhiteSpace(f.Paciente) ? (object)DBNull.Value : f.Paciente.Trim();
            cmd.Parameters.Add("@sucursal", SqlDbType.Int).Value = Sesion.SucursalFiltro(f.Sucursal);
            return cmd;
        }

        private static List<TotalGrupoDto> Agrupar<T>(IEnumerable<T> filas, Func<T, string> clave, Func<T, decimal> valor)
        {
            return filas.GroupBy(x => string.IsNullOrWhiteSpace(clave(x)) ? "(sin dato)" : clave(x))
                .Select(g => new TotalGrupoDto { Nombre = g.Key, Documentos = g.Count(), Total = g.Sum(valor) })
                .OrderByDescending(g => g.Documentos).ThenByDescending(g => g.Total).ToList();
        }

        /// <summary>
        /// Garantías de servicios registradas en el periodo (dbo.REP_SP_Garantias, Reportes/sql/REP_Garantias.sql).
        /// f.Estado: 0 todas | 1 no vistas | 2 vistas por el especialista.
        /// </summary>
        public static ReporteGarantiasDto Garantias(FiltroReporteDto f, DateTime desde, DateTime hasta)
        {
            var d = new ReporteGarantiasDto
            {
                Ok = true, Desde = desde.ToString("yyyy-MM-dd", Inv), Hasta = hasta.ToString("yyyy-MM-dd", Inv),
                Items = new List<GarantiaReporteDto>(), PorEspecialista = new List<GarantiaEspecialistaReporteDto>()
            };
            var procs = new Dictionary<string, int>();
            using (var cn = new SqlConnection(Cn))
            {
                cn.Open();
                for (int accion = 1; accion <= 2; accion++)
                    using (var cmd = new SqlCommand("dbo.REP_SP_Garantias", cn) { CommandType = CommandType.StoredProcedure, CommandTimeout = 60 })
                    {
                        cmd.Parameters.Add("@accion", SqlDbType.Int).Value = accion;
                        cmd.Parameters.Add("@desde", SqlDbType.Date).Value = desde.Date;
                        cmd.Parameters.Add("@hasta", SqlDbType.Date).Value = hasta.Date;
                        cmd.Parameters.Add("@especialista", SqlDbType.BigInt).Value = Math.Max(0, f.Especialista);
                        cmd.Parameters.Add("@visto", SqlDbType.Int).Value = (int)Math.Max(0, Math.Min(2, f.Estado));
                        cmd.Parameters.Add("@tratamiento", SqlDbType.BigInt).Value = Math.Max(0, f.Tratamiento);
                        cmd.Parameters.Add("@paciente", SqlDbType.VarChar, 100).Value = string.IsNullOrWhiteSpace(f.Paciente) ? (object)DBNull.Value : f.Paciente.Trim();
                        cmd.Parameters.Add("@sucursal", SqlDbType.Int).Value = Sesion.SucursalFiltro(f.Sucursal);
                        using (var rd = cmd.ExecuteReader())
                            while (rd.Read())
                            {
                                if (accion == 2) { procs[Txt(rd, "Especialista")] = (int)Num(rd, "Procedimientos"); continue; }
                                var fecha = Fecha(rd, "Fecha");
                                var fp = Fecha(rd, "FechaProcedimiento");
                                var fv = Fecha(rd, "FechaVisto");
                                var fm = Fecha(rd, "FechaModifica");
                                d.Items.Add(new GarantiaReporteDto
                                {
                                    Id = Num(rd, "Id_Reclamo"),
                                    Fecha = fecha.HasValue ? Formato.FechaHora(fecha.Value) : "",
                                    FechaIso = fecha.HasValue ? fecha.Value.ToString("yyyy-MM-dd", Inv) : "",
                                    Usuario = Txt(rd, "Usuario"),
                                    Modificada = fm.HasValue ? Txt(rd, "UsuarioModifica") + " · " + Formato.FechaHora(fm.Value) : "",
                                    Garantia = Txt(rd, "Reclamo"),
                                    IdEspecialista = Num(rd, "Id_Especialista"), Especialista = Txt(rd, "Especialista"),
                                    IdExpediente = Num(rd, "Id_Expediente"), Paciente = Txt(rd, "Paciente"),
                                    Documento = Txt(rd, "Documento"), Celular = Txt(rd, "Celular"),
                                    IdProcedimiento = Num(rd, "Id_Procedimiento"), FechaProcedimiento = Dia(fp),
                                    DiasDesdeProcedimiento = fecha.HasValue && fp.HasValue ? (int?)Math.Max(0, (fecha.Value.Date - fp.Value.Date).Days) : null,
                                    Tratamientos = Txt(rd, "Tratamientos"),
                                    Visto = Bit(rd, "Visto"),
                                    VistoDetalle = fv.HasValue ? Txt(rd, "UsuarioVisto") + " · " + Formato.FechaHora(fv.Value) : "",
                                    Sucursal = Txt(rd, "Sucursal")
                                });
                            }
                    }
            }

            var g = d.Items;
            d.Garantias = g.Count;
            d.Pacientes = g.Select(x => x.IdExpediente).Distinct().Count();
            d.NoVistas = g.Count(x => !x.Visto);
            d.Procedimientos = procs.Values.Sum();
            d.Porcentaje = d.Procedimientos > 0 ? Math.Round(100m * d.Garantias / d.Procedimientos, 1) : 0;
            var dias = g.Where(x => x.DiasDesdeProcedimiento.HasValue).Select(x => (decimal)x.DiasDesdeProcedimiento.Value).ToList();
            d.DiasPromedio = dias.Count > 0 ? Math.Round(dias.Average(), 1) : (decimal?)null;

            // por especialista: también los que tienen procedimientos y ninguna garantía
            foreach (var nombre in g.Select(x => x.Especialista).Union(procs.Keys).Distinct())
            {
                int n = g.Count(x => x.Especialista == nombre), pr;
                procs.TryGetValue(nombre, out pr);
                d.PorEspecialista.Add(new GarantiaEspecialistaReporteDto
                {
                    Especialista = string.IsNullOrWhiteSpace(nombre) ? "(sin especialista)" : nombre,
                    Garantias = n, Procedimientos = pr, NoVistas = g.Count(x => x.Especialista == nombre && !x.Visto),
                    Porcentaje = pr > 0 ? Math.Round(100m * n / pr, 1) : 0
                });
            }
            d.PorEspecialista = d.PorEspecialista.OrderByDescending(x => x.Garantias).ThenByDescending(x => x.Porcentaje).ThenBy(x => x.Especialista).ToList();

            // por tratamiento: cada tratamiento del procedimiento cuenta una vez por garantía
            d.PorTratamiento = g.SelectMany(x => (x.Tratamientos ?? "").Split(new[] { ", " }, StringSplitOptions.RemoveEmptyEntries).Select(t => t.Trim()).Distinct()
                    .DefaultIfEmpty("(sin tratamiento)"))
                .GroupBy(t => t).Select(x => new TotalGrupoDto { Nombre = x.Key, Documentos = x.Count() })
                .OrderByDescending(x => x.Documentos).ThenBy(x => x.Nombre).ToList();

            // por semana (lunes de cada semana)
            d.PorSemana = g.Where(x => x.FechaIso != "")
                .GroupBy(x => { var f0 = DateTime.ParseExact(x.FechaIso, "yyyy-MM-dd", Inv); return f0.AddDays(-(((int)f0.DayOfWeek + 6) % 7)); })
                .OrderBy(x => x.Key)
                .Select(x => new TotalGrupoDto { Nombre = "Semana del " + x.Key.ToString("dd/MM", Inv), Documentos = x.Count() }).ToList();
            return d;
        }

        /// <summary>
        /// Caja por especialista (dbo.REP_SP_CajaEspecialistas, Reportes/sql/REP_CajaEspecialistas.sql): DTE vigentes del periodo
        /// asignados al especialista que atendió, más los pagos adelantados aplicados (solo suman a la venta sin IVA).
        /// </summary>
        public static ReporteCajaEspecialistasDto CajaEspecialistas(FiltroReporteDto f, DateTime desde, DateTime hasta)
        {
            var d = new ReporteCajaEspecialistasDto
            {
                Ok = true, Desde = desde.ToString("yyyy-MM-dd", Inv), Hasta = hasta.ToString("yyyy-MM-dd", Inv),
                Items = new List<CobroEspecialistaDto>()
            };
            var exacto = new Dictionary<CobroEspecialistaDto, decimal>();   // sin IVA sin redondear: se redondea al sumar
            var pagosDte = new Dictionary<long, List<TotalGrupoDto>>();     // pago combinado: líneas de pago de cada DTE
            var dia = new Dictionary<CobroEspecialistaDto, DateTime>();
            using (var cn = new SqlConnection(Cn))
            using (var cmd = new SqlCommand("dbo.REP_SP_CajaEspecialistas", cn) { CommandType = CommandType.StoredProcedure, CommandTimeout = 60 })
            {
                cmd.Parameters.Add("@accion", SqlDbType.Int).Value = 1;
                cmd.Parameters.Add("@desde", SqlDbType.Date).Value = desde.Date;
                cmd.Parameters.Add("@hasta", SqlDbType.Date).Value = hasta.Date;
                cmd.Parameters.Add("@especialista", SqlDbType.BigInt).Value = Math.Max(0, f.Especialista);
                cmd.Parameters.Add("@formaPago", SqlDbType.VarChar, 2).Value = f.FormaPago > 0 && f.FormaPago < 100 ? (object)f.FormaPago.ToString("00", Inv) : DBNull.Value;
                cmd.Parameters.Add("@paciente", SqlDbType.VarChar, 100).Value = string.IsNullOrWhiteSpace(f.Paciente) ? (object)DBNull.Value : f.Paciente.Trim();
                cmd.Parameters.Add("@sucursal", SqlDbType.Int).Value = Sesion.SucursalFiltro(f.Sucursal);
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                    {
                        bool cobro = Txt(rd, "Clase") == "D";
                        string origen = Txt(rd, "Origen"), tipo = Txt(rd, "TipoDte");
                        var fecha = Fecha(rd, "Fecha");
                        var x = new CobroEspecialistaDto
                        {
                            Id = Num(rd, "Id"),
                            Cobro = cobro,
                            Fecha = fecha.HasValue ? Formato.FechaHora(fecha.Value) : "",
                            Tipo = !cobro ? "Pago adelantado aplicado" : tipo == "01" ? "Factura" : tipo == "03" ? "Crédito fiscal" : tipo == "14" ? "Sujeto excluido" : "DTE " + tipo,
                            Documento = Txt(rd, "Documento"),
                            IdExpediente = Num(rd, "Id_Expediente"),
                            Paciente = Txt(rd, "Paciente"),
                            DocumentoPaciente = Txt(rd, "DocumentoPaciente"),
                            FormaPago = Txt(rd, "FormaPagoTexto"),
                            Gravado = Dec(rd, "Gravado"),
                            Iva = Dec(rd, "Iva"),
                            Total = Dec(rd, "Total"),
                            SinIva = Math.Round(Dec(rd, "SinIva"), 2, MidpointRounding.AwayFromZero),
                            Origen = origen == "P" ? "Procedimiento" : origen == "C" ? "Pago adelantado de cita" : origen == "L" ? "Pago adelantado sin cita" : "Pago adelantado aplicado",
                            Especialista = Txt(rd, "Especialista"),
                            IdEspecialista = Num(rd, "Id_Especialista"),
                            IdProcedimiento = Num(rd, "Id_Procedimiento"),
                            FechaAtencion = Dia(Fecha(rd, "FechaAtencion")),
                            Tratamientos = Txt(rd, "Tratamientos"),
                            Cajero = Txt(rd, "Cajero"),
                            Sucursal = Txt(rd, "Sucursal")
                        };
                        if (x.Especialista == "") x.Especialista = origen == "L" ? "(pago adelantado sin cita)" : "(sin especialista)";
                        exacto[x] = Dec(rd, "SinIva");
                        if (fecha.HasValue) dia[x] = fecha.Value.Date;
                        d.Items.Add(x);
                    }

                cmd.Parameters["@accion"].Value = 3;
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                    {
                        long id = Num(rd, "Id_Dte");
                        List<TotalGrupoDto> l;
                        if (!pagosDte.TryGetValue(id, out l)) pagosDte[id] = l = new List<TotalGrupoDto>();
                        l.Add(new TotalGrupoDto { Nombre = Txt(rd, "FormaPago"), Documentos = 1, Total = Dec(rd, "Monto") });
                    }
            }

            // Cobrado por forma de pago: por línea de pago (un documento combinado cuenta en cada forma que usó)
            Func<IEnumerable<CobroEspecialistaDto>, List<TotalGrupoDto>> porForma = l => l
                .SelectMany(x => pagosDte.ContainsKey(x.Id) ? pagosDte[x.Id] : new List<TotalGrupoDto> { new TotalGrupoDto { Nombre = x.FormaPago, Documentos = 1, Total = x.Total } })
                .GroupBy(g => g.Nombre)
                .Select(g => new TotalGrupoDto { Nombre = g.Key, Documentos = g.Count(), Total = g.Sum(z => z.Total) })
                .OrderByDescending(g => g.Total).ToList();

            Func<IEnumerable<CobroEspecialistaDto>, decimal> sinIva = l => Math.Round(l.Sum(x => exacto[x]), 2, MidpointRounding.AwayFromZero);
            var cobros = d.Items.Where(x => x.Cobro).ToList();
            d.Cobrado = cobros.Sum(x => x.Total);
            d.Iva = cobros.Sum(x => x.Iva);
            d.SinIva = sinIva(d.Items);
            d.Adelantos = sinIva(d.Items.Where(x => !x.Cobro));
            d.Documentos = cobros.Count;
            d.Pacientes = d.Items.Where(x => x.IdExpediente > 0).Select(x => x.IdExpediente).Distinct().Count();
            d.TicketPromedio = d.Documentos > 0 ? Math.Round(d.Cobrado / d.Documentos, 2) : 0;

            d.PorFormaPago = porForma(cobros);
            d.FormasPago = d.PorFormaPago.Select(g => g.Nombre).ToList();
            d.PorDia = cobros.Where(x => dia.ContainsKey(x)).GroupBy(x => dia[x]).OrderBy(g => g.Key)
                .Select(g => new TotalGrupoDto { Nombre = g.Key.ToString("dd/MM/yyyy", Inv), Documentos = g.Count(), Total = g.Sum(x => x.Total) }).ToList();

            d.PorEspecialista = d.Items.GroupBy(x => x.Especialista).Select(g =>
            {
                var c = g.Where(x => x.Cobro).ToList();
                decimal cobrado = c.Sum(x => x.Total);
                return new CajaEspecialistaDto
                {
                    Especialista = g.Key,
                    Documentos = c.Count,
                    Pacientes = g.Where(x => x.IdExpediente > 0).Select(x => x.IdExpediente).Distinct().Count(),
                    Cobrado = cobrado,
                    Iva = c.Sum(x => x.Iva),
                    SinIva = sinIva(g),
                    Adelantos = sinIva(g.Where(x => !x.Cobro)),
                    Porcentaje = d.Cobrado > 0 ? Math.Round(100m * cobrado / d.Cobrado, 1) : 0,
                    PorFormaPago = porForma(c),
                    IdEspecialista = g.Select(x => x.IdEspecialista).FirstOrDefault(x => x > 0)
                };
            }).OrderByDescending(x => x.Cobrado).ThenByDescending(x => x.SinIva).ThenBy(x => x.Especialista).ToList();

            MetasYComision(d, f, hasta, exacto, dia);
            return d;
        }

        /// <summary>
        /// Meta activa del mes de la fecha final y comisión de cada especialista (Registros/MetasRepository.Calcular):
        /// las ventas sin IVA del periodo se separan por mes y cada mes se calcula con la meta y la escala de ese mes.
        /// </summary>
        private static void MetasYComision(ReporteCajaEspecialistasDto d, FiltroReporteDto f, DateTime hasta,
            Dictionary<CobroEspecialistaDto, decimal> exacto, Dictionary<CobroEspecialistaDto, DateTime> dia)
        {
            var mesFinal = new DateTime(hasta.Year, hasta.Month, 1);
            Func<CobroEspecialistaDto, DateTime> mesDe = x => { DateTime t; return dia.TryGetValue(x, out t) ? new DateTime(t.Year, t.Month, 1) : mesFinal; };
            var meses = d.Items.Select(mesDe).Concat(new[] { mesFinal }).Distinct().OrderBy(m => m).ToList();

            // meta vigente de cada especialista en cada mes
            var metas = new Dictionary<DateTime, Dictionary<long, Registros.MetaDto>>();
            foreach (var m in meses)
                metas[m] = Registros.MetasRepository.AvanceMes(m.Year, m.Month, 0).Especialistas
                    .Where(a => a.Meta != null).ToDictionary(a => a.IdEspecialista, a => a.Meta);

            d.MetaPeriodo = Registros.MetasRepository.NombrePeriodo(mesFinal.Year, mesFinal.Month);
            decimal ventasMesFinal = 0;
            foreach (var e in d.PorEspecialista)
            {
                if (e.IdEspecialista <= 0) continue;
                var porMes = d.Items.Where(x => x.IdEspecialista == e.IdEspecialista).GroupBy(mesDe)
                    .ToDictionary(g => g.Key, g => Math.Round(g.Sum(x => exacto[x]), 2, MidpointRounding.AwayFromZero));
                Registros.MetaDto metaFinal;
                if (metas[mesFinal].TryGetValue(e.IdEspecialista, out metaFinal))
                {
                    e.Meta = metaFinal.MetaVentas;
                    d.MetaMes += metaFinal.MetaVentas;
                    d.MetaEspecialistas++;
                    decimal v; if (porMes.TryGetValue(mesFinal, out v)) ventasMesFinal += v;
                }
                var detalles = new List<string>();
                foreach (var pm in porMes.OrderBy(p => p.Key))
                {
                    Registros.MetaDto meta;
                    if (!metas[pm.Key].TryGetValue(e.IdEspecialista, out meta)) continue;
                    var a = new Registros.AvanceMetaDto { IdEspecialista = e.IdEspecialista, Ventas = pm.Value };
                    Registros.MetasRepository.Calcular(a, meta);
                    e.Comision += a.TotalBono;
                    if (pm.Key == mesFinal) { e.PorcentajeEscala = a.PorcentajeEscala; e.BonoAlcance = a.BonoAlcance; }
                    string texto = a.DetalleComision;
                    if (a.BonoEscala > 0) texto += (texto.Length > 0 ? " + " : "") + "bono de escala " + a.BonoEscala.ToString("#,##0.00", Inv);
                    if (a.BonoAlcance > 0) texto += (texto.Length > 0 ? " + " : "") + "bono por meta " + a.BonoAlcance.ToString("#,##0.00", Inv);
                    if (meta.Escalas == null || meta.Escalas.Count == 0) { texto = "la meta no tiene escalas de comisión (Registros › Metas)"; if (pm.Key == mesFinal) e.SinEscalas = true; }
                    else if (texto.Length == 0) texto = "bajo el mínimo para comisionar (" + meta.MinimoComision.ToString("#,##0.00", Inv) + ")";
                    detalles.Add((porMes.Count > 1 ? Registros.MetasRepository.NombrePeriodo(pm.Key.Year, pm.Key.Month) + ": " : "") + texto);
                }
                e.DetalleComision = string.Join(" · ", detalles);
                d.Comision += e.Comision;
            }
            d.MetaAvance = d.MetaMes > 0 ? Math.Round(100m * ventasMesFinal / d.MetaMes, 1) : 0;
        }

        /// <summary>Formas de pago activas (CAT-017) con el código como número (01 → 1) para el filtro.</summary>
        public static List<OpcionDto> FormasPago()
        {
            var l = new List<OpcionDto>();
            using (var cn = new SqlConnection(Cn))
            using (var cmd = new SqlCommand("dbo.REP_SP_CajaEspecialistas", cn) { CommandType = CommandType.StoredProcedure })
            {
                cmd.Parameters.Add("@accion", SqlDbType.Int).Value = 2;
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                    {
                        int codigo;
                        if (int.TryParse(Txt(rd, "Codigo"), NumberStyles.Integer, Inv, out codigo) && codigo > 0)
                            l.Add(new OpcionDto { Id = codigo, Texto = Txt(rd, "Descripcion") });
                    }
            }
            return l;
        }

        public static CatalogosReporteDto Catalogos()
        {
            var d = new CatalogosReporteDto { Ok = true };
            var listas = new List<List<OpcionDto>>();
            using (var cn = new SqlConnection(Cn))
            using (var cmd = new SqlCommand("dbo.REP_SP_Reportes", cn) { CommandType = CommandType.StoredProcedure })
            {
                cmd.Parameters.Add("@accion", SqlDbType.Int).Value = 4;
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    do
                    {
                        var l = new List<OpcionDto>();
                        while (rd.Read()) l.Add(new OpcionDto { Id = Num(rd, "Id"), Texto = Txt(rd, "Texto") });
                        listas.Add(l);
                    } while (rd.NextResult());
            }
            d.Especialistas = listas[0]; d.Estados = listas[1]; d.TiposCita = listas[2];
            d.Tratamientos = listas[3]; d.Sexos = listas[4]; d.Departamentos = listas[5];
            // Sucursal: los administradores eligen (o ven todas); los demás, la suya sin selector
            d.SucursalActual = Sesion.Sucursal;
            d.Sucursales = Sesion.EsAdministrador ? Opciones.SucursalesRepository.Activas() : null;
            return d;
        }

        // ===== Citas =====
        public static ReporteCitasDto Citas(FiltroReporteDto f, DateTime desde, DateTime hasta)
        {
            var d = new ReporteCitasDto { Ok = true, Desde = desde.ToString("yyyy-MM-dd", Inv), Hasta = hasta.ToString("yyyy-MM-dd", Inv), Items = new List<CitaReporteDto>() };
            var extra = new List<Tuple<CitaReporteDto, bool, bool, DateTime?>>();   // cancelada, finalizada, inicio
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, 1, f, desde, hasta))
            {
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                    {
                        var ini = Fecha(rd, "Inicio");
                        string hora = Hora(ini);
                        if (hora == "") hora = Formato.HoraTexto(Txt(rd, "HoraHorario"));
                        var c = new CitaReporteDto
                        {
                            Id = Num(rd, "Id_Cita"),
                            Fecha = Dia(ini),
                            Hora = hora,
                            IdExpediente = Num(rd, "Id_Expediente"),
                            Paciente = Txt(rd, "Paciente"),
                            Documento = Txt(rd, "Documento"),
                            Celular = Txt(rd, "Celular"),
                            TipoCita = Txt(rd, "TipoCita"),
                            Especialista = Txt(rd, "Especialista"),
                            Estado = Txt(rd, "Estado"),
                            Color = Txt(rd, "Color"),
                            Tratamientos = Txt(rd, "Tratamientos"),
                            Valor = Dec(rd, "Valor"),
                            Comentarios = Txt(rd, "Comentarios"),
                            CreadoPor = Txt(rd, "UsuarioCrea"),
                            Creado = Formato.FechaHora(Fecha(rd, "FechaCrea"))
                        };
                        d.Items.Add(c);
                        extra.Add(Tuple.Create(c, Bit(rd, "EsCancelada"), Bit(rd, "EsFinalizada"), ini));
                    }
            }

            d.Total = d.Items.Count;
            d.Atendidas = extra.Count(x => x.Item3);
            d.Canceladas = extra.Count(x => x.Item2);
            d.Pendientes = extra.Count(x => !x.Item2 && !x.Item3 && x.Item4.HasValue && x.Item4.Value.Date >= DateTime.Today && x.Item1.Estado != "Anulado");   // una cita reprogramada sigue pendiente
            d.Asistencia = d.Atendidas + d.Canceladas == 0 ? 0 : Math.Round(100m * d.Atendidas / (d.Atendidas + d.Canceladas), 1);
            d.ValorAtendidas = extra.Where(x => x.Item3).Sum(x => x.Item1.Valor);
            d.ValorTotal = d.Items.Sum(x => x.Valor);
            d.PorEstado = Agrupar(d.Items, x => x.Estado, x => x.Valor);
            d.PorEspecialista = Agrupar(d.Items, x => x.Especialista, x => x.Valor);
            d.PorTipo = Agrupar(d.Items, x => x.TipoCita, x => x.Valor);
            // lunes a domingo, en ese orden
            d.PorDiaSemana = extra.Where(x => x.Item4.HasValue)
                .GroupBy(x => ((int)x.Item4.Value.DayOfWeek + 6) % 7)
                .OrderBy(g => g.Key)
                .Select(g => new TotalGrupoDto
                {
                    Nombre = Es.TextInfo.ToTitleCase(Es.DateTimeFormat.GetDayName(g.First().Item4.Value.DayOfWeek)),
                    Documentos = g.Count(),
                    Total = g.Sum(x => x.Item1.Valor)
                }).ToList();
            return d;
        }

        // ===== Procedimientos =====
        public static ReporteProcedimientosDto Procedimientos(FiltroReporteDto f, DateTime desde, DateTime hasta)
        {
            var d = new ReporteProcedimientosDto { Ok = true, Desde = desde.ToString("yyyy-MM-dd", Inv), Hasta = hasta.ToString("yyyy-MM-dd", Inv), Items = new List<ProcedimientoReporteDto>() };
            var porId = new Dictionary<long, ProcedimientoReporteDto>();
            var tratamientos = new List<Tuple<long, string, decimal>>();
            var fechas = new Dictionary<long, DateTime>();

            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, 2, f, desde, hasta))
            {
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                {
                    while (rd.Read())
                    {
                        var ini = Fecha(rd, "InicioProcedimiento");
                        var fin = Fecha(rd, "FinalProcedimiento");
                        int? minutos = null;
                        if (ini.HasValue && fin.HasValue)
                        {
                            // los antiguos guardan solo la hora (1900-01-01): se comparan las horas del mismo día
                            double m = YearReal(ini.Value) && YearReal(fin.Value) ? (fin.Value - ini.Value).TotalMinutes : (fin.Value.TimeOfDay - ini.Value.TimeOfDay).TotalMinutes;
                            if (m >= 1 && m <= 600) minutos = (int)Math.Round(m);
                        }
                        object cobrada = rd["FacturaCobrada"];
                        var p = new ProcedimientoReporteDto
                        {
                            Id = Num(rd, "Id_Procedimiento"),
                            Fecha = Dia(Fecha(rd, "Fecha")),
                            Horario = (Hora(ini) + (Hora(fin) != "" ? " - " + Hora(fin) : "")).Trim(),
                            Minutos = minutos,
                            IdExpediente = Num(rd, "Id_Expediente"),
                            Paciente = Txt(rd, "Paciente"),
                            Documento = Txt(rd, "Documento"),
                            Especialista = Txt(rd, "Especialista"),
                            TipoCita = Txt(rd, "TipoCita"),
                            Diagnostico = Txt(rd, "Diagnostico"),
                            IdFactura = Num(rd, "Id_Factura"),
                            Factura = cobrada == DBNull.Value ? "Sin factura" : (Convert.ToBoolean(cobrada) ? "Cobrada" : "Pendiente"),
                            Usuario = Txt(rd, "Usuario")
                        };
                        d.Items.Add(p);
                        porId[p.Id] = p;
                        fechas[p.Id] = Fecha(rd, "Fecha") ?? desde;
                    }
                    rd.NextResult();
                    while (rd.Read())
                        tratamientos.Add(Tuple.Create(Num(rd, "Id_Procedimiento"), Txt(rd, "Descripcion"), Dec(rd, "Valor")));
                }
            }

            foreach (var g in tratamientos.GroupBy(t => t.Item1))
            {
                ProcedimientoReporteDto p;
                if (!porId.TryGetValue(g.Key, out p)) continue;
                p.Tratamientos = string.Join(", ", g.Select(t => t.Item2));
                p.Cantidad = g.Count();
                p.Total = g.Sum(t => t.Item3);
            }
            foreach (var p in d.Items.Where(x => x.Tratamientos == null)) p.Tratamientos = "";

            d.Procedimientos = d.Items.Count;
            d.Pacientes = d.Items.Select(x => x.IdExpediente).Distinct().Count();
            d.Tratamientos = tratamientos.Count;
            d.Total = d.Items.Sum(x => x.Total);
            d.TicketPromedio = d.Procedimientos == 0 ? 0 : Math.Round(d.Total / d.Procedimientos, 2);
            var conMinutos = d.Items.Where(x => x.Minutos.HasValue).ToList();
            d.MinutosPromedio = conMinutos.Count == 0 ? (decimal?)null : Math.Round((decimal)conMinutos.Average(x => x.Minutos.Value), 1);
            d.Cobrado = d.Items.Where(x => x.Factura == "Cobrada").Sum(x => x.Total);
            d.Pendiente = d.Items.Where(x => x.Factura == "Pendiente").Sum(x => x.Total);
            d.PorEspecialista = Agrupar(d.Items, x => x.Especialista, x => x.Total);
            d.PorTratamiento = tratamientos.GroupBy(t => Es.TextInfo.ToTitleCase(t.Item2.ToLower(Es)))
                .Select(g => new TotalGrupoDto { Nombre = g.Key, Documentos = g.Count(), Total = g.Sum(t => t.Item3) })
                .OrderByDescending(g => g.Documentos).ThenByDescending(g => g.Total).ToList();
            d.PorDia = d.Items.GroupBy(x => fechas[x.Id].Date).OrderBy(g => g.Key)
                .Select(g => new TotalGrupoDto { Nombre = g.Key.ToString("dd/MM/yyyy", Inv), Documentos = g.Count(), Total = g.Sum(x => x.Total) }).ToList();
            return d;
        }

        private static bool YearReal(DateTime d) { return d.Year > 2000; }

        // ===== Expedientes =====
        private static readonly int[] LimitesEdad = { 18, 30, 45, 60 };
        private static readonly string[] RangosEdad = { "0 a 17 años", "18 a 29 años", "30 a 44 años", "45 a 59 años", "60 años o más" };

        private static int EdadEn(DateTime nac)
        {
            var hoy = DateTime.Today;
            int e = hoy.Year - nac.Year;
            if (nac.Date > hoy.AddYears(-e)) e--;
            return Math.Max(e, 0);
        }

        /// <summary>Pacientes con procedimientos o citas en el rango, de más a menos procedimientos (luego citas y valor).</summary>
        public static ReportePacientesActividadDto PacientesActividad(FiltroReporteDto f, DateTime desde, DateTime hasta)
        {
            var d = new ReportePacientesActividadDto
            {
                Ok = true, Desde = desde.ToString("yyyy-MM-dd", Inv), Hasta = hasta.ToString("yyyy-MM-dd", Inv),
                Items = new List<PacienteActividadDto>()
            };
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, 5, f, desde, hasta))
            {
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                    {
                        var nac = Fecha(rd, "FechaNacimiento");
                        d.Items.Add(new PacienteActividadDto
                        {
                            Posicion = d.Items.Count + 1,
                            Id = Num(rd, "Id_Expediente"),
                            Paciente = Txt(rd, "Paciente"),
                            Documento = Txt(rd, "Documento"),
                            Celular = Txt(rd, "Celular"),
                            Edad = nac.HasValue && nac.Value.Year > 1900 ? EdadEn(nac.Value).ToString(Inv) : "",
                            Procedimientos = (int)Num(rd, "Procedimientos"),
                            Visitas = (int)Num(rd, "Visitas"),
                            Valor = Dec(rd, "Valor"),
                            UltimoProcedimiento = Dia(Fecha(rd, "UltimoProcedimiento")),
                            Citas = (int)Num(rd, "Citas"),
                            Atendidas = (int)Num(rd, "Atendidas"),
                            Canceladas = (int)Num(rd, "Canceladas"),
                            UltimaCita = Dia(Fecha(rd, "UltimaCita"))
                        });
                    }
            }
            d.Pacientes = d.Items.Count;
            d.Procedimientos = d.Items.Sum(x => x.Procedimientos);
            d.Citas = d.Items.Sum(x => x.Citas);
            d.Canceladas = d.Items.Sum(x => x.Canceladas);
            d.Valor = d.Items.Sum(x => x.Valor);
            d.Recurrentes = d.Items.Count(x => x.Procedimientos >= 2);
            d.SoloCitas = d.Items.Count(x => x.Procedimientos == 0);
            d.PorProcedimientos = d.Items
                .GroupBy(x => x.Procedimientos >= 4 ? 4 : x.Procedimientos)
                .OrderByDescending(g => g.Key)
                .Select(g => new TotalGrupoDto
                {
                    Nombre = g.Key == 0 ? "Sin procedimientos (solo citas)" : g.Key == 4 ? "4 o más procedimientos" : g.Key + (g.Key == 1 ? " procedimiento" : " procedimientos"),
                    Documentos = g.Count(), Total = g.Sum(x => x.Valor)
                }).ToList();
            return d;
        }

        public static ReporteExpedientesDto Expedientes(FiltroReporteDto f, DateTime desde, DateTime hasta)
        {
            var d = new ReporteExpedientesDto { Ok = true, Desde = desde.ToString("yyyy-MM-dd", Inv), Hasta = hasta.ToString("yyyy-MM-dd", Inv), Items = new List<ExpedienteReporteDto>() };
            var edades = new List<int>();
            var rango = new Dictionary<long, string>();
            var fuentes = new List<Tuple<long, string>>();
            var departamentos = new Dictionary<long, string>();

            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, 3, f, desde, hasta))
            {
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                    {
                        long id = Num(rd, "Id_Expediente");
                        var nac = Fecha(rd, "FechaNacimiento");
                        int? edad = nac.HasValue && nac.Value.Year > 1900 ? EdadEn(nac.Value) : (int?)null;
                        if (edad.HasValue)
                        {
                            edades.Add(edad.Value);
                            int i = 0; while (i < LimitesEdad.Length && edad.Value >= LimitesEdad[i]) i++;
                            rango[id] = RangosEdad[i];
                        }
                        var fs = new List<string>();
                        if (Bit(rd, "Facebook")) fs.Add("Facebook");
                        if (Bit(rd, "Instagram")) fs.Add("Instagram");
                        if (Bit(rd, "TikTok")) fs.Add("TikTok");
                        if (Bit(rd, "WhatsApp")) fs.Add("WhatsApp");
                        if (Bit(rd, "Otros")) fs.Add("Otros");
                        if (Bit(rd, "Buscador")) fs.Add("Buscador web");
                        if (Bit(rd, "Recomendado")) fs.Add("Recomendado");
                        if (fs.Count == 0) fuentes.Add(Tuple.Create(id, "Sin dato"));
                        foreach (var x in fs) fuentes.Add(Tuple.Create(id, x));
                        string depto = Txt(rd, "Departamento");
                        departamentos[id] = depto;

                        d.Items.Add(new ExpedienteReporteDto
                        {
                            Id = id,
                            Registro = Formato.FechaHora(Fecha(rd, "FechaCrea")),
                            Documento = (Txt(rd, "TipoDocumento") + " " + Txt(rd, "Documento")).Trim(),
                            Paciente = Txt(rd, "Paciente"),
                            Edad = edad.HasValue ? edad.Value.ToString(Inv) : "",
                            Sexo = Txt(rd, "Sexo"),
                            Celular = Txt(rd, "Celular"),
                            Email = Txt(rd, "Email"),
                            Ubicacion = string.Join(", ", new[] { Txt(rd, "Municipio"), depto }.Where(s => s != "")),
                            Fuentes = string.Join(", ", fs),
                            Visitas = (int)Num(rd, "Visitas"),
                            UltimaVisita = Dia(Fecha(rd, "UltimaVisita")),
                            RegistradoPor = Txt(rd, "UsuarioCrea")
                        });
                    }
            }

            d.Total = d.Items.Count;
            d.ConVisitas = d.Items.Count(x => x.Visitas > 0);
            d.Recurrentes = d.Items.Count(x => x.Visitas >= 2);
            d.EdadPromedio = edades.Count == 0 ? (decimal?)null : Math.Round((decimal)edades.Average(), 1);
            d.SinEmail = d.Items.Count(x => x.Email == "");
            d.PorSexo = Agrupar(d.Items, x => Es.TextInfo.ToTitleCase(x.Sexo.ToLower(Es)), x => 0);
            d.PorEdad = RangosEdad.Select(r => new TotalGrupoDto { Nombre = r, Documentos = rango.Count(x => x.Value == r) })
                .Concat(d.Items.Any(x => !rango.ContainsKey(x.Id)) ? new[] { new TotalGrupoDto { Nombre = "Sin fecha válida", Documentos = d.Items.Count(x => !rango.ContainsKey(x.Id)) } } : new TotalGrupoDto[0])
                .Where(g => g.Documentos > 0).ToList();
            d.PorFuente = fuentes.GroupBy(x => x.Item2).Select(g => new TotalGrupoDto { Nombre = g.Key, Documentos = g.Count() })
                .OrderByDescending(g => g.Documentos).ToList();
            d.PorDepartamento = Agrupar(d.Items, x => departamentos[x.Id], x => 0);
            d.PorUsuario = Agrupar(d.Items, x => x.RegistradoPor, x => 0);
            return d;
        }
    }
}
