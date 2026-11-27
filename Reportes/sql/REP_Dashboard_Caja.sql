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
