#Requires -Version 5.1
<#
.SYNOPSIS
  Revisa el log serial de QEMU en busca de fallos evidentes.

.EXAMPLE
  .\tests\check-serial.ps1 -Log "out\qemu-serial.log"
#>
param(
    [string]$Log = "out\qemu-serial.log"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $Log)) {
    throw "No existe el log serial: $Log"
}

$content = Get-Content -Raw -Path $Log
$failures = @()

$panicPatterns = @(
    "Kernel panic",
    "Call Trace:",
    "BUG: unable to handle",
    "Out of memory",
    "Failed to mount root"
)

foreach ($pattern in $panicPatterns) {
    if ($content -match [regex]::Escape($pattern)) {
        $failures += $pattern
    }
}

$booted = ($content -match "Reached target Multi-User System") -or
          ($content -match "login:") -or
          ($content -match "Reached target Graphical Interface")

Write-Host "MiSO - revisión de log serial"
Write-Host "  Archivo: $Log"
Write-Host "  Arranque detectado: $(if ($booted) { 'sí' } else { 'no' })"

if ($failures.Count -gt 0) {
    Write-Host "  Fallos detectados:" -ForegroundColor Red
    foreach ($f in $failures) { Write-Host "    - $f" -ForegroundColor Red }
    exit 1
}

if (-not $booted) {
    Write-Host "  ADVERTENCIA: no se encontró una marca de arranque completo." -ForegroundColor Yellow
    exit 2
}

Write-Host "  Sin pánicos ni errores evidentes." -ForegroundColor Green
exit 0
