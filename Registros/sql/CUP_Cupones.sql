/* =====================================================================
   DPieCenter - Cupones de descuento con código QR (Registros/frm_ListaCupones.aspx) que se aplican en caja
   (Facturacion/frm_OpenFactura.aspx) al escanear el QR.

   El QR solo contiene el código del cupón (DPC- + 8 letras al azar): no se puede adivinar ni armar a mano.
   El porcentaje por defecto (10 %), los días de vigencia, el porcentaje máximo y el texto del cupón se configuran
   en FAC_CUPONES_CONFIG. Cada cupón guarda su propio porcentaje.
   Un cupón puede ser para un paciente (o para quien lo presente) y para un tratamiento (o para toda la factura).
   Estado: P pendiente, U usado, A anulado (vencido = pendiente con FechaVence pasada).

   CUP_SP_Cupones
     1 lista   2 crear   3 anular   4 configuración   5 guardar configuración   6 detalle (para imprimir)
     7 aplicar a una factura   8 quitar de la factura   9 marcar usado (dentro de la transacción del pago)
     10 cupón aplicado a una factura   11 resumen
   Script idempotente: se puede ejecutar varias veces.
   ===================================================================== */
SET NOCOUNT ON;
GO

/* ---------- Configuración ---------- */
IF OBJECT_ID('dbo.FAC_CUPONES_CONFIG', 'U') IS NULL
BEGIN
	CREATE TABLE dbo.FAC_CUPONES_CONFIG (
		 Id_Config          int           NOT NULL CONSTRAINT PK_FAC_CUPONES_CONFIG PRIMARY KEY
		,PorcentajeDefecto  decimal(5,2)  NOT NULL
		,PorcentajeMaximo   decimal(5,2)  NOT NULL
		,DiasVigencia       int           NOT NULL
		,Leyenda            varchar(250)  NULL
		,UsuarioModifica    varchar(20)   NULL
		,FechaModifica      datetime      NULL
	);
	INSERT INTO dbo.FAC_CUPONES_CONFIG (Id_Config, PorcentajeDefecto, PorcentajeMaximo, DiasVigencia, Leyenda)
	VALUES (1, 10, 50, 30, 'Presente este cupón en caja. Válido una sola vez. No acumulable con otras promociones.');
END
GO

/* ---------- Cupones: paciente y tratamiento opcionales, porcentaje, vigencia y uso ---------- */
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EXP_CUPONES') AND name = 'Id_Tratamiento_FK' AND is_nullable = 0)
BEGIN
	IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_EXP_CUPONES_CAT_TRATAMIENTOS')
		ALTER TABLE dbo.EXP_CUPONES DROP CONSTRAINT FK_EXP_CUPONES_CAT_TRATAMIENTOS;
	ALTER TABLE dbo.EXP_CUPONES ALTER COLUMN Id_Tratamiento_FK bigint NULL;
	ALTER TABLE dbo.EXP_CUPONES ADD CONSTRAINT FK_EXP_CUPONES_CAT_TRATAMIENTOS FOREIGN KEY (Id_Tratamiento_FK) REFERENCES dbo.CAT_TRATAMIENTOS (Id_Tratamientos);
END
GO
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EXP_CUPONES') AND name = 'Id_expediente_FK' AND is_nullable = 0)
	ALTER TABLE dbo.EXP_CUPONES ALTER COLUMN Id_expediente_FK bigint NULL;
GO
IF COL_LENGTH('dbo.EXP_CUPONES', 'Porcentaje') IS NULL
	ALTER TABLE dbo.EXP_CUPONES ADD Porcentaje decimal(5,2) NOT NULL CONSTRAINT DF_EXP_CUPONES_Porcentaje DEFAULT (10);
IF COL_LENGTH('dbo.EXP_CUPONES', 'FechaVence') IS NULL
	ALTER TABLE dbo.EXP_CUPONES ADD FechaVence date NULL;
IF COL_LENGTH('dbo.EXP_CUPONES', 'Estado') IS NULL
	ALTER TABLE dbo.EXP_CUPONES ADD Estado char(1) NOT NULL CONSTRAINT DF_EXP_CUPONES_Estado DEFAULT ('P');
IF COL_LENGTH('dbo.EXP_CUPONES', 'Id_Factura_FK') IS NULL
	ALTER TABLE dbo.EXP_CUPONES ADD Id_Factura_FK bigint NULL;
IF COL_LENGTH('dbo.EXP_CUPONES', 'FechaUso') IS NULL
	ALTER TABLE dbo.EXP_CUPONES ADD FechaUso datetime NULL;
