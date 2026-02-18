###############################################################################
# sync_sd_card.ps1
# Synchronise une carte SD de console retro portable (iCube/cubegm)
#
# Ce que fait le script :
#   1. Renomme les ROMs et images contenant des virgules (incompatible CSV)
#   2. Pour chaque dossier plateforme :
#      - Detecte les ROMs reels presents
#      - Associe les images aux ROMs (renomme + deplace dans images/)
#      - Supprime les images orphelines (pas de ROM correspondant)
#      - Genere/met a jour filelist.csv
#   3. Synchronise cubegm/allfiles.lst avec les ROMs reels
#   4. Nettoie favorites.lst et recent.lst (supprime les entrees fantomes)
#
# Usage :
#   powershell -ExecutionPolicy Bypass -File sync_sd_card.ps1
#   powershell -ExecutionPolicy Bypass -File sync_sd_card.ps1 -DryRun $false
#
# Par defaut le script tourne en mode SIMULATION ($DryRun = $true)
###############################################################################

param(
    [string]$RootPath = "H:\",
    [bool]$DryRun = $true
)

# Extensions ROM par plateforme
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

# Extensions image
$imgExtensions = @('.jpg', '.jpeg', '.png', '.bmp', '.gif')

$platforms = $romExtMap.Keys | Sort-Object

# Fonction: lister les ROMs d'un dossier (filtre les tracks BIN/CUE pour PS)
function Get-GameRoms($dirPath, $exts, $platform) {
    $allRoms = Get-ChildItem $dirPath -File -Force -ErrorAction SilentlyContinue | Where-Object { $exts -contains $_.Extension.ToLower() } | Sort-Object Name
    if ($platform -eq 'PS' -and $allRoms.Count -gt 0) {
        $cueFiles = $allRoms | Where-Object { $_.Extension.ToLower() -eq '.cue' }
        $cueBaseNames = @{}
        foreach ($c in $cueFiles) { $cueBaseNames[$c.BaseName] = $true }
        $filtered = New-Object System.Collections.ArrayList
        foreach ($rom in $allRoms) {
            if ($rom.Extension.ToLower() -eq '.cue') {
                [void]$filtered.Add($rom)
            } elseif ($rom.Extension.ToLower() -eq '.bin') {
                $binBase = $rom.BaseName -replace ' \(Track \d+\)', ''
                if (-not $cueBaseNames.ContainsKey($binBase)) { [void]$filtered.Add($rom) }
            } else {
                [void]$filtered.Add($rom)
            }
        }
        return $filtered
    }
    return $allRoms
}

Write-Output "============================================"
Write-Output " SYNC SD CARD - $(if ($DryRun) { 'SIMULATION' } else { 'EXECUTION' })"
Write-Output " Racine: $RootPath"
Write-Output "============================================"
Write-Output ""

###############################################################################
# ETAPE 1 : Renommer les fichiers contenant des virgules
###############################################################################
Write-Output "--- ETAPE 1 : Renommage fichiers avec virgules ---"

foreach ($dirName in $platforms) {
    $dirPath = Join-Path $RootPath $dirName
    if (-not (Test-Path $dirPath)) { continue }
    $imagesPath = Join-Path $dirPath "images"

    # ROMs avec virgules
    $exts = $romExtMap[$dirName]
    $roms = Get-ChildItem $dirPath -File -Force -ErrorAction SilentlyContinue | Where-Object { $exts -contains $_.Extension.ToLower() -and $_.Name -match ',' }
    foreach ($rom in $roms) {
        $newName = $rom.Name -replace ',', ''
        if ($DryRun) { Write-Output "  [$dirName] ROM: $($rom.Name) -> $newName" }
        else { Rename-Item -Path $rom.FullName -NewName $newName -Force; Write-Output "  [$dirName] ROM renomme: $newName" }
    }

    # Images avec virgules dans images/
    if (Test-Path $imagesPath) {
        $imgs = Get-ChildItem $imagesPath -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match ',' }
        foreach ($img in $imgs) {
            $newName = $img.Name -replace ',', ''
            if ($DryRun) { Write-Output "  [$dirName] IMG: $($img.Name) -> $newName" }
            else { Rename-Item -Path $img.FullName -NewName $newName -Force; Write-Output "  [$dirName] IMG renomme: $newName" }
        }
    }
}
Write-Output ""

