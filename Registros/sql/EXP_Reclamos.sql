/* =====================================================================
   DPieCenter - Reclamos de pacientes (Registros/frm_ListaExpedientes.aspx, ficha del expediente)

   La aplicación registra el reclamo sobre un procedimiento del paciente (SqlProcess.mtdEXP_Reclamos envía
   @procedimiento y @user). Algunas bases tienen la estructura anterior de EXP_Reclamos (Id_Expediente,
   Id_Especialista, sin procedimiento): se renombran las columnas (los datos se conservan) y se agrega
   Id_Procedimiento_FK. Script idempotente.
   ===================================================================== */
SET NOCOUNT ON;
GO

IF OBJECT_ID('dbo.EXP_Reclamos', 'U') IS NULL
    CREATE TABLE dbo.EXP_Reclamos (
        Id_Reclamo          bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_EXP_Reclamos PRIMARY KEY,
        Id_Expediente_fk    bigint        NOT NULL,
        Id_Especialista_FK  bigint        NOT NULL,
        Id_Procedimiento_FK bigint        NULL,
        Reclamo             varchar(max)  NOT NULL,
        UsuarioCrea         varchar(20)   NOT NULL,
        FechaCrea           datetime      NOT NULL,
        UsuarioModifica     varchar(20)   NULL,
        FechaModifica       datetime      NULL
    );
GO
IF COL_LENGTH('dbo.EXP_Reclamos', 'Id_Expediente_fk') IS NULL AND COL_LENGTH('dbo.EXP_Reclamos', 'Id_Expediente') IS NOT NULL
    EXEC sp_rename 'dbo.EXP_Reclamos.Id_Expediente', 'Id_Expediente_fk', 'COLUMN';
GO
IF COL_LENGTH('dbo.EXP_Reclamos', 'Id_Especialista_FK') IS NULL AND COL_LENGTH('dbo.EXP_Reclamos', 'Id_Especialista') IS NOT NULL
    EXEC sp_rename 'dbo.EXP_Reclamos.Id_Especialista', 'Id_Especialista_FK', 'COLUMN';
GO
IF COL_LENGTH('dbo.EXP_Reclamos', 'Id_Procedimiento_FK') IS NULL
    ALTER TABLE dbo.EXP_Reclamos ADD Id_Procedimiento_FK bigint NULL;
GO
/* Aviso (campana) al especialista: la garantía queda "no vista" hasta que él la abre */
IF COL_LENGTH('dbo.EXP_Reclamos', 'Visto') IS NULL
    ALTER TABLE dbo.EXP_Reclamos ADD Visto bit NOT NULL CONSTRAINT DF_EXP_Reclamos_Visto DEFAULT (0);
IF COL_LENGTH('dbo.EXP_Reclamos', 'FechaVisto') IS NULL
    ALTER TABLE dbo.EXP_Reclamos ADD FechaVisto datetime NULL, UsuarioVisto varchar(20) NULL;
GO

/* @accion 1 nuevo | 2 modificar | 3 eliminar | 4 todos | 5 uno | 6 del expediente
           7 no vistas (@especialista 0 = de todos) | 8 marcar como vistas las del especialista (@id > 0: solo esa) */
CREATE OR ALTER PROCEDURE [dbo].[EXP_SP_Reclamos]
     @id            bigint = 0
    ,@expediente    bigint = 0
    ,@especialista  bigint = 0
    ,@procedimiento bigint = 0
    ,@reclamo       varchar(2500) = NULL
    ,@user          varchar(20) = NULL
    ,@usuario       varchar(20) = NULL      -- nombre del parámetro en la versión anterior
    ,@accion        int