IF COL_LENGTH('dbo.EXP_CUPONES', 'UsuarioUso') IS NULL
	ALTER TABLE dbo.EXP_CUPONES ADD UsuarioUso varchar(20) NULL;
IF COL_LENGTH('dbo.EXP_CUPONES', 'MontoDescuento') IS NULL
	ALTER TABLE dbo.EXP_CUPONES ADD MontoDescuento decimal(12,2) NULL;
IF COL_LENGTH('dbo.EXP_CUPONES', 'Nota') IS NULL
	ALTER TABLE dbo.EXP_CUPONES ADD Nota varchar(250) NULL;
IF COL_LENGTH('dbo.EXP_CUPONES', 'MotivoAnulacion') IS NULL
	ALTER TABLE dbo.EXP_CUPONES ADD MotivoAnulacion varchar(250) NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_EXP_CUPONES_Codigo')
	CREATE UNIQUE INDEX UX_EXP_CUPONES_Codigo ON dbo.EXP_CUPONES (CodigoCupon);
GO

/* ---------- Cupón aplicado a la factura (antes de cobrar) ---------- */
IF COL_LENGTH('dbo.CAJ_FACTURAS', 'Id_Cupon_FK') IS NULL
	ALTER TABLE dbo.CAJ_FACTURAS ADD Id_Cupon_FK bigint NULL;
GO

CREATE OR ALTER PROCEDURE dbo.CUP_SP_Cupones
	 @accion      int
	,@usuario     varchar(20)   = NULL
	,@id          bigint        = 0
	,@codigo      varchar(20)   = NULL
	,@asignado    varchar(150)  = NULL
	,@expediente  bigint        = 0
	,@tratamiento bigint        = 0
	,@porcentaje  decimal(5,2)  = 0
	,@vence       date          = NULL
	,@nota        varchar(250)  = NULL
	,@factura     bigint        = 0
	,@monto       decimal(12,2) = 0
	,@estado      varchar(1)    = NULL      -- filtro: P pendientes, U usados, A anulados, V vencidos
	,@texto       nvarchar(100) = NULL
	,@desde       date          = NULL
	,@hasta       date          = NULL
	,@dias        int           = 0
	,@maximo      decimal(5,2)  = 0
