/* =====================================================================
   DPieCenter - Metas de ventas y esquema de bono por especialista (analista) (Registros/frm_Metas.aspx)

   Basado en "Tabla de Bonos Dpie.xlsx":
     - Meta mensual de ventas sin IVA de cada especialista (varía mes a mes).
     - Salario base y mínimo de ventas para empezar a comisionar.
     - Bonificación por escala: según el rango de ventas, un % sobre la diferencia (ventas sin IVA − mínimo para comisionar) más un bono fijo.
     - Bonificación por alcance: monto fijo al cumplir la meta.

   Cada especialista tiene una meta vigente por mes. Nunca se modifica en su lugar: cada cambio crea una versión nueva
   (vigente) y la anterior queda inactiva como historial (quién y cuándo la reemplazó).
   Si un mes no tiene meta (no hubo cambios) se genera automáticamente copiando la del mes anterior (Origen 'A').
   Al cambiar la meta de un mes, los meses siguientes que se habían generado automáticamente toman el cambio.

   Ventas sin IVA de un especialista = líneas de DTE vigentes (no anulados) de sus procedimientos, por fecha de emisión,
   ya con los descuentos (por tratamiento y cupón). En la factura (01) el precio incluye IVA: se divide entre 1.13.
   Script idempotente: se puede ejecutar varias veces.
   ===================================================================== */
SET NOCOUNT ON;
GO

IF OBJECT_ID('dbo.MET_METAS', 'U') IS NULL
    CREATE TABLE dbo.MET_METAS (
        Id_Meta          bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_MET_METAS PRIMARY KEY,
        Anio             int           NOT NULL,
        Mes              int           NOT NULL CONSTRAINT CK_MET_METAS_Mes CHECK (Mes between 1 and 12),
        MetaVentas       decimal(12,2) NOT NULL,      -- meta mensual de ventas sin IVA del especialista
        SalarioBase      decimal(12,2) NOT NULL CONSTRAINT DF_MET_METAS_Salario DEFAULT (0),
        MinimoComision   decimal(12,2) NOT NULL CONSTRAINT DF_MET_METAS_Minimo DEFAULT (0),
        BonoAlcance      decimal(12,2) NOT NULL CONSTRAINT DF_MET_METAS_Bono DEFAULT (0),   -- por cumplir la meta
        Observaciones    varchar(500)  NULL,
        Vigente          bit           NOT NULL CONSTRAINT DF_MET_METAS_Vigente DEFAULT (1),
        UsuarioCrea      varchar(20)   NOT NULL,
        FechaCrea        datetime      NOT NULL CONSTRAINT DF_MET_METAS_FechaCrea DEFAULT (GETDATE()),
        UsuarioModifica  varchar(20)   NULL,          -- quién la reemplazó por una versión nueva
        FechaModifica    datetime      NULL
    );
GO
IF COL_LENGTH('dbo.MET_METAS', 'Id_Especialista_FK') IS NULL
    ALTER TABLE dbo.MET_METAS ADD Id_Especialista_FK bigint NULL;
GO
IF COL_LENGTH('dbo.MET_METAS', 'Origen') IS NULL
    ALTER TABLE dbo.MET_METAS ADD Origen char(1) NOT NULL CONSTRAINT DF_MET_METAS_Origen DEFAULT ('M');   -- M manual | A automática
GO
IF COL_LENGTH('dbo.MET_METAS', 'Id_MetaOrigen_FK') IS NULL
    ALTER TABLE dbo.MET_METAS ADD Id_MetaOrigen_FK bigint NULL;    -- versión que reemplaza o meta del mes anterior que copió
GO
IF OBJECT_ID('dbo.MET_ESCALAS', 'U') IS NULL
    CREATE TABLE dbo.MET_ESCALAS (
        Id_Escala   bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_MET_ESCALAS PRIMARY KEY,
        Id_Meta_FK  bigint        NOT NULL CONSTRAINT FK_MET_ESCALAS_Meta REFERENCES dbo.MET_METAS (Id_Meta) ON DELETE CASCADE,
        Desde       decimal(12,2) NOT NULL,
        Hasta       decimal(12,2) NULL,                -- NULL: en adelante
        Porcentaje  decimal(5,2)  NOT NULL CONSTRAINT DF_MET_ESCALAS_Pct DEFAULT (0),  -- % sobre (ventas sin IVA − mínimo para comisionar)
        Bono        decimal(12,2) NOT NULL CONSTRAINT DF_MET_ESCALAS_Bono DEFAULT (0)  -- monto fijo adicional
    );
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_MET_ESCALAS_Meta')
    CREATE INDEX IX_MET_ESCALAS_Meta ON dbo.MET_ESCALAS (Id_Meta_FK, Desde);
GO
-- Antes había una sola meta vigente para todos: ahora una por especialista y mes
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_MET_METAS_Vigente')
    DROP INDEX UX_MET_METAS_Vigente ON dbo.MET_METAS;
