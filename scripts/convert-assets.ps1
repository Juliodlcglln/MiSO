#Requires -Version 5.1
Add-Type -AssemblyName System.Drawing

$logoSource = 'C:\Users\santos\.gemini\antigravity\brain\407156da-c245-472c-945f-249f7be395e9\.user_uploaded\media_1794472671224_54a416d1.png'
$wallSource = 'C:\Users\santos\.gemini\antigravity\brain\407156da-c245-472c-945f-249f7be395e9\.user_uploaded\media_1794473141961_775e4f0a.jpg'

function Resize-Image {
    param(
        [string]$SourcePath,
        [string]$DestPath,
        [int]$TargetWidth,
        [int]$TargetHeight,
        [System.Drawing.Imaging.ImageFormat]$Format = [System.Drawing.Imaging.ImageFormat]::Png
    )
    $src = [System.Drawing.Image]::FromFile($SourcePath)
    $dest = New-Object System.Drawing.Bitmap($TargetWidth, $TargetHeight)
    $g = [System.Drawing.Graphics]::FromImage($dest)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    
    $g.DrawImage($src, 0, 0, $TargetWidth, $TargetHeight)
    $g.Dispose()
    $src.Dispose()
    
    $dir = Split-Path -Parent $DestPath
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    
    $dest.Save($DestPath, $Format)
    $dest.Dispose()
    Write-Host "Generated: $DestPath ($TargetWidth x $TargetHeight)"
}

$ProjectRoot = Split-Path -Parent $PSScriptRoot

# 1. Wallpapers (1920x1080)
Resize-Image $wallSource "$ProjectRoot\branding\wallpapers\wanuku-default.png" 1920 1080 ([System.Drawing.Imaging.ImageFormat]::Png)
Resize-Image $wallSource "$ProjectRoot\branding\wallpapers\wanuku-default.jpg" 1920 1080 ([System.Drawing.Imaging.ImageFormat]::Jpeg)
# Also keep miso-default name aliased/overwritten so existing lookups resolve
Resize-Image $wallSource "$ProjectRoot\branding\wallpapers\miso-default.png" 1920 1080 ([System.Drawing.Imaging.ImageFormat]::Png)

# 2. Logos (256x256, 128x128, 64x64, 48x48, 32x32)
Resize-Image $logoSource "$ProjectRoot\branding\logo\wanuku-logo.png" 256 256 ([System.Drawing.Imaging.ImageFormat]::Png)
Resize-Image $logoSource "$ProjectRoot\branding\logo\wanuku-logo-128.png" 128 128 ([System.Drawing.Imaging.ImageFormat]::Png)
Resize-Image $logoSource "$ProjectRoot\branding\logo\wanuku-logo-64.png" 64 64 ([System.Drawing.Imaging.ImageFormat]::Png)
Resize-Image $logoSource "$ProjectRoot\branding\logo\wanuku-logo-48.png" 48 48 ([System.Drawing.Imaging.ImageFormat]::Png)
Resize-Image $logoSource "$ProjectRoot\branding\logo\wanuku-logo-32.png" 32 32 ([System.Drawing.Imaging.ImageFormat]::Png)
Resize-Image $logoSource "$ProjectRoot\branding\logo\miso-logo.png" 256 256 ([System.Drawing.Imaging.ImageFormat]::Png)
Resize-Image $logoSource "$ProjectRoot\branding\logo\miso-logo-64.png" 64 64 ([System.Drawing.Imaging.ImageFormat]::Png)

# 3. Calamares branding
Resize-Image $logoSource "$ProjectRoot\installer\calamares\branding\miso\logo.png" 256 256 ([System.Drawing.Imaging.ImageFormat]::Png)
Resize-Image $logoSource "$ProjectRoot\installer\calamares\branding\miso\icon.png" 64 64 ([System.Drawing.Imaging.ImageFormat]::Png)
Resize-Image $wallSource "$ProjectRoot\installer\calamares\branding\miso\welcome.png" 900 500 ([System.Drawing.Imaging.ImageFormat]::Png)

# 4. SDDM branding
Resize-Image $wallSource "$ProjectRoot\branding\sddm\background.png" 1920 1080 ([System.Drawing.Imaging.ImageFormat]::Png)
Resize-Image $logoSource "$ProjectRoot\branding\sddm\logo.png" 128 128 ([System.Drawing.Imaging.ImageFormat]::Png)

# 5. Plymouth branding
Resize-Image $logoSource "$ProjectRoot\branding\plymouth\logo.png" 192 192 ([System.Drawing.Imaging.ImageFormat]::Png)

Write-Host "All branding assets converted successfully!"
