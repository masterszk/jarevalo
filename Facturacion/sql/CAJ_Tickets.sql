/* =====================================================================
   DPieCenter - Ticket POS para servicios sin costo

   Cuando el total de la factura es $0.00 (control, revisión o cortesía) no se genera DTE: Hacienda no recibe documentos
   sin valor. En su lugar la caja emite un ticket interno numerado (T-000001) que se imprime en papel de 80 mm,
   cierra la factura (CAJ_FACTURAS.Estado = 1) y queda en el listado y el reporte de la caja.

   CAJ_SP_Tickets: 1 emitir   2 ticket de una factura (encabezado + servicios)   3 tickets de una caja
   Requiere CAJ_Caja_Anulaciones.sql (caja diaria). Script idempotente: se puede ejecutar varias veces.
   ===================================================================== */
SET NOCOUNT ON;
GO

IF OBJECT_ID('dbo.CAJ_TICKETS', 'U') IS NULL
BEGIN
	CREATE TABLE dbo.CAJ_TICKETS (
		 Id_Ticket       bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_CAJ_TICKETS PRIMARY KEY
		,Numero          varchar(12)    NOT NULL
		,Id_Factura_FK   bigint         NOT NULL CONSTRAINT FK_CAJ_TICKETS_FACTURA REFERENCES dbo.CAJ_FACTURAS (Id_factura)
		,Id_Apertura_FK  bigint         NOT NULL CONSTRAINT FK_CAJ_TICKETS_APERTURA REFERENCES dbo.CAJ_APETURTACAJA (Id_Apertura)
		,Paciente        varchar(250)   NOT NULL
		,Documento       varchar(30)    NULL
		,Servicios       int            NOT NULL
		,Total           decimal(12,2)  NOT NULL CONSTRAINT DF_CAJ_TICKETS_TOTAL DEFAULT (0)
		,Motivo          varchar(100)   NOT NULL
		,UsuarioCrea     varchar(20)    NOT NULL
		,FechaCrea       datetime       NOT NULL CONSTRAINT DF_CAJ_TICKETS_FECHA DEFAULT (GETDATE())
	);
	CREATE UNIQUE INDEX UX_CAJ_TICKETS_NUMERO ON dbo.CAJ_TICKETS (Numero);
	CREATE UNIQUE INDEX UX_CAJ_TICKETS_FACTURA ON dbo.CAJ_TICKETS (Id_Factura_FK);
	CREATE INDEX IX_CAJ_TICKETS_APERTURA ON dbo.CAJ_TICKETS (Id_Apertura_FK);
END
GO

CREATE OR ALTER PROCEDURE dbo.CAJ_SP_Tickets
	 @accion   int
	,@factura  bigint       = NULL
	,@id       bigint       = NULL      -- apertura de caja (acción 3)
	,@cajero   varchar(20)  = NULL
	,@motivo   varchar(100) = NULL