GO

/* Migración: la meta general anterior se copia a cada especialista activo (misma escala) y se elimina */
IF EXISTS (SELECT 1 FROM dbo.MET_METAS WHERE Id_Especialista_FK IS NULL)
BEGIN
    SET XACT_ABORT ON;
    BEGIN TRANSACTION;
    DECLARE @nuevas TABLE (Id_Meta bigint, Id_Origen bigint);
    INSERT INTO dbo.MET_METAS (Anio, Mes, MetaVentas, SalarioBase, MinimoComision, BonoAlcance, Observaciones, Vigente
        ,UsuarioCrea, FechaCrea, Id_Especialista_FK, Origen, Id_MetaOrigen_FK)
    OUTPUT inserted.Id_Meta, inserted.Id_MetaOrigen_FK INTO @nuevas
    SELECT m.Anio, m.Mes, m.MetaVentas, m.SalarioBase, m.MinimoComision, m.BonoAlcance, m.Observaciones, 1
        ,m.UsuarioCrea, m.FechaCrea, s.Id_Especialista, 'M', m.Id_Meta
    FROM dbo.MET_METAS AS m
        CROSS JOIN dbo.CAT_ESPECIALISTAS AS s
    WHERE m.Id_Especialista_FK IS NULL AND m.Vigente = 1 AND s.IsActivo = 1;
    INSERT INTO dbo.MET_ESCALAS (Id_Meta_FK, Desde, Hasta, Porcentaje, Bono)
    SELECT n.Id_Meta, e.Desde, e.Hasta, e.Porcentaje, e.Bono
    FROM @nuevas AS n INNER JOIN dbo.MET_ESCALAS AS e ON e.Id_Meta_FK = n.Id_Origen;
    UPDATE dbo.MET_METAS SET Id_MetaOrigen_FK = NULL WHERE Id_MetaOrigen_FK IN (SELECT Id_Meta FROM dbo.MET_METAS WHERE Id_Especialista_FK IS NULL);
    DELETE FROM dbo.MET_METAS WHERE Id_Especialista_FK IS NULL;
    COMMIT TRANSACTION;
END
GO
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.MET_METAS') AND name = 'Id_Especialista_FK' AND is_nullable = 1)
    ALTER TABLE dbo.MET_METAS ALTER COLUMN Id_Especialista_FK bigint NOT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_MET_METAS_Especialista')
    ALTER TABLE dbo.MET_METAS ADD CONSTRAINT FK_MET_METAS_Especialista FOREIGN KEY (Id_Especialista_FK) REFERENCES dbo.CAT_ESPECIALISTAS (Id_Especialista);
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_MET_METAS_Origen')
    ALTER TABLE dbo.MET_METAS ADD CONSTRAINT CK_MET_METAS_Origen CHECK (Origen in ('M', 'A'));
GO
-- Una sola versión vigente por especialista y mes
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_MET_METAS_EspecialistaMes')
    CREATE UNIQUE INDEX UX_MET_METAS_EspecialistaMes ON dbo.MET_METAS (Id_Especialista_FK, Anio, Mes) WHERE Vigente = 1;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_MET_METAS_Historial')
    CREATE INDEX IX_MET_METAS_Historial ON dbo.MET_METAS (Id_Especialista_FK, Anio, Mes, Id_Meta);
GO

/* Genera la meta de los meses sin meta, hasta @anio/@mes (nunca después del mes en curso), copiando la del mes anterior
   de cada especialista activo. Un especialista sin ninguna meta previa no se genera: se le asigna en la pantalla. */
