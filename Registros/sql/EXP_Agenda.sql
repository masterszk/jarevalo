/* =====================================================================
   DPieCenter - Agenda y calendario de citas (Registros/CitasRepository.cs, AgendaService.cs)

   Procedimientos que la aplicación llama y que solo existían en la base de desarrollo (no estaban en ningún script):
     EXP_SP_Especialistas, EXP_SP_TiposCitas, EXP_SP_EstadoCitas   catálogos con @accion = 1
     EXP_SP_CitasViewData                                          detalle de una cita (modal del calendario)
     EXP_SP_CitaUpdate                                             editar profesional, estado y horario de una cita
     EXP_SP_CitasBuscaExp                                          búsqueda de pacientes del asistente de citas
     EXP_SP_ListaFechasAgendadas, EXP_SP_ListaNumCitas             horarios ocupados y choques (las citas cobradas liberan la hora)
     EXP_SP_GetFechaFinal                                          fecha final = inicio + minutos
   Reescritos a partir de lo que espera el código (nombres de columnas y parámetros). Script idempotente.
   ===================================================================== */
SET NOCOUNT ON;
GO

/* Profesionales activos: IdProfesional, Profesional. @sucursal > 0: solo los que atienden en esa sucursal. */
CREATE OR ALTER PROCEDURE dbo.EXP_SP_Especialistas
     @accion   int = 1
    ,@sucursal int = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT e.Id_Especialista AS IdProfesional, LTRIM(RTRIM(e.Descripcion)) AS Profesional
    FROM dbo.CAT_ESPECIALISTAS AS e
    WHERE ISNULL(e.IsActivo, 1) = 1
      AND (@sucursal = 0 OR EXISTS (SELECT 1 FROM dbo.CAT_ESPECIALISTAS_SUCURSALES AS x
                                     WHERE x.Id_Especialista_FK = e.Id_Especialista AND x.Id_Sucursal_FK = @sucursal))
    ORDER BY e.Descripcion;
END
GO

/* Tipos de cita activos: IdTipoCita, TipoCita */
CREATE OR ALTER PROCEDURE dbo.EXP_SP_TiposCitas
    @accion int = 1
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Id_TipoCita AS IdTipoCita, LTRIM(RTRIM(Descripcion)) AS TipoCita
    FROM dbo.CAT_TIPOSCITAS
    WHERE ISNULL(IsActivo, 1) = 1
    ORDER BY Id_TipoCita;
END
GO

/* Estados de cita activos: IdEstado, Estado */
CREATE OR ALTER PROCEDURE dbo.EXP_SP_EstadoCitas
    @accion int = 1
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Id_Estado AS IdEstado, LTRIM(RTRIM(Descripcion)) AS Estado
    FROM dbo.CAT_ESTADOSCITAS
    WHERE ISNULL(IsActivo, 1) = 1
    ORDER BY Id_Estado;
END
GO

