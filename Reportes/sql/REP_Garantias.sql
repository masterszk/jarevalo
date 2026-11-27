/* =====================================================================
   DPieCenter - Reporte de Garantía de Servicios (Reportes/frm_repGarantias.aspx)

   REP_SP_Garantias @accion:
     1 detalle de las garantías registradas en el periodo (fecha de registro), con paciente, especialista,
       procedimiento, tratamientos y si el especialista ya la vio.
       Filtros: @especialista, @visto (0 todas | 1 no vistas | 2 vistas), @tratamiento (el procedimiento lo incluye),
       @paciente (nombre, documento o celular), @sucursal (la del procedimiento; 0 = todas)
     2 procedimientos finalizados del periodo por especialista (para el % de garantías)
   Script idempotente: se puede ejecutar varias veces.
   ===================================================================== */
SET NOCOUNT ON;
GO

CREATE OR ALTER PROCEDURE [dbo].[REP_SP_Garantias]
     @accion       int
    ,@desde        date
    ,@hasta        date
    ,@especialista bigint = 0
    ,@visto        int = 0
    ,@tratamiento  bigint = 0
    ,@paciente     varchar(100) = NULL
    ,@sucursal     int = 0
AS
BEGIN
    SET NOCOUNT ON;
    declare @fin date = DATEADD(DAY, 1, @hasta)
    set @paciente = NULLIF(LTRIM(RTRIM(@paciente)), '')

    if @accion = 1
    begin
        select r.Id_Reclamo
            ,r.FechaCrea as Fecha
            ,r.UsuarioCrea as Usuario
            ,r.FechaModifica, r.UsuarioModifica
            ,r.Reclamo
            ,r.Id_Especialista_FK as Id_Especialista, ISNULL(s.Descripcion, '') as Especialista
            ,r.Id_Expediente_fk as Id_Expediente
            ,LTRIM(RTRIM(ISNULL(e.Nombres, '') + ' ' + ISNULL(e.Apellidos, ''))) as Paciente
            ,ISNULL(e.Documento, '') as Documento, ISNULL(e.Celular, '') as Celular
            ,r.Id_Procedimiento_FK as Id_Procedimiento, p.Fecha as FechaProcedimiento
            ,ISNULL(STUFF((select ', ' + t.Descripcion from EXP_PROCEDIMIENTOSTRATAMIENTOS as t
                           where t.Id_Procedimiento_FK = r.Id_Procedimiento_FK order by t.Descripcion
                           for xml path(''), type).value('.', 'varchar(max)'), 1, 2, ''), '') as Tratamientos
            ,ISNULL(r.Visto, 0) as Visto, r.FechaVisto, r.UsuarioVisto
            ,ISNULL(su.Nombre, '') as Sucursal
        from EXP_Reclamos as r
            left join CAT_ESPECIALISTAS as s on s.Id_Especialista = r.Id_Especialista_FK
            left join EXP_EXPEDIENTES as e on e.Id_Expediente = r.Id_Expediente_fk
            left join EXP_PROCEDIMIENTOS as p on p.Id_Procedimiento = r.Id_Procedimiento_FK
            left join CAT_SUCURSALES as su on su.Id_Sucursal = p.Id_Sucursal_FK
        where r.FechaCrea >= @desde and r.FechaCrea < @fin
            and (@especialista = 0 or r.Id_Especialista_FK = @especialista)
            and (@visto = 0 or (@visto = 1 and ISNULL(r.Visto, 0) = 0) or (@visto = 2 and r.Visto = 1))
            and (@tratamiento = 0 or exists (select 1 from EXP_PROCEDIMIENTOSTRATAMIENTOS as t
                                             where t.Id_Procedimiento_FK = r.Id_Procedimiento_FK and t.Id_Tratamiento_FK = @tratamiento))
            and (@sucursal = 0 or p.Id_Sucursal_FK = @sucursal)
            and (@paciente is null or e.Nombres + ' ' + e.Apellidos like '%' + @paciente + '%'
                 or e.Documento like '%' + @paciente + '%' or e.Celular like '%' + @paciente + '%')
        order by r.FechaCrea desc, r.Id_Reclamo desc
        return
    end

    if @accion = 2
    begin
        select p.Id_Especialista_fk as Id_Especialista, ISNULL(s.Descripcion, '') as Especialista, COUNT(*) as Procedimientos
        from EXP_PROCEDIMIENTOS as p
            left join CAT_ESPECIALISTAS as s on s.Id_Especialista = p.Id_Especialista_fk
        where p.Estado = 'F' and p.Fecha >= @desde and p.Fecha < @fin
            and (@especialista = 0 or p.Id_Especialista_fk = @especialista)
            and (@sucursal = 0 or p.Id_Sucursal_FK = @sucursal)
            and (@tratamiento = 0 or exists (select 1 from EXP_PROCEDIMIENTOSTRATAMIENTOS as t
                                             where t.Id_Procedimiento_FK = p.Id_Procedimiento and t.Id_Tratamiento_FK = @tratamiento))
        group by p.Id_Especialista_fk, s.Descripcion
        return
    end;

    THROW 50099, 'Acción no válida.', 1;
END
GO

/* ---------- Menú: Reportes > Garantía de Servicios (mismos grupos que los demás reportes) ---------- */
IF NOT EXISTS (SELECT 1 FROM dbo.Sys_Opciones WHERE AccesoURL = 'Reportes/frm_repGarantias.aspx')
BEGIN
    BEGIN TRANSACTION;
    DECLARE @opcion bigint;
    INSERT INTO dbo.Sys_Opciones (Descripcion, Abreviado, AccesoURL, IdModulo_FK, Id_UsuarioCrea_FK, FechaCreacion, Orden)
    VALUES ('Garantía de Servicios', 'GS', 'Reportes/frm_repGarantias.aspx', 6, 'admin', GETDATE(), 6);
    SET @opcion = SCOPE_IDENTITY();
    INSERT INTO dbo.Sys_Permisos (IdAplicativo_FK, IdModulo_FK, IdOpcion_FK, IdGrupo_FK, Id_UsuarioCrea_FK, FechaCreacion)
    SELECT 2, 6, @opcion, g.Grupo, 'admin', GETDATE()
    FROM (VALUES ('Administradores'), ('ADMINISTRATIVOS'), ('Direccion')) as g(Grupo)
    WHERE EXISTS (SELECT 1 FROM dbo.Sys_Permisos WHERE IdGrupo_FK = g.Grupo);
    INSERT INTO dbo.Sys_AccesosObjetos (IdAplicativo_FK, IdModulo_FK, IdOpcion_FK, IdGrupo_FK, Descripcion, Accion)
    VALUES (2, 6, @opcion, 'Administradores', 'Garantía de Servicios', 1);
    COMMIT TRANSACTION;
END
GO
