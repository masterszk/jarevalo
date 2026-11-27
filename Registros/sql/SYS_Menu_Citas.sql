/* =====================================================================
   DPieCenter - Menú Registros > Citas abre el calendario de citas

   La opción "Citas" apuntaba a la lista anterior (Registros/frm_ListaCitas.aspx). Ahora abre
   Registros/frm_CitasCalendario.aspx, desde donde se crean y editan las citas.
   Se conserva la opción (mismo Id), así que los permisos de los perfiles no cambian. Script idempotente.
   ===================================================================== */
SET NOCOUNT ON;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Sys_Opciones WHERE AccesoURL = 'Registros/frm_CitasCalendario.aspx')
	UPDATE dbo.Sys_Opciones
	   SET AccesoURL = 'Registros/frm_CitasCalendario.aspx'
	 WHERE AccesoURL = 'Registros/frm_ListaCitas.aspx';
GO
