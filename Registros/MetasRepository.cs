using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;
using System.Linq;
using System.Text;

namespace DPieCenter.Registros
{
    // ===== Metas de ventas y esquema de bono (Registros/frm_Metas.aspx, dashboards) =====

    public class EscalaMetaDto
    {
        public decimal Desde { get; set; }
        /// <summary>null: en adelante.</summary>
        public decimal? Hasta { get; set; }
        /// <summary>% sobre la diferencia (ventas sin IVA del mes − mínimo para comisionar).</summary>
        public decimal Porcentaje { get; set; }
        /// <summary>Monto fijo adicional del rango.</summary>
        public decimal Bono { get; set; }
    }

    public class MetaDto
    {
        public long Id { get; set; }
        public int Anio { get; set; }
        public int Mes { get; set; }
        /// <summary>"Noviembre 2026"</summary>
        public string Periodo { get; set; }
        public decimal MetaVentas { get; set; }
        public decimal SalarioBase { get; set; }
        public decimal MinimoComision { get; set; }
        public decimal BonoAlcance { get; set; }
        public string Observaciones { get; set; }
        public bool Vigente { get; set; }
        public long IdEspecialista { get; set; }
        public string Especialista { get; set; }
        /// <summary>Generada automáticamente copiando la del mes anterior (sin cambios).</summary>
        public bool Automatica { get; set; }
        /// <summary>Versiones registradas del mes para el especialista (incluye la vigente).</summary>
        public int Versiones { get; set; }
        public string UsuarioCrea { get; set; }
        public string FechaCrea { get; set; }
        public string Modificado { get; set; }
        public int NumEscalas { get; set; }
        public List<EscalaMetaDto> Escalas { get; set; }
    }

    /// <summary>Avance de un especialista contra la meta del mes, con el bono estimado según el esquema.</summary>
    public class AvanceMetaDto
    {
        public long IdEspecialista { get; set; }
        public string Especialista { get; set; }
        /// <summary>Meta del especialista aplicada al mes (con escalas). null si no tiene.</summary>
        public MetaDto Meta { get; set; }
        /// <summary>Ventas sin IVA del mes (DTE vigentes de sus procedimientos).</summary>
        public decimal Ventas { get; set; }
        /// <summary>Ventas con IVA del mes (lo cobrado).</summary>
        public decimal VentasConIva { get; set; }
        /// <summary>"749.00 × 12 % = 89.88 + 500.00 × 15 % = 75.00 = 164.88"</summary>
        public string DetalleComision { get; set; }
        public int Procedimientos { get; set; }
        /// <summary>Ventas / meta × 100.</summary>
        public decimal Avance { get; set; }
        public bool CumpleMeta { get; set; }
        public decimal FaltaMeta { get; set; }
        /// <summary>% de la escala alcanzada (0 si no llega al mínimo).</summary>
        public decimal PorcentajeEscala { get; set; }
        public decimal Comision { get; set; }
        public decimal BonoEscala { get; set; }
        public decimal BonoAlcance { get; set; }
        /// <summary>Comisión + bono de escala + bono por alcance.</summary>
        public decimal TotalBono { get; set; }
        /// <summary>Bono estimado (comisión + bono de escala) + bono por meta. No incluye el salario base.</summary>
        public decimal TotalEstimado { get; set; }
        /// <summary>Ventas al ritmo actual hasta fin de mes (solo el mes en curso).</summary>
        public decimal? Proyeccion { get; set; }
        /// <summary>Monto donde empieza la siguiente escala (null si ya está en la última).</summary>
        public decimal? SiguienteEscala { get; set; }
    }

    public class MetasMesDto
    {
        /// <summary>Meta de referencia del mes (la del primer especialista con meta). null si ninguno tiene meta.
        /// Cada especialista trae la suya en AvanceMetaDto.Meta.</summary>
        public MetaDto Meta { get; set; }
        /// <summary>Todos los especialistas tienen la misma meta de ventas y mínimo.</summary>
        public bool MetaComun { get; set; }
        public string Periodo { get; set; }
        public bool MesEnCurso { get; set; }
        public int DiasTranscurridos { get; set; }
        public int DiasMes { get; set; }
        public List<AvanceMetaDto> Especialistas { get; set; }
    }

    // ===== Meta sugerida según el mes del año =====

