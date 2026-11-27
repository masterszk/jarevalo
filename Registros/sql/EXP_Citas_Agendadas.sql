/* =====================================================================
   DPieCenter - Citas agendadas (calendario de Registros > Citas)
   Agrega la columna Paciente: el calendario muestra el nombre del paciente en lugar del especialista.
   Sin @desde/@hasta: citas no canceladas desde hoy (lógica original).
   Con @desde/@hasta: citas no canceladas en ese rango, incluidos días pasados (semana del calendario).
   Idempotente.
   ===================================================================== */
SET NOCOUNT ON;
GO
CREATE OR ALTER PROCEDURE [dbo].[EXP_SP_Citas_Agendadas]
	@acc int
	,@desde datetime2 = NULL
	,@hasta datetime2 = NULL
	,@sucursal int = 0          -- 0: todas las sucursales
AS
BEGIN TRY
	SET NOCOUNT ON;

	select
		c.Id_Cita [Id]
		,c.FechaInicio
		,s.Descripcion [Profesional]
		,t.Descripcion [TipoCita]
		,LTRIM(RTRIM(ISNULL(e.Nombres, '') + ' ' + ISNULL(e.Apellidos, ''))) [Paciente]
	from EXP_CITAS as c
		inner join CAT_ESPECIALISTAS as s on c.Id_Especialista_fk = s.Id_Especialista
		inner join CAT_TIPOSCITAS as t on c.Id_TipoCita_FK = t.Id_TipoCita
		left join EXP_EXPEDIENTES as e on e.Id_Expediente = c.Id_Expediente_fk
	where c.Id_EstadoCita_fk <> 3
		and (@sucursal = 0 or c.Id_Sucursal_FK = @sucursal)
		and ((@desde is null and c.Fecha >= CAST(GETDATE() as date))
			or (@desde is not null and c.FechaInicio >= @desde and c.FechaInicio < ISNULL(@hasta, DATEADD(day, 7, @desde))))
	order by c.FechaInicio

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
