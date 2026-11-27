<# Une los scripts SQL del proyecto, en orden, en un solo archivo idempotente (sql\DPieCenter_Cambios_BD_*.sql).
   Al agregar un script nuevo, agréguelo a la lista en el orden en que debe ejecutarse. #>
param([string]$Salida = (Join-Path (Split-Path $PSScriptRoot -Parent) 'sql\DPieCenter_Cambios_BD_2026-11-04.sql'))
$root = Split-Path $PSScriptRoot -Parent
$items = @(
  [pscustomobject]@{F='Facturacion\sql\FAC_DTE_Estructura.sql';           D='Facturación electrónica: tablas y SPs base de los DTE'}
  [pscustomobject]@{F='Facturacion\sql\FAC_DTE_Pagos.sql';                D='Pago combinado: varias formas de pago por DTE'}
  [pscustomobject]@{F='Catalogos\sql\CAT_Tratamientos_Descuento.sql';     D='Tratamientos: descuento en %'}
  [pscustomobject]@{F='Opciones\sql\SUC_Sucursales.sql';                 D='Sucursales: estructuras, Casa Matriz y datos actuales'}
  [pscustomobject]@{F='Registros\sql\EXP_Citas_Horarios.sql';             D='Citas: FechaInicio/FechaFin según Fecha y CAT_HORARIOS'}
  [pscustomobject]@{F='Registros\sql\EXP_Citas_ProcedimientoEnCurso.sql'; D='Citas: procedimiento en curso'}
  [pscustomobject]@{F='Facturacion\sql\CAJ_Anticipos.sql';                D='Cobro por adelantado, saldo a favor y pago adelantado sin cita'}
  [pscustomobject]@{F='Registros\sql\EXP_Procedimientos_Atencion.sql';    D='Procedimientos: atención (incluye acción 14, lista en curso)'}
  [pscustomobject]@{F='Registros\sql\EXP_Procedimientos_Cierre.sql';      D='Cierre de procesos abiertos de meses anteriores'}
  [pscustomobject]@{F='Registros\sql\EXP_Reclamos.sql';                   D='Reclamos: estructura con procedimiento y SP'}
  [pscustomobject]@{F='Registros\sql\EXP_Agenda.sql';                     D='Agenda y calendario: catálogos, detalle, edición y búsqueda de pacientes'}
  [pscustomobject]@{F='Registros\sql\CAT_Paises.sql';                     D='Paises: nacionalidad y formato de telefono y documento'}
  [pscustomobject]@{F='Registros\sql\EXP_Expedientes_Lista.sql';          D='Expedientes: lista'}
  [pscustomobject]@{F='Registros\sql\EXP_Expediente_Detalle.sql';         D='Expedientes: detalle'}
  [pscustomobject]@{F='Reportes\sql\REP_Reportes.sql';                    D='Reportes de citas, procedimientos y expedientes'}
  [pscustomobject]@{F='Reportes\sql\REP_Garantias.sql';                  D='Reporte de Garantía de Servicios'}
  [pscustomobject]@{F='Reportes\sql\REP_CajaEspecialistas.sql';          D='Reporte de caja por especialista'}
  [pscustomobject]@{F='Opciones\sql\SYS_Administracion.sql';              D='Módulo Opciones (módulos, opciones, perfiles, usuarios, dashboards, empresa)'}
  [pscustomobject]@{F='Opciones\sql\SYS_Login_Legado.sql';                D='Procedimientos del login anterior'}
  [pscustomobject]@{F='Catalogos\sql\CAT_Catalogos.sql';                  D='Módulo Catálogos (incluye tipos de factura CAT-002)'}
  [pscustomobject]@{F='Registros\sql\REG_Inbound.sql';                    D='Registros > Inbound'}
  [pscustomobject]@{F='Dashboard\sql\REP_Dashboard_Usuarios.sql';         D='Dashboard de usuarios'}
  [pscustomobject]@{F='Registros\sql\CUP_Cupones.sql';                    D='Cupones con QR y descuento en caja'}
  [pscustomobject]@{F='Facturacion\sql\CAJ_Caja_Anulaciones.sql';         D='Caja diaria, salidas de efectivo y anulaciones de DTE'}
  [pscustomobject]@{F='Facturacion\sql\CAJ_Tickets.sql';                  D='Ticket POS para servicios sin costo'}
  [pscustomobject]@{F='Facturacion\sql\FAC_DTE_Diagnostico.sql';          D='Diagnóstico DTE y bitácora de eventos'}
  [pscustomobject]@{F='Facturacion\sql\FAC_DTE_Firmador.sql';             D='Generador de firma de Hacienda (quita menú Datos DTE)'}
  [pscustomobject]@{F='Reportes\sql\REP_Dashboard_Caja.sql';              D='Dashboard general y reporte de caja'}
  [pscustomobject]@{F='Facturacion\sql\FAC_Procedimientos_Curso.sql';     D='Menú Facturación > Procedimientos (en curso)'}
  [pscustomobject]@{F='Registros\sql\EXP_Citas_Agendadas.sql';             D='Calendario de citas: nombre del paciente'}
  [pscustomobject]@{F='Opciones\sql\SYS_Recuperar_Clave.sql';              D='Recuperar contraseña desde el login (código de 6 dígitos)'}
  [pscustomobject]@{F='Registros\sql\SYS_Menu_Citas.sql';                 D='Menú Registros > Citas abre el calendario'}
  [pscustomobject]@{F='Opciones\sql\SYS_Menu_Publicidad.sql';             D='Menú Opciones > Videos de turnos'}
  [pscustomobject]@{F='Registros\sql\SYS_Menu_Turnos.sql';                D='Menú Registros > Pantalla de turnos'},
  [pscustomobject]@{F='Registros\sql\MET_Metas.sql';                      D='Metas de ventas y esquema de bono (Registros > Metas)'}
)
$n = $items.Count
$sb = New-Object System.Text.StringBuilder
$nl = "`r`n"
[void]$sb.Append("/* =====================================================================$nl")
[void]$sb.Append("   DPieCenter - Script consolidado de cambios a la base de datos$nl")
[void]$sb.Append("   Generado: " + (Get-Date).ToString('dd/MM/yyyy hh:mm tt',[Globalization.CultureInfo]::InvariantCulture) + "$nl$nl")
[void]$sb.Append("   Ejecutar completo en SQL Server Management Studio, conectado a la base de la aplicación$nl")
[void]$sb.Append("   (no incluye USE: seleccione la base antes de ejecutar). Haga un respaldo antes.$nl")
[void]$sb.Append("   Todos los scripts son idempotentes: se puede ejecutar varias veces sin duplicar datos.$nl$nl")
[void]$sb.Append("   Contenido (en este orden):$nl")
$i = 0
foreach ($it in $items) { $i++; [void]$sb.Append(("   {0,2}. {1,-50} {2}" -f $i, $it.F, $it.D).TrimEnd() + $nl) }
[void]$sb.Append("   ===================================================================== */$nl")
[void]$sb.Append("SET NOCOUNT ON;${nl}GO$nl")
[void]$sb.Append("IF OBJECT_ID('dbo.CAJ_FACTURAS', 'U') IS NULL OR OBJECT_ID('dbo.Sys_Opciones', 'U') IS NULL OR OBJECT_ID('dbo.EXP_EXPEDIENTES', 'U') IS NULL$nl")
[void]$sb.Append("    THROW 50000, 'Esta no es la base de DPieCenter: seleccione la base correcta antes de ejecutar.', 1;${nl}GO$nl")
$i = 0
foreach ($it in $items) {
  $i++
  $p = Join-Path $root $it.F
  if (-not (Test-Path $p)) { throw "No existe $p" }
  $t = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
  $t = ($t -replace "`r?`n", $nl).TrimEnd()
  if ($t -notmatch '(?m)^GO\s*$\z' -and $t -notmatch "GO$") { $t += "${nl}GO" }
  [void]$sb.Append("$nl/* #####################################################################$nl")
  [void]$sb.Append("   $i/$n  $($it.F)$nl")
  [void]$sb.Append("   ##################################################################### */$nl")
  [void]$sb.Append("PRINT N'>> $i/$n $($it.F)';${nl}GO$nl")
  [void]$sb.Append($t + $nl)
}
[void]$sb.Append("${nl}PRINT N'>> Terminado: todos los cambios aplicados.';$nl")
[System.IO.File]::WriteAllText($Salida, $sb.ToString(), (New-Object System.Text.UTF8Encoding($true)))
"Escrito: $Salida ({0} líneas, {1} scripts)" -f ($sb.ToString() -split "`n").Count, $n
