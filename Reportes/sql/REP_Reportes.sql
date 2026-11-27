/* =====================================================================
   DPieCenter - Reportes de citas, procedimientos y expedientes
   (Reportes/frm_repReporteCitas.aspx, frm_repReporteProcedimientos.aspx, frm_Expedientes.aspx)

   REP_SP_Reportes:
     @accion 1 citas | 2 procedimientos finalizados (+ sus tratamientos) | 3 expedientes registrados | 4 catálogos de los filtros
             5 pacientes por procedimientos y citas (de mayor a menor)
   Las fechas y horas se toman de FechaInicio de la cita (las citas antiguas sin FechaInicio usan Fecha y CAT_HORARIOS).
   El paciente se busca por nombre, apellido, documento o celular.
   Script idempotente: se puede ejecutar varias veces.
   ===================================================================== */
SET NOCOUNT ON;
GO

CREATE OR ALTER PROCEDURE [dbo].[REP_SP_Reportes]
	 @accion       int
	,@desde        date = null
	,@hasta        date = null
	,@especialista bigint = 0
	,@estado       bigint = 0
	,@tipoCita     bigint = 0
	,@tratamiento  bigint = 0
	,@sexo         bigint = 0
	,@departamento bigint = 0
	,@fuente       varchar(20) = null     -- Facebook | Instagram | TikTok | WhatsApp | Buscador | Recomendado | Otros | SinDato
	,@paciente     varchar(100) = null
	,@sucursal     int = 0                -- 0: todas las sucursales
