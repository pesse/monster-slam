# Richtet sound-eval unter Windows (nativ, PowerShell) ein – Gegenstück zu setup.sh.
#   powershell -ExecutionPolicy Bypass -File tools\sound_eval\setup.ps1          # GPU wenn vorhanden
#   powershell -ExecutionPolicy Bypass -File tools\sound_eval\setup.ps1 -Cpu
#   powershell -ExecutionPolicy Bypass -File tools\sound_eval\setup.ps1 -CheckOnly   # nur prüfen
param([switch]$Cpu, [switch]$CheckOnly)
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$uv = Get-Command uv -ErrorAction SilentlyContinue
if (-not $uv) { $uv = Get-Command "$env:USERPROFILE\.local\bin\uv.exe" -ErrorAction SilentlyContinue }
Write-Host ("uv:     " + $(if ($uv) { $uv.Source } else { "fehlt (wird nach %USERPROFILE%\.local\bin installiert)" }))

$variant = "cpu"
$smi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
if (-not $Cpu -and $smi) {
    $gpus = @(& nvidia-smi -L 2>$null)  # erst ganz einlesen; Select -First 1 bricht nvidia-smi ab
    if ($LASTEXITCODE -eq 0 -and $gpus.Count -gt 0) { $variant = "cu128"; Write-Host "GPU:    $($gpus[0])" }
}
Write-Host "Torch:  $variant"
if ($CheckOnly) { exit 0 }

if (-not $uv) {
    powershell -ExecutionPolicy Bypass -c "irm https://astral.sh/uv/install.ps1 | iex"
    $env:Path = "$env:USERPROFILE\.local\bin;$env:Path"
}
uv sync --project $here --extra $variant --extra dev
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& "$here\sound-eval.cmd" doctor --smoke
