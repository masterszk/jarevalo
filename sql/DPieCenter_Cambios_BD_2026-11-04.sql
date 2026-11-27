/* =====================================================================
   DPieCenter - Script consolidado de cambios a la base de datos
   Generado: 26/11/2026 03:39 PM

   Ejecutar completo en SQL Server Management Studio, conectado a la base de la aplicación
   (no incluye USE: seleccione la base antes de ejecutar). Haga un respaldo antes.
   Todos los scripts son idempotentes: se puede ejecutar varias veces sin duplicar datos.

   Contenido (en este orden):
    1. Facturacion\sql\FAC_DTE_Estructura.sql             Facturación electrónica: tablas y SPs base de los DTE
    2. Facturacion\sql\FAC_DTE_Pagos.sql                  Pago combinado: varias formas de pago por DTE
    3. Catalogos\sql\CAT_Tratamientos_Descuento.sql       Tratamientos: descuento en %
    4. Opciones\sql\SUC_Sucursales.sql                    Sucursales: estructuras, Casa Matriz y datos actuales
    5. Registros\sql\EXP_Citas_Horarios.sql               Citas: FechaInicio/FechaFin según Fecha y CAT_HORARIOS
    6. Registros\sql\EXP_Citas_ProcedimientoEnCurso.sql   Citas: procedimiento en curso
    7. Facturacion\sql\CAJ_Anticipos.sql                  Cobro por adelantado, saldo a favor y pago adelantado sin cita
    8. Registros\sql\EXP_Procedimientos_Atencion.sql      Procedimientos: atención (incluye acción 14, lista en curso)
    9. Registros\sql\EXP_Procedimientos_Cierre.sql        Cierre de procesos abiertos de meses anteriores
   10. Registros\sql\EXP_Reclamos.sql                     Reclamos: estructura con procedimiento y SP
   11. Registros\sql\EXP_Agenda.sql                       Agenda y calendario: catálogos, detalle, edición y búsqueda de pacientes
   12. Registros\sql\CAT_Paises.sql                       Paises: nacionalidad y formato de telefono y documento
   13. Registros\sql\EXP_Expedientes_Lista.sql            Expedientes: lista
   14. Registros\sql\EXP_Expediente_Detalle.sql           Expedientes: detalle
   15. Reportes\sql\REP_Reportes.sql                      Reportes de citas, procedimientos y expedientes
   16. Reportes\sql\REP_Garantias.sql                     Reporte de Garantía de Servicios
   17. Reportes\sql\REP_CajaEspecialistas.sql             Reporte de caja por especialista
   18. Opciones\sql\SYS_Administracion.sql                Módulo Opciones (módulos, opciones, perfiles, usuarios, dashboards, empresa)
   19. Opciones\sql\SYS_Login_Legado.sql                  Procedimientos del login anterior
   20. Catalogos\sql\CAT_Catalogos.sql                    Módulo Catálogos (incluye tipos de factura CAT-002)
   21. Registros\sql\REG_Inbound.sql                      Registros > Inbound
   22. Dashboard\sql\REP_Dashboard_Usuarios.sql           Dashboard de usuarios
   23. Registros\sql\CUP_Cupones.sql                      Cupones con QR y descuento en caja
   24. Facturacion\sql\CAJ_Caja_Anulaciones.sql           Caja diaria, salidas de efectivo y anulaciones de DTE
   25. Facturacion\sql\CAJ_Tickets.sql                    Ticket POS para servicios sin costo
   26. Facturacion\sql\FAC_DTE_Diagnostico.sql            Diagnóstico DTE y bitácora de eventos
   27. Facturacion\sql\FAC_DTE_Firmador.sql               Generador de firma de Hacienda (quita menú Datos DTE)
   28. Reportes\sql\REP_Dashboard_Caja.sql                Dashboard general y reporte de caja
   29. Facturacion\sql\FAC_Procedimientos_Curso.sql       Menú Facturación > Procedimientos (en curso)
   30. Registros\sql\EXP_Citas_Agendadas.sql              Calendario de citas: nombre del paciente
   31. Opciones\sql\SYS_Recuperar_Clave.sql               Recuperar contraseña desde el login (código de 6 dígitos)
   32. Registros\sql\SYS_Menu_Citas.sql                   Menú Registros > Citas abre el calendario
   33. Opciones\sql\SYS_Menu_Publicidad.sql               Menú Opciones > Videos de turnos
   34. Registros\sql\SYS_Menu_Turnos.sql                  Menú Registros > Pantalla de turnos
   35. Registros\sql\MET_Metas.sql                        Metas de ventas y esquema de bono (Registros > Metas)
   ===================================================================== */
SET NOCOUNT ON;
GO
IF OBJECT_ID('dbo.CAJ_FACTURAS', 'U') IS NULL OR OBJECT_ID('dbo.Sys_Opciones', 'U') IS NULL OR OBJECT_ID('dbo.EXP_EXPEDIENTES', 'U') IS NULL
    THROW 50000, 'Esta no es la base de DPieCenter: seleccione la base correcta antes de ejecutar.', 1;
GO

/* #####################################################################
   1/35  Facturacion\sql\FAC_DTE_Estructura.sql
   ##################################################################### */
PRINT N'>> 1/35 Facturacion\sql\FAC_DTE_Estructura.sql';
GO
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
GO

/* #####################################################################
   2/35  Facturacion\sql\FAC_DTE_Pagos.sql
   ##################################################################### */
PRINT N'>> 2/35 Facturacion\sql\FAC_DTE_Pagos.sql';
GO
/* =====================================================================
   DPieCenter - Pago combinado: varias formas de pago en un mismo DTE (Facturacion/frm_OpenFactura.aspx)

   FAC_DTE_PAGOS: una fila por forma de pago del documento con el monto APLICADO al total
                  (en efectivo, lo recibido menos el cambio). La suma de las filas = TotalPagar.
                  FAC_DTE_DOCUMENTOS.FormaPago sigue guardando la forma principal (la de mayor monto).
   FAC_VW_DTE_PAGOS: pagos de cada documento; los emitidos antes del pago combinado (sin filas en
                  FAC_DTE_PAGOS) salen con su única forma de pago y el total, así los reportes no cambian.
   FAC_FN_EfectivoCajero: efectivo cobrado por un cajero en un día (DTE vigentes) para el arqueo.
   FAC_FN_FormasPagoTexto: "Billetes y monedas" o "Tarjeta Crédito $15.00 + Billetes y monedas $8.90".
   FAC_SP_DTE_GUARDARPAGO: guarda una línea de pago (dentro de la transacción de la emisión).
   Requiere FAC_DTE_Estructura.sql. Script idempotente: se puede ejecutar varias veces.
   ===================================================================== */
SET NOCOUNT ON;
GO

IF OBJECT_ID('dbo.FAC_DTE_PAGOS', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.FAC_DTE_PAGOS (
        Id_Pago     bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_FAC_DTE_PAGOS PRIMARY KEY,
        Id_Dte_FK   bigint        NOT NULL CONSTRAINT FK_FAC_DTE_PAGOS_Dte REFERENCES dbo.FAC_DTE_DOCUMENTOS (Id_Dte),
        FormaPago   char(2)       NOT NULL,          -- CAT-017
        Monto       decimal(12,2) NOT NULL,          -- aplicado al total (efectivo: recibido - cambio)
        Recibido    decimal(12,2) NULL,              -- solo efectivo: lo que entregó el cliente
        Referencia  varchar(50)   NULL,
        UsuarioCrea varchar(20)   NOT NULL,
        FechaCrea   datetime      NOT NULL CONSTRAINT DF_FAC_DTE_PAGOS_Fecha DEFAULT (GETDATE())
    );
    CREATE INDEX IX_FAC_DTE_PAGOS_Dte ON dbo.FAC_DTE_PAGOS (Id_Dte_FK) INCLUDE (FormaPago, Monto);
END
GO

CREATE OR ALTER VIEW dbo.FAC_VW_DTE_PAGOS
AS
    select p.Id_Dte_FK as Id_Dte, p.FormaPago, p.Monto, p.Referencia
    from dbo.FAC_DTE_PAGOS as p
    union all
    -- documentos emitidos con una sola forma de pago (antes del pago combinado)
    select d.Id_Dte, d.FormaPago, ISNULL(d.TotalPagar, 0), d.ReferenciaPago
    from dbo.FAC_DTE_DOCUMENTOS as d
    where not exists (select 1 from dbo.FAC_DTE_PAGOS as x where x.Id_Dte_FK = d.Id_Dte);
GO

CREATE OR ALTER FUNCTION dbo.FAC_FN_EfectivoCajero (@cajero varchar(20), @fecha date)
RETURNS decimal(12,2)
AS
BEGIN
    RETURN ISNULL((select SUM(p.Monto)
                   from dbo.FAC_DTE_DOCUMENTOS as d
                       inner join dbo.FAC_VW_DTE_PAGOS as p on p.Id_Dte = d.Id_Dte and p.FormaPago = '01'
                   where d.UsuarioCrea = @cajero and d.FechaEmision = @fecha and d.Estado <> 'A'), 0);
END
GO

CREATE OR ALTER FUNCTION dbo.FAC_FN_FormasPagoTexto (@dte bigint)
RETURNS varchar(400)
AS
BEGIN
    declare @n int = (select COUNT(*) from dbo.FAC_VW_DTE_PAGOS where Id_Dte = @dte)
    if @n <= 1
        RETURN (select top 1 ISNULL(fp.Descripcion, p.FormaPago)
                from dbo.FAC_VW_DTE_PAGOS as p left join dbo.CAT_FORMASPAGO as fp on fp.Codigo = p.FormaPago
                where p.Id_Dte = @dte);
    RETURN STUFF((select ' + ' + ISNULL(fp.Descripcion, p.FormaPago) + ' $' + CONVERT(varchar(20), CAST(p.Monto as money), 1)
                  from dbo.FAC_VW_DTE_PAGOS as p left join dbo.CAT_FORMASPAGO as fp on fp.Codigo = p.FormaPago
                  where p.Id_Dte = @dte
                  order by p.Monto desc, p.FormaPago
                  for xml path(''), type).value('.', 'varchar(400)'), 1, 3, '');
END
GO

CREATE OR ALTER PROCEDURE dbo.FAC_SP_DTE_GUARDARPAGO
     @dte        bigint
    ,@formaPago  char(2)
    ,@monto      decimal(12,2)
    ,@recibido   decimal(12,2) = NULL
    ,@referencia varchar(50) = NULL
    ,@usuario    varchar(20)
AS
BEGIN
    SET NOCOUNT ON;
    if not exists (select 1 from dbo.CAT_FORMASPAGO where Codigo = @formaPago)
        THROW 50460, 'La forma de pago no es válida.', 1;
    if @monto <= 0
        THROW 50461, 'Cada forma de pago debe tener un monto mayor a cero.', 1;
    insert into dbo.FAC_DTE_PAGOS (Id_Dte_FK, FormaPago, Monto, Recibido, Referencia, UsuarioCrea)
    values (@dte, @formaPago, @monto, @recibido, NULLIF(LTRIM(RTRIM(@referencia)), ''), @usuario);
END
GO

/* #####################################################################
   3/35  Catalogos\sql\CAT_Tratamientos_Descuento.sql
   ##################################################################### */
PRINT N'>> 3/35 Catalogos\sql\CAT_Tratamientos_Descuento.sql';
GO
/* =====================================================================
   DPieCenter - Descuento en % por tratamiento (Catálogos › Tratamientos)

   CAT_TRATAMIENTOS.Descuento: 0 = sin descuento. Se aplica al cobrar (Facturacion/DescuentosTratamiento.cs):
   en la factura va en valores (montoDescu de la línea y totalDescu) y las pantallas de citas, procedimientos
   y caja muestran el precio con descuento. Debe ejecutarse antes que los SP que leen la columna
   (EXP_Agenda, EXP_Procedimientos_Atencion, CAJ_Caja_Anulaciones, CAT_Catalogos).
   Script idempotente: se puede ejecutar varias veces.
   ===================================================================== */
SET NOCOUNT ON;
GO

IF COL_LENGTH('dbo.CAT_TRATAMIENTOS', 'Descuento') IS NULL
	ALTER TABLE dbo.CAT_TRATAMIENTOS ADD Descuento decimal(5,2) NOT NULL CONSTRAINT DF_CAT_TRATAMIENTOS_Descuento DEFAULT (0);
GO

/* #####################################################################
   4/35  Opciones\sql\SUC_Sucursales.sql
   ##################################################################### */
PRINT N'>> 4/35 Opciones\sql\SUC_Sucursales.sql';
GO
/* =====================================================================
   DPieCenter - Sucursales

   Estructuras:
     CAT_SUCURSALES                 sucursales; la Casa Matriz (EsMatriz = 1) se crea con los datos del emisor DTE
     CAT_ESPECIALISTAS_SUCURSALES   en qué sucursales atiende cada especialista
     Id_Sucursal_FK en              Sys_Usuarios (sucursal fija del usuario), EXP_EXPEDIENTES (sucursal donde se registró;
                                    los pacientes se comparten), EXP_CITAS, EXP_PROCEDIMIENTOS, CAJ_FACTURAS,
                                    CAJ_APETURTACAJA, FAC_DTE_DOCUMENTOS, REG_INBOUND y FAC_DTE_CORRELATIVOS (por sucursal)
   Todos los datos existentes quedan en Casa Matriz (valor por defecto de la columna).
   Herencia (triggers): el procedimiento toma la sucursal de su cita; la factura, la de su procedimiento;
   el DTE, la de su factura. Así las pantallas solo indican la sucursal al crear la cita y al abrir la caja.
   Script idempotente.
   ===================================================================== */
SET NOCOUNT ON;
GO

IF OBJECT_ID('dbo.CAT_SUCURSALES', 'U') IS NULL
BEGIN
	CREATE TABLE dbo.CAT_SUCURSALES (
		 Id_Sucursal      int IDENTITY(1,1) NOT NULL CONSTRAINT PK_CAT_SUCURSALES PRIMARY KEY
		,Codigo           varchar(10)   NOT NULL
		,Nombre           varchar(100)  NOT NULL
		,EsMatriz         bit           NOT NULL CONSTRAINT DF_CAT_SUCURSALES_Matriz DEFAULT (0)
		,Direccion        varchar(250)  NULL
		,Telefono         varchar(20)   NULL
		,CodDepartamento  char(2)       NULL      -- dirección del establecimiento para el DTE
		,CodMunicipio     char(2)       NULL
		,CodDistrito      char(2)       NULL
		,CodEstableMH     char(4)       NULL      -- código asignado por Hacienda al establecimiento
		,CodEstable       char(4)       NOT NULL  -- código interno del establecimiento (número de control)
		,CodPuntoVentaMH  char(4)       NULL
		,CodPuntoVenta    char(4)       NOT NULL
		,IsActivo         bit           NOT NULL CONSTRAINT DF_CAT_SUCURSALES_Activo DEFAULT (1)
		,UsuarioCrea      varchar(20)   NOT NULL
		,FechaCrea        datetime      NOT NULL CONSTRAINT DF_CAT_SUCURSALES_FC DEFAULT (GETDATE())
		,UsuarioModifica  varchar(20)   NULL
		,FechaModifica    datetime      NULL
		,CONSTRAINT UX_CAT_SUCURSALES_Codigo UNIQUE (Codigo)
		,CONSTRAINT UX_CAT_SUCURSALES_Estable UNIQUE (CodEstable, CodPuntoVenta)
	);
	-- solo una Casa Matriz
	CREATE UNIQUE INDEX UX_CAT_SUCURSALES_Matriz ON dbo.CAT_SUCURSALES (EsMatriz) WHERE EsMatriz = 1;
END
GO

-- Casa Matriz con los datos del emisor de los DTE
IF NOT EXISTS (SELECT 1 FROM dbo.CAT_SUCURSALES WHERE EsMatriz = 1)
	INSERT INTO dbo.CAT_SUCURSALES (Codigo, Nombre, EsMatriz, Direccion, Telefono, CodDepartamento, CodMunicipio, CodDistrito,
	                                CodEstableMH, CodEstable, CodPuntoVentaMH, CodPuntoVenta, UsuarioCrea)
	SELECT TOP 1 'MATRIZ', 'Casa Matriz', 1, p.Complemento, p.Telefono, p.CodDepartamento, p.CodMunicipio, p.CodDistrito,
	       p.CodEstableMH, ISNULL(p.CodEstable, 'M001'), p.CodPuntoVentaMH, ISNULL(p.CodPuntoVenta, 'P001'), 'admin'
	FROM (SELECT 1 AS x) AS uno
		LEFT JOIN dbo.FAC_DTE_PARAMETROS AS p ON p.Estado = 1
	ORDER BY p.Id_Parametro;
GO

/* Id de la Casa Matriz: valor por defecto de todas las columnas Id_Sucursal_FK.
   Se crea una sola vez: los DEFAULT que la usan impiden modificarla después. */
IF OBJECT_ID('dbo.SUC_FN_Matriz', 'FN') IS NULL
	EXEC (N'CREATE FUNCTION dbo.SUC_FN_Matriz()
RETURNS int
AS
BEGIN
	RETURN (SELECT TOP 1 Id_Sucursal FROM dbo.CAT_SUCURSALES WHERE EsMatriz = 1);
END');
GO

/* Columna Id_Sucursal_FK (NOT NULL, por defecto Casa Matriz, con FK e índice) en cada tabla */
DECLARE @tablas TABLE (Tabla sysname, Indice nvarchar(200));
INSERT @tablas VALUES
	 ('Sys_Usuarios', NULL)
	,('EXP_EXPEDIENTES', NULL)
	,('EXP_CITAS', N'(Id_Sucursal_FK, Fecha)')
	,('EXP_PROCEDIMIENTOS', N'(Id_Sucursal_FK, Fecha)')
	,('CAJ_FACTURAS', N'(Id_Sucursal_FK, Estado)')
	,('CAJ_APETURTACAJA', N'(Id_Sucursal_FK, FechaApertura)')
	,('FAC_DTE_DOCUMENTOS', N'(Id_Sucursal_FK, FechaEmision)')
	,('REG_INBOUND', N'(Id_Sucursal_FK, FechaCrea)');
DECLARE @t sysname, @ix nvarchar(200), @q nvarchar(max);
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT Tabla, Indice FROM @tablas;
OPEN c; FETCH NEXT FROM c INTO @t, @ix;
WHILE @@FETCH_STATUS = 0
BEGIN
	IF OBJECT_ID('dbo.' + @t, 'U') IS NOT NULL AND COL_LENGTH('dbo.' + @t, 'Id_Sucursal_FK') IS NULL
	BEGIN
		SET @q = N'ALTER TABLE dbo.' + QUOTENAME(@t) + N' ADD Id_Sucursal_FK int NOT NULL CONSTRAINT ' + QUOTENAME('DF_' + @t + '_Sucursal')
		       + N' DEFAULT (dbo.SUC_FN_Matriz()) WITH VALUES;';
		EXEC sys.sp_executesql @q;
		SET @q = N'ALTER TABLE dbo.' + QUOTENAME(@t) + N' WITH CHECK ADD CONSTRAINT ' + QUOTENAME('FK_' + @t + '_Sucursal')
		       + N' FOREIGN KEY (Id_Sucursal_FK) REFERENCES dbo.CAT_SUCURSALES (Id_Sucursal);';
		EXEC sys.sp_executesql @q;
		IF @ix IS NOT NULL
		BEGIN
			SET @q = N'CREATE INDEX ' + QUOTENAME('IX_' + @t + '_Sucursal') + N' ON dbo.' + QUOTENAME(@t) + N' ' + @ix + N';';
			EXEC sys.sp_executesql @q;
		END
	END
	FETCH NEXT FROM c INTO @t, @ix;
END
CLOSE c; DEALLOCATE c;
GO

/* Correlativos de los DTE por sucursal (el número de control lleva el establecimiento y punto de venta de la sucursal) */
IF COL_LENGTH('dbo.FAC_DTE_CORRELATIVOS', 'Id_Sucursal_FK') IS NULL
BEGIN
	ALTER TABLE dbo.FAC_DTE_CORRELATIVOS ADD Id_Sucursal_FK int NOT NULL
		CONSTRAINT DF_FAC_DTE_CORRELATIVOS_Sucursal DEFAULT (dbo.SUC_FN_Matriz()) WITH VALUES;
	ALTER TABLE dbo.FAC_DTE_CORRELATIVOS DROP CONSTRAINT PK_FAC_DTE_CORRELATIVOS;
	ALTER TABLE dbo.FAC_DTE_CORRELATIVOS ADD CONSTRAINT PK_FAC_DTE_CORRELATIVOS PRIMARY KEY (Id_Sucursal_FK, TipoDte, Anio);
	ALTER TABLE dbo.FAC_DTE_CORRELATIVOS WITH CHECK ADD CONSTRAINT FK_FAC_DTE_CORRELATIVOS_Sucursal
		FOREIGN KEY (Id_Sucursal_FK) REFERENCES dbo.CAT_SUCURSALES (Id_Sucursal);
END
GO

/* Número de control por sucursal: correlativo propio y su establecimiento / punto de venta.
   La Casa Matriz usa los códigos de Opciones > Empresa > Facturación electrónica (FAC_DTE_PARAMETROS). */
CREATE OR ALTER PROCEDURE dbo.FAC_SP_DTE_CORRELATIVO
     @tipoDte char(2)
    ,@usuario varchar(20)
    ,@factura bigint = 0       -- la sucursal se toma de la factura (0 = Casa Matriz)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @anio int = YEAR(GETDATE()), @ultimo bigint, @estable char(4), @punto char(4), @matriz bit;
    DECLARE @sucursal int = ISNULL((SELECT Id_Sucursal_FK FROM dbo.CAJ_FACTURAS WHERE Id_factura = @factura), dbo.SUC_FN_Matriz());

    SELECT @estable = CodEstable, @punto = CodPuntoVenta, @matriz = EsMatriz FROM dbo.CAT_SUCURSALES WHERE Id_Sucursal = @sucursal;
    IF @matriz = 1 OR @estable IS NULL
        SELECT TOP 1 @estable = CodEstable, @punto = CodPuntoVenta
        FROM dbo.FAC_DTE_PARAMETROS WHERE Estado = 1 ORDER BY Id_Parametro;

    IF @estable IS NULL
        THROW 50010, 'No hay parámetros de facturación electrónica configurados (FAC_DTE_PARAMETROS).', 1;

    UPDATE dbo.FAC_DTE_CORRELATIVOS WITH (UPDLOCK, HOLDLOCK)
       SET @ultimo = Ultimo = Ultimo + 1, UsuarioModifica = @usuario, FechaModifica = GETDATE()
     WHERE Id_Sucursal_FK = @sucursal AND TipoDte = @tipoDte AND Anio = @anio;

    IF @ultimo IS NULL
    BEGIN
        SET @ultimo = 1;
        INSERT INTO dbo.FAC_DTE_CORRELATIVOS (Id_Sucursal_FK, TipoDte, Anio, Ultimo, UsuarioCrea) VALUES (@sucursal, @tipoDte, @anio, 1, @usuario);
    END

    SELECT 'DTE-' + @tipoDte + '-' + @estable + @punto + '-' + RIGHT(REPLICATE('0', 15) + CAST(@ultimo AS varchar(15)), 15) AS NumeroControl,
           @ultimo AS Correlativo;
END
GO

/* Especialistas por sucursal; los existentes quedan en Casa Matriz */
IF OBJECT_ID('dbo.CAT_ESPECIALISTAS_SUCURSALES', 'U') IS NULL
BEGIN
	CREATE TABLE dbo.CAT_ESPECIALISTAS_SUCURSALES (
		 Id_Especialista_FK bigint      NOT NULL CONSTRAINT FK_CAT_ESP_SUC_Esp REFERENCES dbo.CAT_ESPECIALISTAS (Id_Especialista)
		,Id_Sucursal_FK     int         NOT NULL CONSTRAINT FK_CAT_ESP_SUC_Suc REFERENCES dbo.CAT_SUCURSALES (Id_Sucursal)
		,UsuarioCrea        varchar(20) NOT NULL
		,FechaCrea          datetime    NOT NULL CONSTRAINT DF_CAT_ESP_SUC_FC DEFAULT (GETDATE())
		,CONSTRAINT PK_CAT_ESPECIALISTAS_SUCURSALES PRIMARY KEY (Id_Especialista_FK, Id_Sucursal_FK)
	);
	INSERT INTO dbo.CAT_ESPECIALISTAS_SUCURSALES (Id_Especialista_FK, Id_Sucursal_FK, UsuarioCrea)
	SELECT Id_Especialista, dbo.SUC_FN_Matriz(), 'admin' FROM dbo.CAT_ESPECIALISTAS;
END
GO

/* Especialista nuevo (desde el catálogo): queda en Casa Matriz hasta que se asigne en Opciones > Sucursales */
CREATE OR ALTER TRIGGER dbo.TR_CAT_ESPECIALISTAS_Sucursal
ON dbo.CAT_ESPECIALISTAS
AFTER INSERT
AS
BEGIN
	SET NOCOUNT ON;
	INSERT INTO dbo.CAT_ESPECIALISTAS_SUCURSALES (Id_Especialista_FK, Id_Sucursal_FK, UsuarioCrea)
	SELECT i.Id_Especialista, dbo.SUC_FN_Matriz(), 'sistema'
	FROM inserted AS i
	WHERE NOT EXISTS (SELECT 1 FROM dbo.CAT_ESPECIALISTAS_SUCURSALES AS x WHERE x.Id_Especialista_FK = i.Id_Especialista);
END
GO

/* ---------- herencia de la sucursal ---------- */
CREATE OR ALTER TRIGGER dbo.TR_EXP_PROCEDIMIENTOS_Sucursal
ON dbo.EXP_PROCEDIMIENTOS
AFTER INSERT
AS
BEGIN
	SET NOCOUNT ON;
	UPDATE p SET Id_Sucursal_FK = c.Id_Sucursal_FK
	FROM dbo.EXP_PROCEDIMIENTOS AS p
		INNER JOIN inserted AS i ON i.Id_Procedimiento = p.Id_Procedimiento
		INNER JOIN dbo.EXP_CITAS AS c ON c.Id_Cita = p.Id_Cita_FK
	WHERE p.Id_Sucursal_FK <> c.Id_Sucursal_FK;
END
GO

CREATE OR ALTER TRIGGER dbo.TR_CAJ_FACTURAS_Sucursal
ON dbo.CAJ_FACTURAS
AFTER INSERT
AS
BEGIN
	SET NOCOUNT ON;
	UPDATE f SET Id_Sucursal_FK = p.Id_Sucursal_FK
	FROM dbo.CAJ_FACTURAS AS f
		INNER JOIN inserted AS i ON i.Id_factura = f.Id_factura
		INNER JOIN dbo.EXP_PROCEDIMIENTOS AS p ON p.Id_Procedimiento = f.Id_Procedimiento_FK
	WHERE f.Id_Sucursal_FK <> p.Id_Sucursal_FK;
END
GO

CREATE OR ALTER TRIGGER dbo.TR_FAC_DTE_DOCUMENTOS_Sucursal
ON dbo.FAC_DTE_DOCUMENTOS
AFTER INSERT
AS
BEGIN
	SET NOCOUNT ON;
	UPDATE d SET Id_Sucursal_FK = f.Id_Sucursal_FK
	FROM dbo.FAC_DTE_DOCUMENTOS AS d
		INNER JOIN inserted AS i ON i.Id_Dte = d.Id_Dte
		INNER JOIN dbo.CAJ_FACTURAS AS f ON f.Id_factura = d.Id_Factura_FK
	WHERE d.Id_Sucursal_FK <> f.Id_Sucursal_FK;
END
GO

/* Datos históricos: procedimientos, facturas y DTE con la sucursal de su cita (hoy todo es Casa Matriz) */
UPDATE p SET Id_Sucursal_FK = c.Id_Sucursal_FK
FROM dbo.EXP_PROCEDIMIENTOS AS p INNER JOIN dbo.EXP_CITAS AS c ON c.Id_Cita = p.Id_Cita_FK
WHERE p.Id_Sucursal_FK <> c.Id_Sucursal_FK;
UPDATE f SET Id_Sucursal_FK = p.Id_Sucursal_FK
FROM dbo.CAJ_FACTURAS AS f INNER JOIN dbo.EXP_PROCEDIMIENTOS AS p ON p.Id_Procedimiento = f.Id_Procedimiento_FK
WHERE f.Id_Sucursal_FK <> p.Id_Sucursal_FK;
UPDATE d SET Id_Sucursal_FK = f.Id_Sucursal_FK
FROM dbo.FAC_DTE_DOCUMENTOS AS d INNER JOIN dbo.CAJ_FACTURAS AS f ON f.Id_factura = d.Id_Factura_FK
WHERE d.Id_Sucursal_FK <> f.Id_Sucursal_FK;
GO

/* ---------- administración (Opciones > Sucursales) ----------
   @accion 1 lista | 2 una (con sus especialistas) | 3 guardar | 4 activar/inactivar | 5 asignar especialistas (@especialistas = '1,5,8')
          6 sucursales activas (para listas) | 7 sucursal de un usuario */
CREATE OR ALTER PROCEDURE dbo.SUC_SP_Sucursales
	 @accion          int
	,@id              int           = 0
	,@codigo          varchar(10)   = NULL
	,@nombre          varchar(100)  = NULL
	,@direccion       varchar(250)  = NULL
	,@telefono        varchar(20)   = NULL
	,@codDepartamento char(2)       = NULL
	,@codMunicipio    char(2)       = NULL
	,@codDistrito     char(2)       = NULL
	,@codEstableMH    char(4)       = NULL
	,@codEstable      char(4)       = NULL
	,@codPuntoVentaMH char(4)       = NULL
	,@codPuntoVenta   char(4)       = NULL
	,@activo          bit           = 1
	,@especialistas   varchar(max)  = NULL
	,@usuarioId       varchar(20)   = NULL
	,@usuario         varchar(20)   = NULL
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	SET @codigo = UPPER(NULLIF(LTRIM(RTRIM(@codigo)), ''));
	SET @nombre = NULLIF(LTRIM(RTRIM(@nombre)), '');
	SET @codEstable = UPPER(NULLIF(LTRIM(RTRIM(@codEstable)), ''));
	SET @codPuntoVenta = UPPER(NULLIF(LTRIM(RTRIM(@codPuntoVenta)), ''));
	SET @codEstableMH = UPPER(NULLIF(LTRIM(RTRIM(@codEstableMH)), ''));
	SET @codPuntoVentaMH = UPPER(NULLIF(LTRIM(RTRIM(@codPuntoVentaMH)), ''));

	IF @accion = 1
	BEGIN
		SELECT s.Id_Sucursal, s.Codigo, s.Nombre, s.EsMatriz, s.Direccion, s.Telefono, s.CodDepartamento, s.CodMunicipio, s.CodDistrito,
		       s.CodEstableMH, s.CodEstable, s.CodPuntoVentaMH, s.CodPuntoVenta, s.IsActivo,
		       (SELECT COUNT(*) FROM dbo.Sys_Usuarios AS u WHERE u.Id_Sucursal_FK = s.Id_Sucursal) AS Usuarios,
		       (SELECT COUNT(*) FROM dbo.CAT_ESPECIALISTAS_SUCURSALES AS e WHERE e.Id_Sucursal_FK = s.Id_Sucursal) AS Especialistas,
		       (SELECT COUNT(*) FROM dbo.EXP_CITAS AS c WHERE c.Id_Sucursal_FK = s.Id_Sucursal) AS Citas,
		       ISNULL(s.UsuarioModifica, s.UsuarioCrea) AS Usuario, ISNULL(s.FechaModifica, s.FechaCrea) AS Fecha
		FROM dbo.CAT_SUCURSALES AS s
		ORDER BY s.EsMatriz DESC, s.Nombre;
		RETURN;
	END

	IF @accion = 2
	BEGIN
		SELECT e.Id_Especialista AS Id, LTRIM(RTRIM(e.Descripcion)) AS Nombre, CAST(ISNULL(e.IsActivo, 1) AS bit) AS Activo,
		       CAST(CASE WHEN x.Id_Sucursal_FK IS NULL THEN 0 ELSE 1 END AS bit) AS Asignado
		FROM dbo.CAT_ESPECIALISTAS AS e
			LEFT JOIN dbo.CAT_ESPECIALISTAS_SUCURSALES AS x ON x.Id_Especialista_FK = e.Id_Especialista AND x.Id_Sucursal_FK = @id
		ORDER BY e.Descripcion;
		RETURN;
	END

	IF @accion = 3
	BEGIN
		IF @codigo IS NULL THROW 50300, 'Ingrese el código de la sucursal.', 1;
		IF @nombre IS NULL THROW 50301, 'Ingrese el nombre de la sucursal.', 1;
		IF @codEstable IS NULL OR LEN(@codEstable) <> 4 THROW 50302, 'El código de establecimiento debe tener 4 caracteres (ej. S001).', 1;
		IF @codPuntoVenta IS NULL OR LEN(@codPuntoVenta) <> 4 THROW 50303, 'El código de punto de venta debe tener 4 caracteres (ej. P001).', 1;
		IF @codEstableMH IS NOT NULL AND LEN(@codEstableMH) <> 4 THROW 50304, 'El código de establecimiento MH debe tener 4 caracteres.', 1;
		IF @codPuntoVentaMH IS NOT NULL AND LEN(@codPuntoVentaMH) <> 4 THROW 50305, 'El código de punto de venta MH debe tener 4 caracteres.', 1;
		IF EXISTS (SELECT 1 FROM dbo.CAT_SUCURSALES WHERE Codigo = @codigo AND Id_Sucursal <> @id) THROW 50306, 'Ya existe una sucursal con ese código.', 1;
		IF EXISTS (SELECT 1 FROM dbo.CAT_SUCURSALES WHERE CodEstable = @codEstable AND CodPuntoVenta = @codPuntoVenta AND Id_Sucursal <> @id)
			THROW 50307, 'Otra sucursal ya usa ese establecimiento y punto de venta: el número de control se repetiría.', 1;
		IF @id > 0 AND @activo = 0 AND EXISTS (SELECT 1 FROM dbo.CAT_SUCURSALES WHERE Id_Sucursal = @id AND EsMatriz = 1)
			THROW 50308, 'La Casa Matriz no se puede inactivar.', 1;

		IF @id = 0
		BEGIN
			INSERT INTO dbo.CAT_SUCURSALES (Codigo, Nombre, Direccion, Telefono, CodDepartamento, CodMunicipio, CodDistrito,
			                                CodEstableMH, CodEstable, CodPuntoVentaMH, CodPuntoVenta, IsActivo, UsuarioCrea)
			VALUES (@codigo, @nombre, NULLIF(@direccion, ''), NULLIF(@telefono, ''), NULLIF(@codDepartamento, ''), NULLIF(@codMunicipio, ''),
			        NULLIF(@codDistrito, ''), @codEstableMH, @codEstable, @codPuntoVentaMH, @codPuntoVenta, ISNULL(@activo, 1), @usuario);
			SELECT CAST(SCOPE_IDENTITY() AS int) AS Id;
			RETURN;
		END
		IF NOT EXISTS (SELECT 1 FROM dbo.CAT_SUCURSALES WHERE Id_Sucursal = @id) THROW 50309, 'La sucursal ya no existe.', 1;
		UPDATE dbo.CAT_SUCURSALES SET Codigo = @codigo, Nombre = @nombre, Direccion = NULLIF(@direccion, ''), Telefono = NULLIF(@telefono, ''),
		       CodDepartamento = NULLIF(@codDepartamento, ''), CodMunicipio = NULLIF(@codMunicipio, ''), CodDistrito = NULLIF(@codDistrito, ''),
		       CodEstableMH = @codEstableMH, CodEstable = @codEstable, CodPuntoVentaMH = @codPuntoVentaMH, CodPuntoVenta = @codPuntoVenta,
		       IsActivo = ISNULL(@activo, IsActivo), UsuarioModifica = @usuario, FechaModifica = GETDATE()
		WHERE Id_Sucursal = @id;
		SELECT @id AS Id;
		RETURN;
	END

	IF @accion = 4
	BEGIN
		IF @activo = 0 AND EXISTS (SELECT 1 FROM dbo.CAT_SUCURSALES WHERE Id_Sucursal = @id AND EsMatriz = 1)
			THROW 50308, 'La Casa Matriz no se puede inactivar.', 1;
		IF @activo = 0 AND EXISTS (SELECT 1 FROM dbo.Sys_Usuarios WHERE Id_Sucursal_FK = @id AND ISNULL(EstatusUsuario, 'A') = 'A')
			THROW 50310, 'Hay usuarios activos en esta sucursal. Cámbielos de sucursal antes de inactivarla.', 1;
		UPDATE dbo.CAT_SUCURSALES SET IsActivo = @activo, UsuarioModifica = @usuario, FechaModifica = GETDATE() WHERE Id_Sucursal = @id;
		SELECT @id AS Id;
		RETURN;
	END

	IF @accion = 5
	BEGIN
		IF NOT EXISTS (SELECT 1 FROM dbo.CAT_SUCURSALES WHERE Id_Sucursal = @id) THROW 50309, 'La sucursal ya no existe.', 1;
		DECLARE @lista TABLE (Id bigint PRIMARY KEY);
		-- '1,5,8' -> filas (sin STRING_SPLIT: la base puede tener un nivel de compatibilidad anterior a 130)
		DECLARE @xml xml = CAST('<i>' + REPLACE(ISNULL(@especialistas, ''), ',', '</i><i>') + '</i>' AS xml);
		INSERT @lista SELECT DISTINCT v.Id
		FROM (SELECT TRY_CAST(n.value('.', 'varchar(20)') AS bigint) AS Id FROM @xml.nodes('/i') AS x(n)) AS v
		WHERE v.Id IN (SELECT Id_Especialista FROM dbo.CAT_ESPECIALISTAS);
		BEGIN TRANSACTION;
			DELETE FROM dbo.CAT_ESPECIALISTAS_SUCURSALES WHERE Id_Sucursal_FK = @id AND Id_Especialista_FK NOT IN (SELECT Id FROM @lista);
			INSERT INTO dbo.CAT_ESPECIALISTAS_SUCURSALES (Id_Especialista_FK, Id_Sucursal_FK, UsuarioCrea)
			SELECT l.Id, @id, @usuario FROM @lista AS l
			WHERE NOT EXISTS (SELECT 1 FROM dbo.CAT_ESPECIALISTAS_SUCURSALES AS x WHERE x.Id_Especialista_FK = l.Id AND x.Id_Sucursal_FK = @id);
		COMMIT TRANSACTION;
		SELECT @id AS Id;
		RETURN;
	END

	IF @accion = 6
	BEGIN
		SELECT Id_Sucursal AS Id, Nombre AS Texto, EsMatriz FROM dbo.CAT_SUCURSALES WHERE IsActivo = 1 ORDER BY EsMatriz DESC, Nombre;
		RETURN;
	END

	IF @accion = 7
	BEGIN
		SELECT TOP 1 s.Id_Sucursal AS Id, s.Nombre
		FROM dbo.Sys_Usuarios AS u INNER JOIN dbo.CAT_SUCURSALES AS s ON s.Id_Sucursal = u.Id_Sucursal_FK
		WHERE u.Id_Usuario = @usuarioId;
		RETURN;
	END
END
GO

/* Menú Opciones > Sucursales (Administradores) */
IF NOT EXISTS (SELECT 1 FROM dbo.Sys_Opciones WHERE AccesoURL = 'Opciones/frm_Sucursales.aspx')
BEGIN
	BEGIN TRANSACTION;
	DECLARE @opcion bigint, @orden int = ISNULL((SELECT MAX(Orden) FROM dbo.Sys_Opciones WHERE IdModulo_FK = 2), 0) + 1;
	INSERT INTO dbo.Sys_Opciones (Descripcion, Abreviado, AccesoURL, IdModulo_FK, Id_UsuarioCrea_FK, FechaCreacion, Orden)
	VALUES ('Sucursales', 'SU', 'Opciones/frm_Sucursales.aspx', 2, 'admin', GETDATE(), @orden);
	SET @opcion = SCOPE_IDENTITY();
	INSERT INTO dbo.Sys_Permisos (IdAplicativo_FK, IdModulo_FK, IdOpcion_FK, IdGrupo_FK, Id_UsuarioCrea_FK, FechaCreacion)
	SELECT 2, 2, @opcion, g.Id_Grupo, 'admin', GETDATE() FROM dbo.Sys_Grupos AS g WHERE g.Id_Grupo = 'Administradores';
	COMMIT TRANSACTION;
END
GO

/* #####################################################################
   5/35  Registros\sql\EXP_Citas_Horarios.sql
   ##################################################################### */
PRINT N'>> 5/35 Registros\sql\EXP_Citas_Horarios.sql';
GO
/* =====================================================================
   DPieCenter - Citas: FechaInicio / FechaFin según Fecha y la tabla de horarios (CAT_HORARIOS)

   Problema encontrado:
     - Citas sin FechaInicio/FechaFin (las crea EXP_SP_Citas, que solo guarda Fecha y los horarios).
     - Citas con FechaInicio = FechaFin = hora en que se finalizó la atención, no la hora de la cita.
     - El calendario (EXP_SP_Citas_V2) guardaba siempre Id_Horario_fk = 1 (08:00).

   Este script:
     1. dbo.EXP_FN_HorarioCita(@hora): horario activo de CAT_HORARIOS que corresponde a una hora
        (el último horario que empieza a esa hora o antes; si es antes del primero, el primero).
     2. Corrige los datos: FechaInicio = Fecha + hora del horario inicial;
        FechaFin = Fecha + hora del horario final si es posterior, si no, inicio + 60 minutos.
        Solo toca citas sin FechaInicio o con FechaInicio = FechaFin (las de horario real se conservan).
     3. Trigger TR_EXP_CITAS_Horario: mantiene FechaInicio/FechaFin cuando una cita se guarda con
        Fecha y horario pero sin FechaInicio (pantallas anteriores).
   Script idempotente.
   ===================================================================== */
SET NOCOUNT ON;
GO

CREATE OR ALTER FUNCTION dbo.EXP_FN_HorarioCita (@hora time)
RETURNS bigint
AS
BEGIN
    RETURN COALESCE(
        (SELECT TOP 1 Id_Horario FROM dbo.CAT_HORARIOS WHERE ISNULL(IsActivo, 1) = 1 AND Hora <= @hora ORDER BY Hora DESC),
        (SELECT TOP 1 Id_Horario FROM dbo.CAT_HORARIOS WHERE ISNULL(IsActivo, 1) = 1 ORDER BY Hora));
END
GO

/* Corrección de datos */
DECLARE @propia bit = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
BEGIN TRY
    IF @propia = 1 BEGIN TRANSACTION;

    ;WITH x AS (
        SELECT c.FechaInicio, c.FechaFin,
               DATEADD(SECOND, DATEDIFF(SECOND, CAST('00:00' AS time), h.Hora), CAST(c.Fecha AS datetime2)) AS NuevoInicio,
               DATEADD(SECOND, DATEDIFF(SECOND, CAST('00:00' AS time), hf.Hora), CAST(c.Fecha AS datetime2)) AS FinHorario
        FROM dbo.EXP_CITAS AS c
            INNER JOIN dbo.CAT_HORARIOS AS h ON h.Id_Horario = c.Id_Horario_fk
            LEFT JOIN dbo.CAT_HORARIOS AS hf ON hf.Id_Horario = c.Id_HorarioFin_FK
        WHERE c.FechaInicio IS NULL OR c.FechaFin IS NULL OR c.FechaInicio = c.FechaFin
    )
    UPDATE x SET
         FechaInicio = NuevoInicio
        ,FechaFin = CASE WHEN FinHorario > NuevoInicio THEN FinHorario ELSE DATEADD(MINUTE, 60, NuevoInicio) END;

    PRINT N'Citas corregidas: ' + CAST(@@ROWCOUNT AS nvarchar(10));
    IF @propia = 1 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @propia = 1 AND @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH
GO

/* Citas guardadas con Fecha y horario pero sin FechaInicio (o con cambio de fecha/horario sin FechaInicio) */
CREATE OR ALTER TRIGGER dbo.TR_EXP_CITAS_Horario
ON dbo.EXP_CITAS
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;
    DECLARE @recalcular bit = CASE WHEN NOT UPDATE(FechaInicio)
                                    AND (UPDATE(Fecha) OR UPDATE(Id_Horario_fk) OR UPDATE(Id_HorarioFin_FK)) THEN 1 ELSE 0 END;

    ;WITH x AS (
        SELECT c.FechaInicio, c.FechaFin,
               DATEADD(SECOND, DATEDIFF(SECOND, CAST('00:00' AS time), h.Hora), CAST(c.Fecha AS datetime2)) AS NuevoInicio,
               DATEADD(SECOND, DATEDIFF(SECOND, CAST('00:00' AS time), hf.Hora), CAST(c.Fecha AS datetime2)) AS FinHorario
        FROM dbo.EXP_CITAS AS c
            INNER JOIN inserted AS i ON i.Id_Cita = c.Id_Cita
            INNER JOIN dbo.CAT_HORARIOS AS h ON h.Id_Horario = c.Id_Horario_fk
            LEFT JOIN dbo.CAT_HORARIOS AS hf ON hf.Id_Horario = c.Id_HorarioFin_FK
        WHERE c.FechaInicio IS NULL OR @recalcular = 1
    )
    UPDATE x SET
         FechaInicio = NuevoInicio
        ,FechaFin = CASE WHEN FinHorario > NuevoInicio THEN FinHorario ELSE DATEADD(MINUTE, 60, NuevoInicio) END;
END
GO

/* #####################################################################
   6/35  Registros\sql\EXP_Citas_ProcedimientoEnCurso.sql
   ##################################################################### */
PRINT N'>> 6/35 Registros\sql\EXP_Citas_ProcedimientoEnCurso.sql';
GO
/* =====================================================================
   DPieCenter - Agenda: al crear una cita en la hora en curso se abre su procedimiento
   (EXP_PROCEDIMIENTOS) con los tratamientos de la cita (EXP_CITASTRATAMIENTOS -> EXP_PROCEDIMIENTOSTRATAMIENTOS),
   igual que hacía EXP_SP_Citas con EXP_SP_ProcedimientosCreaV2.

   Lo invoca Registros/CitasRepository.CrearCita dentro de la misma transacción, después de guardar los tratamientos.
   Script idempotente: se puede ejecutar varias veces.
   ===================================================================== */
SET NOCOUNT ON;
GO

/* Devuelve solo el Id de la cita. Antes devolvía también 'OK' cuando la cita era en la hora en curso,
   y CitasRepository leía ese 'OK' con ExecuteScalar en lugar del Id (InvalidCastException). */
CREATE OR ALTER PROCEDURE [dbo].[EXP_SP_Citas_V2]
	 @expediente bigint
	,@tipocita bigint
	,@especialista bigint
	,@fechaInicio datetime2
	,@fechaFin datetime2
	,@comentarios varchar(max)
	,@user varchar(20)
	,@sucursal int = 0          -- sucursal de la sesión (0 = Casa Matriz)
AS
BEGIN
	SET NOCOUNT ON;
	set @sucursal = ISNULL(NULLIF(@sucursal, 0), dbo.SUC_FN_Matriz())

	insert into EXP_CITAS
		(Id_Expediente_fk,Id_Horario_fk,Id_HorarioFin_FK
		,Id_TipoCita_FK,Id_Especialista_fk,Id_Tratamiento_fk
		,Id_EstadoCita_fk,Comentarios,Fecha,FechaInicio
		,FechaFin,UsuarioCrea,FechaCrea,Id_Sucursal_FK)
	values
		(@expediente
		,dbo.EXP_FN_HorarioCita(CAST(@fechaInicio as time))		-- horario de CAT_HORARIOS (EXP_Citas_Horarios.sql)
		,dbo.EXP_FN_HorarioCita(CAST(DATEADD(MINUTE, -1, @fechaFin) as time))
		,@tipocita,@especialista,1
		,1,@comentarios,cast(@fechaInicio as date),@fechaInicio
		,@fechaFin,@user,GETDATE(),@sucursal)

	select CAST(SCOPE_IDENTITY() as bigint) as Id_Cita
END
GO

/* Guarda la descripción del catálogo (antes quedaba vacía y el procedimiento heredaba tratamientos sin nombre) */
CREATE OR ALTER PROCEDURE [dbo].[EXP_SP_CitasTratamientos_V2]
	@cita bigint
	,@tratamiento bigint
	,@precio float
	,@duracion int
	,@user varchar(20)
AS
BEGIN
	SET NOCOUNT ON;

	insert into EXP_CITASTRATAMIENTOS
		(Id_Cita_FK,Id_Tratamiento_FK,Descripcion,Valor,UsuarioCrea,FechaCreacion)
	select
		@cita,@tratamiento,ISNULL(t.Descripcion,''),@precio,@user,GETDATE()
	from (select 1 as x) as uno
		left join CAT_TRATAMIENTOS as t on t.Id_Tratamientos = @tratamiento
END
GO

/* Si la cita es de hoy y en la hora en curso, crea el procedimiento con sus tratamientos y pasa la cita a "En proceso".
   Devuelve el Id del procedimiento, o 0 si la cita no es de la hora en curso o ya tenía procedimiento (sin contar los
   reprogramados 'R'). Lo usan la agenda al crear una cita, EXP_SP_CitaUpdate y la reprogramación de Procedimientos.
   Sin TRY/CATCH: los errores llegan a la aplicación y se revierte toda la creación de la cita. */
CREATE OR ALTER PROCEDURE [dbo].[EXP_SP_Citas_ProcedimientoEnCurso]
	@cita bigint
	,@user varchar(20)
AS
BEGIN
	SET NOCOUNT ON;

	declare @ahora datetime = GETDATE(), @procedimiento bigint = 0
	declare @enProceso bigint = (select top 1 Id_Estado from CAT_ESTADOSCITAS where Accion = 1 order by Id_Estado)   -- 4 En proceso

	if exists (select 1 from EXP_CITAS
			   where Id_Cita = @cita
				 and CAST(FechaInicio as date) = CAST(@ahora as date)
				 and DATEPART(HOUR, FechaInicio) = DATEPART(HOUR, @ahora))
	   -- los procedimientos 'R' son de un horario anterior de la misma cita (reprogramada): no cuentan
	   and not exists (select 1 from EXP_PROCEDIMIENTOS where Id_Cita_FK = @cita and Estado <> 'R')
	begin
		insert into EXP_PROCEDIMIENTOS
			(Id_Expediente_FK,Id_TipoCita_FK,Id_Especialista_FK,Id_Cita_FK,Id_Horario_FK
			,Id_Horariofin_FK,InicioProcedimiento,Id_EstadoCita_fk,Fecha,Estado,UsuarioCrea,FechaCrea)
		select
			Id_Expediente_fk,Id_TipoCita_FK,Id_Especialista_fk,Id_Cita,Id_Horario_fk
			,Id_Horariofin_FK,FechaInicio,@enProceso,Fecha,'S',@user,@ahora   -- 'S' = en sala de espera
		from EXP_CITAS
		where Id_Cita = @cita

		set @procedimiento = SCOPE_IDENTITY()

		insert into EXP_PROCEDIMIENTOSTRATAMIENTOS
			(Id_Procedimiento_FK,Id_Tratamiento_FK,Descripcion,Valor,Estatus,UsuarioCrea,FechaCreacion)
		select
			@procedimiento,tto.Id_Tratamiento_FK,ISNULL(NULLIF(tto.Descripcion,''),ISNULL(t.Descripcion,'')),tto.Valor,1
			,@user,@ahora
		from EXP_CITASTRATAMIENTOS as tto
			left join CAT_TRATAMIENTOS as t on t.Id_Tratamientos = tto.Id_Tratamiento_FK
		where tto.Id_Cita_FK = @cita

		update EXP_CITAS set
			Id_EstadoCita_fk = @enProceso
		where Id_Cita = @cita
	end

	select @procedimiento as Id_Procedimiento
END
GO

/* #####################################################################
   7/35  Facturacion\sql\CAJ_Anticipos.sql
   ##################################################################### */
PRINT N'>> 7/35 Facturacion\sql\CAJ_Anticipos.sql';
GO
/* =====================================================================
   DPieCenter - Cobro de citas por adelantado en caja (Facturacion/frm_Facturas.aspx, pestaña "Citas por cobrar")

   Se cobra el total de los tratamientos de la cita y se emite la factura (DTE) en ese momento:
   CAJ_FACTURAS con Anticipo = 1, Id_Cita_FK = la cita e Id_Procedimiento_FK = NULL hasta que se atiende.
   Al finalizar el procedimiento (EXP_SP_Procedimientos acción 10) la factura del anticipo se liga al procedimiento y solo
   queda pendiente de cobro lo que no se pagó por adelantado (tratamientos agregados).
   Si la cita se cancela o se anula, lo pagado queda a favor del paciente: se aplica a su próximo procedimiento
   (automáticamente al finalizarlo) o, desde caja, a otra de sus citas.

   Pago adelantado sin cita (monto libre): el paciente paga un monto antes de tener cita y la cita queda pendiente de agendar.
   CAJ_FACTURAS con Anticipo = 1, MontoLibre = 1, Id_Cita_FK = NULL y un solo detalle sin tratamiento por el monto.
   Al agendar, desde caja o la agenda se usa en una cita ("Usar pago adelantado": Id_Cita_FK = la cita). Al finalizar el
   procedimiento (EXP_SP_Procedimientos acción 10) se descuenta de los tratamientos hasta donde alcance (CAJ_ANTICIPOS_USOS),
   el resto se cobra y, si sobra, el pago vuelve a "pendiente de agendar" con su saldo. Sin plazo de vencimiento.

   CAJ_SP_Anticipos @accion:
     1 citas por cobrar (desde hoy, de la sucursal)   2 crear la factura del anticipo de una cita (devuelve Id_factura)
     3 saldos a favor (anticipos de citas canceladas/anuladas aún sin usar)   4 aplicar un saldo a favor a otra cita
     5 crear el pago sin cita (@expediente, @monto, @descripcion; devuelve Id_factura)
     6 pagos pendientes de agendar (@texto o @expediente)   7 usar un pago adelantado en una cita (@cita, @factura 0 = el más antiguo)
     8 quitar el pago adelantado de una cita (@cita)
   Script idempotente: se puede ejecutar varias veces.
   ===================================================================== */
SET NOCOUNT ON;
GO

/* ---------- Pago adelantado sin cita ---------- */
IF COL_LENGTH('dbo.CAJ_FACTURAS', 'MontoLibre') IS NULL
	ALTER TABLE dbo.CAJ_FACTURAS ADD MontoLibre bit NOT NULL CONSTRAINT DF_CAJ_FACTURAS_MontoLibre DEFAULT (0);
GO
-- el detalle del pago adelantado no es un tratamiento
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.CAJ_FACTURASDETALLES') AND name = 'Id_tratamiento_FK' AND is_nullable = 0)
	ALTER TABLE dbo.CAJ_FACTURASDETALLES ALTER COLUMN Id_tratamiento_FK bigint NULL;
GO
-- lo que se ha descontado de cada pago adelantado (puede usarse en varias citas hasta agotarse)
IF OBJECT_ID('dbo.CAJ_ANTICIPOS_USOS', 'U') IS NULL
	CREATE TABLE dbo.CAJ_ANTICIPOS_USOS (
		Id_Uso               bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_CAJ_ANTICIPOS_USOS PRIMARY KEY,
		Id_FacturaAnticipo_FK bigint       NOT NULL CONSTRAINT FK_CAJ_ANTICIPOS_USOS_Factura REFERENCES dbo.CAJ_FACTURAS (Id_factura),
		Id_Procedimiento_FK  bigint        NULL,
		Id_Cita_FK           bigint        NULL,
		Monto                decimal(12,2) NOT NULL,
		UsuarioCrea          varchar(20)   NOT NULL,
		FechaCrea            datetime      NOT NULL CONSTRAINT DF_CAJ_ANTICIPOS_USOS_Fecha DEFAULT (GETDATE())
	);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CAJ_ANTICIPOS_USOS_Factura')
	CREATE INDEX IX_CAJ_ANTICIPOS_USOS_Factura ON dbo.CAJ_ANTICIPOS_USOS (Id_FacturaAnticipo_FK);
GO

/* Pagos adelantados sin cita con su saldo: pagado (DTE vigentes) - usado. Id_Cita = la cita activa donde se usará (NULL = pendiente de agendar). */
CREATE OR ALTER FUNCTION dbo.CAJ_FN_PagosAdelantados (@expediente bigint)
RETURNS TABLE
AS
RETURN
	select f.Id_factura, f.Id_Expediente_FK as Id_Expediente, f.Id_Sucursal_FK as Id_Sucursal
		,case when c.Id_Cita is not null and ec.Procesos = 1 then c.Id_Cita end as Id_Cita
		,ISNULL(d.Descripion, '') as Descripcion
		,x.Pagado, ISNULL(u.Usado, 0) as Usado, CAST(x.Pagado - ISNULL(u.Usado, 0) as decimal(12,2)) as Disponible
		,x.FechaPago
	from CAJ_FACTURAS as f
		cross apply (select CAST(ISNULL(SUM(TotalPagar), 0) as decimal(12,2)) as Pagado, MAX(FechaEmision) as FechaPago
					 from FAC_DTE_DOCUMENTOS where Id_Factura_FK = f.Id_factura and Estado <> 'A') as x
		outer apply (select SUM(Monto) as Usado from CAJ_ANTICIPOS_USOS where Id_FacturaAnticipo_FK = f.Id_factura) as u
		outer apply (select top 1 Descripion from CAJ_FACTURASDETALLES where Id_Factura_FK = f.Id_factura order by Id_detalle) as d
		left join EXP_CITAS as c on c.Id_Cita = f.Id_Cita_FK
		left join CAT_ESTADOSCITAS as ec on ec.Id_Estado = c.Id_EstadoCita_fk
	where f.Anticipo = 1 and f.MontoLibre = 1 and f.Estado = 1
		and (@expediente = 0 or f.Id_Expediente_FK = @expediente)
		and x.Pagado - ISNULL(u.Usado, 0) > 0
GO

-- La factura de un anticipo todavía no tiene procedimiento
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.CAJ_FACTURAS') AND name = 'Id_Procedimiento_FK' AND is_nullable = 0)
	ALTER TABLE dbo.CAJ_FACTURAS ALTER COLUMN Id_Procedimiento_FK bigint NULL;
IF COL_LENGTH('dbo.CAJ_FACTURAS', 'Id_Cita_FK') IS NULL
	ALTER TABLE dbo.CAJ_FACTURAS ADD Id_Cita_FK bigint NULL;
IF COL_LENGTH('dbo.CAJ_FACTURAS', 'Anticipo') IS NULL
	ALTER TABLE dbo.CAJ_FACTURAS ADD Anticipo bit NOT NULL CONSTRAINT DF_CAJ_FACTURAS_Anticipo DEFAULT (0);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CAJ_FACTURAS_Cita')
	CREATE INDEX IX_CAJ_FACTURAS_Cita ON dbo.CAJ_FACTURAS (Id_Cita_FK) WHERE Id_Cita_FK IS NOT NULL;
GO

CREATE OR ALTER PROCEDURE dbo.CAJ_SP_Anticipos
	 @accion   int
	,@usuario  varchar(20)
	,@sucursal int = 0               -- sucursal de la sesión (0 = todas)
	,@cita     bigint = 0
	,@factura  bigint = 0
	,@texto    nvarchar(100) = NULL
	,@hasta    date = NULL           -- 1: hasta esta fecha (por defecto 30 días)
	,@expediente  bigint = 0         -- 5, 6
	,@monto       decimal(12,2) = 0  -- 5
	,@descripcion varchar(250) = NULL -- 5
AS
BEGIN
	SET NOCOUNT ON;
	declare @hoy date = CAST(GETDATE() as date)
	set @texto = NULLIF(LTRIM(RTRIM(@texto)), '')

	-- Saldos a favor: anticipos pagados de citas canceladas o anuladas que aún no se aplicaron a un procedimiento
	declare @saldos table (Id_Factura bigint primary key, Id_Expediente bigint, Id_Cita bigint, Total decimal(12,2), FechaPago date)
	insert @saldos
	select f.Id_factura, f.Id_Expediente_FK, f.Id_Cita_FK
		,ISNULL((select SUM(TotalPagar) from FAC_DTE_DOCUMENTOS where Id_Factura_FK = f.Id_factura and Estado <> 'A'), 0)
		,(select MAX(FechaEmision) from FAC_DTE_DOCUMENTOS where Id_Factura_FK = f.Id_factura and Estado <> 'A')
	from CAJ_FACTURAS as f
		inner join EXP_CITAS as c on c.Id_Cita = f.Id_Cita_FK
		inner join CAT_ESTADOSCITAS as ec on ec.Id_Estado = c.Id_EstadoCita_fk
	where f.Anticipo = 1 and f.MontoLibre = 0 and f.Estado = 1 and f.Id_Procedimiento_FK is null
		and (ec.Cancelada = 1 or c.Id_EstadoCita_fk = 7)

	/* 1: citas por cobrar por adelantado: desde hoy, activas, de la sucursal */
	if @accion = 1
	begin
		-- 30 días; al buscar un paciente, todo el año (sus citas lejanas también se pueden cobrar o recibir su saldo a favor)
		set @hasta = ISNULL(@hasta, DATEADD(DAY, case when @texto is null then 30 else 365 end, @hoy))
		select c.Id_Cita
			,ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2)) as Inicio
			,e.Id_Expediente
			,LTRIM(RTRIM(e.Nombres + ' ' + e.Apellidos)) as Paciente
			,ISNULL(e.Documento, '') as Documento
			,ISNULL(e.Celular, '') as Celular
			,ISNULL(s.Descripcion, '') as Especialista
			,ISNULL(ec.Descripcion, '') as Estado
			,ISNULL(STUFF((select ', ' + ct.Descripcion from EXP_CITASTRATAMIENTOS as ct where ct.Id_Cita_FK = c.Id_Cita
				for xml path(''), type).value('.', 'nvarchar(max)'), 1, 2, ''), '') as Servicios
			-- total con el descuento vigente de cada tratamiento
			,ISNULL((select SUM(ct.Valor - ROUND(ct.Valor * ISNULL(t.Descuento, 0) / 100, 2))
					 from EXP_CITASTRATAMIENTOS as ct left join CAT_TRATAMIENTOS as t on t.Id_Tratamientos = ct.Id_Tratamiento_FK
					 where ct.Id_Cita_FK = c.Id_Cita), 0) as Total
			-- anticipo de la cita: pagado o creado sin pagar
			,a.Id_factura as IdFactura
			,ISNULL(a.Estado, 0) as Pagada
			,ISNULL((select SUM(Total) from @saldos where Id_Expediente = e.Id_Expediente), 0) as SaldoFavor
			-- pago adelantado sin cita: el que se usará en esta cita y los del paciente pendientes de agendar
			,ISNULL((select SUM(Disponible) from dbo.CAJ_FN_PagosAdelantados(e.Id_Expediente) where Id_Cita = c.Id_Cita), 0) as PagoAdelantado
			,ISNULL((select SUM(Disponible) from dbo.CAJ_FN_PagosAdelantados(e.Id_Expediente) where Id_Cita is null), 0) as PagosPendientes
		from EXP_CITAS as c
			inner join EXP_EXPEDIENTES as e on e.Id_Expediente = c.Id_Expediente_fk
			inner join CAT_ESTADOSCITAS as ec on ec.Id_Estado = c.Id_EstadoCita_fk
			left join CAT_ESPECIALISTAS as s on s.Id_Especialista = c.Id_Especialista_fk
			outer apply (select top 1 Id_factura, Estado from CAJ_FACTURAS
						 where Id_Cita_FK = c.Id_Cita and Anticipo = 1 and MontoLibre = 0 order by Estado desc, Id_factura desc) as a
		where ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2)) >= @hoy
			and ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2)) < DATEADD(DAY, 1, @hasta)
			and ec.Procesos = 1
			and (@sucursal = 0 or c.Id_Sucursal_FK = @sucursal)
			and not exists (select 1 from EXP_PROCEDIMIENTOS as p where p.Id_Cita_FK = c.Id_Cita and p.Estado = 'F')
			and (@texto is null or e.Nombres + ' ' + e.Apellidos like '%' + @texto + '%' or e.Documento like '%' + @texto + '%'
				 or e.Celular like '%' + @texto + '%')
		order by ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2)), c.Id_Cita
		return
	end

	/* 2: factura del anticipo de la cita (si ya existe sin pagar, se rehace con los tratamientos actuales) */
	if @accion = 2
	begin
		declare @exp bigint, @sucCita int, @procesos bit
		select @exp = c.Id_Expediente_fk, @sucCita = c.Id_Sucursal_FK, @procesos = ec.Procesos
		from EXP_CITAS as c inner join CAT_ESTADOSCITAS as ec on ec.Id_Estado = c.Id_EstadoCita_fk
		where c.Id_Cita = @cita
		if @exp is null THROW 50601, 'La cita no existe.', 1;
		if ISNULL(@procesos, 0) = 0 THROW 50602, 'La cita está cancelada, anulada o finalizada: no se puede cobrar por adelantado.', 1;
		if exists (select 1 from EXP_PROCEDIMIENTOS where Id_Cita_FK = @cita and Estado = 'F')
			THROW 50603, 'La cita ya fue atendida: cóbrela en Pendientes de cobro.', 1;
		if exists (select 1 from CAJ_FACTURAS where Id_Cita_FK = @cita and Anticipo = 1 and MontoLibre = 0 and Estado = 1)
			THROW 50604, 'La cita ya está pagada por adelantado.', 1;
		if exists (select 1 from dbo.CAJ_FN_PagosAdelantados(@exp) where Id_Cita = @cita)
			THROW 50607, 'La cita usará un pago adelantado del paciente: al atenderla se descuenta y solo se cobra la diferencia.', 1;
		if not exists (select 1 from EXP_CITASTRATAMIENTOS where Id_Cita_FK = @cita)
			THROW 50605, 'La cita no tiene tratamientos para cobrar.', 1;

		declare @f bigint = (select top 1 Id_factura from CAJ_FACTURAS where Id_Cita_FK = @cita and Anticipo = 1 and Estado = 0 order by Id_factura desc)

		BEGIN TRANSACTION;
		if @f is null
		begin
			insert into CAJ_FACTURAS (FechaFactura, Id_Procedimiento_FK, Id_Expediente_FK, Estado, UsuarioCrea, FechaCrea, Id_Sucursal_FK, Id_Cita_FK, Anticipo)
			values (@hoy, NULL, @exp, 0, @usuario, GETDATE(), ISNULL(NULLIF(@sucCita, 0), dbo.SUC_FN_Matriz()), @cita, 1)
			set @f = SCOPE_IDENTITY()
		end
		else
		begin
			update CAJ_FACTURAS set FechaFactura = @hoy, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_factura = @f
			delete from CAJ_FACTURASDETALLES where Id_Factura_FK = @f
		end

		insert into CAJ_FACTURASDETALLES (Id_Factura_FK, Id_tratamiento_FK, Descripion, Valor, UsuarioCrea, FechaCrea)
		select @f, ct.Id_Tratamiento_FK, ISNULL(NULLIF(LTRIM(RTRIM(ct.Descripcion)), ''), t.Descripcion), ISNULL(ct.Valor, 0), @usuario, GETDATE()
		from EXP_CITASTRATAMIENTOS as ct left join CAT_TRATAMIENTOS as t on t.Id_Tratamientos = ct.Id_Tratamiento_FK
		where ct.Id_Cita_FK = @cita
		order by ct.Id
		COMMIT TRANSACTION;

		select @f as Id_Factura
		return
	end

	/* 3: saldos a favor (para el paciente @factura = 0: todos los de la sucursal) */
	if @accion = 3
	begin
		select s.Id_Factura, s.Id_Expediente, LTRIM(RTRIM(e.Nombres + ' ' + e.Apellidos)) as Paciente, ISNULL(e.Documento, '') as Documento
			,s.Id_Cita, ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2)) as InicioCita, ISNULL(ec.Descripcion, '') as EstadoCita
			,s.Total, s.FechaPago
		from @saldos as s
			inner join EXP_EXPEDIENTES as e on e.Id_Expediente = s.Id_Expediente
			inner join CAJ_FACTURAS as f on f.Id_factura = s.Id_Factura
			left join EXP_CITAS as c on c.Id_Cita = s.Id_Cita
			left join CAT_ESTADOSCITAS as ec on ec.Id_Estado = c.Id_EstadoCita_fk
		where (@sucursal = 0 or f.Id_Sucursal_FK = @sucursal)
		order by s.FechaPago, s.Id_Factura
		return
	end

	/* 4: aplicar el saldo a favor más antiguo del paciente a una de sus citas activas */
	if @accion = 4
	begin
		declare @expC bigint, @procC bit
		select @expC = c.Id_Expediente_fk, @procC = ec.Procesos
		from EXP_CITAS as c inner join CAT_ESTADOSCITAS as ec on ec.Id_Estado = c.Id_EstadoCita_fk
		where c.Id_Cita = @cita
		if @expC is null THROW 50601, 'La cita no existe.', 1;
		if ISNULL(@procC, 0) = 0 THROW 50602, 'La cita está cancelada, anulada o finalizada.', 1;
		if exists (select 1 from CAJ_FACTURAS where Id_Cita_FK = @cita and Anticipo = 1 and MontoLibre = 0 and Estado = 1)
			THROW 50604, 'La cita ya está pagada por adelantado.', 1;
		if exists (select 1 from dbo.CAJ_FN_PagosAdelantados(@expC) where Id_Cita = @cita)
			THROW 50607, 'La cita ya usará un pago adelantado del paciente.', 1;

		declare @saldo bigint = (select top 1 Id_Factura from @saldos where Id_Expediente = @expC order by FechaPago, Id_Factura)
		if @saldo is null THROW 50606, 'El paciente no tiene saldo a favor.', 1;

		BEGIN TRANSACTION;
		-- un anticipo sin pagar de esta cita ya no hace falta
		delete d from CAJ_FACTURASDETALLES as d inner join CAJ_FACTURAS as f on f.Id_factura = d.Id_Factura_FK
		where f.Id_Cita_FK = @cita and f.Anticipo = 1 and f.Estado = 0
			and not exists (select 1 from FAC_DTE_DOCUMENTOS where Id_Factura_FK = f.Id_factura)
		delete f from CAJ_FACTURAS as f
		where f.Id_Cita_FK = @cita and f.Anticipo = 1 and f.Estado = 0
			and not exists (select 1 from FAC_DTE_DOCUMENTOS where Id_Factura_FK = f.Id_factura)

		update CAJ_FACTURAS set Id_Cita_FK = @cita, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_factura = @saldo
		COMMIT TRANSACTION;

		select @saldo as Id_Factura
		return
	end

	/* 5: pago adelantado sin cita (monto libre). Se cobra en frm_OpenFactura.aspx como cualquier factura */
	if @accion = 5
	begin
		if not exists (select 1 from EXP_EXPEDIENTES where Id_Expediente = @expediente)
			THROW 50610, 'Seleccione el paciente.', 1;
		if ISNULL(@monto, 0) <= 0
			THROW 50611, 'El monto del pago debe ser mayor que cero.', 1;
		if @monto > 10000
			THROW 50612, 'El monto del pago no puede superar $10,000.00.', 1;
		set @descripcion = ISNULL(NULLIF(LTRIM(RTRIM(@descripcion)), ''), 'Pago adelantado de servicios podológicos')

		BEGIN TRANSACTION;
		-- un pago sin cita del mismo paciente creado y no cobrado se descarta
		delete d from CAJ_FACTURASDETALLES as d inner join CAJ_FACTURAS as f on f.Id_factura = d.Id_Factura_FK
		where f.Id_Expediente_FK = @expediente and f.MontoLibre = 1 and f.Estado = 0
			and not exists (select 1 from FAC_DTE_DOCUMENTOS where Id_Factura_FK = f.Id_factura)
		delete f from CAJ_FACTURAS as f
		where f.Id_Expediente_FK = @expediente and f.MontoLibre = 1 and f.Estado = 0
			and not exists (select 1 from FAC_DTE_DOCUMENTOS where Id_Factura_FK = f.Id_factura)
			and not exists (select 1 from CAJ_FACTURASDETALLES where Id_Factura_FK = f.Id_factura)

		declare @nueva bigint
		insert into CAJ_FACTURAS (FechaFactura, Id_Procedimiento_FK, Id_Expediente_FK, Estado, UsuarioCrea, FechaCrea, Id_Sucursal_FK, Id_Cita_FK, Anticipo, MontoLibre)
		values (@hoy, NULL, @expediente, 0, @usuario, GETDATE(), ISNULL(NULLIF(@sucursal, 0), dbo.SUC_FN_Matriz()), NULL, 1, 1)
		set @nueva = SCOPE_IDENTITY()
		insert into CAJ_FACTURASDETALLES (Id_Factura_FK, Id_tratamiento_FK, Descripion, Valor, UsuarioCrea, FechaCrea)
		values (@nueva, NULL, LEFT(@descripcion, 250), @monto, @usuario, GETDATE())
		COMMIT TRANSACTION;

		select @nueva as Id_Factura
		return
	end

	/* 6: pagos adelantados con saldo (de la sucursal; @expediente 0 = todos). Pendiente = sin cita activa */
	if @accion = 6
	begin
		select p.Id_factura as Id_Factura, p.Id_Expediente, LTRIM(RTRIM(e.Nombres + ' ' + e.Apellidos)) as Paciente
			,ISNULL(e.Documento, '') as Documento, ISNULL(e.Celular, '') as Celular
			,p.Descripcion, p.Pagado, p.Usado, p.Disponible, p.FechaPago
			,p.Id_Cita, ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2)) as InicioCita
		from dbo.CAJ_FN_PagosAdelantados(@expediente) as p
			inner join EXP_EXPEDIENTES as e on e.Id_Expediente = p.Id_Expediente
			left join EXP_CITAS as c on c.Id_Cita = p.Id_Cita
		where (@sucursal = 0 or p.Id_Sucursal = @sucursal or @expediente <> 0)
			and (@texto is null or e.Nombres + ' ' + e.Apellidos like '%' + @texto + '%' or e.Documento like '%' + @texto + '%'
				 or e.Celular like '%' + @texto + '%')
		order by p.FechaPago, p.Id_factura
		return
	end

	/* 7: usar un pago adelantado en una cita activa del mismo paciente (@factura 0 = el pendiente más antiguo) */
	if @accion = 7
	begin
		declare @expU bigint, @procU bit
		select @expU = c.Id_Expediente_fk, @procU = ec.Procesos
		from EXP_CITAS as c inner join CAT_ESTADOSCITAS as ec on ec.Id_Estado = c.Id_EstadoCita_fk
		where c.Id_Cita = @cita
		if @expU is null THROW 50601, 'La cita no existe.', 1;
		if ISNULL(@procU, 0) = 0 THROW 50602, 'La cita está cancelada, anulada o finalizada.', 1;
		if exists (select 1 from EXP_PROCEDIMIENTOS where Id_Cita_FK = @cita and Estado = 'F')
			THROW 50603, 'La cita ya fue atendida.', 1;
		if exists (select 1 from CAJ_FACTURAS where Id_Cita_FK = @cita and Anticipo = 1 and MontoLibre = 0 and Estado = 1)
			THROW 50604, 'La cita ya está pagada por adelantado.', 1;
		if exists (select 1 from dbo.CAJ_FN_PagosAdelantados(@expU) where Id_Cita = @cita)
			THROW 50607, 'La cita ya usará un pago adelantado del paciente.', 1;

		declare @pago bigint = (select top 1 Id_factura from dbo.CAJ_FN_PagosAdelantados(@expU)
								where Id_Cita is null and (@factura = 0 or Id_factura = @factura) order by FechaPago, Id_factura)
		if @pago is null THROW 50613, 'El paciente no tiene pagos adelantados pendientes de agendar.', 1;

		BEGIN TRANSACTION;
		-- un anticipo de la cita creado y no pagado ya no hace falta
		delete d from CAJ_FACTURASDETALLES as d inner join CAJ_FACTURAS as f on f.Id_factura = d.Id_Factura_FK
		where f.Id_Cita_FK = @cita and f.Anticipo = 1 and f.Estado = 0
			and not exists (select 1 from FAC_DTE_DOCUMENTOS where Id_Factura_FK = f.Id_factura)
		delete f from CAJ_FACTURAS as f
		where f.Id_Cita_FK = @cita and f.Anticipo = 1 and f.Estado = 0
			and not exists (select 1 from FAC_DTE_DOCUMENTOS where Id_Factura_FK = f.Id_factura)
		update CAJ_FACTURAS set Id_Cita_FK = @cita, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_factura = @pago
		COMMIT TRANSACTION;

		select @pago as Id_Factura
		return
	end

	/* 8: la cita ya no usará el pago adelantado (vuelve a pendiente de agendar) */
	if @accion = 8
	begin
		declare @quitado bigint = (select top 1 f.Id_factura from CAJ_FACTURAS as f
								   where f.Id_Cita_FK = @cita and f.Anticipo = 1 and f.MontoLibre = 1 and f.Estado = 1)
		if @quitado is null THROW 50614, 'La cita no tiene un pago adelantado asignado.', 1;
		if exists (select 1 from EXP_PROCEDIMIENTOS where Id_Cita_FK = @cita and Estado = 'F')
			THROW 50603, 'La cita ya fue atendida.', 1;
		update CAJ_FACTURAS set Id_Cita_FK = NULL, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_factura = @quitado
		select @quitado as Id_Factura
		return
	end;

	THROW 50699, 'Acción no válida.', 1;
END
GO

/* #####################################################################
   8/35  Registros\sql\EXP_Procedimientos_Atencion.sql
   ##################################################################### */
PRINT N'>> 8/35 Registros\sql\EXP_Procedimientos_Atencion.sql';
GO
/* =====================================================================
   DPieCenter - Atención de procedimientos (Registros/frm_Procedimientos.aspx)
   y pantalla de turnos para pacientes (Registros/frm_TurnosPacientes.aspx).

   Estados de EXP_PROCEDIMIENTOS.Estado:
     'S' en sala de espera (creado al agendar en la hora en curso, EXP_SP_Citas_ProcedimientoEnCurso)
     'I' en atención   'F' finalizado   'C' cancelado   'R' reprogramado

   Reemplaza a los SP que llamaba la versión anterior de la pantalla y que no existen en la base
   (EXP_SP_EstatusUpdate, EXP_SP_CitaProcessUpdate, EXP_SP_ProcessProfetionalUpdate).
   Los errores de negocio se lanzan con THROW 5002x y llegan como mensaje a la pantalla.
   Script idempotente: se puede ejecutar varias veces.
   ===================================================================== */
SET NOCOUNT ON;
GO

/* ---------- Inicio y fin del procedimiento con fecha y hora ----------
   En algunas bases InicioProcedimiento y FinalProcedimiento son "time" (solo la hora): la atención que queda abierta
   de un día a otro pierde la fecha y los SP de abajo no compilan (CAST(time as date)). Se convierten a datetime
   una sola vez y a los registros existentes se les pone la fecha del procedimiento. */
IF EXISTS (SELECT 1 FROM sys.columns c JOIN sys.types t ON t.user_type_id = c.user_type_id
           WHERE c.object_id = OBJECT_ID('dbo.EXP_PROCEDIMIENTOS') AND c.name = 'InicioProcedimiento' AND t.name = 'time')
    ALTER TABLE dbo.EXP_PROCEDIMIENTOS ALTER COLUMN InicioProcedimiento datetime NOT NULL;
GO
IF EXISTS (SELECT 1 FROM sys.columns c JOIN sys.types t ON t.user_type_id = c.user_type_id
           WHERE c.object_id = OBJECT_ID('dbo.EXP_PROCEDIMIENTOS') AND c.name = 'FinalProcedimiento' AND t.name = 'time')
    ALTER TABLE dbo.EXP_PROCEDIMIENTOS ALTER COLUMN FinalProcedimiento datetime NULL;
GO
/* ---------- Estados permitidos ----------
   La base de producción tiene un CHECK que solo acepta 'I', 'F', 'S': cancelar ('C') o reprogramar ('R')
   fallaba con "The UPDATE statement conflicted with the CHECK constraint". Se reemplaza por uno con todos los estados. */
DECLARE @ck sysname, @sql nvarchar(400);
DECLARE ck CURSOR LOCAL FAST_FORWARD FOR
    SELECT cc.name FROM sys.check_constraints AS cc
        INNER JOIN sys.columns AS c ON c.object_id = cc.parent_object_id AND c.column_id = cc.parent_column_id
    WHERE cc.parent_object_id = OBJECT_ID('dbo.EXP_PROCEDIMIENTOS') AND c.name = 'Estado'
      AND cc.name <> 'CK_EXP_PROCEDIMIENTOS_Estado';
OPEN ck;
FETCH NEXT FROM ck INTO @ck;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'ALTER TABLE dbo.EXP_PROCEDIMIENTOS DROP CONSTRAINT ' + QUOTENAME(@ck);
    EXEC sys.sp_executesql @sql;
    FETCH NEXT FROM ck INTO @ck;
END
CLOSE ck; DEALLOCATE ck;
IF OBJECT_ID('dbo.CK_EXP_PROCEDIMIENTOS_Estado', 'C') IS NULL
    ALTER TABLE dbo.EXP_PROCEDIMIENTOS WITH CHECK
        ADD CONSTRAINT CK_EXP_PROCEDIMIENTOS_Estado CHECK (Estado IN ('S', 'I', 'F', 'C', 'R'));
GO

-- Registros que quedaron con 1900-01-01 (solo hora): se les suma la fecha del procedimiento
UPDATE dbo.EXP_PROCEDIMIENTOS
   SET InicioProcedimiento = DATEADD(DAY, DATEDIFF(DAY, '19000101', Fecha), InicioProcedimiento)
 WHERE YEAR(InicioProcedimiento) < 2000 AND Fecha IS NOT NULL;
UPDATE dbo.EXP_PROCEDIMIENTOS
   SET FinalProcedimiento = DATEADD(DAY, DATEDIFF(DAY, '19000101', Fecha), FinalProcedimiento)
 WHERE FinalProcedimiento IS NOT NULL AND YEAR(FinalProcedimiento) < 2000 AND Fecha IS NOT NULL;
GO

CREATE OR ALTER PROCEDURE [dbo].[EXP_SP_Procedimientos_Atencion]
	 @accion        int
	,@especialista  bigint = 0
	,@cita          bigint = 0
	,@procedimiento bigint = 0
	,@expediente    bigint = 0
	,@item          bigint = 0
	,@texto         varchar(max) = null
	,@fechaInicio   datetime2 = null
	,@fechaFin      datetime2 = null
	,@user          varchar(20) = null
	,@usuarioEsp    bigint = 0      -- especialista del usuario que opera: solo puede trabajar sus citas (0 = sin restricción)
	,@sucursal      int = 0         -- listas (2 y 14): solo la sucursal indicada (0 = todas)
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	declare @ahora datetime = GETDATE()
	declare @hoy date = CAST(@ahora as date)
	declare @enProceso  bigint = (select top 1 Id_Estado from CAT_ESTADOSCITAS where Accion = 1 order by Id_Estado)        -- 4
	declare @finalizada bigint = (select top 1 Id_Estado from CAT_ESTADOSCITAS where Finalizada = 1 order by Id_Estado)    -- 6
	declare @cancelada  bigint = (select top 1 Id_Estado from CAT_ESTADOSCITAS where Cancelada = 1 order by Id_Estado)     -- 3
	declare @reprogramada bigint = 5, @activa bigint = 1

	/* 1: especialista asociado al usuario del sistema */
	if @accion = 1
	begin
		select Id_Especialista, Descripcion
		from CAT_ESPECIALISTAS
		where UsaurioSystem = @user and IsActivo = 1
		return
	end

	/* 2: cola del día (citas activas de hoy), @especialista = 0 para todos */
	if @accion = 2
	begin
		select
			c.Id_Cita
			,ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2)) as FechaInicio
			,c.FechaFin
			,c.Id_Especialista_fk as Id_Especialista
			,s.Descripcion as Especialista
			-- nombre completo del especialista (el de su usuario del sistema) para el audio de la pantalla de turnos
			,ISNULL(NULLIF(LTRIM(RTRIM(ISNULL(us.Nombres, '') + ' ' + ISNULL(us.Apellidos, ''))), ''), s.Descripcion) as EspecialistaCompleto
			,c.Id_Expediente_fk as Id_Expediente
			,LTRIM(RTRIM(e.Nombres)) as Nombres
			,LTRIM(RTRIM(e.Apellidos)) as Apellidos
			,e.FechaNacimiento
			,tc.Descripcion as TipoCita
			,ec.Descripcion as EstadoCita
			,ISNULL(p.Id_Procedimiento, 0) as Id_Procedimiento
			,ISNULL(p.Estado, '') as Estado
			,p.InicioProcedimiento
			,p.FechaCrea as RegistroProcedimiento      -- llegada a sala cuando Estado = 'S'
			,ISNULL(STUFF((select ', ' + ct.Descripcion
						   from EXP_CITASTRATAMIENTOS as ct
						   where ct.Id_Cita_FK = c.Id_Cita
						   for xml path(''), type).value('.', 'varchar(max)'), 1, 2, ''), '') as Tratamientos
		from EXP_CITAS as c
			inner join EXP_EXPEDIENTES as e on e.Id_Expediente = c.Id_Expediente_fk
			inner join CAT_ESPECIALISTAS as s on s.Id_Especialista = c.Id_Especialista_fk
			left join Sys_Usuarios as us on us.Id_Usuario = s.UsaurioSystem
			inner join CAT_ESTADOSCITAS as ec on ec.Id_Estado = c.Id_EstadoCita_fk
			left join CAT_TIPOSCITAS as tc on tc.Id_TipoCita = c.Id_TipoCita_FK
			outer apply (select top 1 Id_Procedimiento, Estado, InicioProcedimiento, FechaCrea
						 from EXP_PROCEDIMIENTOS
						 where Id_Cita_FK = c.Id_Cita and Estado <> 'R'      -- 'R': de un horario anterior de la cita
						 order by Id_Procedimiento desc) as p
		where CAST(ISNULL(c.FechaInicio, c.Fecha) as date) = @hoy
			and ec.Procesos = 1          -- vigentes: Activa, Confirmada, En proceso y Reprogramada
			and ISNULL(p.Estado, '') not in ('F', 'C')
			and (@especialista = 0 or c.Id_Especialista_fk = @especialista)
			and (@sucursal = 0 or c.Id_Sucursal_FK = @sucursal)
		order by ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2)), c.Id_Cita
		return
	end

	/* 3: procedimiento + cita + paciente */
	if @accion = 3
	begin
		select
			p.Id_Procedimiento
			,p.Id_Cita_FK as Id_Cita
			,p.Id_Expediente_fk as Id_Expediente
			,p.Estado
			,p.InicioProcedimiento
			,c.FechaInicio
			,c.FechaFin
			,ISNULL(c.Comentarios, '') as Comentarios
			,ISNULL(p.Diagnostico, '') as Diagnostico
			,p.Id_Especialista_fk as Id_Especialista
			,s.Descripcion as Especialista
			,ISNULL(tc.Descripcion, '') as TipoCita
			,LTRIM(RTRIM(e.Nombres + ' ' + e.Apellidos)) as Paciente
			,ISNULL(e.Documento, '') as Documento
			,e.FechaNacimiento
			,ISNULL(sx.Descripcion, '') as Sexo
			,ISNULL(e.Celular, '') as Celular
			,ISNULL(e.Email, '') as Email
			,ISNULL(e.PersonaEmergencia, '') as PersonaEmergencia
			,ISNULL(e.TelefonoEmergencia, '') as TelefonoEmergencia
			,LTRIM(ISNULL(e.Direccion, '') + ISNULL(', ' + m.Descripcion, '') + ISNULL(', ' + d.Descripcion, '')) as Direccion
		from EXP_PROCEDIMIENTOS as p
			inner join EXP_EXPEDIENTES as e on e.Id_Expediente = p.Id_Expediente_fk
			left join EXP_CITAS as c on c.Id_Cita = p.Id_Cita_FK
			left join CAT_ESPECIALISTAS as s on s.Id_Especialista = p.Id_Especialista_fk
			left join CAT_TIPOSCITAS as tc on tc.Id_TipoCita = p.Id_TipoCita_FK
			left join CAT_SEXOS as sx on sx.Id_Sexos = e.Id_Sexo_fk
			left join CAT_MUNICIPIOS as m on m.Id_Municipio = e.Id_Municipio_fk
			left join CAT_DEPARTAMENTOS as d on d.Id_Departamento = m.Id_Departamento_fk
		where p.Id_Procedimiento = @procedimiento
		return
	end

	/* 4: tratamientos del procedimiento */
	if @accion = 4
	begin
		select Id, Id_Tratamiento_FK as Id_Tratamiento, Descripcion, ISNULL(Valor, 0) as Valor
		from EXP_PROCEDIMIENTOSTRATAMIENTOS
		where Id_Procedimiento_FK = @procedimiento
		order by Id
		return
	end

	/* 5: historial del paciente (últimos 20 procedimientos finalizados) */
	if @accion = 5
	begin
		select top 20
			p.Id_Procedimiento
			-- la versión anterior guardaba solo la hora en FinalProcedimiento (1900-01-01 hh:mm)
			,case when p.FinalProcedimiento is null then CAST(p.Fecha as datetime2)
				  when YEAR(p.FinalProcedimiento) < 2000 and p.Fecha is not null
					then DATEADD(DAY, DATEDIFF(DAY, '19000101', p.Fecha), p.FinalProcedimiento)
				  else p.FinalProcedimiento end as Fecha
			,ISNULL(s.Descripcion, '') as Especialista
			,ISNULL(p.Diagnostico, '') as Diagnostico
			,ISNULL(STUFF((select ', ' + t.Descripcion
						   from EXP_PROCEDIMIENTOSTRATAMIENTOS as t
						   where t.Id_Procedimiento_FK = p.Id_Procedimiento
						   for xml path(''), type).value('.', 'varchar(max)'), 1, 2, ''), '') as Tratamientos
			,ISNULL((select SUM(t.Valor) from EXP_PROCEDIMIENTOSTRATAMIENTOS as t
					 where t.Id_Procedimiento_FK = p.Id_Procedimiento), 0) as Total
		from EXP_PROCEDIMIENTOS as p
			left join CAT_ESPECIALISTAS as s on s.Id_Especialista = p.Id_Especialista_fk
		where p.Id_Expediente_fk = @expediente
			and p.Estado = 'F'
			and p.Id_Procedimiento <> @procedimiento
		order by p.Fecha desc, p.Id_Procedimiento desc
		return
	end

	/* 6: llamar / iniciar la atención de una cita. Devuelve el Id del procedimiento */
	if @accion = 6
	begin
		declare @esp bigint, @estadoCita bigint, @fechaCita date
		select @esp = c.Id_Especialista_fk, @estadoCita = c.Id_EstadoCita_fk
			  ,@fechaCita = CAST(ISNULL(c.FechaInicio, c.Fecha) as date)
		from EXP_CITAS as c where c.Id_Cita = @cita

		if @esp is null
			THROW 50020, 'La cita no existe.', 1;
		if @usuarioEsp > 0 and @esp <> @usuarioEsp
			THROW 50024, 'La cita no está asignada a su usuario.', 1;
		if @fechaCita <> @hoy
			THROW 50021, 'Solo se pueden atender citas del día de hoy.', 1;
		-- una cita reprogramada sigue vigente y se puede llamar
		if @estadoCita in (@cancelada, @finalizada, 7)
			THROW 50022, 'La cita ya no está activa (cancelada, finalizada o anulada).', 1;

		BEGIN TRANSACTION;

		select @procedimiento = Id_Procedimiento
		from EXP_PROCEDIMIENTOS with (updlock, holdlock)
		where Id_Cita_FK = @cita and Estado in ('S', 'I')

		if exists (select 1 from EXP_PROCEDIMIENTOS with (updlock, holdlock)
				   where Id_Especialista_fk = @esp and Estado = 'I'
					 and CAST(InicioProcedimiento as date) = @hoy
					 and Id_Procedimiento <> ISNULL(@procedimiento, 0))
			THROW 50023, 'El especialista ya tiene un paciente en atención. Finalícelo antes de llamar al siguiente.', 1;

		if @procedimiento is null or @procedimiento = 0
		begin
			insert into EXP_PROCEDIMIENTOS
				(Id_Expediente_FK,Id_TipoCita_FK,Id_Especialista_FK,Id_Cita_FK,Id_Horario_FK
				,Id_Horariofin_FK,InicioProcedimiento,Id_EstadoCita_fk,Fecha,Estado,UsuarioCrea,FechaCrea)
			select
				Id_Expediente_fk,Id_TipoCita_FK,Id_Especialista_fk,Id_Cita,Id_Horario_fk
				,Id_HorarioFin_FK,@ahora,@enProceso,@hoy,'I',@user,@ahora
			from EXP_CITAS
			where Id_Cita = @cita

			set @procedimiento = SCOPE_IDENTITY()

			insert into EXP_PROCEDIMIENTOSTRATAMIENTOS
				(Id_Procedimiento_FK,Id_Tratamiento_FK,Descripcion,Valor,Estatus,UsuarioCrea,FechaCreacion)
			select
				@procedimiento,ct.Id_Tratamiento_FK,ISNULL(NULLIF(ct.Descripcion,''),ISNULL(t.Descripcion,'')),ct.Valor,1,@user,@ahora
			from EXP_CITASTRATAMIENTOS as ct
				left join CAT_TRATAMIENTOS as t on t.Id_Tratamientos = ct.Id_Tratamiento_FK
			where ct.Id_Cita_FK = @cita
		end
		else
			update EXP_PROCEDIMIENTOS set
				Estado = 'I'
				,InicioProcedimiento = case when Estado = 'S' then @ahora else InicioProcedimiento end
				,Id_EstadoCita_fk = @enProceso
				,UsuarioModifica = @user
				,FechaModifica = @ahora
			where Id_Procedimiento = @procedimiento

		update EXP_CITAS set
			Id_EstadoCita_fk = @enProceso
			,UsuarioModifica = @user
			,FechaModifica = @ahora
		where Id_Cita = @cita

		COMMIT TRANSACTION;

		select @procedimiento as Id_Procedimiento
		return
	end

	/* 14: procedimientos abiertos de todos los especialistas (Facturacion/frm_ProcedimientosCurso.aspx).
	   Incluye los de días anteriores que quedaron sin finalizar. @especialista = 0 para todos */
	if @accion = 14
	begin
		select
			p.Id_Procedimiento
			,p.Id_Cita_FK as Id_Cita
			,p.Estado
			,p.InicioProcedimiento
			,p.FechaCrea as RegistroProcedimiento
			,ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2)) as FechaInicio
			,c.FechaFin
			,p.Id_Especialista_fk as Id_Especialista
			,ISNULL(s.Descripcion, '') as Especialista
			,p.Id_Expediente_fk as Id_Expediente
			,LTRIM(RTRIM(e.Nombres + ' ' + e.Apellidos)) as Paciente
			,ISNULL(e.Documento, '') as Documento
			,ISNULL(e.Celular, '') as Celular
			,ISNULL(tc.Descripcion, '') as TipoCita
			,ISNULL(t.Cantidad, 0) as Tratamientos
			,ISNULL(t.Total, 0) as Total
			,ISNULL(STUFF((select ', ' + pt.Descripcion
						   from EXP_PROCEDIMIENTOSTRATAMIENTOS as pt
						   where pt.Id_Procedimiento_FK = p.Id_Procedimiento
						   for xml path(''), type).value('.', 'varchar(max)'), 1, 2, ''), '') as Detalle
		from EXP_PROCEDIMIENTOS as p
			inner join EXP_EXPEDIENTES as e on e.Id_Expediente = p.Id_Expediente_fk
			left join EXP_CITAS as c on c.Id_Cita = p.Id_Cita_FK
			left join CAT_ESPECIALISTAS as s on s.Id_Especialista = p.Id_Especialista_fk
			left join CAT_TIPOSCITAS as tc on tc.Id_TipoCita = p.Id_TipoCita_FK
			-- total con el descuento vigente de cada tratamiento (CAT_TRATAMIENTOS.Descuento)
			outer apply (select COUNT(*) as Cantidad
							,SUM(ISNULL(x.Valor, 0) - ROUND(ISNULL(x.Valor, 0) * ISNULL(ct.Descuento, 0) / 100, 2)) as Total
						 from EXP_PROCEDIMIENTOSTRATAMIENTOS as x
							left join CAT_TRATAMIENTOS as ct on ct.Id_Tratamientos = x.Id_Tratamiento_FK
						 where x.Id_Procedimiento_FK = p.Id_Procedimiento) as t
		where p.Estado in ('S', 'I')
			and (@especialista = 0 or p.Id_Especialista_fk = @especialista)
			and (@sucursal = 0 or p.Id_Sucursal_FK = @sucursal)
		order by case p.Estado when 'I' then 0 else 1 end, ISNULL(p.InicioProcedimiento, p.FechaCrea)
		return
	end

	/* Las acciones siguientes trabajan sobre un procedimiento abierto (en espera o en atención) */
	declare @estadoProc char(1), @citaProc bigint, @espProc bigint
	select @estadoProc = Estado, @citaProc = Id_Cita_FK, @espProc = Id_Especialista_fk
	from EXP_PROCEDIMIENTOS where Id_Procedimiento = @procedimiento

	if @accion between 7 and 12 and (@estadoProc is null or @estadoProc not in ('S', 'I'))
		THROW 50030, 'El procedimiento ya no está abierto (fue finalizado, cancelado o reprogramado).', 1;
	if @accion between 7 and 12 and @usuarioEsp > 0 and @espProc <> @usuarioEsp
		THROW 50035, 'El procedimiento no está asignado a su usuario.', 1;

	/* 7: agregar tratamiento del catálogo (@item = Id_Tratamientos) */
	if @accion = 7
	begin
		if not exists (select 1 from CAT_TRATAMIENTOS where Id_Tratamientos = @item and IsActivo = 1)
			THROW 50031, 'El tratamiento seleccionado no está disponible.', 1;

		insert into EXP_PROCEDIMIENTOSTRATAMIENTOS
			(Id_Procedimiento_FK,Id_Tratamiento_FK,Descripcion,Valor,Estatus,UsuarioCrea,FechaCreacion)
		select @procedimiento,Id_Tratamientos,Descripcion,Precio,1,@user,@ahora
		from CAT_TRATAMIENTOS
		where Id_Tratamientos = @item

		select CAST(SCOPE_IDENTITY() as bigint) as Id
		return
	end

	/* 8: quitar tratamiento (@item = Id de EXP_PROCEDIMIENTOSTRATAMIENTOS) */
	if @accion = 8
	begin
		delete from EXP_PROCEDIMIENTOSTRATAMIENTOS
		where Id = @item and Id_Procedimiento_FK = @procedimiento

		select @@ROWCOUNT as Filas
		return
	end

	/* 9: guardar diagnóstico */
	if @accion = 9
	begin
		update EXP_PROCEDIMIENTOS set
			Diagnostico = @texto
			,UsuarioModifica = @user
			,FechaModifica = @ahora
		where Id_Procedimiento = @procedimiento

		select @procedimiento as Id_Procedimiento
		return
	end

	/* 10: finalizar. Guarda el diagnóstico y genera la factura pendiente de cobro. Devuelve el Id de la factura */
	if @accion = 10
	begin
		if @estadoProc <> 'I'
			THROW 50032, 'Inicie la atención antes de finalizar.', 1;
		if not exists (select 1 from EXP_PROCEDIMIENTOSTRATAMIENTOS where Id_Procedimiento_FK = @procedimiento)
			THROW 50033, 'Agregue al menos un tratamiento antes de finalizar.', 1;

		declare @factura bigint

		BEGIN TRANSACTION;

		update EXP_PROCEDIMIENTOS set
			Diagnostico = ISNULL(@texto, Diagnostico)
			,FinalProcedimiento = @ahora
			,Estado = 'F'
			,Id_EstadoCita_fk = @finalizada
			,UsuarioModifica = @user
			,FechaModifica = @ahora
		where Id_Procedimiento = @procedimiento

		update EXP_CITAS set
			Id_EstadoCita_fk = @finalizada
			,UsuarioModifica = @user
			,FechaModifica = @ahora
		where Id_Cita = @citaProc

		select @factura = Id_factura from CAJ_FACTURAS where Id_Procedimiento_FK = @procedimiento

		if @factura is null
		begin
			/* Cobro por adelantado (Facturacion/sql/CAJ_Anticipos.sql): el anticipo pagado de esta cita o, si no tiene,
			   el saldo a favor más antiguo del paciente (anticipo de una cita cancelada o anulada). */
			declare @expProc bigint = (select Id_Expediente_fk from EXP_PROCEDIMIENTOS where Id_Procedimiento = @procedimiento)
			declare @anticipo bigint = (select top 1 Id_factura from CAJ_FACTURAS
										where Id_Cita_FK = @citaProc and Anticipo = 1 and MontoLibre = 0 and Estado = 1 and Id_Procedimiento_FK is null order by Id_factura)
			if @anticipo is null
				set @anticipo = (select top 1 f.Id_factura from CAJ_FACTURAS as f
									inner join EXP_CITAS as c on c.Id_Cita = f.Id_Cita_FK
									inner join CAT_ESTADOSCITAS as ec on ec.Id_Estado = c.Id_EstadoCita_fk
								 where f.Id_Expediente_FK = @expProc and f.Anticipo = 1 and f.MontoLibre = 0 and f.Estado = 1 and f.Id_Procedimiento_FK is null
									and (ec.Cancelada = 1 or c.Id_EstadoCita_fk = 7)
								 order by f.Id_factura)

			-- un anticipo de esta cita que se creó y no se pagó ya no sirve
			delete d from CAJ_FACTURASDETALLES as d inner join CAJ_FACTURAS as f on f.Id_factura = d.Id_Factura_FK
			where f.Id_Cita_FK = @citaProc and f.Anticipo = 1 and f.Estado = 0
				and not exists (select 1 from FAC_DTE_DOCUMENTOS where Id_Factura_FK = f.Id_factura)
			delete f from CAJ_FACTURAS as f
			where f.Id_Cita_FK = @citaProc and f.Anticipo = 1 and f.Estado = 0
				and not exists (select 1 from FAC_DTE_DOCUMENTOS where Id_Factura_FK = f.Id_factura)

			-- tratamientos del procedimiento que el anticipo no cubre (se comparan por tratamiento, uno a uno)
			declare @porCobrar table (Fila int identity(1,1), Id_Tratamiento bigint null, Descripcion varchar(500), Valor float)
			insert @porCobrar (Id_Tratamiento, Descripcion, Valor)
			select p.Id_Tratamiento_FK, p.Descripcion, p.Valor
			from (select Id_Tratamiento_FK, Descripcion, Valor, ROW_NUMBER() over (partition by Id_Tratamiento_FK order by Id) as n
				  from EXP_PROCEDIMIENTOSTRATAMIENTOS where Id_Procedimiento_FK = @procedimiento) as p
			where @anticipo is null
				or not exists (select 1 from (select Id_tratamiento_FK, ROW_NUMBER() over (partition by Id_tratamiento_FK order by Id_detalle) as n
											  from CAJ_FACTURASDETALLES where Id_Factura_FK = @anticipo) as a
							   where a.Id_tratamiento_FK = p.Id_Tratamiento_FK and a.n = p.n)

			if @anticipo is not null
				update CAJ_FACTURAS set Id_Procedimiento_FK = @procedimiento, Id_Cita_FK = @citaProc, UsuarioModifica = @user, FechaModifica = @ahora
				where Id_factura = @anticipo

			/* Pago adelantado sin cita (monto libre, CAJ_Anticipos.sql) que se usará en esta cita: se descuenta del valor de los
			   tratamientos por cobrar (con su % de descuento) hasta donde alcance. Lo cubierto ya no se cobra; si un tratamiento
			   queda cubierto en parte se cobra solo la diferencia. Si sobra, el pago vuelve a "pendiente de agendar". */
			declare @libre bigint = (select top 1 Id_factura from CAJ_FACTURAS
									 where Id_Cita_FK = @citaProc and Anticipo = 1 and MontoLibre = 1 and Estado = 1 order by Id_factura)
			if @libre is not null
			begin
				declare @credito decimal(12,2) = ISNULL((select Disponible from dbo.CAJ_FN_PagosAdelantados(@expProc) where Id_factura = @libre), 0)
				declare @usado decimal(12,2) = 0, @fila int = 1, @filas int = (select MAX(Fila) from @porCobrar)
				declare @valorF decimal(12,2), @pctF decimal(9,4), @netoF decimal(12,2), @cubre decimal(12,2)
				while @credito > 0 and @fila <= ISNULL(@filas, 0)
				begin
					select @valorF = CAST(ROUND(pc.Valor, 2) as decimal(12,2)), @pctF = ISNULL(t.Descuento, 0)
					from @porCobrar as pc left join CAT_TRATAMIENTOS as t on t.Id_Tratamientos = pc.Id_Tratamiento
					where pc.Fila = @fila
					if @@ROWCOUNT > 0
					begin
						set @netoF = @valorF - ROUND(@valorF * @pctF / 100, 2)
						set @cubre = case when @credito >= @netoF then @netoF else @credito end
						if @cubre >= @netoF
							delete from @porCobrar where Fila = @fila
						else if @cubre > 0
							-- queda por cobrar el resto; el % del tratamiento se vuelve a aplicar al cobrar
							update @porCobrar set Valor = ROUND((@netoF - @cubre) / (1 - @pctF / 100), 2)
								,Descripcion = LEFT(Descripcion + ' (abono pago adelantado $' + CONVERT(varchar(20), @cubre) + ')', 500)
							where Fila = @fila
						set @credito = @credito - @cubre
						set @usado = @usado + @cubre
					end
					set @fila = @fila + 1
				end
				if @usado > 0
					insert into CAJ_ANTICIPOS_USOS (Id_FacturaAnticipo_FK, Id_Procedimiento_FK, Id_Cita_FK, Monto, UsuarioCrea, FechaCrea)
					values (@libre, @procedimiento, @citaProc, @usado, @user, @ahora)
				-- el pago ya no queda ligado a la cita: si le queda saldo, vuelve a pendiente de agendar
				update CAJ_FACTURAS set Id_Cita_FK = NULL, UsuarioModifica = @user, FechaModifica = @ahora where Id_factura = @libre
				if @anticipo is null set @anticipo = @libre      -- si todo quedó cubierto, se devuelve el pago
			end

			if exists (select 1 from @porCobrar)
			begin
				insert into CAJ_FACTURAS
					(FechaFactura,Id_Procedimiento_FK,Id_Expediente_FK,Estado,UsuarioCrea,FechaCrea,Id_Cita_FK)
				select @hoy,Id_Procedimiento,Id_Expediente_fk,0,@user,@ahora,@citaProc
				from EXP_PROCEDIMIENTOS
				where Id_Procedimiento = @procedimiento

				set @factura = SCOPE_IDENTITY()

				insert into CAJ_FACTURASDETALLES
					(Id_Factura_FK,Id_tratamiento_FK,Descripion,Valor,UsuarioCrea,FechaCrea)
				select @factura,Id_Tratamiento,Descripcion,Valor,@user,@ahora
				from @porCobrar
			end
			else
				set @factura = @anticipo      -- todo estaba pagado por adelantado: no queda nada pendiente
		end

		COMMIT TRANSACTION;

		select @factura as Id_Factura
		return
	end

	/* 11: cancelar la atención y la cita (@texto = motivo) */
	if @accion = 11
	begin
		BEGIN TRANSACTION;

		update EXP_PROCEDIMIENTOS set
			Estado = 'C'
			,Id_EstadoCita_fk = @cancelada
			,FinalProcedimiento = @ahora
			,Comentarios = NULLIF(LTRIM(RTRIM(@texto)), '')
			,UsuarioModifica = @user
			,FechaModifica = @ahora
		where Id_Procedimiento = @procedimiento

		update EXP_CITAS set
			Id_EstadoCita_fk = @cancelada
			,UsuarioModifica = @user
			,FechaModifica = @ahora
		where Id_Cita = @citaProc

		COMMIT TRANSACTION;

		select @procedimiento as Id_Procedimiento
		return
	end

	/* 12: cambiar de especialista (procedimiento y cita) */
	if @accion = 12
	begin
		if not exists (select 1 from CAT_ESPECIALISTAS where Id_Especialista = @especialista and IsActivo = 1)
			THROW 50034, 'El especialista seleccionado no está activo.', 1;

		BEGIN TRANSACTION;

		update EXP_PROCEDIMIENTOS set
			Id_Especialista_fk = @especialista
			,UsuarioModifica = @user
			,FechaModifica = @ahora
		where Id_Procedimiento = @procedimiento

		update EXP_CITAS set
			Id_Especialista_fk = @especialista
			,UsuarioModifica = @user
			,FechaModifica = @ahora
		where Id_Cita = @citaProc

		COMMIT TRANSACTION;

		select @procedimiento as Id_Procedimiento
		return
	end

	/* 13: reprogramar la cita (@cita, @fechaInicio, @fechaFin). Cambia la fecha y hora de la MISMA cita y la deja en
	   "Reprogramada" (vigente: se llama en Procedimientos). Antes creaba una cita nueva y escondía la anterior.
	   El procedimiento en sala o en atención queda como reprogramado ('R'). Devuelve el Id de la cita. */
	if @accion = 13
	begin
		declare @espR bigint, @estadoR bigint, @nueva bigint, @minutos int
		select @espR = Id_Especialista_fk, @estadoR = Id_EstadoCita_fk
			  ,@minutos = case when FechaFin > FechaInicio then DATEDIFF(MINUTE, FechaInicio, FechaFin) else 60 end
		from EXP_CITAS where Id_Cita = @cita

		-- sin @fechaFin se conserva la duración de la cita original
		if @fechaFin is null and @fechaInicio is not null
			set @fechaFin = DATEADD(MINUTE, @minutos, @fechaInicio)

		if @espR is null
			THROW 50040, 'La cita no existe.', 1;
		if @usuarioEsp > 0 and @espR <> @usuarioEsp
			THROW 50045, 'La cita no está asignada a su usuario.', 1;
		if @estadoR in (@cancelada, @finalizada, 7)
			THROW 50041, 'La cita ya no está activa (cancelada, finalizada o anulada).', 1;
		if @fechaInicio is null or @fechaFin is null or @fechaFin <= @fechaInicio
			THROW 50042, 'La nueva fecha y hora no son válidas.', 1;
		if @fechaInicio < DATEADD(MINUTE, -5, @ahora)
			THROW 50043, 'La nueva fecha y hora ya pasaron.', 1;

		BEGIN TRANSACTION;

		if exists (select 1
				   from EXP_CITAS as c with (updlock, holdlock)
					   inner join CAT_ESTADOSCITAS as ec on ec.Id_Estado = c.Id_EstadoCita_fk
				   where c.Id_Especialista_fk = @espR
					 and c.Id_Cita <> @cita
					 and ec.Procesos = 1
					 and c.FechaInicio < @fechaFin
					 and ISNULL(c.FechaFin, DATEADD(HOUR, 1, c.FechaInicio)) > @fechaInicio)
			THROW 50044, 'El especialista ya tiene una cita en ese horario. Elija otra fecha u hora.', 1;

		set @nueva = @cita

		update EXP_PROCEDIMIENTOS set
			Estado = 'R'
			,Id_EstadoCita_fk = @reprogramada
			,UsuarioModifica = @user
			,FechaModifica = @ahora
		where Id_Cita_FK = @cita and Estado in ('S', 'I')

		update EXP_CITAS set
			Id_EstadoCita_fk = @reprogramada
			,Fecha = CAST(@fechaInicio as date)
			,FechaInicio = @fechaInicio
			,FechaFin = @fechaFin
			,Id_Horario_fk = dbo.EXP_FN_HorarioCita(CAST(@fechaInicio as time))
			,Id_HorarioFin_FK = dbo.EXP_FN_HorarioCita(CAST(DATEADD(MINUTE, -1, @fechaFin) as time))
			,UsuarioModifica = @user
			,FechaModifica = @ahora
		where Id_Cita = @cita

		-- Si la nueva cita cae en la hora en curso queda en sala de espera, igual que al agendar
		declare @tmp table (Id_Procedimiento bigint)
		insert into @tmp exec dbo.EXP_SP_Citas_ProcedimientoEnCurso @cita = @nueva, @user = @user

		COMMIT TRANSACTION;

		select @nueva as Id_Cita
		return
	end;

	THROW 50099, 'Acción no válida.', 1;
END
GO

/* #####################################################################
   9/35  Registros\sql\EXP_Procedimientos_Cierre.sql
   ##################################################################### */
PRINT N'>> 9/35 Registros\sql\EXP_Procedimientos_Cierre.sql';
GO
/* =====================================================================
   DPieCenter - Cierre de procesos abiertos de meses anteriores

   Procedimientos en sala ('S') o en atención ('I') con fecha anterior al mes en curso:
     - Si la cita ya está cancelada  -> 'C' cancelado (equivale a lo que hace Cancelar en Facturación > Procedimientos).
     - Si no                          -> 'F' finalizado y la cita pasa a Finalizada.
   No genera facturas (son atenciones de meses cerrados). FinalProcedimiento queda con la hora de inicio
   si no tenía. Se puede ejecutar varias veces: solo toca los que sigan abiertos.
   Requiere el CHECK CK_EXP_PROCEDIMIENTOS_Estado (EXP_Procedimientos_Atencion.sql).
   ===================================================================== */
SET NOCOUNT ON;
GO

DECLARE @mes date = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1);
DECLARE @ahora datetime = GETDATE();
DECLARE @finalizada bigint = (SELECT TOP 1 Id_Estado FROM dbo.CAT_ESTADOSCITAS WHERE Finalizada = 1 ORDER BY Id_Estado);
DECLARE @cancelada  bigint = (SELECT TOP 1 Id_Estado FROM dbo.CAT_ESTADOSCITAS WHERE Cancelada = 1 ORDER BY Id_Estado);
DECLARE @c TABLE (Id_Procedimiento bigint PRIMARY KEY, Id_Cita bigint NULL, Cancelada bit NOT NULL);

INSERT @c (Id_Procedimiento, Id_Cita, Cancelada)
SELECT p.Id_Procedimiento, p.Id_Cita_FK, CASE WHEN ISNULL(ec.Cancelada, 0) = 1 THEN 1 ELSE 0 END
FROM dbo.EXP_PROCEDIMIENTOS AS p
    LEFT JOIN dbo.EXP_CITAS AS c ON c.Id_Cita = p.Id_Cita_FK
    LEFT JOIN dbo.CAT_ESTADOSCITAS AS ec ON ec.Id_Estado = c.Id_EstadoCita_fk
WHERE p.Estado IN ('S', 'I') AND p.Fecha < @mes;

DECLARE @propia bit = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
BEGIN TRY
    IF @propia = 1 BEGIN TRANSACTION;

    UPDATE p SET
         Estado = CASE WHEN x.Cancelada = 1 THEN 'C' ELSE 'F' END
        ,Id_EstadoCita_fk = CASE WHEN x.Cancelada = 1 THEN @cancelada ELSE @finalizada END
        ,FinalProcedimiento = ISNULL(p.FinalProcedimiento, p.InicioProcedimiento)
        ,UsuarioModifica = 'sistema'
        ,FechaModifica = @ahora
    FROM dbo.EXP_PROCEDIMIENTOS AS p
        INNER JOIN @c AS x ON x.Id_Procedimiento = p.Id_Procedimiento;

    UPDATE c SET
         Id_EstadoCita_fk = @finalizada
        ,UsuarioModifica = 'sistema'
        ,FechaModifica = @ahora
    FROM dbo.EXP_CITAS AS c
        INNER JOIN @c AS x ON x.Id_Cita = c.Id_Cita
    WHERE x.Cancelada = 0;

    IF @propia = 1 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @propia = 1 AND @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH

DECLARE @f int = (SELECT COUNT(*) FROM @c WHERE Cancelada = 0), @k int = (SELECT COUNT(*) FROM @c WHERE Cancelada = 1);
PRINT N'Procesos de meses anteriores cerrados: ' + CAST(@f AS nvarchar(10)) + N' finalizados, ' + CAST(@k AS nvarchar(10)) + N' cancelados.';
GO

/* #####################################################################
   10/35  Registros\sql\EXP_Reclamos.sql
   ##################################################################### */
PRINT N'>> 10/35 Registros\sql\EXP_Reclamos.sql';
GO
/* =====================================================================
   DPieCenter - Reclamos de pacientes (Registros/frm_ListaExpedientes.aspx, ficha del expediente)

   La aplicación registra el reclamo sobre un procedimiento del paciente (SqlProcess.mtdEXP_Reclamos envía
   @procedimiento y @user). Algunas bases tienen la estructura anterior de EXP_Reclamos (Id_Expediente,
   Id_Especialista, sin procedimiento): se renombran las columnas (los datos se conservan) y se agrega
   Id_Procedimiento_FK. Script idempotente.
   ===================================================================== */
SET NOCOUNT ON;
GO

IF OBJECT_ID('dbo.EXP_Reclamos', 'U') IS NULL
    CREATE TABLE dbo.EXP_Reclamos (
        Id_Reclamo          bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_EXP_Reclamos PRIMARY KEY,
        Id_Expediente_fk    bigint        NOT NULL,
        Id_Especialista_FK  bigint        NOT NULL,
        Id_Procedimiento_FK bigint        NULL,
        Reclamo             varchar(max)  NOT NULL,
        UsuarioCrea         varchar(20)   NOT NULL,
        FechaCrea           datetime      NOT NULL,
        UsuarioModifica     varchar(20)   NULL,
        FechaModifica       datetime      NULL
    );
GO
IF COL_LENGTH('dbo.EXP_Reclamos', 'Id_Expediente_fk') IS NULL AND COL_LENGTH('dbo.EXP_Reclamos', 'Id_Expediente') IS NOT NULL
    EXEC sp_rename 'dbo.EXP_Reclamos.Id_Expediente', 'Id_Expediente_fk', 'COLUMN';
GO
IF COL_LENGTH('dbo.EXP_Reclamos', 'Id_Especialista_FK') IS NULL AND COL_LENGTH('dbo.EXP_Reclamos', 'Id_Especialista') IS NOT NULL
    EXEC sp_rename 'dbo.EXP_Reclamos.Id_Especialista', 'Id_Especialista_FK', 'COLUMN';
GO
IF COL_LENGTH('dbo.EXP_Reclamos', 'Id_Procedimiento_FK') IS NULL
    ALTER TABLE dbo.EXP_Reclamos ADD Id_Procedimiento_FK bigint NULL;
GO
/* Aviso (campana) al especialista: la garantía queda "no vista" hasta que él la abre */
IF COL_LENGTH('dbo.EXP_Reclamos', 'Visto') IS NULL
    ALTER TABLE dbo.EXP_Reclamos ADD Visto bit NOT NULL CONSTRAINT DF_EXP_Reclamos_Visto DEFAULT (0);
IF COL_LENGTH('dbo.EXP_Reclamos', 'FechaVisto') IS NULL
    ALTER TABLE dbo.EXP_Reclamos ADD FechaVisto datetime NULL, UsuarioVisto varchar(20) NULL;
GO

/* @accion 1 nuevo | 2 modificar | 3 eliminar | 4 todos | 5 uno | 6 del expediente
           7 no vistas (@especialista 0 = de todos) | 8 marcar como vistas las del especialista (@id > 0: solo esa) */
CREATE OR ALTER PROCEDURE [dbo].[EXP_SP_Reclamos]
     @id            bigint = 0
    ,@expediente    bigint = 0
    ,@especialista  bigint = 0
    ,@procedimiento bigint = 0
    ,@reclamo       varchar(2500) = NULL
    ,@user          varchar(20) = NULL
    ,@usuario       varchar(20) = NULL      -- nombre del parámetro en la versión anterior
    ,@accion        int
AS
BEGIN TRY
    SET NOCOUNT ON;
    SET @user = COALESCE(@user, @usuario);

    IF @accion = 1
    BEGIN
        INSERT INTO EXP_Reclamos (Id_Expediente_fk, Id_Especialista_FK, Id_Procedimiento_FK, Reclamo, UsuarioCrea, FechaCrea)
        VALUES (@expediente, @especialista, NULLIF(@procedimiento, 0), @reclamo, @user, GETDATE());
        SELECT 'OK' AS resp;
    END
    ELSE IF @accion = 2
    BEGIN
        UPDATE EXP_Reclamos SET
             Id_Especialista_FK = @especialista
            ,Id_Procedimiento_FK = COALESCE(NULLIF(@procedimiento, 0), Id_Procedimiento_FK)
            ,Reclamo = @reclamo
            ,UsuarioModifica = @user
            ,FechaModifica = GETDATE()
            ,Visto = 0, FechaVisto = NULL, UsuarioVisto = NULL     -- se avisa de nuevo al especialista
        WHERE Id_Reclamo = @id;
        SELECT 'OK' AS resp;
    END
    ELSE IF @accion = 3
    BEGIN
        DELETE FROM EXP_Reclamos WHERE Id_Reclamo = @id;
        SELECT 'OK' AS resp;
    END
    ELSE IF @accion = 4
    BEGIN
        SELECT r.Id_Reclamo, e.Descripcion AS Especialista, r.Reclamo,
               ISNULL(r.UsuarioModifica, r.UsuarioCrea) AS Usuario, ISNULL(r.FechaModifica, r.FechaCrea) AS Fecha
        FROM EXP_Reclamos AS r
            INNER JOIN CAT_ESPECIALISTAS AS e ON r.Id_Especialista_FK = e.Id_Especialista;
        SELECT 'OK' AS resp;
    END
    ELSE IF @accion = 5
    BEGIN
        SELECT Id_Especialista_FK AS Id_Especialista, Id_Procedimiento_FK AS Id_Procedimiento, Reclamo
        FROM EXP_Reclamos WHERE Id_Reclamo = @id;
        SELECT 'OK' AS resp;
    END
    ELSE IF @accion = 6
    BEGIN
        SELECT r.Id_Reclamo, e.Descripcion AS Especialista, r.Reclamo, r.UsuarioCrea AS Usuario, r.FechaCrea AS Fecha
        FROM EXP_Reclamos AS r
            INNER JOIN CAT_ESPECIALISTAS AS e ON r.Id_Especialista_FK = e.Id_Especialista
        WHERE r.Id_Expediente_fk = @expediente;
        SELECT 'OK' AS resp;
    END
    ELSE IF @accion = 7
    BEGIN
        SELECT r.Id_Reclamo, r.Id_Especialista_FK AS Id_Especialista, ISNULL(s.Descripcion, '') AS Especialista
            ,r.Id_Expediente_fk AS Id_Expediente
            ,LTRIM(RTRIM(ISNULL(e.Nombres, '') + ' ' + ISNULL(e.Apellidos, ''))) AS Paciente
            ,p.Fecha AS FechaProcedimiento
            ,ISNULL(STUFF((SELECT ', ' + t.Descripcion FROM EXP_PROCEDIMIENTOSTRATAMIENTOS AS t
                           WHERE t.Id_Procedimiento_FK = r.Id_Procedimiento_FK ORDER BY t.Descripcion
                           FOR XML PATH(''), TYPE).value('.', 'varchar(max)'), 1, 2, ''), '') AS Tratamientos
            ,r.Reclamo, r.UsuarioCrea AS Usuario, ISNULL(r.FechaModifica, r.FechaCrea) AS Fecha
        FROM EXP_Reclamos AS r
            LEFT JOIN CAT_ESPECIALISTAS AS s ON s.Id_Especialista = r.Id_Especialista_FK
            LEFT JOIN EXP_EXPEDIENTES AS e ON e.Id_Expediente = r.Id_Expediente_fk
            LEFT JOIN EXP_PROCEDIMIENTOS AS p ON p.Id_Procedimiento = r.Id_Procedimiento_FK
        WHERE r.Visto = 0 AND (@especialista = 0 OR r.Id_Especialista_FK = @especialista)
        ORDER BY ISNULL(r.FechaModifica, r.FechaCrea) DESC, r.Id_Reclamo DESC;
    END
    ELSE IF @accion = 8
    BEGIN
        UPDATE EXP_Reclamos SET Visto = 1, FechaVisto = GETDATE(), UsuarioVisto = @user
        WHERE Visto = 0 AND Id_Especialista_FK = @especialista AND (@id = 0 OR Id_Reclamo = @id);
        SELECT CAST(@@ROWCOUNT AS int) AS Marcadas;
    END
END TRY
BEGIN CATCH
    SELECT
    'ERRORNUMBER: '+CONVERT(varchar(max),ERROR_NUMBER())+
    '--ERRORLINE: '+CONVERT(varchar(max),ERROR_LINE())+
    '--ERRORMESSAGE: '+CONVERT(varchar(max),ERROR_MESSAGE())+
    '--ERRORSEVERITY: '+CONVERT(varchar(max),ERROR_SEVERITY())+
    '--ERRORPROCEDURE:'+CONVERT(varchar(max),ERROR_PROCEDURE())+
    '--ERRORSTATE: '+CONVERT(varchar(max),ERROR_STATE()) AS respuesta
END CATCH
GO

/* #####################################################################
   11/35  Registros\sql\EXP_Agenda.sql
   ##################################################################### */
PRINT N'>> 11/35 Registros\sql\EXP_Agenda.sql';
GO
/* =====================================================================
   DPieCenter - Agenda y calendario de citas (Registros/CitasRepository.cs, AgendaService.cs)

   Procedimientos que la aplicación llama y que solo existían en la base de desarrollo (no estaban en ningún script):
     EXP_SP_Especialistas, EXP_SP_TiposCitas, EXP_SP_EstadoCitas   catálogos con @accion = 1
     EXP_SP_CitasViewData                                          detalle de una cita (modal del calendario)
     EXP_SP_CitaUpdate                                             editar profesional, estado y horario de una cita
     EXP_SP_CitasBuscaExp                                          búsqueda de pacientes del asistente de citas
     EXP_SP_ListaFechasAgendadas, EXP_SP_ListaNumCitas             horarios ocupados y choques (las citas cobradas liberan la hora)
     EXP_SP_GetFechaFinal                                          fecha final = inicio + minutos
   Reescritos a partir de lo que espera el código (nombres de columnas y parámetros). Script idempotente.
   ===================================================================== */
SET NOCOUNT ON;
GO

/* Profesionales activos: IdProfesional, Profesional. @sucursal > 0: solo los que atienden en esa sucursal. */
CREATE OR ALTER PROCEDURE dbo.EXP_SP_Especialistas
     @accion   int = 1
    ,@sucursal int = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT e.Id_Especialista AS IdProfesional, LTRIM(RTRIM(e.Descripcion)) AS Profesional
    FROM dbo.CAT_ESPECIALISTAS AS e
    WHERE ISNULL(e.IsActivo, 1) = 1
      AND (@sucursal = 0 OR EXISTS (SELECT 1 FROM dbo.CAT_ESPECIALISTAS_SUCURSALES AS x
                                     WHERE x.Id_Especialista_FK = e.Id_Especialista AND x.Id_Sucursal_FK = @sucursal))
    ORDER BY e.Descripcion;
END
GO

/* Tipos de cita activos: IdTipoCita, TipoCita */
CREATE OR ALTER PROCEDURE dbo.EXP_SP_TiposCitas
    @accion int = 1
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Id_TipoCita AS IdTipoCita, LTRIM(RTRIM(Descripcion)) AS TipoCita
    FROM dbo.CAT_TIPOSCITAS
    WHERE ISNULL(IsActivo, 1) = 1
    ORDER BY Id_TipoCita;
END
GO

/* Estados de cita activos: IdEstado, Estado */
CREATE OR ALTER PROCEDURE dbo.EXP_SP_EstadoCitas
    @accion int = 1
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Id_Estado AS IdEstado, LTRIM(RTRIM(Descripcion)) AS Estado
    FROM dbo.CAT_ESTADOSCITAS
    WHERE ISNULL(IsActivo, 1) = 1
    ORDER BY Id_Estado;
END
GO

/* Detalle de una cita para el modal del calendario */
CREATE OR ALTER PROCEDURE dbo.EXP_SP_CitasViewData
    @cita bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
         c.Id_Cita AS Id
        ,LTRIM(RTRIM(ISNULL(e.Nombres, '') + ' ' + ISNULL(e.Apellidos, ''))) AS Paciente
        ,ISNULL(e.Documento, '') AS Documento
        ,ISNULL(e.Email, '') AS Email
        ,COALESCE(NULLIF(e.Celular, ''), e.Telefono, '') AS Celular
        ,CASE WHEN e.FechaNacimiento IS NULL THEN ''
              ELSE CAST(DATEDIFF(YEAR, e.FechaNacimiento, GETDATE())
                        - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, e.FechaNacimiento, GETDATE()), e.FechaNacimiento) > CAST(GETDATE() AS date) THEN 1 ELSE 0 END
                        AS varchar(3)) + ' años' END AS Edad
        ,LTRIM(RTRIM(ISNULL(e.Direccion, '')
            + CASE WHEN m.Descripcion IS NULL THEN '' ELSE ', ' + m.Descripcion END
            + CASE WHEN d.Descripcion IS NULL THEN '' ELSE ', ' + d.Descripcion END)) AS Direccion
        ,ISNULL(s.Descripcion, '') AS Especialista
        ,ISNULL(tc.Descripcion, '') AS TipoCita
        ,ISNULL(ec.Descripcion, '') AS Estado
        ,ISNULL(c.FechaInicio, CAST(c.Fecha AS datetime2)) AS FechaInicio
        ,ISNULL(c.FechaFin, DATEADD(MINUTE, 60, ISNULL(c.FechaInicio, CAST(c.Fecha AS datetime2)))) AS FechaFin
        ,c.Id_Especialista_fk AS Id_Especialista
        ,c.Id_TipoCita_FK AS Id_TipoCita
        ,c.Id_EstadoCita_fk AS Id_Estado
    FROM dbo.EXP_CITAS AS c
        INNER JOIN dbo.EXP_EXPEDIENTES AS e ON e.Id_Expediente = c.Id_Expediente_fk
        LEFT JOIN dbo.CAT_MUNICIPIOS AS m ON m.Id_Municipio = e.Id_Municipio_fk
        LEFT JOIN dbo.CAT_DEPARTAMENTOS AS d ON d.Id_Departamento = m.Id_Departamento_fk
        LEFT JOIN dbo.CAT_ESPECIALISTAS AS s ON s.Id_Especialista = c.Id_Especialista_fk
        LEFT JOIN dbo.CAT_TIPOSCITAS AS tc ON tc.Id_TipoCita = c.Id_TipoCita_FK
        LEFT JOIN dbo.CAT_ESTADOSCITAS AS ec ON ec.Id_Estado = c.Id_EstadoCita_fk
    WHERE c.Id_Cita = @cita;

    -- Tratamientos de la cita (el modal los muestra solo para consulta: no se modifican ni se eliminan)
    SELECT ISNULL(NULLIF(LTRIM(RTRIM(ct.Descripcion)), ''), ISNULL(t.Descripcion, '')) AS Tratamiento
          ,CAST(ISNULL(ct.Valor, 0) AS decimal(12,2)) AS Valor
          ,ISNULL(t.Descuento, 0) AS Descuento        -- % vigente del tratamiento (Catálogos › Tratamientos)
    FROM dbo.EXP_CITASTRATAMIENTOS AS ct
        LEFT JOIN dbo.CAT_TRATAMIENTOS AS t ON t.Id_Tratamientos = ct.Id_Tratamiento_FK
    WHERE ct.Id_Cita_FK = @cita
    ORDER BY ct.Id;

    -- Pago por adelantado de la cita (Facturacion/sql/CAJ_Anticipos.sql): se conserva aunque cambien la fecha, la hora o el profesional.
    -- MontoLibre = 1: pago adelantado sin cita que se usará en esta (Monto = su saldo disponible).
    SELECT TOP 1 f.Id_factura AS IdFactura
          ,CASE WHEN f.MontoLibre = 1
                THEN ISNULL((SELECT Disponible FROM dbo.CAJ_FN_PagosAdelantados(f.Id_Expediente_FK) WHERE Id_factura = f.Id_factura), 0)
                ELSE CAST(ISNULL((SELECT SUM(TotalPagar) FROM dbo.FAC_DTE_DOCUMENTOS WHERE Id_Factura_FK = f.Id_factura AND Estado <> 'A'), 0) AS decimal(12,2)) END AS Monto
          ,(SELECT MAX(FechaEmision) FROM dbo.FAC_DTE_DOCUMENTOS WHERE Id_Factura_FK = f.Id_factura AND Estado <> 'A') AS FechaPago
          ,f.MontoLibre
    FROM dbo.CAJ_FACTURAS AS f
    WHERE f.Id_Cita_FK = @cita AND f.Anticipo = 1 AND f.Estado = 1
    ORDER BY f.MontoLibre, f.Id_factura;

    -- Pagos adelantados del paciente pendientes de agendar (para "Usar pago adelantado")
    SELECT CAST(ISNULL(SUM(p.Disponible), 0) AS decimal(12,2)) AS PagosPendientes, COUNT(*) AS Cantidad
    FROM dbo.EXP_CITAS AS c
        CROSS APPLY dbo.CAJ_FN_PagosAdelantados(c.Id_Expediente_fk) AS p
    WHERE c.Id_Cita = @cita AND p.Id_Cita IS NULL;
END
GO

/* Edita profesional y horario (el formulario ya no cambia el estado). Las reglas de horario las valida AgendaService.ActualizarCita.
   @estado NULL: si cambia el día o la hora, la cita pasa a "Reprogramada" (5, sigue vigente: se atiende en Procedimientos);
   si no cambia, conserva su estado. Una cita cancelada, finalizada o anulada no se reprograma.
   Al cambiar el horario, el procedimiento en sala de espera se cierra como reprogramado ('R') y, si el nuevo horario
   es la hora en curso de hoy, la cita vuelve a sala de espera igual que al agendarla.
   El procedimiento abierto de la cita sigue al profesional; si la cita se cancela, se cancela. */
CREATE OR ALTER PROCEDURE dbo.EXP_SP_CitaUpdate
     @cita        bigint
    ,@profesional bigint
    ,@estado      bigint = NULL
    ,@fechainicio datetime2
    ,@fechafinal  datetime2
    ,@user        varchar(20)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @reprogramada bigint = 5, @estadoActual bigint, @inicioActual datetime2, @vigente bit;
    SELECT @estadoActual = c.Id_EstadoCita_fk, @inicioActual = ISNULL(c.FechaInicio, CAST(c.Fecha AS datetime2))
          ,@vigente = CASE WHEN ISNULL(ec.Cancelada, 0) = 1 OR ISNULL(ec.Finalizada, 0) = 1 OR c.Id_EstadoCita_fk = 7 THEN 0 ELSE 1 END
    FROM dbo.EXP_CITAS AS c LEFT JOIN dbo.CAT_ESTADOSCITAS AS ec ON ec.Id_Estado = c.Id_EstadoCita_fk
    WHERE c.Id_Cita = @cita;

    IF @estadoActual IS NULL
        THROW 50080, 'La cita no existe.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.CAT_ESPECIALISTAS WHERE Id_Especialista = @profesional)
        THROW 50081, 'El profesional seleccionado no es válido.', 1;
    IF @fechafinal <= @fechainicio
        THROW 50083, 'La hora final debe ser posterior a la inicial.', 1;

    DECLARE @cambioHorario bit = CASE WHEN @fechainicio <> @inicioActual THEN 1 ELSE 0 END;
    IF @cambioHorario = 1 AND @vigente = 0
        THROW 50084, 'La cita está cancelada, finalizada o anulada: no se puede cambiar su fecha ni su hora. Agende una cita nueva.', 1;
    IF @cambioHorario = 1 AND EXISTS (SELECT 1 FROM dbo.EXP_PROCEDIMIENTOS WHERE Id_Cita_FK = @cita AND Estado = 'I')
        THROW 50085, 'El paciente está en atención: finalice o cancele la atención antes de cambiar la fecha u hora.', 1;

    IF @estado IS NULL
        SET @estado = CASE WHEN @cambioHorario = 1 THEN @reprogramada ELSE @estadoActual END;
    IF NOT EXISTS (SELECT 1 FROM dbo.CAT_ESTADOSCITAS WHERE Id_Estado = @estado)
        THROW 50082, 'El estado seleccionado no es válido.', 1;

    DECLARE @cancelada bit = (SELECT ISNULL(Cancelada, 0) FROM dbo.CAT_ESTADOSCITAS WHERE Id_Estado = @estado);
    DECLARE @propia bit = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    BEGIN TRY
        IF @propia = 1 BEGIN TRANSACTION;

        -- el paciente que esperaba en sala para el horario anterior ya no se atiende en ese horario
        IF @cambioHorario = 1
            UPDATE dbo.EXP_PROCEDIMIENTOS SET
                 Estado = 'R'
                ,Id_EstadoCita_fk = @reprogramada
                ,UsuarioModifica = @user
                ,FechaModifica = GETDATE()
            WHERE Id_Cita_FK = @cita AND Estado = 'S';

        UPDATE dbo.EXP_CITAS SET
             Id_Especialista_fk = @profesional
            ,Id_EstadoCita_fk = @estado
            ,FechaInicio = @fechainicio
            ,FechaFin = @fechafinal
            ,Fecha = CAST(@fechainicio AS date)
            ,Id_Horario_fk = dbo.EXP_FN_HorarioCita(CAST(@fechainicio AS time))
            ,Id_HorarioFin_FK = dbo.EXP_FN_HorarioCita(CAST(DATEADD(MINUTE, -1, @fechafinal) AS time))
            ,UsuarioModifica = @user
            ,FechaModifica = GETDATE()
        WHERE Id_Cita = @cita;

        UPDATE dbo.EXP_PROCEDIMIENTOS SET
             Id_Especialista_fk = @profesional
            ,Estado = CASE WHEN @cancelada = 1 THEN 'C' ELSE Estado END
            ,UsuarioModifica = @user
            ,FechaModifica = GETDATE()
        WHERE Id_Cita_FK = @cita AND Estado IN ('S', 'I');

        -- nuevo horario en la hora en curso de hoy: pasa a sala de espera (EXP_Citas_ProcedimientoEnCurso.sql)
        -- (sin INSERT EXEC: devuelve un resultado que la aplicación ignora; así se puede llamar desde otro INSERT EXEC)
        IF @cambioHorario = 1 AND @cancelada = 0
            EXEC dbo.EXP_SP_Citas_ProcedimientoEnCurso @cita = @cita, @user = @user;

        IF @propia = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @propia = 1 AND @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT 'OK' AS resp;
END
GO

/* Cancelar una cita desde el calendario (botón "Cancelar cita"). Queda en estado Cancelada: libera la hora y al
   especialista (EXP_SP_ListaFechasAgendadas / EXP_SP_ListaNumCitas no cuentan las canceladas) y sale del calendario.
   El paciente en sala de espera sale de la cola ('C'). Si el paciente está en atención se cancela desde Procedimientos.
   Si la cita estaba pagada por adelantado, lo pagado queda a favor del paciente (CAJ_Anticipos.sql).
   Devuelve Resp = 'OK' y SaldoFavor (monto pagado por adelantado que queda a favor, 0 si no había). */
CREATE OR ALTER PROCEDURE dbo.EXP_SP_CitaCancelar
     @cita   bigint
    ,@motivo varchar(250)
    ,@user   varchar(20)
AS
BEGIN
    SET NOCOUNT ON;
    SET @motivo = NULLIF(LTRIM(RTRIM(@motivo)), '');
    DECLARE @cancelada bigint = (SELECT TOP 1 Id_Estado FROM dbo.CAT_ESTADOSCITAS WHERE Cancelada = 1 ORDER BY Id_Estado);
    DECLARE @estado bigint, @vigente bit;
    SELECT @estado = c.Id_EstadoCita_fk
          ,@vigente = CASE WHEN ISNULL(ec.Cancelada, 0) = 1 OR ISNULL(ec.Finalizada, 0) = 1 OR c.Id_EstadoCita_fk = 7 THEN 0 ELSE 1 END
    FROM dbo.EXP_CITAS AS c LEFT JOIN dbo.CAT_ESTADOSCITAS AS ec ON ec.Id_Estado = c.Id_EstadoCita_fk
    WHERE c.Id_Cita = @cita;

    IF @estado IS NULL
        THROW 50080, 'La cita no existe.', 1;
    IF @vigente = 0
        THROW 50086, 'La cita ya está cancelada, finalizada o anulada.', 1;
    IF EXISTS (SELECT 1 FROM dbo.EXP_PROCEDIMIENTOS WHERE Id_Cita_FK = @cita AND Estado = 'I')
        THROW 50087, 'El paciente está en atención: cancele la atención desde Procedimientos.', 1;
    IF @motivo IS NULL OR LEN(@motivo) < 5
        THROW 50088, 'Escriba el motivo de la cancelación (al menos 5 caracteres).', 1;

    -- pago adelantado sin cita que se iba a usar en esta cita: vuelve a pendiente de agendar con su saldo
    DECLARE @libre decimal(12,2) = ISNULL((SELECT SUM(p.Disponible) FROM dbo.EXP_CITAS AS c
                                          CROSS APPLY dbo.CAJ_FN_PagosAdelantados(c.Id_Expediente_fk) AS p
                                          WHERE c.Id_Cita = @cita AND p.Id_Cita = @cita), 0);

    DECLARE @propia bit = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    BEGIN TRY
        IF @propia = 1 BEGIN TRANSACTION;

        UPDATE dbo.CAJ_FACTURAS SET Id_Cita_FK = NULL, UsuarioModifica = @user, FechaModifica = GETDATE()
        WHERE Id_Cita_FK = @cita AND Anticipo = 1 AND MontoLibre = 1 AND Estado = 1;

        UPDATE dbo.EXP_CITAS SET
             Id_EstadoCita_fk = @cancelada
            ,Comentarios = LEFT(LTRIM(ISNULL(Comentarios + ' | ', '') + 'Cancelada: ' + @motivo), 1000)
            ,UsuarioModifica = @user
            ,FechaModifica = GETDATE()
        WHERE Id_Cita = @cita;

        -- el paciente que esperaba en sala sale de la cola
        UPDATE dbo.EXP_PROCEDIMIENTOS SET
             Estado = 'C'
            ,Id_EstadoCita_fk = @cancelada
            ,FinalProcedimiento = GETDATE()
            ,UsuarioModifica = @user
            ,FechaModifica = GETDATE()
        WHERE Id_Cita_FK = @cita AND Estado = 'S';

        IF @propia = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @propia = 1 AND @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT 'OK' AS Resp
        ,CAST(ISNULL((SELECT SUM(d.TotalPagar) FROM dbo.CAJ_FACTURAS AS f
                        INNER JOIN dbo.FAC_DTE_DOCUMENTOS AS d ON d.Id_Factura_FK = f.Id_factura AND d.Estado <> 'A'
                      WHERE f.Id_Cita_FK = @cita AND f.Anticipo = 1 AND f.MontoLibre = 0 AND f.Estado = 1 AND f.Id_Procedimiento_FK IS NULL), 0) + @libre AS decimal(12,2)) AS SaldoFavor;
END
GO

/* Búsqueda de pacientes (asistente de citas). @accion 1: nombre (todas las palabras), 2: documento.
   Columnas por posición: Codigo, Nombre, Documento, Celular (sin NULL). AgendaService muestra 25 y avisa si hay más. */
CREATE OR ALTER PROCEDURE dbo.EXP_SP_CitasBuscaExp
     @documento varchar(20)  = ''
    ,@paciente  varchar(250) = ''
    ,@user      varchar(20)  = NULL
    ,@accion    int
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @texto varchar(250) = LTRIM(RTRIM(ISNULL(CASE WHEN @accion = 2 THEN @documento ELSE @paciente END, '')));
    IF LEN(@texto) < 3 RETURN;

    IF @accion = 2
    BEGIN
        DECLARE @digitos varchar(20) = REPLACE(REPLACE(@texto, '-', ''), ' ', '');
        SELECT TOP 26
             e.Id_Expediente AS Codigo
            ,LTRIM(RTRIM(ISNULL(e.Nombres, '') + ' ' + ISNULL(e.Apellidos, ''))) AS Nombre
            ,ISNULL(e.Documento, '') AS Documento
            ,COALESCE(NULLIF(e.Celular, ''), e.Telefono, '') AS Celular
        FROM dbo.EXP_EXPEDIENTES AS e
        WHERE REPLACE(REPLACE(ISNULL(e.Documento, ''), '-', ''), ' ', '') LIKE @digitos + '%'
        ORDER BY e.Nombres, e.Apellidos;
        RETURN;
    END

    -- Por nombre: cada palabra debe aparecer en nombres o apellidos
    DECLARE @p TABLE (palabra varchar(100));
    DECLARE @resto varchar(250) = @texto + ' ', @pos int;
    WHILE LEN(@resto) > 0
    BEGIN
        SET @pos = CHARINDEX(' ', @resto);
        IF @pos > 1 INSERT @p VALUES (LEFT(@resto, @pos - 1));
        SET @resto = LTRIM(SUBSTRING(@resto, @pos + 1, 250));
    END

    SELECT TOP 26
         e.Id_Expediente AS Codigo
        ,LTRIM(RTRIM(ISNULL(e.Nombres, '') + ' ' + ISNULL(e.Apellidos, ''))) AS Nombre
        ,ISNULL(e.Documento, '') AS Documento
        ,COALESCE(NULLIF(e.Celular, ''), e.Telefono, '') AS Celular
    FROM dbo.EXP_EXPEDIENTES AS e
    WHERE NOT EXISTS (SELECT 1 FROM @p AS w
                      WHERE ISNULL(e.Nombres, '') + ' ' + ISNULL(e.Apellidos, '') NOT LIKE '%' + w.palabra + '%')
    ORDER BY e.Nombres, e.Apellidos;
END
GO

/* Horarios ocupados de un profesional (asistente de citas, paso 3: CitasRepository.ObtenerOcupados).
   Devuelve Inicio, Fin (datetime2) de las citas no canceladas que se cruzan con [@desde, @hasta).
   Una cita cuya atención ya se cobró en caja libera su horario (la hora en curso o las siguientes quedan disponibles).
   La versión de producción devolvía COUNT(1) y el asistente fallaba (InvalidCastException). */
CREATE OR ALTER PROCEDURE dbo.EXP_SP_ListaFechasAgendadas
     @profesional bigint
    ,@desde       datetime2
    ,@hasta       datetime2
    ,@cobradas    bit = 0       -- 1: devuelve solo las citas ya cobradas (horas liberadas)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT c.FechaInicio AS Inicio, c.FechaFin AS Fin
    FROM dbo.EXP_CITAS AS c
        INNER JOIN dbo.CAT_ESTADOSCITAS AS e ON e.Id_Estado = c.Id_EstadoCita_fk
    WHERE c.Id_Especialista_fk = @profesional
      AND ISNULL(e.Cancelada, 0) <> 1
      AND c.FechaInicio IS NOT NULL AND c.FechaFin IS NOT NULL
      AND c.FechaInicio < @hasta AND c.FechaFin > @desde
      AND @cobradas = CASE WHEN EXISTS (SELECT 1 FROM dbo.EXP_PROCEDIMIENTOS AS p
                                            INNER JOIN dbo.CAJ_FACTURAS AS f ON f.Id_Procedimiento_FK = p.Id_Procedimiento
                                        WHERE p.Id_Cita_FK = c.Id_Cita AND f.Estado = 1) THEN 1 ELSE 0 END   -- cobrada: libera la hora
    ORDER BY c.FechaInicio;
END
GO

/* Choques al crear una cita (CitasRepository.CrearCita, dentro de la transacción). Mismas reglas que la lista de ocupados. */
CREATE OR ALTER PROCEDURE dbo.EXP_SP_ListaNumCitas
     @profesional bigint
    ,@desde       datetime2
    ,@hasta       datetime2
AS
BEGIN
    SET NOCOUNT ON;
    SELECT COUNT(1)
    FROM dbo.EXP_CITAS AS c WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN dbo.CAT_ESTADOSCITAS AS e ON e.Id_Estado = c.Id_EstadoCita_fk
    WHERE c.Id_Especialista_fk = @profesional
      AND ISNULL(e.Cancelada, 0) <> 1
      AND c.FechaInicio < @hasta AND c.FechaFin > @desde
      AND NOT EXISTS (SELECT 1 FROM dbo.EXP_PROCEDIMIENTOS AS p
                          INNER JOIN dbo.CAJ_FACTURAS AS f ON f.Id_Procedimiento_FK = p.Id_Procedimiento
                      WHERE p.Id_Cita_FK = c.Id_Cita AND f.Estado = 1);
END
GO

/* Fecha final de un procedimiento: inicio + minutos */
CREATE OR ALTER PROCEDURE dbo.EXP_SP_GetFechaFinal
     @inicio datetime2
    ,@minute int
AS
BEGIN
    SET NOCOUNT ON;
    SELECT DATEADD(MINUTE, ISNULL(@minute, 0), @inicio) AS FechaFinal;
END
GO

/* #####################################################################
   12/35  Registros\sql\CAT_Paises.sql
   ##################################################################### */
PRINT N'>> 12/35 Registros\sql\CAT_Paises.sql';
GO
/* =====================================================================
   DPieCenter - Nacionalidad del paciente y formato de teléfono y documento por país
   (Registros/frm_ListaExpedientes.aspx y frm_EditExpediente.aspx)

   CAT_PAISES: países del mundo con el código telefónico internacional, la cantidad de dígitos del número nacional
   y el formato (máscara) del teléfono y del documento de identidad del país.
   Máscaras: # = dígito, A = letra, * = letra o dígito; cualquier otro carácter se escribe tal cual.
   EXP_EXPEDIENTES:
     - Id_Pais_FK: nacionalidad (los existentes quedan como El Salvador).
     - Id_PaisTelefono_FK: país de los teléfonos (código +503, etc.). Los números se guardan solo con dígitos.
   CAT_TIPOSDOCUMENTOS 5: documento de identidad de otro país (DTE: CAT-022 "37 Otro").
   Script idempotente: se puede ejecutar varias veces.
   ===================================================================== */
SET NOCOUNT ON;
GO

IF OBJECT_ID('dbo.CAT_PAISES', 'U') IS NULL
    CREATE TABLE dbo.CAT_PAISES (
        Id_Pais           int IDENTITY(1,1) NOT NULL CONSTRAINT PK_CAT_PAISES PRIMARY KEY,
        Iso2              char(2)      NOT NULL CONSTRAINT UX_CAT_PAISES_Iso2 UNIQUE,
        Nombre            varchar(80)  NOT NULL,
        CodigoTelefono    varchar(6)   NOT NULL,      -- sin "+"
        TelefonoMin       tinyint      NOT NULL CONSTRAINT DF_CAT_PAISES_TelMin DEFAULT (6),
        TelefonoMax       tinyint      NOT NULL CONSTRAINT DF_CAT_PAISES_TelMax DEFAULT (15),
        MascaraTelefono   varchar(30)  NULL,
        DocumentoNombre   varchar(60)  NULL,          -- documento de identidad del país (DUI, DPI, DNI...)
        MascaraDocumento  varchar(30)  NULL,
        Orden             int          NOT NULL CONSTRAINT DF_CAT_PAISES_Orden DEFAULT (100),
        Activo            bit          NOT NULL CONSTRAINT DF_CAT_PAISES_Activo DEFAULT (1)
    );
GO

/* Carga / actualización del catálogo */
DECLARE @p TABLE (Iso2 char(2), Nombre varchar(80), Codigo varchar(6), Mn tinyint, Mx tinyint, MTel varchar(30), Doc varchar(60), MDoc varchar(30), Orden int);
INSERT INTO @p VALUES
 ('SV','El Salvador','503',8,8,'####-####','DUI','########-#',1)
,('GT','Guatemala','502',8,8,'####-####','DPI','#### ##### ####',2)
,('HN','Honduras','504',8,8,'####-####','DNI','####-####-#####',3)
,('NI','Nicaragua','505',8,8,'####-####','Cédula de identidad','###-######-####A',4)
,('CR','Costa Rica','506',8,8,'####-####','Cédula de identidad','#-####-####',5)
,('PA','Panamá','507',7,8,'####-####','Cédula de identidad',NULL,6)
,('BZ','Belice','501',7,7,'###-####',NULL,NULL,7)
,('MX','México','52',10,10,'## #### ####','CURP','AAAA######AAAAAA**',8)
,('US','Estados Unidos','1',10,10,'(###) ###-####','ID / Licencia',NULL,9)
,('AF','Afganistán','93',9,9,NULL,NULL,NULL,100)
,('AL','Albania','355',8,9,NULL,NULL,NULL,100)
,('DE','Alemania','49',10,11,NULL,'Personalausweis',NULL,100)
,('AD','Andorra','376',6,9,NULL,NULL,NULL,100)
,('AO','Angola','244',9,9,'### ### ###',NULL,NULL,100)
,('AG','Antigua y Barbuda','1',10,10,'(###) ###-####',NULL,NULL,100)
,('SA','Arabia Saudita','966',9,9,NULL,NULL,NULL,100)
,('DZ','Argelia','213',9,9,NULL,NULL,NULL,100)
,('AR','Argentina','54',10,10,'## ####-####','DNI','########',100)
,('AM','Armenia','374',8,8,NULL,NULL,NULL,100)
,('AW','Aruba','297',7,7,'### ####',NULL,NULL,100)
,('AU','Australia','61',9,9,'### ### ###',NULL,NULL,100)
,('AT','Austria','43',10,13,NULL,NULL,NULL,100)
,('AZ','Azerbaiyán','994',9,9,NULL,NULL,NULL,100)
,('BS','Bahamas','1',10,10,'(###) ###-####',NULL,NULL,100)
,('BD','Bangladés','880',10,10,NULL,NULL,NULL,100)
,('BB','Barbados','1',10,10,'(###) ###-####',NULL,NULL,100)
,('BH','Baréin','973',8,8,NULL,NULL,NULL,100)
,('BE','Bélgica','32',9,9,'### ## ## ##',NULL,NULL,100)
,('BJ','Benín','229',8,10,NULL,NULL,NULL,100)
,('BY','Bielorrusia','375',9,9,NULL,NULL,NULL,100)
,('MM','Birmania (Myanmar)','95',8,10,NULL,NULL,NULL,100)
,('BO','Bolivia','591',8,8,'#### ####','Cédula de identidad',NULL,100)
,('BA','Bosnia y Herzegovina','387',8,9,NULL,NULL,NULL,100)
,('BW','Botsuana','267',7,8,NULL,NULL,NULL,100)
,('BR','Brasil','55',10,11,'(##) #####-####','CPF','###.###.###-##',100)
,('BN','Brunéi','673',7,7,NULL,NULL,NULL,100)
,('BG','Bulgaria','359',8,9,NULL,NULL,NULL,100)
,('BF','Burkina Faso','226',8,8,NULL,NULL,NULL,100)
,('BI','Burundi','257',8,8,NULL,NULL,NULL,100)
,('BT','Bután','975',7,8,NULL,NULL,NULL,100)
,('CV','Cabo Verde','238',7,7,NULL,NULL,NULL,100)
,('KH','Camboya','855',8,9,NULL,NULL,NULL,100)
,('CM','Camerún','237',9,9,NULL,NULL,NULL,100)
,('CA','Canadá','1',10,10,'(###) ###-####',NULL,NULL,100)
,('QA','Catar','974',8,8,NULL,NULL,NULL,100)
,('TD','Chad','235',8,8,NULL,NULL,NULL,100)
,('CL','Chile','56',9,9,'# #### ####','RUT','##.###.###-*',100)
,('CN','China','86',11,11,'### #### ####',NULL,NULL,100)
,('CY','Chipre','357',8,8,NULL,NULL,NULL,100)
,('VA','Ciudad del Vaticano','39',6,11,NULL,NULL,NULL,100)
,('CO','Colombia','57',10,10,'### ### ####','Cédula de ciudadanía',NULL,100)
,('KM','Comoras','269',7,7,NULL,NULL,NULL,100)
,('CG','Congo','242',9,9,NULL,NULL,NULL,100)
,('CD','Congo (Rep. Democrática)','243',9,9,NULL,NULL,NULL,100)
,('KP','Corea del Norte','850',8,10,NULL,NULL,NULL,100)
,('KR','Corea del Sur','82',9,10,'##-####-####',NULL,NULL,100)
,('CI','Costa de Marfil','225',10,10,NULL,NULL,NULL,100)
,('HR','Croacia','385',8,9,NULL,NULL,NULL,100)
,('CU','Cuba','53',8,8,'# ### ####','Carné de identidad',NULL,100)
,('CW','Curazao','599',7,8,NULL,NULL,NULL,100)
,('DK','Dinamarca','45',8,8,'## ## ## ##',NULL,NULL,100)
,('DM','Dominica','1',10,10,'(###) ###-####',NULL,NULL,100)
,('EC','Ecuador','593',9,9,'## ### ####','Cédula de identidad','##########',100)
,('EG','Egipto','20',10,10,NULL,NULL,NULL,100)
,('AE','Emiratos Árabes Unidos','971',9,9,NULL,NULL,NULL,100)
,('ER','Eritrea','291',7,7,NULL,NULL,NULL,100)
,('SK','Eslovaquia','421',9,9,NULL,NULL,NULL,100)
,('SI','Eslovenia','386',8,8,NULL,NULL,NULL,100)
,('ES','España','34',9,9,'### ### ###','DNI / NIE','*#######A',100)
,('EE','Estonia','372',7,8,NULL,NULL,NULL,100)
,('SZ','Esuatini','268',8,8,NULL,NULL,NULL,100)
,('ET','Etiopía','251',9,9,NULL,NULL,NULL,100)
,('PH','Filipinas','63',10,10,NULL,NULL,NULL,100)
,('FI','Finlandia','358',9,10,NULL,NULL,NULL,100)
,('FJ','Fiyi','679',7,7,NULL,NULL,NULL,100)
,('FR','Francia','33',9,9,'# ## ## ## ##',NULL,NULL,100)
,('GA','Gabón','241',7,8,NULL,NULL,NULL,100)
,('GM','Gambia','220',7,7,NULL,NULL,NULL,100)
,('GE','Georgia','995',9,9,NULL,NULL,NULL,100)
,('GH','Ghana','233',9,9,NULL,NULL,NULL,100)
,('GD','Granada','1',10,10,'(###) ###-####',NULL,NULL,100)
,('GR','Grecia','30',10,10,NULL,NULL,NULL,100)
,('GN','Guinea','224',9,9,NULL,NULL,NULL,100)
,('GQ','Guinea Ecuatorial','240',9,9,NULL,NULL,NULL,100)
,('GW','Guinea-Bisáu','245',7,9,NULL,NULL,NULL,100)
,('GY','Guyana','592',7,7,NULL,NULL,NULL,100)
,('HT','Haití','509',8,8,'## ## ####',NULL,NULL,100)
,('HK','Hong Kong','852',8,8,'#### ####',NULL,NULL,100)
,('HU','Hungría','36',8,9,NULL,NULL,NULL,100)
,('IN','India','91',10,10,'##### #####',NULL,NULL,100)
,('ID','Indonesia','62',9,12,NULL,NULL,NULL,100)
,('IQ','Irak','964',10,10,NULL,NULL,NULL,100)
,('IR','Irán','98',10,10,NULL,NULL,NULL,100)
,('IE','Irlanda','353',9,9,NULL,NULL,NULL,100)
,('IS','Islandia','354',7,7,NULL,NULL,NULL,100)
,('MH','Islas Marshall','692',7,7,NULL,NULL,NULL,100)
,('SB','Islas Salomón','677',7,7,NULL,NULL,NULL,100)
,('IL','Israel','972',9,9,NULL,NULL,NULL,100)
,('IT','Italia','39',9,10,NULL,NULL,NULL,100)
,('JM','Jamaica','1',10,10,'(###) ###-####',NULL,NULL,100)
,('JP','Japón','81',10,10,'##-####-####',NULL,NULL,100)
,('JO','Jordania','962',9,9,NULL,NULL,NULL,100)
,('KZ','Kazajistán','7',10,10,NULL,NULL,NULL,100)
,('KE','Kenia','254',9,9,NULL,NULL,NULL,100)
,('KG','Kirguistán','996',9,9,NULL,NULL,NULL,100)
,('KI','Kiribati','686',8,8,NULL,NULL,NULL,100)
,('XK','Kosovo','383',8,9,NULL,NULL,NULL,100)
,('KW','Kuwait','965',8,8,NULL,NULL,NULL,100)
,('LA','Laos','856',8,10,NULL,NULL,NULL,100)
,('LS','Lesoto','266',8,8,NULL,NULL,NULL,100)
,('LV','Letonia','371',8,8,NULL,NULL,NULL,100)
,('LB','Líbano','961',7,8,NULL,NULL,NULL,100)
,('LR','Liberia','231',7,9,NULL,NULL,NULL,100)
,('LY','Libia','218',9,9,NULL,NULL,NULL,100)
,('LI','Liechtenstein','423',7,9,NULL,NULL,NULL,100)
,('LT','Lituania','370',8,8,NULL,NULL,NULL,100)
,('LU','Luxemburgo','352',6,11,NULL,NULL,NULL,100)
,('MO','Macao','853',8,8,NULL,NULL,NULL,100)
,('MK','Macedonia del Norte','389',8,8,NULL,NULL,NULL,100)
,('MG','Madagascar','261',9,9,NULL,NULL,NULL,100)
,('MY','Malasia','60',9,10,NULL,NULL,NULL,100)
,('MW','Malaui','265',7,9,NULL,NULL,NULL,100)
,('MV','Maldivas','960',7,7,NULL,NULL,NULL,100)
,('ML','Malí','223',8,8,NULL,NULL,NULL,100)
,('MT','Malta','356',8,8,NULL,NULL,NULL,100)
,('MA','Marruecos','212',9,9,NULL,NULL,NULL,100)
,('MU','Mauricio','230',7,8,NULL,NULL,NULL,100)
,('MR','Mauritania','222',8,8,NULL,NULL,NULL,100)
,('FM','Micronesia','691',7,7,NULL,NULL,NULL,100)
,('MD','Moldavia','373',8,8,NULL,NULL,NULL,100)
,('MC','Mónaco','377',8,9,NULL,NULL,NULL,100)
,('MN','Mongolia','976',8,8,NULL,NULL,NULL,100)
,('ME','Montenegro','382',8,8,NULL,NULL,NULL,100)
,('MZ','Mozambique','258',9,9,NULL,NULL,NULL,100)
,('NA','Namibia','264',9,9,NULL,NULL,NULL,100)
,('NR','Nauru','674',7,7,NULL,NULL,NULL,100)
,('NP','Nepal','977',10,10,NULL,NULL,NULL,100)
,('NE','Níger','227',8,8,NULL,NULL,NULL,100)
,('NG','Nigeria','234',10,10,NULL,NULL,NULL,100)
,('NO','Noruega','47',8,8,'### ## ###',NULL,NULL,100)
,('NZ','Nueva Zelanda','64',8,10,NULL,NULL,NULL,100)
,('OM','Omán','968',8,8,NULL,NULL,NULL,100)
,('NL','Países Bajos','31',9,9,'# ########',NULL,NULL,100)
,('PK','Pakistán','92',10,10,NULL,NULL,NULL,100)
,('PW','Palaos','680',7,7,NULL,NULL,NULL,100)
,('PS','Palestina','970',9,9,NULL,NULL,NULL,100)
,('PG','Papúa Nueva Guinea','675',8,8,NULL,NULL,NULL,100)
,('PY','Paraguay','595',9,9,'### ### ###','Cédula de identidad',NULL,100)
,('PE','Perú','51',9,9,'### ### ###','DNI','########',100)
,('PL','Polonia','48',9,9,'### ### ###',NULL,NULL,100)
,('PT','Portugal','351',9,9,'### ### ###',NULL,NULL,100)
,('PR','Puerto Rico','1',10,10,'(###) ###-####',NULL,NULL,100)
,('GB','Reino Unido','44',10,10,'#### ######',NULL,NULL,100)
,('CF','República Centroafricana','236',8,8,NULL,NULL,NULL,100)
,('CZ','República Checa','420',9,9,'### ### ###',NULL,NULL,100)
,('DO','República Dominicana','1',10,10,'(###) ###-####','Cédula de identidad','###-#######-#',100)
,('RW','Ruanda','250',9,9,NULL,NULL,NULL,100)
,('RO','Rumania','40',9,9,NULL,NULL,NULL,100)
,('RU','Rusia','7',10,10,'### ###-##-##',NULL,NULL,100)
,('WS','Samoa','685',5,7,NULL,NULL,NULL,100)
,('KN','San Cristóbal y Nieves','1',10,10,'(###) ###-####',NULL,NULL,100)
,('SM','San Marino','378',6,10,NULL,NULL,NULL,100)
,('VC','San Vicente y las Granadinas','1',10,10,'(###) ###-####',NULL,NULL,100)
,('LC','Santa Lucía','1',10,10,'(###) ###-####',NULL,NULL,100)
,('ST','Santo Tomé y Príncipe','239',7,7,NULL,NULL,NULL,100)
,('SN','Senegal','221',9,9,NULL,NULL,NULL,100)
,('RS','Serbia','381',8,9,NULL,NULL,NULL,100)
,('SC','Seychelles','248',7,7,NULL,NULL,NULL,100)
,('SL','Sierra Leona','232',8,8,NULL,NULL,NULL,100)
,('SG','Singapur','65',8,8,'#### ####',NULL,NULL,100)
,('SY','Siria','963',9,9,NULL,NULL,NULL,100)
,('SO','Somalia','252',7,9,NULL,NULL,NULL,100)
,('LK','Sri Lanka','94',9,9,NULL,NULL,NULL,100)
,('ZA','Sudáfrica','27',9,9,'## ### ####',NULL,NULL,100)
,('SD','Sudán','249',9,9,NULL,NULL,NULL,100)
,('SS','Sudán del Sur','211',9,9,NULL,NULL,NULL,100)
,('SE','Suecia','46',7,10,NULL,NULL,NULL,100)
,('CH','Suiza','41',9,9,'## ### ## ##',NULL,NULL,100)
,('SR','Surinam','597',6,7,NULL,NULL,NULL,100)
,('TH','Tailandia','66',9,9,NULL,NULL,NULL,100)
,('TW','Taiwán','886',9,9,NULL,NULL,NULL,100)
,('TZ','Tanzania','255',9,9,NULL,NULL,NULL,100)
,('TJ','Tayikistán','992',9,9,NULL,NULL,NULL,100)
,('TL','Timor Oriental','670',7,8,NULL,NULL,NULL,100)
,('TG','Togo','228',8,8,NULL,NULL,NULL,100)
,('TO','Tonga','676',5,7,NULL,NULL,NULL,100)
,('TT','Trinidad y Tobago','1',10,10,'(###) ###-####',NULL,NULL,100)
,('TN','Túnez','216',8,8,NULL,NULL,NULL,100)
,('TM','Turkmenistán','993',8,8,NULL,NULL,NULL,100)
,('TR','Turquía','90',10,10,'### ### ## ##',NULL,NULL,100)
,('TV','Tuvalu','688',5,7,NULL,NULL,NULL,100)
,('UA','Ucrania','380',9,9,NULL,NULL,NULL,100)
,('UG','Uganda','256',9,9,NULL,NULL,NULL,100)
,('UY','Uruguay','598',8,8,'#### ####','Cédula de identidad','#.###.###-#',100)
,('UZ','Uzbekistán','998',9,9,NULL,NULL,NULL,100)
,('VU','Vanuatu','678',7,7,NULL,NULL,NULL,100)
,('VE','Venezuela','58',10,10,'### ###-####','Cédula de identidad',NULL,100)
,('VN','Vietnam','84',9,10,NULL,NULL,NULL,100)
,('YE','Yemen','967',9,9,NULL,NULL,NULL,100)
,('DJ','Yibuti','253',8,8,NULL,NULL,NULL,100)
,('ZM','Zambia','260',9,9,NULL,NULL,NULL,100)
,('ZW','Zimbabue','263',9,9,NULL,NULL,NULL,100);

MERGE dbo.CAT_PAISES AS t
USING @p AS s ON t.Iso2 = s.Iso2
WHEN MATCHED THEN UPDATE SET Nombre = s.Nombre, CodigoTelefono = s.Codigo, TelefonoMin = s.Mn, TelefonoMax = s.Mx,
    MascaraTelefono = s.MTel, DocumentoNombre = s.Doc, MascaraDocumento = s.MDoc, Orden = s.Orden
WHEN NOT MATCHED THEN INSERT (Iso2, Nombre, CodigoTelefono, TelefonoMin, TelefonoMax, MascaraTelefono, DocumentoNombre, MascaraDocumento, Orden)
    VALUES (s.Iso2, s.Nombre, s.Codigo, s.Mn, s.Mx, s.MTel, s.Doc, s.MDoc, s.Orden);
GO

/* ---------- Expedientes: nacionalidad y país de los teléfonos ---------- */
IF COL_LENGTH('dbo.EXP_EXPEDIENTES', 'Id_Pais_FK') IS NULL
    ALTER TABLE dbo.EXP_EXPEDIENTES ADD Id_Pais_FK int NULL CONSTRAINT FK_EXP_EXPEDIENTES_Pais REFERENCES dbo.CAT_PAISES (Id_Pais);
GO
IF COL_LENGTH('dbo.EXP_EXPEDIENTES', 'Id_PaisTelefono_FK') IS NULL
    ALTER TABLE dbo.EXP_EXPEDIENTES ADD Id_PaisTelefono_FK int NULL CONSTRAINT FK_EXP_EXPEDIENTES_PaisTel REFERENCES dbo.CAT_PAISES (Id_Pais);
GO
-- Los expedientes existentes son de El Salvador
DECLARE @sv int = (SELECT Id_Pais FROM dbo.CAT_PAISES WHERE Iso2 = 'SV');
UPDATE dbo.EXP_EXPEDIENTES SET Id_Pais_FK = @sv WHERE Id_Pais_FK IS NULL;
UPDATE dbo.EXP_EXPEDIENTES SET Id_PaisTelefono_FK = @sv WHERE Id_PaisTelefono_FK IS NULL;
GO
-- Los números internacionales tienen hasta 15 dígitos (se guardan sin código de país, solo dígitos)
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EXP_EXPEDIENTES') AND name = 'Celular' AND max_length < 20)
    ALTER TABLE dbo.EXP_EXPEDIENTES ALTER COLUMN Celular varchar(20) NULL;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EXP_EXPEDIENTES') AND name = 'Telefono' AND max_length < 20)
    ALTER TABLE dbo.EXP_EXPEDIENTES ALTER COLUMN Telefono varchar(20) NULL;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EXP_EXPEDIENTES') AND name = 'TelefonoEmergencia' AND max_length < 20)
    ALTER TABLE dbo.EXP_EXPEDIENTES ALTER COLUMN TelefonoEmergencia varchar(20) NULL;
GO

/* ---------- Tipo de documento para extranjeros ---------- */
IF NOT EXISTS (SELECT 1 FROM dbo.CAT_TIPOSDOCUMENTOS WHERE Id_TipoDocumento = 5)
BEGIN
    SET IDENTITY_INSERT dbo.CAT_TIPOSDOCUMENTOS ON;
    INSERT INTO dbo.CAT_TIPOSDOCUMENTOS (Id_TipoDocumento, Descripcion, Estatus, Digitos, Formato, UsuarioCrea, FechaCrea)
    VALUES (5, 'DOCUMENTO DE IDENTIDAD EXTRANJERO', 1, 0, 'X', 'admin', GETDATE());
    SET IDENTITY_INSERT dbo.CAT_TIPOSDOCUMENTOS OFF;
END
GO

/* Catálogo de países para los formularios */
CREATE OR ALTER PROCEDURE [dbo].[CAT_SP_Paises]
AS
BEGIN
    SET NOCOUNT ON;
    select Id_Pais, Iso2, Nombre, CodigoTelefono, TelefonoMin, TelefonoMax, MascaraTelefono, DocumentoNombre, MascaraDocumento
    from CAT_PAISES
    where Activo = 1
    order by Orden, Nombre
END
GO

/* #####################################################################
   13/35  Registros\sql\EXP_Expedientes_Lista.sql
   ##################################################################### */
PRINT N'>> 13/35 Registros\sql\EXP_Expedientes_Lista.sql';
GO
/* =====================================================================
   DPieCenter - Lista de expedientes (Registros/frm_ListaExpedientes.aspx)

   - EXP_SP_Expedientes_Lista: búsqueda con paginación, letras, resumen, eliminación validada
     y procedimientos del paciente para reclamos.
   - EXP_SP_Expedientes: se corrige la validación de duplicados al crear y al editar (antes un documento vacío, tipo N/A,
     impedía registrar a un segundo paciente sin documento) y la de eliminación (contaba las citas
     por documento en lugar de por expediente). El resto del SP queda igual.

   Los errores de negocio se lanzan con THROW 5006x y llegan como mensaje a la pantalla.
   Script idempotente: se puede ejecutar varias veces.
   ===================================================================== */
SET NOCOUNT ON;
GO

/* ---------- "¿Cómo nos conoció?" del expediente (marcas sí/no). Algunas bases no tienen estas columnas. ---------- */
IF COL_LENGTH('dbo.EXP_EXPEDIENTES', 'Facebook') IS NULL    ALTER TABLE dbo.EXP_EXPEDIENTES ADD Facebook    bit NULL;
IF COL_LENGTH('dbo.EXP_EXPEDIENTES', 'Instagram') IS NULL   ALTER TABLE dbo.EXP_EXPEDIENTES ADD Instagram   bit NULL;
IF COL_LENGTH('dbo.EXP_EXPEDIENTES', 'Buscador') IS NULL    ALTER TABLE dbo.EXP_EXPEDIENTES ADD Buscador    bit NULL;
IF COL_LENGTH('dbo.EXP_EXPEDIENTES', 'Recomendado') IS NULL ALTER TABLE dbo.EXP_EXPEDIENTES ADD Recomendado bit NULL;
IF COL_LENGTH('dbo.EXP_EXPEDIENTES', 'TikTok') IS NULL      ALTER TABLE dbo.EXP_EXPEDIENTES ADD TikTok      bit NULL;
IF COL_LENGTH('dbo.EXP_EXPEDIENTES', 'WhatsApp') IS NULL    ALTER TABLE dbo.EXP_EXPEDIENTES ADD WhatsApp    bit NULL;
IF COL_LENGTH('dbo.EXP_EXPEDIENTES', 'Otros') IS NULL       ALTER TABLE dbo.EXP_EXPEDIENTES ADD Otros       bit NULL;
GO

CREATE OR ALTER PROCEDURE [dbo].[EXP_SP_Expedientes_Lista]
	 @accion  int
	,@texto   varchar(100) = null     -- nombre, apellido, documento, celular, teléfono, email o registro
	,@letra   char(1) = null          -- inicial del apellido
	,@pagina  int = 1
	,@tamano  int = 25
	,@id      bigint = 0
	,@user    varchar(20) = null
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	declare @ahora datetime = GETDATE()

	/* 1: búsqueda paginada. Sin filtros devuelve los últimos registrados o modificados */
	if @accion = 1
	begin
		set @texto = NULLIF(LTRIM(RTRIM(@texto)), '')
		set @letra = NULLIF(LTRIM(RTRIM(@letra)), '')
		if @pagina < 1 set @pagina = 1
		if @tamano not between 5 and 100 set @tamano = 25

		declare @digitos varchar(100) = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@texto, '-', ''), ' ', ''), '.', ''), '(', ''), ')', ''), '+', '')

		select
			e.Id_Expediente
			,LTRIM(RTRIM(e.Nombres)) as Nombres
			,LTRIM(RTRIM(e.Apellidos)) as Apellidos
			,ISNULL(e.Documento, '') as Documento
			,ISNULL(td.Descripcion, '') as TipoDocumento
			,ISNULL(e.Registro, '') as Registro
			,ISNULL(e.Celular, '') as Celular
			,ISNULL(e.Telefono, '') as Telefono
			,ISNULL(e.Email, '') as Email
			,ISNULL(s.Descripcion, '') as Sexo
			,e.Id_Pais_FK as Id_Pais
			,e.Id_PaisTelefono_FK as Id_PaisTelefono
			,e.FechaNacimiento
			,e.FechaCrea
			,u.UltimaVisita
			,pc.ProximaCita
			,ISNULL(u.Visitas, 0) as Visitas
			,COUNT(*) OVER () as Total
		from EXP_EXPEDIENTES as e
			left join CAT_SEXOS as s on s.Id_Sexos = e.Id_Sexo_fk
			left join CAT_TIPOSDOCUMENTOS as td on td.Id_TipoDocumento = e.Id_TipoDocumento_fk
			outer apply (select MAX(p.Fecha) as UltimaVisita, COUNT(*) as Visitas
						 from EXP_PROCEDIMIENTOS as p
						 where p.Id_Expediente_fk = e.Id_Expediente and p.Estado = 'F') as u
			outer apply (select MIN(c.FechaInicio) as ProximaCita
						 from EXP_CITAS as c
							 inner join CAT_ESTADOSCITAS as ec on ec.Id_Estado = c.Id_EstadoCita_fk
						 where c.Id_Expediente_fk = e.Id_Expediente
							 and ec.Procesos = 1
							 and c.FechaInicio >= CAST(@ahora as date)) as pc
		where (@letra is null or UPPER(LEFT(LTRIM(e.Apellidos), 1)) = UPPER(@letra))
			and (@texto is null
				 or (e.Nombres + ' ' + e.Apellidos) like '%' + @texto + '%'
				 or (e.Apellidos + ' ' + e.Nombres) like '%' + @texto + '%'
				 or e.Email like '%' + @texto + '%'
				 or e.Registro like '%' + @texto + '%'
				 or (LEN(@digitos) >= 3 and (REPLACE(e.Documento, '-', '') like '%' + @digitos + '%'
											 or e.Celular like '%' + @digitos + '%'
											 or e.Telefono like '%' + @digitos + '%')))
		order by
			case when @texto is null and @letra is null then ISNULL(e.FechaModifica, e.FechaCrea) end desc,
			e.Apellidos, e.Nombres, e.Id_Expediente
		offset (@pagina - 1) * @tamano rows fetch next @tamano rows only
		return
	end

	/* 2: iniciales de apellido con su cantidad de expedientes */
	if @accion = 2
	begin
		select UPPER(LEFT(LTRIM(Apellidos), 1)) as Letra, COUNT(*) as Cantidad
		from EXP_EXPEDIENTES
		where LTRIM(Apellidos) <> ''
		group by UPPER(LEFT(LTRIM(Apellidos), 1))
		order by Letra
		return
	end

	/* 3: resumen para los indicadores */
	if @accion = 3
	begin
		select
			(select COUNT(*) from EXP_EXPEDIENTES) as Total
			,(select COUNT(*) from EXP_EXPEDIENTES
			  where FechaCrea >= DATEADD(DAY, 1 - DAY(@ahora), CAST(@ahora as date))) as NuevosMes
			,(select COUNT(distinct c.Id_Expediente_fk)
			  from EXP_CITAS as c inner join CAT_ESTADOSCITAS as ec on ec.Id_Estado = c.Id_EstadoCita_fk
			  where CAST(c.FechaInicio as date) = CAST(@ahora as date) and ec.Procesos = 1) as ConCitaHoy
			,(select COUNT(distinct p.Id_Expediente_fk) from EXP_PROCEDIMIENTOS as p
			  where p.Estado = 'F' and p.Fecha >= DATEADD(DAY, -90, CAST(@ahora as date))) as Activos90
		return
	end

	/* 4: eliminar. Solo expedientes sin historial (citas, procedimientos, reclamos ni datos fiscales) */
	if @accion = 4
	begin
		if not exists (select 1 from EXP_EXPEDIENTES where Id_Expediente = @id)
			THROW 50060, 'El expediente no existe.', 1;
		if exists (select 1 from EXP_CITAS where Id_Expediente_fk = @id)
			or exists (select 1 from EXP_PROCEDIMIENTOS where Id_Expediente_fk = @id)
			THROW 50061, 'No se puede eliminar: el paciente tiene citas o procedimientos registrados.', 1;
		-- La columna se llama Id_Expediente_fk o Id_Expediente según la base: se consulta con SQL dinámico
		declare @reclamos int = 0, @colReclamo sysname =
			case when COL_LENGTH('dbo.EXP_Reclamos', 'Id_Expediente_fk') is not null then N'Id_Expediente_fk'
				 when COL_LENGTH('dbo.EXP_Reclamos', 'Id_Expediente') is not null then N'Id_Expediente' end;
		if @colReclamo is not null
		begin
			declare @sqlReclamo nvarchar(300) = N'select @n = COUNT(*) from dbo.EXP_Reclamos where ' + QUOTENAME(@colReclamo) + N' = @id';
			exec sp_executesql @sqlReclamo, N'@id bigint, @n int output', @id = @id, @n = @reclamos output;
		end
		if @reclamos > 0
			THROW 50062, 'No se puede eliminar: el paciente tiene Garantías de Servicios registradas.', 1;
		if exists (select 1 from FAC_DTE_RECEPTORES where Id_Expediente_FK = @id)
			THROW 50063, 'No se puede eliminar: el paciente tiene datos de facturación registrados.', 1;

		BEGIN TRANSACTION;
		delete from EXP_EXPEDIENTETRATAMIENTOS where Id_Expediente_fk = @id
		delete from EXP_EXPEDIENTES where Id_Expediente = @id
		COMMIT TRANSACTION;

		select @id as Id_Expediente
		return
	end

	/* 5: procedimientos del paciente (para registrar un reclamo) */
	if @accion = 5
	begin
		select top 30
			p.Id_Procedimiento
			,p.Fecha
			,p.Id_Especialista_fk as Id_Especialista
			,ISNULL(s.Descripcion, '') as Especialista
			,ISNULL(STUFF((select ', ' + t.Descripcion
						   from EXP_PROCEDIMIENTOSTRATAMIENTOS as t
						   where t.Id_Procedimiento_FK = p.Id_Procedimiento
						   for xml path(''), type).value('.', 'varchar(max)'), 1, 2, ''), '') as Tratamientos
		from EXP_PROCEDIMIENTOS as p
			left join CAT_ESPECIALISTAS as s on s.Id_Especialista = p.Id_Especialista_fk
		where p.Id_Expediente_fk = @id and p.Estado = 'F'
		order by p.Fecha desc, p.Id_Procedimiento desc
		return
	end;

	THROW 50099, 'Acción no válida.', 1;
END
GO

/* EXP_SP_Expedientes: misma lógica, con las validaciones corregidas en @accion 1 y 3 */
CREATE OR ALTER PROCEDURE [dbo].[EXP_SP_Expedientes]
	@id bigint
	,@documento varchar(20)
	,@nombres varchar(200)
	,@apellidos varchar(200)
	,@nacimiento varchar(10)
	,@telefono varchar(20)
	,@celular varchar(20)
	,@email varchar(100)
	,@emergencia varchar(500)
	,@telefonoemer varchar(20)
	,@municipio bigint
	,@direccion varchar(max)
	,@sexo bigint
	,@tipodoc bigint
	,@registro varchar(100)
	,@facebook int
	,@instagram int
	,@buscador int
	,@recomendado int
	,@usuario varchar(20)
	,@accion int
	,@sucursal int = 0          -- sucursal donde se registra (0 = la del usuario; los pacientes se comparten)
	,@tiktok int = 0
	,@whatsapp int = 0
	,@otros int = 0              -- "¿Cómo nos conoció?": Otros
	,@pais int = 0               -- nacionalidad (CAT_PAISES; 0 = El Salvador)
	,@paisTelefono int = 0       -- país de los teléfonos (0 = el de la nacionalidad)
AS
BEGIN TRY
	SET NOCOUNT ON;
	if ISNULL(@sucursal, 0) = 0
		set @sucursal = ISNULL((select Id_Sucursal_FK from Sys_Usuarios where Id_Usuario = @usuario), dbo.SUC_FN_Matriz())
	if not exists (select 1 from CAT_PAISES where Id_Pais = @pais)
		set @pais = (select Id_Pais from CAT_PAISES where Iso2 = 'SV')
	if not exists (select 1 from CAT_PAISES where Id_Pais = @paisTelefono)
		set @paisTelefono = @pais

	if @accion = 1
	begin
		set @documento = LTRIM(RTRIM(ISNULL(@documento, '')))

		-- El documento solo se valida cuando se ingresó (los pacientes N/A no tienen)
		if @documento <> '' and exists (select 1 from EXP_EXPEDIENTES where Documento = @documento)
			select 'Ya existe un expediente con el número de documento ingresado.' as resp
		else if exists (select 1 from EXP_EXPEDIENTES
						where Nombres = RTRIM(LTRIM(@nombres)) and Apellidos = RTRIM(LTRIM(@apellidos))
						  and FechaNacimiento = @nacimiento)
			select 'Ya existe un expediente con el mismo nombre, apellido y fecha de nacimiento.' as resp
		else
		begin
			insert into EXP_EXPEDIENTES
				(Id_TipoDocumento_fk,Documento,Registro,Nombres,Apellidos
				,FechaNacimiento,Telefono,Celular,Email,PersonaEmergencia
				,TelefonoEmergencia,Id_Municipio_fk,Direccion,Id_Sexo_fk
				,Facebook,Instagram,Buscador,Recomendado,TikTok,WhatsApp,Otros,UsuarioCrea,FechaCrea,Id_Sucursal_FK
				,Id_Pais_FK,Id_PaisTelefono_FK)
			values
				(@tipodoc,@documento,@registro,RTRIM(LTRIM(@nombres)),RTRIM(LTRIM(@apellidos))
				,@nacimiento,@telefono,@celular,@email,@emergencia
				,@telefonoemer,@municipio,@direccion,@sexo
				,@facebook,@instagram,@buscador,@recomendado,ISNULL(@tiktok,0),ISNULL(@whatsapp,0),ISNULL(@otros,0),@usuario,GETDATE(),@sucursal
				,@pais,@paisTelefono)

			select 'OK' as resp
		end
	end
	else if @accion = 2
	begin
		set @documento = LTRIM(RTRIM(ISNULL(@documento, '')))

		-- No se puede asignar el documento de otro paciente
		if @documento <> '' and exists (select 1 from EXP_EXPEDIENTES where Documento = @documento and Id_Expediente <> @id)
		begin
			select 'Otro expediente ya tiene el número de documento ingresado.' as resp
			return
		end

		update EXP_EXPEDIENTES set
			Id_TipoDocumento_fk = @tipodoc
			,Documento = @documento
			,Registro = @registro
			,Nombres = RTRIM(LTRIM(@nombres))
			,Apellidos = RTRIM(LTRIM(@apellidos))
			,FechaNacimiento = @nacimiento
			,Telefono = @telefono
			,Celular = @celular
			,Email = @email
			,PersonaEmergencia = @emergencia
			,TelefonoEmergencia = @telefonoemer
			,Id_Municipio_fk = @municipio
			,Direccion = @direccion
			,Id_Sexo_fk = @sexo
			,Facebook = @facebook
			,Instagram = @instagram
			,Buscador = @buscador
			,Recomendado = @recomendado
			,TikTok = ISNULL(@tiktok, 0)
			,WhatsApp = ISNULL(@whatsapp, 0)
			,Otros = ISNULL(@otros, 0)
			,Id_Pais_FK = @pais
			,Id_PaisTelefono_FK = @paisTelefono
			,UsuarioModifica = @usuario
			,FechaModifica = GETDATE()
		where Id_Expediente = @id

		select 'OK' as resp
	end
	else if @accion = 3
	begin
		-- Por expediente (antes contaba las citas por documento)
		if not exists (select 1 from EXP_CITAS where Id_Expediente_fk = @id)
		   and not exists (select 1 from EXP_PROCEDIMIENTOS where Id_Expediente_fk = @id)
		begin
			delete from EXP_EXPEDIENTETRATAMIENTOS where Id_Expediente_fk = @id
			delete from EXP_EXPEDIENTES
			where Id_Expediente = @id

			select 'OK' as resp
		end
		else
			select 'ERROR: Este expediente tiene citas registradas.' as resp
	end
	else if @accion = 4
	begin
		select
			id_Expediente
			,Nombres+' '+Apellidos [nombres]
			,Documento
			,Email
			,Telefono
			,Celular
			,s.Descripcion[Sexo]
			,DATEDIFF(YEAR,FechaNacimiento,GETDATE()) [Edad]
			,CONVERT(char(10),e.FechaCrea,103) [Ingreso]
			,Id_TipoDocumento_fk
			,Registro
			,case facebook when 1 then 1 else 0 end [Facebook]
			,case Instagram when 1 then 1 else 0 end [Instagram]
			,case Buscador when 1 then 1 else 0 end [Buscador]
			,case Recomendado when 1 then 1 else 0 end [Recomendado]
		from EXP_EXPEDIENTES as e
			inner join CAT_SEXOS as s on e.Id_Sexo_fk = s.Id_Sexos

		select 'OK' as resp
	end
	else if @accion = 5
	begin
		select
			Id_Expediente
			,Nombres+' '+Apellidos [nombres]
			,Documento
			,Email
			,Telefono
			,Celular
			,Id_Sexo_fk
			,DATEDIFF(YEAR,FechaNacimiento,GETDATE()) [Edad]
			,CONVERT(char(10),e.FechaCrea,103) [Ingreso]
			,Id_TipoDocumento_fk
			,Registro
			,case facebook when 1 then 1 else 0 end [Facebook]
			,case Instagram when 1 then 1 else 0 end [Instagram]
			,case Buscador when 1 then 1 else 0 end [Buscador]
			,case Recomendado when 1 then 1 else 0 end [Recomendado]
		from EXP_EXPEDIENTES as e
			inner join CAT_MUNICIPIOS as m on e.id_municipio_fk = m.id_municipio
			inner join CAT_DEPARTAMENTOS as d on m.id_departamento_fk = d.Id_Departamento
		where Id_Expediente = @id

		select 'OK' as resp
	end
	else if @accion = 6
	begin
		select
			 Nombres
			,Apellidos
			,Documento
			,convert(char(10),FechaNacimiento,120)[Nacimiento]
			,Id_Sexo_fk [Sexo]
			,Telefono
			,Celular
			,Email
			,TelefonoEmergencia
			,PersonaEmergencia
			,Id_Departamento
			,Id_Municipio
			,Direccion
			,Id_TipoDocumento_fk
			,Registro
			,case facebook when 1 then 1 else 0 end [Facebook]
			,case Instagram when 1 then 1 else 0 end [Instagram]
			,case Buscador when 1 then 1 else 0 end [Buscador]
			,case Recomendado when 1 then 1 else 0 end [Recomendado]
			,case TikTok when 1 then 1 else 0 end [TikTok]
			,case WhatsApp when 1 then 1 else 0 end [WhatsApp]
			,case Otros when 1 then 1 else 0 end [Otros]
		from EXP_EXPEDIENTES as e
			inner join CAT_MUNICIPIOS as m on e.id_municipio_fk = m.id_municipio
			inner join CAT_DEPARTAMENTOS as d on m.id_departamento_fk = d.Id_Departamento
		where Id_Expediente = @id

		select 'OK' as resp
	end
	else if @accion = 7
	begin
		select
			Nombres+' '+Apellidos [nombres]
			,Documento
			,Email
			,Celular
			,Direccion+', '+m.Descripcion+', '+d.Descripcion [Direccion]
		from EXP_EXPEDIENTES as e
			inner join CAT_MUNICIPIOS as m on e.id_municipio_fk = m.id_municipio
			inner join CAT_DEPARTAMENTOS as d on m.id_departamento_fk = d.Id_Departamento
		where Id_Expediente = @id

		select 'OK' as resp
	end
END TRY
BEGIN CATCH
	SELECT
	'ERRORNUMBER: '+CONVERT(varchar(max),ERROR_NUMBER())+
	'--ERRORLINE: '+CONVERT(varchar(max),ERROR_LINE())+
	'--ERRORMESSAGE: '+CONVERT(varchar(max),ERROR_MESSAGE())+
	'--ERRORSEVERITY: '+CONVERT(varchar(max),ERROR_SEVERITY())+
	'--ERRORPROCEDURE:'+CONVERT(varchar(max),ERROR_PROCEDURE())+
	'--ERRORSTATE: '+CONVERT(varchar(max),ERROR_STATE()) AS respuesta
END CATCH
GO

/* #####################################################################
   14/35  Registros\sql\EXP_Expediente_Detalle.sql
   ##################################################################### */
PRINT N'>> 14/35 Registros\sql\EXP_Expediente_Detalle.sql';
GO
/* =====================================================================
   DPieCenter - Ficha del paciente (Registros/frm_EditExpediente.aspx)

   EXP_SP_Expediente_Detalle: perfil, resumen, historial de citas, procedimientos y reclamos, y la foto.
   Los datos del paciente se siguen guardando con EXP_SP_Expedientes (@accion 2).
   Los errores de negocio se lanzan con THROW 5007x y llegan como mensaje a la pantalla.
   Script idempotente: se puede ejecutar varias veces.
   ===================================================================== */
SET NOCOUNT ON;
GO

/* "¿Cómo nos conoció?": TikTok, WhatsApp y Otros (también en EXP_Expedientes_Lista.sql) */
IF COL_LENGTH('dbo.EXP_EXPEDIENTES', 'TikTok') IS NULL   ALTER TABLE dbo.EXP_EXPEDIENTES ADD TikTok   bit NULL;
IF COL_LENGTH('dbo.EXP_EXPEDIENTES', 'WhatsApp') IS NULL ALTER TABLE dbo.EXP_EXPEDIENTES ADD WhatsApp bit NULL;
IF COL_LENGTH('dbo.EXP_EXPEDIENTES', 'Otros') IS NULL    ALTER TABLE dbo.EXP_EXPEDIENTES ADD Otros    bit NULL;
GO

CREATE OR ALTER PROCEDURE [dbo].[EXP_SP_Expediente_Detalle]
	 @accion int
	,@id     bigint
	,@foto   varchar(max) = null
	,@user   varchar(20) = null
AS
BEGIN
	SET NOCOUNT ON;

	declare @ahora datetime = GETDATE()
	declare @cancelada bigint = (select top 1 Id_Estado from CAT_ESTADOSCITAS where Cancelada = 1 order by Id_Estado)    -- 3
	declare @finalizada bigint = (select top 1 Id_Estado from CAT_ESTADOSCITAS where Finalizada = 1 order by Id_Estado)  -- 6

	if not exists (select 1 from EXP_EXPEDIENTES where Id_Expediente = @id)
		THROW 50070, 'El expediente no existe.', 1;

	/* 1: perfil completo para el formulario */
	if @accion = 1
	begin
		select
			e.Id_Expediente
			,LTRIM(RTRIM(e.Nombres)) as Nombres
			,LTRIM(RTRIM(e.Apellidos)) as Apellidos
			,e.Id_TipoDocumento_fk as Id_TipoDocumento
			,ISNULL(td.Descripcion, '') as TipoDocumento
			,ISNULL(e.Documento, '') as Documento
			,ISNULL(e.Registro, '') as Registro
			,e.FechaNacimiento
			,e.Id_Sexo_fk as Id_Sexo
			,ISNULL(s.Descripcion, '') as Sexo
			,ISNULL(e.Telefono, '') as Telefono
			,ISNULL(e.Celular, '') as Celular
			,ISNULL(e.Email, '') as Email
			,ISNULL(e.PersonaEmergencia, '') as PersonaEmergencia
			,ISNULL(e.TelefonoEmergencia, '') as TelefonoEmergencia
			,e.Id_Pais_FK as Id_Pais
			,ISNULL(pa.Nombre, '') as Pais
			,e.Id_PaisTelefono_FK as Id_PaisTelefono
			,m.Id_Departamento_fk as Id_Departamento
			,e.Id_Municipio_fk as Id_Municipio
			,ISNULL(e.Direccion, '') as Direccion
			,LTRIM(ISNULL(m.Descripcion, '') + ISNULL(', ' + d.Descripcion, '')) as Ubicacion
			,ISNULL(e.Facebook, 0) as Facebook
			,ISNULL(e.Instagram, 0) as Instagram
			,ISNULL(e.Buscador, 0) as Buscador
			,ISNULL(e.Recomendado, 0) as Recomendado
			,ISNULL(e.TikTok, 0) as TikTok
			,ISNULL(e.WhatsApp, 0) as WhatsApp
			,ISNULL(e.Otros, 0) as Otros
			,ISNULL(e.Foto, '') as Foto
			,e.FechaCrea
			,e.UsuarioCrea
			,e.FechaModifica
			,e.UsuarioModifica
		from EXP_EXPEDIENTES as e
			left join CAT_TIPOSDOCUMENTOS as td on td.Id_TipoDocumento = e.Id_TipoDocumento_fk
			left join CAT_SEXOS as s on s.Id_Sexos = e.Id_Sexo_fk
			left join CAT_MUNICIPIOS as m on m.Id_Municipio = e.Id_Municipio_fk
			left join CAT_DEPARTAMENTOS as d on d.Id_Departamento = m.Id_Departamento_fk
			left join CAT_PAISES as pa on pa.Id_Pais = e.Id_Pais_FK
		where e.Id_Expediente = @id
		return
	end

	/* 2: resumen de la ficha */
	if @accion = 2
	begin
		select
			(select COUNT(*) from EXP_CITAS where Id_Expediente_fk = @id) as Citas
			,(select COUNT(*) from EXP_CITAS where Id_Expediente_fk = @id and Id_EstadoCita_fk = @finalizada) as Atendidas
			,(select COUNT(*) from EXP_CITAS where Id_Expediente_fk = @id and Id_EstadoCita_fk = @cancelada) as Canceladas
			,(select COUNT(*) from EXP_PROCEDIMIENTOS where Id_Expediente_fk = @id and Estado = 'F') as Procedimientos
			,(select COUNT(*) from EXP_Reclamos where Id_Expediente_fk = @id) as Reclamos
			,(select MAX(Fecha) from EXP_PROCEDIMIENTOS where Id_Expediente_fk = @id and Estado = 'F') as UltimaVisita
			,(select MIN(c.FechaInicio)
			  from EXP_CITAS as c inner join CAT_ESTADOSCITAS as ec on ec.Id_Estado = c.Id_EstadoCita_fk
			  where c.Id_Expediente_fk = @id and ec.Procesos = 1
				and c.FechaInicio >= CAST(@ahora as date)) as ProximaCita
		return
	end

	/* 3: historial de citas (más recientes primero) */
	if @accion = 3
	begin
		select
			c.Id_Cita
			,ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2)) as FechaInicio
			,c.FechaFin
			,h.Descripcion as HoraHorario            -- citas antiguas: la hora estaba en CAT_HORARIOS
			,ISNULL(s.Descripcion, '') as Especialista
			,ISNULL(tc.Descripcion, '') as TipoCita
			,ISNULL(ec.Descripcion, '') as Estado
			,ISNULL(ec.Colors, 'secondary') as Color
			,ISNULL(c.Comentarios, '') as Comentarios
			,ISNULL(STUFF((select ', ' + ct.Descripcion
						   from EXP_CITASTRATAMIENTOS as ct
						   where ct.Id_Cita_FK = c.Id_Cita
						   for xml path(''), type).value('.', 'varchar(max)'), 1, 2, ''), '') as Tratamientos
		from EXP_CITAS as c
			left join CAT_HORARIOS as h on h.Id_Horario = c.Id_Horario_fk
			left join CAT_ESPECIALISTAS as s on s.Id_Especialista = c.Id_Especialista_fk
			left join CAT_TIPOSCITAS as tc on tc.Id_TipoCita = c.Id_TipoCita_FK
			left join CAT_ESTADOSCITAS as ec on ec.Id_Estado = c.Id_EstadoCita_fk
		where c.Id_Expediente_fk = @id
		order by ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2)) desc, c.Id_Cita desc
		return
	end

	/* 4: procedimientos (más recientes primero) con sus tratamientos */
	if @accion = 4
	begin
		select
			p.Id_Procedimiento
			,p.Fecha
			,p.InicioProcedimiento
			,p.FinalProcedimiento
			,ISNULL(p.Estado, '') as Estado
			,ISNULL(s.Descripcion, '') as Especialista
			,ISNULL(tc.Descripcion, '') as TipoCita
			,ISNULL(p.Diagnostico, '') as Diagnostico
			,ISNULL(p.Resultados, '') as Resultados
			,ISNULL(p.Recomendaciones, '') as Recomendaciones
			,ISNULL(p.Comentarios, '') as Comentarios
		from EXP_PROCEDIMIENTOS as p
			left join CAT_ESPECIALISTAS as s on s.Id_Especialista = p.Id_Especialista_fk
			left join CAT_TIPOSCITAS as tc on tc.Id_TipoCita = p.Id_TipoCita_FK
		where p.Id_Expediente_fk = @id
		order by p.Fecha desc, ISNULL(p.InicioProcedimiento, CAST(p.Fecha as datetime2)) desc, p.Id_Procedimiento desc

		select t.Id_Procedimiento_FK as Id_Procedimiento, t.Descripcion, ISNULL(t.Valor, 0) as Valor
		from EXP_PROCEDIMIENTOSTRATAMIENTOS as t
			inner join EXP_PROCEDIMIENTOS as p on p.Id_Procedimiento = t.Id_Procedimiento_FK
		where p.Id_Expediente_fk = @id
		order by t.Id_Procedimiento_FK, t.Id
		return
	end

	/* 5: reclamos */
	if @accion = 5
	begin
		select
			r.Id_Reclamo
			,r.FechaCrea
			,ISNULL(r.UsuarioCrea, '') as Usuario
			,ISNULL(s.Descripcion, '') as Especialista
			,r.Id_Procedimiento_FK as Id_Procedimiento
			,p.Fecha as FechaProcedimiento
			,ISNULL(r.Reclamo, '') as Reclamo
		from EXP_Reclamos as r
			left join CAT_ESPECIALISTAS as s on s.Id_Especialista = r.Id_Especialista_FK
			left join EXP_PROCEDIMIENTOS as p on p.Id_Procedimiento = r.Id_Procedimiento_FK
		where r.Id_Expediente_fk = @id
		order by r.FechaCrea desc
		return
	end

	/* 6: guardar foto (data URL JPEG ya normalizada en la aplicación) | 7: quitar foto */
	if @accion in (6, 7)
	begin
		update EXP_EXPEDIENTES set
			Foto = case when @accion = 6 then @foto end
			,UsuarioModifica = @user
			,FechaModifica = @ahora
		where Id_Expediente = @id

		select @id as Id_Expediente
		return
	end;

	THROW 50099, 'Acción no válida.', 1;
END
GO

/* #####################################################################
   15/35  Reportes\sql\REP_Reportes.sql
   ##################################################################### */
PRINT N'>> 15/35 Reportes\sql\REP_Reportes.sql';
GO
/* =====================================================================
   DPieCenter - Reportes de citas, procedimientos y expedientes
   (Reportes/frm_repReporteCitas.aspx, frm_repReporteProcedimientos.aspx, frm_Expedientes.aspx)

   REP_SP_Reportes:
     @accion 1 citas | 2 procedimientos finalizados (+ sus tratamientos) | 3 expedientes registrados | 4 catálogos de los filtros
             5 pacientes por procedimientos y citas (de mayor a menor)
   Las fechas y horas se toman de FechaInicio de la cita (las citas antiguas sin FechaInicio usan Fecha y CAT_HORARIOS).
   El paciente se busca por nombre, apellido, documento o celular.
   Script idempotente: se puede ejecutar varias veces.
   ===================================================================== */
SET NOCOUNT ON;
GO

CREATE OR ALTER PROCEDURE [dbo].[REP_SP_Reportes]
	 @accion       int
	,@desde        date = null
	,@hasta        date = null
	,@especialista bigint = 0
	,@estado       bigint = 0
	,@tipoCita     bigint = 0
	,@tratamiento  bigint = 0
	,@sexo         bigint = 0
	,@departamento bigint = 0
	,@fuente       varchar(20) = null     -- Facebook | Instagram | TikTok | WhatsApp | Buscador | Recomendado | Otros | SinDato
	,@paciente     varchar(100) = null
	,@sucursal     int = 0                -- 0: todas las sucursales
AS
BEGIN
	SET NOCOUNT ON;

	/* 4: catálogos de los filtros */
	if @accion = 4
	begin
		select Id_Especialista as Id, Descripcion as Texto from CAT_ESPECIALISTAS order by IsActivo desc, Descripcion
		select Id_Estado as Id, Descripcion as Texto from CAT_ESTADOSCITAS where IsActivo = 1 order by Id_Estado
		select Id_TipoCita as Id, Descripcion as Texto from CAT_TIPOSCITAS order by Descripcion
		select Id_Tratamientos as Id, Descripcion as Texto from CAT_TRATAMIENTOS order by IsActivo desc, Descripcion
		select Id_Sexos as Id, Descripcion as Texto from CAT_SEXOS order by Descripcion
		select Id_Departamento as Id, Descripcion as Texto from CAT_DEPARTAMENTOS order by Descripcion
		return
	end

	if @desde is null or @hasta is null or @hasta < @desde
		THROW 50090, 'Seleccione un rango de fechas válido.', 1;
	if DATEDIFF(DAY, @desde, @hasta) > 731
		THROW 50091, 'El rango no puede superar dos años.', 1;

	declare @fin datetime2 = DATEADD(DAY, 1, CAST(@hasta as datetime2))
	set @paciente = NULLIF(LTRIM(RTRIM(@paciente)), '')
	declare @digitos varchar(100) = REPLACE(REPLACE(@paciente, '-', ''), ' ', '')

	-- Expedientes que coinciden con el texto del paciente (null = sin filtro)
	declare @pacientes table (Id bigint primary key)
	if @paciente is not null
		insert into @pacientes
		select Id_Expediente from EXP_EXPEDIENTES
		where (Nombres + ' ' + Apellidos) like '%' + @paciente + '%'
			or (Apellidos + ' ' + Nombres) like '%' + @paciente + '%'
			or (LEN(@digitos) >= 3 and (REPLACE(Documento, '-', '') like '%' + @digitos + '%' or Celular like '%' + @digitos + '%'))

	/* 1: citas */
	if @accion = 1
	begin
		select
			c.Id_Cita
			,ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2)) as Inicio
			,c.FechaFin
			,h.Descripcion as HoraHorario
			,e.Id_Expediente
			,LTRIM(RTRIM(e.Nombres + ' ' + e.Apellidos)) as Paciente
			,ISNULL(e.Documento, '') as Documento
			,ISNULL(e.Celular, '') as Celular
			,ISNULL(tc.Descripcion, '') as TipoCita
			,ISNULL(s.Descripcion, '') as Especialista
			,c.Id_EstadoCita_fk as Id_Estado
			,ISNULL(ec.Descripcion, '') as Estado
			,ISNULL(ec.Colors, 'secondary') as Color
			,ISNULL(ec.Cancelada, 0) as EsCancelada
			,ISNULL(ec.Finalizada, 0) as EsFinalizada
			,ISNULL(c.Comentarios, '') as Comentarios
			,ISNULL(STUFF((select ', ' + ct.Descripcion from EXP_CITASTRATAMIENTOS as ct where ct.Id_Cita_FK = c.Id_Cita
						   for xml path(''), type).value('.', 'varchar(max)'), 1, 2, ''), '') as Tratamientos
			,ISNULL((select SUM(ct.Valor) from EXP_CITASTRATAMIENTOS as ct where ct.Id_Cita_FK = c.Id_Cita), 0) as Valor
			,ISNULL(c.UsuarioCrea, '') as UsuarioCrea
			,c.FechaCrea
		from EXP_CITAS as c
			inner join EXP_EXPEDIENTES as e on e.Id_Expediente = c.Id_Expediente_fk
			left join CAT_HORARIOS as h on h.Id_Horario = c.Id_Horario_fk
			left join CAT_ESPECIALISTAS as s on s.Id_Especialista = c.Id_Especialista_fk
			left join CAT_ESTADOSCITAS as ec on ec.Id_Estado = c.Id_EstadoCita_fk
			left join CAT_TIPOSCITAS as tc on tc.Id_TipoCita = c.Id_TipoCita_FK
		where ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2)) >= @desde
			and ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2)) < @fin
			and (@especialista = 0 or c.Id_Especialista_fk = @especialista)
			and (@estado = 0 or c.Id_EstadoCita_fk = @estado)
			and (@tipoCita = 0 or c.Id_TipoCita_FK = @tipoCita)
			and (@paciente is null or c.Id_Expediente_fk in (select Id from @pacientes))
			and (@sucursal = 0 or c.Id_Sucursal_FK = @sucursal)
		order by ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2)), c.Id_Cita
		return
	end

	/* 2: procedimientos finalizados y sus tratamientos */
	if @accion = 2
	begin
		declare @procs table (Id bigint primary key)
		insert into @procs
		select p.Id_Procedimiento
		from EXP_PROCEDIMIENTOS as p
		where p.Estado = 'F' and p.Fecha >= @desde and p.Fecha <= @hasta
			and (@especialista = 0 or p.Id_Especialista_fk = @especialista)
			and (@tipoCita = 0 or p.Id_TipoCita_FK = @tipoCita)
			and (@paciente is null or p.Id_Expediente_fk in (select Id from @pacientes))
			and (@sucursal = 0 or p.Id_Sucursal_FK = @sucursal)
			and (@tratamiento = 0 or exists (select 1 from EXP_PROCEDIMIENTOSTRATAMIENTOS as t
											 where t.Id_Procedimiento_FK = p.Id_Procedimiento and t.Id_Tratamiento_FK = @tratamiento))

		select
			p.Id_Procedimiento
			,p.Fecha
			,p.InicioProcedimiento
			,p.FinalProcedimiento
			,e.Id_Expediente
			,LTRIM(RTRIM(e.Nombres + ' ' + e.Apellidos)) as Paciente
			,ISNULL(e.Documento, '') as Documento
			,ISNULL(s.Descripcion, '') as Especialista
			,ISNULL(tc.Descripcion, '') as TipoCita
			,ISNULL(p.Diagnostico, '') as Diagnostico
			,f.Id_factura as Id_Factura
			,f.Estado as FacturaCobrada
			,ISNULL(ISNULL(p.UsuarioModifica, p.UsuarioCrea), '') as Usuario
		from @procs as x
			inner join EXP_PROCEDIMIENTOS as p on p.Id_Procedimiento = x.Id
			inner join EXP_EXPEDIENTES as e on e.Id_Expediente = p.Id_Expediente_fk
			left join CAT_ESPECIALISTAS as s on s.Id_Especialista = p.Id_Especialista_fk
			left join CAT_TIPOSCITAS as tc on tc.Id_TipoCita = p.Id_TipoCita_FK
			outer apply (select top 1 Id_factura, Estado from CAJ_FACTURAS where Id_Procedimiento_FK = p.Id_Procedimiento order by Id_factura desc) as f
		order by p.Fecha, p.Id_Procedimiento

		select t.Id_Procedimiento_FK as Id_Procedimiento, ISNULL(t.Descripcion, '') as Descripcion, ISNULL(t.Valor, 0) as Valor
		from EXP_PROCEDIMIENTOSTRATAMIENTOS as t
			inner join @procs as x on x.Id = t.Id_Procedimiento_FK
		order by t.Id_Procedimiento_FK, t.Id
		return
	end

	/* 3: expedientes registrados en el rango */
	if @accion = 3
	begin
		select
			e.Id_Expediente
			,e.FechaCrea
			,ISNULL(e.Documento, '') as Documento
			,ISNULL(td.Descripcion, '') as TipoDocumento
			,LTRIM(RTRIM(e.Nombres + ' ' + e.Apellidos)) as Paciente
			,e.FechaNacimiento
			,ISNULL(sx.Descripcion, '') as Sexo
			,ISNULL(e.Celular, '') as Celular
			,ISNULL(e.Email, '') as Email
			,ISNULL(m.Descripcion, '') as Municipio
			,ISNULL(d.Descripcion, '') as Departamento
			,ISNULL(e.Facebook, 0) as Facebook
			,ISNULL(e.Instagram, 0) as Instagram
			,ISNULL(e.Buscador, 0) as Buscador
			,ISNULL(e.Recomendado, 0) as Recomendado
			,ISNULL(e.TikTok, 0) as TikTok
			,ISNULL(e.WhatsApp, 0) as WhatsApp
			,ISNULL(e.Otros, 0) as Otros
			,ISNULL(v.Visitas, 0) as Visitas
			,v.UltimaVisita
			,ISNULL(e.UsuarioCrea, '') as UsuarioCrea
		from EXP_EXPEDIENTES as e
			left join CAT_TIPOSDOCUMENTOS as td on td.Id_TipoDocumento = e.Id_TipoDocumento_fk
			left join CAT_SEXOS as sx on sx.Id_Sexos = e.Id_Sexo_fk
			left join CAT_MUNICIPIOS as m on m.Id_Municipio = e.Id_Municipio_fk
			left join CAT_DEPARTAMENTOS as d on d.Id_Departamento = m.Id_Departamento_fk
			outer apply (select COUNT(distinct p.Fecha) as Visitas, MAX(p.Fecha) as UltimaVisita
						 from EXP_PROCEDIMIENTOS as p where p.Id_Expediente_fk = e.Id_Expediente and p.Estado = 'F') as v
		where e.FechaCrea >= @desde and e.FechaCrea < @fin
			and (@sexo = 0 or e.Id_Sexo_fk = @sexo)
			and (@departamento = 0 or m.Id_Departamento_fk = @departamento)
			and (@paciente is null or e.Id_Expediente in (select Id from @pacientes))
			and (@sucursal = 0 or e.Id_Sucursal_FK = @sucursal)       -- sucursal donde se registró
			and (@fuente is null
				 or (@fuente = 'Facebook' and e.Facebook = 1)
				 or (@fuente = 'Instagram' and e.Instagram = 1)
				 or (@fuente = 'Buscador' and e.Buscador = 1)
				 or (@fuente = 'Recomendado' and e.Recomendado = 1)
				 or (@fuente = 'TikTok' and e.TikTok = 1)
				 or (@fuente = 'WhatsApp' and e.WhatsApp = 1)
				 or (@fuente = 'Otros' and e.Otros = 1)
				 or (@fuente = 'SinDato' and ISNULL(e.Facebook,0) = 0 and ISNULL(e.Instagram,0) = 0 and ISNULL(e.Buscador,0) = 0 and ISNULL(e.Recomendado,0) = 0
					 and ISNULL(e.TikTok,0) = 0 and ISNULL(e.WhatsApp,0) = 0 and ISNULL(e.Otros,0) = 0))
		order by e.FechaCrea, e.Id_Expediente
		return
	end;

	/* 5: pacientes por procedimientos y citas en el rango, de mayor a menor (Reportes/frm_repPacientesActividad.aspx).
	      Citas: todas menos las anuladas (se separan atendidas y canceladas). Procedimientos: finalizados.
	      Valor: suma de los tratamientos de los procedimientos con el descuento vigente de cada tratamiento. */
	if @accion = 5
	begin
		declare @anulada bigint = 7
		declare @canc bigint = (select top 1 Id_Estado from CAT_ESTADOSCITAS where Cancelada = 1 order by Id_Estado)
		declare @fina bigint = (select top 1 Id_Estado from CAT_ESTADOSCITAS where Finalizada = 1 order by Id_Estado)

		;with ci as (
			select c.Id_Expediente_fk as Id_Expediente
				,COUNT(*) as Citas
				,SUM(case when c.Id_EstadoCita_fk = @fina then 1 else 0 end) as Atendidas
				,SUM(case when c.Id_EstadoCita_fk = @canc then 1 else 0 end) as Canceladas
				,MAX(ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2))) as UltimaCita
			from EXP_CITAS as c
			where ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2)) >= @desde
				and ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2)) < @fin
				and ISNULL(c.Id_EstadoCita_fk, 0) <> @anulada
				and (@especialista = 0 or c.Id_Especialista_fk = @especialista)
				and (@sucursal = 0 or c.Id_Sucursal_FK = @sucursal)
			group by c.Id_Expediente_fk
		), pr as (
			select p.Id_Expediente_fk as Id_Expediente
				,COUNT(*) as Procedimientos
				,COUNT(distinct p.Fecha) as Visitas
				,MAX(p.Fecha) as UltimoProcedimiento
				,SUM(ISNULL(v.Valor, 0)) as Valor
			from EXP_PROCEDIMIENTOS as p
				outer apply (select SUM(t.Valor - ROUND(t.Valor * ISNULL(ct.Descuento, 0) / 100, 2)) as Valor
							 from EXP_PROCEDIMIENTOSTRATAMIENTOS as t left join CAT_TRATAMIENTOS as ct on ct.Id_Tratamientos = t.Id_Tratamiento_FK
							 where t.Id_Procedimiento_FK = p.Id_Procedimiento) as v
			where p.Estado = 'F' and p.Fecha >= @desde and p.Fecha <= @hasta
				and (@especialista = 0 or p.Id_Especialista_fk = @especialista)
				and (@sucursal = 0 or p.Id_Sucursal_FK = @sucursal)
			group by p.Id_Expediente_fk
		)
		select
			e.Id_Expediente
			,LTRIM(RTRIM(e.Nombres + ' ' + e.Apellidos)) as Paciente
			,ISNULL(e.Documento, '') as Documento
			,ISNULL(e.Celular, '') as Celular
			,e.FechaNacimiento
			,ISNULL(pr.Procedimientos, 0) as Procedimientos
			,ISNULL(pr.Visitas, 0) as Visitas
			,CAST(ISNULL(pr.Valor, 0) as decimal(12,2)) as Valor
			,pr.UltimoProcedimiento
			,ISNULL(ci.Citas, 0) as Citas
			,ISNULL(ci.Atendidas, 0) as Atendidas
			,ISNULL(ci.Canceladas, 0) as Canceladas
			,ci.UltimaCita
		from EXP_EXPEDIENTES as e
			left join ci on ci.Id_Expediente = e.Id_Expediente
			left join pr on pr.Id_Expediente = e.Id_Expediente
		where (ci.Id_Expediente is not null or pr.Id_Expediente is not null)
			and (@paciente is null or e.Id_Expediente in (select Id from @pacientes))
		order by ISNULL(pr.Procedimientos, 0) desc, ISNULL(ci.Citas, 0) desc, ISNULL(pr.Valor, 0) desc, Paciente
		return
	end;

	THROW 50099, 'Acción no válida.', 1;
END
GO

/* ---------- Menú: Reportes > Pacientes por actividad (mismos grupos que los demás reportes) ---------- */
IF NOT EXISTS (SELECT 1 FROM dbo.Sys_Opciones WHERE AccesoURL = 'Reportes/frm_repPacientesActividad.aspx')
BEGIN
    BEGIN TRANSACTION;
    DECLARE @opcion bigint;
    INSERT INTO dbo.Sys_Opciones (Descripcion, Abreviado, AccesoURL, IdModulo_FK, Id_UsuarioCrea_FK, FechaCreacion, Orden)
    VALUES ('Pacientes por actividad', 'PA', 'Reportes/frm_repPacientesActividad.aspx', 6, 'admin', GETDATE(), 5);
    SET @opcion = SCOPE_IDENTITY();
    INSERT INTO dbo.Sys_Permisos (IdAplicativo_FK, IdModulo_FK, IdOpcion_FK, IdGrupo_FK, Id_UsuarioCrea_FK, FechaCreacion)
    SELECT 2, 6, @opcion, g.Grupo, 'admin', GETDATE()
    FROM (VALUES ('Administradores'), ('ADMINISTRATIVOS'), ('Direccion')) as g(Grupo)
    WHERE EXISTS (SELECT 1 FROM dbo.Sys_Permisos WHERE IdGrupo_FK = g.Grupo);
    INSERT INTO dbo.Sys_AccesosObjetos (IdAplicativo_FK, IdModulo_FK, IdOpcion_FK, IdGrupo_FK, Descripcion, Accion)
    VALUES (2, 6, @opcion, 'Administradores', 'Pacientes por actividad', 1);
    COMMIT TRANSACTION;
END
GO

/* #####################################################################
   16/35  Reportes\sql\REP_Garantias.sql
   ##################################################################### */
PRINT N'>> 16/35 Reportes\sql\REP_Garantias.sql';
GO
/* =====================================================================
   DPieCenter - Reporte de Garantía de Servicios (Reportes/frm_repGarantias.aspx)

   REP_SP_Garantias @accion:
     1 detalle de las garantías registradas en el periodo (fecha de registro), con paciente, especialista,
       procedimiento, tratamientos y si el especialista ya la vio.
       Filtros: @especialista, @visto (0 todas | 1 no vistas | 2 vistas), @tratamiento (el procedimiento lo incluye),
       @paciente (nombre, documento o celular), @sucursal (la del procedimiento; 0 = todas)
     2 procedimientos finalizados del periodo por especialista (para el % de garantías)
   Script idempotente: se puede ejecutar varias veces.
   ===================================================================== */
SET NOCOUNT ON;
GO

CREATE OR ALTER PROCEDURE [dbo].[REP_SP_Garantias]
     @accion       int
    ,@desde        date
    ,@hasta        date
    ,@especialista bigint = 0
    ,@visto        int = 0
    ,@tratamiento  bigint = 0
    ,@paciente     varchar(100) = NULL
    ,@sucursal     int = 0
AS
BEGIN
    SET NOCOUNT ON;
    declare @fin date = DATEADD(DAY, 1, @hasta)
    set @paciente = NULLIF(LTRIM(RTRIM(@paciente)), '')

    if @accion = 1
    begin
        select r.Id_Reclamo
            ,r.FechaCrea as Fecha
            ,r.UsuarioCrea as Usuario
            ,r.FechaModifica, r.UsuarioModifica
            ,r.Reclamo
            ,r.Id_Especialista_FK as Id_Especialista, ISNULL(s.Descripcion, '') as Especialista
            ,r.Id_Expediente_fk as Id_Expediente
            ,LTRIM(RTRIM(ISNULL(e.Nombres, '') + ' ' + ISNULL(e.Apellidos, ''))) as Paciente
            ,ISNULL(e.Documento, '') as Documento, ISNULL(e.Celular, '') as Celular
            ,r.Id_Procedimiento_FK as Id_Procedimiento, p.Fecha as FechaProcedimiento
            ,ISNULL(STUFF((select ', ' + t.Descripcion from EXP_PROCEDIMIENTOSTRATAMIENTOS as t
                           where t.Id_Procedimiento_FK = r.Id_Procedimiento_FK order by t.Descripcion
                           for xml path(''), type).value('.', 'varchar(max)'), 1, 2, ''), '') as Tratamientos
            ,ISNULL(r.Visto, 0) as Visto, r.FechaVisto, r.UsuarioVisto
            ,ISNULL(su.Nombre, '') as Sucursal
        from EXP_Reclamos as r
            left join CAT_ESPECIALISTAS as s on s.Id_Especialista = r.Id_Especialista_FK
            left join EXP_EXPEDIENTES as e on e.Id_Expediente = r.Id_Expediente_fk
            left join EXP_PROCEDIMIENTOS as p on p.Id_Procedimiento = r.Id_Procedimiento_FK
            left join CAT_SUCURSALES as su on su.Id_Sucursal = p.Id_Sucursal_FK
        where r.FechaCrea >= @desde and r.FechaCrea < @fin
            and (@especialista = 0 or r.Id_Especialista_FK = @especialista)
            and (@visto = 0 or (@visto = 1 and ISNULL(r.Visto, 0) = 0) or (@visto = 2 and r.Visto = 1))
            and (@tratamiento = 0 or exists (select 1 from EXP_PROCEDIMIENTOSTRATAMIENTOS as t
                                             where t.Id_Procedimiento_FK = r.Id_Procedimiento_FK and t.Id_Tratamiento_FK = @tratamiento))
            and (@sucursal = 0 or p.Id_Sucursal_FK = @sucursal)
            and (@paciente is null or e.Nombres + ' ' + e.Apellidos like '%' + @paciente + '%'
                 or e.Documento like '%' + @paciente + '%' or e.Celular like '%' + @paciente + '%')
        order by r.FechaCrea desc, r.Id_Reclamo desc
        return
    end

    if @accion = 2
    begin
        select p.Id_Especialista_fk as Id_Especialista, ISNULL(s.Descripcion, '') as Especialista, COUNT(*) as Procedimientos
        from EXP_PROCEDIMIENTOS as p
            left join CAT_ESPECIALISTAS as s on s.Id_Especialista = p.Id_Especialista_fk
        where p.Estado = 'F' and p.Fecha >= @desde and p.Fecha < @fin
            and (@especialista = 0 or p.Id_Especialista_fk = @especialista)
            and (@sucursal = 0 or p.Id_Sucursal_FK = @sucursal)
            and (@tratamiento = 0 or exists (select 1 from EXP_PROCEDIMIENTOSTRATAMIENTOS as t
                                             where t.Id_Procedimiento_FK = p.Id_Procedimiento and t.Id_Tratamiento_FK = @tratamiento))
        group by p.Id_Especialista_fk, s.Descripcion
        return
    end;

    THROW 50099, 'Acción no válida.', 1;
END
GO

/* ---------- Menú: Reportes > Garantía de Servicios (mismos grupos que los demás reportes) ---------- */
IF NOT EXISTS (SELECT 1 FROM dbo.Sys_Opciones WHERE AccesoURL = 'Reportes/frm_repGarantias.aspx')
BEGIN
    BEGIN TRANSACTION;
    DECLARE @opcion bigint;
    INSERT INTO dbo.Sys_Opciones (Descripcion, Abreviado, AccesoURL, IdModulo_FK, Id_UsuarioCrea_FK, FechaCreacion, Orden)
    VALUES ('Garantía de Servicios', 'GS', 'Reportes/frm_repGarantias.aspx', 6, 'admin', GETDATE(), 6);
    SET @opcion = SCOPE_IDENTITY();
    INSERT INTO dbo.Sys_Permisos (IdAplicativo_FK, IdModulo_FK, IdOpcion_FK, IdGrupo_FK, Id_UsuarioCrea_FK, FechaCreacion)
    SELECT 2, 6, @opcion, g.Grupo, 'admin', GETDATE()
    FROM (VALUES ('Administradores'), ('ADMINISTRATIVOS'), ('Direccion')) as g(Grupo)
    WHERE EXISTS (SELECT 1 FROM dbo.Sys_Permisos WHERE IdGrupo_FK = g.Grupo);
    INSERT INTO dbo.Sys_AccesosObjetos (IdAplicativo_FK, IdModulo_FK, IdOpcion_FK, IdGrupo_FK, Descripcion, Accion)
    VALUES (2, 6, @opcion, 'Administradores', 'Garantía de Servicios', 1);
    COMMIT TRANSACTION;
END
GO

/* #####################################################################
   17/35  Reportes\sql\REP_CajaEspecialistas.sql
   ##################################################################### */
PRINT N'>> 17/35 Reportes\sql\REP_CajaEspecialistas.sql';
GO
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

/* #####################################################################
   18/35  Opciones\sql\SYS_Administracion.sql
   ##################################################################### */
PRINT N'>> 18/35 Opciones\sql\SYS_Administracion.sql';
GO
/* =====================================================================
   DPieCenter - Administración del sistema (menú Opciones)

   SYS_SP_Administracion: módulos, opciones, grupos, permisos, dashboards, usuarios y datos de la empresa,
   con validaciones (THROW 5xxxx con mensaje para el usuario). Lo usa Opciones/AdministracionRepository.cs.
   Los permisos se leen y guardan directamente en Sys_Permisos (Sys_AccesosObjetos era una tabla temporal
   que se borraba completa cada vez que alguien abría la pantalla de permisos).
   No modifica los SP anteriores (Sys_SP_Modulos, Sys_SP_Usuarios, ...).

   Acciones
     10 módulos                11 guardar módulo         12 eliminar módulo
     20 opciones de un módulo  21 guardar opción         22 eliminar opción (y sus permisos)
     30 grupos                 31 guardar grupo          32 eliminar grupo (y sus permisos)
     40 permisos de un grupo   41 dar / quitar opción    42 dar / quitar módulo completo
     50 dashboards             51 guardar dashboard      52 eliminar dashboard
     60 usuarios               61 un usuario             62 guardar usuario    63 activar / inactivar
     64 restablecer clave      65 eliminar usuario
     70 datos de la empresa (sin la clave del correo)    71 guardar datos de la empresa
     80 departamentos          81 municipios de un departamento
   Script idempotente: se puede ejecutar varias veces.
   ===================================================================== */
SET NOCOUNT ON;
GO

/* Documento (DUI o NIT) del usuario: se imprime en el PDF del DTE como "Documento emisor" */
IF COL_LENGTH('dbo.Sys_Usuarios', 'Documento') IS NULL
    ALTER TABLE dbo.Sys_Usuarios ADD Documento varchar(20) NULL;
GO

/* Clave del "Correo para envíos (SMTP)" de la empresa: ahora se guarda cifrada (aes:...), necesita más espacio.
   La que ya estaba guardada en texto se sigue leyendo; queda cifrada la próxima vez que se guarde. */
IF COL_LENGTH('dbo.Sys_ConfiguracionApp', 'ClaveEmail') < 500
    ALTER TABLE dbo.Sys_ConfiguracionApp ALTER COLUMN ClaveEmail varchar(500) NULL;
GO

CREATE OR ALTER PROCEDURE [dbo].[SYS_SP_Administracion]
	 @accion        int
	,@usuarioSesion varchar(20)   = NULL      -- quien hace el cambio
	,@id            bigint        = 0         -- módulo, opción o dashboard
	,@nuevo         bit           = 0         -- grupo o usuario nuevo
	,@descripcion   varchar(250)  = NULL
	,@icono         varchar(50)   = NULL
	,@url           varchar(200)  = NULL
	,@abreviado     varchar(10)   = NULL
	,@orden         int           = 0
	,@modulo        bigint        = 0
	,@grupo         varchar(20)   = NULL
	,@valor         bit           = 0
	,@estado        char(1)       = NULL
	-- usuarios
	,@idUsuario     varchar(20)   = NULL
	,@nombres       varchar(200)  = NULL
	,@apellidos     varchar(200)  = NULL
	,@email         varchar(100)  = NULL
	,@telefono      varchar(20)   = NULL
	,@celular       varchar(20)   = NULL
	,@documento     varchar(20)   = NULL      -- DUI o NIT del usuario
	,@caducidad     int           = 90
	,@dashboard     bigint        = 0
	,@responsable   bit           = 0
	,@clave         varchar(500)  = NULL      -- clave ya codificada (usuarios) o clave cifrada del correo (empresa; NULL = no cambiarla)
	,@sucursal      int           = 0         -- sucursal fija del usuario (0 = Casa Matriz)
	-- empresa
	,@nombreEmpresa varchar(250)  = NULL
	,@propietario   varchar(250)  = NULL
	,@nrc           varchar(20)   = NULL
	,@nit           varchar(20)   = NULL
	,@dui           varchar(20)   = NULL
	,@actividad     varchar(500)  = NULL
	,@departamento  bigint        = 0
	,@municipio     bigint        = 0
	,@direccion     varchar(max)  = NULL
	,@servidor      varchar(250)  = NULL
	,@puerto        int           = 0
AS
BEGIN
	SET NOCOUNT ON;

	declare @app bigint = 2      -- aplicativo de la clínica
	set @descripcion = NULLIF(LTRIM(RTRIM(@descripcion)), '')
	set @icono = NULLIF(LTRIM(RTRIM(@icono)), '')
	set @url = NULLIF(LTRIM(RTRIM(@url)), '')
	set @abreviado = NULLIF(LTRIM(RTRIM(@abreviado)), '')
	set @grupo = NULLIF(LTRIM(RTRIM(@grupo)), '')
	set @idUsuario = NULLIF(LTRIM(RTRIM(@idUsuario)), '')
	set @nombres = NULLIF(LTRIM(RTRIM(@nombres)), '')
	set @apellidos = NULLIF(LTRIM(RTRIM(@apellidos)), '')
	set @email = NULLIF(LTRIM(RTRIM(@email)), '')
	set @telefono = NULLIF(LTRIM(RTRIM(@telefono)), '')
	set @celular = NULLIF(LTRIM(RTRIM(@celular)), '')
	set @nombreEmpresa = NULLIF(LTRIM(RTRIM(@nombreEmpresa)), '')
	set @propietario = NULLIF(LTRIM(RTRIM(@propietario)), '')
	set @nrc = NULLIF(LTRIM(RTRIM(@nrc)), '')
	set @nit = NULLIF(LTRIM(RTRIM(@nit)), '')
	set @dui = NULLIF(LTRIM(RTRIM(@dui)), '')
	set @actividad = NULLIF(LTRIM(RTRIM(@actividad)), '')
	set @direccion = NULLIF(LTRIM(RTRIM(@direccion)), '')
	set @servidor = NULLIF(LTRIM(RTRIM(@servidor)), '')

	/* ========== Módulos ========== */
	if @accion = 10
	begin
		select m.Id_Modulo, m.Descripcion, m.Icono, m.Orden
			,(select COUNT(*) from Sys_Opciones as o where o.IdModulo_FK = m.Id_Modulo) as Opciones
			,ISNULL(m.Id_UsuarioModifica_FK, m.Id_UsuarioCrea_FK) as Usuario
			,ISNULL(m.FechaModificacion, m.FechaCreacion) as Fecha
		from Sys_Modulos as m
		where m.IdAplicativo_FK = @app
		order by m.Orden, m.Descripcion
		return
	end

	if @accion = 11
	begin
		if @descripcion is null THROW 50200, 'Ingrese el nombre del módulo.', 1;
		if @icono is null THROW 50201, 'Seleccione el icono del módulo.', 1;
		if @orden < 1 THROW 50202, 'El orden debe ser 1 o mayor.', 1;
		if exists (select 1 from Sys_Modulos where IdAplicativo_FK = @app and Descripcion = @descripcion and Id_Modulo <> @id)
			THROW 50203, 'Ya existe un módulo con ese nombre.', 1;
		if @id = 0
		begin
			insert into Sys_Modulos (Descripcion, Icono, IdAplicativo_FK, Id_UsuarioCrea_FK, FechaCreacion, Orden)
			values (@descripcion, @icono, @app, @usuarioSesion, GETDATE(), @orden)
			select CAST(SCOPE_IDENTITY() as bigint) as Id
			return
		end
		if not exists (select 1 from Sys_Modulos where Id_Modulo = @id) THROW 50204, 'El módulo ya no existe. Actualice la lista.', 1;
		update Sys_Modulos set Descripcion = @descripcion, Icono = @icono, Orden = @orden
			,Id_UsuarioModifica_FK = @usuarioSesion, FechaModificacion = GETDATE()
		where Id_Modulo = @id
		select @id as Id
		return
	end

	if @accion = 12
	begin
		if exists (select 1 from Sys_Opciones where IdModulo_FK = @id)
			THROW 50205, 'El módulo tiene opciones. Elimínelas o muévalas a otro módulo antes de eliminarlo.', 1;
		delete from Sys_Permisos where IdModulo_FK = @id
		delete from Sys_Modulos where Id_Modulo = @id
		select @id as Id
		return
	end

	/* ========== Opciones ========== */
	if @accion = 20
	begin
		select o.Id_Opcion, o.Descripcion, o.Abreviado, o.AccesoURL, o.Orden, o.IdModulo_FK
			,(select COUNT(*) from Sys_Permisos as p where p.IdOpcion_FK = o.Id_Opcion) as Grupos
			,ISNULL(o.Id_UsuarioModifica_FK, o.Id_UsuarioCrea_FK) as Usuario
			,ISNULL(o.FechaModificacion, o.FechaCreacion) as Fecha
		from Sys_Opciones as o
		where o.IdModulo_FK = @modulo
		order by o.Orden, o.Descripcion
		return
	end

	if @accion = 21
	begin
		if not exists (select 1 from Sys_Modulos where Id_Modulo = @modulo) THROW 50210, 'Seleccione un módulo válido.', 1;
		if @descripcion is null THROW 50211, 'Ingrese el nombre de la opción.', 1;
		if @url is null THROW 50212, 'Ingrese la página de la opción (por ejemplo Registros/frm_Pagina.aspx).', 1;
		if @url not like '%_/_%.aspx' and @url not like '%_/_%.aspx?%' THROW 50213, 'La página debe tener la forma Carpeta/pagina.aspx.', 1;
		if @orden < 1 THROW 50214, 'El orden debe ser 1 o mayor.', 1;
		if exists (select 1 from Sys_Opciones where AccesoURL = @url and Id_Opcion <> @id)
			THROW 50215, 'Esa página ya está asignada a otra opción del menú.', 1;
		if exists (select 1 from Sys_Opciones where IdModulo_FK = @modulo and Descripcion = @descripcion and Id_Opcion <> @id)
			THROW 50216, 'Ya existe una opción con ese nombre en el módulo.', 1;
		set @abreviado = ISNULL(@abreviado, UPPER(LEFT(@descripcion, 2)))
		if @id = 0
		begin
			insert into Sys_Opciones (Descripcion, Abreviado, AccesoURL, IdModulo_FK, Id_UsuarioCrea_FK, FechaCreacion, Orden)
			values (@descripcion, @abreviado, @url, @modulo, @usuarioSesion, GETDATE(), @orden)
			select CAST(SCOPE_IDENTITY() as bigint) as Id
			return
		end
		if not exists (select 1 from Sys_Opciones where Id_Opcion = @id) THROW 50217, 'La opción ya no existe. Actualice la lista.', 1;
		begin transaction
			update Sys_Opciones set Descripcion = @descripcion, Abreviado = @abreviado, AccesoURL = @url
				,IdModulo_FK = @modulo, Orden = @orden, Id_UsuarioModifica_FK = @usuarioSesion, FechaModificacion = GETDATE()
			where Id_Opcion = @id
			update Sys_Permisos set IdModulo_FK = @modulo where IdOpcion_FK = @id     -- si cambió de módulo, los permisos la siguen
		commit transaction
		select @id as Id
		return
	end

	if @accion = 22
	begin
		if exists (select 1 from Sys_Opciones where Id_Opcion = @id and AccesoURL = 'Opciones/form_confAccesosObjetos.aspx')
			THROW 50218, 'La opción Permisos no se puede eliminar: nadie podría volver a asignar permisos.', 1;
		begin transaction
			delete from Sys_Permisos where IdOpcion_FK = @id
			delete from Sys_Opciones where Id_Opcion = @id
		commit transaction
		select @id as Id
		return
	end

	/* ========== Grupos ========== */
	if @accion = 30
	begin
		select g.Id_Grupo, g.Descripcion
			,(select COUNT(*) from Sys_Usuarios as u where u.Id_Grupo_FK = g.Id_Grupo) as Usuarios
			,(select COUNT(*) from Sys_Permisos as p where p.IdGrupo_FK = g.Id_Grupo) as Permisos
			,ISNULL(g.Id_UsuarioModifica_FK, g.Id_UsuarioCrea_FK) as Usuario
			,ISNULL(g.FechaModificacion, g.FechaCreacion) as Fecha
		from Sys_Grupos as g
		order by g.Descripcion
		return
	end

	if @accion = 31
	begin
		if @grupo is null THROW 50220, 'Ingrese el código del grupo.', 1;
		if @grupo like '%[^A-Za-z0-9_]%' THROW 50221, 'El código del grupo solo puede tener letras, números y guion bajo, sin espacios.', 1;
		if @descripcion is null THROW 50222, 'Ingrese la descripción del grupo.', 1;
		if @nuevo = 1
		begin
			if exists (select 1 from Sys_Grupos where Id_Grupo = @grupo) THROW 50223, 'Ya existe un grupo con ese código.', 1;
			insert into Sys_Grupos (Id_Grupo, Descripcion, Id_UsuarioCrea_FK, FechaCreacion)
			values (@grupo, @descripcion, @usuarioSesion, GETDATE())
		end
		else
		begin
			if not exists (select 1 from Sys_Grupos where Id_Grupo = @grupo) THROW 50224, 'El grupo ya no existe. Actualice la lista.', 1;
			update Sys_Grupos set Descripcion = @descripcion, Id_UsuarioModifica_FK = @usuarioSesion, FechaModificacion = GETDATE()
			where Id_Grupo = @grupo
		end
		select CAST(0 as bigint) as Id
		return
	end

	if @accion = 32
	begin
		if @grupo = 'Administradores' THROW 50225, 'El grupo Administradores no se puede eliminar.', 1;
		if exists (select 1 from Sys_Usuarios where Id_Grupo_FK = @grupo)
			THROW 50226, 'El grupo tiene usuarios asignados. Cámbielos de grupo antes de eliminarlo.', 1;
		begin transaction
			delete from Sys_Permisos where IdGrupo_FK = @grupo
			delete from Sys_AccesosObjetos where IdGrupo_FK = @grupo
			delete from Sys_Grupos where Id_Grupo = @grupo
		commit transaction
		select CAST(0 as bigint) as Id
		return
	end

	/* ========== Permisos ========== */
	if @accion = 40
	begin
		select m.Id_Modulo, m.Descripcion as Modulo, m.Icono
			,o.Id_Opcion, o.Descripcion as Opcion, o.AccesoURL
			,CAST(case when exists (select 1 from Sys_Permisos as p where p.IdOpcion_FK = o.Id_Opcion and p.IdGrupo_FK = @grupo) then 1 else 0 end as bit) as Tiene
		from Sys_Modulos as m
			inner join Sys_Opciones as o on o.IdModulo_FK = m.Id_Modulo
		where m.IdAplicativo_FK = @app
		order by m.Orden, m.Descripcion, o.Orden, o.Descripcion
		return
	end

	if @accion in (41, 42)
	begin
		if not exists (select 1 from Sys_Grupos where Id_Grupo = @grupo) THROW 50230, 'Seleccione un grupo válido.', 1;

		declare @ops table (Id_Opcion bigint primary key, Id_Modulo bigint, AccesoURL varchar(200))
		insert into @ops
		select o.Id_Opcion, o.IdModulo_FK, o.AccesoURL
		from Sys_Opciones as o
		where (@accion = 41 and o.Id_Opcion = @id) or (@accion = 42 and o.IdModulo_FK = @id)

		if not exists (select 1 from @ops) THROW 50231, 'La opción ya no existe. Actualice la pantalla.', 1;
		-- evita que los administradores se queden sin acceso a esta pantalla
		if @valor = 0 and @grupo = 'Administradores' and exists (select 1 from @ops where AccesoURL = 'Opciones/form_confAccesosObjetos.aspx')
			THROW 50232, 'No se puede quitar a Administradores el acceso a Permisos: nadie podría volver a asignarlos.', 1;

		if @valor = 1
			insert into Sys_Permisos (IdAplicativo_FK, IdModulo_FK, IdOpcion_FK, IdGrupo_FK, Id_UsuarioCrea_FK, FechaCreacion)
			select @app, x.Id_Modulo, x.Id_Opcion, @grupo, @usuarioSesion, GETDATE()
			from @ops as x
			where not exists (select 1 from Sys_Permisos as p where p.IdOpcion_FK = x.Id_Opcion and p.IdGrupo_FK = @grupo)
		else
			delete p from Sys_Permisos as p inner join @ops as x on x.Id_Opcion = p.IdOpcion_FK
			where p.IdGrupo_FK = @grupo

		select CAST(COUNT(*) as bigint) as Id from Sys_Permisos where IdGrupo_FK = @grupo
		return
	end

	/* ========== Dashboards ========== */
	if @accion = 50
	begin
		select d.Id_Dashboard, d.Descripcion, d.DashboardUrl, d.Estatus
			,(select COUNT(*) from Sys_Usuarios as u where u.Id_Dashboard_FK = d.Id_Dashboard) as Usuarios
			,ISNULL(d.Id_UsuarioModifica_FK, d.Id_UsuarioCrea_FK) as Usuario
			,ISNULL(d.FechaModificacion, d.FechaCreacion) as Fecha
		from Sys_DashboardInicial as d
		order by d.Id_Dashboard
		return
	end

	if @accion = 51
	begin
		if @descripcion is null THROW 50240, 'Ingrese la descripción del dashboard.', 1;
		if LEN(@descripcion) > 50 THROW 50241, 'La descripción no puede tener más de 50 caracteres.', 1;
		if @url is null THROW 50242, 'Ingrese la página del dashboard.', 1;
		if @url not like '%_/_%.aspx' THROW 50243, 'La página debe tener la forma Carpeta/pagina.aspx.', 1;
		if ISNULL(@estado, '') not in ('A', 'I') THROW 50244, 'Seleccione el estado.', 1;
		if exists (select 1 from Sys_DashboardInicial where Descripcion = @descripcion and Id_Dashboard <> @id)
			THROW 50245, 'Ya existe un dashboard con esa descripción.', 1;
		if @id = 0
		begin
			insert into Sys_DashboardInicial (Descripcion, DashboardUrl, Estatus, Id_UsuarioCrea_FK, FechaCreacion)
			values (@descripcion, @url, @estado, @usuarioSesion, GETDATE())
			select CAST(SCOPE_IDENTITY() as bigint) as Id
			return
		end
		if not exists (select 1 from Sys_DashboardInicial where Id_Dashboard = @id) THROW 50246, 'El dashboard ya no existe. Actualice la lista.', 1;
		if @estado = 'I' and exists (select 1 from Sys_Usuarios where Id_Dashboard_FK = @id and EstatusUsuario = 'A')
			THROW 50247, 'Hay usuarios activos con este dashboard. Asígneles otro antes de inactivarlo.', 1;
		update Sys_DashboardInicial set Descripcion = @descripcion, DashboardUrl = @url, Estatus = @estado
			,Id_UsuarioModifica_FK = @usuarioSesion, FechaModificacion = GETDATE()
		where Id_Dashboard = @id
		select @id as Id
		return
	end

	if @accion = 52
	begin
		if exists (select 1 from Sys_Usuarios where Id_Dashboard_FK = @id)
			THROW 50248, 'Hay usuarios con este dashboard. Asígneles otro antes de eliminarlo.', 1;
		delete from Sys_DashboardInicial where Id_Dashboard = @id
		select @id as Id
		return
	end

	/* ========== Usuarios ========== */
	if @accion in (60, 61)
	begin
		select u.Id_Usuario, u.Nombres, u.Apellidos, u.Id_Grupo_FK, ISNULL(g.Descripcion, u.Id_Grupo_FK) as Grupo
			,u.EstatusUsuario, u.Email, u.Telefono, u.Celular, u.Documento, u.CaducidadClave
			,ISNULL(u.Id_Dashboard_FK, 0) as Id_Dashboard_FK, ISNULL(d.Descripcion, '') as Dashboard
			,CAST(ISNULL(u.Es_Responsable, 0) as bit) as Responsable
			,u.FechaInicioSesion, u.FechaCambioclave
			,ISNULL(u.Id_UsuarioModifica_FK, u.Id_UsuarioCrea_FK) as Usuario
			,ISNULL(u.FechaModificacion, u.FechaCreacion) as Fecha
			,ISNULL(s.Descripcion, '') as Especialista
			,u.Id_Sucursal_FK, ISNULL(su.Nombre, '') as Sucursal
		from Sys_Usuarios as u
			left join Sys_Grupos as g on g.Id_Grupo = u.Id_Grupo_FK
			left join Sys_DashboardInicial as d on d.Id_Dashboard = u.Id_Dashboard_FK
			left join CAT_SUCURSALES as su on su.Id_Sucursal = u.Id_Sucursal_FK
			outer apply (select top 1 Descripcion from CAT_ESPECIALISTAS where UsaurioSystem = u.Id_Usuario and IsActivo = 1) as s
		where @accion = 60 or u.Id_Usuario = @idUsuario
		order by case when u.EstatusUsuario = 'A' then 0 else 1 end, u.Nombres, u.Apellidos
		return
	end

	if @accion = 62     -- @nuevo = 1: usuario nuevo con @clave (clave inicial ya codificada)
	begin
		if @idUsuario is null THROW 50250, 'Ingrese el usuario.', 1;
		if @idUsuario like '%[^A-Za-z0-9._]%' THROW 50251, 'El usuario solo puede tener letras, números, punto y guion bajo, sin espacios.', 1;
		if LEN(@idUsuario) < 3 THROW 50252, 'El usuario debe tener al menos 3 caracteres.', 1;
		if @nombres is null THROW 50253, 'Ingrese los nombres.', 1;
		if @apellidos is null THROW 50254, 'Ingrese los apellidos.', 1;
		if not exists (select 1 from Sys_Grupos where Id_Grupo = @grupo) THROW 50255, 'Seleccione el grupo del usuario.', 1;
		if @email is not null and @email not like '_%@_%._%' THROW 50256, 'El correo electrónico no es válido.', 1;
		if @documento is not null and (@documento like '%[^0-9-]%' or LEN(REPLACE(@documento, '-', '')) not in (9, 14))
			THROW 50249, 'El documento debe ser un DUI (00000000-0) o un NIT de 14 dígitos.', 1;
		if @caducidad < 1 or @caducidad > 999999 THROW 50257, 'Los días de vigencia de la clave deben estar entre 1 y 999999.', 1;
		if @dashboard > 0 and not exists (select 1 from Sys_DashboardInicial where Id_Dashboard = @dashboard and Estatus = 'A')
			THROW 50258, 'Seleccione un dashboard activo.', 1;
		set @sucursal = ISNULL(NULLIF(@sucursal, 0), dbo.SUC_FN_Matriz());
		if not exists (select 1 from CAT_SUCURSALES where Id_Sucursal = @sucursal and IsActivo = 1)
			THROW 50248, 'Seleccione una sucursal activa.', 1;
		-- un administrador no puede quitarse a sí mismo del grupo Administradores
		if @nuevo = 0 and @idUsuario = @usuarioSesion and @grupo <> 'Administradores'
			and exists (select 1 from Sys_Usuarios where Id_Usuario = @idUsuario and Id_Grupo_FK = 'Administradores')
			THROW 50259, 'No puede quitarse a sí mismo del grupo Administradores.', 1;

		if @nuevo = 1
		begin
			if exists (select 1 from Sys_Usuarios where Id_Usuario = @idUsuario) THROW 50260, 'Ya existe un usuario con ese código.', 1;
			if @clave is null THROW 50261, 'No se generó la clave inicial.', 1;
			insert into Sys_Usuarios (Id_Usuario, Id_Grupo_FK, Nombres, Apellidos, EstatusUsuario, ClaveAcceso, CaducidadClave
				,Telefono, Celular, Documento, Email, SesionUsuario, Id_Dashboard_FK, Es_Responsable, Id_UsuarioCrea_FK, FechaCreacion, FechaCambioclave, Id_Sucursal_FK)
			values (@idUsuario, @grupo, @nombres, @apellidos, 'A', @clave, @caducidad
				,@telefono, @celular, @documento, @email, 'I', NULLIF(@dashboard, 0), @responsable, @usuarioSesion, GETDATE(), GETDATE(), @sucursal)
		end
		else
		begin
			if not exists (select 1 from Sys_Usuarios where Id_Usuario = @idUsuario) THROW 50262, 'El usuario ya no existe. Actualice la lista.', 1;
			update Sys_Usuarios set Id_Grupo_FK = @grupo, Nombres = @nombres, Apellidos = @apellidos, CaducidadClave = @caducidad
				,Telefono = @telefono, Celular = @celular, Documento = @documento, Email = @email, Id_Dashboard_FK = NULLIF(@dashboard, 0)
				,Es_Responsable = @responsable, Id_Sucursal_FK = @sucursal, Id_UsuarioModifica_FK = @usuarioSesion, FechaModificacion = GETDATE()
			where Id_Usuario = @idUsuario
		end
		select CAST(0 as bigint) as Id
		return
	end

	if @accion in (63, 64, 65)
	begin
		if not exists (select 1 from Sys_Usuarios where Id_Usuario = @idUsuario) THROW 50263, 'El usuario ya no existe. Actualice la lista.', 1;
		if @idUsuario = @usuarioSesion and @accion in (63, 65)
			THROW 50264, 'No puede inactivar ni eliminar su propio usuario.', 1;
	end

	if @accion = 63
	begin
		if ISNULL(@estado, '') not in ('A', 'I') THROW 50265, 'Estado no válido.', 1;
		update Sys_Usuarios set EstatusUsuario = @estado, Id_UsuarioModifica_FK = @usuarioSesion, FechaModificacion = GETDATE()
		where Id_Usuario = @idUsuario
		select CAST(0 as bigint) as Id
		return
	end

	if @accion = 64     -- la clave nueva (ya codificada) la calcula la aplicación
	begin
		if @clave is null THROW 50266, 'No se generó la clave.', 1;
		begin transaction
			insert into Sys_UsuarioHistoricoClave (Id_Usuario_FK, Clave, FechaCreacion, Id_UsuarioCrea_FK)
			select Id_Usuario, ClaveAcceso, GETDATE(), @usuarioSesion from Sys_Usuarios where Id_Usuario = @idUsuario
			update Sys_Usuarios set ClaveAcceso = @clave, FechaCambioclave = GETDATE()
				,Id_UsuarioModifica_FK = @usuarioSesion, FechaModificacion = GETDATE()
			where Id_Usuario = @idUsuario
		commit transaction
		select CAST(0 as bigint) as Id
		return
	end

	if @accion = 65
	begin
		-- si ya trabajó en el sistema se inactiva en lugar de eliminarse, para no perder el historial
		if exists (select 1 from Sys_UsuariosSesiones where Id_Usuario_FK = @idUsuario)
			or exists (select 1 from CAT_ESPECIALISTAS where UsaurioSystem = @idUsuario)
			or exists (select 1 from EXP_CITAS where UsuarioCrea = @idUsuario)
			or exists (select 1 from EXP_EXPEDIENTES where UsuarioCrea = @idUsuario)
			THROW 50267, 'El usuario tiene registros en el sistema y no se puede eliminar. Inactívelo en su lugar.', 1;
		begin transaction
			delete from Sys_UsuarioHistoricoClave where Id_Usuario_FK = @idUsuario
			delete from Sys_Usuarios where Id_Usuario = @idUsuario
		commit transaction
		select CAST(0 as bigint) as Id
		return
	end

	/* ========== Empresa ========== */
	if @accion = 70
	begin
		select top 1 Id_Configuracion, NombreEmpresa, NombrePropietario, RegistroIVA, NumeroNIT, NumeroDUI, Telefono
			,ActividadEconomica, Departamento, Municipio, Direccion, Email, Servidor, Puerto
			,CAST(case when LEN(ISNULL(ClaveEmail, '')) > 0 then 1 else 0 end as bit) as TieneClave
			,ISNULL(Id_UsuarioModifica_FK, Id_UsuarioCrea_FK) as Usuario
			,ISNULL(FechaModificacion, FechaCreacion) as Fecha
		from Sys_ConfiguracionApp
		order by Id_Configuracion
		return
	end

	if @accion = 71
	begin
		if @nombreEmpresa is null THROW 50270, 'Ingrese el nombre de la empresa.', 1;
		if @propietario is null THROW 50271, 'Ingrese el nombre del propietario o razón social.', 1;
		if @nrc is null THROW 50272, 'Ingrese el NRC.', 1;
		if @nit is null THROW 50273, 'Ingrese el NIT.', 1;
		if @nit like '%[^0-9-]%' THROW 50274, 'El NIT solo puede tener números y guiones.', 1;
		if @telefono is not null and @telefono like '%[^0-9 -]%' THROW 50275, 'El teléfono solo puede tener números.', 1;
		if not exists (select 1 from CAT_DEPARTAMENTOS where Id_Departamento = @departamento) THROW 50276, 'Seleccione el departamento.', 1;
		if not exists (select 1 from CAT_MUNICIPIOS where Id_Municipio = @municipio and Id_Departamento_fk = @departamento) THROW 50277, 'Seleccione el municipio.', 1;
		if @email is not null and @email not like '_%@_%._%' THROW 50278, 'El correo electrónico no es válido.', 1;
		if @puerto < 0 or @puerto > 65535 THROW 50279, 'El puerto debe estar entre 1 y 65535.', 1;

		if not exists (select 1 from Sys_ConfiguracionApp)
		begin
			insert into Sys_ConfiguracionApp (NombreEmpresa, NombrePropietario, RegistroIVA, NumeroNIT, NumeroDUI, Telefono, ActividadEconomica
				,Departamento, Municipio, Direccion, Email, ClaveEmail, Servidor, Puerto, Id_UsuarioCrea_FK, FechaCreacion)
			values (@nombreEmpresa, @propietario, @nrc, @nit, @dui, @telefono, @actividad
				,@departamento, @municipio, @direccion, @email, @clave, @servidor, NULLIF(@puerto, 0), @usuarioSesion, GETDATE())
			select CAST(SCOPE_IDENTITY() as bigint) as Id
			return
		end
		declare @idEmpresa bigint = (select top 1 Id_Configuracion from Sys_ConfiguracionApp order by Id_Configuracion)
		update Sys_ConfiguracionApp set NombreEmpresa = @nombreEmpresa, NombrePropietario = @propietario, RegistroIVA = @nrc
			,NumeroNIT = @nit, NumeroDUI = @dui, Telefono = @telefono, ActividadEconomica = @actividad
			,Departamento = @departamento, Municipio = @municipio, Direccion = @direccion, Email = @email
			,ClaveEmail = ISNULL(@clave, ClaveEmail)      -- sin clave nueva se conserva la guardada
			,Servidor = @servidor, Puerto = NULLIF(@puerto, 0)
			,Id_UsuarioModifica_FK = @usuarioSesion, FechaModificacion = GETDATE()
		where Id_Configuracion = @idEmpresa
		select @idEmpresa as Id
		return
	end

	if @accion = 80
	begin
		select Id_Departamento as Id, Descripcion as Texto from CAT_DEPARTAMENTOS order by Descripcion
		return
	end

	if @accion = 81
	begin
		select Id_Municipio as Id, Descripcion as Texto from CAT_MUNICIPIOS where Id_Departamento_fk = @departamento order by Descripcion
		return
	end;

	THROW 50299, 'Acción no válida.', 1;
END
GO

/* #####################################################################
   19/35  Opciones\sql\SYS_Login_Legado.sql
   ##################################################################### */
PRINT N'>> 19/35 Opciones\sql\SYS_Login_Legado.sql';
GO
/* =====================================================================
   DPieCenter - Procedimientos del login anterior (login.aspx.cs: mtd_leeEmpresa, leeEmpresaByUsuario, leeSesionesByUsuario)

   Solo existían en la base de desarrollo. La pantalla actual de login (assets/js/login.js) ya no llama esos
   WebMethods, pero se dejan para que no fallen si algo los usa:
     Sys_SP_InfoEmpresa          sistema de una sola empresa: @Accion 10 devuelve 0 (sin empresas configuradas)
     Sys_SP_UsuarioCierreSesion  marca la sesión del usuario como cerrada y devuelve 0
   Script idempotente.
   ===================================================================== */
SET NOCOUNT ON;
GO

CREATE OR ALTER PROCEDURE dbo.Sys_SP_InfoEmpresa
     @IdEmpresa             bigint        = 0
    ,@Empresa               varchar(250)  = NULL
    ,@Abreviado             varchar(50)   = NULL
    ,@LogoEmpresa           varchar(max)  = NULL
    ,@usuarioCreacion       varchar(20)   = NULL
    ,@usuarioModificacion   varchar(20)   = NULL
    ,@LogoCliente           varchar(max)  = NULL
    ,@LogoTituloPagina      varchar(max)  = NULL
    ,@TituloPagina          varchar(250)  = NULL
    ,@LogoMenuAplicativo    varchar(max)  = NULL
    ,@ImagenFonoLogin       varchar(max)  = NULL
    ,@ImagenFondoAplicativo varchar(max)  = NULL
    ,@NombreSistema         varchar(250)  = NULL
    ,@MensajeBienvenida     varchar(max)  = NULL
    ,@TituloBienvenida      varchar(250)  = NULL
    ,@SignoMonedaLocal      varchar(10)   = NULL
    ,@SignoMonedaDolar      varchar(10)   = NULL
    ,@HoraInicio            varchar(10)   = NULL
    ,@HoraFinal             varchar(10)   = NULL
    ,@Lunes                 bit           = 1
    ,@Martes                bit           = 1
    ,@Miercoles             bit           = 1
    ,@Jueves                bit           = 1
    ,@Viernes               bit           = 1
    ,@Sabado                bit           = 1
    ,@Domingo               bit           = 1
    ,@Accion                bigint        = 10
AS
BEGIN
    SET NOCOUNT ON;
    IF @Accion = 10
    BEGIN
        SELECT CAST(0 AS bigint) AS IdEmpresa;      -- login.aspx.cs: 0 = sin empresa configurada
        RETURN;
    END

    -- Datos para la pantalla de inicio (logo de Opciones > Empresa; el resto lo pone la página)
    SELECT TOP 1
         CAST('' AS varchar(10)) AS ImagenFonoLogin
        ,ISNULL(CAST(LogoEmpresa AS varchar(max)), '') AS LogoEmpresa
        ,CAST('' AS varchar(10)) AS LogoCliente
        ,CAST('' AS varchar(10)) AS LogoTituloPagina
        ,CAST('D'' Pie Center' AS varchar(50)) AS TituloPagina
        ,CAST('D'' Pie Center' AS varchar(50)) AS NombreSistema
        ,CAST('Bienvenido' AS varchar(50)) AS TituloBienvenida
        ,CAST('' AS varchar(10)) AS MensajeBienvenida
        ,CAST('' AS varchar(10)) AS Agencia
    FROM dbo.Sys_ConfiguracionApp;
    SELECT 'OK' AS resp;
END
GO

CREATE OR ALTER PROCEDURE dbo.Sys_SP_UsuarioCierreSesion
    @IdUsuario varchar(20)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Sys_Usuarios
       SET SesionUsuario = 'I', FechaFinSesion = GETDATE()
     WHERE Id_Usuario = @IdUsuario;
    SELECT 0 AS Sesiones;      -- login.aspx.cs: 0 = sin sesión abierta
END
GO

/* #####################################################################
   20/35  Catalogos\sql\CAT_Catalogos.sql
   ##################################################################### */
PRINT N'>> 20/35 Catalogos\sql\CAT_Catalogos.sql';
GO
/* =====================================================================
   DPieCenter - Catálogos (menú Catálogos)

   CAT_SP_Catalogos: lista, guarda, activa / inactiva y elimina los registros de los catálogos con validaciones
   (THROW 5xxxx con mensaje para el usuario). Lo usa Catalogos/CatalogosRepository.cs.
   @catalogo: departamentos | municipios | sexos | especialistas | estados | horarios | tratamientos | tiposdocumento | tiposcita
   @accion:   1 lista   2 guardar (@id = 0 agrega)   3 eliminar   4 activar / inactivar (@activo)

   La lista devuelve las mismas columnas para todos los catálogos (las que no aplican van en NULL) y "Usos":
   cuántos registros lo usan. Un registro en uso no se puede eliminar; se inactiva para que no aparezca en las listas.
   No modifica los SP anteriores (CAT_SP_Departamentos, ...).
   Script idempotente: se puede ejecutar varias veces.
   ===================================================================== */
SET NOCOUNT ON;
GO

-- Descuento del tratamiento en % (0 = sin descuento). Se aplica al cobrar: en la factura va en valores
-- (montoDescu de la línea y totalDescu) y las pantallas muestran el precio con descuento.
IF COL_LENGTH('dbo.CAT_TRATAMIENTOS', 'Descuento') IS NULL
	ALTER TABLE dbo.CAT_TRATAMIENTOS ADD Descuento decimal(5,2) NOT NULL CONSTRAINT DF_CAT_TRATAMIENTOS_Descuento DEFAULT (0);
GO

CREATE OR ALTER PROCEDURE [dbo].[CAT_SP_Catalogos]
	 @catalogo        varchar(30)
	,@accion          int
	,@usuario         varchar(20)   = NULL
	,@id              bigint        = 0
	,@descripcion     varchar(250)  = NULL
	,@activo          bit           = 1
	,@padre           bigint        = 0      -- departamento del municipio
	,@usuarioSistema  varchar(20)   = NULL   -- usuario del especialista
	,@color           varchar(20)   = NULL
	,@procesos        bit           = 0
	,@cancelada       bit           = 0
	,@finalizada      bit           = 0
	,@hora            time          = NULL
	,@digitos         int           = 0
	,@formato         varchar(20)   = NULL
	,@duracion        int           = 0
	,@precio          decimal(10,2) = 0
	,@caracteristicas varchar(max)  = NULL
	,@imagen          varchar(300)  = NULL   -- NULL conserva la imagen; '-' la quita
	,@descuento       decimal(5,2)  = 0      -- tratamientos: descuento en %
AS
BEGIN
	SET NOCOUNT ON;

	set @catalogo = LOWER(LTRIM(RTRIM(@catalogo)))
	set @descripcion = NULLIF(LTRIM(RTRIM(@descripcion)), '')
	set @usuarioSistema = NULLIF(LTRIM(RTRIM(@usuarioSistema)), '')
	set @formato = NULLIF(LTRIM(RTRIM(@formato)), '')
	set @caracteristicas = NULLIF(LTRIM(RTRIM(@caracteristicas)), '')

	if @catalogo not in ('departamentos', 'municipios', 'sexos', 'especialistas', 'estados', 'horarios', 'tratamientos', 'tiposdocumento', 'tiposcita', 'tiposfactura')
		THROW 50300, 'Catálogo no válido.', 1;

	/* ================= 1: lista ================= */
	if @accion = 1
	begin
		if @catalogo = 'departamentos'
			select d.Id_Departamento as Id, d.Descripcion, CAST(1 as bit) as Activo
				,(select COUNT(*) from CAT_MUNICIPIOS where Id_Departamento_fk = d.Id_Departamento)
				 + (select COUNT(*) from Sys_ConfiguracionApp where Departamento = d.Id_Departamento) as Usos
				,CAST(NULL as bigint) as Padre, CAST(NULL as varchar(250)) as PadreTexto, CAST(NULL as varchar(20)) as UsuarioSistema
				,CAST(NULL as varchar(20)) as Color, CAST(NULL as bit) as Procesos, CAST(NULL as bit) as Cancelada, CAST(NULL as bit) as Finalizada
				,CAST(NULL as time) as Hora, CAST(NULL as int) as Digitos, CAST(NULL as varchar(20)) as Formato
				,CAST(NULL as int) as Duracion, CAST(NULL as decimal(10,2)) as Precio, CAST(NULL as varchar(max)) as Caracteristicas, CAST(NULL as varchar(max)) as Imagen
				,ISNULL(d.UsuarioModifica, d.UsuarioCrea) as Usuario, ISNULL(d.FechaModifica, d.FechaCrea) as Fecha
			from CAT_DEPARTAMENTOS as d
			order by d.Descripcion
		else if @catalogo = 'municipios'
			select m.Id_Municipio as Id, m.Descripcion, CAST(1 as bit) as Activo
				,(select COUNT(*) from EXP_EXPEDIENTES where Id_Municipio_fk = m.Id_Municipio)
				 + (select COUNT(*) from Sys_ConfiguracionApp where Municipio = m.Id_Municipio) as Usos
				,m.Id_Departamento_fk as Padre, d.Descripcion as PadreTexto, CAST(NULL as varchar(20)) as UsuarioSistema
				,CAST(NULL as varchar(20)) as Color, CAST(NULL as bit) as Procesos, CAST(NULL as bit) as Cancelada, CAST(NULL as bit) as Finalizada
				,CAST(NULL as time) as Hora, CAST(NULL as int) as Digitos, CAST(NULL as varchar(20)) as Formato
				,CAST(NULL as int) as Duracion, CAST(NULL as decimal(10,2)) as Precio, CAST(NULL as varchar(max)) as Caracteristicas, CAST(NULL as varchar(max)) as Imagen
				,ISNULL(m.UsuarioModifica, m.UsuarioCrea) as Usuario, ISNULL(m.FechaModifica, m.FechaCrea) as Fecha
			from CAT_MUNICIPIOS as m
				left join CAT_DEPARTAMENTOS as d on d.Id_Departamento = m.Id_Departamento_fk
			order by d.Descripcion, m.Descripcion
		else if @catalogo = 'sexos'
			select s.Id_Sexos as Id, s.Descripcion, s.IsActivo as Activo
				,(select COUNT(*) from EXP_EXPEDIENTES where Id_Sexo_fk = s.Id_Sexos) as Usos
				,CAST(NULL as bigint) as Padre, CAST(NULL as varchar(250)) as PadreTexto, CAST(NULL as varchar(20)) as UsuarioSistema
				,CAST(NULL as varchar(20)) as Color, CAST(NULL as bit) as Procesos, CAST(NULL as bit) as Cancelada, CAST(NULL as bit) as Finalizada
				,CAST(NULL as time) as Hora, CAST(NULL as int) as Digitos, CAST(NULL as varchar(20)) as Formato
				,CAST(NULL as int) as Duracion, CAST(NULL as decimal(10,2)) as Precio, CAST(NULL as varchar(max)) as Caracteristicas, CAST(NULL as varchar(max)) as Imagen
				,ISNULL(s.UsuarioModifica, s.UsuarioCrea) as Usuario, ISNULL(s.FechaModifica, s.FechaCrea) as Fecha
			from CAT_SEXOS as s
			order by s.Descripcion
		else if @catalogo = 'especialistas'
			select e.Id_Especialista as Id, e.Descripcion, e.IsActivo as Activo
				,(select COUNT(*) from EXP_CITAS where Id_Especialista_fk = e.Id_Especialista)
				 + (select COUNT(*) from EXP_PROCEDIMIENTOS where Id_Especialista_fk = e.Id_Especialista) as Usos
				,CAST(NULL as bigint) as Padre
				,LTRIM(RTRIM(ISNULL(u.Nombres, '') + ' ' + ISNULL(u.Apellidos, ''))) as PadreTexto
				,e.UsaurioSystem as UsuarioSistema
				,CAST(NULL as varchar(20)) as Color, CAST(NULL as bit) as Procesos, CAST(NULL as bit) as Cancelada, CAST(NULL as bit) as Finalizada
				,CAST(NULL as time) as Hora, CAST(NULL as int) as Digitos, CAST(NULL as varchar(20)) as Formato
				,CAST(NULL as int) as Duracion, CAST(NULL as decimal(10,2)) as Precio, CAST(NULL as varchar(max)) as Caracteristicas, CAST(NULL as varchar(max)) as Imagen
				,ISNULL(e.UsuarioModifica, e.UsuarioCrea) as Usuario, ISNULL(e.FechaModifica, e.FechaCrea) as Fecha
			from CAT_ESPECIALISTAS as e
				left join Sys_Usuarios as u on u.Id_Usuario = e.UsaurioSystem
			order by e.IsActivo desc, e.Descripcion
		else if @catalogo = 'estados'
			select s.Id_Estado as Id, s.Descripcion, s.IsActivo as Activo
				,(select COUNT(*) from EXP_CITAS where Id_EstadoCita_fk = s.Id_Estado) as Usos
				,CAST(NULL as bigint) as Padre, CAST(NULL as varchar(250)) as PadreTexto, CAST(NULL as varchar(20)) as UsuarioSistema
				,s.Colors as Color, ISNULL(s.Procesos, 0) as Procesos, ISNULL(s.Cancelada, 0) as Cancelada, ISNULL(s.Finalizada, 0) as Finalizada
				,CAST(NULL as time) as Hora, CAST(NULL as int) as Digitos, CAST(NULL as varchar(20)) as Formato
				,CAST(NULL as int) as Duracion, CAST(NULL as decimal(10,2)) as Precio, CAST(NULL as varchar(max)) as Caracteristicas, CAST(NULL as varchar(max)) as Imagen
				,ISNULL(s.UsuarioModifica, s.UsuarioCrea) as Usuario, ISNULL(s.FechaModifica, s.FechaCrea) as Fecha
			from CAT_ESTADOSCITAS as s
			order by s.Id_Estado
		else if @catalogo = 'horarios'
			select h.Id_Horario as Id, h.Descripcion, h.IsActivo as Activo
				,(select COUNT(*) from EXP_CITAS where Id_Horario_fk = h.Id_Horario or Id_HorarioFin_FK = h.Id_Horario)
				 + (select COUNT(*) from EXP_PROCEDIMIENTOS where Id_Horario_fk = h.Id_Horario or Id_Horariofin_fk = h.Id_Horario) as Usos
				,CAST(NULL as bigint) as Padre, CAST(NULL as varchar(250)) as PadreTexto, CAST(NULL as varchar(20)) as UsuarioSistema
				,CAST(NULL as varchar(20)) as Color, CAST(NULL as bit) as Procesos, CAST(NULL as bit) as Cancelada, CAST(NULL as bit) as Finalizada
				,h.Hora, CAST(NULL as int) as Digitos, CAST(NULL as varchar(20)) as Formato
				,CAST(NULL as int) as Duracion, CAST(NULL as decimal(10,2)) as Precio, CAST(NULL as varchar(max)) as Caracteristicas, CAST(NULL as varchar(max)) as Imagen
				,ISNULL(h.UsuarioModifica, h.UsuarioCrea) as Usuario, ISNULL(h.FechaModifica, h.FechaCrea) as Fecha
			from CAT_HORARIOS as h
			order by h.Hora, h.Descripcion
		else if @catalogo = 'tratamientos'
			select t.Id_Tratamientos as Id, t.Descripcion, t.IsActivo as Activo
				,(select COUNT(*) from EXP_CITAS where Id_Tratamiento_fk = t.Id_Tratamientos)
				 + (select COUNT(*) from EXP_PROCEDIMIENTOSTRATAMIENTOS where Id_Tratamiento_FK = t.Id_Tratamientos)
				 + (select COUNT(*) from EXP_CUPONES where Id_Tratamiento_FK = t.Id_Tratamientos) as Usos
				,CAST(NULL as bigint) as Padre, CAST(NULL as varchar(250)) as PadreTexto, CAST(NULL as varchar(20)) as UsuarioSistema
				,CAST(NULL as varchar(20)) as Color, CAST(NULL as bit) as Procesos, CAST(NULL as bit) as Cancelada, CAST(NULL as bit) as Finalizada
				,CAST(NULL as time) as Hora, CAST(NULL as int) as Digitos, CAST(NULL as varchar(20)) as Formato
				,t.Duracion, CAST(t.Precio as decimal(10,2)) as Precio, t.Caracteristicas, t.Imagen
				,ISNULL(t.UsuarioModifica, t.UsuarioCrea) as Usuario, ISNULL(t.FechaModifica, t.FechaCrea) as Fecha
				,t.Descuento
			from CAT_TRATAMIENTOS as t
			order by t.IsActivo desc, t.Descripcion
		else if @catalogo = 'tiposdocumento'
			select d.Id_TipoDocumento as Id, d.Descripcion, d.Estatus as Activo
				,(select COUNT(*) from EXP_EXPEDIENTES where Id_TipoDocumento_fk = d.Id_TipoDocumento) as Usos
				,CAST(NULL as bigint) as Padre, CAST(NULL as varchar(250)) as PadreTexto, CAST(NULL as varchar(20)) as UsuarioSistema
				,CAST(NULL as varchar(20)) as Color, CAST(NULL as bit) as Procesos, CAST(NULL as bit) as Cancelada, CAST(NULL as bit) as Finalizada
				,CAST(NULL as time) as Hora, ISNULL(d.Digitos, 0) as Digitos, d.Formato
				,CAST(NULL as int) as Duracion, CAST(NULL as decimal(10,2)) as Precio, CAST(NULL as varchar(max)) as Caracteristicas, CAST(NULL as varchar(max)) as Imagen
				,ISNULL(d.UsuarioModifica, d.UsuarioCrea) as Usuario, ISNULL(d.FechaModifica, d.FechaCrea) as Fecha
			from CAT_TIPOSDOCUMENTOS as d
			order by d.Id_TipoDocumento
		else if @catalogo = 'tiposfactura'
			-- el código de Hacienda (CAT-002) va en Formato; Digitos = 1 si el sistema emite ese tipo (01 y 03)
			select t.Id_TipoFactura as Id, t.Descripcion, t.Estatus as Activo
				,(select COUNT(*) from FAC_DTE_DOCUMENTOS where Id_TipoFactura_FK = t.Id_TipoFactura) as Usos
				,CAST(NULL as bigint) as Padre, CAST(NULL as varchar(250)) as PadreTexto, CAST(NULL as varchar(20)) as UsuarioSistema
				,CAST(NULL as varchar(20)) as Color, CAST(NULL as bit) as Procesos, CAST(NULL as bit) as Cancelada, CAST(NULL as bit) as Finalizada
				,CAST(NULL as time) as Hora, case when t.Codigo in ('01', '03') then 1 else 0 end as Digitos, CAST(t.Codigo as varchar(20)) as Formato
				,CAST(NULL as int) as Duracion, CAST(NULL as decimal(10,2)) as Precio, CAST(NULL as varchar(max)) as Caracteristicas, CAST(NULL as varchar(max)) as Imagen
				,ISNULL(t.UsuarioModifica, t.UsuarioCrea) as Usuario, ISNULL(t.FechaModifica, t.FechaCrea) as Fecha
			from CAT_TIPOSFACTURAS as t
			order by t.Codigo
		else
			select t.Id_TipoCita as Id, t.Descripcion, t.IsActivo as Activo
				,(select COUNT(*) from EXP_CITAS where Id_TipoCita_FK = t.Id_TipoCita)
				 + (select COUNT(*) from EXP_PROCEDIMIENTOS where Id_TipoCita_FK = t.Id_TipoCita) as Usos
				,CAST(NULL as bigint) as Padre, CAST(NULL as varchar(250)) as PadreTexto, CAST(NULL as varchar(20)) as UsuarioSistema
				,CAST(NULL as varchar(20)) as Color, CAST(NULL as bit) as Procesos, CAST(NULL as bit) as Cancelada, CAST(NULL as bit) as Finalizada
				,CAST(NULL as time) as Hora, CAST(NULL as int) as Digitos, CAST(NULL as varchar(20)) as Formato
				,CAST(NULL as int) as Duracion, CAST(NULL as decimal(10,2)) as Precio, CAST(NULL as varchar(max)) as Caracteristicas, CAST(NULL as varchar(max)) as Imagen
				,ISNULL(t.UsuarioModifica, t.UsuarioCrea) as Usuario, ISNULL(t.FechaModifica, t.FechaCrea) as Fecha
			from CAT_TIPOSCITAS as t
			order by t.Descripcion
		return
	end

	/* ================= 2: guardar ================= */
	if @accion = 2
	begin
		if @descripcion is null THROW 50301, 'Ingrese la descripción.', 1;
		if @id > 0 and not exists (
				select 1 from CAT_DEPARTAMENTOS where @catalogo = 'departamentos' and Id_Departamento = @id union all
				select 1 from CAT_MUNICIPIOS where @catalogo = 'municipios' and Id_Municipio = @id union all
				select 1 from CAT_SEXOS where @catalogo = 'sexos' and Id_Sexos = @id union all
				select 1 from CAT_ESPECIALISTAS where @catalogo = 'especialistas' and Id_Especialista = @id union all
				select 1 from CAT_ESTADOSCITAS where @catalogo = 'estados' and Id_Estado = @id union all
				select 1 from CAT_HORARIOS where @catalogo = 'horarios' and Id_Horario = @id union all
				select 1 from CAT_TRATAMIENTOS where @catalogo = 'tratamientos' and Id_Tratamientos = @id union all
				select 1 from CAT_TIPOSDOCUMENTOS where @catalogo = 'tiposdocumento' and Id_TipoDocumento = @id union all
				select 1 from CAT_TIPOSCITAS where @catalogo = 'tiposcita' and Id_TipoCita = @id union all
				select 1 from CAT_TIPOSFACTURAS where @catalogo = 'tiposfactura' and Id_TipoFactura = @id)
			THROW 50317, 'El registro ya no existe. Actualice la lista.', 1;

		-- descripción repetida
		if (@catalogo = 'departamentos' and exists (select 1 from CAT_DEPARTAMENTOS where Descripcion = @descripcion and Id_Departamento <> @id))
			or (@catalogo = 'municipios' and exists (select 1 from CAT_MUNICIPIOS where Descripcion = @descripcion and Id_Departamento_fk = @padre and Id_Municipio <> @id))
			or (@catalogo = 'sexos' and exists (select 1 from CAT_SEXOS where Descripcion = @descripcion and Id_Sexos <> @id))
			or (@catalogo = 'especialistas' and exists (select 1 from CAT_ESPECIALISTAS where Descripcion = @descripcion and Id_Especialista <> @id))
			or (@catalogo = 'estados' and exists (select 1 from CAT_ESTADOSCITAS where Descripcion = @descripcion and Id_Estado <> @id))
			or (@catalogo = 'horarios' and exists (select 1 from CAT_HORARIOS where Descripcion = @descripcion and Id_Horario <> @id))
			or (@catalogo = 'tratamientos' and exists (select 1 from CAT_TRATAMIENTOS where Descripcion = @descripcion and Id_Tratamientos <> @id))
			or (@catalogo = 'tiposdocumento' and exists (select 1 from CAT_TIPOSDOCUMENTOS where Descripcion = @descripcion and Id_TipoDocumento <> @id))
			or (@catalogo = 'tiposcita' and exists (select 1 from CAT_TIPOSCITAS where Descripcion = @descripcion and Id_TipoCita <> @id))
			or (@catalogo = 'tiposfactura' and exists (select 1 from CAT_TIPOSFACTURAS where Descripcion = @descripcion and Id_TipoFactura <> @id))
			THROW 50302, 'Ya existe un registro con esa descripción.', 1;

		if @catalogo = 'departamentos'
		begin
			if @id = 0 insert into CAT_DEPARTAMENTOS (Descripcion, UsuarioCrea, FechaCrea) values (@descripcion, @usuario, GETDATE())
			else update CAT_DEPARTAMENTOS set Descripcion = @descripcion, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_Departamento = @id
		end
		else if @catalogo = 'municipios'
		begin
			if not exists (select 1 from CAT_DEPARTAMENTOS where Id_Departamento = @padre) THROW 50303, 'Seleccione el departamento.', 1;
			if @id = 0 insert into CAT_MUNICIPIOS (Descripcion, Id_Departamento_fk, UsuarioCrea, FechaCrea) values (@descripcion, @padre, @usuario, GETDATE())
			else update CAT_MUNICIPIOS set Descripcion = @descripcion, Id_Departamento_fk = @padre, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_Municipio = @id
		end
		else if @catalogo = 'sexos'
		begin
			if @id = 0 insert into CAT_SEXOS (Descripcion, IsActivo, UsuarioCrea, FechaCrea) values (@descripcion, @activo, @usuario, GETDATE())
			else update CAT_SEXOS set Descripcion = @descripcion, IsActivo = @activo, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_Sexos = @id
		end
		else if @catalogo = 'especialistas'
		begin
			if @usuarioSistema is not null and not exists (select 1 from Sys_Usuarios where Id_Usuario = @usuarioSistema)
				THROW 50304, 'El usuario del sistema no existe.', 1;
			-- un usuario solo puede ser un especialista activo (frm_Procedimientos lo usa para mostrarle sus citas)
			if @usuarioSistema is not null and @activo = 1
				and exists (select 1 from CAT_ESPECIALISTAS where UsaurioSystem = @usuarioSistema and IsActivo = 1 and Id_Especialista <> @id)
				THROW 50305, 'Ese usuario ya está vinculado a otro especialista activo.', 1;
			if @id = 0 insert into CAT_ESPECIALISTAS (Descripcion, IsActivo, UsaurioSystem, UsuarioCrea, FechaCrea) values (@descripcion, @activo, @usuarioSistema, @usuario, GETDATE())
			else update CAT_ESPECIALISTAS set Descripcion = @descripcion, IsActivo = @activo, UsaurioSystem = @usuarioSistema, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_Especialista = @id
		end
		else if @catalogo = 'estados'
		begin
			if ISNULL(@color, '') not in ('info', 'success', 'warning', 'danger', 'secondary', 'primary') THROW 50306, 'Seleccione el color.', 1;
			if @cancelada = 1 and @finalizada = 1 THROW 50307, 'Un estado no puede ser cancelado y finalizado a la vez.', 1;
			if @cancelada = 1 and exists (select 1 from CAT_ESTADOSCITAS where Cancelada = 1 and Id_Estado <> @id)
				THROW 50308, 'Ya hay otro estado marcado como cancelado. Solo puede haber uno.', 1;
			if @finalizada = 1 and exists (select 1 from CAT_ESTADOSCITAS where Finalizada = 1 and Id_Estado <> @id)
				THROW 50309, 'Ya hay otro estado marcado como finalizado. Solo puede haber uno.', 1;
			-- los estados 1 a 7 los usa la agenda y la atención: no se les cambia el tipo
			if @id between 1 and 7 and exists (select 1 from CAT_ESTADOSCITAS where Id_Estado = @id
					and (ISNULL(Procesos, 0) <> @procesos or ISNULL(Cancelada, 0) <> @cancelada or ISNULL(Finalizada, 0) <> @finalizada or (IsActivo = 1 and @activo = 0)))
				THROW 50310, 'Este estado lo usa el sistema: solo se puede cambiar su nombre y su color.', 1;
			if @id = 0 insert into CAT_ESTADOSCITAS (Descripcion, IsActivo, Colors, Accion, Procesos, Cancelada, Finalizada, UsuarioCrea, FechaCrea)
				values (@descripcion, @activo, @color, 0, @procesos, @cancelada, @finalizada, @usuario, GETDATE())
			else update CAT_ESTADOSCITAS set Descripcion = @descripcion, IsActivo = @activo, Colors = @color, Procesos = @procesos
				,Cancelada = @cancelada, Finalizada = @finalizada, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_Estado = @id
		end
		else if @catalogo = 'horarios'
		begin
			if @hora is null THROW 50311, 'Ingrese la hora.', 1;
			if exists (select 1 from CAT_HORARIOS where Hora = @hora and Id_Horario <> @id) THROW 50312, 'Ya existe un horario con esa hora.', 1;
			if @id = 0 insert into CAT_HORARIOS (Descripcion, Hora, IsActivo, UsuarioCrea, FechaCrea) values (@descripcion, @hora, @activo, @usuario, GETDATE())
			else update CAT_HORARIOS set Descripcion = @descripcion, Hora = @hora, IsActivo = @activo, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_Horario = @id
		end
		else if @catalogo = 'tratamientos'
		begin
			if @duracion < 0 or @duracion > 600 THROW 50313, 'La duración debe estar entre 0 y 600 minutos.', 1;
			if @precio < 0 THROW 50314, 'El precio no puede ser negativo.', 1;
			set @descuento = ISNULL(@descuento, 0)
			if @descuento < 0 or @descuento >= 100 THROW 50315, 'El descuento debe estar entre 0 y 99.99 por ciento.', 1;
			if @id = 0 insert into CAT_TRATAMIENTOS (Descripcion, Duracion, Precio, Descuento, IsActivo, Caracteristicas, Imagen, UsuarioCrea, FechaCrea)
				values (@descripcion, @duracion, @precio, @descuento, @activo, @caracteristicas, NULLIF(@imagen, '-'), @usuario, GETDATE())
			else update CAT_TRATAMIENTOS set Descripcion = @descripcion, Duracion = @duracion, Precio = @precio, Descuento = @descuento, IsActivo = @activo
				,Caracteristicas = @caracteristicas
				,Imagen = case when @imagen is null then Imagen when @imagen = '-' then NULL else @imagen end
				,UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_Tratamientos = @id
		end
		else if @catalogo = 'tiposdocumento'
		begin
			if @digitos < 0 or @digitos > 30 THROW 50315, 'Los dígitos deben estar entre 0 y 30.', 1;
			if @id = 0 insert into CAT_TIPOSDOCUMENTOS (Descripcion, Estatus, Digitos, Formato, UsuarioCrea, FechaCrea) values (@descripcion, @activo, @digitos, @formato, @usuario, GETDATE())
			else update CAT_TIPOSDOCUMENTOS set Descripcion = @descripcion, Estatus = @activo, Digitos = @digitos, Formato = @formato, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_TipoDocumento = @id
		end
		else if @catalogo = 'tiposfactura'
		begin
			-- @formato = código de Hacienda (CAT-002), dos dígitos
			if @formato is null or @formato not like '[0-9][0-9]' THROW 50320, 'El código debe tener dos dígitos, como en el catálogo CAT-002 de Hacienda.', 1;
			if exists (select 1 from CAT_TIPOSFACTURAS where Codigo = @formato and Id_TipoFactura <> @id) THROW 50321, 'Ya existe un tipo de comprobante con ese código.', 1;
			if @id > 0 and exists (select 1 from CAT_TIPOSFACTURAS where Id_TipoFactura = @id and Codigo <> @formato)
				and exists (select 1 from FAC_DTE_DOCUMENTOS where Id_TipoFactura_FK = @id)
				THROW 50322, 'Ya hay documentos emitidos con este tipo: no se puede cambiar su código.', 1;
			if @id > 0 and @activo = 0 and exists (select 1 from CAT_TIPOSFACTURAS where Id_TipoFactura = @id and Codigo in ('01', '03'))
				THROW 50323, 'La caja emite este tipo de documento: no se puede inactivar.', 1;
			if @id = 0 insert into CAT_TIPOSFACTURAS (Codigo, Descripcion, Estatus, UsuarioCrea, FechaCrea) values (@formato, UPPER(@descripcion), @activo, @usuario, GETDATE())
			else update CAT_TIPOSFACTURAS set Codigo = @formato, Descripcion = UPPER(@descripcion), Estatus = @activo, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_TipoFactura = @id
		end
		else
		begin
			if LEN(@descripcion) > 200 THROW 50316, 'La descripción no puede tener más de 200 caracteres.', 1;
			if @id = 0 insert into CAT_TIPOSCITAS (Descripcion, IsActivo, UsuarioCrea, FechaCrea) values (@descripcion, @activo, @usuario, GETDATE())
			else update CAT_TIPOSCITAS set Descripcion = @descripcion, IsActivo = @activo, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_TipoCita = @id
		end

		if @id = 0
		begin
			select CAST(SCOPE_IDENTITY() as bigint) as Id
			return
		end
		select @id as Id
		return
	end

	/* ================= 3: eliminar (solo si nadie lo usa) ================= */
	if @accion = 3
	begin
		declare @usos int =
			case @catalogo
				when 'departamentos' then (select COUNT(*) from CAT_MUNICIPIOS where Id_Departamento_fk = @id) + (select COUNT(*) from Sys_ConfiguracionApp where Departamento = @id)
				when 'municipios' then (select COUNT(*) from EXP_EXPEDIENTES where Id_Municipio_fk = @id) + (select COUNT(*) from Sys_ConfiguracionApp where Municipio = @id)
				when 'sexos' then (select COUNT(*) from EXP_EXPEDIENTES where Id_Sexo_fk = @id)
				when 'especialistas' then (select COUNT(*) from EXP_CITAS where Id_Especialista_fk = @id) + (select COUNT(*) from EXP_PROCEDIMIENTOS where Id_Especialista_fk = @id)
				when 'estados' then (select COUNT(*) from EXP_CITAS where Id_EstadoCita_fk = @id)
				when 'horarios' then (select COUNT(*) from EXP_CITAS where Id_Horario_fk = @id or Id_HorarioFin_FK = @id)
					+ (select COUNT(*) from EXP_PROCEDIMIENTOS where Id_Horario_fk = @id or Id_Horariofin_fk = @id)
				when 'tratamientos' then (select COUNT(*) from EXP_CITAS where Id_Tratamiento_fk = @id)
					+ (select COUNT(*) from EXP_PROCEDIMIENTOSTRATAMIENTOS where Id_Tratamiento_FK = @id) + (select COUNT(*) from EXP_CUPONES where Id_Tratamiento_FK = @id)
				when 'tiposdocumento' then (select COUNT(*) from EXP_EXPEDIENTES where Id_TipoDocumento_fk = @id)
				when 'tiposfactura' then (select COUNT(*) from FAC_DTE_DOCUMENTOS where Id_TipoFactura_FK = @id)
					+ case when exists (select 1 from CAT_TIPOSFACTURAS where Id_TipoFactura = @id and Codigo in ('01', '03')) then 1 else 0 end
				else (select COUNT(*) from EXP_CITAS where Id_TipoCita_FK = @id) + (select COUNT(*) from EXP_PROCEDIMIENTOS where Id_TipoCita_FK = @id)
			end
		if @catalogo = 'estados' and @id between 1 and 7
			THROW 50310, 'Este estado lo usa el sistema y no se puede eliminar.', 1;
		if @usos > 0 and @catalogo in ('departamentos', 'municipios')
			THROW 50318, 'Este registro está en uso (municipios, expedientes o datos de la empresa) y no se puede eliminar.', 1;
		if @usos > 0
			THROW 50318, 'Este registro está en uso y no se puede eliminar. Inactívelo para que ya no aparezca en las listas.', 1;

		if @catalogo = 'departamentos' delete from CAT_DEPARTAMENTOS where Id_Departamento = @id
		else if @catalogo = 'municipios' delete from CAT_MUNICIPIOS where Id_Municipio = @id
		else if @catalogo = 'sexos' delete from CAT_SEXOS where Id_Sexos = @id
		else if @catalogo = 'especialistas' delete from CAT_ESPECIALISTAS where Id_Especialista = @id
		else if @catalogo = 'estados' delete from CAT_ESTADOSCITAS where Id_Estado = @id
		else if @catalogo = 'horarios' delete from CAT_HORARIOS where Id_Horario = @id
		else if @catalogo = 'tratamientos' delete from CAT_TRATAMIENTOS where Id_Tratamientos = @id
		else if @catalogo = 'tiposdocumento' delete from CAT_TIPOSDOCUMENTOS where Id_TipoDocumento = @id
		else if @catalogo = 'tiposfactura' delete from CAT_TIPOSFACTURAS where Id_TipoFactura = @id
		else delete from CAT_TIPOSCITAS where Id_TipoCita = @id
		select @id as Id
		return
	end

	/* ================= 4: activar / inactivar ================= */
	if @accion = 4
	begin
		if @catalogo in ('departamentos', 'municipios') THROW 50319, 'Este catálogo no se puede inactivar.', 1;
		if @catalogo = 'estados' and @id between 1 and 7 and @activo = 0 THROW 50310, 'Este estado lo usa el sistema: solo se puede cambiar su nombre y su color.', 1;
		if @catalogo = 'especialistas' and @activo = 1
			and exists (select 1 from CAT_ESPECIALISTAS as e where e.Id_Especialista = @id and e.UsaurioSystem is not null
						and exists (select 1 from CAT_ESPECIALISTAS as o where o.UsaurioSystem = e.UsaurioSystem and o.IsActivo = 1 and o.Id_Especialista <> @id))
			THROW 50305, 'Ese usuario ya está vinculado a otro especialista activo.', 1;

		if @catalogo = 'sexos' update CAT_SEXOS set IsActivo = @activo, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_Sexos = @id
		else if @catalogo = 'especialistas' update CAT_ESPECIALISTAS set IsActivo = @activo, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_Especialista = @id
		else if @catalogo = 'estados' update CAT_ESTADOSCITAS set IsActivo = @activo, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_Estado = @id
		else if @catalogo = 'horarios' update CAT_HORARIOS set IsActivo = @activo, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_Horario = @id
		else if @catalogo = 'tratamientos' update CAT_TRATAMIENTOS set IsActivo = @activo, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_Tratamientos = @id
		else if @catalogo = 'tiposdocumento' update CAT_TIPOSDOCUMENTOS set Estatus = @activo, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_TipoDocumento = @id
		else if @catalogo = 'tiposfactura'
		begin
			if @activo = 0 and exists (select 1 from CAT_TIPOSFACTURAS where Id_TipoFactura = @id and Codigo in ('01', '03'))
				THROW 50323, 'La caja emite este tipo de documento: no se puede inactivar.', 1;
			update CAT_TIPOSFACTURAS set Estatus = @activo, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_TipoFactura = @id
		end
		else update CAT_TIPOSCITAS set IsActivo = @activo, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_TipoCita = @id
		if @@ROWCOUNT = 0 THROW 50317, 'El registro ya no existe. Actualice la lista.', 1;
		select @id as Id
		return
	end

	/* ================= 5: tipos de comprobante: agregar los que faltan del catálogo CAT-002 de Hacienda ================= */
	if @accion = 5 and @catalogo = 'tiposfactura'
	begin
		declare @cat002 table (Codigo varchar(2), Descripcion varchar(200))
		insert into @cat002 values
			 ('01', 'FACTURA'), ('03', 'COMPROBANTE DE CRÉDITO FISCAL'), ('04', 'NOTA DE REMISIÓN'), ('05', 'NOTA DE CRÉDITO')
			,('06', 'NOTA DE DÉBITO'), ('07', 'COMPROBANTE DE RETENCIÓN'), ('08', 'COMPROBANTE DE LIQUIDACIÓN')
			,('09', 'DOCUMENTO CONTABLE DE LIQUIDACIÓN'), ('11', 'FACTURA DE EXPORTACIÓN'), ('14', 'FACTURA DE SUJETO EXCLUIDO')
			,('15', 'COMPROBANTE DE DONACIÓN')
		insert into CAT_TIPOSFACTURAS (Codigo, Descripcion, Estatus, UsuarioCrea, FechaCrea)
		select c.Codigo, c.Descripcion, 1, @usuario, GETDATE()
		from @cat002 as c
		where not exists (select 1 from CAT_TIPOSFACTURAS as t where t.Codigo = c.Codigo)
		select CAST(@@ROWCOUNT as bigint) as Id
		return
	end;

	THROW 50399, 'Acción no válida.', 1;
END
GO

/* #####################################################################
   21/35  Registros\sql\REG_Inbound.sql
   ##################################################################### */
PRINT N'>> 21/35 Registros\sql\REG_Inbound.sql';
GO
/* =====================================================================
   DPieCenter - Inbound (Registros/frm_Inbound.aspx)

   Llamadas o contactos entrantes: teléfono y nombre del cliente. Desde la lista se marca si ya se le contestó.
   Al crear un expediente con el mismo teléfono, el registro se inhabilita (Activo = 0) y deja de mostrarse.
   REG_SP_Inbound:
     1 lista (filtros de fecha, estado y texto)   2 agregar   3 modificar   4 marcar contestó / pendiente
     5 eliminar   6 resumen
   Crea la opción "Inbound" en el menú Registros (módulo 4) para Administradores y ADMINISTRATIVOS.
   Script idempotente: se puede ejecutar varias veces.
   ===================================================================== */
SET NOCOUNT ON;
GO

IF OBJECT_ID('dbo.REG_INBOUND', 'U') IS NULL
BEGIN
	CREATE TABLE dbo.REG_INBOUND (
		 Id_Inbound        bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_REG_INBOUND PRIMARY KEY
		,Telefono          varchar(20)   NOT NULL
		,NombreCliente     nvarchar(150) NOT NULL
		,Contesto          bit           NOT NULL CONSTRAINT DF_REG_INBOUND_Contesto DEFAULT (0)
		,UsuarioCrea       varchar(50)   NOT NULL
		,FechaCrea         datetime      NOT NULL CONSTRAINT DF_REG_INBOUND_FechaCrea DEFAULT (GETDATE())
		,UsuarioModifica   varchar(50)   NULL
		,FechaModificacion datetime      NULL
	);
	CREATE INDEX IX_REG_INBOUND_FechaCrea ON dbo.REG_INBOUND (FechaCrea DESC) INCLUDE (Contesto);
	CREATE INDEX IX_REG_INBOUND_Telefono ON dbo.REG_INBOUND (Telefono);
END
GO

/* Activo: 0 cuando el contacto ya se registró como paciente (se creó un expediente con ese teléfono).
   La lista y el resumen de Inbound muestran solo los activos. */
IF COL_LENGTH('dbo.REG_INBOUND', 'Activo') IS NULL
	ALTER TABLE dbo.REG_INBOUND ADD Activo bit NOT NULL CONSTRAINT DF_REG_INBOUND_Activo DEFAULT (1);
GO

/* Sucursal donde se recibió la llamada (Opciones/sql/SUC_Sucursales.sql la agrega si la tabla ya existía) */
IF COL_LENGTH('dbo.REG_INBOUND', 'Id_Sucursal_FK') IS NULL AND OBJECT_ID('dbo.SUC_FN_Matriz', 'FN') IS NOT NULL
BEGIN
	ALTER TABLE dbo.REG_INBOUND ADD Id_Sucursal_FK int NOT NULL CONSTRAINT DF_REG_INBOUND_Sucursal DEFAULT (dbo.SUC_FN_Matriz()) WITH VALUES;
	ALTER TABLE dbo.REG_INBOUND WITH CHECK ADD CONSTRAINT FK_REG_INBOUND_Sucursal FOREIGN KEY (Id_Sucursal_FK) REFERENCES dbo.CAT_SUCURSALES (Id_Sucursal);
	CREATE INDEX IX_REG_INBOUND_Sucursal ON dbo.REG_INBOUND (Id_Sucursal_FK, FechaCrea);
END
GO

/* Al crear un expediente, el registro de Inbound con el mismo celular o teléfono se inhabilita
   (se comparan solo los dígitos: el expediente puede guardar 7000-0000). Cubre cualquier pantalla que cree expedientes. */
CREATE OR ALTER TRIGGER dbo.TR_EXP_EXPEDIENTES_Inbound
ON dbo.EXP_EXPEDIENTES
AFTER INSERT
AS
BEGIN
	SET NOCOUNT ON;
	IF OBJECT_ID('dbo.REG_INBOUND', 'U') IS NULL RETURN;

	DECLARE @tel TABLE (Telefono varchar(20) PRIMARY KEY);
	INSERT @tel (Telefono)
	SELECT DISTINCT t.Telefono
	FROM inserted AS i
		CROSS APPLY (VALUES (i.Celular), (i.Telefono)) AS v(Numero)
		CROSS APPLY (SELECT LEFT(REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(v.Numero, ''), '-', ''), ' ', ''), '(', ''), ')', ''), 20) AS Telefono) AS t
	WHERE LEN(t.Telefono) >= 8;

	UPDATE r SET
		 Activo = 0
		,UsuarioModifica = 'expediente'
		,FechaModificacion = GETDATE()
	FROM dbo.REG_INBOUND AS r
		INNER JOIN @tel AS t ON t.Telefono = r.Telefono
	WHERE r.Activo = 1;
END
GO

CREATE OR ALTER PROCEDURE [dbo].[REG_SP_Inbound]
	 @accion        int
	,@id            bigint        = 0
	,@telefono      varchar(20)   = NULL
	,@nombre        nvarchar(150) = NULL
	,@contesto      int           = -1     -- 1: contestó, 0: pendiente, -1: todos (en la lista)
	,@desde         date          = NULL
	,@hasta         date          = NULL
	,@texto         nvarchar(100) = NULL
	,@usuario       varchar(50)   = NULL
	,@sucursal      int           = 0      -- sucursal de la sesión (0 = todas en la lista; Casa Matriz al agregar)
AS
BEGIN
	SET NOCOUNT ON;

	set @telefono = NULLIF(LTRIM(RTRIM(@telefono)), '')
	set @nombre = NULLIF(LTRIM(RTRIM(@nombre)), '')
	set @texto = NULLIF(LTRIM(RTRIM(@texto)), '')

	/* Teléfonos (celular y fijo) de los expedientes, solo dígitos: el expediente puede guardar 7000-0000 o (503) 7000 0000 */
	declare @telExp table (Telefono varchar(20) not null, Id_Expediente bigint not null, Paciente nvarchar(300) null);
	if @accion in (1, 2, 3, 6)
		insert @telExp (Telefono, Id_Expediente, Paciente)
		select t.Telefono, e.Id_Expediente, LTRIM(RTRIM(ISNULL(e.Nombres, '') + ' ' + ISNULL(e.Apellidos, '')))
		from EXP_EXPEDIENTES as e
			cross apply (values (e.Celular), (e.Telefono)) as v(Numero)
			cross apply (select LEFT(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(v.Numero, ''), '-', ''), ' ', ''), '(', ''), ')', ''), '+', ''), 20) as Telefono) as t
		where LEN(t.Telefono) >= 8;
	-- con código de país 503 también coincide con el número de 8 dígitos
	insert @telExp (Telefono, Id_Expediente, Paciente)
	select RIGHT(Telefono, 8), Id_Expediente, Paciente from @telExp where LEN(Telefono) = 11 and Telefono like '503%';

	/* 1: lista */
	if @accion = 1
	begin
		declare @fin datetime = DATEADD(DAY, 1, CAST(@hasta as datetime))
		select i.Id_Inbound, i.Telefono, i.NombreCliente, i.Contesto
			,i.UsuarioCrea, i.FechaCrea, i.UsuarioModifica, i.FechaModificacion
			-- si el teléfono ya es de un paciente, se muestra a quién pertenece
			,CAST(NULL as bigint) as Id_Expediente, CAST(NULL as nvarchar(300)) as Paciente   -- ya no se listan pacientes; se conservan por compatibilidad
		from REG_INBOUND as i
		where i.Activo = 1          -- los inhabilitados (ya son pacientes) no se muestran
			-- ni los que su teléfono ya existe en un expediente (aunque el expediente sea anterior al registro)
			and not exists (select 1 from @telExp as t where t.Telefono in (i.Telefono, case when LEN(i.Telefono) = 11 and i.Telefono like '503%' then RIGHT(i.Telefono, 8) end))
			and (@sucursal = 0 or i.Id_Sucursal_FK = @sucursal)
			and (@desde is null or i.FechaCrea >= @desde)
			and (@hasta is null or i.FechaCrea < @fin)
			and (@contesto = -1 or i.Contesto = @contesto)
			and (@texto is null or i.Telefono like '%' + @texto + '%' or i.NombreCliente like '%' + @texto + '%')
		order by i.Contesto, i.FechaCrea desc
		return
	end

	/* Validaciones de agregar y modificar */
	if @accion in (2, 3)
	begin
		if @telefono is null
			THROW 50110, 'Ingrese el teléfono.', 1;
		if @telefono like '%[^0-9]%' or LEN(@telefono) < 8 or LEN(@telefono) > 15
			THROW 50111, 'El teléfono debe tener solo números, de 8 a 15 dígitos.', 1;
		if @nombre is null
			THROW 50112, 'Ingrese el nombre del cliente.', 1;
		if LEN(@nombre) < 3
			THROW 50113, 'El nombre del cliente es muy corto.', 1;
		-- el teléfono ya es de un paciente: no se registra (50116 → la pantalla muestra el aviso y limpia el formulario)
		declare @paciente nvarchar(300), @idExp bigint;
		select top 1 @paciente = Paciente, @idExp = Id_Expediente from @telExp
		where Telefono in (@telefono, case when LEN(@telefono) = 11 and @telefono like '503%' then RIGHT(@telefono, 8) end)
		order by Id_Expediente desc;
		if @idExp is not null
		begin
			declare @msj nvarchar(2048) = CONCAT('El teléfono ya existe en el expediente #', @idExp, ' (', @paciente, '). No se guardó el registro.');
			THROW 50116, @msj, 1;
		end
		-- evita registrar dos veces la misma llamada pendiente
		if exists (select 1 from REG_INBOUND where Telefono = @telefono and Contesto = 0 and Activo = 1 and Id_Inbound <> @id
				   and CAST(FechaCrea as date) = CAST(GETDATE() as date))
			THROW 50114, 'Ese teléfono ya tiene un registro pendiente de hoy.', 1;
	end

	if @accion in (3, 4, 5) and not exists (select 1 from REG_INBOUND where Id_Inbound = @id)
		THROW 50115, 'El registro ya no existe. Actualice la lista.', 1;

	/* 2: agregar */
	if @accion = 2
	begin
		insert into REG_INBOUND (Telefono, NombreCliente, Contesto, UsuarioCrea, FechaCrea, Id_Sucursal_FK)
		values (@telefono, @nombre, case when @contesto = 1 then 1 else 0 end, @usuario, GETDATE(), ISNULL(NULLIF(@sucursal, 0), dbo.SUC_FN_Matriz()))
		select CAST(SCOPE_IDENTITY() as bigint) as Id
		return
	end

	/* 3: modificar teléfono y nombre */
	if @accion = 3
	begin
		update REG_INBOUND
		set Telefono = @telefono, NombreCliente = @nombre, UsuarioModifica = @usuario, FechaModificacion = GETDATE()
		where Id_Inbound = @id
		select @id as Id
		return
	end

	/* 4: marcar contestó (1) o pendiente (0) */
	if @accion = 4
	begin
		update REG_INBOUND
		set Contesto = case when @contesto = 1 then 1 else 0 end, UsuarioModifica = @usuario, FechaModificacion = GETDATE()
		where Id_Inbound = @id
		select @id as Id
		return
	end

	/* 5: eliminar */
	if @accion = 5
	begin
		delete from REG_INBOUND where Id_Inbound = @id
		select @id as Id
		return
	end

	/* 6: resumen */
	if @accion = 6
	begin
		;with v as (
			select r.Contesto, r.FechaCrea from REG_INBOUND as r
			where r.Activo = 1 and (@sucursal = 0 or r.Id_Sucursal_FK = @sucursal)
				and not exists (select 1 from @telExp as t where t.Telefono in (r.Telefono, case when LEN(r.Telefono) = 11 and r.Telefono like '503%' then RIGHT(r.Telefono, 8) end))
		)
		select
			 ISNULL(SUM(case when Contesto = 0 then 1 else 0 end), 0) as Pendientes
			,ISNULL(SUM(case when CAST(FechaCrea as date) = CAST(GETDATE() as date) then 1 else 0 end), 0) as Hoy
			,ISNULL(SUM(case when CAST(FechaCrea as date) = CAST(GETDATE() as date) and Contesto = 1 then 1 else 0 end), 0) as ContestadosHoy
			,ISNULL(SUM(case when FechaCrea >= DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1) then 1 else 0 end), 0) as Mes
		from v
		return
	end
END
GO

/* Opción del menú Registros */
IF NOT EXISTS (SELECT 1 FROM dbo.Sys_Opciones WHERE AccesoURL = 'Registros/frm_Inbound.aspx')
BEGIN
	BEGIN TRANSACTION;
	DECLARE @opcion bigint, @orden int = ISNULL((SELECT MAX(Orden) FROM dbo.Sys_Opciones WHERE IdModulo_FK = 4), 0) + 1;
	INSERT INTO dbo.Sys_Opciones (Descripcion, Abreviado, AccesoURL, IdModulo_FK, Id_UsuarioCrea_FK, FechaCreacion, Orden)
	VALUES ('Inbound', 'IN', 'Registros/frm_Inbound.aspx', 4, 'admin', GETDATE(), @orden);
	SET @opcion = SCOPE_IDENTITY();
	INSERT INTO dbo.Sys_Permisos (IdAplicativo_FK, IdModulo_FK, IdOpcion_FK, IdGrupo_FK, Id_UsuarioCrea_FK, FechaCreacion)
	SELECT 2, 4, @opcion, g.Id_Grupo, 'admin', GETDATE() FROM dbo.Sys_Grupos AS g WHERE g.Id_Grupo IN ('Administradores', 'ADMINISTRATIVOS');
	INSERT INTO dbo.Sys_AccesosObjetos (IdAplicativo_FK, IdModulo_FK, IdOpcion_FK, IdGrupo_FK, Descripcion, Accion)
	SELECT 2, 4, @opcion, g.Id_Grupo, 'Inbound', 1 FROM dbo.Sys_Grupos AS g WHERE g.Id_Grupo IN ('Administradores', 'ADMINISTRATIVOS');
	COMMIT TRANSACTION;
END
GO

/* #####################################################################
   22/35  Dashboard\sql\REP_Dashboard_Usuarios.sql
   ##################################################################### */
PRINT N'>> 22/35 Dashboard\sql\REP_Dashboard_Usuarios.sql';
GO
/* =====================================================================
   DPieCenter - Dashboard de usuarios (Dashboard/frm_DashboardUsuarios.aspx)

   REP_SP_DashboardUsuario: el día de trabajo del usuario que inicia sesión.
   @especialista > 0: solo las citas y procedimientos de ese especialista (usuario vinculado en CAT_ESPECIALISTAS.UsaurioSystem).
   @especialista = 0: toda la clínica (recepción y personal administrativo).
   No devuelve montos. Las citas reprogramadas (estado 5) se cuentan: reprogramar cambia la fecha de la misma cita (sigue vigente).

   También asigna esta página al dashboard 4 (Administracion), que tenía una URL no válida.
   Script idempotente: se puede ejecutar varias veces.
   ===================================================================== */
SET NOCOUNT ON;
GO

CREATE OR ALTER PROCEDURE [dbo].[REP_SP_DashboardUsuario]
	 @accion       int
	,@especialista bigint = 0
	,@sucursal     int = 0        -- 0: todas las sucursales
AS
BEGIN
	SET NOCOUNT ON;

	declare @hoy date = CAST(GETDATE() as date)
	declare @manana date = DATEADD(DAY, 1, @hoy)
	declare @mes date = DATEFROMPARTS(YEAR(@hoy), MONTH(@hoy), 1)
	declare @cancelada bigint = (select top 1 Id_Estado from CAT_ESTADOSCITAS where Cancelada = 1 order by Id_Estado)    -- 3
	declare @finalizada bigint = (select top 1 Id_Estado from CAT_ESTADOSCITAS where Finalizada = 1 order by Id_Estado)  -- 6
	declare @reprogramada bigint = 5

	/* 1: indicadores de hoy y del mes */
	if @accion = 1
	begin
		declare @citasHoy table (Id_Cita bigint primary key, Inicio datetime2, Id_Estado bigint, Procesos bit)
		insert into @citasHoy
		select c.Id_Cita, ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2)), c.Id_EstadoCita_fk, ISNULL(ec.Procesos, 0)
		from EXP_CITAS as c left join CAT_ESTADOSCITAS as ec on ec.Id_Estado = c.Id_EstadoCita_fk
		where CAST(ISNULL(c.FechaInicio, c.Fecha) as date) = @hoy			and (@especialista = 0 or c.Id_Especialista_fk = @especialista) and (@sucursal = 0 or c.Id_Sucursal_FK = @sucursal)

		declare @procsMes table (Id_Procedimiento bigint primary key, Fecha date, Id_Expediente bigint, Minutos int)
		insert into @procsMes
		select p.Id_Procedimiento, p.Fecha, p.Id_Expediente_fk
			-- los antiguos guardan solo la hora (1900-01-01): entonces se comparan las horas del mismo día (igual que el reporte de procedimientos)
			,case when x.Minutos between 1 and 600 then x.Minutos end
		from EXP_PROCEDIMIENTOS as p
			cross apply (select case when YEAR(p.InicioProcedimiento) > 2000 and YEAR(p.FinalProcedimiento) > 2000
								  then DATEDIFF(MINUTE, p.InicioProcedimiento, p.FinalProcedimiento)
								  else DATEDIFF(MINUTE, CAST(p.InicioProcedimiento as time), CAST(p.FinalProcedimiento as time)) end as Minutos) as x
		where p.Estado = 'F' and p.Fecha >= @mes and p.Fecha <= @hoy
			and (@especialista = 0 or p.Id_Especialista_fk = @especialista) and (@sucursal = 0 or p.Id_Sucursal_FK = @sucursal)

		declare @citasMes table (Id_Estado bigint)
		insert into @citasMes
		select c.Id_EstadoCita_fk
		from EXP_CITAS as c
		where ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2)) >= @mes and ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2)) < @manana			and (@especialista = 0 or c.Id_Especialista_fk = @especialista) and (@sucursal = 0 or c.Id_Sucursal_FK = @sucursal)

		select
			(select COUNT(*) from @citasHoy) as CitasHoy
			,(select COUNT(*) from @citasHoy where Id_Estado = @finalizada) as AtendidasHoy
			,(select COUNT(*) from @citasHoy where Id_Estado = @cancelada) as CanceladasHoy
			-- por llegar: citas vigentes de hoy que aún no tienen procedimiento
			,(select COUNT(*) from @citasHoy as c where c.Procesos = 1
				and not exists (select 1 from EXP_PROCEDIMIENTOS as p where p.Id_Cita_FK = c.Id_Cita)) as PorLlegar
			,(select COUNT(*) from EXP_PROCEDIMIENTOS as p where p.Estado = 'S' and CAST(p.FechaCrea as date) = @hoy
				and (@especialista = 0 or p.Id_Especialista_fk = @especialista) and (@sucursal = 0 or p.Id_Sucursal_FK = @sucursal)) as EnSala
			,(select COUNT(*) from EXP_PROCEDIMIENTOS as p where p.Estado = 'I' and CAST(p.InicioProcedimiento as date) = @hoy
				and (@especialista = 0 or p.Id_Especialista_fk = @especialista) and (@sucursal = 0 or p.Id_Sucursal_FK = @sucursal)) as EnAtencion
			,(select COUNT(*) from @procsMes) as ProcedimientosMes
			,(select COUNT(distinct Id_Expediente) from @procsMes) as PacientesMes
			,(select AVG(CAST(Minutos as decimal(10,2))) from @procsMes where Minutos is not null) as MinutosPromedio
			,(select COUNT(*) from @citasMes) as CitasMes
			,(select COUNT(*) from @citasMes where Id_Estado = @finalizada) as AtendidasMes
			,(select COUNT(*) from @citasMes where Id_Estado = @cancelada) as CanceladasMes
			,(select COUNT(*) from EXP_EXPEDIENTES where FechaCrea >= @mes and FechaCrea < @manana and (@sucursal = 0 or Id_Sucursal_FK = @sucursal)) as ExpedientesMes
		return
	end

	/* 2: agenda de hoy con el estado del procedimiento (S en sala, I en atención, F finalizado) */
	if @accion = 2
	begin
		select
			c.Id_Cita
			,c.Id_Expediente_fk as Id_Expediente
			,ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2)) as Inicio
			,c.FechaFin as Fin
			,LTRIM(RTRIM(e.Nombres + ' ' + e.Apellidos)) as Paciente
			,ISNULL(e.Celular, '') as Celular
			,ISNULL(s.Descripcion, '') as Especialista
			,ISNULL(tc.Descripcion, '') as TipoCita
			,ISNULL(ec.Descripcion, '') as Estado
			,ISNULL(ec.Colors, 'secondary') as Color
			,c.Id_EstadoCita_fk as Id_Estado
			,ISNULL(p.Estado, '') as EstadoProcedimiento
			,p.FechaCrea as EnSalaDesde
		from EXP_CITAS as c
			inner join EXP_EXPEDIENTES as e on e.Id_Expediente = c.Id_Expediente_fk
			left join CAT_ESPECIALISTAS as s on s.Id_Especialista = c.Id_Especialista_fk
			left join CAT_ESTADOSCITAS as ec on ec.Id_Estado = c.Id_EstadoCita_fk
			left join CAT_TIPOSCITAS as tc on tc.Id_TipoCita = c.Id_TipoCita_FK
			outer apply (select top 1 Estado, FechaCrea from EXP_PROCEDIMIENTOS where Id_Cita_FK = c.Id_Cita order by Id_Procedimiento desc) as p
		where CAST(ISNULL(c.FechaInicio, c.Fecha) as date) = @hoy			and (@especialista = 0 or c.Id_Especialista_fk = @especialista) and (@sucursal = 0 or c.Id_Sucursal_FK = @sucursal)
		order by ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2)), c.Id_Cita
		return
	end

	/* 3: citas de los próximos 7 días (hoy incluido), por día */
	if @accion = 3
	begin
		;with dias as (
			select @hoy as Dia union all select DATEADD(DAY, 1, Dia) from dias where Dia < DATEADD(DAY, 6, @hoy)
		)
		select d.Dia
			,COUNT(c.Id_Cita) as Citas
			,SUM(case when c.Id_EstadoCita_fk = 2 then 1 else 0 end) as Confirmadas
		from dias as d
			left join EXP_CITAS as c on CAST(ISNULL(c.FechaInicio, c.Fecha) as date) = d.Dia
				and c.Id_EstadoCita_fk not in (@cancelada, 7)
				and (@especialista = 0 or c.Id_Especialista_fk = @especialista) and (@sucursal = 0 or c.Id_Sucursal_FK = @sucursal)
		group by d.Dia
		order by d.Dia
		return
	end

	/* 4: procedimientos finalizados de los últimos 30 días, por día */
	if @accion = 4
	begin
		declare @d30 date = DATEADD(DAY, -29, @hoy)
		;with dias as (
			select @d30 as Dia union all select DATEADD(DAY, 1, Dia) from dias where Dia < @hoy
		)
		select d.Dia, COUNT(p.Id_Procedimiento) as Procedimientos
		from dias as d
			left join EXP_PROCEDIMIENTOS as p on p.Fecha = d.Dia and p.Estado = 'F'
				and (@especialista = 0 or p.Id_Especialista_fk = @especialista) and (@sucursal = 0 or p.Id_Sucursal_FK = @sucursal)
		group by d.Dia
		order by d.Dia
		option (maxrecursion 40)
		return
	end

	/* 5: tratamientos más realizados en el mes */
	if @accion = 5
	begin
		select top 6 t.Descripcion, COUNT(*) as Cantidad
		from EXP_PROCEDIMIENTOSTRATAMIENTOS as t
			inner join EXP_PROCEDIMIENTOS as p on p.Id_Procedimiento = t.Id_Procedimiento_FK
		where p.Estado = 'F' and p.Fecha >= @mes and p.Fecha <= @hoy
			and (@especialista = 0 or p.Id_Especialista_fk = @especialista) and (@sucursal = 0 or p.Id_Sucursal_FK = @sucursal)
		group by t.Descripcion
		order by COUNT(*) desc, t.Descripcion
		return
	end

	/* 6: próximas citas (desde mañana, 7 días) */
	if @accion = 6
	begin
		select top 12
			c.Id_Cita
			,c.Id_Expediente_fk as Id_Expediente
			,ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2)) as Inicio
			,LTRIM(RTRIM(e.Nombres + ' ' + e.Apellidos)) as Paciente
			,ISNULL(e.Celular, '') as Celular
			,ISNULL(s.Descripcion, '') as Especialista
			,ISNULL(ec.Descripcion, '') as Estado
			,ISNULL(ec.Colors, 'secondary') as Color
		from EXP_CITAS as c
			inner join EXP_EXPEDIENTES as e on e.Id_Expediente = c.Id_Expediente_fk
			left join CAT_ESPECIALISTAS as s on s.Id_Especialista = c.Id_Especialista_fk
			left join CAT_ESTADOSCITAS as ec on ec.Id_Estado = c.Id_EstadoCita_fk
		where ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2)) >= @manana
			and ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2)) < DATEADD(DAY, 8, @hoy)
			and c.Id_EstadoCita_fk not in (@cancelada, @finalizada, 7)
			and (@especialista = 0 or c.Id_Especialista_fk = @especialista) and (@sucursal = 0 or c.Id_Sucursal_FK = @sucursal)
		order by ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2)), c.Id_Cita
		return
	end

	/* 7: pacientes que cumplen años en los próximos 7 días (los del especialista: atendidos o con cita con él) */
	if @accion = 7
	begin
		select top 10 x.Id_Expediente, x.Paciente, x.Celular, x.FechaNacimiento, x.Cumple
			,DATEDIFF(YEAR, x.FechaNacimiento, x.Cumple) as Edad
		from (
			select e.Id_Expediente
				,LTRIM(RTRIM(e.Nombres + ' ' + e.Apellidos)) as Paciente
				,ISNULL(e.Celular, '') as Celular
				,CAST(e.FechaNacimiento as date) as FechaNacimiento
				-- cumpleaños de este año, o del próximo si ya pasó (29 de febrero → 28 en años no bisiestos)
				,case when DATEADD(YEAR, YEAR(@hoy) - YEAR(e.FechaNacimiento), CAST(e.FechaNacimiento as date)) < @hoy
					  then DATEADD(YEAR, YEAR(@hoy) - YEAR(e.FechaNacimiento) + 1, CAST(e.FechaNacimiento as date))
					  else DATEADD(YEAR, YEAR(@hoy) - YEAR(e.FechaNacimiento), CAST(e.FechaNacimiento as date)) end as Cumple
			from EXP_EXPEDIENTES as e
			where e.FechaNacimiento is not null and YEAR(e.FechaNacimiento) between 1900 and YEAR(@hoy) - 1
				and (@especialista = 0
					 or exists (select 1 from EXP_PROCEDIMIENTOS as p where p.Id_Expediente_fk = e.Id_Expediente and p.Id_Especialista_fk = @especialista)
					 or exists (select 1 from EXP_CITAS as c where c.Id_Expediente_fk = e.Id_Expediente and c.Id_Especialista_fk = @especialista))
		) as x
		where x.Cumple <= DATEADD(DAY, 6, @hoy)
		order by x.Cumple, x.Paciente
		return
	end

	/* 8: garantías de servicios de los últimos 90 días (las del especialista, o todas), con el procedimiento y sus tratamientos */
	if @accion = 8
	begin
		select top 30
			r.Id_Reclamo
			,r.FechaCrea as Fecha
			,r.Id_Expediente_fk as Id_Expediente
			,LTRIM(RTRIM(ISNULL(e.Nombres, '') + ' ' + ISNULL(e.Apellidos, ''))) as Paciente
			,ISNULL(e.Celular, '') as Celular
			,ISNULL(s.Descripcion, '') as Especialista
			,p.Fecha as FechaProcedimiento
			,ISNULL(STUFF((select ', ' + t.Descripcion from EXP_PROCEDIMIENTOSTRATAMIENTOS as t
						   where t.Id_Procedimiento_FK = r.Id_Procedimiento_FK order by t.Descripcion
						   for xml path(''), type).value('.', 'varchar(max)'), 1, 2, ''), '') as Tratamientos
			,r.Reclamo as Detalle
			,r.UsuarioCrea as Usuario
		from EXP_Reclamos as r
			left join EXP_EXPEDIENTES as e on e.Id_Expediente = r.Id_Expediente_fk
			left join CAT_ESPECIALISTAS as s on s.Id_Especialista = r.Id_Especialista_FK
			left join EXP_PROCEDIMIENTOS as p on p.Id_Procedimiento = r.Id_Procedimiento_FK
		where r.FechaCrea >= DATEADD(DAY, -89, @hoy)
			and (@especialista = 0 or r.Id_Especialista_FK = @especialista)
			and (@sucursal = 0 or ISNULL(p.Id_Sucursal_FK, e.Id_Sucursal_FK) = @sucursal)
		order by r.FechaCrea desc, r.Id_Reclamo desc
		return
	end
END
GO

/* La página nueva es el dashboard 4 (Administracion) */
update Sys_DashboardInicial
set DashboardUrl = 'Dashboard/frm_DashboardUsuarios.aspx', Id_UsuarioModifica_FK = 'admin', FechaModificacion = GETDATE()
where Id_Dashboard = 4 and ISNULL(DashboardUrl, '') <> 'Dashboard/frm_DashboardUsuarios.aspx'
GO

/* #####################################################################
   23/35  Registros\sql\CUP_Cupones.sql
   ##################################################################### */
PRINT N'>> 23/35 Registros\sql\CUP_Cupones.sql';
GO
/* =====================================================================
   DPieCenter - Cupones de descuento con código QR (Registros/frm_ListaCupones.aspx) que se aplican en caja
   (Facturacion/frm_OpenFactura.aspx) al escanear el QR.

   El QR solo contiene el código del cupón (DPC- + 8 letras al azar): no se puede adivinar ni armar a mano.
   El porcentaje por defecto (10 %), los días de vigencia, el porcentaje máximo y el texto del cupón se configuran
   en FAC_CUPONES_CONFIG. Cada cupón guarda su propio porcentaje.
   Un cupón puede ser para un paciente (o para quien lo presente) y para un tratamiento (o para toda la factura).
   Estado: P pendiente, U usado, A anulado (vencido = pendiente con FechaVence pasada).

   CUP_SP_Cupones
     1 lista   2 crear   3 anular   4 configuración   5 guardar configuración   6 detalle (para imprimir)
     7 aplicar a una factura   8 quitar de la factura   9 marcar usado (dentro de la transacción del pago)
     10 cupón aplicado a una factura   11 resumen
   Script idempotente: se puede ejecutar varias veces.
   ===================================================================== */
SET NOCOUNT ON;
GO

/* ---------- Configuración ---------- */
IF OBJECT_ID('dbo.FAC_CUPONES_CONFIG', 'U') IS NULL
BEGIN
	CREATE TABLE dbo.FAC_CUPONES_CONFIG (
		 Id_Config          int           NOT NULL CONSTRAINT PK_FAC_CUPONES_CONFIG PRIMARY KEY
		,PorcentajeDefecto  decimal(5,2)  NOT NULL
		,PorcentajeMaximo   decimal(5,2)  NOT NULL
		,DiasVigencia       int           NOT NULL
		,Leyenda            varchar(250)  NULL
		,UsuarioModifica    varchar(20)   NULL
		,FechaModifica      datetime      NULL
	);
	INSERT INTO dbo.FAC_CUPONES_CONFIG (Id_Config, PorcentajeDefecto, PorcentajeMaximo, DiasVigencia, Leyenda)
	VALUES (1, 10, 50, 30, 'Presente este cupón en caja. Válido una sola vez. No acumulable con otras promociones.');
END
GO

/* ---------- Cupones: paciente y tratamiento opcionales, porcentaje, vigencia y uso ---------- */
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EXP_CUPONES') AND name = 'Id_Tratamiento_FK' AND is_nullable = 0)
BEGIN
	IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_EXP_CUPONES_CAT_TRATAMIENTOS')
		ALTER TABLE dbo.EXP_CUPONES DROP CONSTRAINT FK_EXP_CUPONES_CAT_TRATAMIENTOS;
	ALTER TABLE dbo.EXP_CUPONES ALTER COLUMN Id_Tratamiento_FK bigint NULL;
	ALTER TABLE dbo.EXP_CUPONES ADD CONSTRAINT FK_EXP_CUPONES_CAT_TRATAMIENTOS FOREIGN KEY (Id_Tratamiento_FK) REFERENCES dbo.CAT_TRATAMIENTOS (Id_Tratamientos);
END
GO
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EXP_CUPONES') AND name = 'Id_expediente_FK' AND is_nullable = 0)
	ALTER TABLE dbo.EXP_CUPONES ALTER COLUMN Id_expediente_FK bigint NULL;
GO
IF COL_LENGTH('dbo.EXP_CUPONES', 'Porcentaje') IS NULL
	ALTER TABLE dbo.EXP_CUPONES ADD Porcentaje decimal(5,2) NOT NULL CONSTRAINT DF_EXP_CUPONES_Porcentaje DEFAULT (10);
IF COL_LENGTH('dbo.EXP_CUPONES', 'FechaVence') IS NULL
	ALTER TABLE dbo.EXP_CUPONES ADD FechaVence date NULL;
IF COL_LENGTH('dbo.EXP_CUPONES', 'Estado') IS NULL
	ALTER TABLE dbo.EXP_CUPONES ADD Estado char(1) NOT NULL CONSTRAINT DF_EXP_CUPONES_Estado DEFAULT ('P');
IF COL_LENGTH('dbo.EXP_CUPONES', 'Id_Factura_FK') IS NULL
	ALTER TABLE dbo.EXP_CUPONES ADD Id_Factura_FK bigint NULL;
IF COL_LENGTH('dbo.EXP_CUPONES', 'FechaUso') IS NULL
	ALTER TABLE dbo.EXP_CUPONES ADD FechaUso datetime NULL;
IF COL_LENGTH('dbo.EXP_CUPONES', 'UsuarioUso') IS NULL
	ALTER TABLE dbo.EXP_CUPONES ADD UsuarioUso varchar(20) NULL;
IF COL_LENGTH('dbo.EXP_CUPONES', 'MontoDescuento') IS NULL
	ALTER TABLE dbo.EXP_CUPONES ADD MontoDescuento decimal(12,2) NULL;
IF COL_LENGTH('dbo.EXP_CUPONES', 'Nota') IS NULL
	ALTER TABLE dbo.EXP_CUPONES ADD Nota varchar(250) NULL;
IF COL_LENGTH('dbo.EXP_CUPONES', 'MotivoAnulacion') IS NULL
	ALTER TABLE dbo.EXP_CUPONES ADD MotivoAnulacion varchar(250) NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_EXP_CUPONES_Codigo')
	CREATE UNIQUE INDEX UX_EXP_CUPONES_Codigo ON dbo.EXP_CUPONES (CodigoCupon);
GO

/* ---------- Cupón aplicado a la factura (antes de cobrar) ---------- */
IF COL_LENGTH('dbo.CAJ_FACTURAS', 'Id_Cupon_FK') IS NULL
	ALTER TABLE dbo.CAJ_FACTURAS ADD Id_Cupon_FK bigint NULL;
GO

CREATE OR ALTER PROCEDURE dbo.CUP_SP_Cupones
	 @accion      int
	,@usuario     varchar(20)   = NULL
	,@id          bigint        = 0
	,@codigo      varchar(20)   = NULL
	,@asignado    varchar(150)  = NULL
	,@expediente  bigint        = 0
	,@tratamiento bigint        = 0
	,@porcentaje  decimal(5,2)  = 0
	,@vence       date          = NULL
	,@nota        varchar(250)  = NULL
	,@factura     bigint        = 0
	,@monto       decimal(12,2) = 0
	,@estado      varchar(1)    = NULL      -- filtro: P pendientes, U usados, A anulados, V vencidos
	,@texto       nvarchar(100) = NULL
	,@desde       date          = NULL
	,@hasta       date          = NULL
	,@dias        int           = 0
	,@maximo      decimal(5,2)  = 0
AS
BEGIN
	SET NOCOUNT ON;
	declare @hoy date = CAST(GETDATE() as date)
	set @codigo = UPPER(NULLIF(LTRIM(RTRIM(@codigo)), ''))
	set @asignado = NULLIF(LTRIM(RTRIM(@asignado)), '')
	set @nota = NULLIF(LTRIM(RTRIM(@nota)), '')
	set @texto = NULLIF(LTRIM(RTRIM(@texto)), '')
	set @estado = NULLIF(@estado, '')

	/* 1: lista */
	if @accion = 1
	begin
		declare @fin date = DATEADD(DAY, 1, @hasta)
		select x.* from (
			select c.Id_Cupon, c.CodigoCupon, c.Asignado, c.Id_expediente_FK, c.Id_Tratamiento_FK, c.Porcentaje, c.FechaVence
				,case when c.Estado = 'P' and c.FechaVence < @hoy then 'V' else c.Estado end as Estado
				,LTRIM(RTRIM(ISNULL(e.Nombres, '') + ' ' + ISNULL(e.Apellidos, ''))) as Paciente, ISNULL(e.Celular, '') as Celular
				,ISNULL(t.Descripcion, '') as Tratamiento, CAST(ISNULL(t.Precio, 0) as decimal(12,2)) as PrecioTratamiento
				,c.Nota, c.Id_Factura_FK, c.FechaUso, c.UsuarioUso, c.MontoDescuento, c.MotivoAnulacion
				,c.UsuarioCrea, c.FechaCrea
				,(select top 1 f.Id_factura from CAJ_FACTURAS as f where f.Id_Cupon_FK = c.Id_Cupon and f.Estado = 0) as FacturaAplicada
			from EXP_CUPONES as c
				left join EXP_EXPEDIENTES as e on e.Id_Expediente = c.Id_expediente_FK
				left join CAT_TRATAMIENTOS as t on t.Id_Tratamientos = c.Id_Tratamiento_FK
			where (@desde is null or c.FechaCrea >= @desde)
				and (@hasta is null or c.FechaCrea < @fin)
				and (@texto is null or c.CodigoCupon like '%' + @texto + '%' or c.Asignado like '%' + @texto + '%'
					 or e.Nombres + ' ' + e.Apellidos like '%' + @texto + '%' or t.Descripcion like '%' + @texto + '%')
		) as x
		where @estado is null or x.Estado = @estado
		order by x.FechaCrea desc
		return
	end

	/* 2: crear (el código lo genera la aplicación) */
	if @accion = 2
	begin
		declare @max decimal(5,2) = (select PorcentajeMaximo from FAC_CUPONES_CONFIG where Id_Config = 1)
		if @codigo is null or @codigo not like 'DPC-[A-Z][A-Z][A-Z][A-Z][A-Z][A-Z][A-Z][A-Z]' THROW 50500, 'Código de cupón no válido.', 1;
		if exists (select 1 from EXP_CUPONES where CodigoCupon = @codigo) THROW 50501, 'El código ya existe. Intente de nuevo.', 1;
		if @expediente = 0 and @asignado is null THROW 50502, 'Seleccione el paciente o escriba a quién se entrega el cupón.', 1;
		if @expediente > 0 and not exists (select 1 from EXP_EXPEDIENTES where Id_Expediente = @expediente) THROW 50503, 'El paciente no existe.', 1;
		if @tratamiento > 0 and not exists (select 1 from CAT_TRATAMIENTOS where Id_Tratamientos = @tratamiento and IsActivo = 1) THROW 50504, 'El tratamiento no está activo.', 1;
		if @porcentaje <= 0 or @porcentaje > @max
		begin
			declare @m1 nvarchar(120) = N'El descuento debe estar entre 1 y ' + CONVERT(nvarchar(10), CAST(@max as int)) + N' por ciento.';
			THROW 50505, @m1, 1;
		end
		if @vence is null or @vence < @hoy THROW 50506, 'La fecha de vencimiento no puede ser anterior a hoy.', 1;

		if @asignado is null
			select @asignado = LTRIM(RTRIM(Nombres + ' ' + Apellidos)) from EXP_EXPEDIENTES where Id_Expediente = @expediente
		insert into EXP_CUPONES (CodigoCupon, Asignado, Id_expediente_FK, Id_Tratamiento_FK, IsActivo, Porcentaje, FechaVence, Estado, Nota, UsuarioCrea, FechaCrea)
		values (@codigo, @asignado, NULLIF(@expediente, 0), NULLIF(@tratamiento, 0), 1, @porcentaje, @vence, 'P', @nota, @usuario, GETDATE())
		select CAST(SCOPE_IDENTITY() as bigint) as Id
		return
	end

	/* 3: anular (@nota = motivo) */
	if @accion = 3
	begin
		if not exists (select 1 from EXP_CUPONES where Id_Cupon = @id and Estado = 'P') THROW 50507, 'Solo se pueden anular cupones pendientes.', 1;
		if @nota is null or LEN(@nota) < 5 THROW 50508, 'Indique el motivo de la anulación.', 1;
		begin transaction
			update EXP_CUPONES set Estado = 'A', IsActivo = 0, MotivoAnulacion = @nota, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_Cupon = @id
			update CAJ_FACTURAS set Id_Cupon_FK = NULL where Id_Cupon_FK = @id and Estado = 0
		commit transaction
		select @id as Id
		return
	end

	/* 4: configuración */
	if @accion = 4
	begin
		select PorcentajeDefecto, PorcentajeMaximo, DiasVigencia, Leyenda, UsuarioModifica, FechaModifica from FAC_CUPONES_CONFIG where Id_Config = 1
		return
	end

	/* 5: guardar configuración (@porcentaje = por defecto, @maximo, @dias, @nota = leyenda) */
	if @accion = 5
	begin
		if @maximo <= 0 or @maximo > 100 THROW 50509, 'El porcentaje máximo debe estar entre 1 y 100.', 1;
		if @porcentaje <= 0 or @porcentaje > @maximo THROW 50510, 'El porcentaje por defecto debe ser mayor que 0 y no superar el máximo.', 1;
		if @dias < 1 or @dias > 730 THROW 50511, 'La vigencia debe estar entre 1 y 730 días.', 1;
		update FAC_CUPONES_CONFIG set PorcentajeDefecto = @porcentaje, PorcentajeMaximo = @maximo, DiasVigencia = @dias, Leyenda = @nota
			,UsuarioModifica = @usuario, FechaModifica = GETDATE()
		where Id_Config = 1
		select CAST(1 as bigint) as Id
		return
	end

	/* 6: detalle de un cupón (para imprimirlo) */
	if @accion = 6
	begin
		select c.Id_Cupon, c.CodigoCupon, c.Asignado, c.Porcentaje, c.FechaVence, c.Estado, c.Nota, c.FechaCrea
			,ISNULL(t.Descripcion, '') as Tratamiento, cfg.Leyenda
		from EXP_CUPONES as c
			left join CAT_TRATAMIENTOS as t on t.Id_Tratamientos = c.Id_Tratamiento_FK
			cross join FAC_CUPONES_CONFIG as cfg
		where c.Id_Cupon = @id and cfg.Id_Config = 1
		return
	end

	/* 7: aplicar a una factura pendiente (al escanear el QR en caja) */
	if @accion = 7
	begin
		declare @idC bigint, @estC char(1), @venceC date, @expC bigint, @tratC bigint, @facC bigint
		select @idC = Id_Cupon, @estC = Estado, @venceC = FechaVence, @expC = Id_expediente_FK, @tratC = Id_Tratamiento_FK, @facC = Id_Factura_FK
		from EXP_CUPONES where CodigoCupon = @codigo

		if @idC is null THROW 50512, 'El cupón no existe. Verifique el código.', 1;
		if @estC = 'A' THROW 50513, 'El cupón fue anulado.', 1;
		if @estC = 'U' and ISNULL(@facC, 0) <> @factura THROW 50514, 'El cupón ya fue utilizado.', 1;
		if @venceC < @hoy
		begin
			declare @m2 nvarchar(120) = N'El cupón venció el ' + CONVERT(nvarchar(10), @venceC, 103) + N'.';
			THROW 50515, @m2, 1;
		end
		if not exists (select 1 from CAJ_FACTURAS where Id_factura = @factura and Estado = 0) THROW 50516, 'La factura ya fue pagada o no existe.', 1;
		if @expC is not null and not exists (select 1 from CAJ_FACTURAS where Id_factura = @factura and Id_Expediente_FK = @expC)
			THROW 50517, 'Este cupón es de otro paciente.', 1;
		if @tratC is not null and not exists (select 1 from CAJ_FACTURASDETALLES where Id_Factura_FK = @factura and Id_tratamiento_FK = @tratC)
			THROW 50518, 'El cupón es para un tratamiento que no está en esta factura.', 1;
		if exists (select 1 from CAJ_FACTURAS where Id_Cupon_FK = @idC and Estado = 0 and Id_factura <> @factura)
			THROW 50519, 'El cupón ya está aplicado a otra factura pendiente.', 1;

		update CAJ_FACTURAS set Id_Cupon_FK = @idC, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_factura = @factura
		select @idC as Id
		return
	end

	/* 8: quitar el cupón de la factura */
	if @accion = 8
	begin
		update CAJ_FACTURAS set Id_Cupon_FK = NULL, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_factura = @factura and Estado = 0
		select @factura as Id
		return
	end

	/* 9: marcar como usado al pagar (se llama dentro de la transacción del pago) */
	if @accion = 9
	begin
		update c set Estado = 'U', IsActivo = 0, Id_Factura_FK = @factura, FechaUso = GETDATE(), UsuarioUso = @usuario, MontoDescuento = @monto
			,UsuarioModifica = @usuario, FechaModifica = GETDATE()
		from EXP_CUPONES as c
			inner join CAJ_FACTURAS as f on f.Id_Cupon_FK = c.Id_Cupon
		where f.Id_factura = @factura and (c.Estado = 'P' or (c.Estado = 'U' and c.Id_Factura_FK = @factura))
		if @@ROWCOUNT = 0 THROW 50520, 'El cupón ya no es válido. Quítelo de la factura y vuelva a cobrar.', 1;
		select @factura as Id
		return
	end

	/* 10: cupón aplicado a una factura */
	if @accion = 10
	begin
		select c.Id_Cupon, c.CodigoCupon, c.Porcentaje, c.Id_Tratamiento_FK, c.FechaVence, c.Estado, c.Id_Factura_FK, ISNULL(t.Descripcion, '') as Tratamiento
		from CAJ_FACTURAS as f
			inner join EXP_CUPONES as c on c.Id_Cupon = f.Id_Cupon_FK
			left join CAT_TRATAMIENTOS as t on t.Id_Tratamientos = c.Id_Tratamiento_FK
		where f.Id_factura = @factura
		return
	end

	/* 11: resumen */
	if @accion = 11
	begin
		select
			(select COUNT(*) from EXP_CUPONES where Estado = 'P' and FechaVence >= @hoy) as Pendientes
			,(select COUNT(*) from EXP_CUPONES where Estado = 'U') as Usados
			,(select COUNT(*) from EXP_CUPONES where Estado = 'P' and FechaVence < @hoy) as Vencidos
			,(select ISNULL(SUM(MontoDescuento), 0) from EXP_CUPONES where Estado = 'U' and FechaUso >= DATEFROMPARTS(YEAR(@hoy), MONTH(@hoy), 1)) as DescuentoMes
		return
	end;

	THROW 50599, 'Acción no válida.', 1;
END
GO

/* #####################################################################
   24/35  Facturacion\sql\CAJ_Caja_Anulaciones.sql
   ##################################################################### */
PRINT N'>> 24/35 Facturacion\sql\CAJ_Caja_Anulaciones.sql';
GO
/* =====================================================================
   DPieCenter - Caja diaria por usuario (Facturacion/frm_Facturas.aspx) y anulación de DTE (Facturacion/frm_Anulaciones.aspx)

   CAJ_SP_Caja: cada usuario abre su caja del día, cobra los procedimientos finalizados (emite el DTE en frm_OpenFactura)
   y la cierra con el arqueo del efectivo. Sin caja abierta hoy no se puede emitir DTE (lo valida también DteService.Pagar).
     1 estado de la caja del usuario   2 abrir   3 resumen (totales por forma de pago)   4 cerrar   5 reabrir (administradores)
     6 procesos finalizados pendientes de cobro   7 DTE emitidos por el usuario en el día de la caja
     8 registrar entrada o salida de efectivo (@tipo E/S, con motivo)   9 movimientos de efectivo de la caja   10 anular un movimiento
     11 datos del cierre   12 último cierre del cajero
   Efectivo esperado al cerrar = fondo + cobros en efectivo + entradas - salidas.

   FAC_SP_DTE_ANULACIONES: anulación (evento de invalidación) de DTE dentro del plazo de Hacienda.
     1 lista con filtros (marca si aún está en plazo)   2 anular   3 plazos por tipo de DTE   4 guardar plazo   5 cajeros (filtro)
   Plazos iniciales (FAC_DTE_PLAZOSINVALIDACION, configurables): factura consumidor final 90 días; crédito fiscal 1 día.
   Al anular por error (tipo 1) u otro motivo (tipo 3) la factura vuelve a quedar pendiente para emitir el DTE que lo reemplaza;
   al rescindir la operación (tipo 2) la factura queda cerrada.
   Script idempotente: se puede ejecutar varias veces.
   ===================================================================== */
SET NOCOUNT ON;
GO

/* ---------- Caja: columnas del cierre ---------- */
IF COL_LENGTH('dbo.CAJ_APETURTACAJA', 'FechaCierre') IS NULL
	ALTER TABLE dbo.CAJ_APETURTACAJA ADD FechaCierre datetime NULL;
IF COL_LENGTH('dbo.CAJ_APETURTACAJA', 'EfectivoEsperado') IS NULL
	ALTER TABLE dbo.CAJ_APETURTACAJA ADD EfectivoEsperado decimal(12,2) NULL;
IF COL_LENGTH('dbo.CAJ_APETURTACAJA', 'EfectivoContado') IS NULL
	ALTER TABLE dbo.CAJ_APETURTACAJA ADD EfectivoContado decimal(12,2) NULL;
IF COL_LENGTH('dbo.CAJ_APETURTACAJA', 'Observaciones') IS NULL
	ALTER TABLE dbo.CAJ_APETURTACAJA ADD Observaciones varchar(500) NULL;
GO
-- una caja por usuario y día
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_CAJ_APETURTACAJA_Cajero_Fecha')
	CREATE UNIQUE INDEX UX_CAJ_APETURTACAJA_Cajero_Fecha ON dbo.CAJ_APETURTACAJA (Cajero, FechaApertura);
GO

/* ---------- Salidas de efectivo de la caja (gastos, pagos, depósitos…) con su motivo ---------- */
IF OBJECT_ID('dbo.CAJ_SALIDAS', 'U') IS NULL
BEGIN
	CREATE TABLE dbo.CAJ_SALIDAS (
		 Id_Salida        bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_CAJ_SALIDAS PRIMARY KEY
		,Id_Apertura_FK   bigint        NOT NULL CONSTRAINT FK_CAJ_SALIDAS_CAJA REFERENCES dbo.CAJ_APETURTACAJA (Id_Apertura)
		,Monto            decimal(12,2) NOT NULL
		,Categoria        varchar(30)   NOT NULL     -- Gasto, Pago a proveedor, Depósito bancario, Retiro, Otro
		,Motivo           varchar(250)  NOT NULL
		,Referencia       varchar(50)   NULL         -- número de factura del proveedor, boleta de depósito…
		,Estado           char(1)       NOT NULL CONSTRAINT DF_CAJ_SALIDAS_Est DEFAULT ('A')   -- A activa, X anulada
		,MotivoAnulacion  varchar(250)  NULL
		,UsuarioCrea      varchar(20)   NOT NULL
		,FechaCrea        datetime      NOT NULL CONSTRAINT DF_CAJ_SALIDAS_Fec DEFAULT (GETDATE())
		,UsuarioModifica  varchar(20)   NULL
		,FechaModifica    datetime      NULL
	);
	CREATE INDEX IX_CAJ_SALIDAS_CAJA ON dbo.CAJ_SALIDAS (Id_Apertura_FK);
END
GO
IF COL_LENGTH('dbo.CAJ_APETURTACAJA', 'Salidas') IS NULL
	ALTER TABLE dbo.CAJ_APETURTACAJA ADD Salidas decimal(12,2) NULL;
GO
/* Manejo de efectivo: la misma tabla guarda entradas (E: reposición de fondo, cambio…) y salidas (S) */
IF COL_LENGTH('dbo.CAJ_SALIDAS', 'Tipo') IS NULL
	ALTER TABLE dbo.CAJ_SALIDAS ADD Tipo char(1) NOT NULL CONSTRAINT DF_CAJ_SALIDAS_Tipo DEFAULT ('S');
IF COL_LENGTH('dbo.CAJ_APETURTACAJA', 'Entradas') IS NULL
	ALTER TABLE dbo.CAJ_APETURTACAJA ADD Entradas decimal(12,2) NULL;
GO

/* ---------- Plazos de invalidación por tipo de DTE ---------- */
IF OBJECT_ID('dbo.FAC_DTE_PLAZOSINVALIDACION', 'U') IS NULL
BEGIN
	CREATE TABLE dbo.FAC_DTE_PLAZOSINVALIDACION (
		 TipoDte         char(2)      NOT NULL CONSTRAINT PK_FAC_DTE_PLAZOSINVALIDACION PRIMARY KEY
		,Descripcion     varchar(100) NOT NULL
		,Dias            int          NOT NULL
		,UsuarioModifica varchar(20)  NULL
		,FechaModifica   datetime     NULL
	);
	INSERT INTO dbo.FAC_DTE_PLAZOSINVALIDACION (TipoDte, Descripcion, Dias) VALUES
		('01', 'Factura (consumidor final)', 90),
		('03', 'Comprobante de crédito fiscal', 1);
END
GO

/* ---------- Eventos de invalidación ---------- */
IF OBJECT_ID('dbo.FAC_DTE_INVALIDACIONES', 'U') IS NULL
BEGIN
	CREATE TABLE dbo.FAC_DTE_INVALIDACIONES (
		 Id_Invalidacion     bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_FAC_DTE_INVALIDACIONES PRIMARY KEY
		,Id_Dte_FK           bigint        NOT NULL CONSTRAINT FK_FAC_DTE_INVALIDACIONES_DTE REFERENCES dbo.FAC_DTE_DOCUMENTOS (Id_Dte)
		,CodigoGeneracion    char(36)      NOT NULL     -- del evento de invalidación
		,FechaAnulacion      datetime      NOT NULL
		,TipoAnulacion       tinyint       NOT NULL     -- 1 error en la información, 2 rescindir la operación, 3 otro
		,Motivo              varchar(250)  NULL
		,NombreResponsable   varchar(100)  NOT NULL
		,TipoDocResponsable  char(2)       NOT NULL
		,NumDocResponsable   varchar(20)   NOT NULL
		,NombreSolicita      varchar(100)  NOT NULL
		,TipoDocSolicita     char(2)       NOT NULL
		,NumDocSolicita      varchar(20)   NOT NULL
		,JsonEvento          nvarchar(max) NOT NULL
		,SelloRecepcion      varchar(100)  NULL
		,Estado              char(1)       NOT NULL CONSTRAINT DF_FAC_DTE_INVALIDACIONES_Est DEFAULT ('G')   -- G generado, T transmitido
		,UsuarioCrea         varchar(20)   NOT NULL
		,FechaCrea           datetime      NOT NULL CONSTRAINT DF_FAC_DTE_INVALIDACIONES_Fec DEFAULT (GETDATE())
	);
	CREATE UNIQUE INDEX UX_FAC_DTE_INVALIDACIONES_DTE ON dbo.FAC_DTE_INVALIDACIONES (Id_Dte_FK);
END
GO

/* =====================================================================
   CAJ_SP_Caja
   ===================================================================== */
CREATE OR ALTER PROCEDURE dbo.CAJ_SP_Caja
	 @accion     int
	,@cajero     varchar(20)
	,@id         bigint        = 0
	,@monto      decimal(12,2) = 0
	,@texto      nvarchar(100) = NULL
	,@desde      date          = NULL
	,@hasta      date          = NULL
	,@observaciones varchar(500) = NULL
	,@categoria  varchar(30)   = NULL
	,@referencia varchar(50)   = NULL
	,@sucursal   int           = 0      -- sucursal de la sesión: la caja se abre en ella y solo ve sus pendientes (0 = todas)
	,@tipo       char(1)       = 'S'    -- acción 8: E entrada de efectivo, S salida
AS
BEGIN
	SET NOCOUNT ON;
	declare @hoy date = CAST(GETDATE() as date)
	set @texto = NULLIF(LTRIM(RTRIM(@texto)), '')
	set @observaciones = NULLIF(LTRIM(RTRIM(@observaciones)), '')
	set @referencia = NULLIF(LTRIM(RTRIM(@referencia)), '')

	/* 1: caja del usuario hoy y, si la tiene, la caja de un día anterior que quedó abierta */
	if @accion = 1
	begin
		select top 1 Id_Apertura, FechaApertura, CAST(MontoApertura as decimal(12,2)) as MontoApertura, Estatus as Abierta
			,FechaCrea as FechaApertura2, FechaCierre, EfectivoEsperado, EfectivoContado
			,CAST(Sobrante as decimal(12,2)) as Sobrante, CAST(Faltante as decimal(12,2)) as Faltante, Observaciones
			,case when FechaApertura < @hoy then 1 else 0 end as Anterior
		from CAJ_APETURTACAJA
		where Cajero = @cajero and (FechaApertura = @hoy or (Estatus = 1 and FechaApertura < @hoy))
		order by case when Estatus = 1 and FechaApertura < @hoy then 0 else 1 end, FechaApertura desc
		return
	end

	/* 2: abrir la caja de hoy */
	if @accion = 2
	begin
		if @monto < 0 or @monto > 10000 THROW 50400, 'El fondo de caja debe estar entre 0 y 10,000.', 1;
		if exists (select 1 from CAJ_APETURTACAJA where Cajero = @cajero and Estatus = 1 and FechaApertura < @hoy)
			THROW 50401, 'Tiene abierta la caja de un día anterior. Ciérrela antes de abrir la de hoy.', 1;
		if exists (select 1 from CAJ_APETURTACAJA where Cajero = @cajero and FechaApertura = @hoy)
			THROW 50402, 'Ya abrió su caja hoy.', 1;
		insert into CAJ_APETURTACAJA (FechaApertura, MontoApertura, Sobrante, Faltante, Cajero, Estatus, UsuarioCrea, FechaCrea, Id_Sucursal_FK)
		values (@hoy, @monto, 0, 0, @cajero, 1, @cajero, GETDATE(), ISNULL(NULLIF(@sucursal, 0), dbo.SUC_FN_Matriz()))
		select CAST(SCOPE_IDENTITY() as bigint) as Id
		return
	end

	/* 3: resumen de la caja: DTE vigentes emitidos por el cajero ese día, por forma de pago */
	if @accion = 3
	begin
		declare @fecha date, @fondo decimal(12,2)
		select @fecha = FechaApertura, @fondo = MontoApertura from CAJ_APETURTACAJA where Id_Apertura = @id and Cajero = @cajero
		if @fecha is null THROW 50403, 'La caja no existe.', 1;

		-- por línea de pago (FAC_DTE_Pagos.sql): un pago combinado suma en cada forma su parte
		select ISNULL(fp.Descripcion, p.FormaPago) as FormaPago, p.FormaPago as Codigo, COUNT(distinct d.Id_Dte) as Documentos, SUM(p.Monto) as Total
		from FAC_DTE_DOCUMENTOS as d
			inner join FAC_VW_DTE_PAGOS as p on p.Id_Dte = d.Id_Dte
			left join CAT_FORMASPAGO as fp on fp.Codigo = p.FormaPago
		where d.UsuarioCrea = @cajero and d.FechaEmision = @fecha and d.Estado <> 'A'
		group by fp.Descripcion, p.FormaPago
		order by p.FormaPago

		select @fondo as Fondo
			,dbo.FAC_FN_EfectivoCajero(@cajero, @fecha) as Efectivo
			,ISNULL((select SUM(TotalPagar) from FAC_DTE_DOCUMENTOS where UsuarioCrea = @cajero and FechaEmision = @fecha and Estado <> 'A'), 0) as Total
			,(select COUNT(*) from FAC_DTE_DOCUMENTOS where UsuarioCrea = @cajero and FechaEmision = @fecha and Estado <> 'A') as Documentos
			,(select COUNT(*) from FAC_DTE_DOCUMENTOS where UsuarioCrea = @cajero and FechaEmision = @fecha and Estado = 'A') as Anulados
			,ISNULL((select SUM(Monto) from CAJ_SALIDAS where Id_Apertura_FK = @id and Estado = 'A' and Tipo = 'S'), 0) as Salidas
			,(select COUNT(*) from CAJ_SALIDAS where Id_Apertura_FK = @id and Estado = 'A' and Tipo = 'S') as CantidadSalidas
			,ISNULL((select SUM(Monto) from CAJ_SALIDAS where Id_Apertura_FK = @id and Estado = 'A' and Tipo = 'E'), 0) as Entradas
			,(select COUNT(*) from CAJ_SALIDAS where Id_Apertura_FK = @id and Estado = 'A' and Tipo = 'E') as CantidadEntradas
			,(select COUNT(*) from CAJ_TICKETS where Id_Apertura_FK = @id) as Tickets
		return
	end

	/* 4: cerrar la caja con el arqueo (@monto = efectivo contado) */
	if @accion = 4
	begin
		declare @f date, @fon decimal(12,2), @abierta bit
		select @f = FechaApertura, @fon = MontoApertura, @abierta = Estatus from CAJ_APETURTACAJA where Id_Apertura = @id and Cajero = @cajero
		if @f is null THROW 50403, 'La caja no existe.', 1;
		if @abierta = 0 THROW 50404, 'La caja ya está cerrada.', 1;
		if @monto < 0 THROW 50405, 'El efectivo contado no puede ser negativo.', 1;

		declare @salidasCaja decimal(12,2) = ISNULL((select SUM(Monto) from CAJ_SALIDAS where Id_Apertura_FK = @id and Estado = 'A' and Tipo = 'S'), 0)
		declare @entradasCaja decimal(12,2) = ISNULL((select SUM(Monto) from CAJ_SALIDAS where Id_Apertura_FK = @id and Estado = 'A' and Tipo = 'E'), 0)
		declare @esperado decimal(12,2) = @fon + @entradasCaja - @salidasCaja + dbo.FAC_FN_EfectivoCajero(@cajero, @f)
		update CAJ_APETURTACAJA set
			 Estatus = 0, FechaCierre = GETDATE(), EfectivoEsperado = @esperado, EfectivoContado = @monto, Salidas = @salidasCaja, Entradas = @entradasCaja
			,Sobrante = case when @monto > @esperado then @monto - @esperado else 0 end
			,Faltante = case when @monto < @esperado then @esperado - @monto else 0 end
			,Observaciones = NULLIF(LTRIM(RTRIM(@observaciones)), '')
			,UsuarioModifica = @cajero, FechaModifica = GETDATE()
		where Id_Apertura = @id
		select @id as Id
		return
	end

	/* 5: reabrir una caja cerrada de hoy (la aplicación solo lo permite a administradores; @cajero = dueño de la caja) */
	if @accion = 5
	begin
		if not exists (select 1 from CAJ_APETURTACAJA where Id_Apertura = @id and Estatus = 0 and FechaApertura = @hoy)
			THROW 50406, 'Solo se puede reabrir una caja cerrada del día de hoy.', 1;
		update CAJ_APETURTACAJA set Estatus = 1, FechaCierre = NULL, EfectivoEsperado = NULL, EfectivoContado = NULL
			,Sobrante = 0, Faltante = 0, UsuarioModifica = @cajero, FechaModifica = GETDATE()
		where Id_Apertura = @id
		select @id as Id
		return
	end

	/* 6: procesos finalizados pendientes de cobro */
	if @accion = 6
	begin
		declare @fin date = DATEADD(DAY, 1, @hasta)
		select f.Id_factura, f.FechaFactura, p.Fecha as FechaProcedimiento, p.FinalProcedimiento
			,e.Id_Expediente, LTRIM(RTRIM(e.Nombres + ' ' + e.Apellidos)) as Paciente, ISNULL(e.Documento, '') as Documento
			,ISNULL(e.Celular, '') as Celular, ISNULL(s.Descripcion, '') as Especialista
			-- total a cobrar: con el descuento vigente de cada tratamiento (CAT_TRATAMIENTOS.Descuento)
			,ISNULL((select SUM(d.Valor - ROUND(d.Valor * ISNULL(ct.Descuento, 0) / 100, 2)) from CAJ_FACTURASDETALLES as d
					 left join CAT_TRATAMIENTOS as ct on ct.Id_Tratamientos = d.Id_tratamiento_FK
					 where d.Id_Factura_FK = f.Id_factura), 0) as Total
			,ISNULL(STUFF((select ', ' + d.Descripion from CAJ_FACTURASDETALLES as d where d.Id_Factura_FK = f.Id_factura
				for xml path(''), type).value('.', 'nvarchar(max)'), 1, 2, ''), '') as Servicios
			,case when exists (select 1 from FAC_DTE_DOCUMENTOS as x where x.Id_Factura_FK = f.Id_factura and x.Estado = 'A') then 1 else 0 end as Reemplazo
		from CAJ_FACTURAS as f
			inner join EXP_PROCEDIMIENTOS as p on p.Id_Procedimiento = f.Id_Procedimiento_FK and p.Estado = 'F'
			inner join EXP_EXPEDIENTES as e on e.Id_Expediente = f.Id_Expediente_FK
			left join CAT_ESPECIALISTAS as s on s.Id_Especialista = p.Id_Especialista_fk
		where f.Estado = 0
			and (@sucursal = 0 or f.Id_Sucursal_FK = @sucursal)
			and (@desde is null or f.FechaFactura >= @desde)
			and (@hasta is null or f.FechaFactura < @fin)
			and (@texto is null or e.Nombres + ' ' + e.Apellidos like '%' + @texto + '%' or e.Documento like '%' + @texto + '%'
				 or e.Celular like '%' + @texto + '%' or CAST(f.Id_factura as varchar(20)) = @texto)
		order by f.FechaFactura desc, f.Id_factura desc
		return
	end

	/* 7: DTE emitidos por el cajero en el día de la caja */
	if @accion = 7
	begin
		declare @dia date = (select FechaApertura from CAJ_APETURTACAJA where Id_Apertura = @id and Cajero = @cajero)
		select d.Id_Dte, d.Id_Factura_FK, d.TipoDte, d.NumeroControl, d.CodigoGeneracion, d.HoraEmision, d.ReceptorNombre
			,d.TotalPagar, d.FormaPago, dbo.FAC_FN_FormasPagoTexto(d.Id_Dte) as FormaPagoTexto, d.Estado, d.RutaPdf
		from FAC_DTE_DOCUMENTOS as d
		where d.UsuarioCrea = @cajero and d.FechaEmision = @dia
		union all   -- tickets POS de servicios sin costo (CAJ_Tickets.sql): TipoDte 'TK', Estado 'K'
		select t.Id_Ticket, t.Id_Factura_FK, 'TK', t.Numero, '', CAST(t.FechaCrea as time), t.Paciente
			,t.Total, '', 'Sin costo', 'K', NULL
		from CAJ_TICKETS as t
		where t.Id_Apertura_FK = @id and t.UsuarioCrea = @cajero
		order by 6 desc
		return
	end

	/* 8: entrada (@tipo E) o salida (@tipo S) de efectivo en la caja abierta de hoy (@monto, @categoria, @observaciones = motivo, @referencia) */
	if @accion = 8
	begin
		declare @dSal date, @fondoSal decimal(12,2), @abiertaSal bit
		select @dSal = FechaApertura, @fondoSal = MontoApertura, @abiertaSal = Estatus from CAJ_APETURTACAJA with (updlock, holdlock)
		where Id_Apertura = @id and Cajero = @cajero
		set @tipo = UPPER(ISNULL(@tipo, 'S'))
		if @tipo not in ('E', 'S') THROW 50427, 'Indique si es entrada o salida de efectivo.', 1;
		if @dSal is null THROW 50403, 'La caja no existe.', 1;
		if @abiertaSal = 0 or @dSal <> @hoy THROW 50407, 'Solo se puede registrar efectivo en su caja abierta de hoy.', 1;
		if @monto <= 0 THROW 50408, 'Ingrese el monto.', 1;
		if @tipo = 'S' and ISNULL(@categoria, '') not in ('Gasto', 'Pago a proveedor', 'Depósito bancario', 'Retiro', 'Otro') THROW 50409, 'Seleccione el tipo de salida.', 1;
		if @tipo = 'E' and ISNULL(@categoria, '') not in ('Reposición de fondo', 'Cambio (sencillo)', 'Préstamo', 'Otro') THROW 50409, 'Seleccione el tipo de entrada.', 1;
		if @observaciones is null or LEN(@observaciones) < 5 THROW 50421, 'Describa el motivo (al menos 5 caracteres).', 1;
		if LEN(@observaciones) > 250 THROW 50422, 'El motivo no puede tener más de 250 caracteres.', 1;

		-- no se puede sacar más efectivo del que hay: fondo + cobros en efectivo + entradas - salidas anteriores
		if @tipo = 'S'
		begin
			declare @disponible decimal(12,2) = @fondoSal
				+ dbo.FAC_FN_EfectivoCajero(@cajero, @dSal)
				+ ISNULL((select SUM(case when Tipo = 'E' then Monto else -Monto end) from CAJ_SALIDAS where Id_Apertura_FK = @id and Estado = 'A'), 0)
			if @monto > @disponible
			begin
				declare @msg nvarchar(200) = N'No hay suficiente efectivo en la caja. Disponible: $' + CONVERT(nvarchar(20), @disponible) + N'.';
				THROW 50423, @msg, 1;
			end
		end

		insert into CAJ_SALIDAS (Id_Apertura_FK, Tipo, Monto, Categoria, Motivo, Referencia, Estado, UsuarioCrea, FechaCrea)
		values (@id, @tipo, @monto, @categoria, @observaciones, @referencia, 'A', @cajero, GETDATE())
		select CAST(SCOPE_IDENTITY() as bigint) as Id
		return
	end

	/* 9: movimientos de efectivo de la caja (entradas y salidas) */
	if @accion = 9
	begin
		select s.Id_Salida, s.Tipo, s.Monto, s.Categoria, s.Motivo, s.Referencia, s.Estado, s.MotivoAnulacion, s.UsuarioCrea, s.FechaCrea, s.UsuarioModifica, s.FechaModifica
		from CAJ_SALIDAS as s
			inner join CAJ_APETURTACAJA as c on c.Id_Apertura = s.Id_Apertura_FK
		where s.Id_Apertura_FK = @id and c.Cajero = @cajero
		order by s.FechaCrea desc
		return
	end

	/* 10: anular una salida registrada por error (@texto = id de la salida, @observaciones = motivo de la anulación) */
	if @accion = 10
	begin
		declare @idSalida bigint = TRY_CONVERT(bigint, @texto)
		if not exists (select 1 from CAJ_SALIDAS as s inner join CAJ_APETURTACAJA as c on c.Id_Apertura = s.Id_Apertura_FK
					   where s.Id_Salida = @idSalida and c.Cajero = @cajero and s.Estado = 'A')
			THROW 50424, 'El movimiento no existe o ya fue anulado.', 1;
		if not exists (select 1 from CAJ_SALIDAS as s inner join CAJ_APETURTACAJA as c on c.Id_Apertura = s.Id_Apertura_FK
					   where s.Id_Salida = @idSalida and c.Estatus = 1 and c.FechaApertura = @hoy)
			THROW 50425, 'Solo se pueden anular movimientos de la caja abierta de hoy.', 1;
		if @observaciones is null or LEN(@observaciones) < 5 THROW 50426, 'Indique por qué anula el movimiento (al menos 5 caracteres).', 1;
		-- anular una entrada quita ese efectivo: no puede dejar la caja en negativo
		if exists (select 1 from CAJ_SALIDAS where Id_Salida = @idSalida and Tipo = 'E')
		begin
			declare @idCajaMov bigint, @diaMov date, @fondoMov decimal(12,2)
			select @idCajaMov = c.Id_Apertura, @diaMov = c.FechaApertura, @fondoMov = c.MontoApertura
			from CAJ_SALIDAS as s inner join CAJ_APETURTACAJA as c on c.Id_Apertura = s.Id_Apertura_FK where s.Id_Salida = @idSalida
			if @fondoMov
				+ dbo.FAC_FN_EfectivoCajero(@cajero, @diaMov)
				+ ISNULL((select SUM(case when Tipo = 'E' then Monto else -Monto end) from CAJ_SALIDAS where Id_Apertura_FK = @idCajaMov and Estado = 'A' and Id_Salida <> @idSalida), 0) < 0
				THROW 50428, 'No se puede anular la entrada: ese efectivo ya salió de la caja. Anule antes la salida correspondiente.', 1;
		end
		update CAJ_SALIDAS set Estado = 'X', MotivoAnulacion = LEFT(@observaciones, 250), UsuarioModifica = @cajero, FechaModifica = GETDATE()
		where Id_Salida = @idSalida
		select @idSalida as Id
		return
	end;

	/* 11: datos del cierre de la caja (se muestran al cerrar). Cada usuario tiene su caja: solo cuenta lo cobrado en ESTA caja
	       (DTE vigentes que emitió el cajero ese día y tickets de la apertura); no se mezclan cobros de otros usuarios ni de otras cajas.
	       Los procedimientos finalizados del día sin facturar en la sucursal solo se informan como alerta: no bloquean el cierre.
	       1er resultado: totales de la caja y conteo de pendientes   2do resultado: pendientes de facturar */
	if @accion = 11
	begin
		declare @dC date, @sucC int
		select @dC = FechaApertura, @sucC = Id_Sucursal_FK from CAJ_APETURTACAJA where Id_Apertura = @id and Cajero = @cajero
		if @dC is null THROW 50403, 'La caja no existe.', 1;

		-- cobros de esta caja
		declare @dteCaja table (Id_Dte bigint primary key, Total decimal(12,2) not null)
		insert @dteCaja
		select Id_Dte, ISNULL(TotalPagar, 0) from FAC_DTE_DOCUMENTOS where UsuarioCrea = @cajero and FechaEmision = @dC and Estado <> 'A'

		declare @documentos int = (select COUNT(*) from @dteCaja) + (select COUNT(*) from CAJ_TICKETS where Id_Apertura_FK = @id)
		declare @cajaTotal decimal(12,2) = ISNULL((select SUM(Total) from @dteCaja), 0) + ISNULL((select SUM(Total) from CAJ_TICKETS where Id_Apertura_FK = @id), 0)
		-- descuentos dados en los documentos de esta caja: por tratamiento (catálogo) y por cupón
		declare @descTrat decimal(12,2), @descCupon decimal(12,2), @cupones int
		-- en el crédito fiscal (03) el descuento del DTE es sin IVA: se lleva a IVA incluido para que cuadre con lo cobrado
		select @descTrat = ISNULL(SUM(ROUND(ISNULL(x.DescuentoTratamiento, 0) * case when d.TipoDte = '03' then 1.13 else 1 end, 2)), 0)
			,@descCupon = ISNULL(SUM(ROUND(ISNULL(x.DescuentoCupon, 0) * case when d.TipoDte = '03' then 1.13 else 1 end, 2)), 0)
		from FAC_DTE_DETALLES as x inner join FAC_DTE_DOCUMENTOS as d on d.Id_Dte = x.Id_Dte_FK
		where x.Id_Dte_FK in (select Id_Dte from @dteCaja)
		select @cupones = COUNT(distinct x.Id_Dte_FK) from FAC_DTE_DETALLES as x
		where x.Id_Dte_FK in (select Id_Dte from @dteCaja) and x.DescuentoCupon > 0
		declare @descuentos decimal(12,2) = @descTrat + @descCupon

		-- alerta: procedimientos finalizados ese día en la sucursal de la caja que aún no se facturan (de cualquier cajero)
		declare @pend table (Id_Procedimiento bigint primary key, Id_Factura bigint null, Valor decimal(12,2) not null
			,Final datetime null, Paciente nvarchar(300) null, Especialista nvarchar(200) null, Servicios nvarchar(max) null)
		insert @pend
		select p.Id_Procedimiento, f.Id_factura
			-- lo que se espera cobrar: con el descuento vigente de cada tratamiento
			,ISNULL(case when f.Id_factura is not null
						 then (select SUM(d.Valor - ROUND(d.Valor * ISNULL(ct.Descuento, 0) / 100, 2))
							   from CAJ_FACTURASDETALLES as d left join CAT_TRATAMIENTOS as ct on ct.Id_Tratamientos = d.Id_tratamiento_FK
							   where d.Id_Factura_FK = f.Id_factura)
						 else (select SUM(x.Valor - ROUND(x.Valor * ISNULL(ct.Descuento, 0) / 100, 2))
							   from EXP_PROCEDIMIENTOSTRATAMIENTOS as x left join CAT_TRATAMIENTOS as ct on ct.Id_Tratamientos = x.Id_Tratamiento_FK
							   where x.Id_Procedimiento_FK = p.Id_Procedimiento) end, 0)
			,p.FinalProcedimiento
			,LTRIM(RTRIM(ISNULL(e.Nombres, '') + ' ' + ISNULL(e.Apellidos, '')))
			,ISNULL(s.Descripcion, '')
			,ISNULL(STUFF((select ', ' + t.Descripcion from EXP_PROCEDIMIENTOSTRATAMIENTOS as t where t.Id_Procedimiento_FK = p.Id_Procedimiento
				for xml path(''), type).value('.', 'nvarchar(max)'), 1, 2, ''), '')
		from EXP_PROCEDIMIENTOS as p
			outer apply (select top 1 Id_factura, Estado from CAJ_FACTURAS where Id_Procedimiento_FK = p.Id_Procedimiento order by Id_factura desc) as f
			left join EXP_EXPEDIENTES as e on e.Id_Expediente = p.Id_Expediente_fk
			left join CAT_ESPECIALISTAS as s on s.Id_Especialista = p.Id_Especialista_fk
		where p.Estado = 'F' and p.Fecha = @dC and (@sucC is null or p.Id_Sucursal_FK = @sucC)
			and ISNULL(f.Estado, 0) = 0

		select @dC as Fecha
			,@documentos as Documentos
			,@cajaTotal as CajaTotal
			,@descuentos as Descuentos
			,@descTrat as DescuentoTratamientos
			,@descCupon as DescuentoCupones
			,@cupones as Cupones
			-- antes de descuentos: lo que valían los servicios cobrados en esta caja
			,@cajaTotal + @descuentos as ValorServicios
			,(select COUNT(*) from @pend) as Pendientes
			,ISNULL((select SUM(Valor) from @pend), 0) as ValorPendientes

		select Id_Procedimiento, ISNULL(Id_Factura, 0) as Id_Factura, Final, Paciente, Especialista, Servicios, Valor
		from @pend
		order by Final, Id_Procedimiento
		return
	end;

	/* 12: último cierre del cajero (efectivo contado): se propone como fondo al abrir la caja siguiente */
	if @accion = 12
	begin
		select top 1 Id_Apertura, FechaApertura, FechaCierre, EfectivoContado
		from CAJ_APETURTACAJA
		where Cajero = @cajero and Estatus = 0 and EfectivoContado is not null
		order by FechaCierre desc, Id_Apertura desc
		return
	end;

	THROW 50499, 'Acción no válida.', 1;
END
GO

/* =====================================================================
   FAC_SP_DTE_ANULACIONES
   ===================================================================== */
CREATE OR ALTER PROCEDURE dbo.FAC_SP_DTE_ANULACIONES
	 @accion        int
	,@usuario       varchar(20)   = NULL
	,@id            bigint        = 0
	,@desde         date          = NULL
	,@hasta         date          = NULL
	,@tipoDte       char(2)       = NULL
	,@cajero        varchar(20)   = NULL
	,@texto         nvarchar(100) = NULL
	,@vista         varchar(10)   = 'plazo'     -- plazo: anulables | anulados | todos
	,@tipoAnulacion tinyint       = 0
	,@motivo        varchar(250)  = NULL
	,@nombreResponsable  varchar(100) = NULL
	,@tipoDocResponsable char(2)      = NULL
	,@numDocResponsable  varchar(20)  = NULL
	,@nombreSolicita     varchar(100) = NULL
	,@tipoDocSolicita    char(2)      = NULL
	,@numDocSolicita     varchar(20)  = NULL
	,@codigoEvento       char(36)     = NULL
	,@json               nvarchar(max) = NULL
	,@dias               int          = 0
	,@sucursal           int          = 0     -- lista: solo los DTE de esa sucursal (0 = todas)
AS
BEGIN
	SET NOCOUNT ON;
	declare @hoy date = CAST(GETDATE() as date)
	set @texto = NULLIF(LTRIM(RTRIM(@texto)), '')
	set @cajero = NULLIF(LTRIM(RTRIM(@cajero)), '')
	set @tipoDte = NULLIF(LTRIM(RTRIM(@tipoDte)), '')
	set @motivo = NULLIF(LTRIM(RTRIM(@motivo)), '')

	/* 1: lista */
	if @accion = 1
	begin
		declare @fin date = DATEADD(DAY, 1, @hasta)
		;with docs as (
			select d.Id_Dte, d.Id_Factura_FK, d.TipoDte, d.NumeroControl, d.CodigoGeneracion, d.FechaEmision, d.HoraEmision
				,d.ReceptorNombre, ISNULL(d.ReceptorDocumento, '') as ReceptorDocumento, d.TotalIva, d.TotalPagar
				,d.FormaPago, d.Estado, d.SelloRecepcion, d.RutaPdf, d.UsuarioCrea as Cajero, d.Ambiente
				,ISNULL(pl.Dias, 0) as DiasPlazo
				,DATEADD(DAY, ISNULL(pl.Dias, 0), d.FechaEmision) as VencePlazo
				,i.FechaAnulacion, i.TipoAnulacion, i.Motivo, i.UsuarioCrea as AnuladoPor
			from FAC_DTE_DOCUMENTOS as d
				left join FAC_DTE_PLAZOSINVALIDACION as pl on pl.TipoDte = d.TipoDte
				left join FAC_DTE_INVALIDACIONES as i on i.Id_Dte_FK = d.Id_Dte
			where (@desde is null or d.FechaEmision >= @desde)
				and (@hasta is null or d.FechaEmision < @fin)
				and (@sucursal = 0 or d.Id_Sucursal_FK = @sucursal)
				and (@tipoDte is null or d.TipoDte = @tipoDte)
				and (@cajero is null or d.UsuarioCrea = @cajero)
				and (@texto is null or d.ReceptorNombre like '%' + @texto + '%' or d.ReceptorDocumento like '%' + @texto + '%'
					 or d.NumeroControl like '%' + @texto + '%' or d.CodigoGeneracion like '%' + @texto + '%'
					 or CAST(d.Id_Factura_FK as varchar(20)) = @texto)
		)
		select *, CAST(case when Estado <> 'A' and VencePlazo >= @hoy then 1 else 0 end as bit) as EnPlazo
			,DATEDIFF(DAY, @hoy, VencePlazo) as DiasRestantes
		from docs
		where (@vista = 'todos')
			or (@vista = 'anulados' and Estado = 'A')
			or (@vista = 'plazo' and Estado <> 'A' and VencePlazo >= @hoy)
		order by FechaEmision desc, HoraEmision desc
		return
	end

	/* 2: anular (el JSON del evento lo arma la aplicación) */
	if @accion = 2
	begin
		declare @tipo char(2), @emision date, @estado char(1), @factura bigint, @plazo int
		select @tipo = d.TipoDte, @emision = d.FechaEmision, @estado = d.Estado, @factura = d.Id_Factura_FK, @plazo = pl.Dias
		from FAC_DTE_DOCUMENTOS as d with (updlock, holdlock)
			left join FAC_DTE_PLAZOSINVALIDACION as pl on pl.TipoDte = d.TipoDte
		where d.Id_Dte = @id

		if @tipo is null THROW 50410, 'El documento no existe.', 1;
		if @estado = 'A' THROW 50411, 'El documento ya está anulado.', 1;
		if @plazo is null THROW 50412, 'No hay plazo de anulación configurado para este tipo de documento.', 1;
		if DATEADD(DAY, @plazo, @emision) < @hoy
			THROW 50413, 'El plazo para anular este documento ya venció. Debe emitirse una nota de crédito.', 1;
		if @tipoAnulacion not in (1, 2, 3) THROW 50414, 'Seleccione el tipo de anulación.', 1;
		if @tipoAnulacion = 3 and (@motivo is null or LEN(@motivo) < 5) THROW 50415, 'Describa el motivo de la anulación (al menos 5 caracteres).', 1;
		if NULLIF(LTRIM(RTRIM(@nombreResponsable)), '') is null or NULLIF(LTRIM(RTRIM(@numDocResponsable)), '') is null
			THROW 50416, 'Ingrese el nombre y documento del responsable de la anulación.', 1;
		if NULLIF(LTRIM(RTRIM(@nombreSolicita)), '') is null or NULLIF(LTRIM(RTRIM(@numDocSolicita)), '') is null
			THROW 50417, 'Ingrese el nombre y documento de quien solicita la anulación.', 1;
		if @json is null or @codigoEvento is null THROW 50418, 'No se generó el evento de invalidación.', 1;

		begin transaction
			insert into FAC_DTE_INVALIDACIONES (Id_Dte_FK, CodigoGeneracion, FechaAnulacion, TipoAnulacion, Motivo
				,NombreResponsable, TipoDocResponsable, NumDocResponsable, NombreSolicita, TipoDocSolicita, NumDocSolicita
				,JsonEvento, UsuarioCrea, FechaCrea)
			values (@id, @codigoEvento, GETDATE(), @tipoAnulacion, @motivo
				,LTRIM(RTRIM(@nombreResponsable)), @tipoDocResponsable, LTRIM(RTRIM(@numDocResponsable))
				,LTRIM(RTRIM(@nombreSolicita)), @tipoDocSolicita, LTRIM(RTRIM(@numDocSolicita))
				,@json, @usuario, GETDATE())

			update FAC_DTE_DOCUMENTOS set Estado = 'A', UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_Dte = @id

			-- por error u otro motivo se debe emitir otro DTE: la factura vuelve a quedar pendiente de cobro
			if @tipoAnulacion in (1, 3)
				update CAJ_FACTURAS set Estado = 0, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_factura = @factura
		commit transaction

		select @id as Id
		return
	end

	/* 3: plazos */
	if @accion = 3
	begin
		select TipoDte, Descripcion, Dias, UsuarioModifica, FechaModifica from FAC_DTE_PLAZOSINVALIDACION order by TipoDte
		return
	end

	/* 4: guardar plazo */
	if @accion = 4
	begin
		if @dias < 0 or @dias > 365 THROW 50419, 'El plazo debe estar entre 0 y 365 días.', 1;
		update FAC_DTE_PLAZOSINVALIDACION set Dias = @dias, UsuarioModifica = @usuario, FechaModifica = GETDATE() where TipoDte = @tipoDte
		if @@ROWCOUNT = 0 THROW 50420, 'Tipo de documento no válido.', 1;
		select CAST(0 as bigint) as Id
		return
	end

	/* 5: cajeros que han emitido DTE */
	if @accion = 5
	begin
		select distinct d.UsuarioCrea as Cajero, LTRIM(RTRIM(ISNULL(u.Nombres, '') + ' ' + ISNULL(u.Apellidos, ''))) as Nombre
		from FAC_DTE_DOCUMENTOS as d left join Sys_Usuarios as u on u.Id_Usuario = d.UsuarioCrea
		order by 2
		return
	end;

	THROW 50499, 'Acción no válida.', 1;
END
GO

/* #####################################################################
   25/35  Facturacion\sql\CAJ_Tickets.sql
   ##################################################################### */
PRINT N'>> 25/35 Facturacion\sql\CAJ_Tickets.sql';
GO
/* =====================================================================
   DPieCenter - Ticket POS para servicios sin costo

   Cuando el total de la factura es $0.00 (control, revisión o cortesía) no se genera DTE: Hacienda no recibe documentos
   sin valor. En su lugar la caja emite un ticket interno numerado (T-000001) que se imprime en papel de 80 mm,
   cierra la factura (CAJ_FACTURAS.Estado = 1) y queda en el listado y el reporte de la caja.

   CAJ_SP_Tickets: 1 emitir   2 ticket de una factura (encabezado + servicios)   3 tickets de una caja
   Requiere CAJ_Caja_Anulaciones.sql (caja diaria). Script idempotente: se puede ejecutar varias veces.
   ===================================================================== */
SET NOCOUNT ON;
GO

IF OBJECT_ID('dbo.CAJ_TICKETS', 'U') IS NULL
BEGIN
	CREATE TABLE dbo.CAJ_TICKETS (
		 Id_Ticket       bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_CAJ_TICKETS PRIMARY KEY
		,Numero          varchar(12)    NOT NULL
		,Id_Factura_FK   bigint         NOT NULL CONSTRAINT FK_CAJ_TICKETS_FACTURA REFERENCES dbo.CAJ_FACTURAS (Id_factura)
		,Id_Apertura_FK  bigint         NOT NULL CONSTRAINT FK_CAJ_TICKETS_APERTURA REFERENCES dbo.CAJ_APETURTACAJA (Id_Apertura)
		,Paciente        varchar(250)   NOT NULL
		,Documento       varchar(30)    NULL
		,Servicios       int            NOT NULL
		,Total           decimal(12,2)  NOT NULL CONSTRAINT DF_CAJ_TICKETS_TOTAL DEFAULT (0)
		,Motivo          varchar(100)   NOT NULL
		,UsuarioCrea     varchar(20)    NOT NULL
		,FechaCrea       datetime       NOT NULL CONSTRAINT DF_CAJ_TICKETS_FECHA DEFAULT (GETDATE())
	);
	CREATE UNIQUE INDEX UX_CAJ_TICKETS_NUMERO ON dbo.CAJ_TICKETS (Numero);
	CREATE UNIQUE INDEX UX_CAJ_TICKETS_FACTURA ON dbo.CAJ_TICKETS (Id_Factura_FK);
	CREATE INDEX IX_CAJ_TICKETS_APERTURA ON dbo.CAJ_TICKETS (Id_Apertura_FK);
END
GO

CREATE OR ALTER PROCEDURE dbo.CAJ_SP_Tickets
	 @accion   int
	,@factura  bigint       = NULL
	,@id       bigint       = NULL      -- apertura de caja (acción 3)
	,@cajero   varchar(20)  = NULL
	,@motivo   varchar(100) = NULL
AS
BEGIN
	SET NOCOUNT ON;
	declare @hoy date = CAST(GETDATE() as date)

	/* 1: emitir el ticket de una factura sin costo */
	if @accion = 1
	begin
		-- Si el llamador ya tiene una transacción se usa un punto de guardado: un error no deshace su transacción
		declare @tc int = @@TRANCOUNT
		if @tc = 0 BEGIN TRANSACTION; else SAVE TRANSACTION tk_emitir;
		declare @apertura bigint = (select Id_Apertura from CAJ_APETURTACAJA with (updlock, holdlock)
			where Cajero = @cajero and FechaApertura = @hoy and Estatus = 1)
		if @apertura is null
		begin
			if @tc = 0 ROLLBACK TRANSACTION; else ROLLBACK TRANSACTION tk_emitir;
			THROW 50430, 'Abra la caja del día para emitir el ticket.', 1;
		end

		declare @estado bit, @expediente bigint
		select @estado = Estado, @expediente = Id_Expediente_FK from CAJ_FACTURAS with (updlock, holdlock) where Id_factura = @factura
		if @estado is null or @estado = 1
		begin
			if @tc = 0 ROLLBACK TRANSACTION; else ROLLBACK TRANSACTION tk_emitir;
			THROW 50431, 'La factura ya fue cobrada o no existe.', 1;
		end

		declare @servicios int, @total decimal(12,2)
		select @servicios = COUNT(*), @total = ISNULL(SUM(CAST(Valor as decimal(12,2))), 0) from CAJ_FACTURASDETALLES where Id_Factura_FK = @factura
		if @servicios = 0
		begin
			if @tc = 0 ROLLBACK TRANSACTION; else ROLLBACK TRANSACTION tk_emitir;
			THROW 50432, 'Agregue al menos un servicio a la factura.', 1;
		end
		if @total <> 0
		begin
			if @tc = 0 ROLLBACK TRANSACTION; else ROLLBACK TRANSACTION tk_emitir;
			THROW 50433, 'La factura tiene valor: cóbrela con DTE.', 1;
		end

		declare @siguiente int = ISNULL((select MAX(CAST(SUBSTRING(Numero, 3, 10) as int)) from CAJ_TICKETS with (updlock, holdlock)), 0) + 1
		declare @numero varchar(12) = 'T-' + RIGHT('000000' + CAST(@siguiente as varchar(10)), CASE WHEN @siguiente > 999999 THEN 10 ELSE 6 END)

		insert into CAJ_TICKETS (Numero, Id_Factura_FK, Id_Apertura_FK, Paciente, Documento, Servicios, Total, Motivo, UsuarioCrea, FechaCrea)
		select @numero, @factura, @apertura, LEFT(LTRIM(RTRIM(ISNULL(e.Nombres, '') + ' ' + ISNULL(e.Apellidos, ''))), 250), NULLIF(LTRIM(RTRIM(e.Documento)), '')
			,@servicios, 0, ISNULL(NULLIF(LTRIM(RTRIM(@motivo)), ''), 'Servicio sin costo'), @cajero, GETDATE()
		from EXP_EXPEDIENTES as e where e.Id_Expediente = @expediente

		update CAJ_FACTURAS set Estado = 1, Cajero = @cajero, NumeroControl = @numero, FechaEmision = GETDATE()
			,UsuarioModifica = @cajero, FechaModifica = GETDATE()
		where Id_factura = @factura
		if @tc = 0 COMMIT TRANSACTION;

		set @accion = 2     -- devuelve el ticket emitido
	end

	/* 2: ticket de una factura (para imprimir o reimprimir) */
	if @accion = 2
	begin
		select t.Id_Ticket, t.Numero, t.Id_Factura_FK, t.Paciente, t.Documento, t.Servicios, t.Total, t.Motivo, t.UsuarioCrea, t.FechaCrea
			,LTRIM(RTRIM(ISNULL(u.Nombres, '') + ' ' + ISNULL(u.Apellidos, ''))) as Cajero
		from CAJ_TICKETS as t left join Sys_Usuarios as u on u.Id_Usuario = t.UsuarioCrea
		where t.Id_Factura_FK = @factura

		select d.Descripion as Descripcion, CAST(d.Valor as decimal(12,2)) as Valor
		from CAJ_FACTURASDETALLES as d
		where d.Id_Factura_FK = @factura and exists (select 1 from CAJ_TICKETS as t where t.Id_Factura_FK = @factura)
		order by d.Id_detalle
		return
	end

	/* 3: tickets de una caja */
	if @accion = 3
	begin
		select t.Id_Ticket, t.Numero, t.Id_Factura_FK, t.Paciente, t.Documento, t.Servicios, t.Total, t.Motivo, t.UsuarioCrea, t.FechaCrea
		from CAJ_TICKETS as t inner join CAJ_APETURTACAJA as a on a.Id_Apertura = t.Id_Apertura_FK
		where t.Id_Apertura_FK = @id and (@cajero is null or a.Cajero = @cajero)
		order by t.FechaCrea desc
		return
	end;

	THROW 50439, 'Acción no válida.', 1;
END
GO

/* #####################################################################
   26/35  Facturacion\sql\FAC_DTE_Diagnostico.sql
   ##################################################################### */
PRINT N'>> 26/35 Facturacion\sql\FAC_DTE_Diagnostico.sql';
GO
/* =====================================================================
   DPieCenter - Diagnóstico de la emisión de DTE (Facturacion/frm_DiagnosticoDte.aspx)

   FAC_DTE_EVENTOS guarda cada intento de guardar los archivos (PDF / JSON) y de enviar el correo, con el error.
   Antes los errores solo iban a Trace y en producción no quedaba registro de por qué no se generaban o no se enviaban.

   FAC_SP_DTE_DIAGNOSTICO
     1 registrar evento   2 últimos eventos   3 DTE con archivos o correo pendientes   4 datos de un DTE para rearmar sus archivos
   Script idempotente: se puede ejecutar varias veces.
   ===================================================================== */
SET NOCOUNT ON;
GO

IF OBJECT_ID('dbo.FAC_DTE_EVENTOS', 'U') IS NULL
BEGIN
	CREATE TABLE dbo.FAC_DTE_EVENTOS (
		 Id_Evento   bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_FAC_DTE_EVENTOS PRIMARY KEY
		,Id_Dte_FK   bigint        NULL
		,Etapa       varchar(20)   NOT NULL     -- Archivos, Correo, Prueba
		,Ok          bit           NOT NULL
		,Mensaje     nvarchar(1000) NULL
		,Usuario     varchar(20)   NULL
		,Servidor    varchar(100)  NULL
		,Fecha       datetime      NOT NULL CONSTRAINT DF_FAC_DTE_EVENTOS_Fecha DEFAULT (GETDATE())
	);
	CREATE INDEX IX_FAC_DTE_EVENTOS_Fecha ON dbo.FAC_DTE_EVENTOS (Fecha DESC);
	CREATE INDEX IX_FAC_DTE_EVENTOS_DTE ON dbo.FAC_DTE_EVENTOS (Id_Dte_FK);
END
GO

CREATE OR ALTER PROCEDURE dbo.FAC_SP_DTE_DIAGNOSTICO
	 @accion   int
	,@id       bigint         = 0
	,@etapa    varchar(20)    = NULL
	,@ok       bit            = 0
	,@mensaje  nvarchar(1000) = NULL
	,@usuario  varchar(20)    = NULL
	,@servidor varchar(100)   = NULL
	,@codigo   char(36)       = NULL
AS
BEGIN
	SET NOCOUNT ON;

	/* 1: registrar evento */
	if @accion = 1
	begin
		insert into FAC_DTE_EVENTOS (Id_Dte_FK, Etapa, Ok, Mensaje, Usuario, Servidor, Fecha)
		values (NULLIF(@id, 0), @etapa, @ok, LEFT(@mensaje, 1000), @usuario, @servidor, GETDATE())
		return
	end

	/* 2: últimos eventos */
	if @accion = 2
	begin
		select top 50 ev.Id_Evento, ev.Id_Dte_FK, ev.Etapa, ev.Ok, ev.Mensaje, ev.Usuario, ev.Servidor, ev.Fecha, d.NumeroControl
		from FAC_DTE_EVENTOS as ev left join FAC_DTE_DOCUMENTOS as d on d.Id_Dte = ev.Id_Dte_FK
		order by ev.Id_Evento desc
		return
	end

	/* 3: DTE vigentes sin archivos guardados o sin correo enviado (últimos 90 días) */
	if @accion = 3
	begin
		select d.Id_Dte, d.Id_Factura_FK, d.TipoDte, d.NumeroControl, d.CodigoGeneracion, d.FechaEmision, d.HoraEmision, d.ReceptorNombre, d.TotalPagar
			,d.RutaPdf, d.CorreoDestino, d.FechaCorreo, d.UsuarioCrea
			,ISNULL(case when d.TipoDte = '03' then r.Correo else e.Email end, '') as CorreoCliente
			,(select top 1 Mensaje from FAC_DTE_EVENTOS as ev where ev.Id_Dte_FK = d.Id_Dte and ev.Ok = 0 order by ev.Id_Evento desc) as UltimoError
		from FAC_DTE_DOCUMENTOS as d
			inner join CAJ_FACTURAS as f on f.Id_factura = d.Id_Factura_FK
			left join EXP_EXPEDIENTES as e on e.Id_Expediente = f.Id_Expediente_FK
			left join FAC_DTE_RECEPTORES as r on r.Id_Receptor = d.Id_Receptor_FK
		where d.Estado <> 'A' and d.FechaEmision >= DATEADD(DAY, -90, CAST(GETDATE() as date))
			and (ISNULL(d.RutaPdf, '') = '' or d.FechaCorreo is null)
		order by d.Id_Dte desc
		return
	end

	/* 4: datos de un DTE (por id o código de generación) para rearmar sus archivos */
	if @accion = 4
	begin
		select d.Id_Dte, d.Id_Factura_FK, d.TipoDte, d.NumeroControl, d.CodigoGeneracion, d.FechaEmision, d.HoraEmision, d.ReceptorNombre, d.TotalPagar
			-- pago combinado (FAC_DTE_Pagos.sql): "Tarjeta Crédito $15.00 + Billetes y monedas $8.90"
			,d.FormaPago, dbo.FAC_FN_FormasPagoTexto(d.Id_Dte) as FormaPagoTexto, d.ReferenciaPago, d.MontoRecibido, d.Cambio, d.UsuarioCrea, d.JsonDte
			,d.Estado, d.CorreoDestino
		from FAC_DTE_DOCUMENTOS as d
		where (@id > 0 and d.Id_Dte = @id) or (@codigo is not null and d.CodigoGeneracion = @codigo)
		return
	end;

	THROW 50699, 'Acción no válida.', 1;
END
GO

/* Opción del menú Facturación (solo administradores) */
IF NOT EXISTS (SELECT 1 FROM dbo.Sys_Opciones WHERE AccesoURL = 'Facturacion/frm_DiagnosticoDte.aspx')
BEGIN
	BEGIN TRANSACTION;
	DECLARE @opcion bigint, @orden int = ISNULL((SELECT MAX(Orden) FROM dbo.Sys_Opciones WHERE IdModulo_FK = 5), 0) + 1;
	INSERT INTO dbo.Sys_Opciones (Descripcion, Abreviado, AccesoURL, IdModulo_FK, Id_UsuarioCrea_FK, FechaCreacion, Orden)
	VALUES ('Diagnóstico DTE', 'DG', 'Facturacion/frm_DiagnosticoDte.aspx', 5, 'admin', GETDATE(), @orden);
	SET @opcion = SCOPE_IDENTITY();
	INSERT INTO dbo.Sys_Permisos (IdAplicativo_FK, IdModulo_FK, IdOpcion_FK, IdGrupo_FK, Id_UsuarioCrea_FK, FechaCreacion)
	VALUES (2, 5, @opcion, 'Administradores', 'admin', GETDATE());
	COMMIT TRANSACTION;
END
GO

/* #####################################################################
   27/35  Facturacion\sql\FAC_DTE_Firmador.sql
   ##################################################################### */
PRINT N'>> 27/35 Facturacion\sql\FAC_DTE_Firmador.sql';
GO
/* =====================================================================
   DPieCenter - Generador de firma de los DTE (firmador del Ministerio de Hacienda)

   Hacienda entrega el "firmador" (svfe-api-firmador): un servicio local al que se envía el JSON del DTE con el NIT del emisor
   y la contraseña de la llave privada del certificado, y devuelve el documento firmado (JWS) para transmitirlo a Hacienda.
   Aquí se guardan su URL, el NIT del certificado y la contraseña (cifrada con la llave de Web.config), y el resultado de la última prueba.
   Se configuran en Opciones > Empresa > Firma electrónica.

   FAC_SP_DTE_FIRMADOR: 1 consultar (sin la contraseña)   2 guardar (contraseña NULL = conservar)   3 registrar prueba   4 contraseña cifrada
   También quita la opción de menú Facturación > Datos DTE: esos datos ahora están en Opciones > Empresa.
   Script idempotente: se puede ejecutar varias veces.
   ===================================================================== */
SET NOCOUNT ON;
GO

IF COL_LENGTH('dbo.FAC_DTE_PARAMETROS', 'FirmadorUrl') IS NULL
	ALTER TABLE dbo.FAC_DTE_PARAMETROS ADD FirmadorUrl varchar(250) NULL;
IF COL_LENGTH('dbo.FAC_DTE_PARAMETROS', 'FirmadorNit') IS NULL
	ALTER TABLE dbo.FAC_DTE_PARAMETROS ADD FirmadorNit varchar(14) NULL;
IF COL_LENGTH('dbo.FAC_DTE_PARAMETROS', 'FirmadorClave') IS NULL
	ALTER TABLE dbo.FAC_DTE_PARAMETROS ADD FirmadorClave varchar(1000) NULL;
IF COL_LENGTH('dbo.FAC_DTE_PARAMETROS', 'FirmadorPrueba') IS NULL
	ALTER TABLE dbo.FAC_DTE_PARAMETROS ADD FirmadorPrueba datetime NULL;
IF COL_LENGTH('dbo.FAC_DTE_PARAMETROS', 'FirmadorResultado') IS NULL
	ALTER TABLE dbo.FAC_DTE_PARAMETROS ADD FirmadorResultado nvarchar(500) NULL;
GO

CREATE OR ALTER PROCEDURE dbo.FAC_SP_DTE_FIRMADOR
	 @accion    int
	,@url       varchar(250)   = NULL
	,@nit       varchar(14)    = NULL
	,@clave     varchar(1000)  = NULL      -- ya cifrada; NULL conserva la guardada
	,@ok        bit            = 0
	,@resultado nvarchar(500)  = NULL
	,@usuario   varchar(20)    = NULL
AS
BEGIN
	SET NOCOUNT ON;
	declare @id int = (select top 1 Id_Parametro from FAC_DTE_PARAMETROS where Estado = 1 order by Id_Parametro)

	if @accion = 1
	begin
		select FirmadorUrl, ISNULL(FirmadorNit, NIT) as FirmadorNit, NIT as NitEmisor
			,CAST(case when LEN(ISNULL(FirmadorClave, '')) > 0 then 1 else 0 end as bit) as TieneClave
			,FirmadorPrueba, FirmadorResultado
		from FAC_DTE_PARAMETROS where Id_Parametro = @id
		return
	end

	if @accion = 2
	begin
		if @id is null THROW 50700, 'Guarde primero los datos de facturación electrónica.', 1;
		set @url = NULLIF(LTRIM(RTRIM(@url)), '')
		set @nit = NULLIF(LTRIM(RTRIM(@nit)), '')
		if @url is not null and @url not like 'http%://_%' THROW 50701, 'La dirección del firmador debe empezar con http:// o https://.', 1;
		if @nit is not null and (@nit like '%[^0-9]%' or LEN(@nit) not in (9, 14)) THROW 50702, 'El NIT del certificado debe tener 14 dígitos (o 9 si es DUI), sin guiones.', 1;
		update FAC_DTE_PARAMETROS set FirmadorUrl = @url, FirmadorNit = @nit, FirmadorClave = ISNULL(@clave, FirmadorClave)
			,UsuarioModifica = @usuario, FechaModifica = GETDATE()
		where Id_Parametro = @id
		select CAST(@id as bigint) as Id
		return
	end

	if @accion = 3
	begin
		update FAC_DTE_PARAMETROS set FirmadorPrueba = GETDATE(), FirmadorResultado = LEFT((case when @ok = 1 then N'OK: ' else N'ERROR: ' end) + ISNULL(@resultado, N''), 500)
		where Id_Parametro = @id
		return
	end

	if @accion = 4
	begin
		select FirmadorUrl, ISNULL(FirmadorNit, NIT) as FirmadorNit, FirmadorClave from FAC_DTE_PARAMETROS where Id_Parametro = @id
		return
	end;

	THROW 50799, 'Acción no válida.', 1;
END
GO

/* Los datos del DTE se administran ahora en Opciones > Empresa: se quita la opción Facturación > Datos DTE */
IF EXISTS (SELECT 1 FROM dbo.Sys_Opciones WHERE AccesoURL = 'Facturacion/frm_EmpresaDte.aspx')
BEGIN
	BEGIN TRANSACTION;
	DELETE p FROM dbo.Sys_Permisos AS p INNER JOIN dbo.Sys_Opciones AS o ON o.Id_Opcion = p.IdOpcion_FK WHERE o.AccesoURL = 'Facturacion/frm_EmpresaDte.aspx';
	DELETE a FROM dbo.Sys_AccesosObjetos AS a INNER JOIN dbo.Sys_Opciones AS o ON o.Id_Opcion = a.IdOpcion_FK WHERE o.AccesoURL = 'Facturacion/frm_EmpresaDte.aspx';
	DELETE FROM dbo.Sys_Opciones WHERE AccesoURL = 'Facturacion/frm_EmpresaDte.aspx';
	COMMIT TRANSACTION;
END
GO

/* #####################################################################
   28/35  Reportes\sql\REP_Dashboard_Caja.sql
   ##################################################################### */
PRINT N'>> 28/35 Reportes\sql\REP_Dashboard_Caja.sql';
GO
/* =====================================================================
   DPieCenter - Dashboard (Dashboard/form_DashboardGeneral.aspx) y reporte de caja (Reportes/frm_repCaja.aspx)

   REP_SP_Dashboard: indicadores de especialistas, expedientes, citas y procedimientos en un rango de fechas.
   REP_SP_Caja: cobros (DTE y tickets POS), aperturas/cierres con arqueo, salidas de efectivo, anulaciones y cupones por rango y cajero.
   Requiere CAJ_Caja_Anulaciones.sql, CAJ_Tickets.sql y CUP_Cupones.sql.
   Las citas reprogramadas (estado 5) se cuentan: desde 2026-11 reprogramar cambia la fecha de la misma cita (sigue vigente).
   Script idempotente: se puede ejecutar varias veces.
   ===================================================================== */
SET NOCOUNT ON;
GO

CREATE OR ALTER PROCEDURE [dbo].[REP_SP_Dashboard]
	 @accion int
	,@desde  date
	,@hasta  date
	,@sucursal int = 0      -- 0: todas las sucursales
AS
BEGIN
	SET NOCOUNT ON;

	if @hasta < @desde
		THROW 50080, 'La fecha final no puede ser anterior a la inicial.', 1;

	declare @fin datetime2 = DATEADD(DAY, 1, CAST(@hasta as datetime2))   -- fin exclusivo
	declare @cancelada bigint = (select top 1 Id_Estado from CAT_ESTADOSCITAS where Cancelada = 1 order by Id_Estado)    -- 3
	declare @finalizada bigint = (select top 1 Id_Estado from CAT_ESTADOSCITAS where Finalizada = 1 order by Id_Estado)  -- 6
	declare @reprogramada bigint = 5

	-- Citas del rango (las antiguas sin FechaInicio usan Fecha)
	declare @citas table (Id_Cita bigint primary key, Inicio datetime2, Id_Especialista bigint, Id_Estado bigint, Id_Expediente bigint)
	insert into @citas
	select Id_Cita, ISNULL(FechaInicio, CAST(Fecha as datetime2)), Id_Especialista_fk, Id_EstadoCita_fk, Id_Expediente_fk
	from EXP_CITAS
	where ISNULL(FechaInicio, CAST(Fecha as datetime2)) >= @desde and ISNULL(FechaInicio, CAST(Fecha as datetime2)) < @fin		and (@sucursal = 0 or Id_Sucursal_FK = @sucursal)

	-- Procedimientos finalizados del rango con su total
	declare @procs table (Id_Procedimiento bigint primary key, Fecha date, Id_Especialista bigint, Id_Expediente bigint, Total decimal(12,2), Minutos int)
	insert into @procs
	select p.Id_Procedimiento, p.Fecha, p.Id_Especialista_fk, p.Id_Expediente_fk
		,ISNULL((select SUM(t.Valor) from EXP_PROCEDIMIENTOSTRATAMIENTOS as t where t.Id_Procedimiento_FK = p.Id_Procedimiento), 0)
		-- duración solo cuando inicio y fin tienen fecha real (los antiguos guardaban solo la hora)
		,case when YEAR(p.InicioProcedimiento) > 2000 and YEAR(p.FinalProcedimiento) > 2000
				   and DATEDIFF(MINUTE, p.InicioProcedimiento, p.FinalProcedimiento) between 1 and 600
			  then DATEDIFF(MINUTE, p.InicioProcedimiento, p.FinalProcedimiento) end
	from EXP_PROCEDIMIENTOS as p
	where p.Estado = 'F' and p.Fecha >= @desde and p.Fecha <= @hasta
		and (@sucursal = 0 or p.Id_Sucursal_FK = @sucursal)

	/* 1: indicadores */
	if @accion = 1
	begin
		select
			(select COUNT(*) from EXP_EXPEDIENTES where (@sucursal = 0 or Id_Sucursal_FK = @sucursal)) as Pacientes
			,(select COUNT(*) from EXP_EXPEDIENTES where FechaCrea >= @desde and FechaCrea < @fin and (@sucursal = 0 or Id_Sucursal_FK = @sucursal)) as PacientesNuevos
			,(select COUNT(distinct Id_Expediente) from @procs) as PacientesAtendidos
			,(select COUNT(*) from @citas) as Citas
			,(select COUNT(*) from @citas where Id_Estado = @finalizada) as CitasAtendidas
			,(select COUNT(*) from @citas where Id_Estado = @cancelada) as CitasCanceladas
			,(select COUNT(*) from @citas as c inner join CAT_ESTADOSCITAS as ec on ec.Id_Estado = c.Id_Estado
			  where ec.Procesos = 1 and c.Inicio >= CAST(GETDATE() as date)) as CitasPendientes
			,(select COUNT(*) from @procs) as Procedimientos
			,(select ISNULL(SUM(Total), 0) from @procs) as Facturado
			,(select ISNULL(SUM(TotalPagar), 0) from FAC_DTE_DOCUMENTOS
			  where Estado <> 'A' and FechaEmision >= @desde and FechaEmision <= @hasta and (@sucursal = 0 or Id_Sucursal_FK = @sucursal)) as Cobrado
			,(select AVG(CAST(Minutos as decimal(10,2))) from @procs where Minutos is not null) as MinutosPromedio
			,(select COUNT(*) from EXP_PROCEDIMIENTOS where Estado = 'I' and CAST(InicioProcedimiento as date) = CAST(GETDATE() as date) and (@sucursal = 0 or Id_Sucursal_FK = @sucursal)) as EnAtencion
			,(select COUNT(*) from EXP_PROCEDIMIENTOS where Estado = 'S' and CAST(FechaCrea as date) = CAST(GETDATE() as date) and (@sucursal = 0 or Id_Sucursal_FK = @sucursal)) as EnSala
		return
	end

	/* 2: serie diaria: citas, procedimientos finalizados, expedientes nuevos e ingresos (cobrado en caja: DTE vigentes, en efectivo y otras formas) */
	if @accion = 2
	begin
		select x.Dia
			,SUM(x.Citas) as Total
			,SUM(x.Atendidas) as Atendidas
			,SUM(x.Canceladas) as Canceladas
			,SUM(x.Procedimientos) as Procedimientos
			,SUM(x.Nuevos) as Nuevos
			,CAST(SUM(x.Ingresos) as decimal(12,2)) as Ingresos
			,CAST(SUM(x.Efectivo) as decimal(12,2)) as IngresosEfectivo
		from (
			select CAST(Inicio as date) as Dia, 1 as Citas
				,case when Id_Estado = @finalizada then 1 else 0 end as Atendidas
				,case when Id_Estado = @cancelada then 1 else 0 end as Canceladas
				,0 as Procedimientos, 0 as Nuevos, CAST(0 as decimal(12,2)) as Ingresos, CAST(0 as decimal(12,2)) as Efectivo
			from @citas
			union all
			select Fecha, 0, 0, 0, 1, 0, 0, 0 from @procs
			union all
			select CAST(FechaCrea as date), 0, 0, 0, 0, 1, 0, 0
			from EXP_EXPEDIENTES where FechaCrea >= @desde and FechaCrea < @fin and (@sucursal = 0 or Id_Sucursal_FK = @sucursal)
			union all
			-- efectivo: solo la parte en efectivo de cada documento (pago combinado, FAC_DTE_Pagos.sql)
			select d.FechaEmision, 0, 0, 0, 0, 0, ISNULL(d.TotalPagar, 0)
				,ISNULL((select SUM(p.Monto) from FAC_VW_DTE_PAGOS as p where p.Id_Dte = d.Id_Dte and p.FormaPago = '01'), 0)
			from FAC_DTE_DOCUMENTOS as d
			where d.Estado <> 'A' and d.FechaEmision >= @desde and d.FechaEmision <= @hasta and (@sucursal = 0 or d.Id_Sucursal_FK = @sucursal)
		) as x
		group by x.Dia
		order by x.Dia
		return
	end

	/* 3: desempeño por especialista.
	      Facturado: valor de los tratamientos de los procedimientos finalizados en el rango (EXP_PROCEDIMIENTOSTRATAMIENTOS.Valor).
	      FacturadoCaja: lo cobrado en caja CON IVA: DTE vigentes emitidos en el rango
	      (factura 01: precio con IVA; crédito fiscal 03: venta gravada * 1.13) + pagos adelantados usados en el rango. */
	if @accion = 3
	begin
		;with lineas as (
			select p.Id_Especialista_fk as Id_Especialista
				,case when d.TipoDte = '01' then ISNULL(dd.VentaGravada, 0) else ISNULL(dd.VentaGravada, 0) * 1.13 end as Venta
			from FAC_DTE_DOCUMENTOS as d
				inner join FAC_DTE_DETALLES as dd on dd.Id_Dte_FK = d.Id_Dte
				inner join CAJ_FACTURAS as f on f.Id_factura = d.Id_Factura_FK
				inner join EXP_PROCEDIMIENTOS as p on p.Id_Procedimiento = f.Id_Procedimiento_FK
			where d.Estado <> 'A' and d.FechaEmision >= @desde and d.FechaEmision <= @hasta
				and (@sucursal = 0 or d.Id_Sucursal_FK = @sucursal)
			union all
			select p.Id_Especialista_fk, u.Monto
			from CAJ_ANTICIPOS_USOS as u
				inner join EXP_PROCEDIMIENTOS as p on p.Id_Procedimiento = u.Id_Procedimiento_FK
			where u.FechaCrea >= @desde and u.FechaCrea < @fin
				and (@sucursal = 0 or p.Id_Sucursal_FK = @sucursal)
		)
		select Id_Especialista, CAST(SUM(Venta) as decimal(12,2)) as Caja
		into #caja
		from lineas group by Id_Especialista

		select
			s.Id_Especialista
			,s.Descripcion as Especialista
			,s.IsActivo as Activo
			,ISNULL(c.Citas, 0) as Citas
			,ISNULL(c.Atendidas, 0) as Atendidas
			,ISNULL(c.Canceladas, 0) as Canceladas
			,ISNULL(p.Procedimientos, 0) as Procedimientos
			,ISNULL(p.Pacientes, 0) as Pacientes
			,ISNULL(p.Total, 0) as Facturado
			,ISNULL(k.Caja, 0) as FacturadoCaja
			,p.MinutosPromedio
		from CAT_ESPECIALISTAS as s
			left join (select Id_Especialista, COUNT(*) as Citas
							,SUM(case when Id_Estado = @finalizada then 1 else 0 end) as Atendidas
							,SUM(case when Id_Estado = @cancelada then 1 else 0 end) as Canceladas
					   from @citas group by Id_Especialista) as c on c.Id_Especialista = s.Id_Especialista
			left join (select Id_Especialista, COUNT(*) as Procedimientos, COUNT(distinct Id_Expediente) as Pacientes
							,SUM(Total) as Total, AVG(CAST(Minutos as decimal(10,2))) as MinutosPromedio
					   from @procs group by Id_Especialista) as p on p.Id_Especialista = s.Id_Especialista
			left join #caja as k on k.Id_Especialista = s.Id_Especialista
		where s.IsActivo = 1 or c.Citas > 0 or p.Procedimientos > 0 or k.Caja > 0
		order by ISNULL(p.Total, 0) desc, s.Descripcion
		return
	end

	/* 4: tratamientos más realizados */
	if @accion = 4
	begin
		select top 8 t.Descripcion, COUNT(*) as Cantidad, SUM(ISNULL(t.Valor, 0)) as Total
		from EXP_PROCEDIMIENTOSTRATAMIENTOS as t
			inner join @procs as p on p.Id_Procedimiento = t.Id_Procedimiento_FK
		group by t.Descripcion
		order by COUNT(*) desc, SUM(ISNULL(t.Valor, 0)) desc
		return
	end

	/* 5: citas por estado */
	if @accion = 5
	begin
		select ec.Descripcion as Estado, ISNULL(ec.Colors, 'secondary') as Color, COUNT(*) as Cantidad
		from @citas as c inner join CAT_ESTADOSCITAS as ec on ec.Id_Estado = c.Id_Estado
		group by ec.Descripcion, ec.Colors, ec.Id_Estado
		order by ec.Id_Estado
		return
	end

	/* 6: agenda de hoy */
	if @accion = 6
	begin
		select top 20
			ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2)) as Inicio
			,LTRIM(RTRIM(e.Nombres + ' ' + e.Apellidos)) as Paciente
			,ISNULL(s.Descripcion, '') as Especialista
			,ISNULL(ec.Descripcion, '') as Estado
			,ISNULL(ec.Colors, 'secondary') as Color
			,ISNULL(p.Estado, '') as EstadoProcedimiento
		from EXP_CITAS as c
			inner join EXP_EXPEDIENTES as e on e.Id_Expediente = c.Id_Expediente_fk
			left join CAT_ESPECIALISTAS as s on s.Id_Especialista = c.Id_Especialista_fk
			left join CAT_ESTADOSCITAS as ec on ec.Id_Estado = c.Id_EstadoCita_fk
			outer apply (select top 1 Estado from EXP_PROCEDIMIENTOS where Id_Cita_FK = c.Id_Cita order by Id_Procedimiento desc) as p
		where CAST(ISNULL(c.FechaInicio, c.Fecha) as date) = CAST(GETDATE() as date)			and (@sucursal = 0 or c.Id_Sucursal_FK = @sucursal)
		order by ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2)), c.Id_Cita
		return
	end

	/* 7: pacientes nuevos por mes (6 meses hasta @hasta) y cómo nos conocieron (en el rango) */
	if @accion = 7
	begin
		declare @mes0 date = DATEADD(MONTH, -5, DATEFROMPARTS(YEAR(@hasta), MONTH(@hasta), 1))
		;with meses as (
			select @mes0 as Mes union all select DATEADD(MONTH, 1, Mes) from meses where Mes < DATEFROMPARTS(YEAR(@hasta), MONTH(@hasta), 1)
		)
		select m.Mes, COUNT(e.Id_Expediente) as Nuevos
		from meses as m
			left join EXP_EXPEDIENTES as e on e.FechaCrea >= m.Mes and e.FechaCrea < DATEADD(MONTH, 1, m.Mes) and (@sucursal = 0 or e.Id_Sucursal_FK = @sucursal)
		group by m.Mes
		order by m.Mes

		select
			SUM(case when Facebook = 1 then 1 else 0 end) as Facebook
			,SUM(case when Instagram = 1 then 1 else 0 end) as Instagram
			,SUM(case when Buscador = 1 then 1 else 0 end) as Buscador
			,SUM(case when Recomendado = 1 then 1 else 0 end) as Recomendado
			,SUM(case when TikTok = 1 then 1 else 0 end) as TikTok
			,SUM(case when WhatsApp = 1 then 1 else 0 end) as WhatsApp
			,SUM(case when Otros = 1 then 1 else 0 end) as Otros
			,SUM(case when ISNULL(Facebook,0) = 0 and ISNULL(Instagram,0) = 0 and ISNULL(Buscador,0) = 0 and ISNULL(Recomendado,0) = 0
					   and ISNULL(TikTok,0) = 0 and ISNULL(WhatsApp,0) = 0 and ISNULL(Otros,0) = 0 then 1 else 0 end) as SinDato
		from EXP_EXPEDIENTES
		where FechaCrea >= @desde and FechaCrea < @fin and (@sucursal = 0 or Id_Sucursal_FK = @sucursal)
		return
	end

	/* 10: pacientes con cita por día del rango: expediente creado en meses anteriores al de la cita vs creado en el mes de la cita.
	   Sin citas canceladas ni anuladas; cada paciente se cuenta una vez por día. 2.º resultado: pacientes distintos del rango
	   (nuevo = su expediente se creó en el mes de alguna de sus citas del rango). */
	if @accion = 10
	begin
		declare @anulada bigint = 7
		declare @pac table (Dia date, Id_Expediente bigint, Nuevo bit, primary key (Dia, Id_Expediente))
		insert into @pac
		select x.Dia, x.Id_Expediente
			,case when e.FechaCrea >= DATEFROMPARTS(YEAR(x.Dia), MONTH(x.Dia), 1) then 1 else 0 end
		from (select distinct CAST(Inicio as date) as Dia, Id_Expediente from @citas
			  where Id_Expediente is not null and ISNULL(Id_Estado, 0) not in (@cancelada, @anulada)) as x
			inner join EXP_EXPEDIENTES as e on e.Id_Expediente = x.Id_Expediente

		select Dia, SUM(case when Nuevo = 0 then 1 else 0 end) as Anteriores, SUM(case when Nuevo = 1 then 1 else 0 end) as Nuevos
		from @pac group by Dia order by Dia

		select ISNULL(SUM(case when Nuevo = 0 then 1 else 0 end), 0) as Anteriores, ISNULL(SUM(case when Nuevo = 1 then 1 else 0 end), 0) as Nuevos
		from (select Id_Expediente, CAST(MAX(CAST(Nuevo as int)) as bit) as Nuevo from @pac group by Id_Expediente) as t
		return
	end

	/* 11: ingresos por día y forma de pago (DTE vigentes, igual que el total cobrado; un pago combinado suma en cada forma su parte) */
	if @accion = 11
	begin
		select d.FechaEmision as Dia
			,ISNULL(NULLIF(LTRIM(RTRIM(p.FormaPago)), ''), '99') as Codigo
			,ISNULL(f.Descripcion, 'Otros') as FormaPago
			,CAST(SUM(ISNULL(p.Monto, 0)) as decimal(12,2)) as Total
		from FAC_DTE_DOCUMENTOS as d
			inner join FAC_VW_DTE_PAGOS as p on p.Id_Dte = d.Id_Dte
			left join CAT_FORMASPAGO as f on f.Codigo = p.FormaPago
		where d.Estado <> 'A' and d.FechaEmision >= @desde and d.FechaEmision <= @hasta and (@sucursal = 0 or d.Id_Sucursal_FK = @sucursal)
		group by d.FechaEmision, ISNULL(NULLIF(LTRIM(RTRIM(p.FormaPago)), ''), '99'), ISNULL(f.Descripcion, 'Otros')
		order by d.FechaEmision, Codigo
		return
	end

	/* 12: garantías de servicios del rango por especialista, contra sus procedimientos finalizados del rango */
	if @accion = 12
	begin
		select s.Id_Especialista
			,ISNULL(s.Descripcion, 'Sin especialista') as Especialista
			,g.Garantias
			,g.Pacientes
			,ISNULL((select COUNT(*) from @procs as x where x.Id_Especialista = g.Id_Especialista), 0) as Procedimientos
			,g.Ultima
		from (select r.Id_Especialista_FK as Id_Especialista, COUNT(*) as Garantias
					,COUNT(distinct r.Id_Expediente_fk) as Pacientes, MAX(r.FechaCrea) as Ultima
			  from EXP_Reclamos as r
				  left join EXP_PROCEDIMIENTOS as p on p.Id_Procedimiento = r.Id_Procedimiento_FK
				  left join EXP_EXPEDIENTES as e on e.Id_Expediente = r.Id_Expediente_fk
			  where r.FechaCrea >= @desde and r.FechaCrea < @fin
				  and (@sucursal = 0 or ISNULL(p.Id_Sucursal_FK, e.Id_Sucursal_FK) = @sucursal)
			  group by r.Id_Especialista_FK) as g
			left join CAT_ESPECIALISTAS as s on s.Id_Especialista = g.Id_Especialista
		order by g.Garantias desc, s.Descripcion
		return
	end

	/* 8: periodo anterior de la misma duración, para comparar los indicadores */
	if @accion = 8
	begin
		declare @dias int = DATEDIFF(DAY, @desde, @hasta) + 1
		declare @antDesde date = DATEADD(DAY, -@dias, @desde), @antHasta date = DATEADD(DAY, -1, @desde)
		declare @antFin datetime2 = CAST(@desde as datetime2)

		select
			@antDesde as Desde
			,@antHasta as Hasta
			,(select COUNT(*) from EXP_EXPEDIENTES where FechaCrea >= @antDesde and FechaCrea < @antFin and (@sucursal = 0 or Id_Sucursal_FK = @sucursal)) as PacientesNuevos
			,COUNT(*) as Citas
			,SUM(case when c.Id_EstadoCita_fk = @finalizada then 1 else 0 end) as CitasAtendidas
			,SUM(case when c.Id_EstadoCita_fk = @cancelada then 1 else 0 end) as CitasCanceladas
			,(select COUNT(*) from EXP_PROCEDIMIENTOS where Estado = 'F' and Fecha >= @antDesde and Fecha <= @antHasta and (@sucursal = 0 or Id_Sucursal_FK = @sucursal)) as Procedimientos
			,(select COUNT(distinct Id_Expediente_fk) from EXP_PROCEDIMIENTOS where Estado = 'F' and Fecha >= @antDesde and Fecha <= @antHasta and (@sucursal = 0 or Id_Sucursal_FK = @sucursal)) as PacientesAtendidos
			,(select ISNULL(SUM(t.Valor), 0)
			  from EXP_PROCEDIMIENTOSTRATAMIENTOS as t inner join EXP_PROCEDIMIENTOS as p on p.Id_Procedimiento = t.Id_Procedimiento_FK
			  where p.Estado = 'F' and p.Fecha >= @antDesde and p.Fecha <= @antHasta and (@sucursal = 0 or p.Id_Sucursal_FK = @sucursal)) as Facturado
		from EXP_CITAS as c
		where ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2)) >= @antDesde
			and ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2)) < @antFin			and (@sucursal = 0 or c.Id_Sucursal_FK = @sucursal)
		return
	end

	/* 9: top 10 de pacientes recurrentes: más visitas (días distintos con procedimiento finalizado) en el rango */
	if @accion = 9
	begin
		select top 10
			e.Id_Expediente
			,LTRIM(RTRIM(e.Nombres + ' ' + e.Apellidos)) as Paciente
			,ISNULL(e.Celular, '') as Celular
			,COUNT(distinct p.Fecha) as Visitas
			,COUNT(*) as Procedimientos
			,SUM(p.Total) as Total
			,MAX(p.Fecha) as UltimaVisita
			,(select MIN(x.Fecha) from EXP_PROCEDIMIENTOS as x where x.Id_Expediente_fk = e.Id_Expediente and x.Estado = 'F') as PrimeraVisita
			,(select top 1 s.Descripcion
			  from @procs as y inner join CAT_ESPECIALISTAS as s on s.Id_Especialista = y.Id_Especialista
			  where y.Id_Expediente = e.Id_Expediente
			  group by s.Descripcion order by COUNT(*) desc) as Especialista
		from @procs as p
			inner join EXP_EXPEDIENTES as e on e.Id_Expediente = p.Id_Expediente
		group by e.Id_Expediente, e.Nombres, e.Apellidos, e.Celular
		having COUNT(distinct p.Fecha) >= 2
		order by COUNT(distinct p.Fecha) desc, COUNT(*) desc, SUM(p.Total) desc, MAX(p.Fecha) desc
		return
	end;

	THROW 50099, 'Acción no válida.', 1;
END
GO

CREATE OR ALTER PROCEDURE [dbo].[REP_SP_Caja]
	 @accion int
	,@desde  date = null
	,@hasta  date = null
	,@cajero varchar(20) = null      -- null o '' = todos
	,@sucursal int = 0               -- 0: todas las sucursales
AS
BEGIN
	SET NOCOUNT ON;

	set @cajero = NULLIF(LTRIM(RTRIM(@cajero)), '')

	if @accion in (1, 4, 5, 6) and (@desde is null or @hasta is null or @hasta < @desde)
		THROW 50081, 'Seleccione un rango de fechas válido.', 1;
	if @accion in (1, 4, 5, 6) and DATEDIFF(DAY, @desde, @hasta) > 366
		THROW 50082, 'El rango no puede superar un año.', 1;

	/* 1: cobros del rango: DTE emitidos (incluidos los anulados, con su anulación) y tickets POS de servicios sin costo (TipoDte 'TK') */
	if @accion = 1
	begin
		select
			d.Id_Dte
			,d.Id_Factura_FK as Id_Factura
			,d.FechaEmision
			,d.HoraEmision
			,d.TipoDte
			,ISNULL(d.NumeroControl, '') as NumeroControl
			,ISNULL(d.ReceptorNombre, '') as Cliente
			,ISNULL(LTRIM(RTRIM(e.Nombres + ' ' + e.Apellidos)), '') as Paciente
			,ISNULL(d.FormaPago, '') as FormaPago
			,dbo.FAC_FN_FormasPagoTexto(d.Id_Dte) as FormaPagoTexto      -- pago combinado: "Tarjeta Crédito $15.00 + Billetes y monedas $8.90"
			,ISNULL(d.ReferenciaPago, '') as Referencia
			,ISNULL(d.TotalGravado, 0) as Gravado
			,ISNULL(d.TotalIva, 0) as Iva
			,ISNULL(d.TotalPagar, 0) as Total
			,ISNULL(ds.Descuento, 0) as Descuento
			,ISNULL(ds.DescuentoTratamiento, 0) as DescuentoTratamiento
			,ISNULL(ds.DescuentoCupon, 0) as DescuentoCupon
			,ISNULL(cu.CodigoCupon, '') as Cupon
			,d.Estado
			,ISNULL(d.UsuarioCrea, '') as Cajero
			,ISNULL(LTRIM(RTRIM(u.Nombres + ' ' + u.Apellidos)), ISNULL(d.UsuarioCrea, '')) as CajeroNombre
			,inv.FechaAnulacion
			,ISNULL(inv.Motivo, '') as MotivoAnulacion
			,ISNULL(inv.UsuarioCrea, '') as UsuarioAnula
		from FAC_DTE_DOCUMENTOS as d
			left join CAJ_FACTURAS as f on f.Id_factura = d.Id_Factura_FK
			left join EXP_EXPEDIENTES as e on e.Id_Expediente = f.Id_Expediente_FK
			left join CAT_FORMASPAGO as fp on fp.Codigo = d.FormaPago
			left join Sys_Usuarios as u on u.Id_Usuario = d.UsuarioCrea
			left join FAC_DTE_INVALIDACIONES as inv on inv.Id_Dte_FK = d.Id_Dte
			left join EXP_CUPONES as cu on cu.Id_Cupon = f.Id_Cupon_FK
			-- descuento del documento (como en el DTE: en crédito fiscal es sin IVA) y su desglose
			outer apply (select SUM(MontoDescu) as Descuento, SUM(ISNULL(DescuentoTratamiento, 0)) as DescuentoTratamiento
							,SUM(ISNULL(DescuentoCupon, 0)) as DescuentoCupon
						 from FAC_DTE_DETALLES where Id_Dte_FK = d.Id_Dte) as ds
		where d.FechaEmision >= @desde and d.FechaEmision <= @hasta
			and (@cajero is null or d.UsuarioCrea = @cajero)
			and (@sucursal = 0 or d.Id_Sucursal_FK = @sucursal)
		union all
		select
			t.Id_Ticket, t.Id_Factura_FK, CAST(t.FechaCrea as date), CAST(t.FechaCrea as time), 'TK', t.Numero
			,t.Paciente, t.Paciente, '', 'Sin costo', '', 0, 0, t.Total, 0, 0, 0, '', 'K'
			,t.UsuarioCrea, ISNULL(LTRIM(RTRIM(u.Nombres + ' ' + u.Apellidos)), t.UsuarioCrea)
			,null, '', ''
		from CAJ_TICKETS as t
			left join Sys_Usuarios as u on u.Id_Usuario = t.UsuarioCrea
			left join CAJ_APETURTACAJA as ta on ta.Id_Apertura = t.Id_Apertura_FK
		where t.FechaCrea >= @desde and t.FechaCrea < DATEADD(DAY, 1, @hasta)
			and (@cajero is null or t.UsuarioCrea = @cajero)
			and (@sucursal = 0 or ta.Id_Sucursal_FK = @sucursal)
		order by 3, 4, 1
		return
	end

	/* 2: cajeros que han cobrado o abierto caja alguna vez */
	if @accion = 2
	begin
		select x.Cajero, ISNULL(LTRIM(RTRIM(u.Nombres + ' ' + u.Apellidos)), x.Cajero) as Nombre
		from (select UsuarioCrea as Cajero from FAC_DTE_DOCUMENTOS where UsuarioCrea is not null
			  union select Cajero from CAJ_APETURTACAJA where Cajero is not null) as x
			left join Sys_Usuarios as u on u.Id_Usuario = x.Cajero
		order by Nombre
		return
	end

	/* 3: facturas pendientes de cobro generadas en el rango (procedimientos finalizados sin pagar),
	      con el descuento vigente de cada tratamiento (lo que se espera cobrar) */
	if @accion = 3
	begin
		select COUNT(*) as Facturas, ISNULL(SUM(t.Total), 0) as Total
		from CAJ_FACTURAS as f
			outer apply (select SUM(d.Valor - ROUND(d.Valor * ISNULL(ct.Descuento, 0) / 100, 2)) as Total
						 from CAJ_FACTURASDETALLES as d left join CAT_TRATAMIENTOS as ct on ct.Id_Tratamientos = d.Id_tratamiento_FK
						 where d.Id_Factura_FK = f.Id_factura) as t
		where f.Estado = 0 and f.FechaFactura >= @desde and f.FechaFactura <= @hasta
			and (@sucursal = 0 or f.Id_Sucursal_FK = @sucursal)
		return
	end

	/* 4: aperturas y cierres de caja del rango, con el arqueo (las abiertas calculan el esperado al momento) */
	if @accion = 4
	begin
		select a.Id_Apertura, a.FechaApertura, a.Cajero
			,ISNULL(LTRIM(RTRIM(u.Nombres + ' ' + u.Apellidos)), a.Cajero) as CajeroNombre
			,CAST(ISNULL(a.MontoApertura, 0) as decimal(12,2)) as Fondo
			,a.FechaCrea as HoraApertura, a.FechaCierre, a.Estatus as Abierta
			,ISNULL(c.Cobrado, 0) as Cobrado, ISNULL(c.Efectivo, 0) as Efectivo, ISNULL(c.Documentos, 0) as Documentos
			,ISNULL(s.Salidas, 0) as Salidas, ISNULL(s.CantidadSalidas, 0) as CantidadSalidas
			,ISNULL(s.Entradas, 0) as Entradas, ISNULL(s.CantidadEntradas, 0) as CantidadEntradas
			,(select COUNT(*) from CAJ_TICKETS where Id_Apertura_FK = a.Id_Apertura) as Tickets
			,ISNULL(a.EfectivoEsperado, CAST(ISNULL(a.MontoApertura, 0) as decimal(12,2)) + ISNULL(c.Efectivo, 0) + ISNULL(s.Entradas, 0) - ISNULL(s.Salidas, 0)) as EfectivoEsperado
			,a.EfectivoContado
			,CAST(ISNULL(a.Sobrante, 0) as decimal(12,2)) as Sobrante
			,CAST(ISNULL(a.Faltante, 0) as decimal(12,2)) as Faltante
			,ISNULL(a.Observaciones, '') as Observaciones
			,ISNULL(ds.Tratamientos, 0) as DescuentoTratamientos
			,ISNULL(ds.Cupones, 0) as DescuentoCupones
		from CAJ_APETURTACAJA as a
			left join Sys_Usuarios as u on u.Id_Usuario = a.Cajero
			outer apply (select SUM(TotalPagar) as Cobrado, dbo.FAC_FN_EfectivoCajero(a.Cajero, a.FechaApertura) as Efectivo, COUNT(*) as Documentos
				from FAC_DTE_DOCUMENTOS where UsuarioCrea = a.Cajero and FechaEmision = a.FechaApertura and Estado <> 'A') as c
			-- descuentos de la caja (IVA incluido, igual que en su cierre)
			outer apply (select SUM(ROUND(ISNULL(x.DescuentoTratamiento, 0) * case when d.TipoDte = '03' then 1.13 else 1 end, 2)) as Tratamientos
							,SUM(ROUND(ISNULL(x.DescuentoCupon, 0) * case when d.TipoDte = '03' then 1.13 else 1 end, 2)) as Cupones
				from FAC_DTE_DOCUMENTOS as d inner join FAC_DTE_DETALLES as x on x.Id_Dte_FK = d.Id_Dte
				where d.UsuarioCrea = a.Cajero and d.FechaEmision = a.FechaApertura and d.Estado <> 'A') as ds
			outer apply (select SUM(case when Tipo = 'S' then Monto end) as Salidas, COUNT(case when Tipo = 'S' then 1 end) as CantidadSalidas
							,SUM(case when Tipo = 'E' then Monto end) as Entradas, COUNT(case when Tipo = 'E' then 1 end) as CantidadEntradas
				from CAJ_SALIDAS where Id_Apertura_FK = a.Id_Apertura and Estado = 'A') as s
		where a.FechaApertura >= @desde and a.FechaApertura <= @hasta
			and (@cajero is null or a.Cajero = @cajero)
			and (@sucursal = 0 or a.Id_Sucursal_FK = @sucursal)
		order by a.FechaApertura, CajeroNombre
		return
	end

	/* 5: movimientos de efectivo del rango: entradas (E) y salidas (S), incluidos los anulados con su motivo */
	if @accion = 5
	begin
		select s.Id_Salida, s.Tipo, a.FechaApertura, s.FechaCrea, a.Cajero
			,ISNULL(LTRIM(RTRIM(u.Nombres + ' ' + u.Apellidos)), a.Cajero) as CajeroNombre
			,s.Monto, s.Categoria, s.Motivo, ISNULL(s.Referencia, '') as Referencia, s.Estado
			,ISNULL(s.MotivoAnulacion, '') as MotivoAnulacion
		from CAJ_SALIDAS as s
			inner join CAJ_APETURTACAJA as a on a.Id_Apertura = s.Id_Apertura_FK
			left join Sys_Usuarios as u on u.Id_Usuario = a.Cajero
		where a.FechaApertura >= @desde and a.FechaApertura <= @hasta
			and (@cajero is null or a.Cajero = @cajero)
			and (@sucursal = 0 or a.Id_Sucursal_FK = @sucursal)
		order by s.FechaCrea
		return
	end

	/* 6: líneas de pago de los DTE vigentes del rango (pago combinado): Reporte de caja › Por forma de pago */
	if @accion = 6
	begin
		select d.Id_Dte, p.FormaPago as Codigo, ISNULL(fp.Descripcion, p.FormaPago) as FormaPago, p.Monto
		from FAC_DTE_DOCUMENTOS as d
			inner join FAC_VW_DTE_PAGOS as p on p.Id_Dte = d.Id_Dte
			left join CAT_FORMASPAGO as fp on fp.Codigo = p.FormaPago
		where d.Estado <> 'A' and d.FechaEmision >= @desde and d.FechaEmision <= @hasta
			and (@cajero is null or d.UsuarioCrea = @cajero)
			and (@sucursal = 0 or d.Id_Sucursal_FK = @sucursal)
		return
	end;

	THROW 50099, 'Acción no válida.', 1;
END
GO

/* ---------- Menú: Reportes > Caja (solo Administradores, igual que Facturación > Caja) ---------- */
IF NOT EXISTS (SELECT 1 FROM dbo.Sys_Opciones WHERE AccesoURL = 'Reportes/frm_repCaja.aspx')
BEGIN
    BEGIN TRANSACTION;
    DECLARE @opcion bigint;
    INSERT INTO dbo.Sys_Opciones (Descripcion, Abreviado, AccesoURL, IdModulo_FK, Id_UsuarioCrea_FK, FechaCreacion, Orden)
    VALUES ('Caja', 'CJ', 'Reportes/frm_repCaja.aspx', 6, 'admin', GETDATE(), 4);
    SET @opcion = SCOPE_IDENTITY();
    INSERT INTO dbo.Sys_Permisos (IdAplicativo_FK, IdModulo_FK, IdOpcion_FK, IdGrupo_FK, Id_UsuarioCrea_FK, FechaCreacion)
    VALUES (2, 6, @opcion, 'Administradores', 'admin', GETDATE());
    INSERT INTO dbo.Sys_AccesosObjetos (IdAplicativo_FK, IdModulo_FK, IdOpcion_FK, IdGrupo_FK, Descripcion, Accion)
    VALUES (2, 6, @opcion, 'Administradores', 'Caja', 1);
    COMMIT TRANSACTION;
END
GO

/* #####################################################################
   29/35  Facturacion\sql\FAC_Procedimientos_Curso.sql
   ##################################################################### */
PRINT N'>> 29/35 Facturacion\sql\FAC_Procedimientos_Curso.sql';
GO
/* =====================================================================
   DPieCenter - Facturación > Procedimientos (Facturacion/frm_ProcedimientosCurso.aspx)

   Procedimientos en curso de todos los especialistas: reprogramar, cambiar de especialista, cancelar y finalizar.
   Usa dbo.EXP_SP_Procedimientos_Atencion (acción 14 y acciones 10 a 13), de Registros/sql/EXP_Procedimientos_Atencion.sql.
   La opción del menú recibe los mismos grupos que Facturación > Caja.
   Script idempotente: se puede ejecutar varias veces.
   ===================================================================== */
SET NOCOUNT ON;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Sys_Opciones WHERE AccesoURL = 'Facturacion/frm_ProcedimientosCurso.aspx')
BEGIN
	BEGIN TRANSACTION;
	DECLARE @opcion bigint, @orden int = ISNULL((SELECT MAX(Orden) FROM dbo.Sys_Opciones WHERE IdModulo_FK = 5), 0) + 1;
	INSERT INTO dbo.Sys_Opciones (Descripcion, Abreviado, AccesoURL, IdModulo_FK, Id_UsuarioCrea_FK, FechaCreacion, Orden)
	VALUES ('Procedimientos', 'PR', 'Facturacion/frm_ProcedimientosCurso.aspx', 5, 'admin', GETDATE(), @orden);
	SET @opcion = SCOPE_IDENTITY();

	-- mismos grupos que tienen la Caja; si la Caja no tiene permisos, al menos Administradores
	INSERT INTO dbo.Sys_Permisos (IdAplicativo_FK, IdModulo_FK, IdOpcion_FK, IdGrupo_FK, Id_UsuarioCrea_FK, FechaCreacion)
	SELECT DISTINCT p.IdAplicativo_FK, 5, @opcion, p.IdGrupo_FK, 'admin', GETDATE()
	FROM dbo.Sys_Permisos AS p INNER JOIN dbo.Sys_Opciones AS o ON o.Id_Opcion = p.IdOpcion_FK
	WHERE o.AccesoURL = 'Facturacion/frm_Facturas.aspx';

	IF NOT EXISTS (SELECT 1 FROM dbo.Sys_Permisos WHERE IdOpcion_FK = @opcion AND IdGrupo_FK = 'Administradores')
		INSERT INTO dbo.Sys_Permisos (IdAplicativo_FK, IdModulo_FK, IdOpcion_FK, IdGrupo_FK, Id_UsuarioCrea_FK, FechaCreacion)
		VALUES (2, 5, @opcion, 'Administradores', 'admin', GETDATE());
	COMMIT TRANSACTION;
END
GO

/* #####################################################################
   30/35  Registros\sql\EXP_Citas_Agendadas.sql
   ##################################################################### */
PRINT N'>> 30/35 Registros\sql\EXP_Citas_Agendadas.sql';
GO
/* =====================================================================
   DPieCenter - Citas agendadas (calendario de Registros > Citas)
   Agrega la columna Paciente: el calendario muestra el nombre del paciente en lugar del especialista.
   Sin @desde/@hasta: citas no canceladas desde hoy (lógica original).
   Con @desde/@hasta: citas no canceladas en ese rango, incluidos días pasados (semana del calendario).
   Idempotente.
   ===================================================================== */
SET NOCOUNT ON;
GO
CREATE OR ALTER PROCEDURE [dbo].[EXP_SP_Citas_Agendadas]
	@acc int
	,@desde datetime2 = NULL
	,@hasta datetime2 = NULL
	,@sucursal int = 0          -- 0: todas las sucursales
AS
BEGIN TRY
	SET NOCOUNT ON;

	select
		c.Id_Cita [Id]
		,c.FechaInicio
		,s.Descripcion [Profesional]
		,t.Descripcion [TipoCita]
		,LTRIM(RTRIM(ISNULL(e.Nombres, '') + ' ' + ISNULL(e.Apellidos, ''))) [Paciente]
	from EXP_CITAS as c
		inner join CAT_ESPECIALISTAS as s on c.Id_Especialista_fk = s.Id_Especialista
		inner join CAT_TIPOSCITAS as t on c.Id_TipoCita_FK = t.Id_TipoCita
		left join EXP_EXPEDIENTES as e on e.Id_Expediente = c.Id_Expediente_fk
	where c.Id_EstadoCita_fk <> 3
		and (@sucursal = 0 or c.Id_Sucursal_FK = @sucursal)
		and ((@desde is null and c.Fecha >= CAST(GETDATE() as date))
			or (@desde is not null and c.FechaInicio >= @desde and c.FechaInicio < ISNULL(@hasta, DATEADD(day, 7, @desde))))
	order by c.FechaInicio

END TRY
BEGIN CATCH
	SELECT
	'ERRORNUMBER: '+CONVERT(varchar(max),ERROR_NUMBER())+
	'--ERRORLINE: '+CONVERT(varchar(max),ERROR_LINE())+
	'--ERRORMESSAGE: '+CONVERT(varchar(max),ERROR_MESSAGE())+
	'--ERRORSEVERITY: '+CONVERT(varchar(max),ERROR_SEVERITY())+
	'--ERRORPROCEDURE:'+CONVERT(varchar(max),ERROR_PROCEDURE())+
	'--ERRORSTATE: '+CONVERT(varchar(max),ERROR_STATE()) AS respuesta
END CATCH
GO

/* #####################################################################
   31/35  Opciones\sql\SYS_Recuperar_Clave.sql
   ##################################################################### */
PRINT N'>> 31/35 Opciones\sql\SYS_Recuperar_Clave.sql';
GO
/* =====================================================================
   DPieCenter - Recuperación de contraseña desde el login (recuperarClave.aspx)
   1) El usuario escribe su correo y recibe un código de 6 dígitos (vence en 10 minutos).
   2) Valida el código (máximo 5 intentos).
   3) Escribe la nueva contraseña.
   El código no se guarda: solo su hash SHA-256. Script idempotente.
   ===================================================================== */
SET NOCOUNT ON;
GO

IF OBJECT_ID('dbo.Sys_RecuperacionClave', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Sys_RecuperacionClave (
        Id_Recuperacion bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_Sys_RecuperacionClave PRIMARY KEY,
        Id_Usuario_FK   varchar(20)  NOT NULL,
        Email           varchar(100) NOT NULL,
        CodigoHash      char(64)     NOT NULL,          -- SHA-256 en hexadecimal
        Expira          datetime     NOT NULL,
        Intentos        int          NOT NULL CONSTRAINT DF_Sys_RecuperacionClave_Int DEFAULT (0),
        Verificado      datetime     NULL,              -- momento en que se validó el código
        Usado           datetime     NULL,              -- momento en que se cambió la contraseña
        Anulado         bit          NOT NULL CONSTRAINT DF_Sys_RecuperacionClave_Anu DEFAULT (0),
        Ip              varchar(45)  NULL,
        FechaCrea       datetime     NOT NULL CONSTRAINT DF_Sys_RecuperacionClave_FC DEFAULT (GETDATE())
    );
    CREATE INDEX IX_Sys_RecuperacionClave_Usuario ON dbo.Sys_RecuperacionClave (Id_Usuario_FK, FechaCrea DESC);
END
GO

/* @accion
     1 solicitar:  @idUsuario, @codigoHash, @ip -> Id_Recuperacion, Id_Usuario, Nombre, Email (el registrado en el usuario;
                   sin filas si el usuario no existe, está inactivo o no tiene correo)
     2 validar:    @id, @codigoHash         -> Resultado: OK | INCORRECTO (Restantes) | VENCIDO | BLOQUEADO
     3 cambiar:    @id, @newpass (hash)     -> Resultado: OK | VENCIDO | REPETIDA
   Los errores de uso se devuelven con THROW 5xxxx y se muestran al usuario. */
CREATE OR ALTER PROCEDURE dbo.Sys_SP_RecuperarClave
    @accion     int,
    @email      varchar(100) = NULL,
    @codigoHash char(64)     = NULL,
    @ip         varchar(45)  = NULL,
    @id         bigint       = 0,
    @newpass    varchar(50)  = NULL,
    @idUsuario  varchar(20)  = NULL     -- usuario que pide el código: se envía SOLO al correo registrado en ese usuario
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MinutosCodigo int = 10, @MinutosCambio int = 15, @MaxIntentos int = 5, @MaxSolicitudes int = 3;
    DECLARE @usuario varchar(20);

    IF @accion = 1
    BEGIN
        SET @idUsuario = NULLIF(LTRIM(RTRIM(ISNULL(@idUsuario, ''))), '');
        IF @idUsuario IS NULL OR @codigoHash IS NULL THROW 52001, 'Escriba su usuario.', 1;

        -- Antes se buscaba por correo y se tomaba el primer usuario con ese correo: si dos usuarios lo compartían,
        -- el código era para otro usuario. Ahora el correo es siempre el del usuario indicado.
        SELECT @usuario = Id_Usuario, @email = LTRIM(RTRIM(Email))
        FROM dbo.Sys_Usuarios
        WHERE Id_Usuario = @idUsuario AND ISNULL(EstatusUsuario, 'A') <> 'I'
            AND LTRIM(RTRIM(ISNULL(Email, ''))) LIKE '_%@_%._%';

        IF @usuario IS NULL RETURN;    -- usuario inexistente, inactivo o sin correo: no se revela cuál

        IF (SELECT COUNT(*) FROM dbo.Sys_RecuperacionClave
            WHERE Id_Usuario_FK = @usuario AND FechaCrea > DATEADD(MINUTE, -15, GETDATE())) >= @MaxSolicitudes
            THROW 52002, 'Ya se enviaron varios códigos. Espere 15 minutos antes de solicitar otro.', 1;

        UPDATE dbo.Sys_RecuperacionClave SET Anulado = 1
        WHERE Id_Usuario_FK = @usuario AND Usado IS NULL AND Anulado = 0;

        INSERT INTO dbo.Sys_RecuperacionClave (Id_Usuario_FK, Email, CodigoHash, Expira, Ip)
        VALUES (@usuario, @email, @codigoHash, DATEADD(MINUTE, @MinutosCodigo, GETDATE()), @ip);

        SELECT CAST(SCOPE_IDENTITY() AS bigint) AS Id_Recuperacion, u.Id_Usuario,
               LTRIM(RTRIM(ISNULL(u.Nombres, '') + ' ' + ISNULL(u.Apellidos, ''))) AS Nombre, LTRIM(RTRIM(u.Email)) AS Email
        FROM dbo.Sys_Usuarios AS u WHERE u.Id_Usuario = @usuario;
        RETURN;
    END

    IF @accion = 2
    BEGIN
        DECLARE @hash char(64), @expira datetime, @intentos int, @anulado bit, @usado datetime;
        SELECT @hash = CodigoHash, @expira = Expira, @intentos = Intentos, @anulado = Anulado, @usado = Usado
        FROM dbo.Sys_RecuperacionClave WHERE Id_Recuperacion = @id;

        IF @hash IS NULL OR @anulado = 1 OR @usado IS NOT NULL OR @expira < GETDATE()
        BEGIN SELECT 'VENCIDO' AS Resultado, 0 AS Restantes; RETURN; END
        IF @intentos >= @MaxIntentos
        BEGIN SELECT 'BLOQUEADO' AS Resultado, 0 AS Restantes; RETURN; END

        IF @hash = @codigoHash
        BEGIN
            UPDATE dbo.Sys_RecuperacionClave SET Verificado = GETDATE() WHERE Id_Recuperacion = @id;
            SELECT 'OK' AS Resultado, @MaxIntentos - @intentos AS Restantes;
            RETURN;
        END

        UPDATE dbo.Sys_RecuperacionClave SET Intentos = Intentos + 1,
               Anulado = CASE WHEN Intentos + 1 >= @MaxIntentos THEN 1 ELSE Anulado END
        WHERE Id_Recuperacion = @id;
        SELECT CASE WHEN @intentos + 1 >= @MaxIntentos THEN 'BLOQUEADO' ELSE 'INCORRECTO' END AS Resultado,
               @MaxIntentos - @intentos - 1 AS Restantes;
        RETURN;
    END

    IF @accion = 3
    BEGIN
        IF ISNULL(@newpass, '') = '' THROW 52003, 'Escriba la nueva contraseña.', 1;

        SELECT @usuario = Id_Usuario_FK FROM dbo.Sys_RecuperacionClave
        WHERE Id_Recuperacion = @id AND Verificado IS NOT NULL AND Usado IS NULL AND Anulado = 0
          AND Verificado > DATEADD(MINUTE, -@MinutosCambio, GETDATE());
        IF @usuario IS NULL BEGIN SELECT 'VENCIDO' AS Resultado; RETURN; END

        -- No se permite repetir la contraseña actual ni las 3 anteriores
        IF EXISTS (SELECT 1 FROM dbo.Sys_Usuarios WHERE Id_Usuario = @usuario AND ClaveAcceso = @newpass)
           OR EXISTS (SELECT 1 FROM (SELECT TOP 3 Clave FROM dbo.Sys_UsuarioHistoricoClave
                                     WHERE Id_Usuario_FK = @usuario ORDER BY FechaCreacion DESC) AS h WHERE h.Clave = @newpass)
        BEGIN SELECT 'REPETIDA' AS Resultado; RETURN; END

        DECLARE @propia bit = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
        BEGIN TRY
            IF @propia = 1 BEGIN TRANSACTION;

            INSERT INTO dbo.Sys_UsuarioHistoricoClave (Id_Usuario_FK, Clave, FechaCreacion, Id_UsuarioCrea_FK)
            SELECT Id_Usuario, ClaveAcceso, GETDATE(), Id_Usuario FROM dbo.Sys_Usuarios
            WHERE Id_Usuario = @usuario AND ISNULL(ClaveAcceso, '') <> '';

            UPDATE dbo.Sys_Usuarios SET ClaveAcceso = @newpass, FechaCambioclave = GETDATE(),
                   FechaModificacion = GETDATE(), Id_UsuarioModifica_FK = @usuario
            WHERE Id_Usuario = @usuario;

            UPDATE dbo.Sys_RecuperacionClave SET Usado = GETDATE() WHERE Id_Recuperacion = @id;
            UPDATE dbo.Sys_RecuperacionClave SET Anulado = 1
            WHERE Id_Usuario_FK = @usuario AND Usado IS NULL AND Anulado = 0;

            IF @propia = 1 COMMIT TRANSACTION;
        END TRY
        BEGIN CATCH
            IF @propia = 1 AND @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
            THROW;
        END CATCH

        SELECT 'OK' AS Resultado, @usuario AS Id_Usuario;
        RETURN;
    END;

    THROW 52000, 'Acción no válida.', 1;
END
GO

/* #####################################################################
   32/35  Registros\sql\SYS_Menu_Citas.sql
   ##################################################################### */
PRINT N'>> 32/35 Registros\sql\SYS_Menu_Citas.sql';
GO
/* =====================================================================
   DPieCenter - Menú Registros > Citas abre el calendario de citas

   La opción "Citas" apuntaba a la lista anterior (Registros/frm_ListaCitas.aspx). Ahora abre
   Registros/frm_CitasCalendario.aspx, desde donde se crean y editan las citas.
   Se conserva la opción (mismo Id), así que los permisos de los perfiles no cambian. Script idempotente.
   ===================================================================== */
SET NOCOUNT ON;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Sys_Opciones WHERE AccesoURL = 'Registros/frm_CitasCalendario.aspx')
	UPDATE dbo.Sys_Opciones
	   SET AccesoURL = 'Registros/frm_CitasCalendario.aspx'
	 WHERE AccesoURL = 'Registros/frm_ListaCitas.aspx';
GO

/* #####################################################################
   33/35  Opciones\sql\SYS_Menu_Publicidad.sql
   ##################################################################### */
PRINT N'>> 33/35 Opciones\sql\SYS_Menu_Publicidad.sql';
GO
/* =====================================================================
   DPieCenter - Menú Opciones > Videos de turnos (Opciones/frm_Publicidad.aspx)

   Sube, ordena y elimina los videos de la pantalla de turnos (carpeta assets/publicidad).
   Permiso inicial: Administradores. Se puede dar a otros grupos desde Perfiles.
   Script idempotente.
   ===================================================================== */
SET NOCOUNT ON;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Sys_Opciones WHERE AccesoURL = 'Opciones/frm_Publicidad.aspx')
BEGIN
	BEGIN TRANSACTION;
	DECLARE @opcion bigint, @orden int = ISNULL((SELECT MAX(Orden) FROM dbo.Sys_Opciones WHERE IdModulo_FK = 2), 0) + 1;
	INSERT INTO dbo.Sys_Opciones (Descripcion, Abreviado, AccesoURL, IdModulo_FK, Id_UsuarioCrea_FK, FechaCreacion, Orden)
	VALUES ('Videos de turnos', 'VT', 'Opciones/frm_Publicidad.aspx', 2, 'admin', GETDATE(), @orden);
	SET @opcion = SCOPE_IDENTITY();
	INSERT INTO dbo.Sys_Permisos (IdAplicativo_FK, IdModulo_FK, IdOpcion_FK, IdGrupo_FK, Id_UsuarioCrea_FK, FechaCreacion)
	SELECT 2, 2, @opcion, g.Id_Grupo, 'admin', GETDATE() FROM dbo.Sys_Grupos AS g WHERE g.Id_Grupo = 'Administradores';
	COMMIT TRANSACTION;
END
GO

/* #####################################################################
   34/35  Registros\sql\SYS_Menu_Turnos.sql
   ##################################################################### */
PRINT N'>> 34/35 Registros\sql\SYS_Menu_Turnos.sql';
GO
/* =====================================================================
   DPieCenter - Menú Registros > Pantalla de turnos (Registros/frm_TurnosPacientes.aspx)

   Antes se abría con un botón en Registros > Procedimientos. Ahora es una opción del menú;
   assets/js/principal.js la abre en otra pestaña (es una página completa para el televisor de la sala).
   Permiso inicial: los grupos que tienen Registros > Procedimientos, y Administradores.
   Script idempotente.
   ===================================================================== */
SET NOCOUNT ON;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Sys_Opciones WHERE AccesoURL = 'Registros/frm_TurnosPacientes.aspx')
BEGIN
	BEGIN TRANSACTION;
	DECLARE @opcion bigint, @orden int = ISNULL((SELECT MAX(Orden) FROM dbo.Sys_Opciones WHERE IdModulo_FK = 4), 0) + 1;
	INSERT INTO dbo.Sys_Opciones (Descripcion, Abreviado, AccesoURL, IdModulo_FK, Id_UsuarioCrea_FK, FechaCreacion, Orden)
	VALUES ('Pantalla de turnos', 'PT', 'Registros/frm_TurnosPacientes.aspx', 4, 'admin', GETDATE(), @orden);
	SET @opcion = SCOPE_IDENTITY();

	INSERT INTO dbo.Sys_Permisos (IdAplicativo_FK, IdModulo_FK, IdOpcion_FK, IdGrupo_FK, Id_UsuarioCrea_FK, FechaCreacion)
	SELECT DISTINCT p.IdAplicativo_FK, 4, @opcion, p.IdGrupo_FK, 'admin', GETDATE()
	FROM dbo.Sys_Permisos AS p INNER JOIN dbo.Sys_Opciones AS o ON o.Id_Opcion = p.IdOpcion_FK
	WHERE o.AccesoURL = 'Registros/frm_Procedimientos.aspx';

	IF NOT EXISTS (SELECT 1 FROM dbo.Sys_Permisos WHERE IdOpcion_FK = @opcion AND IdGrupo_FK = 'Administradores')
		INSERT INTO dbo.Sys_Permisos (IdAplicativo_FK, IdModulo_FK, IdOpcion_FK, IdGrupo_FK, Id_UsuarioCrea_FK, FechaCreacion)
		VALUES (2, 4, @opcion, 'Administradores', 'admin', GETDATE());
	COMMIT TRANSACTION;
END
GO

/* #####################################################################
   35/35  Registros\sql\MET_Metas.sql
   ##################################################################### */
PRINT N'>> 35/35 Registros\sql\MET_Metas.sql';
GO
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

PRINT N'>> Terminado: todos los cambios aplicados.';
