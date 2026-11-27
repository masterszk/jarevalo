/* =====================================================================
   DPieCenter - Menú Registros > Pantalla de turnos (Registros/frm_TurnosPacientes.aspx)

   Antes se abría con un botón en Registros > Procedimientos. Ahora es una opción del menú;
   assets/js/principal.js la abre en otra pestaña (es una página completa para el televisor de la sala).
   Permiso inicial: los grupos que tienen Registros > Procedimientos, y Administradores.
   Script idempotente.
   ===================================================================== */
SET NOCOUNT ON;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Sys_Opciones WHERE AccesoURL = 'Registros/frm_TurnosPacientes.aspx')
BEGIN
	BEGIN TRANSACTION;
	DECLARE @opcion bigint, @orden int = ISNULL((SELECT MAX(Orden) FROM dbo.Sys_Opciones WHERE IdModulo_FK = 4), 0) + 1;
	INSERT INTO dbo.Sys_Opciones (Descripcion, Abreviado, AccesoURL, IdModulo_FK, Id_UsuarioCrea_FK, FechaCreacion, Orden)
	VALUES ('Pantalla de turnos', 'PT', 'Registros/frm_TurnosPacientes.aspx', 4, 'admin', GETDATE(), @orden);
	SET @opcion = SCOPE_IDENTITY();

	INSERT INTO dbo.Sys_Permisos (IdAplicativo_FK, IdModulo_FK, IdOpcion_FK, IdGrupo_FK, Id_UsuarioCrea_FK, FechaCreacion)
	SELECT DISTINCT p.IdAplicativo_FK, 4, @opcion, p.IdGrupo_FK, 'admin', GETDATE()
	FROM dbo.Sys_Permisos AS p INNER JOIN dbo.Sys_Opciones AS o ON o.Id_Opcion = p.IdOpcion_FK
	WHERE o.AccesoURL = 'Registros/frm_Procedimientos.aspx';

	IF NOT EXISTS (SELECT 1 FROM dbo.Sys_Permisos WHERE IdOpcion_FK = @opcion AND IdGrupo_FK = 'Administradores')
		INSERT INTO dbo.Sys_Permisos (IdAplicativo_FK, IdModulo_FK, IdOpcion_FK, IdGrupo_FK, Id_UsuarioCrea_FK, FechaCreacion)
		VALUES (2, 4, @opcion, 'Administradores', 'admin', GETDATE());
	COMMIT TRANSACTION;
END
GO