AS
BEGIN
	SET NOCOUNT ON;

	/* 4: catálogos de los filtros */
	if @accion = 4
	begin
		select Id_Especialista as Id, Descripcion as Texto from CAT_ESPECIALISTAS order by IsActivo desc, Descripcion
		select Id_Estado as Id, Descripcion as Texto from CAT_ESTADOSCITAS where IsActivo = 1 order by Id_Estado
		select Id_TipoCita as Id, Descripcion as Texto from CAT_TIPOSCITAS order by Descripcion
		select Id_Tratamientos as Id, Descripcion as Texto from CAT_TRATAMIENTOS order by IsActivo desc, Descripcion
		select Id_Sexos as Id, Descripcion as Texto from CAT_SEXOS order by Descripcion
		select Id_Departamento as Id, Descripcion as Texto from CAT_DEPARTAMENTOS order by Descripcion
		return
	end

	if @desde is null or @hasta is null or @hasta < @desde
		THROW 50090, 'Seleccione un rango de fechas válido.', 1;
	if DATEDIFF(DAY, @desde, @hasta) > 731
		THROW 50091, 'El rango no puede superar dos años.', 1;

	declare @fin datetime2 = DATEADD(DAY, 1, CAST(@hasta as datetime2))
	set @paciente = NULLIF(LTRIM(RTRIM(@paciente)), '')
	declare @digitos varchar(100) = REPLACE(REPLACE(@paciente, '-', ''), ' ', '')

	-- Expedientes que coinciden con el texto del paciente (null = sin filtro)
	declare @pacientes table (Id bigint primary key)
	if @paciente is not null
		insert into @pacientes
		select Id_Expediente from EXP_EXPEDIENTES
		where (Nombres + ' ' + Apellidos) like '%' + @paciente + '%'
			or (Apellidos + ' ' + Nombres) like '%' + @paciente + '%'
			or (LEN(@digitos) >= 3 and (REPLACE(Documento, '-', '') like '%' + @digitos + '%' or Celular like '%' + @digitos + '%'))

	/* 1: citas */
	if @accion = 1
	begin
		select
			c.Id_Cita
			,ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2)) as Inicio
			,c.FechaFin
			,h.Descripcion as HoraHorario
			,e.Id_Expediente
			,LTRIM(RTRIM(e.Nombres + ' ' + e.Apellidos)) as Paciente
			,ISNULL(e.Documento, '') as Documento
			,ISNULL(e.Celular, '') as Celular
			,ISNULL(tc.Descripcion, '') as TipoCita
			,ISNULL(s.Descripcion, '') as Especialista
			,c.Id_EstadoCita_fk as Id_Estado
			,ISNULL(ec.Descripcion, '') as Estado
			,ISNULL(ec.Colors, 'secondary') as Color
			,ISNULL(ec.Cancelada, 0) as EsCancelada
			,ISNULL(ec.Finalizada, 0) as EsFinalizada
			,ISNULL(c.Comentarios, '') as Comentarios
			,ISNULL(STUFF((select ', ' + ct.Descripcion from EXP_CITASTRATAMIENTOS as ct where ct.Id_Cita_FK = c.Id_Cita
						   for xml path(''), type).value('.', 'varchar(max)'), 1, 2, ''), '') as Tratamientos
			,ISNULL((select SUM(ct.Valor) from EXP_CITASTRATAMIENTOS as ct where ct.Id_Cita_FK = c.Id_Cita), 0) as Valor
			,ISNULL(c.UsuarioCrea, '') as UsuarioCrea
			,c.FechaCrea
		from EXP_CITAS as c
			inner join EXP_EXPEDIENTES as e on e.Id_Expediente = c.Id_Expediente_fk
			left join CAT_HORARIOS as h on h.Id_Horario = c.Id_Horario_fk
			left join CAT_ESPECIALISTAS as s on s.Id_Especialista = c.Id_Especialista_fk
			left join CAT_ESTADOSCITAS as ec on ec.Id_Estado = c.Id_EstadoCita_fk
			left join CAT_TIPOSCITAS as tc on tc.Id_TipoCita = c.Id_TipoCita_FK
		where ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2)) >= @desde
			and ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2)) < @fin
			and (@especialista = 0 or c.Id_Especialista_fk = @especialista)
			and (@estado = 0 or c.Id_EstadoCita_fk = @estado)
			and (@tipoCita = 0 or c.Id_TipoCita_FK = @tipoCita)
			and (@paciente is null or c.Id_Expediente_fk in (select Id from @pacientes))
			and (@sucursal = 0 or c.Id_Sucursal_FK = @sucursal)
		order by ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2)), c.Id_Cita
		return
	end

	/* 2: procedimientos finalizados y sus tratamientos */
	if @accion = 2
	begin
		declare @procs table (Id bigint primary key)
		insert into @procs
		select p.Id_Procedimiento
		from EXP_PROCEDIMIENTOS as p
		where p.Estado = 'F' and p.Fecha >= @desde and p.Fecha <= @hasta
			and (@especialista = 0 or p.Id_Especialista_fk = @especialista)
			and (@tipoCita = 0 or p.Id_TipoCita_FK = @tipoCita)
			and (@paciente is null or p.Id_Expediente_fk in (select Id from @pacientes))
			and (@sucursal = 0 or p.Id_Sucursal_FK = @sucursal)
			and (@tratamiento = 0 or exists (select 1 from EXP_PROCEDIMIENTOSTRATAMIENTOS as t
											 where t.Id_Procedimiento_FK = p.Id_Procedimiento and t.Id_Tratamiento_FK = @tratamiento))

		select
			p.Id_Procedimiento
			,p.Fecha
			,p.InicioProcedimiento
			,p.FinalProcedimiento
			,e.Id_Expediente
			,LTRIM(RTRIM(e.Nombres + ' ' + e.Apellidos)) as Paciente
			,ISNULL(e.Documento, '') as Documento
			,ISNULL(s.Descripcion, '') as Especialista
			,ISNULL(tc.Descripcion, '') as TipoCita
			,ISNULL(p.Diagnostico, '') as Diagnostico
			,f.Id_factura as Id_Factura
			,f.Estado as FacturaCobrada
			,ISNULL(ISNULL(p.UsuarioModifica, p.UsuarioCrea), '') as Usuario
		from @procs as x
			inner join EXP_PROCEDIMIENTOS as p on p.Id_Procedimiento = x.Id
			inner join EXP_EXPEDIENTES as e on e.Id_Expediente = p.Id_Expediente_fk
			left join CAT_ESPECIALISTAS as s on s.Id_Especialista = p.Id_Especialista_fk
			left join CAT_TIPOSCITAS as tc on tc.Id_TipoCita = p.Id_TipoCita_FK
			outer apply (select top 1 Id_factura, Estado from CAJ_FACTURAS where Id_Procedimiento_FK = p.Id_Procedimiento order by Id_factura desc) as f
		order by p.Fecha, p.Id_Procedimiento

		select t.Id_Procedimiento_FK as Id_Procedimiento, ISNULL(t.Descripcion, '') as Descripcion, ISNULL(t.Valor, 0) as Valor
		from EXP_PROCEDIMIENTOSTRATAMIENTOS as t
			inner join @procs as x on x.Id = t.Id_Procedimiento_FK
		order by t.Id_Procedimiento_FK, t.Id
		return
	end

	/* 3: expedientes registrados en el rango */
	if @accion = 3
	begin
		select
			e.Id_Expediente
			,e.FechaCrea
			,ISNULL(e.Documento, '') as Documento
			,ISNULL(td.Descripcion, '') as TipoDocumento
			,LTRIM(RTRIM(e.Nombres + ' ' + e.Apellidos)) as Paciente
			,e.FechaNacimiento
			,ISNULL(sx.Descripcion, '') as Sexo
			,ISNULL(e.Celular, '') as Celular
			,ISNULL(e.Email, '') as Email
			,ISNULL(m.Descripcion, '') as Municipio
			,ISNULL(d.Descripcion, '') as Departamento
			,ISNULL(e.Facebook, 0) as Facebook
			,ISNULL(e.Instagram, 0) as Instagram
			,ISNULL(e.Buscador, 0) as Buscador
			,ISNULL(e.Recomendado, 0) as Recomendado
			,ISNULL(e.TikTok, 0) as TikTok
			,ISNULL(e.WhatsApp, 0) as WhatsApp
			,ISNULL(e.Otros, 0) as Otros
			,ISNULL(v.Visitas, 0) as Visitas
			,v.UltimaVisita
			,ISNULL(e.UsuarioCrea, '') as UsuarioCrea
		from EXP_EXPEDIENTES as e
			left join CAT_TIPOSDOCUMENTOS as td on td.Id_TipoDocumento = e.Id_TipoDocumento_fk
			left join CAT_SEXOS as sx on sx.Id_Sexos = e.Id_Sexo_fk
			left join CAT_MUNICIPIOS as m on m.Id_Municipio = e.Id_Municipio_fk
			left join CAT_DEPARTAMENTOS as d on d.Id_Departamento = m.Id_Departamento_fk
			outer apply (select COUNT(distinct p.Fecha) as Visitas, MAX(p.Fecha) as UltimaVisita
						 from EXP_PROCEDIMIENTOS as p where p.Id_Expediente_fk = e.Id_Expediente and p.Estado = 'F') as v
		where e.FechaCrea >= @desde and e.FechaCrea < @fin
			and (@sexo = 0 or e.Id_Sexo_fk = @sexo)
			and (@departamento = 0 or m.Id_Departamento_fk = @departamento)
			and (@paciente is null or e.Id_Expediente in (select Id from @pacientes))
			and (@sucursal = 0 or e.Id_Sucursal_FK = @sucursal)       -- sucursal donde se registró
			and (@fuente is null
				 or (@fuente = 'Facebook' and e.Facebook = 1)
				 or (@fuente = 'Instagram' and e.Instagram = 1)
				 or (@fuente = 'Buscador' and e.Buscador = 1)
				 or (@fuente = 'Recomendado' and e.Recomendado = 1)
				 or (@fuente = 'TikTok' and e.TikTok = 1)
				 or (@fuente = 'WhatsApp' and e.WhatsApp = 1)
				 or (@fuente = 'Otros' and e.Otros = 1)
				 or (@fuente = 'SinDato' and ISNULL(e.Facebook,0) = 0 and ISNULL(e.Instagram,0) = 0 and ISNULL(e.Buscador,0) = 0 and ISNULL(e.Recomendado,0) = 0
					 and ISNULL(e.TikTok,0) = 0 and ISNULL(e.WhatsApp,0) = 0 and ISNULL(e.Otros,0) = 0))
		order by e.FechaCrea, e.Id_Expediente
		return
	end;

	/* 5: pacientes por procedimientos y citas en el rango, de mayor a menor (Reportes/frm_repPacientesActividad.aspx).
	      Citas: todas menos las anuladas (se separan atendidas y canceladas). Procedimientos: finalizados.
	      Valor: suma de los tratamientos de los procedimientos con el descuento vigente de cada tratamiento. */
	if @accion = 5
	begin
		declare @anulada bigint = 7
		declare @canc bigint = (select top 1 Id_Estado from CAT_ESTADOSCITAS where Cancelada = 1 order by Id_Estado)
		declare @fina bigint = (select top 1 Id_Estado from CAT_ESTADOSCITAS where Finalizada = 1 order by Id_Estado)

		;with ci as (
			select c.Id_Expediente_fk as Id_Expediente
				,COUNT(*) as Citas
				,SUM(case when c.Id_EstadoCita_fk = @fina then 1 else 0 end) as Atendidas
				,SUM(case when c.Id_EstadoCita_fk = @canc then 1 else 0 end) as Canceladas
				,MAX(ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2))) as UltimaCita
			from EXP_CITAS as c
			where ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2)) >= @desde
				and ISNULL(c.FechaInicio, CAST(c.Fecha as datetime2)) < @fin
				and ISNULL(c.Id_EstadoCita_fk, 0) <> @anulada
				and (@especialista = 0 or c.Id_Especialista_fk = @especialista)
				and (@sucursal = 0 or c.Id_Sucursal_FK = @sucursal)
			group by c.Id_Expediente_fk
		), pr as (
			select p.Id_Expediente_fk as Id_Expediente
				,COUNT(*) as Procedimientos
				,COUNT(distinct p.Fecha) as Visitas
				,MAX(p.Fecha) as UltimoProcedimiento
				,SUM(ISNULL(v.Valor, 0)) as Valor
			from EXP_PROCEDIMIENTOS as p
				outer apply (select SUM(t.Valor - ROUND(t.Valor * ISNULL(ct.Descuento, 0) / 100, 2)) as Valor
							 from EXP_PROCEDIMIENTOSTRATAMIENTOS as t left join CAT_TRATAMIENTOS as ct on ct.Id_Tratamientos = t.Id_Tratamiento_FK
							 where t.Id_Procedimiento_FK = p.Id_Procedimiento) as v
			where p.Estado = 'F' and p.Fecha >= @desde and p.Fecha <= @hasta
				and (@especialista = 0 or p.Id_Especialista_fk = @especialista)
				and (@sucursal = 0 or p.Id_Sucursal_FK = @sucursal)
			group by p.Id_Expediente_fk
		)
		select
			e.Id_Expediente
			,LTRIM(RTRIM(e.Nombres + ' ' + e.Apellidos)) as Paciente
			,ISNULL(e.Documento, '') as Documento
			,ISNULL(e.Celular, '') as Celular
			,e.FechaNacimiento
			,ISNULL(pr.Procedimientos, 0) as Procedimientos
			,ISNULL(pr.Visitas, 0) as Visitas
			,CAST(ISNULL(pr.Valor, 0) as decimal(12,2)) as Valor
			,pr.UltimoProcedimiento
			,ISNULL(ci.Citas, 0) as Citas
			,ISNULL(ci.Atendidas, 0) as Atendidas
			,ISNULL(ci.Canceladas, 0) as Canceladas
			,ci.UltimaCita
		from EXP_EXPEDIENTES as e
			left join ci on ci.Id_Expediente = e.Id_Expediente
			left join pr on pr.Id_Expediente = e.Id_Expediente
		where (ci.Id_Expediente is not null or pr.Id_Expediente is not null)
			and (@paciente is null or e.Id_Expediente in (select Id from @pacientes))
		order by ISNULL(pr.Procedimientos, 0) desc, ISNULL(ci.Citas, 0) desc, ISNULL(pr.Valor, 0) desc, Paciente
		return
	end;

	THROW 50099, 'Acción no válida.', 1;
