/* =====================================================================
   DPieCenter - Caja diaria por usuario (Facturacion/frm_Facturas.aspx) y anulación de DTE (Facturacion/frm_Anulaciones.aspx)

   CAJ_SP_Caja: cada usuario abre su caja del día, cobra los procedimientos finalizados (emite el DTE en frm_OpenFactura)
   y la cierra con el arqueo del efectivo. Sin caja abierta hoy no se puede emitir DTE (lo valida también DteService.Pagar).
     1 estado de la caja del usuario   2 abrir   3 resumen (totales por forma de pago)   4 cerrar   5 reabrir (administradores)
     6 procesos finalizados pendientes de cobro   7 DTE emitidos por el usuario en el día de la caja
     8 registrar entrada o salida de efectivo (@tipo E/S, con motivo)   9 movimientos de efectivo de la caja   10 anular un movimiento
     11 datos del cierre   12 último cierre del cajero
   Efectivo esperado al cerrar = fondo + cobros en efectivo + entradas - salidas.

   FAC_SP_DTE_ANULACIONES: anulación (evento de invalidación) de DTE dentro del plazo de Hacienda.
     1 lista con filtros (marca si aún está en plazo)   2 anular   3 plazos por tipo de DTE   4 guardar plazo   5 cajeros (filtro)
   Plazos iniciales (FAC_DTE_PLAZOSINVALIDACION, configurables): factura consumidor final 90 días; crédito fiscal 1 día.
   Al anular por error (tipo 1) u otro motivo (tipo 3) la factura vuelve a quedar pendiente para emitir el DTE que lo reemplaza;
   al rescindir la operación (tipo 2) la factura queda cerrada.
   Script idempotente: se puede ejecutar varias veces.
   ===================================================================== */
SET NOCOUNT ON;
GO

/* ---------- Caja: columnas del cierre ---------- */
IF COL_LENGTH('dbo.CAJ_APETURTACAJA', 'FechaCierre') IS NULL
	ALTER TABLE dbo.CAJ_APETURTACAJA ADD FechaCierre datetime NULL;
IF COL_LENGTH('dbo.CAJ_APETURTACAJA', 'EfectivoEsperado') IS NULL
	ALTER TABLE dbo.CAJ_APETURTACAJA ADD EfectivoEsperado decimal(12,2) NULL;
IF COL_LENGTH('dbo.CAJ_APETURTACAJA', 'EfectivoContado') IS NULL
	ALTER TABLE dbo.CAJ_APETURTACAJA ADD EfectivoContado decimal(12,2) NULL;
IF COL_LENGTH('dbo.CAJ_APETURTACAJA', 'Observaciones') IS NULL
	ALTER TABLE dbo.CAJ_APETURTACAJA ADD Observaciones varchar(500) NULL;
GO
-- una caja por usuario y día
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_CAJ_APETURTACAJA_Cajero_Fecha')
	CREATE UNIQUE INDEX UX_CAJ_APETURTACAJA_Cajero_Fecha ON dbo.CAJ_APETURTACAJA (Cajero, FechaApertura);
GO

/* ---------- Salidas de efectivo de la caja (gastos, pagos, depósitos…) con su motivo ---------- */
IF OBJECT_ID('dbo.CAJ_SALIDAS', 'U') IS NULL
BEGIN
	CREATE TABLE dbo.CAJ_SALIDAS (
		 Id_Salida        bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_CAJ_SALIDAS PRIMARY KEY
		,Id_Apertura_FK   bigint        NOT NULL CONSTRAINT FK_CAJ_SALIDAS_CAJA REFERENCES dbo.CAJ_APETURTACAJA (Id_Apertura)
		,Monto            decimal(12,2) NOT NULL
		,Categoria        varchar(30)   NOT NULL     -- Gasto, Pago a proveedor, Depósito bancario, Retiro, Otro
		,Motivo           varchar(250)  NOT NULL
		,Referencia       varchar(50)   NULL         -- número de factura del proveedor, boleta de depósito…
		,Estado           char(1)       NOT NULL CONSTRAINT DF_CAJ_SALIDAS_Est DEFAULT ('A')   -- A activa, X anulada
		,MotivoAnulacion  varchar(250)  NULL
		,UsuarioCrea      varchar(20)   NOT NULL
		,FechaCrea        datetime      NOT NULL CONSTRAINT DF_CAJ_SALIDAS_Fec DEFAULT (GETDATE())
		,UsuarioModifica  varchar(20)   NULL
		,FechaModifica    datetime      NULL
	);
	CREATE INDEX IX_CAJ_SALIDAS_CAJA ON dbo.CAJ_SALIDAS (Id_Apertura_FK);
END
GO
IF COL_LENGTH('dbo.CAJ_APETURTACAJA', 'Salidas') IS NULL
	ALTER TABLE dbo.CAJ_APETURTACAJA ADD Salidas decimal(12,2) NULL;
GO
/* Manejo de efectivo: la misma tabla guarda entradas (E: reposición de fondo, cambio…) y salidas (S) */
IF COL_LENGTH('dbo.CAJ_SALIDAS', 'Tipo') IS NULL
	ALTER TABLE dbo.CAJ_SALIDAS ADD Tipo char(1) NOT NULL CONSTRAINT DF_CAJ_SALIDAS_Tipo DEFAULT ('S');
