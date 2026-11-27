<#
.SYNOPSIS
    Crea el paquete de despliegue de DPieCenter: compila en Release, publica en D:\DPIE y arma un .zip con
    el sitio, el script SQL consolidado y el script de despliegue (Desplegar.ps1).

.DESCRIPTION
    Resultado en -Salida (por defecto C:\temp):
        DPieCenter_aaaaMMdd_HHmm.zip   paquete (sitio\, sql\, Desplegar.ps1, LEEME.txt, version.txt)
        Desplegar.ps1                  copia suelta para ejecutarlo en el servidor junto al .zip

    El paquete no lleva los archivos que la aplicación genera en el servidor (Facturacion\facturas).
    Lleva Web.config, que tiene la cadena de conexión y claves: guarde el paquete en un lugar seguro.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\deploy\Crear-Paquete.ps1
.EXAMPLE
    # sin volver a compilar (usa lo que ya está en D:\DPIE)
    powershell -ExecutionPolicy Bypass -File .\deploy\Crear-Paquete.ps1 -SinCompilar
#>
[CmdletBinding()]
param(
    [string]$Publicado = 'D:\DPIE',
    [string]$Salida = 'C:\temp',
    [switch]$SinCompilar
)
$ErrorActionPreference = 'Stop'
$raiz = Split-Path $PSScriptRoot -Parent
$proyecto = Join-Path $raiz 'DPieCenter.csproj'
$marca = Get-Date -Format 'yyyyMMdd_HHmm'
$nombre = "DPieCenter_$marca"

function Paso([string]$t) { Write-Host "`n== $t" -ForegroundColor Cyan }

# 1. Compilar y publicar (perfil FolderProfile -> D:\DPIE)
if (-not $SinCompilar) {
    Paso 'Compilando y publicando en Release'
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    $msbuild = & $vswhere -latest -requires Microsoft.Component.MSBuild -find 'MSBuild\**\Bin\MSBuild.exe' | Select-Object -First 1
    if (-not $msbuild) { throw 'No se encontró MSBuild (Visual Studio).' }
    & $msbuild $proyecto /p:DeployOnBuild=true /p:PublishProfile=FolderProfile /p:Configuration=Release /v:m /nologo
    if ($LASTEXITCODE -ne 0) { throw "La compilación falló (código $LASTEXITCODE)." }
}
if (-not (Test-Path (Join-Path $Publicado 'bin\DPieCenter.dll'))) { throw "No hay un sitio publicado en $Publicado." }

# 2. Script SQL consolidado al día
Paso 'Script SQL consolidado'
$sql = Join-Path $raiz 'sql\DPieCenter_Cambios_BD_2026-11-04.sql'
& (Join-Path $PSScriptRoot 'Consolidar-Sql.ps1') -Salida $sql

# 3. Armar el contenido en una carpeta temporal
Paso 'Armando el paquete'
$tmp = Join-Path $env:TEMP $nombre
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
$sitio = Join-Path $tmp 'sitio'
New-Item -ItemType Directory -Force $sitio, (Join-Path $tmp 'sql') | Out-Null
# los archivos de facturas (PDF/JSON) son del servidor: no viajan en el paquete
robocopy $Publicado $sitio /E /XD (Join-Path $Publicado 'Facturacion\facturas') /R:1 /W:1 /NP /NFL /NDL /NJH /NJS | Out-Null
if ($LASTEXITCODE -ge 8) { throw "No fue posible copiar el sitio publicado (robocopy $LASTEXITCODE)." }
Copy-Item $sql (Join-Path $tmp 'sql')
Copy-Item (Join-Path $PSScriptRoot 'Desplegar.ps1') $tmp
Copy-Item (Join-Path $PSScriptRoot 'LEEME.txt') $tmp

$archivos = Get-ChildItem $sitio -Recurse -File
$dll = Get-Item (Join-Path $sitio 'bin\DPieCenter.dll')
@(
    "Paquete:      $nombre"
    "Creado:       $((Get-Date).ToString('dd/MM/yyyy hh:mm tt', [Globalization.CultureInfo]::InvariantCulture)) en $env:COMPUTERNAME"
    "DPieCenter.dll: $($dll.LastWriteTime.ToString('dd/MM/yyyy HH:mm'))  SHA256 $((Get-FileHash $dll.FullName -Algorithm SHA256).Hash)"
    "Archivos del sitio: $($archivos.Count)  ($([math]::Round(($archivos | Measure-Object Length -Sum).Sum / 1MB, 1)) MB)"
    "Script SQL:   sql\$(Split-Path $sql -Leaf)"
) | Set-Content (Join-Path $tmp 'version.txt') -Encoding UTF8

# 4. Comprimir
New-Item -ItemType Directory -Force $Salida | Out-Null
$zip = Join-Path $Salida "$nombre.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $tmp '*') -DestinationPath $zip -CompressionLevel Optimal
Copy-Item (Join-Path $PSScriptRoot 'Desplegar.ps1') $Salida -Force
Remove-Item $tmp -Recurse -Force

$hash = (Get-FileHash $zip -Algorithm SHA256).Hash
Paso 'Listo'
Write-Host "Paquete:    $zip ($([math]::Round((Get-Item $zip).Length / 1MB, 1)) MB)"
Write-Host "SHA256:     $hash"
Write-Host "Despliegue: copie el .zip y Desplegar.ps1 a C:\temp del servidor y ejecute (PowerShell como administrador):"
Write-Host "            cd C:\temp; powershell -ExecutionPolicy Bypass -File .\Desplegar.ps1" -ForegroundColor Yellow
