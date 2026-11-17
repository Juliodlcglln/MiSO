#Requires -Version 5.1
<#
.SYNOPSIS
  Arranca una ISO de MiSO Desktop en QEMU (BIOS o UEFI).

.EXAMPLE
  .\scripts\run-qemu.ps1 -Iso "out\miso-desktop-0.1.0-core-amd64.iso"

.EXAMPLE
  .\scripts\run-qemu.ps1 -Iso "out\miso-desktop-0.1.0-desktop-amd64.iso" -Uefi -Memory 4G

.EXAMPLE
  .\scripts\run-qemu.ps1 -Iso "out\miso-desktop-0.1.0-desktop-amd64.iso" -Audio dsound

.EXAMPLE
  .\scripts\run-qemu.ps1 -Iso "out\miso-desktop-0.1.0-desktop-amd64.iso" -Audio none
#>
param(
    [string]$Iso = "",
    [string]$Memory = "1536M",
    [int]$Cpus = 4,
    [switch]$Uefi,
    [switch]$Tcg,
    [string]$Display = "sdl",
    [switch]$Gl,
    [ValidateSet("sdl", "dsound", "none")]
    [string]$Audio = "sdl",
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
    "-name", "WanukuOS Desktop",
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

# Audio: QEMU ya no crea tarjeta de sonido por defecto, hay que declararla.
# snd-hda-intel + PipeWire (pipewire-pulse + wireplumber) en el invitado.
if ($Audio -ne "none") {
    $QemuArgs += @(
        "-audiodev", "$Audio,id=snd0",
        "-device", "intel-hda",
        "-device", "hda-duplex,audiodev=snd0"
    )
}

if ($Gl) {
    $QemuArgs += @("-display", "gtk,gl=on")
} elseif ($Display -eq "gtk") {
    $QemuArgs += @("-display", "gtk")
} else {
    $QemuArgs += @("-display", "sdl")
}

if (-not [string]::IsNullOrWhiteSpace($Disk)) {
    if (-not (Test-Path $Disk)) {
        $QemuImg = Join-Path $QemuDir "qemu-img.exe"
        & $QemuImg create -f qcow2 $Disk 40G
    }
    $Disk = (Resolve-Path $Disk).Path
    $QemuArgs += @("-drive", "file=$Disk,if=virtio,format=qcow2")
}

Write-Host "WanukuOS Desktop - QEMU"
Write-Host "  ISO:    $Iso"
Write-Host "  Modo:   $(if ($Uefi) { 'UEFI' } else { 'BIOS' }) / $(if ($Tcg) { 'TCG' } else { 'WHPX' })"
Write-Host "  Audio:  $Audio"
Write-Host "  Serial: $SerialLog"
Write-Host ""

& $Qemu @QemuArgs