AS
BEGIN
	SET NOCOUNT ON;
	declare @hoy date = CAST(GETDATE() as date)

	/* 1: emitir el ticket de una factura sin costo */
	if @accion = 1
	begin
		-- Si el llamador ya tiene una transacción se usa un punto de guardado: un error no deshace su transacción
		declare @tc int = @@TRANCOUNT
		if @tc = 0 BEGIN TRANSACTION; else SAVE TRANSACTION tk_emitir;
		declare @apertura bigint = (select Id_Apertura from CAJ_APETURTACAJA with (updlock, holdlock)
			where Cajero = @cajero and FechaApertura = @hoy and Estatus = 1)
		if @apertura is null
		begin
			if @tc = 0 ROLLBACK TRANSACTION; else ROLLBACK TRANSACTION tk_emitir;
			THROW 50430, 'Abra la caja del día para emitir el ticket.', 1;
		end

		declare @estado bit, @expediente bigint
		select @estado = Estado, @expediente = Id_Expediente_FK from CAJ_FACTURAS with (updlock, holdlock) where Id_factura = @factura
		if @estado is null or @estado = 1
		begin
			if @tc = 0 ROLLBACK TRANSACTION; else ROLLBACK TRANSACTION tk_emitir;
			THROW 50431, 'La factura ya fue cobrada o no existe.', 1;
		end

		declare @servicios int, @total decimal(12,2)
		select @servicios = COUNT(*), @total = ISNULL(SUM(CAST(Valor as decimal(12,2))), 0) from CAJ_FACTURASDETALLES where Id_Factura_FK = @factura
		if @servicios = 0
		begin
			if @tc = 0 ROLLBACK TRANSACTION; else ROLLBACK TRANSACTION tk_emitir;
			THROW 50432, 'Agregue al menos un servicio a la factura.', 1;
		end
		if @total <> 0
		begin
			if @tc = 0 ROLLBACK TRANSACTION; else ROLLBACK TRANSACTION tk_emitir;
			THROW 50433, 'La factura tiene valor: cóbrela con DTE.', 1;
		end

		declare @siguiente int = ISNULL((select MAX(CAST(SUBSTRING(Numero, 3, 10) as int)) from CAJ_TICKETS with (updlock, holdlock)), 0) + 1
		declare @numero varchar(12) = 'T-' + RIGHT('000000' + CAST(@siguiente as varchar(10)), CASE WHEN @siguiente > 999999 THEN 10 ELSE 6 END)

		insert into CAJ_TICKETS (Numero, Id_Factura_FK, Id_Apertura_FK, Paciente, Documento, Servicios, Total, Motivo, UsuarioCrea, FechaCrea)
		select @numero, @factura, @apertura, LEFT(LTRIM(RTRIM(ISNULL(e.Nombres, '') + ' ' + ISNULL(e.Apellidos, ''))), 250), NULLIF(LTRIM(RTRIM(e.Documento)), '')
			,@servicios, 0, ISNULL(NULLIF(LTRIM(RTRIM(@motivo)), ''), 'Servicio sin costo'), @cajero, GETDATE()
		from EXP_EXPEDIENTES as e where e.Id_Expediente = @expediente

		update CAJ_FACTURAS set Estado = 1, Cajero = @cajero, NumeroControl = @numero, FechaEmision = GETDATE()
			,UsuarioModifica = @cajero, FechaModifica = GETDATE()
		where Id_factura = @factura
		if @tc = 0 COMMIT TRANSACTION;

		set @accion = 2     -- devuelve el ticket emitido
	end

	/* 2: ticket de una factura (para imprimir o reimprimir) */
	if @accion = 2
	begin
		select t.Id_Ticket, t.Numero, t.Id_Factura_FK, t.Paciente, t.Documento, t.Servicios, t.Total, t.Motivo, t.UsuarioCrea, t.FechaCrea
			,LTRIM(RTRIM(ISNULL(u.Nombres, '') + ' ' + ISNULL(u.Apellidos, ''))) as Cajero
		from CAJ_TICKETS as t left join Sys_Usuarios as u on u.Id_Usuario = t.UsuarioCrea
		where t.Id_Factura_FK = @factura

		select d.Descripion as Descripcion, CAST(d.Valor as decimal(12,2)) as Valor
		from CAJ_FACTURASDETALLES as d
		where d.Id_Factura_FK = @factura and exists (select 1 from CAJ_TICKETS as t where t.Id_Factura_FK = @factura)
		order by d.Id_detalle
		return
	end

	/* 3: tickets de una caja */
	if @accion = 3
	begin
		select t.Id_Ticket, t.Numero, t.Id_Factura_FK, t.Paciente, t.Documento, t.Servicios, t.Total, t.Motivo, t.UsuarioCrea, t.FechaCrea
		from CAJ_TICKETS as t inner join CAJ_APETURTACAJA as a on a.Id_Apertura = t.Id_Apertura_FK
		where t.Id_Apertura_FK = @id and (@cajero is null or a.Cajero = @cajero)
		order by t.FechaCrea desc
		return
	end;

	THROW 50439, 'Acción no válida.', 1;
END
GO
