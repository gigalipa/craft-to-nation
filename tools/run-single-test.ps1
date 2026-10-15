param([string]$Scene)
$godot = "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
$logPath = Join-Path ([System.IO.Path]::GetTempPath()) "godot_test.log"
if (Test-Path $logPath) { Remove-Item $logPath -Force }
$argList = @("--headless", "--path", "godot", "--log-file", $logPath, "--fixed-fps", "60", "--quit-after", "600", "scenes/$Scene")
$p = Start-Process -FilePath $godot -ArgumentList $argList -Wait -PassThru -WindowStyle Hidden
if (Test-Path $logPath) {
    Get-Content $logPath
    Remove-Item $logPath -Force
}
exit $p.ExitCode
