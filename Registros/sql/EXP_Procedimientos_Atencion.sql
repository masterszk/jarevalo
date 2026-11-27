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