IF COL_LENGTH('dbo.CAJ_APETURTACAJA', 'Entradas') IS NULL
	ALTER TABLE dbo.CAJ_APETURTACAJA ADD Entradas decimal(12,2) NULL;
GO

/* ---------- Plazos de invalidación por tipo de DTE ---------- */
IF OBJECT_ID('dbo.FAC_DTE_PLAZOSINVALIDACION', 'U') IS NULL
BEGIN
	CREATE TABLE dbo.FAC_DTE_PLAZOSINVALIDACION (
		 TipoDte         char(2)      NOT NULL CONSTRAINT PK_FAC_DTE_PLAZOSINVALIDACION PRIMARY KEY
		,Descripcion     varchar(100) NOT NULL
		,Dias            int          NOT NULL
		,UsuarioModifica varchar(20)  NULL
		,FechaModifica   datetime     NULL
	);
	INSERT INTO dbo.FAC_DTE_PLAZOSINVALIDACION (TipoDte, Descripcion, Dias) VALUES
		('01', 'Factura (consumidor final)', 90),
		('03', 'Comprobante de crédito fiscal', 1);
END
GO

/* ---------- Eventos de invalidación ---------- */
IF OBJECT_ID('dbo.FAC_DTE_INVALIDACIONES', 'U') IS NULL
BEGIN
	CREATE TABLE dbo.FAC_DTE_INVALIDACIONES (
		 Id_Invalidacion     bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_FAC_DTE_INVALIDACIONES PRIMARY KEY
		,Id_Dte_FK           bigint        NOT NULL CONSTRAINT FK_FAC_DTE_INVALIDACIONES_DTE REFERENCES dbo.FAC_DTE_DOCUMENTOS (Id_Dte)
		,CodigoGeneracion    char(36)      NOT NULL     -- del evento de invalidación
		,FechaAnulacion      datetime      NOT NULL
		,TipoAnulacion       tinyint       NOT NULL     -- 1 error en la información, 2 rescindir la operación, 3 otro
		,Motivo              varchar(250)  NULL
		,NombreResponsable   varchar(100)  NOT NULL
		,TipoDocResponsable  char(2)       NOT NULL
		,NumDocResponsable   varchar(20)   NOT NULL
		,NombreSolicita      varchar(100)  NOT NULL
		,TipoDocSolicita     char(2)       NOT NULL
		,NumDocSolicita      varchar(20)   NOT NULL
		,JsonEvento          nvarchar(max) NOT NULL
		,SelloRecepcion      varchar(100)  NULL
		,Estado              char(1)       NOT NULL CONSTRAINT DF_FAC_DTE_INVALIDACIONES_Est DEFAULT ('G')   -- G generado, T transmitido
		,UsuarioCrea         varchar(20)   NOT NULL
		,FechaCrea           datetime      NOT NULL CONSTRAINT DF_FAC_DTE_INVALIDACIONES_Fec DEFAULT (GETDATE())
	);
	CREATE UNIQUE INDEX UX_FAC_DTE_INVALIDACIONES_DTE ON dbo.FAC_DTE_INVALIDACIONES (Id_Dte_FK);
END
GO

/* =====================================================================
   CAJ_SP_Caja
   ===================================================================== */
CREATE OR ALTER PROCEDURE dbo.CAJ_SP_Caja
	 @accion     int
	,@cajero     varchar(20)
	,@id         bigint        = 0
	,@monto      decimal(12,2) = 0
	,@texto      nvarchar(100) = NULL
	,@desde      date          = NULL
	,@hasta      date          = NULL
	,@observaciones varchar(500) = NULL
	,@categoria  varchar(30)   = NULL
	,@referencia varchar(50)   = NULL
	,@sucursal   int           = 0      -- sucursal de la sesión: la caja se abre en ella y solo ve sus pendientes (0 = todas)
	,@tipo       char(1)       = 'S'    -- acción 8: E entrada de efectivo, S salida
