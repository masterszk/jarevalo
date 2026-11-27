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