###############################################################################
# ETAPE 2 : Associer images aux ROMs, nettoyer, generer CSV
###############################################################################
Write-Output "--- ETAPE 2 : Synchronisation ROMs / images / CSV ---"

foreach ($dirName in $platforms) {
    $dirPath = Join-Path $RootPath $dirName
    if (-not (Test-Path $dirPath)) { continue }
    $imagesPath = Join-Path $dirPath "images"
    $csvPath = Join-Path $dirPath "filelist.csv"
    $exts = $romExtMap[$dirName]

    # Lister les ROMs reels (filtre tracks PS)
    $romFiles = Get-GameRoms $dirPath $exts $dirName
    $romBaseNames = @{}
    foreach ($r in $romFiles) { $romBaseNames[$r.BaseName] = $r.Name }

    # Lister les images directes (a cote des ROMs, pas dans images/)
    $directImages = Get-ChildItem $dirPath -File -Force -ErrorAction SilentlyContinue | Where-Object { $imgExtensions -contains $_.Extension.ToLower() }

    Write-Output ""
    Write-Output "  === $dirName : $($romFiles.Count) ROMs ==="

    # Creer images/ si necessaire
    if (-not (Test-Path $imagesPath) -and $romFiles.Count -gt 0) {
        if (-not $DryRun) { New-Item -ItemType Directory -Path $imagesPath -Force | Out-Null }
        Write-Output "    Dossier images/ cree"
    }

    # Deplacer les images directes dans images/ (renomme avec nom du ROM)
    if ($directImages.Count -gt 0 -and $romFiles.Count -gt 0) {
        foreach ($img in $directImages) {
            # Chercher le ROM correspondant par nom similaire
            $bestMatch = $null
            $bestScore = 0

            foreach ($rom in $romFiles) {
                $score = 0
                $romWords = ($rom.BaseName.ToLower() -replace '[^a-z0-9]', ' ').Split(' ') | Where-Object { $_.Length -ge 2 }
                $imgWords = ($img.BaseName.ToLower() -replace '[^a-z0-9]', ' ').Split(' ') | Where-Object { $_.Length -ge 2 }
                foreach ($rw in $romWords) {
                    foreach ($iw in $imgWords) {
                        if ($rw -eq $iw -or $rw.Contains($iw) -or $iw.Contains($rw)) { $score++; break }
                    }
                }
                if ($score -gt $bestScore) { $bestScore = $score; $bestMatch = $rom }
            }

            if ($bestMatch -and $bestScore -ge 1) {
                $targetName = "$($bestMatch.BaseName).png"
                $targetPath = Join-Path $imagesPath $targetName
                if ($DryRun) { Write-Output "    [DEPLACER] $($img.Name) -> images/$targetName (score:$bestScore)" }
                else {
                    Copy-Item -Path $img.FullName -Destination $targetPath -Force -ErrorAction SilentlyContinue
                    Remove-Item -Path $img.FullName -Force -ErrorAction SilentlyContinue
                    Write-Output "    [DEPLACE] $($img.Name) -> images/$targetName"
                }
            } else {
                Write-Output "    [?] Pas de ROM pour: $($img.Name)"
            }
        }
    }

    # Supprimer les doublons (.gb/.gbc quand .zip existe)
    if ($romFiles.Count -gt 0) {
        $zipRoms = $romFiles | Where-Object { $_.Extension -eq '.zip' }
        $nonZipRoms = $romFiles | Where-Object { $_.Extension -ne '.zip' }
        foreach ($nz in $nonZipRoms) {
            $zipVersion = $zipRoms | Where-Object { $_.BaseName -eq $nz.BaseName }
            if ($zipVersion) {
                if ($DryRun) { Write-Output "    [DOUBLON] $($nz.Name) (zip existe)" }
                else { Remove-Item -Path $nz.FullName -Force -ErrorAction SilentlyContinue; Write-Output "    [DOUBLON SUPPRIME] $($nz.Name)" }
            }
        }
    }

    # Nettoyer les images orphelines dans images/
    if ((Test-Path $imagesPath) -and $romFiles.Count -gt 0) {
        # Re-lire les ROMs apres suppression des doublons
        $currentRoms = Get-ChildItem $dirPath -File -Force -ErrorAction SilentlyContinue | Where-Object { $exts -contains $_.Extension.ToLower() }
        $validBaseNames = @{}
        foreach ($r in $currentRoms) { $validBaseNames[$r.BaseName] = $true }

        $imgFiles = Get-ChildItem $imagesPath -File -ErrorAction SilentlyContinue
        $kept = 0; $deleted = 0
        foreach ($img in $imgFiles) {
            if ($validBaseNames.ContainsKey($img.BaseName)) { $kept++ }
            else {
                $deleted++
                if (-not $DryRun) { Remove-Item $img.FullName -Force -ErrorAction SilentlyContinue }
            }
        }
        Write-Output "    Images: $kept conservees, $deleted $(if ($DryRun) {'a supprimer'} else {'supprimees'})"
    }
    elseif ((Test-Path $imagesPath) -and $romFiles.Count -eq 0) {
        # Pas de ROMs = supprimer toutes les images
        $imgCount = (Get-ChildItem $imagesPath -File -ErrorAction SilentlyContinue | Measure-Object).Count
        if ($imgCount -gt 0) {
            Write-Output "    $imgCount images a nettoyer (0 ROMs)"
            if (-not $DryRun) {
                Get-ChildItem $imagesPath -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
            }
        }
    }

    # Generer le CSV (utilise les memes ROMs filtres)
    $currentRoms = $romFiles

    # Charger l'ancien CSV
    $oldCsvData = @{}
    if (Test-Path $csvPath) {
        $oldLines = Get-Content $csvPath -Encoding UTF8 -ErrorAction SilentlyContinue | Where-Object { $_.Trim() -ne '' }
        foreach ($line in $oldLines) {
            $firstComma = $line.IndexOf(',')
            if ($firstComma -gt 0) { $oldCsvData[$line.Substring(0, $firstComma).Trim()] = $line.Substring($firstComma + 1) }
        }
    }

    if ($currentRoms.Count -gt 0) {
        $csvContent = New-Object System.Collections.ArrayList
        foreach ($rom in $currentRoms) {
            if ($oldCsvData.ContainsKey($rom.Name)) {
                [void]$csvContent.Add("$($rom.Name),$($oldCsvData[$rom.Name])")
            } else {
                [void]$csvContent.Add("$($rom.Name),$($rom.BaseName),$($rom.BaseName)")
            }
        }
        if ($DryRun) { Write-Output "    CSV: $($csvContent.Count) entrees" }
        else { $csvContent | Out-File -FilePath $csvPath -Encoding UTF8 -Force; Write-Output "    CSV cree: $($csvContent.Count) entrees" }
    }
    elseif (Test-Path $csvPath) {
        if ($DryRun) { Write-Output "    CSV a vider (0 ROMs)" }
        else { Set-Content -Path $csvPath -Value "" -Encoding UTF8 -Force; Write-Output "    CSV vide (0 ROMs)" }
    }
}