CREATE OR ALTER PROCEDURE [dbo].[MET_SP_GenerarMetas]
     @anio int
    ,@mes  int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    declare @hasta int = @anio * 12 + @mes - 1
    declare @hoy int = YEAR(GETDATE()) * 12 + MONTH(GETDATE()) - 1
    if @hasta > @hoy set @hasta = @hoy

    -- nada que hacer: todos los activos con alguna meta ya tienen la del mes
    if not exists (
        select 1 from CAT_ESPECIALISTAS as s
        where s.IsActivo = 1
            and exists (select 1 from MET_METAS where Id_Especialista_FK = s.Id_Especialista and Vigente = 1 and Anio * 12 + Mes - 1 < @hasta)
            and not exists (select 1 from MET_METAS where Id_Especialista_FK = s.Id_Especialista and Vigente = 1 and Anio * 12 + Mes - 1 = @hasta))
        return

    BEGIN TRANSACTION;
    -- evita que dos pantallas generen el mismo mes a la vez
    exec sp_getapplock @Resource = 'MET_SP_GenerarMetas', @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 15000;

    -- primer mes que falta (el siguiente a la última meta de cada especialista), máximo 24 meses atrás
    declare @m int = (
        select MIN(u.Ultimo) + 1
        from (select s.Id_Especialista, MAX(m.Anio * 12 + m.Mes - 1) as Ultimo
              from CAT_ESPECIALISTAS as s inner join MET_METAS as m on m.Id_Especialista_FK = s.Id_Especialista and m.Vigente = 1
              where s.IsActivo = 1 and m.Anio * 12 + m.Mes - 1 <= @hasta
              group by s.Id_Especialista) as u
        where u.Ultimo < @hasta)
    if @m is null set @m = @hasta
    if @m < @hasta - 23 set @m = @hasta - 23

    declare @nuevas table (Id_Meta bigint, Id_Origen bigint)
    while @m <= @hasta
    begin
        delete from @nuevas
        -- copia la última meta anterior al mes (normalmente la del mes inmediato anterior)
        insert into MET_METAS (Anio, Mes, MetaVentas, SalarioBase, MinimoComision, BonoAlcance, Observaciones, Vigente
            ,UsuarioCrea, FechaCrea, Id_Especialista_FK, Origen, Id_MetaOrigen_FK)
        output inserted.Id_Meta, inserted.Id_MetaOrigen_FK into @nuevas
        select @m / 12, @m % 12 + 1, a.MetaVentas, a.SalarioBase, a.MinimoComision, a.BonoAlcance, a.Observaciones, 1
            ,'sistema', GETDATE(), a.Id_Especialista_FK, 'A', a.Id_Meta
        from (select x.*, ROW_NUMBER() over (partition by x.Id_Especialista_FK order by x.Anio desc, x.Mes desc) as n
              from MET_METAS as x where x.Vigente = 1 and x.Anio * 12 + x.Mes - 1 < @m) as a
            inner join CAT_ESPECIALISTAS as s on s.Id_Especialista = a.Id_Especialista_FK and s.IsActivo = 1
        where a.n = 1
            and not exists (select 1 from MET_METAS as x where x.Id_Especialista_FK = a.Id_Especialista_FK and x.Vigente = 1 and x.Anio * 12 + x.Mes - 1 = @m)

        insert into MET_ESCALAS (Id_Meta_FK, Desde, Hasta, Porcentaje, Bono)
        select n.Id_Meta, e.Desde, e.Hasta, e.Porcentaje, e.Bono
        from @nuevas as n inner join MET_ESCALAS as e on e.Id_Meta_FK = n.Id_Origen
        set @m = @m + 1
    end
    COMMIT TRANSACTION;
END
GO

/* ---------- Meta sugerida según el mes del año ----------
   Meta sugerida = promedio de ventas sin IVA de los últimos MesesBase meses × factor del mes × (1 + Crecimiento %),
   redondeada a Redondeo. El cálculo está en Registros/MetasRepository.cs (Sugerencias); aquí, los parámetros. */
IF OBJECT_ID('dbo.MET_FACTORES_MES', 'U') IS NULL
    CREATE TABLE dbo.MET_FACTORES_MES (
        Mes              int          NOT NULL CONSTRAINT PK_MET_FACTORES_MES PRIMARY KEY CONSTRAINT CK_MET_FACTORES_Mes CHECK (Mes between 1 and 12),
        Factor           decimal(5,2) NOT NULL CONSTRAINT CK_MET_FACTORES_Factor CHECK (Factor between 0.1 and 5),
        UsuarioModifica  varchar(20)  NULL,
        FechaModifica    datetime     NULL
    );
GO
-- Supuestos iniciales (editables en Registros > Metas): cuesta de enero, Día de la Madre, vacaciones agostinas, Black Month, Navidad
IF NOT EXISTS (SELECT 1 FROM dbo.MET_FACTORES_MES)
    INSERT INTO dbo.MET_FACTORES_MES (Mes, Factor)
    VALUES (1, 0.85), (2, 0.90), (3, 0.95), (4, 1.00), (5, 1.05), (6, 1.00), (7, 0.95), (8, 1.05), (9, 0.95), (10, 1.00), (11, 1.05), (12, 1.15);
GO
IF OBJECT_ID('dbo.MET_PARAMETROS', 'U') IS NULL
    CREATE TABLE dbo.MET_PARAMETROS (
        Id               int          NOT NULL CONSTRAINT PK_MET_PARAMETROS PRIMARY KEY CONSTRAINT CK_MET_PARAMETROS_Id CHECK (Id = 1),
        Crecimiento      decimal(5,2) NOT NULL CONSTRAINT DF_MET_PARAMETROS_Crec DEFAULT (5),      -- % sobre el promedio
        Redondeo         int          NOT NULL CONSTRAINT DF_MET_PARAMETROS_Red DEFAULT (50),      -- múltiplo de $
        MesesBase        int          NOT NULL CONSTRAINT DF_MET_PARAMETROS_Meses DEFAULT (3),
        UsuarioModifica  varchar(20)  NULL,
        FechaModifica    datetime     NULL
    );
