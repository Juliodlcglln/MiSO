#Requires -Version 5.1
<#
.SYNOPSIS
  Boots a MiSO ISO headless in QEMU, logs in over a serial TCP chardev and runs
  smoke checks (identity, network, rings, doctor).

.DESCRIPTION
  Requires QEMU for Windows and WHPX (or pass -Tcg). The ISO must have been built
  with console=ttyS0 in the kernel command line, which the MiSO GRUB config does.

.EXAMPLE
  .\scripts\serial-smoke.ps1 -Iso "out\miso-desktop-0.1.0-core-amd64.iso"

.EXAMPLE
  .\scripts\serial-smoke.ps1 -Iso "out\miso-desktop-0.1.0-desktop-amd64.iso" -BootWait 140
#>
param(
    [string]$Iso = "",
    [string]$Disk = "",
    [int]$Port = 4555,
    [int]$BootWait = 95,
    [string]$User = "live",
    [string]$Password = "live",
    [switch]$Tcg,
    [switch]$Uefi,
    [switch]$KeepLog,
    [string[]]$Extra = @()
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Qemu = "C:\Program Files\qemu\qemu-system-x86_64.exe"
if (-not (Test-Path $Qemu)) {
    throw "No se encontro qemu-system-x86_64.exe en C:\Program Files\qemu."
}

$BootFromDisk = -not [string]::IsNullOrWhiteSpace($Disk)
if ($BootFromDisk) {
    if (-not (Test-Path $Disk)) { throw "No existe el disco: $Disk" }
    $diskArg = (Resolve-Path $Disk).Path -replace '\\', '/'
} else {
    if ([string]::IsNullOrWhiteSpace($Iso)) {
        $Iso = Join-Path $ProjectRoot "out\miso-desktop-0.1.0-core-amd64.iso"
    }
    if (-not (Test-Path $Iso)) {
        throw "No existe la ISO: $Iso"
    }
    $isoArg = (Resolve-Path $Iso).Path -replace '\\', '/'
}

$OutDir = Join-Path $ProjectRoot "out"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$Log = Join-Path $OutDir "serial-smoke.log"
$ErrLog = Join-Path $env:TEMP "miso-serial-smoke-stderr.log"
Remove-Item $Log, $ErrLog -ErrorAction SilentlyContinue

if ($BootFromDisk) {
    $bootArgs = @("-drive", "`"file=$diskArg,format=raw,if=virtio`"")
} else {
    $bootArgs = @("-drive", "`"file=$isoArg,media=cdrom,readonly=on`"", "-boot", "d")
}

$qemuArgs = @(
    "-name", "MiSO-Smoke", "-machine", "q35", "-smp", "4", "-m", "4096"
) + $bootArgs + @(
    "-device", "virtio-vga", "-nic", "user,model=virtio-net-pci",
    "-chardev", "socket,id=ser0,host=127.0.0.1,port=$Port,server=on,wait=off",
    "-serial", "chardev:ser0",
    "-display", "none", "-no-reboot"
)
if ($Tcg) {
    $qemuArgs += @("-accel", "tcg", "-cpu", "max")
} else {
    $qemuArgs += @("-accel", "whpx", "-cpu", "host")
}

if ($Uefi) {
    $share = "C:\Program Files\qemu\share"
    $code = Join-Path $share "edk2-x86_64-code.fd"
    $varsTemplate = Join-Path $share "edk2-i386-vars.fd"
    if (-not (Test-Path $code) -or -not (Test-Path $varsTemplate)) {
        throw "No se encontro OVMF (edk2-x86_64-code.fd / edk2-i386-vars.fd)."
    }
    $vars = Join-Path $env:TEMP "miso-smoke-ovmf-vars.fd"
    Copy-Item -Force $varsTemplate $vars
    $qemuArgs += @(
        "-drive", "`"if=pflash,format=raw,readonly=on,file=$code`"",
        "-drive", "`"if=pflash,format=raw,file=$vars`""
    )
}

Write-Host "MiSO serial smoke test"
if ($BootFromDisk) { Write-Host "  Disco: $Disk" } else { Write-Host "  ISO:   $Iso" }
Write-Host "  Log:   $Log"
Write-Host ""

$proc = Start-Process -FilePath $Qemu -ArgumentList $qemuArgs -PassThru `
    -WindowStyle Hidden -RedirectStandardError $ErrLog

function Read-Until {
    param($Stream, [string]$Pattern, [int]$TimeoutMs = 60000)
    $sb = New-Object System.Text.StringBuilder
    $deadline = (Get-Date).AddMilliseconds($TimeoutMs)
    $buf = New-Object byte[] 4096
    while ((Get-Date) -lt $deadline) {
        if ($Stream.DataAvailable) {
            $n = $Stream.Read($buf, 0, $buf.Length)
            if ($n -gt 0) {
                [void]$sb.Append([System.Text.Encoding]::UTF8.GetString($buf, 0, $n))
                if ($sb.ToString() -match $Pattern) { break }
            }
        } else {
            Start-Sleep -Milliseconds 200
        }
    }
    return $sb.ToString()
}

function Send-Line {
    param($Stream, [string]$Text)
    $bytes = [System.Text.Encoding]::ASCII.GetBytes("$Text`n")
    $Stream.Write($bytes, 0, $bytes.Length)
    $Stream.Flush()
    Start-Sleep -Milliseconds 700
}

$ok = $false
try {
    Start-Sleep -Seconds $BootWait
    $client = New-Object System.Net.Sockets.TcpClient
    $client.Connect("127.0.0.1", $Port)
    $stream = $client.GetStream()

    $all = New-Object System.Text.StringBuilder
    [void]$all.Append((Read-Until $stream "login:" 30000))
    Send-Line $stream $User
    [void]$all.Append((Read-Until $stream "assword:" 30000))
    Send-Line $stream $Password
    [void]$all.Append((Read-Until $stream '\$|#' 30000))

    $commands = @(
        "echo ===IDENTITY===",
        "cat /etc/os-release | head -2",
        "echo ===NET===",
        "ip -4 -br addr",
        "ping -c 2 -W 3 deb.debian.org",
        "echo ===RINGS===",
        "miso ring list",
        "echo ===DOCTOR===",
        "miso doctor"
    ) + $Extra + @("echo ===DONE===")

    foreach ($cmd in $commands) {
        Send-Line $stream $cmd
        [void]$all.Append((Read-Until $stream '===DONE===|\$ ' 90000))
    }

    $text = $all.ToString()
    Set-Content -Path $Log -Value $text -Encoding UTF8
    $client.Close()
    $ok = $text -match '===DONE==='
} finally {
    if ($proc -and -not $proc.HasExited) { Stop-Process -Id $proc.Id -Force }
}

Get-Content $Log

Write-Host ""
if ($ok) {
    Write-Host "Smoke test completado. Revisa el resumen de miso doctor." -ForegroundColor Green
    exit 0
}

Write-Host "No se pudo completar la secuencia por serial." -ForegroundColor Red
if (Test-Path $ErrLog) { Get-Content $ErrLog -Tail 10 }
exit 1