END
GO

/* ---------- Menú: Reportes > Pacientes por actividad (mismos grupos que los demás reportes) ---------- */
IF NOT EXISTS (SELECT 1 FROM dbo.Sys_Opciones WHERE AccesoURL = 'Reportes/frm_repPacientesActividad.aspx')
BEGIN
    BEGIN TRANSACTION;
    DECLARE @opcion bigint;
    INSERT INTO dbo.Sys_Opciones (Descripcion, Abreviado, AccesoURL, IdModulo_FK, Id_UsuarioCrea_FK, FechaCreacion, Orden)
    VALUES ('Pacientes por actividad', 'PA', 'Reportes/frm_repPacientesActividad.aspx', 6, 'admin', GETDATE(), 5);
    SET @opcion = SCOPE_IDENTITY();
    INSERT INTO dbo.Sys_Permisos (IdAplicativo_FK, IdModulo_FK, IdOpcion_FK, IdGrupo_FK, Id_UsuarioCrea_FK, FechaCreacion)
    SELECT 2, 6, @opcion, g.Grupo, 'admin', GETDATE()
    FROM (VALUES ('Administradores'), ('ADMINISTRATIVOS'), ('Direccion')) as g(Grupo)
    WHERE EXISTS (SELECT 1 FROM dbo.Sys_Permisos WHERE IdGrupo_FK = g.Grupo);
    INSERT INTO dbo.Sys_AccesosObjetos (IdAplicativo_FK, IdModulo_FK, IdOpcion_FK, IdGrupo_FK, Descripcion, Accion)
    VALUES (2, 6, @opcion, 'Administradores', 'Pacientes por actividad', 1);
    COMMIT TRANSACTION;
END
GO