AS
BEGIN
	SET NOCOUNT ON;
	declare @hoy date = CAST(GETDATE() as date)
	set @texto = NULLIF(LTRIM(RTRIM(@texto)), '')
	set @observaciones = NULLIF(LTRIM(RTRIM(@observaciones)), '')
	set @referencia = NULLIF(LTRIM(RTRIM(@referencia)), '')

	/* 1: caja del usuario hoy y, si la tiene, la caja de un día anterior que quedó abierta */
	if @accion = 1
	begin
		select top 1 Id_Apertura, FechaApertura, CAST(MontoApertura as decimal(12,2)) as MontoApertura, Estatus as Abierta
			,FechaCrea as FechaApertura2, FechaCierre, EfectivoEsperado, EfectivoContado
			,CAST(Sobrante as decimal(12,2)) as Sobrante, CAST(Faltante as decimal(12,2)) as Faltante, Observaciones
			,case when FechaApertura < @hoy then 1 else 0 end as Anterior
		from CAJ_APETURTACAJA
		where Cajero = @cajero and (FechaApertura = @hoy or (Estatus = 1 and FechaApertura < @hoy))
		order by case when Estatus = 1 and FechaApertura < @hoy then 0 else 1 end, FechaApertura desc
		return
	end

	/* 2: abrir la caja de hoy */
	if @accion = 2
	begin
		if @monto < 0 or @monto > 10000 THROW 50400, 'El fondo de caja debe estar entre 0 y 10,000.', 1;
		if exists (select 1 from CAJ_APETURTACAJA where Cajero = @cajero and Estatus = 1 and FechaApertura < @hoy)
			THROW 50401, 'Tiene abierta la caja de un día anterior. Ciérrela antes de abrir la de hoy.', 1;
		if exists (select 1 from CAJ_APETURTACAJA where Cajero = @cajero and FechaApertura = @hoy)
			THROW 50402, 'Ya abrió su caja hoy.', 1;
		insert into CAJ_APETURTACAJA (FechaApertura, MontoApertura, Sobrante, Faltante, Cajero, Estatus, UsuarioCrea, FechaCrea, Id_Sucursal_FK)
		values (@hoy, @monto, 0, 0, @cajero, 1, @cajero, GETDATE(), ISNULL(NULLIF(@sucursal, 0), dbo.SUC_FN_Matriz()))
		select CAST(SCOPE_IDENTITY() as bigint) as Id
		return
	end

	/* 3: resumen de la caja: DTE vigentes emitidos por el cajero ese día, por forma de pago */
	if @accion = 3
	begin
		declare @fecha date, @fondo decimal(12,2)
		select @fecha = FechaApertura, @fondo = MontoApertura from CAJ_APETURTACAJA where Id_Apertura = @id and Cajero = @cajero
		if @fecha is null THROW 50403, 'La caja no existe.', 1;

		-- por línea de pago (FAC_DTE_Pagos.sql): un pago combinado suma en cada forma su parte
		select ISNULL(fp.Descripcion, p.FormaPago) as FormaPago, p.FormaPago as Codigo, COUNT(distinct d.Id_Dte) as Documentos, SUM(p.Monto) as Total
		from FAC_DTE_DOCUMENTOS as d
			inner join FAC_VW_DTE_PAGOS as p on p.Id_Dte = d.Id_Dte
			left join CAT_FORMASPAGO as fp on fp.Codigo = p.FormaPago
		where d.UsuarioCrea = @cajero and d.FechaEmision = @fecha and d.Estado <> 'A'
		group by fp.Descripcion, p.FormaPago
		order by p.FormaPago

		select @fondo as Fondo
			,dbo.FAC_FN_EfectivoCajero(@cajero, @fecha) as Efectivo
			,ISNULL((select SUM(TotalPagar) from FAC_DTE_DOCUMENTOS where UsuarioCrea = @cajero and FechaEmision = @fecha and Estado <> 'A'), 0) as Total
			,(select COUNT(*) from FAC_DTE_DOCUMENTOS where UsuarioCrea = @cajero and FechaEmision = @fecha and Estado <> 'A') as Documentos
			,(select COUNT(*) from FAC_DTE_DOCUMENTOS where UsuarioCrea = @cajero and FechaEmision = @fecha and Estado = 'A') as Anulados
			,ISNULL((select SUM(Monto) from CAJ_SALIDAS where Id_Apertura_FK = @id and Estado = 'A' and Tipo = 'S'), 0) as Salidas
			,(select COUNT(*) from CAJ_SALIDAS where Id_Apertura_FK = @id and Estado = 'A' and Tipo = 'S') as CantidadSalidas
			,ISNULL((select SUM(Monto) from CAJ_SALIDAS where Id_Apertura_FK = @id and Estado = 'A' and Tipo = 'E'), 0) as Entradas
			,(select COUNT(*) from CAJ_SALIDAS where Id_Apertura_FK = @id and Estado = 'A' and Tipo = 'E') as CantidadEntradas
			,(select COUNT(*) from CAJ_TICKETS where Id_Apertura_FK = @id) as Tickets
		return
	end

	/* 4: cerrar la caja con el arqueo (@monto = efectivo contado) */
	if @accion = 4
	begin
		declare @f date, @fon decimal(12,2), @abierta bit
		select @f = FechaApertura, @fon = MontoApertura, @abierta = Estatus from CAJ_APETURTACAJA where Id_Apertura = @id and Cajero = @cajero
		if @f is null THROW 50403, 'La caja no existe.', 1;
		if @abierta = 0 THROW 50404, 'La caja ya está cerrada.', 1;
		if @monto < 0 THROW 50405, 'El efectivo contado no puede ser negativo.', 1;

		declare @salidasCaja decimal(12,2) = ISNULL((select SUM(Monto) from CAJ_SALIDAS where Id_Apertura_FK = @id and Estado = 'A' and Tipo = 'S'), 0)
		declare @entradasCaja decimal(12,2) = ISNULL((select SUM(Monto) from CAJ_SALIDAS where Id_Apertura_FK = @id and Estado = 'A' and Tipo = 'E'), 0)
		declare @esperado decimal(12,2) = @fon + @entradasCaja - @salidasCaja + dbo.FAC_FN_EfectivoCajero(@cajero, @f)
		update CAJ_APETURTACAJA set
			 Estatus = 0, FechaCierre = GETDATE(), EfectivoEsperado = @esperado, EfectivoContado = @monto, Salidas = @salidasCaja, Entradas = @entradasCaja
			,Sobrante = case when @monto > @esperado then @monto - @esperado else 0 end
			,Faltante = case when @monto < @esperado then @esperado - @monto else 0 end
			,Observaciones = NULLIF(LTRIM(RTRIM(@observaciones)), '')
			,UsuarioModifica = @cajero, FechaModifica = GETDATE()
		where Id_Apertura = @id
		select @id as Id
		return
	end

	/* 5: reabrir una caja cerrada de hoy (la aplicación solo lo permite a administradores; @cajero = dueño de la caja) */
	if @accion = 5
	begin
		if not exists (select 1 from CAJ_APETURTACAJA where Id_Apertura = @id and Estatus = 0 and FechaApertura = @hoy)
			THROW 50406, 'Solo se puede reabrir una caja cerrada del día de hoy.', 1;
		update CAJ_APETURTACAJA set Estatus = 1, FechaCierre = NULL, EfectivoEsperado = NULL, EfectivoContado = NULL
			,Sobrante = 0, Faltante = 0, UsuarioModifica = @cajero, FechaModifica = GETDATE()
		where Id_Apertura = @id
		select @id as Id
		return
	end

	/* 6: procesos finalizados pendientes de cobro */
	if @accion = 6
	begin
		declare @fin date = DATEADD(DAY, 1, @hasta)
		select f.Id_factura, f.FechaFactura, p.Fecha as FechaProcedimiento, p.FinalProcedimiento
			,e.Id_Expediente, LTRIM(RTRIM(e.Nombres + ' ' + e.Apellidos)) as Paciente, ISNULL(e.Documento, '') as Documento
			,ISNULL(e.Celular, '') as Celular, ISNULL(s.Descripcion, '') as Especialista
			-- total a cobrar: con el descuento vigente de cada tratamiento (CAT_TRATAMIENTOS.Descuento)
			,ISNULL((select SUM(d.Valor - ROUND(d.Valor * ISNULL(ct.Descuento, 0) / 100, 2)) from CAJ_FACTURASDETALLES as d
					 left join CAT_TRATAMIENTOS as ct on ct.Id_Tratamientos = d.Id_tratamiento_FK
					 where d.Id_Factura_FK = f.Id_factura), 0) as Total
			,ISNULL(STUFF((select ', ' + d.Descripion from CAJ_FACTURASDETALLES as d where d.Id_Factura_FK = f.Id_factura
				for xml path(''), type).value('.', 'nvarchar(max)'), 1, 2, ''), '') as Servicios
			,case when exists (select 1 from FAC_DTE_DOCUMENTOS as x where x.Id_Factura_FK = f.Id_factura and x.Estado = 'A') then 1 else 0 end as Reemplazo
		from CAJ_FACTURAS as f
			inner join EXP_PROCEDIMIENTOS as p on p.Id_Procedimiento = f.Id_Procedimiento_FK and p.Estado = 'F'
			inner join EXP_EXPEDIENTES as e on e.Id_Expediente = f.Id_Expediente_FK
			left join CAT_ESPECIALISTAS as s on s.Id_Especialista = p.Id_Especialista_fk
		where f.Estado = 0
			and (@sucursal = 0 or f.Id_Sucursal_FK = @sucursal)
			and (@desde is null or f.FechaFactura >= @desde)
			and (@hasta is null or f.FechaFactura < @fin)
			and (@texto is null or e.Nombres + ' ' + e.Apellidos like '%' + @texto + '%' or e.Documento like '%' + @texto + '%'
				 or e.Celular like '%' + @texto + '%' or CAST(f.Id_factura as varchar(20)) = @texto)
		order by f.FechaFactura desc, f.Id_factura desc
		return
	end

	/* 7: DTE emitidos por el cajero en el día de la caja */
	if @accion = 7
	begin
		declare @dia date = (select FechaApertura from CAJ_APETURTACAJA where Id_Apertura = @id and Cajero = @cajero)
		select d.Id_Dte, d.Id_Factura_FK, d.TipoDte, d.NumeroControl, d.CodigoGeneracion, d.HoraEmision, d.ReceptorNombre
			,d.TotalPagar, d.FormaPago, dbo.FAC_FN_FormasPagoTexto(d.Id_Dte) as FormaPagoTexto, d.Estado, d.RutaPdf
		from FAC_DTE_DOCUMENTOS as d
		where d.UsuarioCrea = @cajero and d.FechaEmision = @dia
		union all   -- tickets POS de servicios sin costo (CAJ_Tickets.sql): TipoDte 'TK', Estado 'K'
		select t.Id_Ticket, t.Id_Factura_FK, 'TK', t.Numero, '', CAST(t.FechaCrea as time), t.Paciente
			,t.Total, '', 'Sin costo', 'K', NULL
		from CAJ_TICKETS as t
		where t.Id_Apertura_FK = @id and t.UsuarioCrea = @cajero
		order by 6 desc
		return
	end

	/* 8: entrada (@tipo E) o salida (@tipo S) de efectivo en la caja abierta de hoy (@monto, @categoria, @observaciones = motivo, @referencia) */
	if @accion = 8
	begin
		declare @dSal date, @fondoSal decimal(12,2), @abiertaSal bit
		select @dSal = FechaApertura, @fondoSal = MontoApertura, @abiertaSal = Estatus from CAJ_APETURTACAJA with (updlock, holdlock)
		where Id_Apertura = @id and Cajero = @cajero
		set @tipo = UPPER(ISNULL(@tipo, 'S'))
		if @tipo not in ('E', 'S') THROW 50427, 'Indique si es entrada o salida de efectivo.', 1;
		if @dSal is null THROW 50403, 'La caja no existe.', 1;
		if @abiertaSal = 0 or @dSal <> @hoy THROW 50407, 'Solo se puede registrar efectivo en su caja abierta de hoy.', 1;
		if @monto <= 0 THROW 50408, 'Ingrese el monto.', 1;
		if @tipo = 'S' and ISNULL(@categoria, '') not in ('Gasto', 'Pago a proveedor', 'Depósito bancario', 'Retiro', 'Otro') THROW 50409, 'Seleccione el tipo de salida.', 1;
		if @tipo = 'E' and ISNULL(@categoria, '') not in ('Reposición de fondo', 'Cambio (sencillo)', 'Préstamo', 'Otro') THROW 50409, 'Seleccione el tipo de entrada.', 1;
		if @observaciones is null or LEN(@observaciones) < 5 THROW 50421, 'Describa el motivo (al menos 5 caracteres).', 1;
		if LEN(@observaciones) > 250 THROW 50422, 'El motivo no puede tener más de 250 caracteres.', 1;

		-- no se puede sacar más efectivo del que hay: fondo + cobros en efectivo + entradas - salidas anteriores
		if @tipo = 'S'
		begin
			declare @disponible decimal(12,2) = @fondoSal
				+ dbo.FAC_FN_EfectivoCajero(@cajero, @dSal)
				+ ISNULL((select SUM(case when Tipo = 'E' then Monto else -Monto end) from CAJ_SALIDAS where Id_Apertura_FK = @id and Estado = 'A'), 0)
			if @monto > @disponible
			begin
				declare @msg nvarchar(200) = N'No hay suficiente efectivo en la caja. Disponible: $' + CONVERT(nvarchar(20), @disponible) + N'.';
				THROW 50423, @msg, 1;
			end
		end

		insert into CAJ_SALIDAS (Id_Apertura_FK, Tipo, Monto, Categoria, Motivo, Referencia, Estado, UsuarioCrea, FechaCrea)
		values (@id, @tipo, @monto, @categoria, @observaciones, @referencia, 'A', @cajero, GETDATE())
		select CAST(SCOPE_IDENTITY() as bigint) as Id
		return
	end

	/* 9: movimientos de efectivo de la caja (entradas y salidas) */
	if @accion = 9
	begin
		select s.Id_Salida, s.Tipo, s.Monto, s.Categoria, s.Motivo, s.Referencia, s.Estado, s.MotivoAnulacion, s.UsuarioCrea, s.FechaCrea, s.UsuarioModifica, s.FechaModifica
		from CAJ_SALIDAS as s
			inner join CAJ_APETURTACAJA as c on c.Id_Apertura = s.Id_Apertura_FK
		where s.Id_Apertura_FK = @id and c.Cajero = @cajero
		order by s.FechaCrea desc
		return
	end

	/* 10: anular una salida registrada por error (@texto = id de la salida, @observaciones = motivo de la anulación) */
	if @accion = 10
	begin
		declare @idSalida bigint = TRY_CONVERT(bigint, @texto)
		if not exists (select 1 from CAJ_SALIDAS as s inner join CAJ_APETURTACAJA as c on c.Id_Apertura = s.Id_Apertura_FK
					   where s.Id_Salida = @idSalida and c.Cajero = @cajero and s.Estado = 'A')
			THROW 50424, 'El movimiento no existe o ya fue anulado.', 1;
		if not exists (select 1 from CAJ_SALIDAS as s inner join CAJ_APETURTACAJA as c on c.Id_Apertura = s.Id_Apertura_FK
					   where s.Id_Salida = @idSalida and c.Estatus = 1 and c.FechaApertura = @hoy)
			THROW 50425, 'Solo se pueden anular movimientos de la caja abierta de hoy.', 1;
		if @observaciones is null or LEN(@observaciones) < 5 THROW 50426, 'Indique por qué anula el movimiento (al menos 5 caracteres).', 1;
		-- anular una entrada quita ese efectivo: no puede dejar la caja en negativo
		if exists (select 1 from CAJ_SALIDAS where Id_Salida = @idSalida and Tipo = 'E')
		begin
			declare @idCajaMov bigint, @diaMov date, @fondoMov decimal(12,2)
			select @idCajaMov = c.Id_Apertura, @diaMov = c.FechaApertura, @fondoMov = c.MontoApertura
			from CAJ_SALIDAS as s inner join CAJ_APETURTACAJA as c on c.Id_Apertura = s.Id_Apertura_FK where s.Id_Salida = @idSalida
			if @fondoMov
				+ dbo.FAC_FN_EfectivoCajero(@cajero, @diaMov)
				+ ISNULL((select SUM(case when Tipo = 'E' then Monto else -Monto end) from CAJ_SALIDAS where Id_Apertura_FK = @idCajaMov and Estado = 'A' and Id_Salida <> @idSalida), 0) < 0
				THROW 50428, 'No se puede anular la entrada: ese efectivo ya salió de la caja. Anule antes la salida correspondiente.', 1;
		end
		update CAJ_SALIDAS set Estado = 'X', MotivoAnulacion = LEFT(@observaciones, 250), UsuarioModifica = @cajero, FechaModifica = GETDATE()
		where Id_Salida = @idSalida
		select @idSalida as Id
		return
	end;

	/* 11: datos del cierre de la caja (se muestran al cerrar). Cada usuario tiene su caja: solo cuenta lo cobrado en ESTA caja
	       (DTE vigentes que emitió el cajero ese día y tickets de la apertura); no se mezclan cobros de otros usuarios ni de otras cajas.
	       Los procedimientos finalizados del día sin facturar en la sucursal solo se informan como alerta: no bloquean el cierre.
	       1er resultado: totales de la caja y conteo de pendientes   2do resultado: pendientes de facturar */
	if @accion = 11
	begin
		declare @dC date, @sucC int
		select @dC = FechaApertura, @sucC = Id_Sucursal_FK from CAJ_APETURTACAJA where Id_Apertura = @id and Cajero = @cajero
		if @dC is null THROW 50403, 'La caja no existe.', 1;

		-- cobros de esta caja
		declare @dteCaja table (Id_Dte bigint primary key, Total decimal(12,2) not null)
		insert @dteCaja
		select Id_Dte, ISNULL(TotalPagar, 0) from FAC_DTE_DOCUMENTOS where UsuarioCrea = @cajero and FechaEmision = @dC and Estado <> 'A'

		declare @documentos int = (select COUNT(*) from @dteCaja) + (select COUNT(*) from CAJ_TICKETS where Id_Apertura_FK = @id)
		declare @cajaTotal decimal(12,2) = ISNULL((select SUM(Total) from @dteCaja), 0) + ISNULL((select SUM(Total) from CAJ_TICKETS where Id_Apertura_FK = @id), 0)
		-- descuentos dados en los documentos de esta caja: por tratamiento (catálogo) y por cupón
		declare @descTrat decimal(12,2), @descCupon decimal(12,2), @cupones int
		-- en el crédito fiscal (03) el descuento del DTE es sin IVA: se lleva a IVA incluido para que cuadre con lo cobrado
		select @descTrat = ISNULL(SUM(ROUND(ISNULL(x.DescuentoTratamiento, 0) * case when d.TipoDte = '03' then 1.13 else 1 end, 2)), 0)
			,@descCupon = ISNULL(SUM(ROUND(ISNULL(x.DescuentoCupon, 0) * case when d.TipoDte = '03' then 1.13 else 1 end, 2)), 0)
		from FAC_DTE_DETALLES as x inner join FAC_DTE_DOCUMENTOS as d on d.Id_Dte = x.Id_Dte_FK
		where x.Id_Dte_FK in (select Id_Dte from @dteCaja)
		select @cupones = COUNT(distinct x.Id_Dte_FK) from FAC_DTE_DETALLES as x
		where x.Id_Dte_FK in (select Id_Dte from @dteCaja) and x.DescuentoCupon > 0
		declare @descuentos decimal(12,2) = @descTrat + @descCupon

		-- alerta: procedimientos finalizados ese día en la sucursal de la caja que aún no se facturan (de cualquier cajero)
		declare @pend table (Id_Procedimiento bigint primary key, Id_Factura bigint null, Valor decimal(12,2) not null
			,Final datetime null, Paciente nvarchar(300) null, Especialista nvarchar(200) null, Servicios nvarchar(max) null)
		insert @pend
		select p.Id_Procedimiento, f.Id_factura
			-- lo que se espera cobrar: con el descuento vigente de cada tratamiento
			,ISNULL(case when f.Id_factura is not null
						 then (select SUM(d.Valor - ROUND(d.Valor * ISNULL(ct.Descuento, 0) / 100, 2))
							   from CAJ_FACTURASDETALLES as d left join CAT_TRATAMIENTOS as ct on ct.Id_Tratamientos = d.Id_tratamiento_FK
							   where d.Id_Factura_FK = f.Id_factura)
						 else (select SUM(x.Valor - ROUND(x.Valor * ISNULL(ct.Descuento, 0) / 100, 2))
							   from EXP_PROCEDIMIENTOSTRATAMIENTOS as x left join CAT_TRATAMIENTOS as ct on ct.Id_Tratamientos = x.Id_Tratamiento_FK
							   where x.Id_Procedimiento_FK = p.Id_Procedimiento) end, 0)
			,p.FinalProcedimiento
			,LTRIM(RTRIM(ISNULL(e.Nombres, '') + ' ' + ISNULL(e.Apellidos, '')))
			,ISNULL(s.Descripcion, '')
			,ISNULL(STUFF((select ', ' + t.Descripcion from EXP_PROCEDIMIENTOSTRATAMIENTOS as t where t.Id_Procedimiento_FK = p.Id_Procedimiento
				for xml path(''), type).value('.', 'nvarchar(max)'), 1, 2, ''), '')
		from EXP_PROCEDIMIENTOS as p
			outer apply (select top 1 Id_factura, Estado from CAJ_FACTURAS where Id_Procedimiento_FK = p.Id_Procedimiento order by Id_factura desc) as f
			left join EXP_EXPEDIENTES as e on e.Id_Expediente = p.Id_Expediente_fk
			left join CAT_ESPECIALISTAS as s on s.Id_Especialista = p.Id_Especialista_fk
		where p.Estado = 'F' and p.Fecha = @dC and (@sucC is null or p.Id_Sucursal_FK = @sucC)
			and ISNULL(f.Estado, 0) = 0

		select @dC as Fecha
			,@documentos as Documentos
			,@cajaTotal as CajaTotal
			,@descuentos as Descuentos
			,@descTrat as DescuentoTratamientos
			,@descCupon as DescuentoCupones
			,@cupones as Cupones
			-- antes de descuentos: lo que valían los servicios cobrados en esta caja
			,@cajaTotal + @descuentos as ValorServicios
			,(select COUNT(*) from @pend) as Pendientes
			,ISNULL((select SUM(Valor) from @pend), 0) as ValorPendientes

		select Id_Procedimiento, ISNULL(Id_Factura, 0) as Id_Factura, Final, Paciente, Especialista, Servicios, Valor
		from @pend
		order by Final, Id_Procedimiento
		return
	end;

	/* 12: último cierre del cajero (efectivo contado): se propone como fondo al abrir la caja siguiente */
	if @accion = 12
	begin
		select top 1 Id_Apertura, FechaApertura, FechaCierre, EfectivoContado
		from CAJ_APETURTACAJA
		where Cajero = @cajero and Estatus = 0 and EfectivoContado is not null
		order by FechaCierre desc, Id_Apertura desc
		return
	end;

	THROW 50499, 'Acción no válida.', 1;
