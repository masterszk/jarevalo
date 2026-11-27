/* =====================================================================
   DPieCenter - Documentos Tributarios Electrónicos (DTE) - Ministerio de Hacienda SV
   Factura Consumidor Final (01, versión JSON 1) y Comprobante de Crédito Fiscal (03, versión JSON 3)

   Script idempotente: solo crea objetos nuevos y agrega columnas faltantes a las tablas FAC_DTE_*
   (no altera tablas ni SPs existentes de otros módulos). Se puede ejecutar varias veces.
   ===================================================================== */
SET NOCOUNT ON;
GO

/* ---------- Catálogo de formas de pago (CAT-017 MH) ---------- */
IF OBJECT_ID('dbo.CAT_FORMASPAGO', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CAT_FORMASPAGO (
        Codigo          char(2)      NOT NULL CONSTRAINT PK_CAT_FORMASPAGO PRIMARY KEY,
        Descripcion     varchar(100) NOT NULL,
        Estatus         bit          NOT NULL CONSTRAINT DF_CAT_FORMASPAGO_Estatus DEFAULT (1),
        UsuarioCrea     varchar(20)  NOT NULL CONSTRAINT DF_CAT_FORMASPAGO_UC DEFAULT ('admin'),
        FechaCrea       datetime     NOT NULL CONSTRAINT DF_CAT_FORMASPAGO_FC DEFAULT (GETDATE()),
        UsuarioModifica varchar(20)  NULL,
        FechaModifica   datetime     NULL
    );
    INSERT INTO dbo.CAT_FORMASPAGO (Codigo, Descripcion) VALUES
        ('01', 'Billetes y monedas'),
        ('02', 'Tarjeta Débito'),
        ('03', 'Tarjeta Crédito'),
        ('04', 'Cheque'),
        ('05', 'Transferencias'),
        ('99', 'Otros');
END
GO
-- Nombre corto de la forma de pago 05 en pantallas y reportes (el DTE envía solo el código)
UPDATE dbo.CAT_FORMASPAGO SET Descripcion = 'Transferencias', UsuarioModifica = 'admin', FechaModifica = GETDATE()
WHERE Codigo = '05' AND Descripcion <> 'Transferencias';
GO

/* ---------- Parámetros del emisor para el DTE ---------- */
IF OBJECT_ID('dbo.FAC_DTE_PARAMETROS', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.FAC_DTE_PARAMETROS (
        Id_Parametro        int          IDENTITY(1,1) NOT NULL CONSTRAINT PK_FAC_DTE_PARAMETROS PRIMARY KEY,
        Ambiente            char(2)      NOT NULL CONSTRAINT DF_FAC_DTE_PARAMETROS_Amb DEFAULT ('00'),   -- 00 pruebas, 01 producción
        NIT                 varchar(14)  NOT NULL,            -- sin guiones
        NRC                 varchar(8)   NOT NULL,            -- sin guiones
        Nombre              varchar(250) NOT NULL,
        NombreComercial     varchar(150) NULL,
        CodActividad        varchar(6)   NOT NULL,            -- CAT-019
        DescActividad       varchar(150) NOT NULL,
        TipoEstablecimiento char(2)      NOT NULL CONSTRAINT DF_FAC_DTE_PARAMETROS_TE DEFAULT ('02'),   -- CAT-009: 02 Casa matriz
        CodDepartamento     char(2)      NOT NULL,            -- CAT-012
        CodMunicipio        char(2)      NOT NULL,            -- CAT-013
        Complemento         varchar(200) NOT NULL,
        Telefono            varchar(30)  NOT NULL,
        Correo              varchar(100) NOT NULL,
        CodEstableMH        char(4)      NULL,
        CodEstable          char(4)      NOT NULL CONSTRAINT DF_FAC_DTE_PARAMETROS_CE DEFAULT ('M001'),
        CodPuntoVentaMH     char(4)      NULL,
        CodPuntoVenta       char(4)      NOT NULL CONSTRAINT DF_FAC_DTE_PARAMETROS_PV DEFAULT ('P001'),
        VersionFE           int          NOT NULL CONSTRAINT DF_FAC_DTE_PARAMETROS_VFE DEFAULT (2),     -- DTE 2.0
        VersionCCF          int          NOT NULL CONSTRAINT DF_FAC_DTE_PARAMETROS_VCCF DEFAULT (4),    -- DTE 2.0
        Estado              bit          NOT NULL CONSTRAINT DF_FAC_DTE_PARAMETROS_Est DEFAULT (1),
        UsuarioCrea         varchar(20)  NOT NULL CONSTRAINT DF_FAC_DTE_PARAMETROS_UC DEFAULT ('admin'),
        FechaCrea           datetime     NOT NULL CONSTRAINT DF_FAC_DTE_PARAMETROS_FC DEFAULT (GETDATE()),
        UsuarioModifica     varchar(20)  NULL,
        FechaModifica       datetime     NULL
    );

    -- Valores iniciales tomados de Sys_ConfiguracionApp.
    -- REVISAR: CodActividad, CodDepartamento y CodMunicipio deben coincidir con los catálogos del MH.
    INSERT INTO dbo.FAC_DTE_PARAMETROS (NIT, NRC, Nombre, NombreComercial, CodActividad, DescActividad,
                                        CodDepartamento, CodMunicipio, Complemento, Telefono, Correo)
    SELECT TOP 1
        REPLACE(REPLACE(ISNULL(NumeroNIT, ''), '-', ''), ' ', ''),
        REPLACE(REPLACE(ISNULL(RegistroIVA, ''), '-', ''), ' ', ''),
        ISNULL(NombreEmpresa, ''),
        'D PIE CENTER',
        '96020',
        LEFT(ISNULL(ActividadEconomica, ''), 150),
        '06',
        '23',
        LEFT(ISNULL(Direccion, ''), 200),
        ISNULL(Telefono, ''),
        ISNULL(Email, '')
    FROM dbo.Sys_ConfiguracionApp;
END
GO

/* ---------- Correlativos por tipo de DTE y año ---------- */
IF OBJECT_ID('dbo.FAC_DTE_CORRELATIVOS', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.FAC_DTE_CORRELATIVOS (
        TipoDte         char(2)     NOT NULL,
        Anio            int         NOT NULL,
        Ultimo          bigint      NOT NULL CONSTRAINT DF_FAC_DTE_CORRELATIVOS_Ult DEFAULT (0),
        UsuarioCrea     varchar(20) NOT NULL,
        FechaCrea       datetime    NOT NULL CONSTRAINT DF_FAC_DTE_CORRELATIVOS_FC DEFAULT (GETDATE()),
        UsuarioModifica varchar(20) NULL,
        FechaModifica   datetime    NULL,
        CONSTRAINT PK_FAC_DTE_CORRELATIVOS PRIMARY KEY (TipoDte, Anio)
    );
END
GO

/* ---------- Receptores (datos fiscales para Crédito Fiscal) ---------- */
IF OBJECT_ID('dbo.FAC_DTE_RECEPTORES', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.FAC_DTE_RECEPTORES (
        Id_Receptor      bigint       IDENTITY(1,1) NOT NULL CONSTRAINT PK_FAC_DTE_RECEPTORES PRIMARY KEY,
        Id_Expediente_FK bigint       NULL CONSTRAINT FK_FAC_DTE_RECEPTORES_EXP REFERENCES dbo.EXP_EXPEDIENTES (Id_Expediente),
        NIT              varchar(14)  NOT NULL,
        NRC              varchar(8)   NOT NULL,
        Nombre           varchar(250) NOT NULL,
        NombreComercial  varchar(150) NULL,
        CodActividad     varchar(6)   NOT NULL,
        DescActividad    varchar(150) NOT NULL,
        CodDepartamento  char(2)      NOT NULL,
        CodMunicipio     char(2)      NOT NULL,
        Complemento      varchar(200) NOT NULL,
        Telefono         varchar(30)  NULL,
        Correo           varchar(100) NOT NULL,
        Estado           bit          NOT NULL CONSTRAINT DF_FAC_DTE_RECEPTORES_Est DEFAULT (1),
        UsuarioCrea      varchar(20)  NOT NULL,
        FechaCrea        datetime     NOT NULL CONSTRAINT DF_FAC_DTE_RECEPTORES_FC DEFAULT (GETDATE()),
        UsuarioModifica  varchar(20)  NULL,
        FechaModifica    datetime     NULL
    );
    CREATE UNIQUE INDEX UX_FAC_DTE_RECEPTORES_NIT ON dbo.FAC_DTE_RECEPTORES (NIT);
    CREATE INDEX IX_FAC_DTE_RECEPTORES_EXP ON dbo.FAC_DTE_RECEPTORES (Id_Expediente_FK);
END
GO

/* ---------- Documentos emitidos ---------- */
IF OBJECT_ID('dbo.FAC_DTE_DOCUMENTOS', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.FAC_DTE_DOCUMENTOS (
        Id_Dte            bigint        IDENTITY(1,1) NOT NULL CONSTRAINT PK_FAC_DTE_DOCUMENTOS PRIMARY KEY,
        Id_Factura_FK     bigint        NOT NULL CONSTRAINT FK_FAC_DTE_DOCUMENTOS_FAC REFERENCES dbo.CAJ_FACTURAS (Id_factura),
        Id_TipoFactura_FK bigint        NOT NULL CONSTRAINT FK_FAC_DTE_DOCUMENTOS_TIPO REFERENCES dbo.CAT_TIPOSFACTURAS (Id_TipoFactura),
        TipoDte           char(2)       NOT NULL,
        VersionJson       int           NOT NULL,
        Ambiente          char(2)       NOT NULL,
        NumeroControl     varchar(31)   NOT NULL,
        CodigoGeneracion  char(36)      NOT NULL,
        FechaEmision      date          NOT NULL,
        HoraEmision       time(0)       NOT NULL,
        Id_Receptor_FK    bigint        NULL CONSTRAINT FK_FAC_DTE_DOCUMENTOS_REC REFERENCES dbo.FAC_DTE_RECEPTORES (Id_Receptor),
        ReceptorNombre    varchar(250)  NOT NULL,
        ReceptorDocumento varchar(20)   NULL,
        TotalGravado      decimal(12,2) NOT NULL,
        TotalIva          decimal(12,2) NOT NULL,
        TotalPagar        decimal(12,2) NOT NULL,
        TotalLetras       varchar(250)  NOT NULL,
        FormaPago         char(2)       NOT NULL CONSTRAINT FK_FAC_DTE_DOCUMENTOS_FP REFERENCES dbo.CAT_FORMASPAGO (Codigo),
        ReferenciaPago    varchar(50)   NULL,
        MontoRecibido     decimal(12,2) NOT NULL,
        Cambio            decimal(12,2) NOT NULL,
        JsonDte           nvarchar(max) NOT NULL,
        RutaPdf           varchar(500)  NULL,
        RutaJson          varchar(500)  NULL,
        SelloRecepcion    varchar(100)  NULL,
        FechaProcesado    datetime      NULL,
        Estado            char(1)       NOT NULL CONSTRAINT DF_FAC_DTE_DOCUMENTOS_Est DEFAULT ('G'),   -- G generado, T transmitido, R rechazado, A anulado
        UsuarioCrea       varchar(20)   NOT NULL,
        FechaCrea         datetime      NOT NULL CONSTRAINT DF_FAC_DTE_DOCUMENTOS_FC DEFAULT (GETDATE()),
        UsuarioModifica   varchar(20)   NULL,
        FechaModifica     datetime      NULL
    );
    CREATE UNIQUE INDEX UX_FAC_DTE_DOCUMENTOS_NC ON dbo.FAC_DTE_DOCUMENTOS (NumeroControl);
    CREATE UNIQUE INDEX UX_FAC_DTE_DOCUMENTOS_CG ON dbo.FAC_DTE_DOCUMENTOS (CodigoGeneracion);
    CREATE INDEX IX_FAC_DTE_DOCUMENTOS_FAC ON dbo.FAC_DTE_DOCUMENTOS (Id_Factura_FK);
END
GO

IF OBJECT_ID('dbo.FAC_DTE_DETALLES', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.FAC_DTE_DETALLES (
        Id_DteDetalle     bigint         IDENTITY(1,1) NOT NULL CONSTRAINT PK_FAC_DTE_DETALLES PRIMARY KEY,
        Id_Dte_FK         bigint         NOT NULL CONSTRAINT FK_FAC_DTE_DETALLES_DTE REFERENCES dbo.FAC_DTE_DOCUMENTOS (Id_Dte),
        NumItem           int            NOT NULL,
        Id_Tratamiento_FK bigint         NULL,
        Cantidad          decimal(12,2)  NOT NULL,
        Descripcion       varchar(1000)  NOT NULL,
        PrecioUni         decimal(18,8)  NOT NULL,
        MontoDescu        decimal(12,2)  NOT NULL,
        VentaGravada      decimal(12,2)  NOT NULL,
        IvaItem           decimal(12,2)  NOT NULL
    );
    CREATE INDEX IX_FAC_DTE_DETALLES_DTE ON dbo.FAC_DTE_DETALLES (Id_Dte_FK);
END
GO

/* ---------- Logo y correo de envío del emisor ---------- */
IF COL_LENGTH('dbo.FAC_DTE_PARAMETROS', 'Logo') IS NULL
    ALTER TABLE dbo.FAC_DTE_PARAMETROS ADD
        Logo          varbinary(max) NULL,             -- PNG/JPG que se imprime en el PDF
        LogoTipo      varchar(30)    NULL,             -- image/png | image/jpeg
        SmtpServidor  varchar(150)   NULL,
        SmtpPuerto    int            NULL,
        SmtpUsuario   varchar(100)   NULL,             -- también es el remitente
        SmtpClave     varchar(1000)  NULL,             -- cifrada (DPAPI) desde la aplicación
        EnviarCorreo  bit            NOT NULL CONSTRAINT DF_FAC_DTE_PARAMETROS_EnvC DEFAULT (0);
GO

/* ---------- DTE 2.0 (Factura v2 / Crédito Fiscal v4): la dirección lleva el distrito ----------
   CodMunicipio es el municipio de la división territorial 2024 (CAT-013) y CodDistrito el antiguo municipio
   (ver assets/js/dte-catalogos.js). */
IF COL_LENGTH('dbo.FAC_DTE_PARAMETROS', 'CodDistrito') IS NULL
BEGIN
    ALTER TABLE dbo.FAC_DTE_PARAMETROS ADD CodDistrito char(2) NULL;
    -- Solo la primera vez: DTE 2.0 (factura v2 y crédito fiscal v4). Después se cambia en Opciones > Empresa.
    UPDATE dbo.FAC_DTE_PARAMETROS SET VersionFE = 2 WHERE VersionFE = 1;
    UPDATE dbo.FAC_DTE_PARAMETROS SET VersionCCF = 4 WHERE VersionCCF = 3;
END
GO
IF COL_LENGTH('dbo.FAC_DTE_RECEPTORES', 'CodDistrito') IS NULL
    ALTER TABLE dbo.FAC_DTE_RECEPTORES ADD CodDistrito char(2) NULL;
GO
-- Clínica en San Salvador Centro (municipio 23): distrito 14 = San Salvador. Solo si aún no se configuró.
UPDATE dbo.FAC_DTE_PARAMETROS SET CodDistrito = '14'
 WHERE CodDistrito IS NULL AND CodDepartamento = '06' AND CodMunicipio = '23';
GO

IF COL_LENGTH('dbo.FAC_DTE_DOCUMENTOS', 'CorreoDestino') IS NULL
    ALTER TABLE dbo.FAC_DTE_DOCUMENTOS ADD
        CorreoDestino varchar(100) NULL,
        FechaCorreo   datetime     NULL;
GO

UPDATE dbo.FAC_DTE_PARAMETROS
   SET SmtpServidor = 'p3plzcpnl507039.prod.phx3.secureserver.net', SmtpPuerto = 465, SmtpUsuario = 'dte@dpiesv.com'
 WHERE SmtpServidor IS NULL;
GO

/* =====================================================================
   PROCEDIMIENTOS
   ===================================================================== */

/* Cobro de citas por adelantado (detalle en Facturacion/sql/CAJ_Anticipos.sql): la factura de un anticipo no tiene
   procedimiento hasta que se atiende la cita. Se crean aquí porque FAC_SP_DTE_CONSULTAS las lee. */
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.CAJ_FACTURAS') AND name = 'Id_Procedimiento_FK' AND is_nullable = 0)
    ALTER TABLE dbo.CAJ_FACTURAS ALTER COLUMN Id_Procedimiento_FK bigint NULL;
IF COL_LENGTH('dbo.CAJ_FACTURAS', 'Id_Cita_FK') IS NULL
    ALTER TABLE dbo.CAJ_FACTURAS ADD Id_Cita_FK bigint NULL;
IF COL_LENGTH('dbo.CAJ_FACTURAS', 'Anticipo') IS NULL
    ALTER TABLE dbo.CAJ_FACTURAS ADD Anticipo bit NOT NULL CONSTRAINT DF_CAJ_FACTURAS_Anticipo DEFAULT (0);
IF COL_LENGTH('dbo.CAJ_FACTURAS', 'MontoLibre') IS NULL
    ALTER TABLE dbo.CAJ_FACTURAS ADD MontoLibre bit NOT NULL CONSTRAINT DF_CAJ_FACTURAS_MontoLibre DEFAULT (0);
GO

/* Consultas de la pantalla de pago
   @accion 1: factura + cliente | 2: items | 3: parámetros del emisor | 4: DTE emitido de la factura | 5: formas de pago */
CREATE OR ALTER PROCEDURE dbo.FAC_SP_DTE_CONSULTAS
     @factura bigint
    ,@accion  int
AS
BEGIN
    SET NOCOUNT ON;

    IF @accion = 1
        -- Anticipo / CitaInicio: cobro de una cita por adelantado (CAJ_Anticipos.sql)
        SELECT f.Id_factura, f.Estado, f.Id_Expediente_FK,
               LTRIM(RTRIM(e.Nombres + ' ' + e.Apellidos)) AS Cliente,
               e.Documento, e.Id_TipoDocumento_fk, e.Celular, e.Telefono, e.Email, e.Direccion,
               f.Anticipo, f.MontoLibre, ISNULL(c.FechaInicio, CAST(c.Fecha AS datetime2)) AS CitaInicio
        FROM dbo.CAJ_FACTURAS AS f
            INNER JOIN dbo.EXP_EXPEDIENTES AS e ON e.Id_Expediente = f.Id_Expediente_FK
            LEFT JOIN dbo.EXP_CITAS AS c ON c.Id_Cita = f.Id_Cita_FK
        WHERE f.Id_factura = @factura;

    ELSE IF @accion = 2
        SELECT d.Id_detalle, d.Id_tratamiento_FK, d.Descripion AS Descripcion, d.Valor
        FROM dbo.CAJ_FACTURASDETALLES AS d
        WHERE d.Id_Factura_FK = @factura
        ORDER BY d.Id_detalle;

    ELSE IF @accion = 3
        SELECT TOP 1 * FROM dbo.FAC_DTE_PARAMETROS WHERE Estado = 1 ORDER BY Id_Parametro;

    ELSE IF @accion = 4
        SELECT TOP 1 Id_Dte, TipoDte, NumeroControl, CodigoGeneracion, RutaPdf, RutaJson, Estado, CorreoDestino, FechaCorreo, ReceptorNombre, TotalPagar
        FROM dbo.FAC_DTE_DOCUMENTOS
        WHERE Id_Factura_FK = @factura AND Estado <> 'A'
        ORDER BY Id_Dte DESC;

    ELSE IF @accion = 5
        SELECT Codigo, Descripcion FROM dbo.CAT_FORMASPAGO WHERE Estatus = 1 ORDER BY Codigo;
END
GO

/* Servicios de la factura
   @accion 1: catálogo de servicios activos | 2: agregar servicio | 3: quitar item */
CREATE OR ALTER PROCEDURE dbo.FAC_SP_DTE_SERVICIOS
     @factura     bigint
    ,@tratamiento bigint
    ,@detalle     bigint
    ,@usuario     varchar(20)
    ,@accion      int
AS
BEGIN
    SET NOCOUNT ON;

    IF @accion = 1
    BEGIN
        SELECT Id_Tratamientos AS Id, Descripcion, Precio, Duracion
        FROM dbo.CAT_TRATAMIENTOS
        WHERE IsActivo = 1
        ORDER BY Descripcion;
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.CAJ_FACTURAS WHERE Id_factura = @factura AND Estado = 0)
        THROW 50001, 'La factura no existe o ya fue pagada.', 1;
    IF EXISTS (SELECT 1 FROM dbo.CAJ_FACTURAS WHERE Id_factura = @factura AND MontoLibre = 1)
        THROW 50003, 'El pago adelantado sin cita es un monto libre: no se le agregan ni quitan servicios.', 1;

    IF @accion = 2
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM dbo.CAT_TRATAMIENTOS WHERE Id_Tratamientos = @tratamiento AND IsActivo = 1)
            THROW 50002, 'El servicio seleccionado no está disponible.', 1;

        INSERT INTO dbo.CAJ_FACTURASDETALLES (Id_Factura_FK, Id_tratamiento_FK, Descripion, Valor, UsuarioCrea, FechaCrea)
        SELECT @factura, Id_Tratamientos, Descripcion, Precio, @usuario, GETDATE()
        FROM dbo.CAT_TRATAMIENTOS
        WHERE Id_Tratamientos = @tratamiento;

        SELECT CAST(SCOPE_IDENTITY() AS bigint) AS Id_detalle;
    END
    ELSE IF @accion = 3
    BEGIN
        DELETE FROM dbo.CAJ_FACTURASDETALLES WHERE Id_detalle = @detalle AND Id_Factura_FK = @factura;
        SELECT @@ROWCOUNT AS Filas;
    END
END
GO

/* Receptores de Crédito Fiscal
   @accion 1: último receptor usado por el expediente (o por NIT) | 2: guardar (alta o actualización por NIT) */
CREATE OR ALTER PROCEDURE dbo.FAC_SP_DTE_RECEPTORES
     @expediente      bigint
    ,@nit             varchar(14)
    ,@nrc             varchar(8)
    ,@nombre          varchar(250)
    ,@nombreComercial varchar(150)
    ,@codActividad    varchar(6)
    ,@descActividad   varchar(150)
    ,@codDepartamento char(2)
    ,@codMunicipio    char(2)
    ,@complemento     varchar(200)
    ,@telefono        varchar(30)
    ,@correo          varchar(100)
    ,@usuario         varchar(20)
    ,@accion          int
    ,@codDistrito     char(2)      = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @accion = 1
    BEGIN
        SELECT TOP 1 r.*
        FROM dbo.FAC_DTE_RECEPTORES AS r
        WHERE r.Estado = 1
          AND ((@nit IS NOT NULL AND @nit <> '' AND r.NIT = @nit) OR r.Id_Expediente_FK = @expediente)
        ORDER BY CASE WHEN r.NIT = @nit THEN 0 ELSE 1 END, ISNULL(r.FechaModifica, r.FechaCrea) DESC;
    END
    ELSE IF @accion = 2
    BEGIN
        IF EXISTS (SELECT 1 FROM dbo.FAC_DTE_RECEPTORES WHERE NIT = @nit)
            UPDATE dbo.FAC_DTE_RECEPTORES
               SET Id_Expediente_FK = ISNULL(@expediente, Id_Expediente_FK),
                   NRC = @nrc, Nombre = @nombre, NombreComercial = @nombreComercial,
                   CodActividad = @codActividad, DescActividad = @descActividad,
                   CodDepartamento = @codDepartamento, CodMunicipio = @codMunicipio, CodDistrito = @codDistrito, Complemento = @complemento,
                   Telefono = @telefono, Correo = @correo, Estado = 1,
                   UsuarioModifica = @usuario, FechaModifica = GETDATE()
             WHERE NIT = @nit;
        ELSE
            INSERT INTO dbo.FAC_DTE_RECEPTORES (Id_Expediente_FK, NIT, NRC, Nombre, NombreComercial, CodActividad, DescActividad,
                                                CodDepartamento, CodMunicipio, CodDistrito, Complemento, Telefono, Correo, UsuarioCrea)
            VALUES (@expediente, @nit, @nrc, @nombre, @nombreComercial, @codActividad, @descActividad,
                    @codDepartamento, @codMunicipio, @codDistrito, @complemento, @telefono, @correo, @usuario);

        SELECT Id_Receptor FROM dbo.FAC_DTE_RECEPTORES WHERE NIT = @nit;
    END
END
GO

/* Reserva el siguiente número de control. Debe ejecutarse dentro de la transacción de emisión.
   Con sucursales (Opciones/sql/SUC_Sucursales.sql) se reemplaza por la versión con correlativo por sucursal:
   esta versión solo se crea en una base que todavía no tiene sucursales, para no deshacer aquella. */
IF COL_LENGTH('dbo.FAC_DTE_CORRELATIVOS', 'Id_Sucursal_FK') IS NULL
EXEC (N'CREATE OR ALTER PROCEDURE dbo.FAC_SP_DTE_CORRELATIVO
     @tipoDte char(2)
    ,@usuario varchar(20)
    ,@factura bigint = 0
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @anio int = YEAR(GETDATE()), @ultimo bigint, @estable char(4), @punto char(4);

    SELECT TOP 1 @estable = CodEstable, @punto = CodPuntoVenta
    FROM dbo.FAC_DTE_PARAMETROS WHERE Estado = 1 ORDER BY Id_Parametro;

    IF @estable IS NULL
        THROW 50010, ''No hay parámetros de facturación electrónica configurados (FAC_DTE_PARAMETROS).'', 1;

    UPDATE dbo.FAC_DTE_CORRELATIVOS WITH (UPDLOCK, HOLDLOCK)
       SET @ultimo = Ultimo = Ultimo + 1, UsuarioModifica = @usuario, FechaModifica = GETDATE()
     WHERE TipoDte = @tipoDte AND Anio = @anio;

    IF @ultimo IS NULL
    BEGIN
        SET @ultimo = 1;
        INSERT INTO dbo.FAC_DTE_CORRELATIVOS (TipoDte, Anio, Ultimo, UsuarioCrea) VALUES (@tipoDte, @anio, 1, @usuario);
    END

    SELECT ''DTE-'' + @tipoDte + ''-'' + @estable + @punto + ''-'' + RIGHT(REPLICATE(''0'', 15) + CAST(@ultimo AS varchar(15)), 15) AS NumeroControl,
           @ultimo AS Correlativo;
END');
GO

/* Registra el DTE emitido y marca la factura como pagada. Debe ejecutarse dentro de la transacción de emisión. */
CREATE OR ALTER PROCEDURE dbo.FAC_SP_DTE_GUARDAR
     @factura           bigint
    ,@tipoDte           char(2)
    ,@version           int
    ,@ambiente          char(2)
    ,@numeroControl     varchar(31)
    ,@codigoGeneracion  char(36)
    ,@fechaEmision      date
    ,@horaEmision       time(0)
    ,@receptor          bigint
    ,@receptorNombre    varchar(250)
    ,@receptorDocumento varchar(20)
    ,@totalGravado      decimal(12,2)
    ,@totalIva          decimal(12,2)
    ,@totalPagar        decimal(12,2)
    ,@totalLetras       varchar(250)
    ,@formaPago         char(2)
    ,@referenciaPago    varchar(50)
    ,@montoRecibido     decimal(12,2)
    ,@cambio            decimal(12,2)
    ,@json              nvarchar(max)
    ,@usuario           varchar(20)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @tipoFactura bigint = (SELECT TOP 1 Id_TipoFactura FROM dbo.CAT_TIPOSFACTURAS WHERE Codigo = @tipoDte);

    IF NOT EXISTS (SELECT 1 FROM dbo.CAJ_FACTURAS WITH (UPDLOCK, HOLDLOCK) WHERE Id_factura = @factura AND Estado = 0)
        THROW 50020, 'La factura ya fue pagada o no existe.', 1;

    INSERT INTO dbo.FAC_DTE_DOCUMENTOS (Id_Factura_FK, Id_TipoFactura_FK, TipoDte, VersionJson, Ambiente, NumeroControl, CodigoGeneracion,
                                        FechaEmision, HoraEmision, Id_Receptor_FK, ReceptorNombre, ReceptorDocumento,
                                        TotalGravado, TotalIva, TotalPagar, TotalLetras, FormaPago, ReferenciaPago,
                                        MontoRecibido, Cambio, JsonDte, UsuarioCrea)
    VALUES (@factura, @tipoFactura, @tipoDte, @version, @ambiente, @numeroControl, @codigoGeneracion,
            @fechaEmision, @horaEmision, @receptor, @receptorNombre, @receptorDocumento,
            @totalGravado, @totalIva, @totalPagar, @totalLetras, @formaPago, @referenciaPago,
            @montoRecibido, @cambio, @json, @usuario);

    DECLARE @id bigint = SCOPE_IDENTITY();

    UPDATE dbo.CAJ_FACTURAS
       SET Estado = 1,
           Cajero = @usuario,
           NumeroControl = @numeroControl,
           CodigoGeneracion = @codigoGeneracion,
           CondicionPago = 1,     -- contado
           ModeloFactura = 1,     -- previo
           TipoTransmision = 1,   -- normal
           FechaEmision = CAST(@fechaEmision AS datetime) + CAST(@horaEmision AS datetime),
           VersionJson = CAST(@version AS varchar(50)),
           UsuarioModifica = @usuario,
           FechaModifica = GETDATE()
     WHERE Id_factura = @factura;

    SELECT @id AS Id_Dte;
END
GO

/* Desglose de MontoDescu: el descuento del tratamiento (Catálogos › Tratamientos) y el del cupón.
   Los documentos anteriores a este cambio solo tenían descuentos de cupón. */
IF COL_LENGTH('dbo.FAC_DTE_DETALLES', 'DescuentoTratamiento') IS NULL
    ALTER TABLE dbo.FAC_DTE_DETALLES ADD DescuentoTratamiento decimal(12,2) NULL;
IF COL_LENGTH('dbo.FAC_DTE_DETALLES', 'DescuentoCupon') IS NULL
    ALTER TABLE dbo.FAC_DTE_DETALLES ADD DescuentoCupon decimal(12,2) NULL;
GO
UPDATE dbo.FAC_DTE_DETALLES SET DescuentoTratamiento = 0, DescuentoCupon = ISNULL(MontoDescu, 0)
WHERE DescuentoTratamiento IS NULL AND DescuentoCupon IS NULL;
GO

CREATE OR ALTER PROCEDURE dbo.FAC_SP_DTE_GUARDARDETALLE
     @dte          bigint
    ,@numItem      int
    ,@tratamiento  bigint
    ,@cantidad     decimal(12,2)
    ,@descripcion  varchar(1000)
    ,@precioUni    decimal(18,8)
    ,@montoDescu   decimal(12,2)
    ,@ventaGravada decimal(12,2)
    ,@ivaItem      decimal(12,2)
    ,@descuentoTratamiento decimal(12,2) = 0     -- parte de @montoDescu por el descuento del tratamiento
    ,@descuentoCupon       decimal(12,2) = 0     -- parte de @montoDescu por el cupón
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.FAC_DTE_DETALLES (Id_Dte_FK, NumItem, Id_Tratamiento_FK, Cantidad, Descripcion, PrecioUni, MontoDescu, VentaGravada, IvaItem, DescuentoTratamiento, DescuentoCupon)
    VALUES (@dte, @numItem, @tratamiento, @cantidad, @descripcion, @precioUni, @montoDescu, @ventaGravada, @ivaItem, ISNULL(@descuentoTratamiento, 0), ISNULL(@descuentoCupon, 0));
END
GO

/* Guarda las rutas de los archivos generados (PDF / JSON) */
CREATE OR ALTER PROCEDURE dbo.FAC_SP_DTE_ARCHIVOS
     @dte      bigint
    ,@rutaPdf  varchar(500)
    ,@rutaJson varchar(500)
    ,@usuario  varchar(20)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.FAC_DTE_DOCUMENTOS
       SET RutaPdf = @rutaPdf, RutaJson = @rutaJson, UsuarioModifica = @usuario, FechaModifica = GETDATE()
     WHERE Id_Dte = @dte;
END
GO

/* Registra el envío por correo del DTE (PDF + JSON) */
CREATE OR ALTER PROCEDURE dbo.FAC_SP_DTE_CORREO
     @dte      bigint
    ,@correo   varchar(100)
    ,@usuario  varchar(20)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.FAC_DTE_DOCUMENTOS
       SET CorreoDestino = @correo, FechaCorreo = GETDATE(), UsuarioModifica = @usuario, FechaModifica = GETDATE()
     WHERE Id_Dte = @dte;
END
GO

/* Datos de la empresa emisora (Facturacion/frm_EmpresaDte.aspx)
   @accion 1: consultar | 2: guardar datos (la clave solo cambia si se envía) | 3: guardar logo | 4: leer logo */
CREATE OR ALTER PROCEDURE dbo.FAC_SP_DTE_EMPRESA
     @accion              int
    ,@ambiente            char(2)       = NULL
    ,@nit                 varchar(14)   = NULL
    ,@nrc                 varchar(8)    = NULL
    ,@nombre              varchar(250)  = NULL
    ,@nombreComercial     varchar(150)  = NULL
    ,@codActividad        varchar(6)    = NULL
    ,@descActividad       varchar(150)  = NULL
    ,@tipoEstablecimiento char(2)       = NULL
    ,@codDepartamento     char(2)       = NULL
    ,@codMunicipio        char(2)       = NULL
    ,@complemento         varchar(200)  = NULL
    ,@telefono            varchar(30)   = NULL
    ,@correo              varchar(100)  = NULL
    ,@codEstableMH        char(4)       = NULL
    ,@codEstable          char(4)       = NULL
    ,@codPuntoVentaMH     char(4)       = NULL
    ,@codPuntoVenta       char(4)       = NULL
    ,@smtpServidor        varchar(150)  = NULL
    ,@smtpPuerto          int           = NULL
    ,@smtpUsuario         varchar(100)  = NULL
    ,@smtpClave           varchar(1000) = NULL
    ,@enviarCorreo        bit           = NULL
    ,@logo                varbinary(max) = NULL
    ,@logoTipo            varchar(30)   = NULL
    ,@usuario             varchar(20)   = NULL
    ,@codDistrito         char(2)       = NULL
    ,@versionFE           int           = NULL      -- 1 o 2 (DTE 2.0)
    ,@versionCCF          int           = NULL      -- 3 o 4 (DTE 2.0)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id int = (SELECT TOP 1 Id_Parametro FROM dbo.FAC_DTE_PARAMETROS WHERE Estado = 1 ORDER BY Id_Parametro);

    IF @accion = 1
        SELECT Id_Parametro, Ambiente, NIT, NRC, Nombre, NombreComercial, CodActividad, DescActividad, TipoEstablecimiento,
               CodDepartamento, CodMunicipio, CodDistrito, Complemento, Telefono, Correo, CodEstableMH, CodEstable, CodPuntoVentaMH, CodPuntoVenta,
               SmtpServidor, SmtpPuerto, SmtpUsuario, EnviarCorreo, VersionFE, VersionCCF,
               CAST(CASE WHEN SmtpClave IS NULL THEN 0 ELSE 1 END AS bit) AS TieneClave,
               CAST(CASE WHEN Logo IS NULL THEN 0 ELSE 1 END AS bit) AS TieneLogo,
               ISNULL(FechaModifica, FechaCrea) AS Version
        FROM dbo.FAC_DTE_PARAMETROS
        WHERE Id_Parametro = @id;

    ELSE IF @accion = 2
    BEGIN
        IF @id IS NULL
        BEGIN
            INSERT INTO dbo.FAC_DTE_PARAMETROS (Ambiente, NIT, NRC, Nombre, NombreComercial, CodActividad, DescActividad, TipoEstablecimiento,
                                                CodDepartamento, CodMunicipio, Complemento, Telefono, Correo, CodEstableMH, CodEstable,
                                                CodPuntoVentaMH, CodPuntoVenta, SmtpServidor, SmtpPuerto, SmtpUsuario, SmtpClave, EnviarCorreo,
                                                CodDistrito, VersionFE, VersionCCF, UsuarioCrea)
            VALUES (@ambiente, @nit, @nrc, @nombre, @nombreComercial, @codActividad, @descActividad, @tipoEstablecimiento,
                    @codDepartamento, @codMunicipio, @complemento, @telefono, @correo, @codEstableMH, @codEstable,
                    @codPuntoVentaMH, @codPuntoVenta, @smtpServidor, @smtpPuerto, @smtpUsuario, @smtpClave, ISNULL(@enviarCorreo, 0),
                    @codDistrito, ISNULL(@versionFE, 2), ISNULL(@versionCCF, 4), @usuario);
        END
        ELSE
            UPDATE dbo.FAC_DTE_PARAMETROS
               SET Ambiente = @ambiente, NIT = @nit, NRC = @nrc, Nombre = @nombre, NombreComercial = @nombreComercial,
                   CodActividad = @codActividad, DescActividad = @descActividad, TipoEstablecimiento = @tipoEstablecimiento,
                   CodDepartamento = @codDepartamento, CodMunicipio = @codMunicipio, Complemento = @complemento,
                   CodDistrito = @codDistrito, VersionFE = ISNULL(@versionFE, VersionFE), VersionCCF = ISNULL(@versionCCF, VersionCCF),
                   Telefono = @telefono, Correo = @correo, CodEstableMH = @codEstableMH, CodEstable = @codEstable,
                   CodPuntoVentaMH = @codPuntoVentaMH, CodPuntoVenta = @codPuntoVenta,
                   SmtpServidor = @smtpServidor, SmtpPuerto = @smtpPuerto, SmtpUsuario = @smtpUsuario,
                   SmtpClave = ISNULL(@smtpClave, SmtpClave), EnviarCorreo = ISNULL(@enviarCorreo, 0),
                   UsuarioModifica = @usuario, FechaModifica = GETDATE()
             WHERE Id_Parametro = @id;
    END

    ELSE IF @accion = 3
    BEGIN
        IF @id IS NULL
            THROW 50010, 'Guarde primero los datos de la empresa.', 1;
        UPDATE dbo.FAC_DTE_PARAMETROS
           SET Logo = @logo, LogoTipo = @logoTipo, UsuarioModifica = @usuario, FechaModifica = GETDATE()
         WHERE Id_Parametro = @id;
    END

    ELSE IF @accion = 4
        SELECT Logo, LogoTipo FROM dbo.FAC_DTE_PARAMETROS WHERE Id_Parametro = @id;
END
GO

/* ---------- Menú ----------
   La opción Facturación > Datos DTE ya no se crea: los datos del DTE se administran en Opciones > Empresa
   (ver FAC_DTE_Firmador.sql, que además quita la opción si existe). */
