/* =====================================================================
   DPieCenter - Facturación > Procedimientos (Facturacion/frm_ProcedimientosCurso.aspx)

   Procedimientos en curso de todos los especialistas: reprogramar, cambiar de especialista, cancelar y finalizar.
   Usa dbo.EXP_SP_Procedimientos_Atencion (acción 14 y acciones 10 a 13), de Registros/sql/EXP_Procedimientos_Atencion.sql.
   La opción del menú recibe los mismos grupos que Facturación > Caja.
   Script idempotente: se puede ejecutar varias veces.
   ===================================================================== */
SET NOCOUNT ON;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Sys_Opciones WHERE AccesoURL = 'Facturacion/frm_ProcedimientosCurso.aspx')
BEGIN
	BEGIN TRANSACTION;
	DECLARE @opcion bigint, @orden int = ISNULL((SELECT MAX(Orden) FROM dbo.Sys_Opciones WHERE IdModulo_FK = 5), 0) + 1;
	INSERT INTO dbo.Sys_Opciones (Descripcion, Abreviado, AccesoURL, IdModulo_FK, Id_UsuarioCrea_FK, FechaCreacion, Orden)
	VALUES ('Procedimientos', 'PR', 'Facturacion/frm_ProcedimientosCurso.aspx', 5, 'admin', GETDATE(), @orden);
	SET @opcion = SCOPE_IDENTITY();

	-- mismos grupos que tienen la Caja; si la Caja no tiene permisos, al menos Administradores
	INSERT INTO dbo.Sys_Permisos (IdAplicativo_FK, IdModulo_FK, IdOpcion_FK, IdGrupo_FK, Id_UsuarioCrea_FK, FechaCreacion)
	SELECT DISTINCT p.IdAplicativo_FK, 5, @opcion, p.IdGrupo_FK, 'admin', GETDATE()
	FROM dbo.Sys_Permisos AS p INNER JOIN dbo.Sys_Opciones AS o ON o.Id_Opcion = p.IdOpcion_FK
	WHERE o.AccesoURL = 'Facturacion/frm_Facturas.aspx';

	IF NOT EXISTS (SELECT 1 FROM dbo.Sys_Permisos WHERE IdOpcion_FK = @opcion AND IdGrupo_FK = 'Administradores')
		INSERT INTO dbo.Sys_Permisos (IdAplicativo_FK, IdModulo_FK, IdOpcion_FK, IdGrupo_FK, Id_UsuarioCrea_FK, FechaCreacion)
		VALUES (2, 5, @opcion, 'Administradores', 'admin', GETDATE());
	COMMIT TRANSACTION;
END
GO