    public class FactorMesDto
    {
        public int Mes { get; set; }
        public string Nombre { get; set; }
        /// <summary>Ventas del mes comparadas con un mes normal (1.00).</summary>
        public decimal Factor { get; set; }
    }

    public class ParametrosSugeridaDto
    {
        public List<FactorMesDto> Factores { get; set; }
        /// <summary>% de crecimiento sobre el promedio.</summary>
        public decimal Crecimiento { get; set; }
        /// <summary>La sugerida se redondea a este múltiplo ($).</summary>
        public int Redondeo { get; set; }
        public int MesesBase { get; set; }
        public string Modificado { get; set; }
    }

    public class MesVentaDto
    {
        public string Periodo { get; set; }
        public decimal Ventas { get; set; }
        /// <summary>Se usa en el promedio.</summary>
        public bool Incluido { get; set; }
        /// <summary>"proyección al cierre", "mes incompleto", "sin datos"...</summary>
        public string Nota { get; set; }
    }

    /// <summary>Meta sugerida = promedio de los últimos meses × factor del mes × (1 + crecimiento), redondeada.</summary>
    public class MetaSugeridaDto
    {
        public long IdEspecialista { get; set; }
        public int Anio { get; set; }
        public int Mes { get; set; }
        public string Periodo { get; set; }
        public decimal Promedio { get; set; }
        public decimal Factor { get; set; }
        public decimal Crecimiento { get; set; }
        public int Redondeo { get; set; }
        /// <summary>0 si no hay ventas para calcularla (SinDatos).</summary>
        public decimal Sugerida { get; set; }
        public bool SinDatos { get; set; }
        public List<MesVentaDto> Meses { get; set; }
        /// <summary>"(1,298.02 + 2,225.65 + 2,022.48) ÷ 3 = 1,848.72 × 1.15 × 1.05 = 2,232.33 → 2,250"</summary>
        public string Detalle { get; set; }
    }

    public class SugerenciasMesDto
    {
        public ParametrosSugeridaDto Parametros { get; set; }
        public List<MetaSugeridaDto> Especialistas { get; set; }
        public MetaSugeridaDto De(long especialista) { return Especialistas.FirstOrDefault(s => s.IdEspecialista == especialista); }
    }

    // ===== Histórico de metas por mes (Dashboard de gerencia) =====
    public class MetaHistoricoEspecialistaDto
    {
        public long IdEspecialista { get; set; }
        public string Especialista { get; set; }
        /// <summary>Ventas sin IVA de cada mes (mismo orden que MetasHistoricoDto.Meses).</summary>
        public List<decimal> Ventas { get; set; }
        /// <summary>Meta vigente de cada mes (null = sin meta registrada).</summary>
        public List<decimal?> Metas { get; set; }
    }

    public class MetasHistoricoDto
    {
        /// <summary>"Ago 2026"...</summary>
        public List<string> Meses { get; set; }
        /// <summary>Notas por mes: "en curso", "datos desde el 26"...</summary>
        public List<string> Notas { get; set; }
        public List<MetaHistoricoEspecialistaDto> Especialistas { get; set; }
    }

    /// <summary>Acceso a dbo.MET_SP_Metas (Registros/sql/MET_Metas.sql) y cálculo del bono.</summary>
    public static class MetasRepository
    {
        private static readonly CultureInfo Inv = CultureInfo.InvariantCulture;
        private static readonly CultureInfo Es = new CultureInfo("es-SV");

        private static string Cn { get { return ConfigurationManager.ConnectionStrings["conexionDiarypro"].ConnectionString; } }

        private static string Txt(IDataRecord r, string c) { var v = r[c]; return v == DBNull.Value ? "" : Convert.ToString(v).Trim(); }
        private static decimal Dec(IDataRecord r, string c) { var v = r[c]; return v == DBNull.Value ? 0 : Convert.ToDecimal(v); }
        private static decimal? DecN(IDataRecord r, string c) { var v = r[c]; return v == DBNull.Value ? (decimal?)null : Convert.ToDecimal(v); }
        private static int Ent(IDataRecord r, string c) { var v = r[c]; return v == DBNull.Value ? 0 : Convert.ToInt32(v); }
        private static bool HayColumna(IDataRecord r, string c) { for (int i = 0; i < r.FieldCount; i++) if (r.GetName(i) == c) return true; return false; }

