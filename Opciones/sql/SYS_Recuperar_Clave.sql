/* =====================================================================
   DPieCenter - Recuperación de contraseña desde el login (recuperarClave.aspx)
   1) El usuario escribe su correo y recibe un código de 6 dígitos (vence en 10 minutos).
   2) Valida el código (máximo 5 intentos).
   3) Escribe la nueva contraseña.
   El código no se guarda: solo su hash SHA-256. Script idempotente.
   ===================================================================== */
SET NOCOUNT ON;
GO

IF OBJECT_ID('dbo.Sys_RecuperacionClave', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Sys_RecuperacionClave (
        Id_Recuperacion bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_Sys_RecuperacionClave PRIMARY KEY,
        Id_Usuario_FK   varchar(20)  NOT NULL,
        Email           varchar(100) NOT NULL,
        CodigoHash      char(64)     NOT NULL,          -- SHA-256 en hexadecimal
        Expira          datetime     NOT NULL,
        Intentos        int          NOT NULL CONSTRAINT DF_Sys_RecuperacionClave_Int DEFAULT (0),
        Verificado      datetime     NULL,              -- momento en que se validó el código
        Usado           datetime     NULL,              -- momento en que se cambió la contraseña
        Anulado         bit          NOT NULL CONSTRAINT DF_Sys_RecuperacionClave_Anu DEFAULT (0),
        Ip              varchar(45)  NULL,
        FechaCrea       datetime     NOT NULL CONSTRAINT DF_Sys_RecuperacionClave_FC DEFAULT (GETDATE())
    );
    CREATE INDEX IX_Sys_RecuperacionClave_Usuario ON dbo.Sys_RecuperacionClave (Id_Usuario_FK, FechaCrea DESC);
END
GO

/* @accion
     1 solicitar:  @idUsuario, @codigoHash, @ip -> Id_Recuperacion, Id_Usuario, Nombre, Email (el registrado en el usuario;
                   sin filas si el usuario no existe, está inactivo o no tiene correo)
     2 validar:    @id, @codigoHash         -> Resultado: OK | INCORRECTO (Restantes) | VENCIDO | BLOQUEADO
     3 cambiar:    @id, @newpass (hash)     -> Resultado: OK | VENCIDO | REPETIDA
   Los errores de uso se devuelven con THROW 5xxxx y se muestran al usuario. */
CREATE OR ALTER PROCEDURE dbo.Sys_SP_RecuperarClave
    @accion     int,
    @email      varchar(100) = NULL,
    @codigoHash char(64)     = NULL,
    @ip         varchar(45)  = NULL,
    @id         bigint       = 0,
    @newpass    varchar(50)  = NULL,
    @idUsuario  varchar(20)  = NULL     -- usuario que pide el código: se envía SOLO al correo registrado en ese usuario
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MinutosCodigo int = 10, @MinutosCambio int = 15, @MaxIntentos int = 5, @MaxSolicitudes int = 3;
    DECLARE @usuario varchar(20);

    IF @accion = 1
    BEGIN
        SET @idUsuario = NULLIF(LTRIM(RTRIM(ISNULL(@idUsuario, ''))), '');
        IF @idUsuario IS NULL OR @codigoHash IS NULL THROW 52001, 'Escriba su usuario.', 1;

        -- Antes se buscaba por correo y se tomaba el primer usuario con ese correo: si dos usuarios lo compartían,
        -- el código era para otro usuario. Ahora el correo es siempre el del usuario indicado.
        SELECT @usuario = Id_Usuario, @email = LTRIM(RTRIM(Email))
        FROM dbo.Sys_Usuarios
        WHERE Id_Usuario = @idUsuario AND ISNULL(EstatusUsuario, 'A') <> 'I'
            AND LTRIM(RTRIM(ISNULL(Email, ''))) LIKE '_%@_%._%';

        IF @usuario IS NULL RETURN;    -- usuario inexistente, inactivo o sin correo: no se revela cuál

        IF (SELECT COUNT(*) FROM dbo.Sys_RecuperacionClave
            WHERE Id_Usuario_FK = @usuario AND FechaCrea > DATEADD(MINUTE, -15, GETDATE())) >= @MaxSolicitudes
            THROW 52002, 'Ya se enviaron varios códigos. Espere 15 minutos antes de solicitar otro.', 1;

        UPDATE dbo.Sys_RecuperacionClave SET Anulado = 1
        WHERE Id_Usuario_FK = @usuario AND Usado IS NULL AND Anulado = 0;

        INSERT INTO dbo.Sys_RecuperacionClave (Id_Usuario_FK, Email, CodigoHash, Expira, Ip)
        VALUES (@usuario, @email, @codigoHash, DATEADD(MINUTE, @MinutosCodigo, GETDATE()), @ip);

        SELECT CAST(SCOPE_IDENTITY() AS bigint) AS Id_Recuperacion, u.Id_Usuario,
               LTRIM(RTRIM(ISNULL(u.Nombres, '') + ' ' + ISNULL(u.Apellidos, ''))) AS Nombre, LTRIM(RTRIM(u.Email)) AS Email
        FROM dbo.Sys_Usuarios AS u WHERE u.Id_Usuario = @usuario;
        RETURN;
    END

    IF @accion = 2
    BEGIN
        DECLARE @hash char(64), @expira datetime, @intentos int, @anulado bit, @usado datetime;
        SELECT @hash = CodigoHash, @expira = Expira, @intentos = Intentos, @anulado = Anulado, @usado = Usado
        FROM dbo.Sys_RecuperacionClave WHERE Id_Recuperacion = @id;

        IF @hash IS NULL OR @anulado = 1 OR @usado IS NOT NULL OR @expira < GETDATE()
        BEGIN SELECT 'VENCIDO' AS Resultado, 0 AS Restantes; RETURN; END
        IF @intentos >= @MaxIntentos
        BEGIN SELECT 'BLOQUEADO' AS Resultado, 0 AS Restantes; RETURN; END

        IF @hash = @codigoHash
        BEGIN
            UPDATE dbo.Sys_RecuperacionClave SET Verificado = GETDATE() WHERE Id_Recuperacion = @id;
            SELECT 'OK' AS Resultado, @MaxIntentos - @intentos AS Restantes;
            RETURN;
        END

        UPDATE dbo.Sys_RecuperacionClave SET Intentos = Intentos + 1,
               Anulado = CASE WHEN Intentos + 1 >= @MaxIntentos THEN 1 ELSE Anulado END
        WHERE Id_Recuperacion = @id;
        SELECT CASE WHEN @intentos + 1 >= @MaxIntentos THEN 'BLOQUEADO' ELSE 'INCORRECTO' END AS Resultado,
               @MaxIntentos - @intentos - 1 AS Restantes;
        RETURN;
    END

    IF @accion = 3
    BEGIN
        IF ISNULL(@newpass, '') = '' THROW 52003, 'Escriba la nueva contraseña.', 1;

        SELECT @usuario = Id_Usuario_FK FROM dbo.Sys_RecuperacionClave
        WHERE Id_Recuperacion = @id AND Verificado IS NOT NULL AND Usado IS NULL AND Anulado = 0
          AND Verificado > DATEADD(MINUTE, -@MinutosCambio, GETDATE());
        IF @usuario IS NULL BEGIN SELECT 'VENCIDO' AS Resultado; RETURN; END

        -- No se permite repetir la contraseña actual ni las 3 anteriores
        IF EXISTS (SELECT 1 FROM dbo.Sys_Usuarios WHERE Id_Usuario = @usuario AND ClaveAcceso = @newpass)
           OR EXISTS (SELECT 1 FROM (SELECT TOP 3 Clave FROM dbo.Sys_UsuarioHistoricoClave
                                     WHERE Id_Usuario_FK = @usuario ORDER BY FechaCreacion DESC) AS h WHERE h.Clave = @newpass)
        BEGIN SELECT 'REPETIDA' AS Resultado; RETURN; END

        DECLARE @propia bit = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
        BEGIN TRY
            IF @propia = 1 BEGIN TRANSACTION;

            INSERT INTO dbo.Sys_UsuarioHistoricoClave (Id_Usuario_FK, Clave, FechaCreacion, Id_UsuarioCrea_FK)
            SELECT Id_Usuario, ClaveAcceso, GETDATE(), Id_Usuario FROM dbo.Sys_Usuarios
            WHERE Id_Usuario = @usuario AND ISNULL(ClaveAcceso, '') <> '';

            UPDATE dbo.Sys_Usuarios SET ClaveAcceso = @newpass, FechaCambioclave = GETDATE(),
                   FechaModificacion = GETDATE(), Id_UsuarioModifica_FK = @usuario
            WHERE Id_Usuario = @usuario;

            UPDATE dbo.Sys_RecuperacionClave SET Usado = GETDATE() WHERE Id_Recuperacion = @id;
            UPDATE dbo.Sys_RecuperacionClave SET Anulado = 1
            WHERE Id_Usuario_FK = @usuario AND Usado IS NULL AND Anulado = 0;

            IF @propia = 1 COMMIT TRANSACTION;
        END TRY
        BEGIN CATCH
            IF @propia = 1 AND @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
            THROW;
        END CATCH

        SELECT 'OK' AS Resultado, @usuario AS Id_Usuario;
        RETURN;
    END;

    THROW 52000, 'Acción no válida.', 1;
END
GO