AS
BEGIN TRY
    SET NOCOUNT ON;
    SET @user = COALESCE(@user, @usuario);

    IF @accion = 1
    BEGIN
        INSERT INTO EXP_Reclamos (Id_Expediente_fk, Id_Especialista_FK, Id_Procedimiento_FK, Reclamo, UsuarioCrea, FechaCrea)
        VALUES (@expediente, @especialista, NULLIF(@procedimiento, 0), @reclamo, @user, GETDATE());
        SELECT 'OK' AS resp;
    END
    ELSE IF @accion = 2
    BEGIN
        UPDATE EXP_Reclamos SET
             Id_Especialista_FK = @especialista
            ,Id_Procedimiento_FK = COALESCE(NULLIF(@procedimiento, 0), Id_Procedimiento_FK)
            ,Reclamo = @reclamo
            ,UsuarioModifica = @user
            ,FechaModifica = GETDATE()
            ,Visto = 0, FechaVisto = NULL, UsuarioVisto = NULL     -- se avisa de nuevo al especialista
        WHERE Id_Reclamo = @id;
        SELECT 'OK' AS resp;
    END
    ELSE IF @accion = 3
    BEGIN
        DELETE FROM EXP_Reclamos WHERE Id_Reclamo = @id;
        SELECT 'OK' AS resp;
    END
    ELSE IF @accion = 4
    BEGIN
        SELECT r.Id_Reclamo, e.Descripcion AS Especialista, r.Reclamo,
               ISNULL(r.UsuarioModifica, r.UsuarioCrea) AS Usuario, ISNULL(r.FechaModifica, r.FechaCrea) AS Fecha
        FROM EXP_Reclamos AS r
            INNER JOIN CAT_ESPECIALISTAS AS e ON r.Id_Especialista_FK = e.Id_Especialista;
        SELECT 'OK' AS resp;
    END
    ELSE IF @accion = 5
    BEGIN
        SELECT Id_Especialista_FK AS Id_Especialista, Id_Procedimiento_FK AS Id_Procedimiento, Reclamo
        FROM EXP_Reclamos WHERE Id_Reclamo = @id;
        SELECT 'OK' AS resp;
    END
    ELSE IF @accion = 6
    BEGIN
        SELECT r.Id_Reclamo, e.Descripcion AS Especialista, r.Reclamo, r.UsuarioCrea AS Usuario, r.FechaCrea AS Fecha
        FROM EXP_Reclamos AS r
            INNER JOIN CAT_ESPECIALISTAS AS e ON r.Id_Especialista_FK = e.Id_Especialista
        WHERE r.Id_Expediente_fk = @expediente;
        SELECT 'OK' AS resp;
    END
    ELSE IF @accion = 7
    BEGIN
        SELECT r.Id_Reclamo, r.Id_Especialista_FK AS Id_Especialista, ISNULL(s.Descripcion, '') AS Especialista
            ,r.Id_Expediente_fk AS Id_Expediente
            ,LTRIM(RTRIM(ISNULL(e.Nombres, '') + ' ' + ISNULL(e.Apellidos, ''))) AS Paciente
            ,p.Fecha AS FechaProcedimiento
            ,ISNULL(STUFF((SELECT ', ' + t.Descripcion FROM EXP_PROCEDIMIENTOSTRATAMIENTOS AS t
                           WHERE t.Id_Procedimiento_FK = r.Id_Procedimiento_FK ORDER BY t.Descripcion
                           FOR XML PATH(''), TYPE).value('.', 'varchar(max)'), 1, 2, ''), '') AS Tratamientos
            ,r.Reclamo, r.UsuarioCrea AS Usuario, ISNULL(r.FechaModifica, r.FechaCrea) AS Fecha
        FROM EXP_Reclamos AS r
            LEFT JOIN CAT_ESPECIALISTAS AS s ON s.Id_Especialista = r.Id_Especialista_FK
            LEFT JOIN EXP_EXPEDIENTES AS e ON e.Id_Expediente = r.Id_Expediente_fk
            LEFT JOIN EXP_PROCEDIMIENTOS AS p ON p.Id_Procedimiento = r.Id_Procedimiento_FK
        WHERE r.Visto = 0 AND (@especialista = 0 OR r.Id_Especialista_FK = @especialista)
        ORDER BY ISNULL(r.FechaModifica, r.FechaCrea) DESC, r.Id_Reclamo DESC;
    END
    ELSE IF @accion = 8
    BEGIN
        UPDATE EXP_Reclamos SET Visto = 1, FechaVisto = GETDATE(), UsuarioVisto = @user
        WHERE Visto = 0 AND Id_Especialista_FK = @especialista AND (@id = 0 OR Id_Reclamo = @id);
        SELECT CAST(@@ROWCOUNT AS int) AS Marcadas;
    END
END TRY
BEGIN CATCH
    SELECT
    'ERRORNUMBER: '+CONVERT(varchar(max),ERROR_NUMBER())+
    '--ERRORLINE: '+CONVERT(varchar(max),ERROR_LINE())+
    '--ERRORMESSAGE: '+CONVERT(varchar(max),ERROR_MESSAGE())+
    '--ERRORSEVERITY: '+CONVERT(varchar(max),ERROR_SEVERITY())+
    '--ERRORPROCEDURE:'+CONVERT(varchar(max),ERROR_PROCEDURE())+
    '--ERRORSTATE: '+CONVERT(varchar(max),ERROR_STATE()) AS respuesta
END CATCH
GO