/* Detalle de una cita para el modal del calendario */
CREATE OR ALTER PROCEDURE dbo.EXP_SP_CitasViewData
    @cita bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
         c.Id_Cita AS Id
        ,LTRIM(RTRIM(ISNULL(e.Nombres, '') + ' ' + ISNULL(e.Apellidos, ''))) AS Paciente
        ,ISNULL(e.Documento, '') AS Documento
        ,ISNULL(e.Email, '') AS Email
        ,COALESCE(NULLIF(e.Celular, ''), e.Telefono, '') AS Celular
        ,CASE WHEN e.FechaNacimiento IS NULL THEN ''
              ELSE CAST(DATEDIFF(YEAR, e.FechaNacimiento, GETDATE())
                        - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, e.FechaNacimiento, GETDATE()), e.FechaNacimiento) > CAST(GETDATE() AS date) THEN 1 ELSE 0 END
                        AS varchar(3)) + ' años' END AS Edad
        ,LTRIM(RTRIM(ISNULL(e.Direccion, '')
            + CASE WHEN m.Descripcion IS NULL THEN '' ELSE ', ' + m.Descripcion END
            + CASE WHEN d.Descripcion IS NULL THEN '' ELSE ', ' + d.Descripcion END)) AS Direccion
        ,ISNULL(s.Descripcion, '') AS Especialista
        ,ISNULL(tc.Descripcion, '') AS TipoCita
        ,ISNULL(ec.Descripcion, '') AS Estado
        ,ISNULL(c.FechaInicio, CAST(c.Fecha AS datetime2)) AS FechaInicio
        ,ISNULL(c.FechaFin, DATEADD(MINUTE, 60, ISNULL(c.FechaInicio, CAST(c.Fecha AS datetime2)))) AS FechaFin
        ,c.Id_Especialista_fk AS Id_Especialista
        ,c.Id_TipoCita_FK AS Id_TipoCita
        ,c.Id_EstadoCita_fk AS Id_Estado
    FROM dbo.EXP_CITAS AS c
        INNER JOIN dbo.EXP_EXPEDIENTES AS e ON e.Id_Expediente = c.Id_Expediente_fk
        LEFT JOIN dbo.CAT_MUNICIPIOS AS m ON m.Id_Municipio = e.Id_Municipio_fk
        LEFT JOIN dbo.CAT_DEPARTAMENTOS AS d ON d.Id_Departamento = m.Id_Departamento_fk
        LEFT JOIN dbo.CAT_ESPECIALISTAS AS s ON s.Id_Especialista = c.Id_Especialista_fk
        LEFT JOIN dbo.CAT_TIPOSCITAS AS tc ON tc.Id_TipoCita = c.Id_TipoCita_FK
        LEFT JOIN dbo.CAT_ESTADOSCITAS AS ec ON ec.Id_Estado = c.Id_EstadoCita_fk
    WHERE c.Id_Cita = @cita;

    -- Tratamientos de la cita (el modal los muestra solo para consulta: no se modifican ni se eliminan)
    SELECT ISNULL(NULLIF(LTRIM(RTRIM(ct.Descripcion)), ''), ISNULL(t.Descripcion, '')) AS Tratamiento
          ,CAST(ISNULL(ct.Valor, 0) AS decimal(12,2)) AS Valor
          ,ISNULL(t.Descuento, 0) AS Descuento        -- % vigente del tratamiento (Catálogos › Tratamientos)
    FROM dbo.EXP_CITASTRATAMIENTOS AS ct
        LEFT JOIN dbo.CAT_TRATAMIENTOS AS t ON t.Id_Tratamientos = ct.Id_Tratamiento_FK
    WHERE ct.Id_Cita_FK = @cita
    ORDER BY ct.Id;

    -- Pago por adelantado de la cita (Facturacion/sql/CAJ_Anticipos.sql): se conserva aunque cambien la fecha, la hora o el profesional.
    -- MontoLibre = 1: pago adelantado sin cita que se usará en esta (Monto = su saldo disponible).
    SELECT TOP 1 f.Id_factura AS IdFactura
          ,CASE WHEN f.MontoLibre = 1
                THEN ISNULL((SELECT Disponible FROM dbo.CAJ_FN_PagosAdelantados(f.Id_Expediente_FK) WHERE Id_factura = f.Id_factura), 0)
                ELSE CAST(ISNULL((SELECT SUM(TotalPagar) FROM dbo.FAC_DTE_DOCUMENTOS WHERE Id_Factura_FK = f.Id_factura AND Estado <> 'A'), 0) AS decimal(12,2)) END AS Monto
          ,(SELECT MAX(FechaEmision) FROM dbo.FAC_DTE_DOCUMENTOS WHERE Id_Factura_FK = f.Id_factura AND Estado <> 'A') AS FechaPago
          ,f.MontoLibre
    FROM dbo.CAJ_FACTURAS AS f
    WHERE f.Id_Cita_FK = @cita AND f.Anticipo = 1 AND f.Estado = 1
    ORDER BY f.MontoLibre, f.Id_factura;

    -- Pagos adelantados del paciente pendientes de agendar (para "Usar pago adelantado")
    SELECT CAST(ISNULL(SUM(p.Disponible), 0) AS decimal(12,2)) AS PagosPendientes, COUNT(*) AS Cantidad
    FROM dbo.EXP_CITAS AS c
        CROSS APPLY dbo.CAJ_FN_PagosAdelantados(c.Id_Expediente_fk) AS p
    WHERE c.Id_Cita = @cita AND p.Id_Cita IS NULL;
