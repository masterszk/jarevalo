using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;

namespace DPieCenter.Facturacion
{
    // Acceso a datos de facturación electrónica (SPs de Facturacion/sql/FAC_DTE_Estructura.sql)
    public static class DteRepository
    {
        public static string Cn
        {
            get { return ConfigurationManager.ConnectionStrings["conexionDiarypro"].ConnectionString; }
        }

        private static SqlCommand Sp(SqlConnection cn, string nombre, SqlTransaction tx = null)
        {
            return new SqlCommand(nombre, cn, tx) { CommandType = CommandType.StoredProcedure };
        }

        private static object Db(object v) { return v ?? DBNull.Value; }
        private static object DbTexto(string v) { return string.IsNullOrWhiteSpace(v) ? (object)DBNull.Value : v.Trim(); }
        private static string Txt(IDataRecord r, string col) { var v = r[col]; return v == DBNull.Value ? "" : Convert.ToString(v).Trim(); }

        // ===== Consultas =====
        public static ClienteFacturaDto ObtenerFactura(long factura)
        {
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, "dbo.FAC_SP_DTE_CONSULTAS"))
            {
                cmd.Parameters.Add("@factura", SqlDbType.BigInt).Value = factura;
                cmd.Parameters.Add("@accion", SqlDbType.Int).Value = 1;
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                {
                    if (!rd.Read()) return null;
                    return new ClienteFacturaDto
                    {
                        IdFactura = Convert.ToInt64(rd["Id_factura"]),
                        Pagada = Convert.ToBoolean(rd["Estado"]),
                        IdExpediente = Convert.ToInt64(rd["Id_Expediente_FK"]),
                        Cliente = Txt(rd, "Cliente"),
                        Documento = Txt(rd, "Documento"),
                        IdTipoDocumento = rd["Id_TipoDocumento_fk"] == DBNull.Value ? (long?)null : Convert.ToInt64(rd["Id_TipoDocumento_fk"]),
                        Celular = Txt(rd, "Celular") != "" ? Txt(rd, "Celular") : Txt(rd, "Telefono"),
                        Email = Txt(rd, "Email"),
                        Direccion = Txt(rd, "Direccion"),
                        Anticipo = rd["Anticipo"] != DBNull.Value && Convert.ToBoolean(rd["Anticipo"]),
                        MontoLibre = rd["MontoLibre"] != DBNull.Value && Convert.ToBoolean(rd["MontoLibre"]),
                        CitaInicio = rd["CitaInicio"] == DBNull.Value ? "" : Formato.FechaHora(Convert.ToDateTime(rd["CitaInicio"]))
                    };
                }
            }
        }

        public static List<ItemFacturaDto> ObtenerItems(long factura)
        {
            var lista = new List<ItemFacturaDto>();
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, "dbo.FAC_SP_DTE_CONSULTAS"))
            {
                cmd.Parameters.Add("@factura", SqlDbType.BigInt).Value = factura;
                cmd.Parameters.Add("@accion", SqlDbType.Int).Value = 2;
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                        lista.Add(new ItemFacturaDto
                        {
                            Id = Convert.ToInt64(rd["Id_detalle"]),
                            IdTratamiento = rd["Id_tratamiento_FK"] == DBNull.Value ? (long?)null : Convert.ToInt64(rd["Id_tratamiento_FK"]),
                            Descripcion = Txt(rd, "Descripcion"),
                            Valor = Math.Round(Convert.ToDecimal(rd["Valor"]), 2, MidpointRounding.AwayFromZero)
                        });
            }
            return lista;
        }

        public static EmisorDte ObtenerEmisor()
        {
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, "dbo.FAC_SP_DTE_CONSULTAS"))
            {
                cmd.Parameters.Add("@factura", SqlDbType.BigInt).Value = 0;
                cmd.Parameters.Add("@accion", SqlDbType.Int).Value = 3;
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                {
                    if (!rd.Read()) return null;
                    return new EmisorDte
                    {
                        Ambiente = Txt(rd, "Ambiente"),
                        Nit = Txt(rd, "NIT"),
                        Nrc = Txt(rd, "NRC"),
                        Nombre = Txt(rd, "Nombre"),
                        NombreComercial = Txt(rd, "NombreComercial"),
                        CodActividad = Txt(rd, "CodActividad"),
                        DescActividad = Txt(rd, "DescActividad"),
                        TipoEstablecimiento = Txt(rd, "TipoEstablecimiento"),
                        CodDepartamento = Txt(rd, "CodDepartamento"),
                        CodMunicipio = Txt(rd, "CodMunicipio"),
                        CodDistrito = Txt(rd, "CodDistrito"),
                        Complemento = Txt(rd, "Complemento"),
                        Telefono = Txt(rd, "Telefono"),
                        Correo = Txt(rd, "Correo"),
                        CodEstableMH = Txt(rd, "CodEstableMH"),
                        CodEstable = Txt(rd, "CodEstable"),
                        CodPuntoVentaMH = Txt(rd, "CodPuntoVentaMH"),
                        CodPuntoVenta = Txt(rd, "CodPuntoVenta"),
                        VersionFE = Convert.ToInt32(rd["VersionFE"]),
                        VersionCCF = Convert.ToInt32(rd["VersionCCF"]),
                        Logo = rd["Logo"] == DBNull.Value ? null : (byte[])rd["Logo"],
                        SmtpServidor = Txt(rd, "SmtpServidor"),
                        SmtpPuerto = rd["SmtpPuerto"] == DBNull.Value ? 0 : Convert.ToInt32(rd["SmtpPuerto"]),
                        SmtpUsuario = Txt(rd, "SmtpUsuario"),
                        SmtpClave = Txt(rd, "SmtpClave"),
                        EnviarCorreo = Convert.ToBoolean(rd["EnviarCorreo"])
                    };
                }
            }
        }

        // ===== Sucursales =====

        /// <summary>Sucursal de una factura (la de su cita). 0 si no existe.</summary>
        public static int SucursalDeFactura(long factura) { return Sucursal("select Id_Sucursal_FK from CAJ_FACTURAS where Id_factura = @id", factura); }

        /// <summary>Sucursal de un DTE emitido. 0 si no existe.</summary>
        public static int SucursalDeDte(long idDte) { return Sucursal("select Id_Sucursal_FK from FAC_DTE_DOCUMENTOS where Id_Dte = @id", idDte); }

        public static int SucursalDeCodigo(string codigoGeneracion)
        {
            using (var cn = new SqlConnection(Cn))
            using (var cmd = new SqlCommand("select Id_Sucursal_FK from FAC_DTE_DOCUMENTOS where CodigoGeneracion = @c", cn))
            {
                cmd.Parameters.Add("@c", SqlDbType.Char, 36).Value = (codigoGeneracion ?? "").Trim();
                cn.Open();
                var v = cmd.ExecuteScalar();
                return v == null || v == DBNull.Value ? 0 : Convert.ToInt32(v);
            }
        }

        private static int Sucursal(string sql, long id)
        {
            using (var cn = new SqlConnection(Cn))
            using (var cmd = new SqlCommand(sql, cn))
            {
                cmd.Parameters.Add("@id", SqlDbType.BigInt).Value = id;
                cn.Open();
                var v = cmd.ExecuteScalar();
                return v == null || v == DBNull.Value ? 0 : Convert.ToInt32(v);
            }
        }

        /// <summary>
        /// Emisor con el establecimiento de la sucursal: códigos de establecimiento y punto de venta y, si la sucursal los tiene,
        /// su dirección y teléfono. La Casa Matriz usa los datos de Opciones > Empresa > Facturación electrónica.
        /// </summary>
        public static EmisorDte ObtenerEmisor(int sucursal)
        {
            var e = ObtenerEmisor();
            if (e == null || sucursal <= 0) return e;
            var s = Opciones.SucursalesRepository.Obtener(sucursal);
            if (s == null || s.EsMatriz) return e;
            e.CodEstable = s.CodEstable;
            e.CodPuntoVenta = s.CodPuntoVenta;
            e.CodEstableMH = string.IsNullOrEmpty(s.CodEstableMH) ? null : s.CodEstableMH;
            e.CodPuntoVentaMH = string.IsNullOrEmpty(s.CodPuntoVentaMH) ? null : s.CodPuntoVentaMH;
            if (!string.IsNullOrEmpty(s.CodDepartamento) && !string.IsNullOrEmpty(s.CodMunicipio))
            {
                e.CodDepartamento = s.CodDepartamento;
                e.CodMunicipio = s.CodMunicipio;
                if (!string.IsNullOrEmpty(s.CodDistrito)) e.CodDistrito = s.CodDistrito;
            }
            if (!string.IsNullOrEmpty(s.Direccion)) e.Complemento = s.Direccion;
            if (!string.IsNullOrEmpty(s.Telefono)) e.Telefono = s.Telefono;
            return e;
        }

        public static DteEmitidoDto ObtenerDteDeFactura(long factura)
        {
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, "dbo.FAC_SP_DTE_CONSULTAS"))
            {
                cmd.Parameters.Add("@factura", SqlDbType.BigInt).Value = factura;
                cmd.Parameters.Add("@accion", SqlDbType.Int).Value = 4;
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                {
                    if (!rd.Read()) return null;
                    return new DteEmitidoDto
                    {
                        Id = Convert.ToInt64(rd["Id_Dte"]),
                        TipoDte = Txt(rd, "TipoDte"),
                        NumeroControl = Txt(rd, "NumeroControl"),
                        CodigoGeneracion = Txt(rd, "CodigoGeneracion"),
                        UrlPdf = Txt(rd, "RutaPdf"),
                        UrlJson = Txt(rd, "RutaJson"),
                        ReceptorNombre = Txt(rd, "ReceptorNombre"),
                        Total = Convert.ToDecimal(rd["TotalPagar"]),
                        CorreoDestino = Txt(rd, "CorreoDestino"),
                        FechaCorreo = rd["FechaCorreo"] == DBNull.Value ? "" : Formato.FechaHora(Convert.ToDateTime(rd["FechaCorreo"]))
                    };
                }
            }
        }

        public static List<OpcionPagoDto> ObtenerFormasPago()
        {
            var lista = new List<OpcionPagoDto>();
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, "dbo.FAC_SP_DTE_CONSULTAS"))
            {
                cmd.Parameters.Add("@factura", SqlDbType.BigInt).Value = 0;
                cmd.Parameters.Add("@accion", SqlDbType.Int).Value = 5;
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                        lista.Add(new OpcionPagoDto { Codigo = Txt(rd, "Codigo"), Descripcion = Txt(rd, "Descripcion") });
            }
            return lista;
        }

        // ===== Servicios =====
        private static SqlCommand CmdServicios(SqlConnection cn, long factura, long tratamiento, long detalle, string usuario, int accion)
        {
            var cmd = Sp(cn, "dbo.FAC_SP_DTE_SERVICIOS");
            cmd.Parameters.Add("@factura", SqlDbType.BigInt).Value = factura;
            cmd.Parameters.Add("@tratamiento", SqlDbType.BigInt).Value = tratamiento;
            cmd.Parameters.Add("@detalle", SqlDbType.BigInt).Value = detalle;
            cmd.Parameters.Add("@usuario", SqlDbType.VarChar, 20).Value = usuario;
            cmd.Parameters.Add("@accion", SqlDbType.Int).Value = accion;
            return cmd;
        }

        public static List<ServicioDto> ObtenerServicios(string usuario)
        {
            var lista = new List<ServicioDto>();
            using (var cn = new SqlConnection(Cn))
            using (var cmd = CmdServicios(cn, 0, 0, 0, usuario, 1))
            {
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read())
                        lista.Add(new ServicioDto
                        {
                            Id = Convert.ToInt64(rd["Id"]),
                            Descripcion = Txt(rd, "Descripcion"),
                            Precio = Math.Round(Convert.ToDecimal(rd["Precio"]), 2, MidpointRounding.AwayFromZero),
                            Duracion = rd["Duracion"] == DBNull.Value ? 0 : Convert.ToInt32(rd["Duracion"])
                        });
            }
            var desc = DescuentosTratamiento.Vigentes();
            foreach (var s in lista) s.Descuento = DescuentosTratamiento.Porcentaje(desc, s.Id);
            return lista;
        }

        public static void AgregarServicio(long factura, long tratamiento, string usuario)
        {
            using (var cn = new SqlConnection(Cn))
            using (var cmd = CmdServicios(cn, factura, tratamiento, 0, usuario, 2))
            {
                cn.Open();
                cmd.ExecuteNonQuery();
            }
        }

        public static void QuitarServicio(long factura, long detalle, string usuario)
        {
            using (var cn = new SqlConnection(Cn))
            using (var cmd = CmdServicios(cn, factura, 0, detalle, usuario, 3))
            {
                cn.Open();
                cmd.ExecuteNonQuery();
            }
        }

        // ===== Receptores (crédito fiscal) =====
        private static SqlCommand CmdReceptor(SqlConnection cn, SqlTransaction tx, long? expediente, ReceptorDto r, string usuario, int accion)
        {
            r = r ?? new ReceptorDto();
            var cmd = Sp(cn, "dbo.FAC_SP_DTE_RECEPTORES", tx);
            cmd.Parameters.Add("@expediente", SqlDbType.BigInt).Value = Db(expediente);
            cmd.Parameters.Add("@nit", SqlDbType.VarChar, 14).Value = DbTexto(r.Nit);
            cmd.Parameters.Add("@nrc", SqlDbType.VarChar, 8).Value = DbTexto(r.Nrc);
            cmd.Parameters.Add("@nombre", SqlDbType.VarChar, 250).Value = DbTexto(r.Nombre);
            cmd.Parameters.Add("@nombreComercial", SqlDbType.VarChar, 150).Value = DbTexto(r.NombreComercial);
            cmd.Parameters.Add("@codActividad", SqlDbType.VarChar, 6).Value = DbTexto(r.CodActividad);
            cmd.Parameters.Add("@descActividad", SqlDbType.VarChar, 150).Value = DbTexto(r.DescActividad);
            cmd.Parameters.Add("@codDepartamento", SqlDbType.Char, 2).Value = DbTexto(r.CodDepartamento);
            cmd.Parameters.Add("@codMunicipio", SqlDbType.Char, 2).Value = DbTexto(r.CodMunicipio);
            cmd.Parameters.Add("@complemento", SqlDbType.VarChar, 200).Value = DbTexto(r.Complemento);
            cmd.Parameters.Add("@telefono", SqlDbType.VarChar, 30).Value = DbTexto(r.Telefono);
            cmd.Parameters.Add("@correo", SqlDbType.VarChar, 100).Value = DbTexto(r.Correo);
            cmd.Parameters.Add("@usuario", SqlDbType.VarChar, 20).Value = usuario;
            cmd.Parameters.Add("@accion", SqlDbType.Int).Value = accion;
            cmd.Parameters.Add("@codDistrito", SqlDbType.Char, 2).Value = DbTexto(r.CodDistrito);
            return cmd;
        }

        public static ReceptorDto BuscarReceptor(long? expediente, string nit, string usuario)
        {
            using (var cn = new SqlConnection(Cn))
            using (var cmd = CmdReceptor(cn, null, expediente, new ReceptorDto { Nit = nit }, usuario, 1))
            {
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                {
                    if (!rd.Read()) return null;
                    return new ReceptorDto
                    {
                        Id = Convert.ToInt64(rd["Id_Receptor"]),
                        Nit = Txt(rd, "NIT"),
                        Nrc = Txt(rd, "NRC"),
                        Nombre = Txt(rd, "Nombre"),
                        NombreComercial = Txt(rd, "NombreComercial"),
                        CodActividad = Txt(rd, "CodActividad"),
                        DescActividad = Txt(rd, "DescActividad"),
                        CodDepartamento = Txt(rd, "CodDepartamento"),
                        CodMunicipio = Txt(rd, "CodMunicipio"),
                        CodDistrito = Txt(rd, "CodDistrito"),
                        Complemento = Txt(rd, "Complemento"),
                        Telefono = Txt(rd, "Telefono"),
                        Correo = Txt(rd, "Correo")
                    };
                }
            }
        }

        public static long GuardarReceptor(SqlConnection cn, SqlTransaction tx, long expediente, ReceptorDto r, string usuario)
        {
            using (var cmd = CmdReceptor(cn, tx, expediente, r, usuario, 2))
                return Convert.ToInt64(cmd.ExecuteScalar());
        }

        // ===== Emisión (dentro de la transacción) =====
        /// <summary>Número de control con el establecimiento y el correlativo de la sucursal de la factura.</summary>
        public static string SiguienteNumeroControl(SqlConnection cn, SqlTransaction tx, string tipoDte, string usuario, long factura)
        {
            using (var cmd = Sp(cn, "dbo.FAC_SP_DTE_CORRELATIVO", tx))
            {
                cmd.Parameters.Add("@tipoDte", SqlDbType.Char, 2).Value = tipoDte;
                cmd.Parameters.Add("@usuario", SqlDbType.VarChar, 20).Value = usuario;
                cmd.Parameters.Add("@factura", SqlDbType.BigInt).Value = factura;
                return Convert.ToString(cmd.ExecuteScalar());
            }
        }

        public static long GuardarDte(SqlConnection cn, SqlTransaction tx, long factura, string tipoDte, int version, string ambiente,
            string numeroControl, string codigoGeneracion, DateTime emision, long? receptor, string receptorNombre, string receptorDocumento,
            TotalesDto t, string totalLetras, string formaPago, string referencia, decimal montoRecibido, decimal cambio, string json, string usuario)
        {
            using (var cmd = Sp(cn, "dbo.FAC_SP_DTE_GUARDAR", tx))
            {
                var p = cmd.Parameters;
                p.Add("@factura", SqlDbType.BigInt).Value = factura;
                p.Add("@tipoDte", SqlDbType.Char, 2).Value = tipoDte;
                p.Add("@version", SqlDbType.Int).Value = version;
                p.Add("@ambiente", SqlDbType.Char, 2).Value = ambiente;
                p.Add("@numeroControl", SqlDbType.VarChar, 31).Value = numeroControl;
                p.Add("@codigoGeneracion", SqlDbType.Char, 36).Value = codigoGeneracion;
                p.Add("@fechaEmision", SqlDbType.Date).Value = emision.Date;
                p.Add("@horaEmision", SqlDbType.Time).Value = new TimeSpan(emision.Hour, emision.Minute, emision.Second);
                p.Add("@receptor", SqlDbType.BigInt).Value = Db(receptor);
                p.Add("@receptorNombre", SqlDbType.VarChar, 250).Value = receptorNombre;
                p.Add("@receptorDocumento", SqlDbType.VarChar, 20).Value = DbTexto(receptorDocumento);
                p.Add("@totalGravado", SqlDbType.Decimal).Value = t.Gravado;
                p.Add("@totalIva", SqlDbType.Decimal).Value = t.Iva;
                p.Add("@totalPagar", SqlDbType.Decimal).Value = t.Total;
                p.Add("@totalLetras", SqlDbType.VarChar, 250).Value = totalLetras;
                p.Add("@formaPago", SqlDbType.Char, 2).Value = formaPago;
                p.Add("@referenciaPago", SqlDbType.VarChar, 50).Value = DbTexto(referencia);
                p.Add("@montoRecibido", SqlDbType.Decimal).Value = montoRecibido;
                p.Add("@cambio", SqlDbType.Decimal).Value = cambio;
                p.Add("@json", SqlDbType.NVarChar, -1).Value = json;
                p.Add("@usuario", SqlDbType.VarChar, 20).Value = usuario;
                foreach (SqlParameter d in p) if (d.SqlDbType == SqlDbType.Decimal) { d.Precision = 12; d.Scale = 2; }
                return Convert.ToInt64(cmd.ExecuteScalar());
            }
        }

        /// <summary>Línea del pago combinado (Facturacion/sql/FAC_DTE_Pagos.sql).</summary>
        public static void GuardarPago(SqlConnection cn, SqlTransaction tx, long dte, PagoAplicado p, string usuario)
        {
            using (var cmd = Sp(cn, "dbo.FAC_SP_DTE_GUARDARPAGO", tx))
            {
                var c = cmd.Parameters;
                c.Add("@dte", SqlDbType.BigInt).Value = dte;
                c.Add("@formaPago", SqlDbType.Char, 2).Value = p.FormaPago;
                c.Add(new SqlParameter("@monto", SqlDbType.Decimal) { Precision = 12, Scale = 2, Value = p.Monto });
                c.Add(new SqlParameter("@recibido", SqlDbType.Decimal) { Precision = 12, Scale = 2, Value = Db(p.Recibido) });
                c.Add("@referencia", SqlDbType.VarChar, 50).Value = DbTexto(p.Referencia);
                c.Add("@usuario", SqlDbType.VarChar, 20).Value = usuario;
                cmd.ExecuteNonQuery();
            }
        }

        public static void GuardarDetalle(SqlConnection cn, SqlTransaction tx, long dte, LineaDte l)
        {
            using (var cmd = Sp(cn, "dbo.FAC_SP_DTE_GUARDARDETALLE", tx))
            {
                var p = cmd.Parameters;
                p.Add("@dte", SqlDbType.BigInt).Value = dte;
                p.Add("@numItem", SqlDbType.Int).Value = l.NumItem;
                p.Add("@tratamiento", SqlDbType.BigInt).Value = Db(l.IdTratamiento);
                p.Add("@cantidad", SqlDbType.Decimal).Value = l.Cantidad;
                p.Add("@descripcion", SqlDbType.VarChar, 1000).Value = l.Descripcion;
                p.Add(new SqlParameter("@precioUni", SqlDbType.Decimal) { Precision = 18, Scale = 8, Value = l.PrecioUni });
                p.Add("@montoDescu", SqlDbType.Decimal).Value = l.MontoDescu;
                p.Add("@ventaGravada", SqlDbType.Decimal).Value = l.VentaGravada;
                p.Add("@ivaItem", SqlDbType.Decimal).Value = l.IvaItem;
                p.Add("@descuentoTratamiento", SqlDbType.Decimal).Value = l.DescuentoTratamiento;
                p.Add("@descuentoCupon", SqlDbType.Decimal).Value = l.DescuentoCupon;
                foreach (SqlParameter d in p) if (d.SqlDbType == SqlDbType.Decimal && d.ParameterName != "@precioUni") { d.Precision = 12; d.Scale = 2; }
                cmd.ExecuteNonQuery();
            }
        }

        public static void GuardarArchivos(long dte, string rutaPdf, string rutaJson, string usuario)
        {
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, "dbo.FAC_SP_DTE_ARCHIVOS"))
            {
                cmd.Parameters.Add("@dte", SqlDbType.BigInt).Value = dte;
                cmd.Parameters.Add("@rutaPdf", SqlDbType.VarChar, 500).Value = DbTexto(rutaPdf);
                cmd.Parameters.Add("@rutaJson", SqlDbType.VarChar, 500).Value = DbTexto(rutaJson);
                cmd.Parameters.Add("@usuario", SqlDbType.VarChar, 20).Value = usuario;
                cn.Open();
                cmd.ExecuteNonQuery();
            }
        }

        public static void RegistrarCorreo(long dte, string correo, string usuario)
        {
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, "dbo.FAC_SP_DTE_CORREO"))
            {
                cmd.Parameters.Add("@dte", SqlDbType.BigInt).Value = dte;
                cmd.Parameters.Add("@correo", SqlDbType.VarChar, 100).Value = correo;
                cmd.Parameters.Add("@usuario", SqlDbType.VarChar, 20).Value = usuario;
                cn.Open();
                cmd.ExecuteNonQuery();
            }
        }

        // ===== Empresa emisora =====
        public static EmpresaDteDto ObtenerEmpresa()
        {
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, "dbo.FAC_SP_DTE_EMPRESA"))
            {
                cmd.Parameters.Add("@accion", SqlDbType.Int).Value = 1;
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                {
                    if (!rd.Read()) return null;
                    return new EmpresaDteDto
                    {
                        Ambiente = Txt(rd, "Ambiente"),
                        Nit = Txt(rd, "NIT"),
                        Nrc = Txt(rd, "NRC"),
                        Nombre = Txt(rd, "Nombre"),
                        NombreComercial = Txt(rd, "NombreComercial"),
                        CodActividad = Txt(rd, "CodActividad"),
                        DescActividad = Txt(rd, "DescActividad"),
                        TipoEstablecimiento = Txt(rd, "TipoEstablecimiento"),
                        CodDepartamento = Txt(rd, "CodDepartamento"),
                        CodMunicipio = Txt(rd, "CodMunicipio"),
                        CodDistrito = Txt(rd, "CodDistrito"),
                        Complemento = Txt(rd, "Complemento"),
                        Telefono = Txt(rd, "Telefono"),
                        Correo = Txt(rd, "Correo"),
                        CodEstableMH = Txt(rd, "CodEstableMH"),
                        CodEstable = Txt(rd, "CodEstable"),
                        CodPuntoVentaMH = Txt(rd, "CodPuntoVentaMH"),
                        CodPuntoVenta = Txt(rd, "CodPuntoVenta"),
                        SmtpServidor = Txt(rd, "SmtpServidor"),
                        SmtpPuerto = rd["SmtpPuerto"] == DBNull.Value ? 0 : Convert.ToInt32(rd["SmtpPuerto"]),
                        SmtpUsuario = Txt(rd, "SmtpUsuario"),
                        EnviarCorreo = Convert.ToBoolean(rd["EnviarCorreo"]),
                        VersionFE = Convert.ToInt32(rd["VersionFE"]),
                        VersionCCF = Convert.ToInt32(rd["VersionCCF"]),
                        TieneClave = Convert.ToBoolean(rd["TieneClave"]),
                        TieneLogo = Convert.ToBoolean(rd["TieneLogo"]),
                        Version = Convert.ToDateTime(rd["Version"]).Ticks.ToString()
                    };
                }
            }
        }

        // claveCifrada null = conserva la clave guardada
        public static void GuardarEmpresa(EmpresaDteDto e, string claveCifrada, string usuario)
        {
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, "dbo.FAC_SP_DTE_EMPRESA"))
            {
                var p = cmd.Parameters;
                p.Add("@accion", SqlDbType.Int).Value = 2;
                p.Add("@ambiente", SqlDbType.Char, 2).Value = e.Ambiente;
                p.Add("@nit", SqlDbType.VarChar, 14).Value = e.Nit;
                p.Add("@nrc", SqlDbType.VarChar, 8).Value = e.Nrc;
                p.Add("@nombre", SqlDbType.VarChar, 250).Value = e.Nombre;
                p.Add("@nombreComercial", SqlDbType.VarChar, 150).Value = DbTexto(e.NombreComercial);
                p.Add("@codActividad", SqlDbType.VarChar, 6).Value = e.CodActividad;
                p.Add("@descActividad", SqlDbType.VarChar, 150).Value = e.DescActividad;
                p.Add("@tipoEstablecimiento", SqlDbType.Char, 2).Value = e.TipoEstablecimiento;
                p.Add("@codDepartamento", SqlDbType.Char, 2).Value = e.CodDepartamento;
                p.Add("@codMunicipio", SqlDbType.Char, 2).Value = e.CodMunicipio;
                p.Add("@complemento", SqlDbType.VarChar, 200).Value = e.Complemento;
                p.Add("@telefono", SqlDbType.VarChar, 30).Value = e.Telefono;
                p.Add("@correo", SqlDbType.VarChar, 100).Value = e.Correo;
                p.Add("@codEstableMH", SqlDbType.Char, 4).Value = DbTexto(e.CodEstableMH);
                p.Add("@codEstable", SqlDbType.Char, 4).Value = e.CodEstable;
                p.Add("@codPuntoVentaMH", SqlDbType.Char, 4).Value = DbTexto(e.CodPuntoVentaMH);
                p.Add("@codPuntoVenta", SqlDbType.Char, 4).Value = e.CodPuntoVenta;
                p.Add("@smtpServidor", SqlDbType.VarChar, 150).Value = DbTexto(e.SmtpServidor);
                p.Add("@smtpPuerto", SqlDbType.Int).Value = e.SmtpPuerto > 0 ? (object)e.SmtpPuerto : DBNull.Value;
                p.Add("@smtpUsuario", SqlDbType.VarChar, 100).Value = DbTexto(e.SmtpUsuario);
                p.Add("@smtpClave", SqlDbType.VarChar, 1000).Value = Db(claveCifrada);
                p.Add("@enviarCorreo", SqlDbType.Bit).Value = e.EnviarCorreo;
                p.Add("@usuario", SqlDbType.VarChar, 20).Value = usuario;
                p.Add("@codDistrito", SqlDbType.Char, 2).Value = DbTexto(e.CodDistrito);
                p.Add("@versionFE", SqlDbType.Int).Value = e.VersionFE == 1 || e.VersionFE == 2 ? (object)e.VersionFE : DBNull.Value;
                p.Add("@versionCCF", SqlDbType.Int).Value = e.VersionCCF == 3 || e.VersionCCF == 4 ? (object)e.VersionCCF : DBNull.Value;
                cn.Open();
                cmd.ExecuteNonQuery();
            }
        }

        public static void GuardarLogo(byte[] logo, string tipo, string usuario)
        {
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, "dbo.FAC_SP_DTE_EMPRESA"))
            {
                cmd.Parameters.Add("@accion", SqlDbType.Int).Value = 3;
                cmd.Parameters.Add("@logo", SqlDbType.VarBinary, -1).Value = Db(logo);
                cmd.Parameters.Add("@logoTipo", SqlDbType.VarChar, 30).Value = Db(tipo);
                cmd.Parameters.Add("@usuario", SqlDbType.VarChar, 20).Value = usuario;
                cn.Open();
                cmd.ExecuteNonQuery();
            }
        }

        // ===== Diagnóstico (Facturacion/sql/FAC_DTE_Diagnostico.sql) =====

        /// <summary>Registra el resultado de guardar archivos o enviar el correo; un fallo al registrar no interrumpe la emisión.</summary>
        public static void RegistrarEvento(long dte, string etapa, bool ok, string mensaje, string usuario)
        {
            try
            {
                using (var cn = new SqlConnection(Cn))
                using (var cmd = Sp(cn, "dbo.FAC_SP_DTE_DIAGNOSTICO"))
                {
                    cmd.Parameters.Add("@accion", SqlDbType.Int).Value = 1;
                    cmd.Parameters.Add("@id", SqlDbType.BigInt).Value = dte;
                    cmd.Parameters.Add("@etapa", SqlDbType.VarChar, 20).Value = etapa;
                    cmd.Parameters.Add("@ok", SqlDbType.Bit).Value = ok;
                    cmd.Parameters.Add("@mensaje", SqlDbType.NVarChar, 1000).Value = DbTexto(mensaje != null && mensaje.Length > 1000 ? mensaje.Substring(0, 1000) : mensaje);
                    cmd.Parameters.Add("@usuario", SqlDbType.VarChar, 20).Value = DbTexto(usuario);
                    cmd.Parameters.Add("@servidor", SqlDbType.VarChar, 100).Value = Environment.MachineName;
                    cn.Open();
                    cmd.ExecuteNonQuery();
                }
            }
            catch (Exception ex) { System.Diagnostics.Trace.TraceError("DTE evento: " + ex); }
        }

        public static DataTable Diagnostico(int accion)
        {
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, "dbo.FAC_SP_DTE_DIAGNOSTICO"))
            {
                cmd.Parameters.Add("@accion", SqlDbType.Int).Value = accion;
                var t = new DataTable();
                using (var da = new SqlDataAdapter(cmd)) da.Fill(t);
                return t;
            }
        }

        /// <summary>Fila de FAC_DTE_DOCUMENTOS con lo necesario para rearmar el PDF desde el JSON guardado.</summary>
        public static DataRow DocumentoParaArchivos(long id, string codigo)
        {
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, "dbo.FAC_SP_DTE_DIAGNOSTICO"))
            {
                cmd.Parameters.Add("@accion", SqlDbType.Int).Value = 4;
                cmd.Parameters.Add("@id", SqlDbType.BigInt).Value = id;
                cmd.Parameters.Add("@codigo", SqlDbType.Char, 36).Value = DbTexto(codigo);
                var t = new DataTable();
                using (var da = new SqlDataAdapter(cmd)) da.Fill(t);
                return t.Rows.Count > 0 ? t.Rows[0] : null;
            }
        }

        public static byte[] ObtenerLogo(out string tipo)
        {
            tipo = null;
            using (var cn = new SqlConnection(Cn))
            using (var cmd = Sp(cn, "dbo.FAC_SP_DTE_EMPRESA"))
            {
                cmd.Parameters.Add("@accion", SqlDbType.Int).Value = 4;
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                {
                    if (!rd.Read() || rd["Logo"] == DBNull.Value) return null;
                    tipo = Txt(rd, "LogoTipo");
                    return (byte[])rd["Logo"];
                }
            }
        }
    }
}
