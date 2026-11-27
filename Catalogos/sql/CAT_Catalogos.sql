/* =====================================================================
   DPieCenter - Catálogos (menú Catálogos)

   CAT_SP_Catalogos: lista, guarda, activa / inactiva y elimina los registros de los catálogos con validaciones
   (THROW 5xxxx con mensaje para el usuario). Lo usa Catalogos/CatalogosRepository.cs.
   @catalogo: departamentos | municipios | sexos | especialistas | estados | horarios | tratamientos | tiposdocumento | tiposcita
   @accion:   1 lista   2 guardar (@id = 0 agrega)   3 eliminar   4 activar / inactivar (@activo)

   La lista devuelve las mismas columnas para todos los catálogos (las que no aplican van en NULL) y "Usos":
   cuántos registros lo usan. Un registro en uso no se puede eliminar; se inactiva para que no aparezca en las listas.
   No modifica los SP anteriores (CAT_SP_Departamentos, ...).
   Script idempotente: se puede ejecutar varias veces.
   ===================================================================== */
SET NOCOUNT ON;
GO

-- Descuento del tratamiento en % (0 = sin descuento). Se aplica al cobrar: en la factura va en valores
-- (montoDescu de la línea y totalDescu) y las pantallas muestran el precio con descuento.
IF COL_LENGTH('dbo.CAT_TRATAMIENTOS', 'Descuento') IS NULL
	ALTER TABLE dbo.CAT_TRATAMIENTOS ADD Descuento decimal(5,2) NOT NULL CONSTRAINT DF_CAT_TRATAMIENTOS_Descuento DEFAULT (0);
GO

CREATE OR ALTER PROCEDURE [dbo].[CAT_SP_Catalogos]
	 @catalogo        varchar(30)
	,@accion          int
	,@usuario         varchar(20)   = NULL
	,@id              bigint        = 0
	,@descripcion     varchar(250)  = NULL
	,@activo          bit           = 1
	,@padre           bigint        = 0      -- departamento del municipio
	,@usuarioSistema  varchar(20)   = NULL   -- usuario del especialista
	,@color           varchar(20)   = NULL
	,@procesos        bit           = 0
	,@cancelada       bit           = 0
	,@finalizada      bit           = 0
	,@hora            time          = NULL
	,@digitos         int           = 0
	,@formato         varchar(20)   = NULL
	,@duracion        int           = 0
	,@precio          decimal(10,2) = 0
	,@caracteristicas varchar(max)  = NULL
	,@imagen          varchar(300)  = NULL   -- NULL conserva la imagen; '-' la quita
	,@descuento       decimal(5,2)  = 0      -- tratamientos: descuento en %