END
GO

/* Edita profesional y horario (el formulario ya no cambia el estado). Las reglas de horario las valida AgendaService.ActualizarCita.
   @estado NULL: si cambia el día o la hora, la cita pasa a "Reprogramada" (5, sigue vigente: se atiende en Procedimientos);
   si no cambia, conserva su estado. Una cita cancelada, finalizada o anulada no se reprograma.
   Al cambiar el horario, el procedimiento en sala de espera se cierra como reprogramado ('R') y, si el nuevo horario
   es la hora en curso de hoy, la cita vuelve a sala de espera igual que al agendarla.
   El procedimiento abierto de la cita sigue al profesional; si la cita se cancela, se cancela. */
CREATE OR ALTER PROCEDURE dbo.EXP_SP_CitaUpdate
     @cita        bigint
    ,@profesional bigint
    ,@estado      bigint = NULL
    ,@fechainicio datetime2
    ,@fechafinal  datetime2
    ,@user        varchar(20)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @reprogramada bigint = 5, @estadoActual bigint, @inicioActual datetime2, @vigente bit;
    SELECT @estadoActual = c.Id_EstadoCita_fk, @inicioActual = ISNULL(c.FechaInicio, CAST(c.Fecha AS datetime2))
          ,@vigente = CASE WHEN ISNULL(ec.Cancelada, 0) = 1 OR ISNULL(ec.Finalizada, 0) = 1 OR c.Id_EstadoCita_fk = 7 THEN 0 ELSE 1 END
    FROM dbo.EXP_CITAS AS c LEFT JOIN dbo.CAT_ESTADOSCITAS AS ec ON ec.Id_Estado = c.Id_EstadoCita_fk
    WHERE c.Id_Cita = @cita;

    IF @estadoActual IS NULL
        THROW 50080, 'La cita no existe.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.CAT_ESPECIALISTAS WHERE Id_Especialista = @profesional)
        THROW 50081, 'El profesional seleccionado no es válido.', 1;
    IF @fechafinal <= @fechainicio
        THROW 50083, 'La hora final debe ser posterior a la inicial.', 1;

    DECLARE @cambioHorario bit = CASE WHEN @fechainicio <> @inicioActual THEN 1 ELSE 0 END;
    IF @cambioHorario = 1 AND @vigente = 0
        THROW 50084, 'La cita está cancelada, finalizada o anulada: no se puede cambiar su fecha ni su hora. Agende una cita nueva.', 1;
    IF @cambioHorario = 1 AND EXISTS (SELECT 1 FROM dbo.EXP_PROCEDIMIENTOS WHERE Id_Cita_FK = @cita AND Estado = 'I')
        THROW 50085, 'El paciente está en atención: finalice o cancele la atención antes de cambiar la fecha u hora.', 1;

    IF @estado IS NULL
        SET @estado = CASE WHEN @cambioHorario = 1 THEN @reprogramada ELSE @estadoActual END;
    IF NOT EXISTS (SELECT 1 FROM dbo.CAT_ESTADOSCITAS WHERE Id_Estado = @estado)
        THROW 50082, 'El estado seleccionado no es válido.', 1;

    DECLARE @cancelada bit = (SELECT ISNULL(Cancelada, 0) FROM dbo.CAT_ESTADOSCITAS WHERE Id_Estado = @estado);
    DECLARE @propia bit = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    BEGIN TRY
        IF @propia = 1 BEGIN TRANSACTION;

        -- el paciente que esperaba en sala para el horario anterior ya no se atiende en ese horario
        IF @cambioHorario = 1
            UPDATE dbo.EXP_PROCEDIMIENTOS SET
                 Estado = 'R'
                ,Id_EstadoCita_fk = @reprogramada
                ,UsuarioModifica = @user
                ,FechaModifica = GETDATE()
            WHERE Id_Cita_FK = @cita AND Estado = 'S';

        UPDATE dbo.EXP_CITAS SET
             Id_Especialista_fk = @profesional
            ,Id_EstadoCita_fk = @estado
            ,FechaInicio = @fechainicio
            ,FechaFin = @fechafinal
            ,Fecha = CAST(@fechainicio AS date)
            ,Id_Horario_fk = dbo.EXP_FN_HorarioCita(CAST(@fechainicio AS time))
            ,Id_HorarioFin_FK = dbo.EXP_FN_HorarioCita(CAST(DATEADD(MINUTE, -1, @fechafinal) AS time))
            ,UsuarioModifica = @user
            ,FechaModifica = GETDATE()
        WHERE Id_Cita = @cita;

        UPDATE dbo.EXP_PROCEDIMIENTOS SET
             Id_Especialista_fk = @profesional
            ,Estado = CASE WHEN @cancelada = 1 THEN 'C' ELSE Estado END
            ,UsuarioModifica = @user
            ,FechaModifica = GETDATE()
        WHERE Id_Cita_FK = @cita AND Estado IN ('S', 'I');

        -- nuevo horario en la hora en curso de hoy: pasa a sala de espera (EXP_Citas_ProcedimientoEnCurso.sql)
        -- (sin INSERT EXEC: devuelve un resultado que la aplicación ignora; así se puede llamar desde otro INSERT EXEC)
        IF @cambioHorario = 1 AND @cancelada = 0
            EXEC dbo.EXP_SP_Citas_ProcedimientoEnCurso @cita = @cita, @user = @user;

        IF @propia = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @propia = 1 AND @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT 'OK' AS resp;
