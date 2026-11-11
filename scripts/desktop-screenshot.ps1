#Requires -Version 5.1
<#
.SYNOPSIS
  Arranca una ISO de MiSO en QEMU sin ventana y guarda capturas del
  framebuffer mediante el monitor de QEMU.

.EXAMPLE
  .\scripts\desktop-screenshot.ps1 -Iso "out\miso-desktop-0.1.0-desktop-amd64.iso" -BootWait 150
#>
param(
    [string]$Iso = "",
    [string]$Disk = "",
    [int]$BootWait = 150,
    [int]$MonitorPort = 4556,
    [string]$OutDir = "",
    [switch]$Tcg,
    [switch]$Uefi,
    [int]$Shots = 2,
    [int]$ShotInterval = 20
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Qemu = "C:\Program Files\qemu\qemu-system-x86_64.exe"
if (-not (Test-Path $Qemu)) { throw "No se encontro qemu-system-x86_64.exe." }

$BootFromDisk = -not [string]::IsNullOrWhiteSpace($Disk)
if ($BootFromDisk) {
    if (-not (Test-Path $Disk)) { throw "No existe el disco: $Disk" }
    $diskArg = (Resolve-Path $Disk).Path -replace '\\', '/'
    $bootArgs = @("-drive", "`"file=$diskArg,format=raw,if=virtio`"")
} else {
    if ([string]::IsNullOrWhiteSpace($Iso)) {
        $Iso = Join-Path $ProjectRoot "out\miso-desktop-0.1.0-desktop-amd64.iso"
    }
    if (-not (Test-Path $Iso)) { throw "No existe la ISO: $Iso" }
    $isoArg = (Resolve-Path $Iso).Path -replace '\\', '/'
    $bootArgs = @("-drive", "`"file=$isoArg,media=cdrom,readonly=on`"", "-boot", "d")
}

if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = Join-Path $ProjectRoot "out\screenshots"
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$qemuArgs = @(
    "-name", "MiSO-Shot", "-machine", "q35", "-smp", "4", "-m", "4096"
) + $bootArgs + @(
    "-device", "virtio-vga", "-nic", "user,model=virtio-net-pci",
    "-display", "none", "-no-reboot",
    "-monitor", "tcp:127.0.0.1:$MonitorPort,server=on,wait=off"
)
if ($Tcg) { $qemuArgs += @("-accel", "tcg", "-cpu", "max") }
else { $qemuArgs += @("-accel", "whpx", "-cpu", "host") }

if ($Uefi) {
    $share = "C:\Program Files\qemu\share"
    $code = Join-Path $share "edk2-x86_64-code.fd"
    $varsTemplate = Join-Path $share "edk2-i386-vars.fd"
    if (-not (Test-Path $code) -or -not (Test-Path $varsTemplate)) {
        throw "No se encontro OVMF."
    }
    $vars = Join-Path $env:TEMP "miso-shot-ovmf-vars.fd"
    Copy-Item -Force $varsTemplate $vars
    $qemuArgs += @(
        "-drive", "`"if=pflash,format=raw,readonly=on,file=$code`"",
        "-drive", "`"if=pflash,format=raw,file=$vars`""
    )
}

$ErrLog = Join-Path $env:TEMP "miso-desktop-shot-stderr.log"
Remove-Item $ErrLog -ErrorAction SilentlyContinue

Write-Host "MiSO desktop screenshot"
if ($BootFromDisk) { Write-Host "  Disco: $Disk" } else { Write-Host "  ISO:   $Iso" }
Write-Host "  Salida: $OutDir"

$proc = Start-Process -FilePath $Qemu -ArgumentList $qemuArgs -PassThru `
    -WindowStyle Hidden -RedirectStandardError $ErrLog

function Send-Monitor {
    param([string]$Command)
    $client = New-Object System.Net.Sockets.TcpClient
    $client.Connect("127.0.0.1", $MonitorPort)
    $stream = $client.GetStream()
    $stream.ReadTimeout = 5000
    Start-Sleep -Milliseconds 300
    $bytes = [System.Text.Encoding]::ASCII.GetBytes("$Command`n")
    $stream.Write($bytes, 0, $bytes.Length)
    $stream.Flush()
    Start-Sleep -Seconds 2
    $client.Close()
}

$files = @()
try {
    Start-Sleep -Seconds $BootWait
    for ($i = 1; $i -le $Shots; $i++) {
        $ppm = Join-Path $OutDir ("miso-desktop-{0}.ppm" -f $i)
        $winPath = $ppm -replace '\\', '/'
        # La ruta puede llevar espacios: el monitor de QEMU exige comillas.
        Send-Monitor "screendump `"$winPath`""
        if (Test-Path $ppm) {
            $files += $ppm
            Write-Host "  captura: $ppm"
        } else {
            Write-Warning "No se genero $ppm"
        }
        if ($i -lt $Shots) { Start-Sleep -Seconds $ShotInterval }
    }
} finally {
    if ($proc -and -not $proc.HasExited) { Stop-Process -Id $proc.Id -Force }
}

if ($files.Count -eq 0) {
    if (Test-Path $ErrLog) { Get-Content $ErrLog -Tail 20 }
    throw "No se pudo capturar la pantalla."
}

Write-Host ""
Write-Host "Capturas listas en $OutDir"