GO
IF NOT EXISTS (SELECT 1 FROM dbo.MET_PARAMETROS) INSERT INTO dbo.MET_PARAMETROS (Id) VALUES (1);
GO

/* @accion 1 metas de un mes: la vigente de cada especialista (activos o con meta), genera el mes si falta
           2 una versión (encabezado y escalas)
           3 guardar: nueva versión para cada especialista de @especialistas (<s i="1"/>...) en @anio/@mes;
             la vigente pasa al historial y los meses siguientes generados automáticamente toman el cambio
           4 historial de versiones de un especialista (@especialista)
           5 avance de un mes: meta de cada especialista, escalas y ventas sin IVA (@especialista 0 = todos)
           6 meta sugerida de @anio/@mes: factores, parámetros, inicio de los datos y ventas sin IVA por especialista
             de los meses anteriores (hasta el mes en curso). Facturas electrónicas desde el primer mes con DTE;
             antes, el valor de los procedimientos finalizados.
           7 guardar factores (@factores <f m="1" v="0.85"/>...) y parámetros (@crecimiento, @redondeo)
   @escalas: <e d="1251" h="2000" p="12" b="0"/>... (h vacío = en adelante) */
CREATE OR ALTER PROCEDURE [dbo].[MET_SP_Metas]
     @accion         int
    ,@id             bigint = 0
    ,@anio           int = 0
    ,@mes            int = 0
    ,@meta           decimal(12,2) = 0
    ,@salario        decimal(12,2) = 0
    ,@minimo         decimal(12,2) = 0
    ,@bonoAlcance    decimal(12,2) = 0
    ,@observaciones  varchar(500) = NULL
    ,@escalas        xml = NULL
    ,@especialistas  xml = NULL
    ,@especialista   bigint = 0
    ,@user           varchar(20) = NULL
    ,@factores       xml = NULL
    ,@crecimiento    decimal(5,2) = NULL
    ,@redondeo       int = NULL
    ,@meses          int = 0          -- 6: meses anteriores a @anio/@mes (0 = MesesBase); con > 0 también devuelve las metas
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;      -- un error dentro de la transacción la revierte completa

    if @accion in (1, 5) and (@anio = 0 or @mes = 0) select @anio = YEAR(GETDATE()), @mes = MONTH(GETDATE())
    if @accion in (1, 5) exec MET_SP_GenerarMetas @anio, @mes

    if @accion = 1
    begin
        select s.Id_Especialista, s.Descripcion as Especialista, s.IsActivo
            ,m.Id_Meta, m.Anio, m.Mes, m.MetaVentas, m.SalarioBase, m.MinimoComision, m.BonoAlcance, m.Observaciones, m.Vigente
            ,m.UsuarioCrea, m.FechaCrea, m.UsuarioModifica, m.FechaModifica, m.Origen
            ,(select COUNT(*) from MET_ESCALAS where Id_Meta_FK = m.Id_Meta) as Escalas
            ,(select COUNT(*) from MET_METAS where Id_Especialista_FK = s.Id_Especialista and Anio = @anio and Mes = @mes) as Versiones
        from CAT_ESPECIALISTAS as s
            left join MET_METAS as m on m.Id_Especialista_FK = s.Id_Especialista and m.Anio = @anio and m.Mes = @mes and m.Vigente = 1
        where s.IsActivo = 1 or m.Id_Meta is not null
        order by s.Descripcion
        return
    end

    if @accion = 2
    begin
        select m.Id_Meta, m.Anio, m.Mes, m.MetaVentas, m.SalarioBase, m.MinimoComision, m.BonoAlcance, m.Observaciones, m.Vigente
            ,m.UsuarioCrea, m.FechaCrea, m.UsuarioModifica, m.FechaModifica, m.Origen
            ,m.Id_Especialista_FK as Id_Especialista, s.Descripcion as Especialista
        from MET_METAS as m inner join CAT_ESPECIALISTAS as s on s.Id_Especialista = m.Id_Especialista_FK
        where m.Id_Meta = @id
        select Id_Escala, Desde, Hasta, Porcentaje, Bono from MET_ESCALAS where Id_Meta_FK = @id order by Desde
        return
    end

    if @accion = 3
    begin
        if @anio not between 2020 and 2100 or @mes not between 1 and 12
            THROW 50401, 'Seleccione el mes y el año de la meta.', 1;
        if ISNULL(@meta, 0) <= 0
            THROW 50402, 'La meta mensual de ventas debe ser mayor que cero.', 1;
        if @salario < 0 or @minimo < 0 or @bonoAlcance < 0
            THROW 50403, 'Los montos no pueden ser negativos.', 1;

        declare @esc table (Desde decimal(12,2), Hasta decimal(12,2) null, Porcentaje decimal(5,2), Bono decimal(12,2))
        insert into @esc
        select x.value('@d', 'decimal(12,2)')
            ,NULLIF(x.value('@h', 'varchar(20)'), '')
            ,ISNULL(NULLIF(x.value('@p', 'varchar(20)'), ''), '0')
            ,ISNULL(NULLIF(x.value('@b', 'varchar(20)'), ''), '0')
        from @escalas.nodes('/e') as t(x)

        if exists (select 1 from @esc where Desde < 0 or Porcentaje < 0 or Porcentaje > 100 or Bono < 0 or (Hasta is not null and Hasta < Desde))
            THROW 50404, 'Revise la escala: los rangos deben ir de menor a mayor y el porcentaje entre 0 y 100.', 1;
        if exists (select Desde from @esc group by Desde having COUNT(*) > 1)
            THROW 50405, 'Hay dos rangos de la escala que empiezan en el mismo monto.', 1;

        declare @esp table (Id_Especialista bigint primary key)
        insert into @esp
        select distinct s.Id_Especialista
        from @especialistas.nodes('/s') as t(x)
            inner join CAT_ESPECIALISTAS as s on s.Id_Especialista = x.value('@i', 'bigint')
        if not exists (select 1 from @esp)
            THROW 50406, 'Seleccione al menos un especialista.', 1;

        declare @obs varchar(500) = NULLIF(LTRIM(RTRIM(@observaciones)), '')
        declare @nuevas table (Id_Meta bigint, Id_Origen bigint, Id_Especialista bigint)
        declare @mm int = @anio * 12 + @mes - 1
        declare @hoy int = YEAR(GETDATE()) * 12 + MONTH(GETDATE()) - 1

        BEGIN TRANSACTION;
        exec sp_getapplock @Resource = 'MET_SP_GenerarMetas', @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 15000;

        -- la versión vigente del mes pasa al historial
        declare @anteriores table (Id_Meta bigint, Id_Especialista bigint)
        update m set Vigente = 0, UsuarioModifica = @user, FechaModifica = GETDATE()
        output deleted.Id_Meta, deleted.Id_Especialista_FK into @anteriores
        from MET_METAS as m inner join @esp as e on e.Id_Especialista = m.Id_Especialista_FK
        where m.Anio = @anio and m.Mes = @mes and m.Vigente = 1

        insert into MET_METAS (Anio, Mes, MetaVentas, SalarioBase, MinimoComision, BonoAlcance, Observaciones, Vigente
            ,UsuarioCrea, FechaCrea, Id_Especialista_FK, Origen, Id_MetaOrigen_FK)
        output inserted.Id_Meta, inserted.Id_MetaOrigen_FK, inserted.Id_Especialista_FK into @nuevas
        select @anio, @mes, @meta, @salario, @minimo, @bonoAlcance, @obs, 1, @user, GETDATE(), e.Id_Especialista, 'M', a.Id_Meta
        from @esp as e left join @anteriores as a on a.Id_Especialista = e.Id_Especialista

        insert into MET_ESCALAS (Id_Meta_FK, Desde, Hasta, Porcentaje, Bono)
        select n.Id_Meta, s.Desde, s.Hasta, s.Porcentaje, s.Bono from @nuevas as n cross join @esc as s

        -- los meses siguientes que se generaron automáticamente (sin cambios) toman la meta nueva, hasta el primero con cambios
        declare @sig int = @mm + 1
        declare @prev table (Id_Meta bigint, Id_Especialista bigint)
        insert into @prev select Id_Meta, Id_Especialista from @nuevas
        while @sig <= @hoy and exists (select 1 from @prev)
        begin
            delete from @anteriores
            update m set Vigente = 0, UsuarioModifica = @user, FechaModifica = GETDATE()
            output deleted.Id_Meta, deleted.Id_Especialista_FK into @anteriores
            from MET_METAS as m inner join @prev as p on p.Id_Especialista = m.Id_Especialista_FK
            where m.Anio * 12 + m.Mes - 1 = @sig and m.Vigente = 1 and m.Origen = 'A'

            delete from @nuevas
            insert into MET_METAS (Anio, Mes, MetaVentas, SalarioBase, MinimoComision, BonoAlcance, Observaciones, Vigente
                ,UsuarioCrea, FechaCrea, Id_Especialista_FK, Origen, Id_MetaOrigen_FK)
            output inserted.Id_Meta, inserted.Id_MetaOrigen_FK, inserted.Id_Especialista_FK into @nuevas
            select @sig / 12, @sig % 12 + 1, @meta, @salario, @minimo, @bonoAlcance, @obs, 1, 'sistema', GETDATE(), a.Id_Especialista, 'A', p.Id_Meta
            from @anteriores as a inner join @prev as p on p.Id_Especialista = a.Id_Especialista

            insert into MET_ESCALAS (Id_Meta_FK, Desde, Hasta, Porcentaje, Bono)
            select n.Id_Meta, s.Desde, s.Hasta, s.Porcentaje, s.Bono from @nuevas as n cross join @esc as s

            delete from @prev
            insert into @prev select Id_Meta, Id_Especialista from @nuevas
            set @sig = @sig + 1
        end
        COMMIT TRANSACTION;

        select (select COUNT(*) from @esp) as Guardadas
        return
    end

    if @accion = 4
    begin
        select m.Id_Meta, m.Anio, m.Mes, m.MetaVentas, m.SalarioBase, m.MinimoComision, m.BonoAlcance, m.Observaciones, m.Vigente
            ,m.UsuarioCrea, m.FechaCrea, m.UsuarioModifica, m.FechaModifica, m.Origen
            ,m.Id_Especialista_FK as Id_Especialista, s.Descripcion as Especialista
            ,(select COUNT(*) from MET_ESCALAS where Id_Meta_FK = m.Id_Meta) as Escalas
        from MET_METAS as m inner join CAT_ESPECIALISTAS as s on s.Id_Especialista = m.Id_Especialista_FK
        where m.Id_Especialista_FK = @especialista
        order by m.Anio desc, m.Mes desc, m.Vigente desc, m.Id_Meta desc
        return
    end

    if @accion = 5
    begin
        declare @ini date = DATEFROMPARTS(@anio, @mes, 1)
        declare @fin date = EOMONTH(@ini)

        -- meta del mes de cada especialista; si el mes es futuro y aún no tiene, la última que tenga
        declare @metas table (Id_Meta bigint, Id_Especialista bigint)
        insert into @metas
        select x.Id_Meta, x.Id_Especialista_FK
        from (select m.Id_Meta, m.Id_Especialista_FK
                ,ROW_NUMBER() over (partition by m.Id_Especialista_FK order by m.Anio desc, m.Mes desc) as n
              from MET_METAS as m
              where m.Vigente = 1 and m.Anio * 12 + m.Mes <= @anio * 12 + @mes
                and (@especialista = 0 or m.Id_Especialista_FK = @especialista)) as x
        where x.n = 1

        select m.Id_Meta, m.Anio, m.Mes, m.MetaVentas, m.SalarioBase, m.MinimoComision, m.BonoAlcance, m.Vigente, m.Origen
            ,m.Id_Especialista_FK as Id_Especialista
        from MET_METAS as m inner join @metas as x on x.Id_Meta = m.Id_Meta
        select e.Id_Meta_FK as Id_Meta, e.Desde, e.Hasta, e.Porcentaje, e.Bono
        from MET_ESCALAS as e inner join @metas as x on x.Id_Meta = e.Id_Meta_FK
        order by e.Id_Meta_FK, e.Desde

        ;with lineas as (
            select p.Id_Especialista_fk as Id_Especialista, p.Id_Procedimiento
                ,case when d.TipoDte = '01' then ISNULL(dd.VentaGravada, 0) / 1.13 else ISNULL(dd.VentaGravada, 0) end as Venta
                -- con IVA: en la factura (01) el precio ya lo incluye; en el crédito fiscal (03) se suma el 13 %
                ,case when d.TipoDte = '01' then ISNULL(dd.VentaGravada, 0) else ISNULL(dd.VentaGravada, 0) * 1.13 end as VentaConIva
            from FAC_DTE_DOCUMENTOS as d
                inner join FAC_DTE_DETALLES as dd on dd.Id_Dte_FK = d.Id_Dte
                inner join CAJ_FACTURAS as f on f.Id_factura = d.Id_Factura_FK
                inner join EXP_PROCEDIMIENTOS as p on p.Id_Procedimiento = f.Id_Procedimiento_FK
            where d.Estado <> 'A' and d.FechaEmision >= @ini and d.FechaEmision <= @fin
                and (@especialista = 0 or p.Id_Especialista_fk = @especialista)
            union all
            -- pago adelantado sin cita (CAJ_Anticipos.sql): cuenta para el especialista que atendió, el día que se usó (sin IVA)
            select p.Id_Especialista_fk, p.Id_Procedimiento, u.Monto / 1.13, u.Monto
            from CAJ_ANTICIPOS_USOS as u
                inner join EXP_PROCEDIMIENTOS as p on p.Id_Procedimiento = u.Id_Procedimiento_FK
            where u.FechaCrea >= @ini and u.FechaCrea < DATEADD(DAY, 1, @fin)
                and (@especialista = 0 or p.Id_Especialista_fk = @especialista)
        ), v as (
            select Id_Especialista, SUM(Venta) as Ventas, SUM(VentaConIva) as VentasConIva, COUNT(distinct Id_Procedimiento) as Procedimientos
            from lineas
            group by Id_Especialista
        )
        select s.Id_Especialista, s.Descripcion as Especialista
            ,CAST(ISNULL(v.Ventas, 0) as decimal(12,2)) as Ventas
            ,CAST(ISNULL(v.VentasConIva, 0) as decimal(12,2)) as VentasConIva
            ,ISNULL(v.Procedimientos, 0) as Procedimientos
        from CAT_ESPECIALISTAS as s
            left join v on v.Id_Especialista = s.Id_Especialista
        where (@especialista = 0 and (s.IsActivo = 1 or v.Ventas > 0)) or s.Id_Especialista = @especialista
        order by ISNULL(v.Ventas, 0) desc, s.Descripcion
        return
    end

    if @accion = 6
    begin
        if @anio = 0 or @mes = 0 select @anio = YEAR(GETDATE()), @mes = MONTH(GETDATE())
        declare @historico bit = case when @meses > 0 then 1 else 0 end
        if @meses not between 1 and 24 set @meses = ISNULL((select MesesBase from MET_PARAMETROS where Id = 1), 3)
        declare @objetivo date = DATEFROMPARTS(@anio, @mes, 1)
        declare @desdeS date = DATEADD(MONTH, -@meses, @objetivo)
        declare @hastaS date = DATEADD(DAY, 1, CAST(GETDATE() as date))          -- nunca después de hoy
        if @hastaS > @objetivo set @hastaS = @objetivo
        declare @primerDte date = (select DATEFROMPARTS(YEAR(MIN(FechaEmision)), MONTH(MIN(FechaEmision)), 1) from FAC_DTE_DOCUMENTOS)
        if @primerDte is null set @primerDte = '9999-01-01'

        select Mes, Factor from MET_FACTORES_MES order by Mes
        select Crecimiento, Redondeo, MesesBase, UsuarioModifica, FechaModifica from MET_PARAMETROS where Id = 1
        -- inicio de los datos: un mes que empieza después del día 1 está incompleto y no se promedia
        select MIN(Fecha) as InicioDatos from EXP_PROCEDIMIENTOS where Estado = 'F'

        ;with lineas as (
            select p.Id_Especialista_fk as Id_Especialista, DATEFROMPARTS(YEAR(d.FechaEmision), MONTH(d.FechaEmision), 1) as Mes
                ,case when d.TipoDte = '01' then ISNULL(dd.VentaGravada, 0) / 1.13 else ISNULL(dd.VentaGravada, 0) end as Venta
            from FAC_DTE_DOCUMENTOS as d
                inner join FAC_DTE_DETALLES as dd on dd.Id_Dte_FK = d.Id_Dte
                inner join CAJ_FACTURAS as f on f.Id_factura = d.Id_Factura_FK
                inner join EXP_PROCEDIMIENTOS as p on p.Id_Procedimiento = f.Id_Procedimiento_FK
            where d.Estado <> 'A' and d.FechaEmision >= @desdeS and d.FechaEmision < @hastaS and d.FechaEmision >= @primerDte
            union all
            select p.Id_Especialista_fk, DATEFROMPARTS(YEAR(u.FechaCrea), MONTH(u.FechaCrea), 1), u.Monto / 1.13
            from CAJ_ANTICIPOS_USOS as u inner join EXP_PROCEDIMIENTOS as p on p.Id_Procedimiento = u.Id_Procedimiento_FK
            where u.FechaCrea >= @desdeS and u.FechaCrea < @hastaS
            union all
            -- meses anteriores a la facturación electrónica: valor de los procedimientos finalizados (sin IVA)
            select p.Id_Especialista_fk, DATEFROMPARTS(YEAR(p.Fecha), MONTH(p.Fecha), 1), ISNULL(t.Valor, 0) / 1.13
            from EXP_PROCEDIMIENTOS as p inner join EXP_PROCEDIMIENTOSTRATAMIENTOS as t on t.Id_Procedimiento_FK = p.Id_Procedimiento
            where p.Estado = 'F' and p.Fecha >= @desdeS and p.Fecha < @hastaS and p.Fecha < @primerDte
        )
        select l.Id_Especialista, YEAR(l.Mes) as Anio, MONTH(l.Mes) as Mes, CAST(SUM(l.Venta) as decimal(12,2)) as Ventas
            ,case when l.Mes >= @primerDte then 'DTE' else 'PROC' end as Fuente
        from lineas as l
            inner join CAT_ESPECIALISTAS as s on s.Id_Especialista = l.Id_Especialista
        where (@especialista = 0 and s.IsActivo = 1) or l.Id_Especialista = @especialista
        group by l.Id_Especialista, l.Mes
        order by l.Id_Especialista, l.Mes

        -- histórico (dashboard de gerencia): meta vigente de cada especialista en cada mes del rango
        if @historico = 1
            select m.Id_Especialista_FK as Id_Especialista, s.Descripcion as Especialista, m.Anio, m.Mes, m.MetaVentas
            from MET_METAS as m inner join CAT_ESPECIALISTAS as s on s.Id_Especialista = m.Id_Especialista_FK
            where m.Vigente = 1 and DATEFROMPARTS(m.Anio, m.Mes, 1) >= @desdeS and DATEFROMPARTS(m.Anio, m.Mes, 1) < @objetivo
                and ((@especialista = 0 and s.IsActivo = 1) or m.Id_Especialista_FK = @especialista)
            order by m.Id_Especialista_FK, m.Anio, m.Mes
        return
    end

    if @accion = 7
    begin
        declare @fx table (Mes int, Factor decimal(5,2))
        insert into @fx select x.value('@m', 'int'), x.value('@v', 'decimal(5,2)') from @factores.nodes('/f') as t(x)
        if (select COUNT(distinct Mes) from @fx where Mes between 1 and 12) <> 12
            THROW 50420, 'Indique el factor de los 12 meses.', 1;
        if exists (select 1 from @fx where Factor is null or Factor < 0.1 or Factor > 5)
            THROW 50421, 'Cada factor debe estar entre 0.10 y 5.00 (1.00 = un mes normal).', 1;
        if @crecimiento is null or @crecimiento < -50 or @crecimiento > 100
            THROW 50422, 'El crecimiento debe estar entre -50 % y 100 %.', 1;
        if @redondeo not in (1, 10, 25, 50, 100)
            THROW 50423, 'El redondeo debe ser $1, $10, $25, $50 o $100.', 1;

        BEGIN TRANSACTION;
        update f set Factor = x.Factor, UsuarioModifica = @user, FechaModifica = GETDATE()
        from MET_FACTORES_MES as f inner join @fx as x on x.Mes = f.Mes
        where f.Factor <> x.Factor
        update MET_PARAMETROS set Crecimiento = @crecimiento, Redondeo = @redondeo, UsuarioModifica = @user, FechaModifica = GETDATE() where Id = 1
        COMMIT TRANSACTION;
        select 1 as Ok
        return
    end;

    THROW 50099, 'Acción no válida.', 1;