END
GO

/* Cancelar una cita desde el calendario (botón "Cancelar cita"). Queda en estado Cancelada: libera la hora y al
   especialista (EXP_SP_ListaFechasAgendadas / EXP_SP_ListaNumCitas no cuentan las canceladas) y sale del calendario.
   El paciente en sala de espera sale de la cola ('C'). Si el paciente está en atención se cancela desde Procedimientos.
   Si la cita estaba pagada por adelantado, lo pagado queda a favor del paciente (CAJ_Anticipos.sql).
   Devuelve Resp = 'OK' y SaldoFavor (monto pagado por adelantado que queda a favor, 0 si no había). */
CREATE OR ALTER PROCEDURE dbo.EXP_SP_CitaCancelar
     @cita   bigint
    ,@motivo varchar(250)
    ,@user   varchar(20)
AS
BEGIN
    SET NOCOUNT ON;
    SET @motivo = NULLIF(LTRIM(RTRIM(@motivo)), '');
    DECLARE @cancelada bigint = (SELECT TOP 1 Id_Estado FROM dbo.CAT_ESTADOSCITAS WHERE Cancelada = 1 ORDER BY Id_Estado);
    DECLARE @estado bigint, @vigente bit;
    SELECT @estado = c.Id_EstadoCita_fk
          ,@vigente = CASE WHEN ISNULL(ec.Cancelada, 0) = 1 OR ISNULL(ec.Finalizada, 0) = 1 OR c.Id_EstadoCita_fk = 7 THEN 0 ELSE 1 END
    FROM dbo.EXP_CITAS AS c LEFT JOIN dbo.CAT_ESTADOSCITAS AS ec ON ec.Id_Estado = c.Id_EstadoCita_fk
    WHERE c.Id_Cita = @cita;

    IF @estado IS NULL
        THROW 50080, 'La cita no existe.', 1;
    IF @vigente = 0
        THROW 50086, 'La cita ya está cancelada, finalizada o anulada.', 1;
    IF EXISTS (SELECT 1 FROM dbo.EXP_PROCEDIMIENTOS WHERE Id_Cita_FK = @cita AND Estado = 'I')
        THROW 50087, 'El paciente está en atención: cancele la atención desde Procedimientos.', 1;
    IF @motivo IS NULL OR LEN(@motivo) < 5
        THROW 50088, 'Escriba el motivo de la cancelación (al menos 5 caracteres).', 1;

    -- pago adelantado sin cita que se iba a usar en esta cita: vuelve a pendiente de agendar con su saldo
    DECLARE @libre decimal(12,2) = ISNULL((SELECT SUM(p.Disponible) FROM dbo.EXP_CITAS AS c
                                          CROSS APPLY dbo.CAJ_FN_PagosAdelantados(c.Id_Expediente_fk) AS p
                                          WHERE c.Id_Cita = @cita AND p.Id_Cita = @cita), 0);

    DECLARE @propia bit = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    BEGIN TRY
        IF @propia = 1 BEGIN TRANSACTION;

        UPDATE dbo.CAJ_FACTURAS SET Id_Cita_FK = NULL, UsuarioModifica = @user, FechaModifica = GETDATE()
        WHERE Id_Cita_FK = @cita AND Anticipo = 1 AND MontoLibre = 1 AND Estado = 1;

        UPDATE dbo.EXP_CITAS SET
             Id_EstadoCita_fk = @cancelada
            ,Comentarios = LEFT(LTRIM(ISNULL(Comentarios + ' | ', '') + 'Cancelada: ' + @motivo), 1000)
            ,UsuarioModifica = @user
            ,FechaModifica = GETDATE()
        WHERE Id_Cita = @cita;

        -- el paciente que esperaba en sala sale de la cola
        UPDATE dbo.EXP_PROCEDIMIENTOS SET
             Estado = 'C'
            ,Id_EstadoCita_fk = @cancelada
            ,FinalProcedimiento = GETDATE()
            ,UsuarioModifica = @user
            ,FechaModifica = GETDATE()
        WHERE Id_Cita_FK = @cita AND Estado = 'S';

        IF @propia = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @propia = 1 AND @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT 'OK' AS Resp
        ,CAST(ISNULL((SELECT SUM(d.TotalPagar) FROM dbo.CAJ_FACTURAS AS f
                        INNER JOIN dbo.FAC_DTE_DOCUMENTOS AS d ON d.Id_Factura_FK = f.Id_factura AND d.Estado <> 'A'
                      WHERE f.Id_Cita_FK = @cita AND f.Anticipo = 1 AND f.MontoLibre = 0 AND f.Estado = 1 AND f.Id_Procedimiento_FK IS NULL), 0) + @libre AS decimal(12,2)) AS SaldoFavor;
