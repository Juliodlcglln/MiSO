#Requires -Version 5.1
<#
.SYNOPSIS
  Arranca una ISO de MiSO Desktop en QEMU (BIOS o UEFI).

.EXAMPLE
  .\scripts\run-qemu.ps1 -Iso "out\miso-desktop-0.1.0-core-amd64.iso"

.EXAMPLE
  .\scripts\run-qemu.ps1 -Iso "out\miso-desktop-0.1.0-desktop-amd64.iso" -Uefi -Memory 4G
#>
param(
    [string]$Iso = "",
    [string]$Memory = "4G",
    [int]$Cpus = 4,
    [switch]$Uefi,
    [switch]$Tcg,
    [switch]$NoGl,
    [string]$Disk = ""
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$QemuDir = "C:\Program Files\qemu"
$Qemu = Join-Path $QemuDir "qemu-system-x86_64.exe"

if (-not (Test-Path $Qemu)) {
    throw "No se encontró qemu-system-x86_64.exe en '$QemuDir'. Instala QEMU para Windows."
}

if ([string]::IsNullOrWhiteSpace($Iso)) {
    $Iso = Join-Path $ProjectRoot "out\miso-desktop-0.1.0-core-amd64.iso"
}
if (-not (Test-Path $Iso)) {
    throw "No existe la ISO: $Iso`nConstruye primero con: sudo bash build/build-iso.sh --profile core"
}
$Iso = (Resolve-Path $Iso).Path

$OutDir = Join-Path $ProjectRoot "out"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$SerialLog = Join-Path $OutDir "qemu-serial.log"

$QemuArgs = @(
    "-name", "MiSO Desktop",
    "-machine", "q35",
    "-smp", "$Cpus",
    "-m", $Memory
)

if ($Tcg) {
    $QemuArgs += @("-accel", "tcg", "-cpu", "max")
} else {
    $QemuArgs += @("-accel", "whpx", "-cpu", "host")
}

if ($Uefi) {
    $CodeCandidates = @(
        (Join-Path $QemuDir "share\edk2-x86_64-code.fd"),
        (Join-Path $QemuDir "share\OVMF_CODE.fd"),
        (Join-Path $QemuDir "share\ovmf\OVMF_CODE.fd"),
        (Join-Path $QemuDir "share\edk2-x86_64-code.fd")
    )
    $VarsCandidates = @(
        (Join-Path $QemuDir "share\edk2-i386-vars.fd"),
        (Join-Path $QemuDir "share\OVMF_VARS.fd"),
        (Join-Path $QemuDir "share\ovmf\OVMF_VARS.fd")
    )

    $Code = $CodeCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    $VarsTemplate = $VarsCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $Code -or -not $VarsTemplate) {
        throw @"
No se encontró el firmware OVMF en '$QemuDir\share'.
Busca edk2-x86_64-code.fd / edk2-i386-vars.fd o instala el paquete OVMF.
También puedes arrancar en BIOS omitiendo -Uefi.
"@
    }

    $Vars = Join-Path $env:TEMP "miso-ovmf-vars.fd"
    Copy-Item -Force $VarsTemplate $Vars
    $QemuArgs += @(
        "-drive", "if=pflash,format=raw,readonly=on,file=$Code",
        "-drive", "if=pflash,format=raw,file=$Vars"
    )
}

$QemuArgs += @(
    "-drive", "file=$Iso,media=cdrom,readonly=on",
    "-boot", "d",
    "-device", "virtio-vga",
    "-nic", "user,model=virtio-net-pci",
    "-device", "qemu-xhci",
    "-usb",
    "-serial", "file:$SerialLog"
)

if (-not $NoGl) {
    $QemuArgs += @("-display", "gtk,gl=on")
}

if (-not [string]::IsNullOrWhiteSpace($Disk)) {
    if (-not (Test-Path $Disk)) {
        $QemuImg = Join-Path $QemuDir "qemu-img.exe"
        & $QemuImg create -f qcow2 $Disk 40G
    }
    $Disk = (Resolve-Path $Disk).Path
    $QemuArgs += @("-drive", "file=$Disk,if=virtio,format=qcow2")
}

Write-Host "MiSO Desktop - QEMU"
Write-Host "  ISO:    $Iso"
Write-Host "  Modo:   $(if ($Uefi) { 'UEFI' } else { 'BIOS' }) / $(if ($Tcg) { 'TCG' } else { 'WHPX' })"
Write-Host "  Serial: $SerialLog"
Write-Host ""

& $Qemu @Args
