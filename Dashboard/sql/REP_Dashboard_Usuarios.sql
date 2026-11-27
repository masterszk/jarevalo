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