END
GO

/* Búsqueda de pacientes (asistente de citas). @accion 1: nombre (todas las palabras), 2: documento.
   Columnas por posición: Codigo, Nombre, Documento, Celular (sin NULL). AgendaService muestra 25 y avisa si hay más. */
CREATE OR ALTER PROCEDURE dbo.EXP_SP_CitasBuscaExp
     @documento varchar(20)  = ''
    ,@paciente  varchar(250) = ''
    ,@user      varchar(20)  = NULL
    ,@accion    int
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @texto varchar(250) = LTRIM(RTRIM(ISNULL(CASE WHEN @accion = 2 THEN @documento ELSE @paciente END, '')));
    IF LEN(@texto) < 3 RETURN;

    IF @accion = 2
    BEGIN
        DECLARE @digitos varchar(20) = REPLACE(REPLACE(@texto, '-', ''), ' ', '');
        SELECT TOP 26
             e.Id_Expediente AS Codigo
            ,LTRIM(RTRIM(ISNULL(e.Nombres, '') + ' ' + ISNULL(e.Apellidos, ''))) AS Nombre
            ,ISNULL(e.Documento, '') AS Documento
            ,COALESCE(NULLIF(e.Celular, ''), e.Telefono, '') AS Celular
        FROM dbo.EXP_EXPEDIENTES AS e
        WHERE REPLACE(REPLACE(ISNULL(e.Documento, ''), '-', ''), ' ', '') LIKE @digitos + '%'
        ORDER BY e.Nombres, e.Apellidos;
        RETURN;
    END

    -- Por nombre: cada palabra debe aparecer en nombres o apellidos
    DECLARE @p TABLE (palabra varchar(100));
    DECLARE @resto varchar(250) = @texto + ' ', @pos int;
    WHILE LEN(@resto) > 0
    BEGIN
        SET @pos = CHARINDEX(' ', @resto);
        IF @pos > 1 INSERT @p VALUES (LEFT(@resto, @pos - 1));
        SET @resto = LTRIM(SUBSTRING(@resto, @pos + 1, 250));
    END

    SELECT TOP 26
         e.Id_Expediente AS Codigo
        ,LTRIM(RTRIM(ISNULL(e.Nombres, '') + ' ' + ISNULL(e.Apellidos, ''))) AS Nombre
        ,ISNULL(e.Documento, '') AS Documento
        ,COALESCE(NULLIF(e.Celular, ''), e.Telefono, '') AS Celular
    FROM dbo.EXP_EXPEDIENTES AS e
    WHERE NOT EXISTS (SELECT 1 FROM @p AS w
                      WHERE ISNULL(e.Nombres, '') + ' ' + ISNULL(e.Apellidos, '') NOT LIKE '%' + w.palabra + '%')
    ORDER BY e.Nombres, e.Apellidos;