Write-Output ""

###############################################################################
# ETAPE 3 : Synchroniser allfiles.lst
###############################################################################
Write-Output "--- ETAPE 3 : Synchronisation allfiles.lst ---"

$allfilesPath = Join-Path $RootPath "cubegm\allfiles.lst"
if (Test-Path $allfilesPath) {
    # Charger les anciennes entrees pour recuperer les noms chinois
    $oldAllfiles = @{}
    $oldLines = Get-Content $allfilesPath -Encoding UTF8 -ErrorAction SilentlyContinue | Where-Object { $_.Trim() -ne '' }
    foreach ($line in $oldLines) {
        $parts = $line.Split('|')
        if ($parts.Count -ge 1) { $oldAllfiles[$parts[0]] = $line }
    }

    $allContent = New-Object System.Collections.ArrayList
    foreach ($dirName in $platforms) {
        $dirPath = Join-Path $RootPath $dirName
        if (-not (Test-Path $dirPath)) { continue }
        $exts = $romExtMap[$dirName]
        $roms = Get-GameRoms $dirPath $exts $dirName

        foreach ($rom in $roms) {
            $key = "$dirName/$($rom.Name)"
            if ($oldAllfiles.ContainsKey($key)) {
                [void]$allContent.Add($oldAllfiles[$key])
            } else {
                $dn = $rom.BaseName; $up = $dn.ToUpper()
                [void]$allContent.Add("$key|$dn|$up|$dn|$dn")
            }
        }
    }

    $oldCount = $oldAllfiles.Count
    if ($DryRun) { Write-Output "  allfiles.lst: $($allContent.Count) entrees (avant: $oldCount)" }
    else { $allContent | Out-File -FilePath $allfilesPath -Encoding UTF8 -Force; Write-Output "  allfiles.lst mis a jour: $($allContent.Count) entrees (avant: $oldCount)" }
}

