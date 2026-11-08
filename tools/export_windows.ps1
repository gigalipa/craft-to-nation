<#
.SYNOPSIS
    Exporta Craft to Nation para Windows Desktop y genera el .zip para Itch.io.
#>
[CmdletBinding()]
param(
    [string]$GodotPath = "",
    [string]$Version = "v0.1"
)

$ErrorActionPreference = "Stop"

function Resolve-GodotExecutable {
    param([string]$RequestedPath)

    if ($RequestedPath) {
        if (-not (Test-Path -LiteralPath $RequestedPath -PathType Leaf)) {
            throw "No se encontró Godot en '$RequestedPath'."
        }
        return (Resolve-Path -LiteralPath $RequestedPath).Path
    }

    foreach ($name in @("godot", "godot4")) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command) {
            return $command.Source
        }
    }

    $steamPath = "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
    if (Test-Path -LiteralPath $steamPath -PathType Leaf) {
        return $steamPath
    }

    throw "No se encontró Godot Engine. Por favor especifica la ruta con -GodotPath."
}

$godot = Resolve-GodotExecutable $GodotPath
$rootPath = Resolve-Path (Join-Path $PSScriptRoot "..")
$godotProjectPath = Join-Path $rootPath "godot"
$buildDir = Join-Path $godotProjectPath "build"

if (-not (Test-Path -LiteralPath $buildDir)) {
    New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
}

Write-Host "==> Exportando Craft to Nation para Windows Desktop..." -ForegroundColor Cyan
$exportTarget = "build/CraftToNation.exe"
$arguments = @(
    "--headless",
    "--path", "`"$godotProjectPath`"",
    "--export-release", "`"Windows Desktop`"",
    "`"$exportTarget`""
)

$process = Start-Process -FilePath $godot -ArgumentList $arguments -Wait -PassThru -NoNewWindow
if ($process.ExitCode -ne 0) {
    Write-Error "Fallo en la exportación de Godot (código de salida: $($process.ExitCode))."
    exit 1
}

$exePath = Join-Path $buildDir "CraftToNation.exe"
if (-not (Test-Path -LiteralPath $exePath)) {
    Write-Error "No se generó el ejecutable en '$exePath'."
    exit 1
}

$zipName = "CraftToNation_${Version}_Windows.zip"
$zipPath = Join-Path $buildDir $zipName

Write-Host "==> Comprimiendo paquete zip: $zipName..." -ForegroundColor Cyan
if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

Compress-Archive -Path $exePath -DestinationPath $zipPath -CompressionLevel Optimal

$zipItem = Get-Item -LiteralPath $zipPath
$sizeMB = [math]::Round($zipItem.Length / 1MB, 2)
Write-Host "==> ¡Exportación completada con éxito!" -ForegroundColor Green
Write-Host "    Archivo: $($zipItem.FullName) ($sizeMB MB)" -ForegroundColor Green