END
GO

/* Meta inicial tomada de "Tabla de Bonos Dpie.xlsx" (noviembre 2026) para cada especialista activo, solo si aún no hay metas */
IF NOT EXISTS (SELECT 1 FROM dbo.MET_METAS)
BEGIN
    DECLARE @n TABLE (Id_Meta bigint);
    INSERT INTO dbo.MET_METAS (Anio, Mes, MetaVentas, SalarioBase, MinimoComision, BonoAlcance, Observaciones, Vigente, UsuarioCrea, FechaCrea, Id_Especialista_FK, Origen)
    OUTPUT inserted.Id_Meta INTO @n
    SELECT 2026, 11, 2500, 500, 1250, 100, 'Tabla de Bonos Dpie (noviembre 2026)', 1, 'admin', GETDATE(), Id_Especialista, 'M'
    FROM dbo.CAT_ESPECIALISTAS WHERE IsActivo = 1;
    INSERT INTO dbo.MET_ESCALAS (Id_Meta_FK, Desde, Hasta, Porcentaje, Bono)
    SELECT n.Id_Meta, e.Desde, e.Hasta, e.Porcentaje, e.Bono
    FROM @n AS n CROSS JOIN (VALUES (1251, 2000, 12, 0), (2001, 2500, 15, 0), (2501, 3000, 18, 0), (3001, 3500, 20, 0), (3501, NULL, 20, 150)) AS e(Desde, Hasta, Porcentaje, Bono);
