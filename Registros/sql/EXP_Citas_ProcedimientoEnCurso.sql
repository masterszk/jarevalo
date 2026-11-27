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