AS
BEGIN
	SET NOCOUNT ON;

	set @catalogo = LOWER(LTRIM(RTRIM(@catalogo)))
	set @descripcion = NULLIF(LTRIM(RTRIM(@descripcion)), '')
	set @usuarioSistema = NULLIF(LTRIM(RTRIM(@usuarioSistema)), '')
	set @formato = NULLIF(LTRIM(RTRIM(@formato)), '')
	set @caracteristicas = NULLIF(LTRIM(RTRIM(@caracteristicas)), '')

	if @catalogo not in ('departamentos', 'municipios', 'sexos', 'especialistas', 'estados', 'horarios', 'tratamientos', 'tiposdocumento', 'tiposcita', 'tiposfactura')
		THROW 50300, 'Catálogo no válido.', 1;

	/* ================= 1: lista ================= */
	if @accion = 1
	begin
		if @catalogo = 'departamentos'
			select d.Id_Departamento as Id, d.Descripcion, CAST(1 as bit) as Activo
				,(select COUNT(*) from CAT_MUNICIPIOS where Id_Departamento_fk = d.Id_Departamento)
				 + (select COUNT(*) from Sys_ConfiguracionApp where Departamento = d.Id_Departamento) as Usos
				,CAST(NULL as bigint) as Padre, CAST(NULL as varchar(250)) as PadreTexto, CAST(NULL as varchar(20)) as UsuarioSistema
				,CAST(NULL as varchar(20)) as Color, CAST(NULL as bit) as Procesos, CAST(NULL as bit) as Cancelada, CAST(NULL as bit) as Finalizada
				,CAST(NULL as time) as Hora, CAST(NULL as int) as Digitos, CAST(NULL as varchar(20)) as Formato
				,CAST(NULL as int) as Duracion, CAST(NULL as decimal(10,2)) as Precio, CAST(NULL as varchar(max)) as Caracteristicas, CAST(NULL as varchar(max)) as Imagen
				,ISNULL(d.UsuarioModifica, d.UsuarioCrea) as Usuario, ISNULL(d.FechaModifica, d.FechaCrea) as Fecha
			from CAT_DEPARTAMENTOS as d
			order by d.Descripcion
		else if @catalogo = 'municipios'
			select m.Id_Municipio as Id, m.Descripcion, CAST(1 as bit) as Activo
				,(select COUNT(*) from EXP_EXPEDIENTES where Id_Municipio_fk = m.Id_Municipio)
				 + (select COUNT(*) from Sys_ConfiguracionApp where Municipio = m.Id_Municipio) as Usos
				,m.Id_Departamento_fk as Padre, d.Descripcion as PadreTexto, CAST(NULL as varchar(20)) as UsuarioSistema
				,CAST(NULL as varchar(20)) as Color, CAST(NULL as bit) as Procesos, CAST(NULL as bit) as Cancelada, CAST(NULL as bit) as Finalizada
				,CAST(NULL as time) as Hora, CAST(NULL as int) as Digitos, CAST(NULL as varchar(20)) as Formato
				,CAST(NULL as int) as Duracion, CAST(NULL as decimal(10,2)) as Precio, CAST(NULL as varchar(max)) as Caracteristicas, CAST(NULL as varchar(max)) as Imagen
				,ISNULL(m.UsuarioModifica, m.UsuarioCrea) as Usuario, ISNULL(m.FechaModifica, m.FechaCrea) as Fecha
			from CAT_MUNICIPIOS as m
				left join CAT_DEPARTAMENTOS as d on d.Id_Departamento = m.Id_Departamento_fk
			order by d.Descripcion, m.Descripcion
		else if @catalogo = 'sexos'
			select s.Id_Sexos as Id, s.Descripcion, s.IsActivo as Activo
				,(select COUNT(*) from EXP_EXPEDIENTES where Id_Sexo_fk = s.Id_Sexos) as Usos
				,CAST(NULL as bigint) as Padre, CAST(NULL as varchar(250)) as PadreTexto, CAST(NULL as varchar(20)) as UsuarioSistema
				,CAST(NULL as varchar(20)) as Color, CAST(NULL as bit) as Procesos, CAST(NULL as bit) as Cancelada, CAST(NULL as bit) as Finalizada
				,CAST(NULL as time) as Hora, CAST(NULL as int) as Digitos, CAST(NULL as varchar(20)) as Formato
				,CAST(NULL as int) as Duracion, CAST(NULL as decimal(10,2)) as Precio, CAST(NULL as varchar(max)) as Caracteristicas, CAST(NULL as varchar(max)) as Imagen
				,ISNULL(s.UsuarioModifica, s.UsuarioCrea) as Usuario, ISNULL(s.FechaModifica, s.FechaCrea) as Fecha
			from CAT_SEXOS as s
			order by s.Descripcion
		else if @catalogo = 'especialistas'
			select e.Id_Especialista as Id, e.Descripcion, e.IsActivo as Activo
				,(select COUNT(*) from EXP_CITAS where Id_Especialista_fk = e.Id_Especialista)
				 + (select COUNT(*) from EXP_PROCEDIMIENTOS where Id_Especialista_fk = e.Id_Especialista) as Usos
				,CAST(NULL as bigint) as Padre
				,LTRIM(RTRIM(ISNULL(u.Nombres, '') + ' ' + ISNULL(u.Apellidos, ''))) as PadreTexto
				,e.UsaurioSystem as UsuarioSistema
				,CAST(NULL as varchar(20)) as Color, CAST(NULL as bit) as Procesos, CAST(NULL as bit) as Cancelada, CAST(NULL as bit) as Finalizada
				,CAST(NULL as time) as Hora, CAST(NULL as int) as Digitos, CAST(NULL as varchar(20)) as Formato
				,CAST(NULL as int) as Duracion, CAST(NULL as decimal(10,2)) as Precio, CAST(NULL as varchar(max)) as Caracteristicas, CAST(NULL as varchar(max)) as Imagen
				,ISNULL(e.UsuarioModifica, e.UsuarioCrea) as Usuario, ISNULL(e.FechaModifica, e.FechaCrea) as Fecha
			from CAT_ESPECIALISTAS as e
				left join Sys_Usuarios as u on u.Id_Usuario = e.UsaurioSystem
			order by e.IsActivo desc, e.Descripcion
		else if @catalogo = 'estados'
			select s.Id_Estado as Id, s.Descripcion, s.IsActivo as Activo
				,(select COUNT(*) from EXP_CITAS where Id_EstadoCita_fk = s.Id_Estado) as Usos
				,CAST(NULL as bigint) as Padre, CAST(NULL as varchar(250)) as PadreTexto, CAST(NULL as varchar(20)) as UsuarioSistema
				,s.Colors as Color, ISNULL(s.Procesos, 0) as Procesos, ISNULL(s.Cancelada, 0) as Cancelada, ISNULL(s.Finalizada, 0) as Finalizada
				,CAST(NULL as time) as Hora, CAST(NULL as int) as Digitos, CAST(NULL as varchar(20)) as Formato
				,CAST(NULL as int) as Duracion, CAST(NULL as decimal(10,2)) as Precio, CAST(NULL as varchar(max)) as Caracteristicas, CAST(NULL as varchar(max)) as Imagen
				,ISNULL(s.UsuarioModifica, s.UsuarioCrea) as Usuario, ISNULL(s.FechaModifica, s.FechaCrea) as Fecha
			from CAT_ESTADOSCITAS as s
			order by s.Id_Estado
		else if @catalogo = 'horarios'
			select h.Id_Horario as Id, h.Descripcion, h.IsActivo as Activo
				,(select COUNT(*) from EXP_CITAS where Id_Horario_fk = h.Id_Horario or Id_HorarioFin_FK = h.Id_Horario)
				 + (select COUNT(*) from EXP_PROCEDIMIENTOS where Id_Horario_fk = h.Id_Horario or Id_Horariofin_fk = h.Id_Horario) as Usos
				,CAST(NULL as bigint) as Padre, CAST(NULL as varchar(250)) as PadreTexto, CAST(NULL as varchar(20)) as UsuarioSistema
				,CAST(NULL as varchar(20)) as Color, CAST(NULL as bit) as Procesos, CAST(NULL as bit) as Cancelada, CAST(NULL as bit) as Finalizada
				,h.Hora, CAST(NULL as int) as Digitos, CAST(NULL as varchar(20)) as Formato
				,CAST(NULL as int) as Duracion, CAST(NULL as decimal(10,2)) as Precio, CAST(NULL as varchar(max)) as Caracteristicas, CAST(NULL as varchar(max)) as Imagen
				,ISNULL(h.UsuarioModifica, h.UsuarioCrea) as Usuario, ISNULL(h.FechaModifica, h.FechaCrea) as Fecha
			from CAT_HORARIOS as h
			order by h.Hora, h.Descripcion
		else if @catalogo = 'tratamientos'
			select t.Id_Tratamientos as Id, t.Descripcion, t.IsActivo as Activo
				,(select COUNT(*) from EXP_CITAS where Id_Tratamiento_fk = t.Id_Tratamientos)
				 + (select COUNT(*) from EXP_PROCEDIMIENTOSTRATAMIENTOS where Id_Tratamiento_FK = t.Id_Tratamientos)
				 + (select COUNT(*) from EXP_CUPONES where Id_Tratamiento_FK = t.Id_Tratamientos) as Usos
				,CAST(NULL as bigint) as Padre, CAST(NULL as varchar(250)) as PadreTexto, CAST(NULL as varchar(20)) as UsuarioSistema
				,CAST(NULL as varchar(20)) as Color, CAST(NULL as bit) as Procesos, CAST(NULL as bit) as Cancelada, CAST(NULL as bit) as Finalizada
				,CAST(NULL as time) as Hora, CAST(NULL as int) as Digitos, CAST(NULL as varchar(20)) as Formato
				,t.Duracion, CAST(t.Precio as decimal(10,2)) as Precio, t.Caracteristicas, t.Imagen
				,ISNULL(t.UsuarioModifica, t.UsuarioCrea) as Usuario, ISNULL(t.FechaModifica, t.FechaCrea) as Fecha
				,t.Descuento
			from CAT_TRATAMIENTOS as t
			order by t.IsActivo desc, t.Descripcion
		else if @catalogo = 'tiposdocumento'
			select d.Id_TipoDocumento as Id, d.Descripcion, d.Estatus as Activo
				,(select COUNT(*) from EXP_EXPEDIENTES where Id_TipoDocumento_fk = d.Id_TipoDocumento) as Usos
				,CAST(NULL as bigint) as Padre, CAST(NULL as varchar(250)) as PadreTexto, CAST(NULL as varchar(20)) as UsuarioSistema
				,CAST(NULL as varchar(20)) as Color, CAST(NULL as bit) as Procesos, CAST(NULL as bit) as Cancelada, CAST(NULL as bit) as Finalizada
				,CAST(NULL as time) as Hora, ISNULL(d.Digitos, 0) as Digitos, d.Formato
				,CAST(NULL as int) as Duracion, CAST(NULL as decimal(10,2)) as Precio, CAST(NULL as varchar(max)) as Caracteristicas, CAST(NULL as varchar(max)) as Imagen
				,ISNULL(d.UsuarioModifica, d.UsuarioCrea) as Usuario, ISNULL(d.FechaModifica, d.FechaCrea) as Fecha
			from CAT_TIPOSDOCUMENTOS as d
			order by d.Id_TipoDocumento
		else if @catalogo = 'tiposfactura'
			-- el código de Hacienda (CAT-002) va en Formato; Digitos = 1 si el sistema emite ese tipo (01 y 03)
			select t.Id_TipoFactura as Id, t.Descripcion, t.Estatus as Activo
				,(select COUNT(*) from FAC_DTE_DOCUMENTOS where Id_TipoFactura_FK = t.Id_TipoFactura) as Usos
				,CAST(NULL as bigint) as Padre, CAST(NULL as varchar(250)) as PadreTexto, CAST(NULL as varchar(20)) as UsuarioSistema
				,CAST(NULL as varchar(20)) as Color, CAST(NULL as bit) as Procesos, CAST(NULL as bit) as Cancelada, CAST(NULL as bit) as Finalizada
				,CAST(NULL as time) as Hora, case when t.Codigo in ('01', '03') then 1 else 0 end as Digitos, CAST(t.Codigo as varchar(20)) as Formato
				,CAST(NULL as int) as Duracion, CAST(NULL as decimal(10,2)) as Precio, CAST(NULL as varchar(max)) as Caracteristicas, CAST(NULL as varchar(max)) as Imagen
				,ISNULL(t.UsuarioModifica, t.UsuarioCrea) as Usuario, ISNULL(t.FechaModifica, t.FechaCrea) as Fecha
			from CAT_TIPOSFACTURAS as t
			order by t.Codigo
		else
			select t.Id_TipoCita as Id, t.Descripcion, t.IsActivo as Activo
				,(select COUNT(*) from EXP_CITAS where Id_TipoCita_FK = t.Id_TipoCita)
				 + (select COUNT(*) from EXP_PROCEDIMIENTOS where Id_TipoCita_FK = t.Id_TipoCita) as Usos
				,CAST(NULL as bigint) as Padre, CAST(NULL as varchar(250)) as PadreTexto, CAST(NULL as varchar(20)) as UsuarioSistema
				,CAST(NULL as varchar(20)) as Color, CAST(NULL as bit) as Procesos, CAST(NULL as bit) as Cancelada, CAST(NULL as bit) as Finalizada
				,CAST(NULL as time) as Hora, CAST(NULL as int) as Digitos, CAST(NULL as varchar(20)) as Formato
				,CAST(NULL as int) as Duracion, CAST(NULL as decimal(10,2)) as Precio, CAST(NULL as varchar(max)) as Caracteristicas, CAST(NULL as varchar(max)) as Imagen
				,ISNULL(t.UsuarioModifica, t.UsuarioCrea) as Usuario, ISNULL(t.FechaModifica, t.FechaCrea) as Fecha
			from CAT_TIPOSCITAS as t
			order by t.Descripcion
		return
	end

	/* ================= 2: guardar ================= */
	if @accion = 2
	begin
		if @descripcion is null THROW 50301, 'Ingrese la descripción.', 1;
		if @id > 0 and not exists (
				select 1 from CAT_DEPARTAMENTOS where @catalogo = 'departamentos' and Id_Departamento = @id union all
				select 1 from CAT_MUNICIPIOS where @catalogo = 'municipios' and Id_Municipio = @id union all
				select 1 from CAT_SEXOS where @catalogo = 'sexos' and Id_Sexos = @id union all
				select 1 from CAT_ESPECIALISTAS where @catalogo = 'especialistas' and Id_Especialista = @id union all
				select 1 from CAT_ESTADOSCITAS where @catalogo = 'estados' and Id_Estado = @id union all
				select 1 from CAT_HORARIOS where @catalogo = 'horarios' and Id_Horario = @id union all
				select 1 from CAT_TRATAMIENTOS where @catalogo = 'tratamientos' and Id_Tratamientos = @id union all
				select 1 from CAT_TIPOSDOCUMENTOS where @catalogo = 'tiposdocumento' and Id_TipoDocumento = @id union all
				select 1 from CAT_TIPOSCITAS where @catalogo = 'tiposcita' and Id_TipoCita = @id union all
				select 1 from CAT_TIPOSFACTURAS where @catalogo = 'tiposfactura' and Id_TipoFactura = @id)
			THROW 50317, 'El registro ya no existe. Actualice la lista.', 1;

		-- descripción repetida
		if (@catalogo = 'departamentos' and exists (select 1 from CAT_DEPARTAMENTOS where Descripcion = @descripcion and Id_Departamento <> @id))
			or (@catalogo = 'municipios' and exists (select 1 from CAT_MUNICIPIOS where Descripcion = @descripcion and Id_Departamento_fk = @padre and Id_Municipio <> @id))
			or (@catalogo = 'sexos' and exists (select 1 from CAT_SEXOS where Descripcion = @descripcion and Id_Sexos <> @id))
			or (@catalogo = 'especialistas' and exists (select 1 from CAT_ESPECIALISTAS where Descripcion = @descripcion and Id_Especialista <> @id))
			or (@catalogo = 'estados' and exists (select 1 from CAT_ESTADOSCITAS where Descripcion = @descripcion and Id_Estado <> @id))
			or (@catalogo = 'horarios' and exists (select 1 from CAT_HORARIOS where Descripcion = @descripcion and Id_Horario <> @id))
			or (@catalogo = 'tratamientos' and exists (select 1 from CAT_TRATAMIENTOS where Descripcion = @descripcion and Id_Tratamientos <> @id))
			or (@catalogo = 'tiposdocumento' and exists (select 1 from CAT_TIPOSDOCUMENTOS where Descripcion = @descripcion and Id_TipoDocumento <> @id))
			or (@catalogo = 'tiposcita' and exists (select 1 from CAT_TIPOSCITAS where Descripcion = @descripcion and Id_TipoCita <> @id))
			or (@catalogo = 'tiposfactura' and exists (select 1 from CAT_TIPOSFACTURAS where Descripcion = @descripcion and Id_TipoFactura <> @id))
			THROW 50302, 'Ya existe un registro con esa descripción.', 1;

		if @catalogo = 'departamentos'
		begin
			if @id = 0 insert into CAT_DEPARTAMENTOS (Descripcion, UsuarioCrea, FechaCrea) values (@descripcion, @usuario, GETDATE())
			else update CAT_DEPARTAMENTOS set Descripcion = @descripcion, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_Departamento = @id
		end
		else if @catalogo = 'municipios'
		begin
			if not exists (select 1 from CAT_DEPARTAMENTOS where Id_Departamento = @padre) THROW 50303, 'Seleccione el departamento.', 1;
			if @id = 0 insert into CAT_MUNICIPIOS (Descripcion, Id_Departamento_fk, UsuarioCrea, FechaCrea) values (@descripcion, @padre, @usuario, GETDATE())
			else update CAT_MUNICIPIOS set Descripcion = @descripcion, Id_Departamento_fk = @padre, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_Municipio = @id
		end
		else if @catalogo = 'sexos'
		begin
			if @id = 0 insert into CAT_SEXOS (Descripcion, IsActivo, UsuarioCrea, FechaCrea) values (@descripcion, @activo, @usuario, GETDATE())
			else update CAT_SEXOS set Descripcion = @descripcion, IsActivo = @activo, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_Sexos = @id
		end
		else if @catalogo = 'especialistas'
		begin
			if @usuarioSistema is not null and not exists (select 1 from Sys_Usuarios where Id_Usuario = @usuarioSistema)
				THROW 50304, 'El usuario del sistema no existe.', 1;
			-- un usuario solo puede ser un especialista activo (frm_Procedimientos lo usa para mostrarle sus citas)
			if @usuarioSistema is not null and @activo = 1
				and exists (select 1 from CAT_ESPECIALISTAS where UsaurioSystem = @usuarioSistema and IsActivo = 1 and Id_Especialista <> @id)
				THROW 50305, 'Ese usuario ya está vinculado a otro especialista activo.', 1;
			if @id = 0 insert into CAT_ESPECIALISTAS (Descripcion, IsActivo, UsaurioSystem, UsuarioCrea, FechaCrea) values (@descripcion, @activo, @usuarioSistema, @usuario, GETDATE())
			else update CAT_ESPECIALISTAS set Descripcion = @descripcion, IsActivo = @activo, UsaurioSystem = @usuarioSistema, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_Especialista = @id
		end
		else if @catalogo = 'estados'
		begin
			if ISNULL(@color, '') not in ('info', 'success', 'warning', 'danger', 'secondary', 'primary') THROW 50306, 'Seleccione el color.', 1;
			if @cancelada = 1 and @finalizada = 1 THROW 50307, 'Un estado no puede ser cancelado y finalizado a la vez.', 1;
			if @cancelada = 1 and exists (select 1 from CAT_ESTADOSCITAS where Cancelada = 1 and Id_Estado <> @id)
				THROW 50308, 'Ya hay otro estado marcado como cancelado. Solo puede haber uno.', 1;
			if @finalizada = 1 and exists (select 1 from CAT_ESTADOSCITAS where Finalizada = 1 and Id_Estado <> @id)
				THROW 50309, 'Ya hay otro estado marcado como finalizado. Solo puede haber uno.', 1;
			-- los estados 1 a 7 los usa la agenda y la atención: no se les cambia el tipo
			if @id between 1 and 7 and exists (select 1 from CAT_ESTADOSCITAS where Id_Estado = @id
					and (ISNULL(Procesos, 0) <> @procesos or ISNULL(Cancelada, 0) <> @cancelada or ISNULL(Finalizada, 0) <> @finalizada or (IsActivo = 1 and @activo = 0)))
				THROW 50310, 'Este estado lo usa el sistema: solo se puede cambiar su nombre y su color.', 1;
			if @id = 0 insert into CAT_ESTADOSCITAS (Descripcion, IsActivo, Colors, Accion, Procesos, Cancelada, Finalizada, UsuarioCrea, FechaCrea)
				values (@descripcion, @activo, @color, 0, @procesos, @cancelada, @finalizada, @usuario, GETDATE())
			else update CAT_ESTADOSCITAS set Descripcion = @descripcion, IsActivo = @activo, Colors = @color, Procesos = @procesos
				,Cancelada = @cancelada, Finalizada = @finalizada, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_Estado = @id
		end
		else if @catalogo = 'horarios'
		begin
			if @hora is null THROW 50311, 'Ingrese la hora.', 1;
			if exists (select 1 from CAT_HORARIOS where Hora = @hora and Id_Horario <> @id) THROW 50312, 'Ya existe un horario con esa hora.', 1;
			if @id = 0 insert into CAT_HORARIOS (Descripcion, Hora, IsActivo, UsuarioCrea, FechaCrea) values (@descripcion, @hora, @activo, @usuario, GETDATE())
			else update CAT_HORARIOS set Descripcion = @descripcion, Hora = @hora, IsActivo = @activo, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_Horario = @id
		end
		else if @catalogo = 'tratamientos'
		begin
			if @duracion < 0 or @duracion > 600 THROW 50313, 'La duración debe estar entre 0 y 600 minutos.', 1;
			if @precio < 0 THROW 50314, 'El precio no puede ser negativo.', 1;
			set @descuento = ISNULL(@descuento, 0)
			if @descuento < 0 or @descuento >= 100 THROW 50315, 'El descuento debe estar entre 0 y 99.99 por ciento.', 1;
			if @id = 0 insert into CAT_TRATAMIENTOS (Descripcion, Duracion, Precio, Descuento, IsActivo, Caracteristicas, Imagen, UsuarioCrea, FechaCrea)
				values (@descripcion, @duracion, @precio, @descuento, @activo, @caracteristicas, NULLIF(@imagen, '-'), @usuario, GETDATE())
			else update CAT_TRATAMIENTOS set Descripcion = @descripcion, Duracion = @duracion, Precio = @precio, Descuento = @descuento, IsActivo = @activo
				,Caracteristicas = @caracteristicas
				,Imagen = case when @imagen is null then Imagen when @imagen = '-' then NULL else @imagen end
				,UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_Tratamientos = @id
		end
		else if @catalogo = 'tiposdocumento'
		begin
			if @digitos < 0 or @digitos > 30 THROW 50315, 'Los dígitos deben estar entre 0 y 30.', 1;
			if @id = 0 insert into CAT_TIPOSDOCUMENTOS (Descripcion, Estatus, Digitos, Formato, UsuarioCrea, FechaCrea) values (@descripcion, @activo, @digitos, @formato, @usuario, GETDATE())
			else update CAT_TIPOSDOCUMENTOS set Descripcion = @descripcion, Estatus = @activo, Digitos = @digitos, Formato = @formato, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_TipoDocumento = @id
		end
		else if @catalogo = 'tiposfactura'
		begin
			-- @formato = código de Hacienda (CAT-002), dos dígitos
			if @formato is null or @formato not like '[0-9][0-9]' THROW 50320, 'El código debe tener dos dígitos, como en el catálogo CAT-002 de Hacienda.', 1;
			if exists (select 1 from CAT_TIPOSFACTURAS where Codigo = @formato and Id_TipoFactura <> @id) THROW 50321, 'Ya existe un tipo de comprobante con ese código.', 1;
			if @id > 0 and exists (select 1 from CAT_TIPOSFACTURAS where Id_TipoFactura = @id and Codigo <> @formato)
				and exists (select 1 from FAC_DTE_DOCUMENTOS where Id_TipoFactura_FK = @id)
				THROW 50322, 'Ya hay documentos emitidos con este tipo: no se puede cambiar su código.', 1;
			if @id > 0 and @activo = 0 and exists (select 1 from CAT_TIPOSFACTURAS where Id_TipoFactura = @id and Codigo in ('01', '03'))
				THROW 50323, 'La caja emite este tipo de documento: no se puede inactivar.', 1;
			if @id = 0 insert into CAT_TIPOSFACTURAS (Codigo, Descripcion, Estatus, UsuarioCrea, FechaCrea) values (@formato, UPPER(@descripcion), @activo, @usuario, GETDATE())
			else update CAT_TIPOSFACTURAS set Codigo = @formato, Descripcion = UPPER(@descripcion), Estatus = @activo, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_TipoFactura = @id
		end
		else
		begin
			if LEN(@descripcion) > 200 THROW 50316, 'La descripción no puede tener más de 200 caracteres.', 1;
			if @id = 0 insert into CAT_TIPOSCITAS (Descripcion, IsActivo, UsuarioCrea, FechaCrea) values (@descripcion, @activo, @usuario, GETDATE())
			else update CAT_TIPOSCITAS set Descripcion = @descripcion, IsActivo = @activo, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_TipoCita = @id
		end

		if @id = 0
		begin
			select CAST(SCOPE_IDENTITY() as bigint) as Id
			return
		end
		select @id as Id
		return
	end

	/* ================= 3: eliminar (solo si nadie lo usa) ================= */
	if @accion = 3
	begin
		declare @usos int =
			case @catalogo
				when 'departamentos' then (select COUNT(*) from CAT_MUNICIPIOS where Id_Departamento_fk = @id) + (select COUNT(*) from Sys_ConfiguracionApp where Departamento = @id)
				when 'municipios' then (select COUNT(*) from EXP_EXPEDIENTES where Id_Municipio_fk = @id) + (select COUNT(*) from Sys_ConfiguracionApp where Municipio = @id)
				when 'sexos' then (select COUNT(*) from EXP_EXPEDIENTES where Id_Sexo_fk = @id)
				when 'especialistas' then (select COUNT(*) from EXP_CITAS where Id_Especialista_fk = @id) + (select COUNT(*) from EXP_PROCEDIMIENTOS where Id_Especialista_fk = @id)
				when 'estados' then (select COUNT(*) from EXP_CITAS where Id_EstadoCita_fk = @id)
				when 'horarios' then (select COUNT(*) from EXP_CITAS where Id_Horario_fk = @id or Id_HorarioFin_FK = @id)
					+ (select COUNT(*) from EXP_PROCEDIMIENTOS where Id_Horario_fk = @id or Id_Horariofin_fk = @id)
				when 'tratamientos' then (select COUNT(*) from EXP_CITAS where Id_Tratamiento_fk = @id)
					+ (select COUNT(*) from EXP_PROCEDIMIENTOSTRATAMIENTOS where Id_Tratamiento_FK = @id) + (select COUNT(*) from EXP_CUPONES where Id_Tratamiento_FK = @id)
				when 'tiposdocumento' then (select COUNT(*) from EXP_EXPEDIENTES where Id_TipoDocumento_fk = @id)
				when 'tiposfactura' then (select COUNT(*) from FAC_DTE_DOCUMENTOS where Id_TipoFactura_FK = @id)
					+ case when exists (select 1 from CAT_TIPOSFACTURAS where Id_TipoFactura = @id and Codigo in ('01', '03')) then 1 else 0 end
				else (select COUNT(*) from EXP_CITAS where Id_TipoCita_FK = @id) + (select COUNT(*) from EXP_PROCEDIMIENTOS where Id_TipoCita_FK = @id)
			end
		if @catalogo = 'estados' and @id between 1 and 7
			THROW 50310, 'Este estado lo usa el sistema y no se puede eliminar.', 1;
		if @usos > 0 and @catalogo in ('departamentos', 'municipios')
			THROW 50318, 'Este registro está en uso (municipios, expedientes o datos de la empresa) y no se puede eliminar.', 1;
		if @usos > 0
			THROW 50318, 'Este registro está en uso y no se puede eliminar. Inactívelo para que ya no aparezca en las listas.', 1;

		if @catalogo = 'departamentos' delete from CAT_DEPARTAMENTOS where Id_Departamento = @id
		else if @catalogo = 'municipios' delete from CAT_MUNICIPIOS where Id_Municipio = @id
		else if @catalogo = 'sexos' delete from CAT_SEXOS where Id_Sexos = @id
		else if @catalogo = 'especialistas' delete from CAT_ESPECIALISTAS where Id_Especialista = @id
		else if @catalogo = 'estados' delete from CAT_ESTADOSCITAS where Id_Estado = @id
		else if @catalogo = 'horarios' delete from CAT_HORARIOS where Id_Horario = @id
		else if @catalogo = 'tratamientos' delete from CAT_TRATAMIENTOS where Id_Tratamientos = @id
		else if @catalogo = 'tiposdocumento' delete from CAT_TIPOSDOCUMENTOS where Id_TipoDocumento = @id
		else if @catalogo = 'tiposfactura' delete from CAT_TIPOSFACTURAS where Id_TipoFactura = @id
		else delete from CAT_TIPOSCITAS where Id_TipoCita = @id
		select @id as Id
		return
	end

	/* ================= 4: activar / inactivar ================= */
	if @accion = 4
	begin
		if @catalogo in ('departamentos', 'municipios') THROW 50319, 'Este catálogo no se puede inactivar.', 1;
		if @catalogo = 'estados' and @id between 1 and 7 and @activo = 0 THROW 50310, 'Este estado lo usa el sistema: solo se puede cambiar su nombre y su color.', 1;
		if @catalogo = 'especialistas' and @activo = 1
			and exists (select 1 from CAT_ESPECIALISTAS as e where e.Id_Especialista = @id and e.UsaurioSystem is not null
						and exists (select 1 from CAT_ESPECIALISTAS as o where o.UsaurioSystem = e.UsaurioSystem and o.IsActivo = 1 and o.Id_Especialista <> @id))
			THROW 50305, 'Ese usuario ya está vinculado a otro especialista activo.', 1;

		if @catalogo = 'sexos' update CAT_SEXOS set IsActivo = @activo, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_Sexos = @id
		else if @catalogo = 'especialistas' update CAT_ESPECIALISTAS set IsActivo = @activo, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_Especialista = @id
		else if @catalogo = 'estados' update CAT_ESTADOSCITAS set IsActivo = @activo, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_Estado = @id
		else if @catalogo = 'horarios' update CAT_HORARIOS set IsActivo = @activo, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_Horario = @id
		else if @catalogo = 'tratamientos' update CAT_TRATAMIENTOS set IsActivo = @activo, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_Tratamientos = @id
		else if @catalogo = 'tiposdocumento' update CAT_TIPOSDOCUMENTOS set Estatus = @activo, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_TipoDocumento = @id
		else if @catalogo = 'tiposfactura'
		begin
			if @activo = 0 and exists (select 1 from CAT_TIPOSFACTURAS where Id_TipoFactura = @id and Codigo in ('01', '03'))
				THROW 50323, 'La caja emite este tipo de documento: no se puede inactivar.', 1;
			update CAT_TIPOSFACTURAS set Estatus = @activo, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_TipoFactura = @id
		end
		else update CAT_TIPOSCITAS set IsActivo = @activo, UsuarioModifica = @usuario, FechaModifica = GETDATE() where Id_TipoCita = @id
		if @@ROWCOUNT = 0 THROW 50317, 'El registro ya no existe. Actualice la lista.', 1;
		select @id as Id
		return
	end

	/* ================= 5: tipos de comprobante: agregar los que faltan del catálogo CAT-002 de Hacienda ================= */
	if @accion = 5 and @catalogo = 'tiposfactura'
	begin
		declare @cat002 table (Codigo varchar(2), Descripcion varchar(200))
		insert into @cat002 values
			 ('01', 'FACTURA'), ('03', 'COMPROBANTE DE CRÉDITO FISCAL'), ('04', 'NOTA DE REMISIÓN'), ('05', 'NOTA DE CRÉDITO')
			,('06', 'NOTA DE DÉBITO'), ('07', 'COMPROBANTE DE RETENCIÓN'), ('08', 'COMPROBANTE DE LIQUIDACIÓN')
			,('09', 'DOCUMENTO CONTABLE DE LIQUIDACIÓN'), ('11', 'FACTURA DE EXPORTACIÓN'), ('14', 'FACTURA DE SUJETO EXCLUIDO')
			,('15', 'COMPROBANTE DE DONACIÓN')
		insert into CAT_TIPOSFACTURAS (Codigo, Descripcion, Estatus, UsuarioCrea, FechaCrea)
		select c.Codigo, c.Descripcion, 1, @usuario, GETDATE()
		from @cat002 as c
		where not exists (select 1 from CAT_TIPOSFACTURAS as t where t.Codigo = c.Codigo)
		select CAST(@@ROWCOUNT as bigint) as Id
		return
	end;

	THROW 50399, 'Acción no válida.', 1;
END
GO
