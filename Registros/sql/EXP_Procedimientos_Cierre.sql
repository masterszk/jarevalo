/* =====================================================================
   DPieCenter - Cierre de procesos abiertos de meses anteriores

   Procedimientos en sala ('S') o en atención ('I') con fecha anterior al mes en curso:
     - Si la cita ya está cancelada  -> 'C' cancelado (equivale a lo que hace Cancelar en Facturación > Procedimientos).
     - Si no                          -> 'F' finalizado y la cita pasa a Finalizada.
   No genera facturas (son atenciones de meses cerrados). FinalProcedimiento queda con la hora de inicio
   si no tenía. Se puede ejecutar varias veces: solo toca los que sigan abiertos.
   Requiere el CHECK CK_EXP_PROCEDIMIENTOS_Estado (EXP_Procedimientos_Atencion.sql).
   ===================================================================== */
SET NOCOUNT ON;
GO

DECLARE @mes date = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1);
DECLARE @ahora datetime = GETDATE();
DECLARE @finalizada bigint = (SELECT TOP 1 Id_Estado FROM dbo.CAT_ESTADOSCITAS WHERE Finalizada = 1 ORDER BY Id_Estado);
DECLARE @cancelada  bigint = (SELECT TOP 1 Id_Estado FROM dbo.CAT_ESTADOSCITAS WHERE Cancelada = 1 ORDER BY Id_Estado);
DECLARE @c TABLE (Id_Procedimiento bigint PRIMARY KEY, Id_Cita bigint NULL, Cancelada bit NOT NULL);

INSERT @c (Id_Procedimiento, Id_Cita, Cancelada)
SELECT p.Id_Procedimiento, p.Id_Cita_FK, CASE WHEN ISNULL(ec.Cancelada, 0) = 1 THEN 1 ELSE 0 END
FROM dbo.EXP_PROCEDIMIENTOS AS p
    LEFT JOIN dbo.EXP_CITAS AS c ON c.Id_Cita = p.Id_Cita_FK
    LEFT JOIN dbo.CAT_ESTADOSCITAS AS ec ON ec.Id_Estado = c.Id_EstadoCita_fk
WHERE p.Estado IN ('S', 'I') AND p.Fecha < @mes;

DECLARE @propia bit = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
BEGIN TRY
    IF @propia = 1 BEGIN TRANSACTION;

    UPDATE p SET
         Estado = CASE WHEN x.Cancelada = 1 THEN 'C' ELSE 'F' END
        ,Id_EstadoCita_fk = CASE WHEN x.Cancelada = 1 THEN @cancelada ELSE @finalizada END
        ,FinalProcedimiento = ISNULL(p.FinalProcedimiento, p.InicioProcedimiento)
        ,UsuarioModifica = 'sistema'
        ,FechaModifica = @ahora
    FROM dbo.EXP_PROCEDIMIENTOS AS p
        INNER JOIN @c AS x ON x.Id_Procedimiento = p.Id_Procedimiento;

    UPDATE c SET
         Id_EstadoCita_fk = @finalizada
        ,UsuarioModifica = 'sistema'
        ,FechaModifica = @ahora
    FROM dbo.EXP_CITAS AS c
        INNER JOIN @c AS x ON x.Id_Cita = c.Id_Cita
    WHERE x.Cancelada = 0;

    IF @propia = 1 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @propia = 1 AND @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH

DECLARE @f int = (SELECT COUNT(*) FROM @c WHERE Cancelada = 0), @k int = (SELECT COUNT(*) FROM @c WHERE Cancelada = 1);
PRINT N'Procesos de meses anteriores cerrados: ' + CAST(@f AS nvarchar(10)) + N' finalizados, ' + CAST(@k AS nvarchar(10)) + N' cancelados.';
GO
