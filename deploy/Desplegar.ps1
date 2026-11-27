<#
.SYNOPSIS
    Despliega un paquete de DPieCenter (DPieCenter_aaaaMMdd_HHmm.zip) en la carpeta del sitio de IIS.

.DESCRIPTION
    1. Respalda el sitio actual en <carpeta del sitio>_respaldos\aaaaMMdd_HHmmss (sin facturas ni videos).
    2. Pone el sitio fuera de línea (app_offline.htm o deteniendo el AppPool si se indica -AppPool).
    3. Copia los archivos nuevos. NO borra nada del servidor y:
         - conserva el Web.config del servidor (cadena de conexión y claves). El del paquete queda en el respaldo.
           Use -ReemplazarWebConfig solo si el servidor no tiene uno o debe usar el del paquete.
         - en Facturacion\facturas, Catalogos\uploadtratamientos y assets\publicidad (archivos que genera la
           aplicación) solo agrega los que falten: nunca sobrescribe ni borra.
    4. Vuelve a poner el sitio en línea.
    5. Con -AplicarSql ejecuta el script SQL del paquete (idempotente) en la base del Web.config del servidor.

    Todo queda registrado en <carpeta del sitio>_respaldos\despliegue_aaaaMMdd_HHmmss.log.
    Para volver a la versión anterior: -Restaurar '<carpeta del respaldo>'.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Desplegar.ps1
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Desplegar.ps1 -AppPool 'DPieCenter' -AplicarSql -Url 'https://miservidor/DPieCenter/login.aspx'
.EXAMPLE
    # solo ver qué haría, sin cambiar nada
    powershell -ExecutionPolicy Bypass -File .\Desplegar.ps1 -Simular
.EXAMPLE
    # volver a la versión anterior
    powershell -ExecutionPolicy Bypass -File .\Desplegar.ps1 -Restaurar 'C:\inetpub\wwwroot\DPieCenter_respaldos\20261124_173000'
