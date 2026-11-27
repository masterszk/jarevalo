/* =====================================================================
   DPieCenter - Generador de firma de los DTE (firmador del Ministerio de Hacienda)

   Hacienda entrega el "firmador" (svfe-api-firmador): un servicio local al que se envía el JSON del DTE con el NIT del emisor
   y la contraseña de la llave privada del certificado, y devuelve el documento firmado (JWS) para transmitirlo a Hacienda.
   Aquí se guardan su URL, el NIT del certificado y la contraseña (cifrada con la llave de Web.config), y el resultado de la última prueba.
   Se configuran en Opciones > Empresa > Firma electrónica.

   FAC_SP_DTE_FIRMADOR: 1 consultar (sin la contraseña)   2 guardar (contraseña NULL = conservar)   3 registrar prueba   4 contraseña cifrada
   También quita la opción de menú Facturación > Datos DTE: esos datos ahora están en Opciones > Empresa.
   Script idempotente: se puede ejecutar varias veces.
   ===================================================================== */
SET NOCOUNT ON;
GO

IF COL_LENGTH('dbo.FAC_DTE_PARAMETROS', 'FirmadorUrl') IS NULL
	ALTER TABLE dbo.FAC_DTE_PARAMETROS ADD FirmadorUrl varchar(250) NULL;
IF COL_LENGTH('dbo.FAC_DTE_PARAMETROS', 'FirmadorNit') IS NULL
	ALTER TABLE dbo.FAC_DTE_PARAMETROS ADD FirmadorNit varchar(14) NULL;
IF COL_LENGTH('dbo.FAC_DTE_PARAMETROS', 'FirmadorClave') IS NULL
	ALTER TABLE dbo.FAC_DTE_PARAMETROS ADD FirmadorClave varchar(1000) NULL;
IF COL_LENGTH('dbo.FAC_DTE_PARAMETROS', 'FirmadorPrueba') IS NULL
	ALTER TABLE dbo.FAC_DTE_PARAMETROS ADD FirmadorPrueba datetime NULL;
IF COL_LENGTH('dbo.FAC_DTE_PARAMETROS', 'FirmadorResultado') IS NULL
	ALTER TABLE dbo.FAC_DTE_PARAMETROS ADD FirmadorResultado nvarchar(500) NULL;
GO

CREATE OR ALTER PROCEDURE dbo.FAC_SP_DTE_FIRMADOR
	 @accion    int
	,@url       varchar(250)   = NULL
	,@nit       varchar(14)    = NULL
	,@clave     varchar(1000)  = NULL      -- ya cifrada; NULL conserva la guardada
	,@ok        bit            = 0
	,@resultado nvarchar(500)  = NULL
	,@usuario   varchar(20)    = NULL
AS
BEGIN
	SET NOCOUNT ON;
	declare @id int = (select top 1 Id_Parametro from FAC_DTE_PARAMETROS where Estado = 1 order by Id_Parametro)

	if @accion = 1
	begin
		select FirmadorUrl, ISNULL(FirmadorNit, NIT) as FirmadorNit, NIT as NitEmisor
			,CAST(case when LEN(ISNULL(FirmadorClave, '')) > 0 then 1 else 0 end as bit) as TieneClave
			,FirmadorPrueba, FirmadorResultado
		from FAC_DTE_PARAMETROS where Id_Parametro = @id
		return
	end

	if @accion = 2
	begin
		if @id is null THROW 50700, 'Guarde primero los datos de facturación electrónica.', 1;
		set @url = NULLIF(LTRIM(RTRIM(@url)), '')
		set @nit = NULLIF(LTRIM(RTRIM(@nit)), '')
		if @url is not null and @url not like 'http%://_%' THROW 50701, 'La dirección del firmador debe empezar con http:// o https://.', 1;
		if @nit is not null and (@nit like '%[^0-9]%' or LEN(@nit) not in (9, 14)) THROW 50702, 'El NIT del certificado debe tener 14 dígitos (o 9 si es DUI), sin guiones.', 1;
		update FAC_DTE_PARAMETROS set FirmadorUrl = @url, FirmadorNit = @nit, FirmadorClave = ISNULL(@clave, FirmadorClave)
			,UsuarioModifica = @usuario, FechaModifica = GETDATE()
		where Id_Parametro = @id
		select CAST(@id as bigint) as Id
		return
	end

	if @accion = 3
	begin
		update FAC_DTE_PARAMETROS set FirmadorPrueba = GETDATE(), FirmadorResultado = LEFT((case when @ok = 1 then N'OK: ' else N'ERROR: ' end) + ISNULL(@resultado, N''), 500)
		where Id_Parametro = @id
		return
	end

	if @accion = 4
	begin
		select FirmadorUrl, ISNULL(FirmadorNit, NIT) as FirmadorNit, FirmadorClave from FAC_DTE_PARAMETROS where Id_Parametro = @id
		return
	end;

	THROW 50799, 'Acción no válida.', 1;
END
GO

/* Los datos del DTE se administran ahora en Opciones > Empresa: se quita la opción Facturación > Datos DTE */
IF EXISTS (SELECT 1 FROM dbo.Sys_Opciones WHERE AccesoURL = 'Facturacion/frm_EmpresaDte.aspx')
BEGIN
	BEGIN TRANSACTION;
	DELETE p FROM dbo.Sys_Permisos AS p INNER JOIN dbo.Sys_Opciones AS o ON o.Id_Opcion = p.IdOpcion_FK WHERE o.AccesoURL = 'Facturacion/frm_EmpresaDte.aspx';
	DELETE a FROM dbo.Sys_AccesosObjetos AS a INNER JOIN dbo.Sys_Opciones AS o ON o.Id_Opcion = a.IdOpcion_FK WHERE o.AccesoURL = 'Facturacion/frm_EmpresaDte.aspx';
	DELETE FROM dbo.Sys_Opciones WHERE AccesoURL = 'Facturacion/frm_EmpresaDte.aspx';
	COMMIT TRANSACTION;
END
GO