        public static string NombrePeriodo(int anio, int mes)
        {
            if (mes < 1 || mes > 12) return "";
            return Es.TextInfo.ToTitleCase(Es.DateTimeFormat.GetMonthName(mes)) + " " + anio;
        }

        private static SqlCommand Sp(SqlConnection cn, int accion)
        {
            var cmd = new SqlCommand("dbo.MET_SP_Metas", cn) { CommandType = CommandType.StoredProcedure };
            cmd.Parameters.Add("@accion", SqlDbType.Int).Value = accion;
            return cmd;
        }

        private static MetaDto LeerMeta(IDataRecord r)
        {
            var m = new MetaDto
            {
                Id = Convert.ToInt64(r["Id_Meta"]),
                Anio = Ent(r, "Anio"),
                Mes = Ent(r, "Mes"),
                MetaVentas = Dec(r, "MetaVentas"),
                SalarioBase = Dec(r, "SalarioBase"),
                MinimoComision = Dec(r, "MinimoComision"),
                BonoAlcance = Dec(r, "BonoAlcance"),
                Vigente = r["Vigente"] != DBNull.Value && Convert.ToBoolean(r["Vigente"]),
                Escalas = new List<EscalaMetaDto>()
            };
            m.Periodo = NombrePeriodo(m.Anio, m.Mes);
            if (HayColumna(r, "Observaciones")) m.Observaciones = Txt(r, "Observaciones");
            if (HayColumna(r, "UsuarioCrea"))
            {
                m.UsuarioCrea = Txt(r, "UsuarioCrea");
                m.FechaCrea = r["FechaCrea"] == DBNull.Value ? "" : Convert.ToDateTime(r["FechaCrea"]).ToString("dd/MM/yyyy hh:mm tt", Inv);
                m.Modificado = r["FechaModifica"] == DBNull.Value ? "" : Txt(r, "UsuarioModifica") + " · " + Convert.ToDateTime(r["FechaModifica"]).ToString("dd/MM/yyyy hh:mm tt", Inv);
            }
            if (HayColumna(r, "Escalas")) m.NumEscalas = Ent(r, "Escalas");
            if (HayColumna(r, "Id_Especialista") && r["Id_Especialista"] != DBNull.Value) m.IdEspecialista = Convert.ToInt64(r["Id_Especialista"]);
            if (HayColumna(r, "Especialista")) m.Especialista = Txt(r, "Especialista");
            if (HayColumna(r, "Origen")) m.Automatica = Txt(r, "Origen") == "A";
            if (HayColumna(r, "Versiones")) m.Versiones = Ent(r, "Versiones");
            return m;
        }

        private static EscalaMetaDto LeerEscala(IDataRecord r)
        {
            return new EscalaMetaDto { Desde = Dec(r, "Desde"), Hasta = DecN(r, "Hasta"), Porcentaje = Dec(r, "Porcentaje"), Bono = Dec(r, "Bono") };
        }

