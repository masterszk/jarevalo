/* =====================================================================
   DPieCenter - Menú Opciones > Videos de turnos (Opciones/frm_Publicidad.aspx)

   Sube, ordena y elimina los videos de la pantalla de turnos (carpeta assets/publicidad).
   Permiso inicial: Administradores. Se puede dar a otros grupos desde Perfiles.
   Script idempotente.
   ===================================================================== */
SET NOCOUNT ON;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Sys_Opciones WHERE AccesoURL = 'Opciones/frm_Publicidad.aspx')
BEGIN
	BEGIN TRANSACTION;
	DECLARE @opcion bigint, @orden int = ISNULL((SELECT MAX(Orden) FROM dbo.Sys_Opciones WHERE IdModulo_FK = 2), 0) + 1;
	INSERT INTO dbo.Sys_Opciones (Descripcion, Abreviado, AccesoURL, IdModulo_FK, Id_UsuarioCrea_FK, FechaCreacion, Orden)
	VALUES ('Videos de turnos', 'VT', 'Opciones/frm_Publicidad.aspx', 2, 'admin', GETDATE(), @orden);
	SET @opcion = SCOPE_IDENTITY();
	INSERT INTO dbo.Sys_Permisos (IdAplicativo_FK, IdModulo_FK, IdOpcion_FK, IdGrupo_FK, Id_UsuarioCrea_FK, FechaCreacion)
	SELECT 2, 2, @opcion, g.Id_Grupo, 'admin', GETDATE() FROM dbo.Sys_Grupos AS g WHERE g.Id_Grupo = 'Administradores';
	COMMIT TRANSACTION;
END
GO
