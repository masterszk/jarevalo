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
