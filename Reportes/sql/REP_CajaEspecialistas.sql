/* =====================================================================
   DPieCenter - Reporte de caja por especialista (Reportes/frm_repCajaEspecialistas.aspx)

   REP_SP_CajaEspecialistas @accion:
     1 cobros del periodo (DTE vigentes por fecha de emisión) asignados al especialista que atendió:
         - factura de un procedimiento: especialista del procedimiento (Origen 'P')
         - pago adelantado de una cita aún sin procedimiento: especialista de la cita (Origen 'C')
         - pago adelantado sin cita (monto libre): sin especialista (Origen 'L')
       y los pagos adelantados aplicados en el periodo (Origen 'U'): no suman al cobrado (ya se cobraron),
       solo a la venta sin IVA del especialista que atendió, como en las metas (MET_SP_Metas 5).
       SinIva: factura (01) precio con IVA / 1.13; crédito fiscal (03) venta gravada (mismo criterio que las metas).
       Filtros: @especialista, @formaPago (código CAT-017; '' = todas), @paciente (nombre, documento o celular),
       @sucursal (la del documento; 0 = todas)
     2 formas de pago (filtro)
     3 líneas de pago de los DTE vigentes del periodo (pago combinado): cobrado por forma de pago de cada especialista
   Requiere FAC_DTE_Estructura.sql, FAC_DTE_Pagos.sql y CAJ_Anticipos.sql.
   Script idempotente: se puede ejecutar varias veces.
   ===================================================================== */
SET NOCOUNT ON;
GO

CREATE OR ALTER PROCEDURE [dbo].[REP_SP_CajaEspecialistas]
     @accion       int
    ,@desde        date = null
    ,@hasta        date = null
    ,@especialista bigint = 0
    ,@formaPago    varchar(2) = null
    ,@paciente     varchar(100) = null
    ,@sucursal     int = 0