Write-Output ""

###############################################################################
# ETAPE 4 : Nettoyer favoris et recents
###############################################################################
Write-Output "--- ETAPE 4 : Nettoyage favoris et recents ---"

# Construire la liste des ROMs valides
$validRoms = @{}
foreach ($dirName in $platforms) {
    $dirPath = Join-Path $RootPath $dirName
    if (-not (Test-Path $dirPath)) { continue }
    $exts = $romExtMap[$dirName]
    $roms = Get-GameRoms $dirPath $exts $dirName
    foreach ($rom in $roms) { $validRoms["$dirName/$($rom.Name)"] = $true }
}

foreach ($lstName in @('favorites.lst', 'recent.lst')) {
    $lstPath = Join-Path $RootPath "cubegm\$lstName"
    if (-not (Test-Path $lstPath)) { continue }

    $lines = Get-Content $lstPath -Encoding UTF8 -ErrorAction SilentlyContinue | Where-Object { $_.Trim() -ne '' }
    $kept = New-Object System.Collections.ArrayList
    $removed = 0

    foreach ($line in $lines) {
        $key = ($line.Split('|'))[0]
        if ($validRoms.ContainsKey($key)) { [void]$kept.Add($line) }
        else { $removed++ }
    }

    if ($DryRun) { Write-Output "  $lstName : $($kept.Count) gardes, $removed a retirer" }
    else {
        if ($kept.Count -gt 0) { $kept | Out-File -FilePath $lstPath -Encoding UTF8 -Force }
        else { Set-Content -Path $lstPath -Value "" -Encoding UTF8 -Force }
        Write-Output "  $lstName : $($kept.Count) gardes, $removed retires"
    }
}

Write-Output ""

###############################################################################
# RESUME
###############################################################################
Write-Output "============================================"
Write-Output " RESUME"
Write-Output "============================================"

foreach ($dirName in $platforms) {
    $dirPath = Join-Path $RootPath $dirName
    if (-not (Test-Path $dirPath)) { continue }

    $exts = $romExtMap[$dirName]
    $romCount = (Get-GameRoms $dirPath $exts $dirName | Measure-Object).Count
    $imagesPath = Join-Path $dirPath "images"
    $imgCount = 0
    if (Test-Path $imagesPath) { $imgCount = (Get-ChildItem $imagesPath -File -ErrorAction SilentlyContinue | Measure-Object).Count }
    $csvPath = Join-Path $dirPath "filelist.csv"
    $csvCount = 0
    if (Test-Path $csvPath) { $csvCount = (Get-Content $csvPath -Encoding UTF8 -ErrorAction SilentlyContinue | Where-Object { $_.Trim() -ne '' } | Measure-Object).Count }

    $status = if ($romCount -eq 0 -and $imgCount -eq 0) { "VIDE" }
              elseif ($romCount -eq 0) { "PAS DE ROMS" }
              elseif ($romCount -eq $csvCount -and $romCount -eq $imgCount) { "OK" }
              else { "MISMATCH" }

    Write-Output "  $dirName : ROMs=$romCount CSV=$csvCount Img=$imgCount [$status]"
}

if ($DryRun) {
    Write-Output ""
    Write-Output ">>> SIMULATION - Relancer avec -DryRun `$false pour executer <<<"
}