END
GO

/* =====================================================================
   FAC_SP_DTE_ANULACIONES
   ===================================================================== */
CREATE OR ALTER PROCEDURE dbo.FAC_SP_DTE_ANULACIONES
	 @accion        int
	,@usuario       varchar(20)   = NULL
	,@id            bigint        = 0
	,@desde         date          = NULL
	,@hasta         date          = NULL
	,@tipoDte       char(2)       = NULL
	,@cajero        varchar(20)   = NULL
	,@texto         nvarchar(100) = NULL
	,@vista         varchar(10)   = 'plazo'     -- plazo: anulables | anulados | todos
	,@tipoAnulacion tinyint       = 0
	,@motivo        varchar(250)  = NULL
	,@nombreResponsable  varchar(100) = NULL
	,@tipoDocResponsable char(2)      = NULL
	,@numDocResponsable  varchar(20)  = NULL
	,@nombreSolicita     varchar(100) = NULL
	,@tipoDocSolicita    char(2)      = NULL
	,@numDocSolicita     varchar(20)  = NULL
	,@codigoEvento       char(36)     = NULL
	,@json               nvarchar(max) = NULL
	,@dias               int          = 0
	,@sucursal           int          = 0     -- lista: solo los DTE de esa sucursal (0 = todas)
AS
BEGIN
	SET NOCOUNT ON;
	declare @hoy date = CAST(GETDATE() as date)
	set @texto = NULLIF(LTRIM(RTRIM(@texto)), '')
	set @cajero = NULLIF(LTRIM(RTRIM(@cajero)), '')
	set @tipoDte = NULLIF(LTRIM(RTRIM(@tipoDte)), '')
	set @motivo = NULLIF(LTRIM(RTRIM(@motivo)), '')

	/* 1: lista */
	if @accion = 1
	begin
		declare @fin date = DATEADD(DAY, 1, @hasta)
		;with docs as (
			select d.Id_Dte, d.Id_Factura_FK, d.TipoDte, d.NumeroControl, d.CodigoGeneracion, d.FechaEmision, d.HoraEmision
				,d.ReceptorNombre, ISNULL(d.ReceptorDocumento, '') as ReceptorDocumento, d.TotalIva, d.TotalPagar
				,d.FormaPago, d.Estado, d.SelloRecepcion, d.RutaPdf, d.UsuarioCrea as Cajero, d.Ambiente
				,ISNULL(pl.Dias, 0) as DiasPlazo
				,DATEADD(DAY, ISNULL(pl.Dias, 0), d.FechaEmision) as VencePlazo
				,i.FechaAnulacion, i.TipoAnulacion, i.Motivo, i.UsuarioCrea as AnuladoPor
			from FAC_DTE_DOCUMENTOS as d
				left join FAC_DTE_PLAZOSINVALIDACION as pl on pl.TipoDte = d.TipoDte
				left join FAC_DTE_INVALIDACIONES as i on i.Id_Dte_FK = d.Id_Dte
			where (@desde is null or d.FechaEmision >= @desde)
				and (@hasta is null or d.FechaEmision < @fin)
				and (@sucursal = 0 or d.Id_Sucursal_FK = @sucursal)
				and (@tipoDte is null or d.TipoDte = @tipoDte)
				and (@cajero is null or d.UsuarioCrea = @cajero)
				and (@texto is null or d.ReceptorNombre like '%' + @texto + '%' or d.ReceptorDocumento like '%' + @texto + '%'
					 or d.NumeroControl like '%' + @texto + '%' or d.CodigoGeneracion like '%' + @texto + '%'
					 or CAST(d.Id_Factura_FK as varchar(20)) = @texto)
		)
		select *, CAST(case when Estado <> 'A' and VencePlazo >= @hoy then 1 else 0 end as bit) as EnPlazo
			,DATEDIFF(DAY, @hoy, VencePlazo) as DiasRestantes
		from docs
		where (@vista = 'todos')
			or (@vista = 'anulados' and Estado = 'A')
			or (@vista = 'plazo' and Estado <> 'A' and VencePlazo >= @hoy)
		order by FechaEmision desc, HoraEmision desc
		return
	end

	/* 2: anular (el JSON del evento lo arma la aplicación) */
	if @accion = 2
	begin
		declare @tipo char(2), @emision date, @estado char(1), @factura bigint, @plazo int
		select @tipo = d.TipoDte, @emision = d.FechaEmision, @estado = d.Estado, @factura = d.Id_Factura_FK, @plazo = pl.Dias
		from FAC_DTE_DOCUMENTOS as d with (updlock, holdlock)
			left join FAC_DTE_PLAZOSINVALIDACION as pl on pl.TipoDte = d.TipoDte
		where d.Id_Dte = @id

		if @tipo is null THROW 50410, 'El documento no existe.', 1;
		if @estado = 'A' THROW 50411, 'El documento ya está anulado.', 1;
		if @plazo is null THROW 50412, 'No hay plazo de anulación configurado para este tipo de documento.', 1;
		if DATEADD(DAY, @plazo, @emision) < @hoy
			THROW 50413, 'El plazo para anular este documento ya venció. Debe emitirse una nota de crédito.', 1;
		if @tipoAnulacion not in (1, 2, 3) THROW 50414, 'Seleccione el tipo de anulación.', 1;
		if @tipoAnulacion = 3 and (@motivo is null or LEN(@motivo) < 5) THROW 50415, 'Describa el motivo de la anulación (al menos 5 caracteres).', 1;
		if NULLIF(LTRIM(RTRIM(@nombreResponsable)), '') is null or NULLIF(LTRIM(RTRIM(@numDocResponsable)), '') is null
			THROW 50416, 'Ingrese el nombre y documento del responsable de la anulación.', 1;
		if NULLIF(LTRIM(RTRIM(@nombreSolicita)), '') is null or NULLIF(LTRIM(RTRIM(@numDocSolicita)), '') is null
			THROW 50417, 'Ingrese el nombre y documento de quien solicita la anulación.', 1;
		if @json is null or @codigoEvento is null THROW 50418, 'No se generó el evento de invalidación.', 1;

		begin transaction
			insert into FAC_DTE_INVALIDACIONES (Id_Dte_FK, CodigoGeneracion, FechaAnulacion, TipoAnulacion, Motivo
				,NombreResponsable, TipoDocResponsable, NumDocResponsable, NombreSolicita, TipoDocSolicita, NumDocSolicita
				,JsonEvento, UsuarioCrea, FechaCrea)
			values (@id, @codigoEvento, GETDATE(), @tipoAnulacion, @motivo
				,LTRIM(RTRIM(@nombreResponsable)), @tipoDocResponsable, LTRIM(RTRIM(@numDocResponsable))
				,LTRIM(RTRIM(@nombreSolicita)), @tipoDocSolicita, LTRIM(RTRIM(@numDocSolicita))
				,@json, @usuario, GETDATE())

			update FAC_DTE_DOCUMENTOS set Estado = 'A', UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_Dte = @id

			-- por error u otro motivo se debe emitir otro DTE: la factura vuelve a quedar pendiente de cobro
			if @tipoAnulacion in (1, 3)
				update CAJ_FACTURAS set Estado = 0, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_factura = @factura
		commit transaction

		select @id as Id
		return
	end

	/* 3: plazos */
	if @accion = 3
	begin
		select TipoDte, Descripcion, Dias, UsuarioModifica, FechaModifica from FAC_DTE_PLAZOSINVALIDACION order by TipoDte
		return
	end

	/* 4: guardar plazo */
	if @accion = 4
	begin
		if @dias < 0 or @dias > 365 THROW 50419, 'El plazo debe estar entre 0 y 365 días.', 1;
		update FAC_DTE_PLAZOSINVALIDACION set Dias = @dias, UsuarioModifica = @usuario, FechaModifica = GETDATE() where TipoDte = @tipoDte
		if @@ROWCOUNT = 0 THROW 50420, 'Tipo de documento no válido.', 1;
		select CAST(0 as bigint) as Id
		return
	end

	/* 5: cajeros que han emitido DTE */
	if @accion = 5
	begin
		select distinct d.UsuarioCrea as Cajero, LTRIM(RTRIM(ISNULL(u.Nombres, '') + ' ' + ISNULL(u.Apellidos, ''))) as Nombre
		from FAC_DTE_DOCUMENTOS as d left join Sys_Usuarios as u on u.Id_Usuario = d.UsuarioCrea
		order by 2
		return
	end;

	THROW 50499, 'Acción no válida.', 1;
END
GO
