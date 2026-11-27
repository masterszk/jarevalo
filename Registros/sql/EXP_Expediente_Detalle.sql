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