AS
BEGIN
    SET NOCOUNT ON;

    if @accion = 2
    begin
        select Codigo, Descripcion from dbo.CAT_FORMASPAGO where Estatus = 1 order by Codigo
        return
    end

    if @accion = 1
    begin
        if @desde is null or @hasta is null or @hasta < @desde
            THROW 50083, 'Seleccione un rango de fechas válido.', 1;
        if DATEDIFF(DAY, @desde, @hasta) > 366
            THROW 50084, 'El rango no puede superar un año.', 1;

        set @formaPago = NULLIF(LTRIM(RTRIM(@formaPago)), '')
        set @paciente = NULLIF(LTRIM(RTRIM(@paciente)), '')
        declare @fin datetime = DATEADD(DAY, 1, CAST(@hasta as datetime))

        ;with cobros as (
            select 'D' as Clase
                ,d.Id_Dte as Id
                ,CAST(d.FechaEmision as datetime) + CAST(ISNULL(d.HoraEmision, '00:00') as datetime) as Fecha
                ,d.TipoDte
                ,ISNULL(d.NumeroControl, '') as Documento
                ,f.Id_Expediente_FK as Id_Expediente
                ,ISNULL(d.ReceptorNombre, '') as Cliente
                ,ISNULL(d.FormaPago, '') as FormaPago
                ,dbo.FAC_FN_FormasPagoTexto(d.Id_Dte) as FormaPagoTexto      -- pago combinado (FAC_DTE_Pagos.sql)
                ,ISNULL(d.TotalGravado, 0) as Gravado
                ,ISNULL(d.TotalIva, 0) as Iva
                ,ISNULL(d.TotalPagar, 0) as Total
                ,ISNULL(ln.SinIva, 0) as SinIva
                ,case when f.Id_Procedimiento_FK is not null then 'P' when f.Id_Cita_FK is not null then 'C' else 'L' end as Origen
                ,case when f.Id_Procedimiento_FK is not null then p.Id_Especialista_fk else c.Id_Especialista_fk end as Id_Especialista
                ,f.Id_Procedimiento_FK as Id_Procedimiento
                ,p.Fecha as FechaAtencion
                ,ISNULL(d.UsuarioCrea, '') as Cajero
                ,d.Id_Sucursal_FK as Id_Sucursal
            from FAC_DTE_DOCUMENTOS as d
                left join CAJ_FACTURAS as f on f.Id_factura = d.Id_Factura_FK
                left join EXP_PROCEDIMIENTOS as p on p.Id_Procedimiento = f.Id_Procedimiento_FK
                left join EXP_CITAS as c on c.Id_Cita = f.Id_Cita_FK
                left join CAT_FORMASPAGO as fp on fp.Codigo = d.FormaPago
                -- decimal(18,2) antes de dividir: SUM devuelve decimal(38,2) y la división perdería los decimales
                outer apply (select CAST(CAST(SUM(ISNULL(dd.VentaGravada, 0)) as decimal(18,2)) / case when d.TipoDte = '01' then 1.13 else 1 end as decimal(18,6)) as SinIva
                             from FAC_DTE_DETALLES as dd where dd.Id_Dte_FK = d.Id_Dte) as ln
            where d.Estado <> 'A' and d.FechaEmision >= @desde and d.FechaEmision <= @hasta
                and (@sucursal = 0 or d.Id_Sucursal_FK = @sucursal)
                -- forma de pago: documentos que la usaron (sola o combinada)
                and (@formaPago is null or exists (select 1 from FAC_VW_DTE_PAGOS as fx where fx.Id_Dte = d.Id_Dte and fx.FormaPago = @formaPago))
            union all
            -- pagos adelantados aplicados en el periodo (el cobro ya se registró cuando se pagó)
            select 'U', u.Id_Uso, u.FechaCrea, 'AD', ISNULL(da.NumeroControl, '')
                ,p.Id_Expediente_fk, '', ISNULL(da.FormaPago, ''), 'Pago adelantado'
                ,0, 0, 0, CAST(u.Monto / 1.13 as decimal(18,6))
                ,'U', p.Id_Especialista_fk, u.Id_Procedimiento_FK, p.Fecha, u.UsuarioCrea, p.Id_Sucursal_FK
            from CAJ_ANTICIPOS_USOS as u
                inner join EXP_PROCEDIMIENTOS as p on p.Id_Procedimiento = u.Id_Procedimiento_FK
                outer apply (select top 1 NumeroControl, FormaPago from FAC_DTE_DOCUMENTOS
                             where Id_Factura_FK = u.Id_FacturaAnticipo_FK and Estado <> 'A' order by Id_Dte desc) as da
            where u.FechaCrea >= @desde and u.FechaCrea < @fin
                and (@sucursal = 0 or p.Id_Sucursal_FK = @sucursal)
                and @formaPago is null
        )
        select x.Clase, x.Id, x.Fecha, x.TipoDte, x.Documento, x.Id_Expediente
            ,ISNULL(LTRIM(RTRIM(e.Nombres + ' ' + e.Apellidos)), x.Cliente) as Paciente
            ,ISNULL(e.Documento, '') as DocumentoPaciente
            ,x.Cliente, x.FormaPago, x.FormaPagoTexto
            ,x.Gravado, x.Iva, x.Total
            ,CAST(x.SinIva as decimal(16,6)) as SinIva     -- se redondea al sumar (igual que las metas y el Dashboard)
            ,x.Origen, ISNULL(x.Id_Especialista, 0) as Id_Especialista
            ,ISNULL(s.Descripcion, '') as Especialista
            ,x.Id_Procedimiento, x.FechaAtencion
            ,ISNULL(STUFF((select ', ' + t.Descripcion from EXP_PROCEDIMIENTOSTRATAMIENTOS as t
                           where t.Id_Procedimiento_FK = x.Id_Procedimiento order by t.Id
                           for xml path(''), type).value('.', 'varchar(max)'), 1, 2, ''), '') as Tratamientos
            ,ISNULL(LTRIM(RTRIM(us.Nombres + ' ' + us.Apellidos)), x.Cajero) as Cajero
            ,ISNULL(su.Nombre, '') as Sucursal
        from cobros as x
            left join EXP_EXPEDIENTES as e on e.Id_Expediente = x.Id_Expediente
            left join CAT_ESPECIALISTAS as s on s.Id_Especialista = x.Id_Especialista
            left join Sys_Usuarios as us on us.Id_Usuario = x.Cajero
            left join CAT_SUCURSALES as su on su.Id_Sucursal = x.Id_Sucursal
        where (@especialista = 0 or x.Id_Especialista = @especialista)
            and (@paciente is null or e.Nombres + ' ' + e.Apellidos like '%' + @paciente + '%'
                 or e.Apellidos + ' ' + e.Nombres like '%' + @paciente + '%'
                 or e.Documento like '%' + @paciente + '%' or e.Celular like '%' + @paciente + '%'
                 or x.Cliente like '%' + @paciente + '%')
        order by x.Fecha, x.Id
        return
    end;

    if @accion = 3
    begin
        select d.Id_Dte, ISNULL(fp.Descripcion, p.FormaPago) as FormaPago, p.Monto
        from FAC_DTE_DOCUMENTOS as d
            inner join FAC_VW_DTE_PAGOS as p on p.Id_Dte = d.Id_Dte
            left join CAT_FORMASPAGO as fp on fp.Codigo = p.FormaPago
        where d.Estado <> 'A' and d.FechaEmision >= @desde and d.FechaEmision <= @hasta
            and (@sucursal = 0 or d.Id_Sucursal_FK = @sucursal)
        return
    end;

    THROW 50099, 'Acción no válida.', 1;
END
GO

/* ---------- Menú: Reportes > Caja por especialista (mismos grupos que los demás reportes) ---------- */
IF NOT EXISTS (SELECT 1 FROM dbo.Sys_Opciones WHERE AccesoURL = 'Reportes/frm_repCajaEspecialistas.aspx')
BEGIN
    BEGIN TRANSACTION;
    DECLARE @opcion bigint;
    INSERT INTO dbo.Sys_Opciones (Descripcion, Abreviado, AccesoURL, IdModulo_FK, Id_UsuarioCrea_FK, FechaCreacion, Orden)
    VALUES ('Caja por especialista', 'CE', 'Reportes/frm_repCajaEspecialistas.aspx', 6, 'admin', GETDATE(), 7);
    SET @opcion = SCOPE_IDENTITY();
    INSERT INTO dbo.Sys_Permisos (IdAplicativo_FK, IdModulo_FK, IdOpcion_FK, IdGrupo_FK, Id_UsuarioCrea_FK, FechaCreacion)
    SELECT 2, 6, @opcion, g.Grupo, 'admin', GETDATE()
    FROM (VALUES ('Administradores'), ('ADMINISTRATIVOS'), ('Direccion')) as g(Grupo)
    WHERE EXISTS (SELECT 1 FROM dbo.Sys_Permisos WHERE IdGrupo_FK = g.Grupo);
    INSERT INTO dbo.Sys_AccesosObjetos (IdAplicativo_FK, IdModulo_FK, IdOpcion_FK, IdGrupo_FK, Descripcion, Accion)
    VALUES (2, 6, @opcion, 'Administradores', 'Caja por especialista', 1);
    COMMIT TRANSACTION;
END
GO
