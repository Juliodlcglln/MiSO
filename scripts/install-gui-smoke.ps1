#Requires -Version 5.1
<#
.SYNOPSIS
  Prueba de humo del instalador grafico: arranca la ISO con un disco vacio,
  abre Calamares desde la consola de la sesion live y guarda capturas.

.DESCRIPTION
  Usa el monitor de QEMU para enviar teclas y raton (KRunner no es fiable en
  Wayland) y `screendump` para capturar el framebuffer.

.EXAMPLE
  .\scripts\install-gui-smoke.ps1 -Iso "out\miso-desktop-0.1.0-desktop-amd64.iso" -Uefi
#>
param(
    [string]$Iso = "",
    [string]$Disk = "",
    [int]$BootWait = 190,
    [int]$MonitorPort = 4557,
    [string]$OutDir = "",
    [string]$LivePassword = "live",
    [switch]$Tcg,
    [switch]$Uefi,
    [switch]$KeepRunning
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Qemu = "C:\Program Files\qemu\qemu-system-x86_64.exe"
$QemuImg = "C:\Program Files\qemu\qemu-img.exe"
if (-not (Test-Path $Qemu)) { throw "No se encontro qemu-system-x86_64.exe." }

if ([string]::IsNullOrWhiteSpace($Iso)) {
    $Iso = Join-Path $ProjectRoot "out\miso-desktop-0.1.0-desktop-amd64.iso"
}
if (-not (Test-Path $Iso)) { throw "No existe la ISO: $Iso" }
$isoArg = (Resolve-Path $Iso).Path -replace '\\', '/'

if ([string]::IsNullOrWhiteSpace($Disk)) {
    $Disk = Join-Path $env:TEMP "miso-gui-install.qcow2"
}
if (-not (Test-Path $Disk)) {
    Write-Host "Creando disco vacio: $Disk"
    & $QemuImg create -f qcow2 $Disk 40G | Out-Null
}
$diskArg = (Resolve-Path $Disk).Path -replace '\\', '/'

if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = Join-Path $ProjectRoot "out\screenshots\installer"
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$qemuArgs = @(
    "-name", "MiSO-Install-GUI", "-machine", "q35", "-smp", "4", "-m", "4096",
    "-drive", "`"file=$isoArg,media=cdrom,readonly=on`"",
    "-drive", "`"file=$diskArg,format=qcow2,if=virtio`"",
    "-boot", "d",
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
    $vars = Join-Path $env:TEMP "miso-install-ovmf-vars.fd"
    Copy-Item -Force $varsTemplate $vars
    $qemuArgs += @(
        "-drive", "`"if=pflash,format=raw,readonly=on,file=$code`"",
        "-drive", "`"if=pflash,format=raw,file=$vars`""
    )
}

$ErrLog = Join-Path $env:TEMP "miso-install-gui-stderr.log"
Remove-Item $ErrLog -ErrorAction SilentlyContinue

Write-Host "MiSO install GUI smoke"
Write-Host "  ISO:   $Iso"
Write-Host "  Disco: $Disk"
Write-Host "  Salida: $OutDir"

$proc = Start-Process -FilePath $Qemu -ArgumentList $qemuArgs -PassThru `
    -WindowStyle Hidden -RedirectStandardError $ErrLog

function Send-Monitor {
    param([string]$Command)
    $client = New-Object System.Net.Sockets.TcpClient
    $client.Connect("127.0.0.1", $MonitorPort)
    $stream = $client.GetStream()
    $stream.ReadTimeout = 5000
    Start-Sleep -Milliseconds 250
    $bytes = [System.Text.Encoding]::ASCII.GetBytes("$Command`n")
    $stream.Write($bytes, 0, $bytes.Length)
    $stream.Flush()
    Start-Sleep -Milliseconds 400
    $client.Close()
}

function Send-Text {
    param([string]$Text, [int]$DelayMs = 110)
    foreach ($ch in $Text.ToCharArray()) {
        $key = switch -Regex ($ch.ToString()) {
            "[a-z]" { $ch.ToString() }
            "[0-9]" { $ch.ToString() }
            " "     { "spc" }
            "-"     { "minus" }
            "."     { "dot" }
            "/"     { "slash" }
            default { $null }
        }
        if ($key) {
            Send-Monitor "sendkey $key"
            Start-Sleep -Milliseconds $DelayMs
        }
    }
}

function Move-Click {
    param([int]$X, [int]$Y)
    Send-Monitor "mouse_move -2000 -2000"
    Start-Sleep -Milliseconds 300
    Send-Monitor "mouse_move $X $Y"
    Start-Sleep -Milliseconds 300
    Send-Monitor "mouse_button 1"
    Start-Sleep -Milliseconds 120
    Send-Monitor "mouse_button 0"
    Start-Sleep -Milliseconds 500
}

function Save-Shot {
    param([string]$Name)
    $ppm = Join-Path $OutDir ("{0}.ppm" -f $Name)
    $winPath = $ppm -replace '\\', '/'
    Send-Monitor "screendump `"$winPath`""
    Start-Sleep -Seconds 2
    if (Test-Path $ppm) {
        Write-Host "  captura: $ppm"
    } else {
        Write-Warning "No se genero $ppm"
    }
}

try {
    Write-Host "Esperando el escritorio live ($BootWait s)..."
    Start-Sleep -Seconds $BootWait
    Save-Shot "01-escritorio"

    # Cierra el Centro de bienvenida de KDE si sigue abierto.
    Send-Monitor "sendkey alt-f4"
    Start-Sleep -Seconds 3
    Save-Shot "02-escritorio-limpio"

    # Enfoca la consola de bienvenida de MiSO y lanza Calamares con sudo.
    Write-Host "Abriendo Calamares desde la consola..."
    Move-Click 240 300
    Send-Text "sudo calamares"
    Start-Sleep -Milliseconds 400
    Send-Monitor "sendkey ret"
    Start-Sleep -Seconds 3
    Save-Shot "03-password"

    Send-Text $LivePassword
    Start-Sleep -Milliseconds 400
    Send-Monitor "sendkey ret"
    Start-Sleep -Seconds 20
    Save-Shot "04-bienvenida"

    # Avanza a la pagina siguiente (idioma/teclado).
    Send-Monitor "sendkey ret"
    Start-Sleep -Seconds 6
    Save-Shot "05-siguiente"
} finally {
    if ($KeepRunning) {
        Write-Host "QEMU sigue en marcha (PID $($proc.Id))."
    } elseif ($proc -and -not $proc.HasExited) {
        Stop-Process -Id $proc.Id -Force
    }
}

if (Test-Path $ErrLog) {
    $err = Get-Content $ErrLog -Tail 10
    if ($err) { Write-Host "--- qemu stderr ---"; $err }
}
Write-Host ""
Write-Host "Capturas del instalador en $OutDir"