END
GO

/* ---------- Menú: Registros > Metas (administración) ---------- */
IF NOT EXISTS (SELECT 1 FROM dbo.Sys_Opciones WHERE AccesoURL = 'Registros/frm_Metas.aspx')
BEGIN
    BEGIN TRANSACTION;
    DECLARE @opcion bigint;
    INSERT INTO dbo.Sys_Opciones (Descripcion, Abreviado, AccesoURL, IdModulo_FK, Id_UsuarioCrea_FK, FechaCreacion, Orden)
    VALUES ('Metas', 'ME', 'Registros/frm_Metas.aspx', 4, 'admin', GETDATE(), 8);
    SET @opcion = SCOPE_IDENTITY();
    INSERT INTO dbo.Sys_Permisos (IdAplicativo_FK, IdModulo_FK, IdOpcion_FK, IdGrupo_FK, Id_UsuarioCrea_FK, FechaCreacion)
    SELECT 2, 4, @opcion, g.Grupo, 'admin', GETDATE()
    FROM (VALUES ('Administradores'), ('Direccion')) as g(Grupo)
    WHERE EXISTS (SELECT 1 FROM dbo.Sys_Permisos WHERE IdGrupo_FK = g.Grupo);
    INSERT INTO dbo.Sys_AccesosObjetos (IdAplicativo_FK, IdModulo_FK, IdOpcion_FK, IdGrupo_FK, Descripcion, Accion)
    VALUES (2, 4, @opcion, 'Administradores', 'Metas', 1);
    COMMIT TRANSACTION;
END
GO
