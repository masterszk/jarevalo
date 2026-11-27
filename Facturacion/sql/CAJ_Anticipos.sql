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