END
GO

/* Horarios ocupados de un profesional (asistente de citas, paso 3: CitasRepository.ObtenerOcupados).
   Devuelve Inicio, Fin (datetime2) de las citas no canceladas que se cruzan con [@desde, @hasta).
   Una cita cuya atención ya se cobró en caja libera su horario (la hora en curso o las siguientes quedan disponibles).
   La versión de producción devolvía COUNT(1) y el asistente fallaba (InvalidCastException). */
CREATE OR ALTER PROCEDURE dbo.EXP_SP_ListaFechasAgendadas
     @profesional bigint
    ,@desde       datetime2
    ,@hasta       datetime2
    ,@cobradas    bit = 0       -- 1: devuelve solo las citas ya cobradas (horas liberadas)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT c.FechaInicio AS Inicio, c.FechaFin AS Fin
    FROM dbo.EXP_CITAS AS c
        INNER JOIN dbo.CAT_ESTADOSCITAS AS e ON e.Id_Estado = c.Id_EstadoCita_fk
    WHERE c.Id_Especialista_fk = @profesional
      AND ISNULL(e.Cancelada, 0) <> 1
      AND c.FechaInicio IS NOT NULL AND c.FechaFin IS NOT NULL
      AND c.FechaInicio < @hasta AND c.FechaFin > @desde
      AND @cobradas = CASE WHEN EXISTS (SELECT 1 FROM dbo.EXP_PROCEDIMIENTOS AS p
                                            INNER JOIN dbo.CAJ_FACTURAS AS f ON f.Id_Procedimiento_FK = p.Id_Procedimiento
                                        WHERE p.Id_Cita_FK = c.Id_Cita AND f.Estado = 1) THEN 1 ELSE 0 END   -- cobrada: libera la hora
    ORDER BY c.FechaInicio;
END
GO

/* Choques al crear una cita (CitasRepository.CrearCita, dentro de la transacción). Mismas reglas que la lista de ocupados. */
CREATE OR ALTER PROCEDURE dbo.EXP_SP_ListaNumCitas
     @profesional bigint
    ,@desde       datetime2
    ,@hasta       datetime2
AS
BEGIN
    SET NOCOUNT ON;
    SELECT COUNT(1)
    FROM dbo.EXP_CITAS AS c WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN dbo.CAT_ESTADOSCITAS AS e ON e.Id_Estado = c.Id_EstadoCita_fk
    WHERE c.Id_Especialista_fk = @profesional
      AND ISNULL(e.Cancelada, 0) <> 1
      AND c.FechaInicio < @hasta AND c.FechaFin > @desde
      AND NOT EXISTS (SELECT 1 FROM dbo.EXP_PROCEDIMIENTOS AS p
                          INNER JOIN dbo.CAJ_FACTURAS AS f ON f.Id_Procedimiento_FK = p.Id_Procedimiento
                      WHERE p.Id_Cita_FK = c.Id_Cita AND f.Estado = 1);
END
GO

/* Fecha final de un procedimiento: inicio + minutos */
CREATE OR ALTER PROCEDURE dbo.EXP_SP_GetFechaFinal
     @inicio datetime2
    ,@minute int
AS
BEGIN
    SET NOCOUNT ON;
    SELECT DATEADD(MINUTE, ISNULL(@minute, 0), @inicio) AS FechaFinal;
END
GO
