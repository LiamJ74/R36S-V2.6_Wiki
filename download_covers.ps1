###############################################################################
# download_covers.ps1
# Downloads missing cover art from libretro-thumbnails for R36S SD card
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File download_covers.ps1
#   powershell -ExecutionPolicy Bypass -File download_covers.ps1 -Platform GBA
#   powershell -ExecutionPolicy Bypass -File download_covers.ps1 -RootPath "D:\"
###############################################################################

param(
    [string]$RootPath = "H:\",
    [string]$Platform = ""
)

Add-Type -AssemblyName System.Drawing

# Mapping: local folder -> libretro-thumbnails repo name
$repoMap = @{
    'ATARI' = 'Atari_-_2600'
    'FC'    = 'Nintendo_-_Nintendo_Entertainment_System'
    'GB'    = 'Nintendo_-_Game_Boy'
    'GBA'   = 'Nintendo_-_Game_Boy_Advance'
    'GBC'   = 'Nintendo_-_Game_Boy_Color'
    'GG'    = 'Sega_-_Game_Gear'
    'MAME'  = 'MAME'
    'MD'    = 'Sega_-_Mega_Drive_-_Genesis'
    'NGPC'  = 'SNK_-_Neo_Geo_Pocket_Color'
    'PCE'   = 'NEC_-_PC_Engine_-_TurboGrafx_16'
    'PS'    = 'Sony_-_PlayStation'
    'SFC'   = 'Nintendo_-_Super_Nintendo_Entertainment_System'
}

# ROM extensions per platform
$romExtMap = @{
    'ATARI' = @('.a26', '.a78', '.bin', '.zip', '.7z')
    'FC'    = @('.nes', '.fds', '.zip', '.7z')
    'GB'    = @('.gb', '.zip', '.7z')
    'GBA'   = @('.gba', '.zip', '.7z')
    'GBC'   = @('.gbc', '.zip', '.7z')
    'GG'    = @('.gg', '.sms', '.zip', '.7z')
    'MAME'  = @('.fba', '.zip', '.7z')
    'MD'    = @('.md', '.gen', '.bin', '.zip', '.7z', '.smd')
    'NGPC'  = @('.ngp', '.ngc', '.zip', '.7z')
    'PCE'   = @('.pce', '.zip', '.7z')
    'PS'    = @('.img', '.iso', '.bin', '.cue', '.pbp', '.chd', '.zip', '.7z')
    'SFC'   = @('.sfc', '.smc', '.zip', '.7z')
}

$baseUrl = "https://raw.githubusercontent.com/libretro-thumbnails"

# Convert ROM name to libretro thumbnail name
function Get-LibretroName($baseName) {
    $n = $baseName
    # Remove region/language tags like (Europe) (En,Fr,De) (Rev 1) etc.
    $n = $n -replace '\s*\([^)]*\)', ''
    # Remove trailing whitespace
    $n = $n.Trim()
    # Replace special characters with underscore
    $n = $n -replace '[&\*/:\"<>\?\\\|]', '_'
    # Replace spaces with underscore
    $n = $n -replace ' ', '_'
    return $n
}

