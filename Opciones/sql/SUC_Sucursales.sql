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
