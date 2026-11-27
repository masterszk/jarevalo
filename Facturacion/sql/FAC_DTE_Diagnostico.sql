/* =====================================================================
   DPieCenter - Diagnóstico de la emisión de DTE (Facturacion/frm_DiagnosticoDte.aspx)

   FAC_DTE_EVENTOS guarda cada intento de guardar los archivos (PDF / JSON) y de enviar el correo, con el error.
   Antes los errores solo iban a Trace y en producción no quedaba registro de por qué no se generaban o no se enviaban.

   FAC_SP_DTE_DIAGNOSTICO
     1 registrar evento   2 últimos eventos   3 DTE con archivos o correo pendientes   4 datos de un DTE para rearmar sus archivos
   Script idempotente: se puede ejecutar varias veces.
   ===================================================================== */
SET NOCOUNT ON;
GO

IF OBJECT_ID('dbo.FAC_DTE_EVENTOS', 'U') IS NULL
BEGIN
	CREATE TABLE dbo.FAC_DTE_EVENTOS (
		 Id_Evento   bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_FAC_DTE_EVENTOS PRIMARY KEY
		,Id_Dte_FK   bigint        NULL
		,Etapa       varchar(20)   NOT NULL     -- Archivos, Correo, Prueba
		,Ok          bit           NOT NULL
		,Mensaje     nvarchar(1000) NULL
		,Usuario     varchar(20)   NULL
		,Servidor    varchar(100)  NULL
		,Fecha       datetime      NOT NULL CONSTRAINT DF_FAC_DTE_EVENTOS_Fecha DEFAULT (GETDATE())
	);
	CREATE INDEX IX_FAC_DTE_EVENTOS_Fecha ON dbo.FAC_DTE_EVENTOS (Fecha DESC);
	CREATE INDEX IX_FAC_DTE_EVENTOS_DTE ON dbo.FAC_DTE_EVENTOS (Id_Dte_FK);
END
GO

CREATE OR ALTER PROCEDURE dbo.FAC_SP_DTE_DIAGNOSTICO
	 @accion   int
	,@id       bigint         = 0
	,@etapa    varchar(20)    = NULL
	,@ok       bit            = 0
	,@mensaje  nvarchar(1000) = NULL
	,@usuario  varchar(20)    = NULL
	,@servidor varchar(100)   = NULL
	,@codigo   char(36)       = NULL
AS
BEGIN
	SET NOCOUNT ON;

	/* 1: registrar evento */
	if @accion = 1
	begin
		insert into FAC_DTE_EVENTOS (Id_Dte_FK, Etapa, Ok, Mensaje, Usuario, Servidor, Fecha)
		values (NULLIF(@id, 0), @etapa, @ok, LEFT(@mensaje, 1000), @usuario, @servidor, GETDATE())
		return
	end

	/* 2: últimos eventos */
	if @accion = 2
	begin
		select top 50 ev.Id_Evento, ev.Id_Dte_FK, ev.Etapa, ev.Ok, ev.Mensaje, ev.Usuario, ev.Servidor, ev.Fecha, d.NumeroControl
		from FAC_DTE_EVENTOS as ev left join FAC_DTE_DOCUMENTOS as d on d.Id_Dte = ev.Id_Dte_FK
		order by ev.Id_Evento desc
		return
	end

	/* 3: DTE vigentes sin archivos guardados o sin correo enviado (últimos 90 días) */
	if @accion = 3
	begin
		select d.Id_Dte, d.Id_Factura_FK, d.TipoDte, d.NumeroControl, d.CodigoGeneracion, d.FechaEmision, d.HoraEmision, d.ReceptorNombre, d.TotalPagar
			,d.RutaPdf, d.CorreoDestino, d.FechaCorreo, d.UsuarioCrea
			,ISNULL(case when d.TipoDte = '03' then r.Correo else e.Email end, '') as CorreoCliente
			,(select top 1 Mensaje from FAC_DTE_EVENTOS as ev where ev.Id_Dte_FK = d.Id_Dte and ev.Ok = 0 order by ev.Id_Evento desc) as UltimoError
		from FAC_DTE_DOCUMENTOS as d
			inner join CAJ_FACTURAS as f on f.Id_factura = d.Id_Factura_FK
			left join EXP_EXPEDIENTES as e on e.Id_Expediente = f.Id_Expediente_FK
			left join FAC_DTE_RECEPTORES as r on r.Id_Receptor = d.Id_Receptor_FK
		where d.Estado <> 'A' and d.FechaEmision >= DATEADD(DAY, -90, CAST(GETDATE() as date))
			and (ISNULL(d.RutaPdf, '') = '' or d.FechaCorreo is null)
		order by d.Id_Dte desc
		return
	end

	/* 4: datos de un DTE (por id o código de generación) para rearmar sus archivos */
	if @accion = 4
	begin
		select d.Id_Dte, d.Id_Factura_FK, d.TipoDte, d.NumeroControl, d.CodigoGeneracion, d.FechaEmision, d.HoraEmision, d.ReceptorNombre, d.TotalPagar
			-- pago combinado (FAC_DTE_Pagos.sql): "Tarjeta Crédito $15.00 + Billetes y monedas $8.90"
			,d.FormaPago, dbo.FAC_FN_FormasPagoTexto(d.Id_Dte) as FormaPagoTexto, d.ReferenciaPago, d.MontoRecibido, d.Cambio, d.UsuarioCrea, d.JsonDte
			,d.Estado, d.CorreoDestino
		from FAC_DTE_DOCUMENTOS as d
		where (@id > 0 and d.Id_Dte = @id) or (@codigo is not null and d.CodigoGeneracion = @codigo)
		return
	end;

	THROW 50699, 'Acción no válida.', 1;
END
GO

/* Opción del menú Facturación (solo administradores) */
IF NOT EXISTS (SELECT 1 FROM dbo.Sys_Opciones WHERE AccesoURL = 'Facturacion/frm_DiagnosticoDte.aspx')
BEGIN
	BEGIN TRANSACTION;
	DECLARE @opcion bigint, @orden int = ISNULL((SELECT MAX(Orden) FROM dbo.Sys_Opciones WHERE IdModulo_FK = 5), 0) + 1;
	INSERT INTO dbo.Sys_Opciones (Descripcion, Abreviado, AccesoURL, IdModulo_FK, Id_UsuarioCrea_FK, FechaCreacion, Orden)
	VALUES ('Diagnóstico DTE', 'DG', 'Facturacion/frm_DiagnosticoDte.aspx', 5, 'admin', GETDATE(), @orden);
	SET @opcion = SCOPE_IDENTITY();
	INSERT INTO dbo.Sys_Permisos (IdAplicativo_FK, IdModulo_FK, IdOpcion_FK, IdGrupo_FK, Id_UsuarioCrea_FK, FechaCreacion)
	VALUES (2, 5, @opcion, 'Administradores', 'admin', GETDATE());
	COMMIT TRANSACTION;
END
GO
