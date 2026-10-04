[CmdletBinding()]
param(
	[string]$GodotPath = ""
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

	throw "No se encontró Godot. Pasa la ruta con -GodotPath."
}

$godot = Resolve-GodotExecutable $GodotPath
$projectPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\godot")).Path
$scenesPath = Join-Path $projectPath "scenes"
$scenes = @(Get-ChildItem -LiteralPath $scenesPath -Filter "*Test.tscn" -File | Sort-Object Name)
$expectedScenes = @(
	"BlueprintsTest.tscn",
	"BuscadorRutasTest.tscn",
	"CadenaMineralesTest.tscn",
	"CamaraCenitalModosTest.tscn",
	"CiudadTest.tscn",
	"ColonosTest.tscn",
	"ConstruccionTest.tscn",
	"EconomiaTest.tscn",
	"ExtraccionTest.tscn",
	"FantasmasPermeablesTest.tscn",
	"GeneradorArbolTest.tscn",
	"GeneradorMundoTest.tscn",
	"HUDTest.tscn",
	"MiniaturaRendererTest.tscn",
	"NiveladorTerrenoTest.tscn",
	"ObrasTest.tscn",
	"PlantillasPuestoTest.tscn",
	"PlayerNatacionTest.tscn",
	"PlayerOxigenoTest.tscn",
	"PuertasTest.tscn",
	"PuestosPrevisualizacionTest.tscn",
	"RecoleccionTest.tscn",
	"Test.tscn",
	"TranslucidosRendererTest.tscn",
	"ViasTest.tscn",
	"ZonificacionTest.tscn"
)
$foundNames = @($scenes | ForEach-Object { $_.Name })
$missingScenes = @($expectedScenes | Where-Object { $_ -notin $foundNames })
$unexpectedScenes = @($foundNames | Where-Object { $_ -notin $expectedScenes })
if ($missingScenes.Count -gt 0 -or $unexpectedScenes.Count -gt 0) {
	Write-Error ("El conjunto de escenas cambió. Faltan: [{0}]. Sobran: [{1}]." -f ($missingScenes -join ", "), ($unexpectedScenes -join ", "))
	exit 1
}
$failures = @()

foreach ($scene in $scenes) {
	$logPath = Join-Path ([System.IO.Path]::GetTempPath()) ("citycraft-{0}-{1}.log" -f $scene.BaseName, [guid]::NewGuid())
	try {
		$arguments = @(
			"--headless",
			"--path", $projectPath,
			"--log-file", $logPath,
			"--fixed-fps", "60",
			"--quit-after", "600",
			("scenes/{0}" -f $scene.Name)
		)
		$process = Start-Process -FilePath $godot -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden
		$log = if (Test-Path -LiteralPath $logPath) { Get-Content -Raw -LiteralPath $logPath } else { "" }
		$errors = @($log -split "`r?`n" | Where-Object { $_ -match "^(SCRIPT ERROR|ERROR:|Parse Error|Assertion failed)" })
		$completed = $log -match "(?im)^.*(?:pasaron correctamente|todas las pruebas pasaron).*$"

		if ($process.ExitCode -ne 0 -or $errors.Count -gt 0 -or -not $completed) {
			$failures += $scene.Name
			Write-Host "FALLO $($scene.Name) (exit=$($process.ExitCode), errores=$($errors.Count), completa=$completed)" -ForegroundColor Red
			$errors | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" }
		} else {
			Write-Host "OK    $($scene.Name)"
		}
	} finally {
		if (Test-Path -LiteralPath $logPath) {
			Remove-Item -LiteralPath $logPath -Force
		}
	}
}

if ($failures.Count -gt 0) {
	Write-Error ("Fallaron {0} de {1} escenas: {2}" -f $failures.Count, $scenes.Count, ($failures -join ", "))
	exit 1
}

Write-Host "Las $($scenes.Count) escenas de prueba pasaron sin errores."