# Try multiple name variations to find a match
function Try-Download($repo, $baseName, $destPath) {
    $variations = @()

    # Variation 1: full basename (with region tags)
    $v1 = $baseName -replace '[&\*/:\"<>\?\\\|]', '_'
    $v1 = $v1 -replace ' ', '_'
    $variations += $v1

    # Variation 2: without region/language tags
    $v2 = Get-LibretroName $baseName
    if ($v2 -ne $v1) { $variations += $v2 }

    # Variation 3: without " - " subtitle
    if ($v2 -match '^(.+?)_-_') {
        $variations += $Matches[1]
    }

    foreach ($name in $variations) {
        $url = "$baseUrl/$repo/master/Named_Boxarts/$name.png"
        try {
            $tempFile = [System.IO.Path]::GetTempFileName()
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($url, $tempFile)
            $webClient.Dispose()

            # Resize to 320x240
            $img = [System.Drawing.Image]::FromFile($tempFile)
            $bmp = New-Object System.Drawing.Bitmap(320, 240, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $g = [System.Drawing.Graphics]::FromImage($bmp)
            $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

            # Fit maintaining aspect ratio on white background
            $ratioX = 320 / $img.Width
            $ratioY = 240 / $img.Height
            $ratio = [Math]::Min($ratioX, $ratioY)
            $newW = [int]($img.Width * $ratio)
            $newH = [int]($img.Height * $ratio)
            $posX = [int]((320 - $newW) / 2)
            $posY = [int]((240 - $newH) / 2)

            $g.Clear([System.Drawing.Color]::White)
            $g.DrawImage($img, $posX, $posY, $newW, $newH)
            $g.Dispose()
            $img.Dispose()

            $bmp.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)
            $bmp.Dispose()

            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            return $name
        } catch {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            continue
        }
    }
    return $null
}

# Determine which platforms to process
if ($Platform -ne "") {
    $platformList = @($Platform.ToUpper())
} else {
    $platformList = $repoMap.Keys | Sort-Object
}

$totalDownloaded = 0
$totalMissing = 0

foreach ($plat in $platformList) {
    if (-not $repoMap.ContainsKey($plat)) {
        Write-Output "Plateforme inconnue: $plat"
        continue
    }

    $dirPath = Join-Path $RootPath $plat
    if (-not (Test-Path $dirPath)) { continue }

    $exts = $romExtMap[$plat]
    $imagesPath = Join-Path $dirPath "images"
    $repo = $repoMap[$plat]

    # Get ROMs (filter PS tracks)
    $roms = Get-ChildItem $dirPath -File -Force -ErrorAction SilentlyContinue | Where-Object { $exts -contains $_.Extension.ToLower() } | Sort-Object Name
    if ($plat -eq 'PS' -and $roms.Count -gt 0) {
        $cueFiles = $roms | Where-Object { $_.Extension.ToLower() -eq '.cue' }
        $cueBaseNames = @{}
        foreach ($c in $cueFiles) { $cueBaseNames[$c.BaseName] = $true }
        $filtered = New-Object System.Collections.ArrayList
        foreach ($rom in $roms) {
            if ($rom.Extension.ToLower() -eq '.cue') {
                [void]$filtered.Add($rom)
            } elseif ($rom.Extension.ToLower() -eq '.bin') {
                $binBase = $rom.BaseName -replace ' \(Track \d+\)', ''
                if (-not $cueBaseNames.ContainsKey($binBase)) { [void]$filtered.Add($rom) }
            } else {
                [void]$filtered.Add($rom)
            }
        }
        $roms = $filtered
    }

    if ($roms.Count -eq 0) { continue }

    # Find ROMs without covers
    $missing = @()
    foreach ($rom in $roms) {
        $imgFile = Join-Path $imagesPath "$($rom.BaseName).png"
        if (-not (Test-Path $imgFile)) { $missing += $rom }
    }

    if ($missing.Count -eq 0) { continue }

    Write-Output ""
    Write-Output "=== $plat : $($missing.Count) covers manquantes ==="

    if (-not (Test-Path $imagesPath)) {
        New-Item -ItemType Directory -Path $imagesPath -Force | Out-Null
    }

    foreach ($rom in $missing) {
        $destPath = Join-Path $imagesPath "$($rom.BaseName).png"
        $result = Try-Download $repo $rom.BaseName $destPath
        if ($result) {
            Write-Output "  OK: $($rom.BaseName) (match: $result)"
            $totalDownloaded++
        } else {
            Write-Output "  INTROUVABLE: $($rom.BaseName)"
            $totalMissing++
        }
    }
}

Write-Output ""
Write-Output "============================================"
Write-Output "Telecharges: $totalDownloaded | Introuvables: $totalMissing"
Write-Output "============================================"
