/* =====================================================================
   DPieCenter - Citas: FechaInicio / FechaFin según Fecha y la tabla de horarios (CAT_HORARIOS)

   Problema encontrado:
     - Citas sin FechaInicio/FechaFin (las crea EXP_SP_Citas, que solo guarda Fecha y los horarios).
     - Citas con FechaInicio = FechaFin = hora en que se finalizó la atención, no la hora de la cita.
     - El calendario (EXP_SP_Citas_V2) guardaba siempre Id_Horario_fk = 1 (08:00).

   Este script:
     1. dbo.EXP_FN_HorarioCita(@hora): horario activo de CAT_HORARIOS que corresponde a una hora
        (el último horario que empieza a esa hora o antes; si es antes del primero, el primero).
     2. Corrige los datos: FechaInicio = Fecha + hora del horario inicial;
        FechaFin = Fecha + hora del horario final si es posterior, si no, inicio + 60 minutos.
        Solo toca citas sin FechaInicio o con FechaInicio = FechaFin (las de horario real se conservan).
     3. Trigger TR_EXP_CITAS_Horario: mantiene FechaInicio/FechaFin cuando una cita se guarda con
        Fecha y horario pero sin FechaInicio (pantallas anteriores).
   Script idempotente.
   ===================================================================== */
SET NOCOUNT ON;
GO

CREATE OR ALTER FUNCTION dbo.EXP_FN_HorarioCita (@hora time)
RETURNS bigint
AS
BEGIN
    RETURN COALESCE(
        (SELECT TOP 1 Id_Horario FROM dbo.CAT_HORARIOS WHERE ISNULL(IsActivo, 1) = 1 AND Hora <= @hora ORDER BY Hora DESC),
        (SELECT TOP 1 Id_Horario FROM dbo.CAT_HORARIOS WHERE ISNULL(IsActivo, 1) = 1 ORDER BY Hora));
END
GO

/* Corrección de datos */
DECLARE @propia bit = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
BEGIN TRY
    IF @propia = 1 BEGIN TRANSACTION;

    ;WITH x AS (
        SELECT c.FechaInicio, c.FechaFin,
               DATEADD(SECOND, DATEDIFF(SECOND, CAST('00:00' AS time), h.Hora), CAST(c.Fecha AS datetime2)) AS NuevoInicio,
               DATEADD(SECOND, DATEDIFF(SECOND, CAST('00:00' AS time), hf.Hora), CAST(c.Fecha AS datetime2)) AS FinHorario
        FROM dbo.EXP_CITAS AS c
            INNER JOIN dbo.CAT_HORARIOS AS h ON h.Id_Horario = c.Id_Horario_fk
            LEFT JOIN dbo.CAT_HORARIOS AS hf ON hf.Id_Horario = c.Id_HorarioFin_FK
        WHERE c.FechaInicio IS NULL OR c.FechaFin IS NULL OR c.FechaInicio = c.FechaFin
    )
    UPDATE x SET
         FechaInicio = NuevoInicio
        ,FechaFin = CASE WHEN FinHorario > NuevoInicio THEN FinHorario ELSE DATEADD(MINUTE, 60, NuevoInicio) END;

    PRINT N'Citas corregidas: ' + CAST(@@ROWCOUNT AS nvarchar(10));
    IF @propia = 1 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @propia = 1 AND @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH
GO

/* Citas guardadas con Fecha y horario pero sin FechaInicio (o con cambio de fecha/horario sin FechaInicio) */
CREATE OR ALTER TRIGGER dbo.TR_EXP_CITAS_Horario
ON dbo.EXP_CITAS
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;
    DECLARE @recalcular bit = CASE WHEN NOT UPDATE(FechaInicio)
                                    AND (UPDATE(Fecha) OR UPDATE(Id_Horario_fk) OR UPDATE(Id_HorarioFin_FK)) THEN 1 ELSE 0 END;

    ;WITH x AS (
        SELECT c.FechaInicio, c.FechaFin,
               DATEADD(SECOND, DATEDIFF(SECOND, CAST('00:00' AS time), h.Hora), CAST(c.Fecha AS datetime2)) AS NuevoInicio,
               DATEADD(SECOND, DATEDIFF(SECOND, CAST('00:00' AS time), hf.Hora), CAST(c.Fecha AS datetime2)) AS FinHorario
        FROM dbo.EXP_CITAS AS c
            INNER JOIN inserted AS i ON i.Id_Cita = c.Id_Cita
            INNER JOIN dbo.CAT_HORARIOS AS h ON h.Id_Horario = c.Id_Horario_fk
            LEFT JOIN dbo.CAT_HORARIOS AS hf ON hf.Id_Horario = c.Id_HorarioFin_FK
        WHERE c.FechaInicio IS NULL OR @recalcular = 1
    )
    UPDATE x SET
         FechaInicio = NuevoInicio
        ,FechaFin = CASE WHEN FinHorario > NuevoInicio THEN FinHorario ELSE DATEADD(MINUTE, 60, NuevoInicio) END;
END
GO