        /// <summary>Metas del mes: la vigente de cada especialista (Id = 0 si no tiene). Genera el mes si no hubo cambios.</summary>
        public static List<MetaDto> Lista(int anio, int mes)
        {
            var lista = new List<MetaDto>();
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, 1))
            {
                cmd.Parameters.Add("@anio", SqlDbType.Int).Value = anio;
                cmd.Parameters.Add("@mes", SqlDbType.Int).Value = mes;
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                    {
                        MetaDto m;
                        if (rd["Id_Meta"] == DBNull.Value)
                            m = new MetaDto { Anio = anio, Mes = mes, Periodo = NombrePeriodo(anio, mes), Escalas = new List<EscalaMetaDto>() };
                        else m = LeerMeta(rd);
                        m.IdEspecialista = Convert.ToInt64(rd["Id_Especialista"]);
                        m.Especialista = Txt(rd, "Especialista");
                        lista.Add(m);
                    }
            }
            return lista;
        }

        /// <summary>Todas las versiones de las metas de un especialista (la más reciente primero).</summary>
        public static List<MetaDto> Historial(long especialista)
        {
            var lista = new List<MetaDto>();
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, 4))
            {
                cmd.Parameters.Add("@especialista", SqlDbType.BigInt).Value = especialista;
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read()) lista.Add(LeerMeta(rd));
            }
            return lista;
        }

        /// <summary>Una versión. null si no existe.</summary>
        public static MetaDto Obtener(long id)
        {
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, 2))
            {
                cmd.Parameters.Add("@id", SqlDbType.BigInt).Value = id;
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                {
                    if (!rd.Read()) return null;
                    var m = LeerMeta(rd);
                    if (rd.NextResult()) while (rd.Read()) m.Escalas.Add(LeerEscala(rd));
                    m.NumEscalas = m.Escalas.Count;
                    return m;
                }
            }
        }

        /// <summary>
        /// Crea una versión nueva de la meta del mes para cada especialista indicado; la vigente queda en el historial
        /// y los meses siguientes generados automáticamente toman el cambio. Devuelve cuántas se guardaron.
        /// </summary>
        public static int Guardar(MetaDto m, IEnumerable<long> especialistas, string usuario)
        {
            var xml = new StringBuilder();
            foreach (var e in m.Escalas ?? new List<EscalaMetaDto>())
                xml.AppendFormat(Inv, "<e d=\"{0}\" h=\"{1}\" p=\"{2}\" b=\"{3}\"/>", e.Desde, e.Hasta.HasValue ? e.Hasta.Value.ToString(Inv) : "", e.Porcentaje, e.Bono);
            var esp = new StringBuilder();
            foreach (var id in (especialistas ?? new long[0]).Distinct()) esp.AppendFormat(Inv, "<s i=\"{0}\"/>", id);

            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, 3))
            {
                cmd.Parameters.Add("@especialistas", SqlDbType.Xml).Value = esp.ToString();
                cmd.Parameters.Add("@anio", SqlDbType.Int).Value = m.Anio;
                cmd.Parameters.Add("@mes", SqlDbType.Int).Value = m.Mes;
                cmd.Parameters.Add("@meta", SqlDbType.Decimal).Value = m.MetaVentas;
                cmd.Parameters.Add("@salario", SqlDbType.Decimal).Value = m.SalarioBase;
                cmd.Parameters.Add("@minimo", SqlDbType.Decimal).Value = m.MinimoComision;
                cmd.Parameters.Add("@bonoAlcance", SqlDbType.Decimal).Value = m.BonoAlcance;
                foreach (SqlParameter p in cmd.Parameters) if (p.SqlDbType == SqlDbType.Decimal) { p.Precision = 12; p.Scale = 2; }
                cmd.Parameters.Add("@observaciones", SqlDbType.VarChar, 500).Value = (object)m.Observaciones ?? DBNull.Value;
                cmd.Parameters.Add("@escalas", SqlDbType.Xml).Value = xml.ToString();
                cmd.Parameters.Add("@user", SqlDbType.VarChar, 20).Value = usuario;
                cn.Open();
                return Convert.ToInt32(cmd.ExecuteScalar());
            }
        }

        /// <summary>Avance del mes por especialista (especialista = 0: todos los activos o con ventas).</summary>
        public static MetasMesDto AvanceMes(int anio, int mes, long especialista)
        {
            DateTime hoy = DateTime.Today;
            var r = new MetasMesDto
            {
                Periodo = NombrePeriodo(anio, mes),
                MesEnCurso = anio == hoy.Year && mes == hoy.Month,
                DiasMes = DateTime.DaysInMonth(anio, mes),
                Especialistas = new List<AvanceMetaDto>()
            };
            var inicio = new DateTime(anio, mes, 1);
            r.DiasTranscurridos = r.MesEnCurso ? hoy.Day : inicio > hoy ? 0 : r.DiasMes;

            var ventas = new List<AvanceMetaDto>();
            var metas = new Dictionary<long, MetaDto>();      // por especialista
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, 5))
            {
                cmd.Parameters.Add("@anio", SqlDbType.Int).Value = anio;
                cmd.Parameters.Add("@mes", SqlDbType.Int).Value = mes;
                cmd.Parameters.Add("@especialista", SqlDbType.BigInt).Value = especialista;
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                {
                    var porId = new Dictionary<long, MetaDto>();
                    while (rd.Read()) { var m = LeerMeta(rd); metas[m.IdEspecialista] = m; porId[m.Id] = m; }
                    rd.NextResult();
                    while (rd.Read())
                    {
                        MetaDto m;
                        if (porId.TryGetValue(Convert.ToInt64(rd["Id_Meta"]), out m)) m.Escalas.Add(LeerEscala(rd));
                    }
                    rd.NextResult();
                    while (rd.Read())
                        ventas.Add(new AvanceMetaDto
                        {
                            IdEspecialista = Convert.ToInt64(rd["Id_Especialista"]),
                            Especialista = Txt(rd, "Especialista"),
                            Ventas = Dec(rd, "Ventas"),
                            VentasConIva = HayColumna(rd, "VentasConIva") ? Dec(rd, "VentasConIva") : 0,
                            Procedimientos = Ent(rd, "Procedimientos")
                        });
                }
            }
            foreach (var m in metas.Values) m.NumEscalas = m.Escalas.Count;

            foreach (var a in ventas)
            {
                MetaDto m;
                if (metas.TryGetValue(a.IdEspecialista, out m)) { a.Meta = m; Calcular(a, m); }
                if (r.MesEnCurso && r.DiasTranscurridos > 0)
                    a.Proyeccion = Math.Round(a.Ventas / r.DiasTranscurridos * r.DiasMes, 2);
                r.Especialistas.Add(a);
            }
            var conMeta = r.Especialistas.Where(a => a.Meta != null).Select(a => a.Meta).ToList();
            r.Meta = conMeta.FirstOrDefault();
            r.MetaComun = conMeta.Count > 0 && conMeta.All(x => x.MetaVentas == r.Meta.MetaVentas && x.MinimoComision == r.Meta.MinimoComision);
            return r;
        }

        private static string Dinero(decimal n) { return n.ToString("#,##0.00", Inv); }

        /// <summary>
        /// Meta sugerida de anio/mes para cada especialista activo (especialista 0) o uno solo.
        /// Promedio de ventas sin IVA de los MesesBase meses anteriores: el mes en curso se cuenta con su proyección al
        /// cierre; el mes en que empiezan los datos (si no empieza el día 1) y los anteriores no se cuentan.
        /// </summary>
        public static SugerenciasMesDto Sugerencias(int anio, int mes, long especialista)
        {
            var r = new SugerenciasMesDto { Especialistas = new List<MetaSugeridaDto>() };
            var p = new ParametrosSugeridaDto { Factores = new List<FactorMesDto>(), Crecimiento = 5, Redondeo = 50, MesesBase = 3 };
            DateTime? inicio = null;
            var ventas = new Dictionary<long, Dictionary<DateTime, decimal>>();
            var ids = new List<long>();
            using (var cn = new SqlConnection(Cn))
            {
                cn.Open();
                using (var cmd = Sp(cn, 6))
                {
                    cmd.Parameters.Add("@anio", SqlDbType.Int).Value = anio;
                    cmd.Parameters.Add("@mes", SqlDbType.Int).Value = mes;
                    cmd.Parameters.Add("@especialista", SqlDbType.BigInt).Value = especialista;
                    using (var rd = cmd.ExecuteReader())
                    {
                        while (rd.Read())
                        {
                            int m = Ent(rd, "Mes");
                            p.Factores.Add(new FactorMesDto { Mes = m, Nombre = Es.TextInfo.ToTitleCase(Es.DateTimeFormat.GetMonthName(m)), Factor = Dec(rd, "Factor") });
                        }
                        rd.NextResult();
                        if (rd.Read())
                        {
                            p.Crecimiento = Dec(rd, "Crecimiento"); p.Redondeo = Ent(rd, "Redondeo"); p.MesesBase = Ent(rd, "MesesBase");
                            p.Modificado = rd["FechaModifica"] == DBNull.Value ? "" : Txt(rd, "UsuarioModifica") + " · " + Convert.ToDateTime(rd["FechaModifica"]).ToString("dd/MM/yyyy hh:mm tt", Inv);
                        }
                        rd.NextResult();
                        if (rd.Read() && rd["InicioDatos"] != DBNull.Value) inicio = Convert.ToDateTime(rd["InicioDatos"]).Date;
                        rd.NextResult();
                        while (rd.Read())
                        {
                            long id = Convert.ToInt64(rd["Id_Especialista"]);
                            Dictionary<DateTime, decimal> d;
                            if (!ventas.TryGetValue(id, out d)) ventas[id] = d = new Dictionary<DateTime, decimal>();
                            d[new DateTime(Ent(rd, "Anio"), Ent(rd, "Mes"), 1)] = Dec(rd, "Ventas");
                        }
                    }
                }
                // especialistas activos (con o sin ventas)
                using (var cmd = new SqlCommand("select Id_Especialista from dbo.CAT_ESPECIALISTAS where (@e = 0 and IsActivo = 1) or Id_Especialista = @e", cn))
                {
                    cmd.Parameters.Add("@e", SqlDbType.BigInt).Value = especialista;
                    using (var rd = cmd.ExecuteReader()) while (rd.Read()) ids.Add(Convert.ToInt64(rd[0]));
                }
            }
            r.Parametros = p;

            DateTime hoy = DateTime.Today, mesHoy = new DateTime(hoy.Year, hoy.Month, 1), objetivo = new DateTime(anio, mes, 1);
            DateTime? mesInicio = inicio.HasValue ? new DateTime(inicio.Value.Year, inicio.Value.Month, 1) : (DateTime?)null;
            var fm = p.Factores.FirstOrDefault(f => f.Mes == mes);
            decimal factor = fm != null ? fm.Factor : 1m;

            foreach (long id in ids)
            {
                Dictionary<DateTime, decimal> d;
                ventas.TryGetValue(id, out d);
                var s = new MetaSugeridaDto
                {
                    IdEspecialista = id, Anio = anio, Mes = mes, Periodo = NombrePeriodo(anio, mes),
                    Factor = factor, Crecimiento = p.Crecimiento, Redondeo = p.Redondeo, Meses = new List<MesVentaDto>()
                };
                var usados = new List<decimal>();
                for (int k = p.MesesBase; k >= 1; k--)
                {
                    DateTime m = objetivo.AddMonths(-k);
                    decimal v = d != null && d.ContainsKey(m) ? d[m] : 0m;
                    var mv = new MesVentaDto { Periodo = NombrePeriodo(m.Year, m.Month), Ventas = v };
                    if (m > mesHoy) mv.Nota = "aún no llega";
                    else if (!mesInicio.HasValue || m < mesInicio.Value) mv.Nota = "sin datos";
                    else if (m == mesInicio.Value && inicio.Value.Day > 1) mv.Nota = "mes incompleto (datos desde el " + inicio.Value.Day + ")";
                    else
                    {
                        if (m == mesHoy)
                        {
                            int dias = DateTime.DaysInMonth(m.Year, m.Month);
                            mv.Ventas = Math.Round(v / hoy.Day * dias, 2);
                            mv.Nota = "proyección al cierre; " + Dinero(v) + " al día " + hoy.Day;
                        }
                        mv.Incluido = true;
                        usados.Add(mv.Ventas);
                    }
                    s.Meses.Add(mv);
                }
                if (usados.Count == 0 || usados.Sum() <= 0)
                {
                    s.SinDatos = true;
                    s.Detalle = "Sin ventas en los meses anteriores para calcularla.";
                }
                else
                {
                    s.Promedio = Math.Round(usados.Average(), 2);
                    decimal bruta = Math.Round(s.Promedio * factor * (1 + p.Crecimiento / 100m), 2);
                    int red = p.Redondeo > 0 ? p.Redondeo : 1;
                    s.Sugerida = Math.Round(bruta / red, 0, MidpointRounding.AwayFromZero) * red;
                    s.Detalle = (usados.Count > 1 ? "(" + string.Join(" + ", usados.Select(Dinero)) + ") ÷ " + usados.Count + " = " : "") + Dinero(s.Promedio)
                        + " × " + factor.ToString("0.00", Inv) + " (" + (fm != null ? fm.Nombre.ToLowerInvariant() : "mes") + ") × " + (1 + p.Crecimiento / 100m).ToString("0.00##", Inv)
                        + " (" + p.Crecimiento.ToString("0.##", Inv) + " % crecimiento) = " + Dinero(bruta) + " → " + Dinero(s.Sugerida);
                }
                r.Especialistas.Add(s);
            }
            return r;
        }

        /// <summary>Ventas sin IVA y meta vigente por especialista de los "meses" meses que terminan en anio/mes (incluido).</summary>
        public static MetasHistoricoDto Historico(int anio, int mes, int meses)
        {
            meses = Math.Max(2, Math.Min(12, meses));
            var fin = new DateTime(anio, mes, 1);
            var hoy = DateTime.Today;
            if (fin > new DateTime(hoy.Year, hoy.Month, 1)) fin = new DateTime(hoy.Year, hoy.Month, 1);
            var lista = Enumerable.Range(0, meses).Select(i => fin.AddMonths(i - meses + 1)).ToList();
            var r = new MetasHistoricoDto { Meses = new List<string>(), Notas = new List<string>(), Especialistas = new List<MetaHistoricoEspecialistaDto>() };
            var ventas = new Dictionary<long, Dictionary<DateTime, decimal>>();
            var metas = new Dictionary<long, Dictionary<DateTime, decimal>>();
            var nombres = new Dictionary<long, string>();
            DateTime? inicio = null;
            var sig = fin.AddMonths(1);
            using (var cn = new SqlConnection(Cn))
            {
                cn.Open();
                using (var cmd = Sp(cn, 6))
                {
                    cmd.Parameters.Add("@anio", SqlDbType.Int).Value = sig.Year;
                    cmd.Parameters.Add("@mes", SqlDbType.Int).Value = sig.Month;
                    cmd.Parameters.Add("@meses", SqlDbType.Int).Value = meses;
                    using (var rd = cmd.ExecuteReader())
                    {
                        rd.NextResult(); rd.NextResult();                         // factores y parámetros
                        if (rd.Read() && rd["InicioDatos"] != DBNull.Value) inicio = Convert.ToDateTime(rd["InicioDatos"]).Date;
                        rd.NextResult();
                        while (rd.Read())
                        {
                            long id = Convert.ToInt64(rd["Id_Especialista"]);
                            if (!ventas.ContainsKey(id)) ventas[id] = new Dictionary<DateTime, decimal>();
                            ventas[id][new DateTime(Ent(rd, "Anio"), Ent(rd, "Mes"), 1)] = Dec(rd, "Ventas");
                        }
                        rd.NextResult();
                        while (rd.Read())
                        {
                            long id = Convert.ToInt64(rd["Id_Especialista"]);
                            nombres[id] = Txt(rd, "Especialista");
                            if (!metas.ContainsKey(id)) metas[id] = new Dictionary<DateTime, decimal>();
                            metas[id][new DateTime(Ent(rd, "Anio"), Ent(rd, "Mes"), 1)] = Dec(rd, "MetaVentas");
                        }
                    }
                }
                using (var cmd = new SqlCommand("select Id_Especialista, Descripcion from dbo.CAT_ESPECIALISTAS where IsActivo = 1", cn))
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read()) nombres[Convert.ToInt64(rd[0])] = Convert.ToString(rd[1]).Trim();
            }

            foreach (var m in lista)
            {
                r.Meses.Add(Es.TextInfo.ToTitleCase(Es.DateTimeFormat.GetAbbreviatedMonthName(m.Month).TrimEnd('.')) + " " + m.Year);
                string nota = "";
                if (m.Year == hoy.Year && m.Month == hoy.Month) nota = "en curso (al día " + hoy.Day + ")";
                else if (inicio.HasValue && m.Year == inicio.Value.Year && m.Month == inicio.Value.Month && inicio.Value.Day > 1) nota = "datos desde el " + inicio.Value.Day;
                else if (inicio.HasValue && m < new DateTime(inicio.Value.Year, inicio.Value.Month, 1)) nota = "sin datos";
                r.Notas.Add(nota);
            }
            foreach (var id in ventas.Keys.Union(metas.Keys).Distinct())
            {
                if (!nombres.ContainsKey(id)) continue;      // especialista inactivo
                Dictionary<DateTime, decimal> v, mt;
                ventas.TryGetValue(id, out v); metas.TryGetValue(id, out mt);
                r.Especialistas.Add(new MetaHistoricoEspecialistaDto
                {
                    IdEspecialista = id, Especialista = nombres[id],
                    Ventas = lista.Select(m => v != null && v.ContainsKey(m) ? v[m] : 0m).ToList(),
                    Metas = lista.Select(m => mt != null && mt.ContainsKey(m) ? mt[m] : (decimal?)null).ToList()
                });
            }
            r.Especialistas = r.Especialistas.OrderByDescending(e => e.Ventas.Sum()).ToList();
            return r;
        }

        /// <summary>Guarda los 12 factores (enero a diciembre), el % de crecimiento y el redondeo.</summary>
        public static void GuardarParametros(List<decimal> factores, decimal crecimiento, int redondeo, string usuario)
        {
            if (factores == null || factores.Count != 12) throw new ArgumentException("Indique el factor de los 12 meses.");
            var xml = new StringBuilder();
            for (int i = 0; i < 12; i++) xml.AppendFormat(Inv, "<f m=\"{0}\" v=\"{1}\"/>", i + 1, factores[i]);
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, 7))
            {
                cmd.Parameters.Add("@factores", SqlDbType.Xml).Value = xml.ToString();
                var c = cmd.Parameters.Add("@crecimiento", SqlDbType.Decimal); c.Precision = 5; c.Scale = 2; c.Value = crecimiento;
                cmd.Parameters.Add("@redondeo", SqlDbType.Int).Value = redondeo;
                cmd.Parameters.Add("@user", SqlDbType.VarChar, 20).Value = usuario;
                cn.Open();
                cmd.ExecuteNonQuery();
            }
        }

        /// <summary>
        /// Esquema de "Tabla de Bonos Dpie": por encima del mínimo para comisionar se aplica el % de la escala alcanzada
        /// de forma escalonada: cada rango paga su % por la parte de las ventas sin IVA que cae en él y se suman; más el bono fijo
        /// de la escala alcanzada; al cumplir la meta se suma el bono por alcance.
        /// Ej.: ventas 2,600, mínimo 1,251 → (2,000 − 1,251) × 12 % + (2,500 − 2,000) × 15 % + (2,600 − 2,500) × 18 % = 182.88.
        /// Los rangos son contiguos (1251–2000, 2001–2500...): una venta de 2000.50 queda en el rango que empieza en 2001.
        /// </summary>
        public static void Calcular(AvanceMetaDto a, MetaDto m)
        {
            var escalas = (m.Escalas ?? new List<EscalaMetaDto>()).OrderBy(e => e.Desde).ToList();
            decimal v = a.Ventas;
            a.Avance = m.MetaVentas > 0 ? Math.Round(100m * v / m.MetaVentas, 1) : 0;
            a.CumpleMeta = m.MetaVentas > 0 && v >= m.MetaVentas;
            a.FaltaMeta = a.CumpleMeta ? 0 : Math.Max(0, m.MetaVentas - v);

            EscalaMetaDto escala = null;
            if (v > m.MinimoComision)
                escala = escalas.LastOrDefault(e => v > e.Desde - 1) ?? escalas.FirstOrDefault();
            a.PorcentajeEscala = escala != null ? escala.Porcentaje : 0;

            // Comisión escalonada: cada rango paga su % solo por la parte de las ventas que cae en él, y se suman.
            // El primer rango empieza en el mínimo para comisionar; los siguientes, donde termina el anterior.
            decimal comision = 0;
            var partes = new List<string>();
            if (escala != null)
                for (int i = 0; i < escalas.Count; i++)
                {
                    decimal desde = i == 0 ? Math.Max(m.MinimoComision, escalas[0].Desde - 1) : (escalas[i - 1].Hasta ?? escalas[i].Desde - 1);
                    decimal hasta = escalas[i].Hasta ?? decimal.MaxValue;
                    if (v <= desde || hasta <= desde) continue;
                    decimal tramo = Math.Min(v, hasta) - desde;
                    decimal c = Math.Round(tramo * escalas[i].Porcentaje / 100m, 2, MidpointRounding.AwayFromZero);
                    comision += c;
                    partes.Add(Dinero(tramo) + " × " + escalas[i].Porcentaje.ToString("0.##", Inv) + " % = " + Dinero(c));
                }
            a.Comision = comision;
            a.DetalleComision = partes.Count > 0 ? string.Join(" + ", partes) + (partes.Count > 1 ? " = " + Dinero(comision) : "") : "";
            a.BonoEscala = escala != null ? escala.Bono : 0;
            a.BonoAlcance = a.CumpleMeta ? m.BonoAlcance : 0;
            a.TotalBono = a.Comision + a.BonoEscala + a.BonoAlcance;
            a.TotalEstimado = a.TotalBono;       // sin el salario base: bono estimado + bono por meta

            var siguiente = escala == null ? escalas.FirstOrDefault(e => e.Desde > v) : escalas.FirstOrDefault(e => e.Desde > escala.Desde);
            a.SiguienteEscala = siguiente != null ? siguiente.Desde : (decimal?)null;
        }
    }
}