AS
BEGIN
	SET NOCOUNT ON;
	declare @hoy date = CAST(GETDATE() as date)
	set @codigo = UPPER(NULLIF(LTRIM(RTRIM(@codigo)), ''))
	set @asignado = NULLIF(LTRIM(RTRIM(@asignado)), '')
	set @nota = NULLIF(LTRIM(RTRIM(@nota)), '')
	set @texto = NULLIF(LTRIM(RTRIM(@texto)), '')
	set @estado = NULLIF(@estado, '')

	/* 1: lista */
	if @accion = 1
	begin
		declare @fin date = DATEADD(DAY, 1, @hasta)
		select x.* from (
			select c.Id_Cupon, c.CodigoCupon, c.Asignado, c.Id_expediente_FK, c.Id_Tratamiento_FK, c.Porcentaje, c.FechaVence
				,case when c.Estado = 'P' and c.FechaVence < @hoy then 'V' else c.Estado end as Estado
				,LTRIM(RTRIM(ISNULL(e.Nombres, '') + ' ' + ISNULL(e.Apellidos, ''))) as Paciente, ISNULL(e.Celular, '') as Celular
				,ISNULL(t.Descripcion, '') as Tratamiento, CAST(ISNULL(t.Precio, 0) as decimal(12,2)) as PrecioTratamiento
				,c.Nota, c.Id_Factura_FK, c.FechaUso, c.UsuarioUso, c.MontoDescuento, c.MotivoAnulacion
				,c.UsuarioCrea, c.FechaCrea
				,(select top 1 f.Id_factura from CAJ_FACTURAS as f where f.Id_Cupon_FK = c.Id_Cupon and f.Estado = 0) as FacturaAplicada
			from EXP_CUPONES as c
				left join EXP_EXPEDIENTES as e on e.Id_Expediente = c.Id_expediente_FK
				left join CAT_TRATAMIENTOS as t on t.Id_Tratamientos = c.Id_Tratamiento_FK
			where (@desde is null or c.FechaCrea >= @desde)
				and (@hasta is null or c.FechaCrea < @fin)
				and (@texto is null or c.CodigoCupon like '%' + @texto + '%' or c.Asignado like '%' + @texto + '%'
					 or e.Nombres + ' ' + e.Apellidos like '%' + @texto + '%' or t.Descripcion like '%' + @texto + '%')
		) as x
		where @estado is null or x.Estado = @estado
		order by x.FechaCrea desc
		return
	end

	/* 2: crear (el código lo genera la aplicación) */
	if @accion = 2
	begin
		declare @max decimal(5,2) = (select PorcentajeMaximo from FAC_CUPONES_CONFIG where Id_Config = 1)
		if @codigo is null or @codigo not like 'DPC-[A-Z][A-Z][A-Z][A-Z][A-Z][A-Z][A-Z][A-Z]' THROW 50500, 'Código de cupón no válido.', 1;
		if exists (select 1 from EXP_CUPONES where CodigoCupon = @codigo) THROW 50501, 'El código ya existe. Intente de nuevo.', 1;
		if @expediente = 0 and @asignado is null THROW 50502, 'Seleccione el paciente o escriba a quién se entrega el cupón.', 1;
		if @expediente > 0 and not exists (select 1 from EXP_EXPEDIENTES where Id_Expediente = @expediente) THROW 50503, 'El paciente no existe.', 1;
		if @tratamiento > 0 and not exists (select 1 from CAT_TRATAMIENTOS where Id_Tratamientos = @tratamiento and IsActivo = 1) THROW 50504, 'El tratamiento no está activo.', 1;
		if @porcentaje <= 0 or @porcentaje > @max
		begin
			declare @m1 nvarchar(120) = N'El descuento debe estar entre 1 y ' + CONVERT(nvarchar(10), CAST(@max as int)) + N' por ciento.';
			THROW 50505, @m1, 1;
		end
		if @vence is null or @vence < @hoy THROW 50506, 'La fecha de vencimiento no puede ser anterior a hoy.', 1;

		if @asignado is null
			select @asignado = LTRIM(RTRIM(Nombres + ' ' + Apellidos)) from EXP_EXPEDIENTES where Id_Expediente = @expediente
		insert into EXP_CUPONES (CodigoCupon, Asignado, Id_expediente_FK, Id_Tratamiento_FK, IsActivo, Porcentaje, FechaVence, Estado, Nota, UsuarioCrea, FechaCrea)
		values (@codigo, @asignado, NULLIF(@expediente, 0), NULLIF(@tratamiento, 0), 1, @porcentaje, @vence, 'P', @nota, @usuario, GETDATE())
		select CAST(SCOPE_IDENTITY() as bigint) as Id
		return
	end

	/* 3: anular (@nota = motivo) */
	if @accion = 3
	begin
		if not exists (select 1 from EXP_CUPONES where Id_Cupon = @id and Estado = 'P') THROW 50507, 'Solo se pueden anular cupones pendientes.', 1;
		if @nota is null or LEN(@nota) < 5 THROW 50508, 'Indique el motivo de la anulación.', 1;
		begin transaction
			update EXP_CUPONES set Estado = 'A', IsActivo = 0, MotivoAnulacion = @nota, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_Cupon = @id
			update CAJ_FACTURAS set Id_Cupon_FK = NULL where Id_Cupon_FK = @id and Estado = 0
		commit transaction
		select @id as Id
		return
	end

	/* 4: configuración */
	if @accion = 4
	begin
		select PorcentajeDefecto, PorcentajeMaximo, DiasVigencia, Leyenda, UsuarioModifica, FechaModifica from FAC_CUPONES_CONFIG where Id_Config = 1
		return
	end

	/* 5: guardar configuración (@porcentaje = por defecto, @maximo, @dias, @nota = leyenda) */
	if @accion = 5
	begin
		if @maximo <= 0 or @maximo > 100 THROW 50509, 'El porcentaje máximo debe estar entre 1 y 100.', 1;
		if @porcentaje <= 0 or @porcentaje > @maximo THROW 50510, 'El porcentaje por defecto debe ser mayor que 0 y no superar el máximo.', 1;
		if @dias < 1 or @dias > 730 THROW 50511, 'La vigencia debe estar entre 1 y 730 días.', 1;
		update FAC_CUPONES_CONFIG set PorcentajeDefecto = @porcentaje, PorcentajeMaximo = @maximo, DiasVigencia = @dias, Leyenda = @nota
			,UsuarioModifica = @usuario, FechaModifica = GETDATE()
		where Id_Config = 1
		select CAST(1 as bigint) as Id
		return
	end

	/* 6: detalle de un cupón (para imprimirlo) */
	if @accion = 6
	begin
		select c.Id_Cupon, c.CodigoCupon, c.Asignado, c.Porcentaje, c.FechaVence, c.Estado, c.Nota, c.FechaCrea
			,ISNULL(t.Descripcion, '') as Tratamiento, cfg.Leyenda
		from EXP_CUPONES as c
			left join CAT_TRATAMIENTOS as t on t.Id_Tratamientos = c.Id_Tratamiento_FK
			cross join FAC_CUPONES_CONFIG as cfg
		where c.Id_Cupon = @id and cfg.Id_Config = 1
		return
	end

	/* 7: aplicar a una factura pendiente (al escanear el QR en caja) */
	if @accion = 7
	begin
		declare @idC bigint, @estC char(1), @venceC date, @expC bigint, @tratC bigint, @facC bigint
		select @idC = Id_Cupon, @estC = Estado, @venceC = FechaVence, @expC = Id_expediente_FK, @tratC = Id_Tratamiento_FK, @facC = Id_Factura_FK
		from EXP_CUPONES where CodigoCupon = @codigo

		if @idC is null THROW 50512, 'El cupón no existe. Verifique el código.', 1;
		if @estC = 'A' THROW 50513, 'El cupón fue anulado.', 1;
		if @estC = 'U' and ISNULL(@facC, 0) <> @factura THROW 50514, 'El cupón ya fue utilizado.', 1;
		if @venceC < @hoy
		begin
			declare @m2 nvarchar(120) = N'El cupón venció el ' + CONVERT(nvarchar(10), @venceC, 103) + N'.';
			THROW 50515, @m2, 1;
		end
		if not exists (select 1 from CAJ_FACTURAS where Id_factura = @factura and Estado = 0) THROW 50516, 'La factura ya fue pagada o no existe.', 1;
		if @expC is not null and not exists (select 1 from CAJ_FACTURAS where Id_factura = @factura and Id_Expediente_FK = @expC)
			THROW 50517, 'Este cupón es de otro paciente.', 1;
		if @tratC is not null and not exists (select 1 from CAJ_FACTURASDETALLES where Id_Factura_FK = @factura and Id_tratamiento_FK = @tratC)
			THROW 50518, 'El cupón es para un tratamiento que no está en esta factura.', 1;
		if exists (select 1 from CAJ_FACTURAS where Id_Cupon_FK = @idC and Estado = 0 and Id_factura <> @factura)
			THROW 50519, 'El cupón ya está aplicado a otra factura pendiente.', 1;

		update CAJ_FACTURAS set Id_Cupon_FK = @idC, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_factura = @factura
		select @idC as Id
		return
	end

	/* 8: quitar el cupón de la factura */
	if @accion = 8
	begin
		update CAJ_FACTURAS set Id_Cupon_FK = NULL, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_factura = @factura and Estado = 0
		select @factura as Id
		return
	end

	/* 9: marcar como usado al pagar (se llama dentro de la transacción del pago) */
	if @accion = 9
	begin
		update c set Estado = 'U', IsActivo = 0, Id_Factura_FK = @factura, FechaUso = GETDATE(), UsuarioUso = @usuario, MontoDescuento = @monto
			,UsuarioModifica = @usuario, FechaModifica = GETDATE()
		from EXP_CUPONES as c
			inner join CAJ_FACTURAS as f on f.Id_Cupon_FK = c.Id_Cupon
		where f.Id_factura = @factura and (c.Estado = 'P' or (c.Estado = 'U' and c.Id_Factura_FK = @factura))
		if @@ROWCOUNT = 0 THROW 50520, 'El cupón ya no es válido. Quítelo de la factura y vuelva a cobrar.', 1;
		select @factura as Id
		return
	end

	/* 10: cupón aplicado a una factura */
	if @accion = 10
	begin
		select c.Id_Cupon, c.CodigoCupon, c.Porcentaje, c.Id_Tratamiento_FK, c.FechaVence, c.Estado, c.Id_Factura_FK, ISNULL(t.Descripcion, '') as Tratamiento
		from CAJ_FACTURAS as f
			inner join EXP_CUPONES as c on c.Id_Cupon = f.Id_Cupon_FK
			left join CAT_TRATAMIENTOS as t on t.Id_Tratamientos = c.Id_Tratamiento_FK
		where f.Id_factura = @factura
		return
	end

	/* 11: resumen */
	if @accion = 11
	begin
		select
			(select COUNT(*) from EXP_CUPONES where Estado = 'P' and FechaVence >= @hoy) as Pendientes
			,(select COUNT(*) from EXP_CUPONES where Estado = 'U') as Usados
			,(select COUNT(*) from EXP_CUPONES where Estado = 'P' and FechaVence < @hoy) as Vencidos
			,(select ISNULL(SUM(MontoDescuento), 0) from EXP_CUPONES where Estado = 'U' and FechaUso >= DATEFROMPARTS(YEAR(@hoy), MONTH(@hoy), 1)) as DescuentoMes
		return
	end;

	THROW 50599, 'Acción no válida.', 1;
END
GO
