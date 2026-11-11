#Requires -Version 5.1
<#
.SYNOPSIS
  Escribe una ISO de MiSO Desktop en una USB. Operación destructiva.

.DESCRIPTION
  Requiere confirmación explícita. Prefiere Rufus o Ventoy si no tienes `dd`.
  El número de disco se obtiene con: Get-Disk
#>
param(
    [Parameter(Mandatory = $true)][string]$Iso,
    [Parameter(Mandatory = $true)][int]$DiskNumber
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $Iso)) {
    throw "No existe la ISO: $Iso"
}

$Disk = Get-Disk -Number $DiskNumber -ErrorAction Stop
Write-Host "ATENCIÓN: se borrará el disco $DiskNumber" -ForegroundColor Red
$Disk | Format-List Number, FriendlyName, Size, BusType, PartitionStyle

$confirm = Read-Host "Escribe BORRAR para continuar"
if ($confirm -ne "BORRAR") {
    Write-Host "Cancelado."
    exit 1
}

$dd = Get-Command dd -ErrorAction SilentlyContinue
if (-not $dd) {
    throw @"
No se encontró 'dd'. Usa Rufus (modo DD) o Ventoy:
  https://rufus.ie/
  https://www.ventoy.net/
"@
}

$target = "\\.\PhysicalDrive$DiskNumber"
Write-Host "Escribiendo $Iso en $target ..."
& dd if="$Iso" of="$target" bs=8M --progress
if ($LASTEXITCODE -ne 0) {
    throw "dd falló con código $LASTEXITCODE"
}

Write-Host "Listo. Verifica el arranque en el equipo de laboratorio." -ForegroundColor Green