#>
[CmdletBinding()]
param(
    [string]$Destino = 'C:\inetpub\wwwroot\DPieCenter',   # carpeta del sitio en IIS
    [string]$Paquete,                 # por defecto: el DPieCenter_*.zip más reciente de -CarpetaPaquetes (o junto a este script)
    [string]$CarpetaPaquetes = 'C:\temp',
    [string]$AppPool,                 # opcional: se detiene y se inicia (requiere IIS / WebAdministration)
    [switch]$ReemplazarWebConfig,
    [switch]$AplicarSql,
    [string]$Url,                     # opcional: página a abrir al final para comprobar que responde
    [switch]$Simular,
    [string]$Restaurar                # carpeta de un respaldo para volver a la versión anterior
)
$ErrorActionPreference = 'Stop'
$Destino = $Destino.TrimEnd('\')
$marca = Get-Date -Format 'yyyyMMdd_HHmmss'
$respaldos = "${Destino}_respaldos"
$DATOS = @('Facturacion\facturas', 'Catalogos\uploadtratamientos', 'assets\publicidad')   # archivos que genera la aplicación

function Paso([string]$t) { Write-Host "`n== $t" -ForegroundColor Cyan }
function Copiar([string]$de, [string]$a, [string[]]$extra) {
    # robocopy: sin /MIR (nunca borra en el destino). Códigos 0-7 = correcto
    $opciones = @($de, $a, '/E', '/R:2', '/W:2', '/NP', '/NFL', '/NDL', '/NJH') + $extra
    if ($Simular) { $opciones += '/L' }
    & robocopy @opciones | Out-Host
    if ($LASTEXITCODE -ge 8) { throw "robocopy falló (código $LASTEXITCODE) copiando $de -> $a" }
}
function SitioFueraDeLinea {
    if ($Simular) { Write-Host '(simulación) el sitio se pondría fuera de línea'; return }
    if ($AppPool) {
        Import-Module WebAdministration
        if ((Get-WebAppPoolState $AppPool).Value -ne 'Stopped') { Stop-WebAppPool $AppPool; Start-Sleep 3 }
        Write-Host "AppPool $AppPool detenido."
    } else {
        Set-Content (Join-Path $Destino 'app_offline.htm') -Encoding UTF8 -Value '<!doctype html><meta charset="utf-8"><title>Actualizando</title><body style="font-family:sans-serif;text-align:center;margin-top:15%"><h2>D'' Pie Center se está actualizando</h2><p>Vuelva a intentar en unos minutos.</p></body>'
        Start-Sleep 3
        Write-Host 'Sitio fuera de línea (app_offline.htm).'
    }
}
function SitioEnLinea {
    if ($Simular) { return }
    if ($AppPool) { Start-WebAppPool $AppPool; Write-Host "AppPool $AppPool iniciado." }
    $off = Join-Path $Destino 'app_offline.htm'
    if (Test-Path $off) { Remove-Item $off -Force; Write-Host 'Sitio en línea.' }
}

if (-not (Test-Path $Destino)) {
    if ($Restaurar) { throw "No existe la carpeta del sitio $Destino." }
    Write-Host "La carpeta $Destino no existe: se creará (primera instalación)." -ForegroundColor Yellow
    if (-not $Simular) { New-Item -ItemType Directory -Force $Destino | Out-Null }
}
if (-not $Simular) { New-Item -ItemType Directory -Force $respaldos | Out-Null; Start-Transcript -Path (Join-Path $respaldos "despliegue_$marca.log") | Out-Null }

try {
    # ---------- Volver a una versión anterior ----------
    if ($Restaurar) {
        if (-not (Test-Path (Join-Path $Restaurar 'bin\DPieCenter.dll'))) { throw "$Restaurar no es un respaldo del sitio." }
        Paso "Restaurando $Restaurar"
        SitioFueraDeLinea
        try { Copiar $Restaurar $Destino @('/XF', 'app_offline.htm', 'Web.config.paquete') }
        finally { SitioEnLinea }
        Paso 'Restauración terminada'
        return
    }

    # ---------- Paquete ----------
    if (-not $Paquete) {
        $Paquete = Get-ChildItem $PSScriptRoot -Filter 'DPieCenter_*.zip' | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
        if (-not $Paquete) { throw "No se encontró un DPieCenter_*.zip junto a Desplegar.ps1. Indique -Paquete." }
    }
    Paso "Paquete $Paquete"
    $tmp = Join-Path $env:TEMP ('DPieCenter_despliegue_' + $marca)
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
    Expand-Archive -Path $Paquete -DestinationPath $tmp
    $sitio = Join-Path $tmp 'sitio'
    if (-not (Test-Path (Join-Path $sitio 'bin\DPieCenter.dll'))) { throw 'El paquete no contiene el sitio (sitio\bin\DPieCenter.dll).' }
    if (Test-Path (Join-Path $tmp 'version.txt')) { Get-Content (Join-Path $tmp 'version.txt') | Write-Host }

    $webConfigServidor = Join-Path $Destino 'Web.config'
    $conservarWebConfig = (Test-Path $webConfigServidor) -and -not $ReemplazarWebConfig
    if (-not (Test-Path $webConfigServidor)) { Write-Host 'El servidor no tiene Web.config: se usará el del paquete.' -ForegroundColor Yellow }

    # ---------- 1. Respaldo ----------
    $respaldo = Join-Path $respaldos $marca
    if (Test-Path (Join-Path $Destino 'bin\DPieCenter.dll')) {
        Paso "Respaldo del sitio actual en $respaldo"
        $excluir = $DATOS | ForEach-Object { Join-Path $Destino $_ }
        # sin los paquetes .zip ni el script, por si se dejaron en la misma carpeta del sitio
        Copiar $Destino $respaldo (@('/XD') + $excluir + @('/XF', 'app_offline.htm', 'DPieCenter_*.zip', 'Desplegar.ps1'))
    }
    if (-not $Simular) {
        New-Item -ItemType Directory -Force $respaldo | Out-Null
        Copy-Item (Join-Path $sitio 'Web.config') (Join-Path $respaldo 'Web.config.paquete') -Force   # para comparar
    }

    # ---------- 2-4. Copia ----------
    Paso 'Actualizando archivos'
    SitioFueraDeLinea
    try {
        $excluirDatos = $DATOS | ForEach-Object { Join-Path $sitio $_ }
        $extra = @('/XD') + $excluirDatos
        if ($conservarWebConfig) { $extra += @('/XF', 'Web.config'); Write-Host 'Se conserva el Web.config del servidor.' }
        Copiar $sitio $Destino $extra
        # archivos de la aplicación: solo los que no existan en el servidor (/XC /XN /XO = no sobrescribe)
        foreach ($d in $DATOS) {
            $origen = Join-Path $sitio $d
            if (Test-Path $origen) { Copiar $origen (Join-Path $Destino $d) @('/XC', '/XN', '/XO') }
        }
    }
    finally { SitioEnLinea }

    # ---------- 5. Base de datos ----------
    if ($AplicarSql) {
        $script = Get-ChildItem (Join-Path $tmp 'sql') -Filter '*.sql' | Select-Object -First 1
        if (-not $script) { throw 'El paquete no contiene el script SQL.' }
        Paso "Base de datos: $($script.Name)"
        [xml]$cfg = Get-Content $webConfigServidor
        $cs = ($cfg.configuration.connectionStrings.add | Where-Object { $_.name -eq 'conexionDiarypro' }).connectionString
        if (-not $cs) { throw 'No se encontró la conexión "conexionDiarypro" en el Web.config del servidor.' }
        $b = New-Object System.Data.SqlClient.SqlConnectionStringBuilder $cs
        Write-Host "Servidor: $($b.DataSource)  Base: $($b.InitialCatalog)"
        if ($Simular) { Write-Host '(simulación) no se ejecuta el SQL' }
        else {
            $cn = New-Object System.Data.SqlClient.SqlConnection $cs
            $cn.add_InfoMessage({ param($s, $e) foreach ($m in $e.Errors) { Write-Host "  $($m.Message)" } })
            $cn.Open()
            try {
                $lotes = [regex]::Split([IO.File]::ReadAllText($script.FullName, [Text.Encoding]::UTF8), '(?im)^\s*GO\s*$') | Where-Object { $_.Trim() }
                $n = 0
                foreach ($l in $lotes) {
                    $n++
                    $cmd = $cn.CreateCommand(); $cmd.CommandTimeout = 600; $cmd.CommandText = $l
                    try { [void]$cmd.ExecuteNonQuery() }
                    catch { throw "Error en el lote $n de $($lotes.Count): $($_.Exception.GetBaseException().Message)" }
                }
                Write-Host "SQL aplicado: $n lotes." -ForegroundColor Green
            }
            finally { $cn.Close() }
        }
    }

    # ---------- Comprobación ----------
    if ($Url -and -not $Simular) {
        Paso "Comprobando $Url"
        try {
            $r = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 120
            Write-Host "Respondió HTTP $($r.StatusCode)." -ForegroundColor Green
        } catch { Write-Host "No respondió correctamente: $($_.Exception.Message)" -ForegroundColor Red }
    }

    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Paso ($(if ($Simular) { 'Simulación terminada: no se cambió nada' } else { 'Despliegue terminado' }))
    if (-not $Simular) {
        Write-Host "Respaldo: $respaldo"
        Write-Host "Para volver atrás: .\Desplegar.ps1 -Destino '$Destino' -Restaurar '$respaldo'"
        if (-not $AplicarSql) { Write-Host 'La base de datos no se tocó (use -AplicarSql si el paquete trae cambios de base).' -ForegroundColor Yellow }
    }
}
finally {
    if (-not $Simular) { Stop-Transcript | Out-Null }
}
