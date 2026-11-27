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
