/* =====================================================================
   DPieCenter - Procedimientos del login anterior (login.aspx.cs: mtd_leeEmpresa, leeEmpresaByUsuario, leeSesionesByUsuario)

   Solo existían en la base de desarrollo. La pantalla actual de login (assets/js/login.js) ya no llama esos
   WebMethods, pero se dejan para que no fallen si algo los usa:
     Sys_SP_InfoEmpresa          sistema de una sola empresa: @Accion 10 devuelve 0 (sin empresas configuradas)
     Sys_SP_UsuarioCierreSesion  marca la sesión del usuario como cerrada y devuelve 0
   Script idempotente.
   ===================================================================== */
SET NOCOUNT ON;
GO

CREATE OR ALTER PROCEDURE dbo.Sys_SP_InfoEmpresa
     @IdEmpresa             bigint        = 0
    ,@Empresa               varchar(250)  = NULL
    ,@Abreviado             varchar(50)   = NULL
    ,@LogoEmpresa           varchar(max)  = NULL
    ,@usuarioCreacion       varchar(20)   = NULL
    ,@usuarioModificacion   varchar(20)   = NULL
    ,@LogoCliente           varchar(max)  = NULL
    ,@LogoTituloPagina      varchar(max)  = NULL
    ,@TituloPagina          varchar(250)  = NULL
    ,@LogoMenuAplicativo    varchar(max)  = NULL
    ,@ImagenFonoLogin       varchar(max)  = NULL
    ,@ImagenFondoAplicativo varchar(max)  = NULL
    ,@NombreSistema         varchar(250)  = NULL
    ,@MensajeBienvenida     varchar(max)  = NULL
    ,@TituloBienvenida      varchar(250)  = NULL
    ,@SignoMonedaLocal      varchar(10)   = NULL
    ,@SignoMonedaDolar      varchar(10)   = NULL
    ,@HoraInicio            varchar(10)   = NULL
    ,@HoraFinal             varchar(10)   = NULL
    ,@Lunes                 bit           = 1
    ,@Martes                bit           = 1
    ,@Miercoles             bit           = 1
    ,@Jueves                bit           = 1
    ,@Viernes               bit           = 1
    ,@Sabado                bit           = 1
    ,@Domingo               bit           = 1
    ,@Accion                bigint        = 10
AS
BEGIN
    SET NOCOUNT ON;
    IF @Accion = 10
    BEGIN
        SELECT CAST(0 AS bigint) AS IdEmpresa;      -- login.aspx.cs: 0 = sin empresa configurada
        RETURN;
    END

    -- Datos para la pantalla de inicio (logo de Opciones > Empresa; el resto lo pone la página)
    SELECT TOP 1
         CAST('' AS varchar(10)) AS ImagenFonoLogin
        ,ISNULL(CAST(LogoEmpresa AS varchar(max)), '') AS LogoEmpresa
        ,CAST('' AS varchar(10)) AS LogoCliente
        ,CAST('' AS varchar(10)) AS LogoTituloPagina
        ,CAST('D'' Pie Center' AS varchar(50)) AS TituloPagina
        ,CAST('D'' Pie Center' AS varchar(50)) AS NombreSistema
        ,CAST('Bienvenido' AS varchar(50)) AS TituloBienvenida
        ,CAST('' AS varchar(10)) AS MensajeBienvenida
        ,CAST('' AS varchar(10)) AS Agencia
    FROM dbo.Sys_ConfiguracionApp;
    SELECT 'OK' AS resp;
END
GO

CREATE OR ALTER PROCEDURE dbo.Sys_SP_UsuarioCierreSesion
    @IdUsuario varchar(20)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Sys_Usuarios
       SET SesionUsuario = 'I', FechaFinSesion = GETDATE()
     WHERE Id_Usuario = @IdUsuario;
    SELECT 0 AS Sesiones;      -- login.aspx.cs: 0 = sin sesión abierta
END
GO
