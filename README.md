# R36S Retro Handheld — Complete Wiki

Complete guide for managing and customizing the **R36S** retro gaming handheld SD card.

The R36S is a cheap handheld sold under various brand names. It runs a Linux-based firmware using the **iCube/cubegm** menu system. Despite being marketed as an "R36S", it is not made by Anbernic — it is an unbranded clone with no official manufacturer.

---

## Table of Contents

- [Quick Start](#quick-start)
- [SD Card Structure](#sd-card-structure)
- [Prerequisites](#prerequisites)
- [Adding Games](#adding-games)
- [Cover Images](#cover-images)
- [Sync Scripts](#sync-scripts)
- [File Formats](#file-formats)
- [Supported ROM Extensions](#supported-rom-extensions)
- [Customizing Platform Backgrounds](#customizing-platform-backgrounds)
- [Firmware Internals](#firmware-internals)
- [Troubleshooting](#troubleshooting)
- [Known Limitations](#known-limitations)

---

## Quick Start

```powershell
# Preview changes (dry run)
powershell -ExecutionPolicy Bypass -File sync_sd_card.ps1

# Apply changes
powershell -ExecutionPolicy Bypass -File sync_sd_card.ps1 -DryRun $false
```

```bash
# Preview changes (dry run)
python sync_sd_card.py

# Apply changes
python sync_sd_card.py --execute
```

Both scripts accept a custom root path (`-RootPath "D:\"` / `--root D:\`) if your SD card is not on `H:\`.

---

## SD Card Structure

```
H:\
├── cubegm/                     # System / menu firmware
│   ├── rkgame                  # Main menu binary
│   ├── icube                   # Launcher binary
│   ├── icube_start.sh          # Startup script
│   ├── UI_Res.cpd              # UI resources (backgrounds, icons) — ZIP format
│   ├── resource.cpd            # Core UI layout — ZIP format
│   ├── ui_en.cpd               # English language pack (one per language)
│   ├── setting.xml             # User settings (language, volume, hotkeys)
│   ├── allfiles.lst            # Master game index (pipe-delimited)
│   ├── favorites.lst           # User favorites
│   ├── recent.lst              # Recently played
│   ├── cores/                  # Emulator cores (.so libraries)
│   │   ├── config.xml          # Maps file extensions to emulator cores
│   │   └── filelist.xml        # Per-game core overrides
│   ├── saves/                  # Save files
│   ├── states/                 # Save states (organized by platform)
│   ├── lib/                    # Shared libraries + BIOS files
│   └── language/               # Localized UI images
│
├── ATARI/                      # One folder per platform
│   ├── *.a26                   # ROM files
│   ├── filelist.csv            # Game list for this platform
│   └── images/                 # Cover art (PNG, 320x240 recommended)
│       └── GameName.png        # Must match ROM basename
│
├── FC/    GB/    GBA/   GBC/
├── GG/    MAME/  MD/    NGPC/
├── PCE/   PS/    SFC/
│
├── rootfs/                     # Linux root filesystem (DO NOT TOUCH)
├── BGM/                        # Background music
├── Ebook/  Movie/  Music/      # Media player content
└── Photo/
```

---

## Prerequisites

The SD card must already contain the **cubegm firmware and folder structure**. This is the case for any SD card that shipped with the console. The scripts only manage ROMs, cover images, and game lists — they do **not** install or modify the system firmware.

Required system files and folders (do not delete):

| Path | Purpose |
|------|---------|
| `cubegm/` | Menu system, emulator cores, saves, settings |
| `cubegm/cores/` | Emulator libraries (`.so` files) and core config |
| `cubegm/allfiles.lst` | Master game index (managed by the script) |
| `cubegm/saves/` | Save files |
| `cubegm/states/` | Save states |
| `rootfs/` | Linux root filesystem (do not touch) |
| `ATARI/` `FC/` `GB/` ... | Platform folders (one per emulated system) |

Required platform folders must exist at the root: `ATARI`, `FC`, `GB`, `GBA`, `GBC`, `GG`, `MAME`, `MD`, `NGPC`, `PCE`, `PS`, `SFC`. The scripts do not create these — they must already be present on the card.

Other folders on the card (`BGM/`, `Ebook/`, `Movie/`, `Music/`, `Photo/`) are for the console's media player and are unrelated to game emulation.

---

## Adding Games

### Where to put ROMs

Each platform has its own folder at the root of the SD card. Drop your ROM files directly into the matching folder:

```
H:\GB\MyGame.zip
H:\GBA\Pokemon Fire Red.gba
H:\PS\Crash Bandicoot (Europe).zip
```

- Use `.zip` when possible — the script will automatically remove uncompressed duplicates (e.g., deletes `game.gb` if `game.zip` exists)
- Filenames with commas are fine — the script will rename them automatically
- **Avoid accented characters** in filenames (é, è, ê, etc.) — they can cause display issues on the console
- See [Supported ROM Extensions](#supported-rom-extensions) for accepted file types per platform

### What you don't need to do

- **Don't edit `filelist.csv`** — the script generates it from the ROMs present
- **Don't edit `allfiles.lst`** — the script rebuilds it automatically
- **Don't manually create `images/`** — the script creates it if needed
- **Don't worry about commas in filenames** — the script sanitizes them

---

## Cover Images

### Recommended format

- **Format:** PNG
- **Size:** 320x240 pixels (landscape). This matches the internal `nodata.raw` placeholder used by the firmware.
- **Name:** Must match the ROM filename without extension (e.g., `Zelda.zip` → `images/Zelda.png`)

The firmware loads PNG images and scales them at runtime, but oversized images (800x800, etc.) may cause display glitches or show the wrong cover on some games. **Always resize to 320x240 for reliable results.**

### Option A — Let the script match them (bulk adds)

Drop the cover images **next to the ROMs** in the platform folder (not inside `images/`):

```
H:\GB\MyGame.zip           # ROM
H:\GB\my-game-cover.png    # Cover image (any name)
H:\GB\another_cover.jpg    # JPG, PNG, BMP, GIF accepted
```

The script will fuzzy-match each image to the closest ROM, rename it to `ROMBaseName.png`, convert to the correct format, and move it into `images/`.

### Option B — Place them directly in `images/` (precise control)

Put the image in the `images/` subfolder with the **exact same basename** as the ROM:

```
H:\GB\Donkey Kong Land.zip
H:\GB\images\Donkey Kong Land.png    # Must match exactly (without ROM extension)
```

Images already in `images/` with a matching ROM are left untouched. Orphan images (no matching ROM) are deleted by the script.

### Image matching algorithm

When images are placed next to ROMs, the script uses fuzzy keyword matching:

1. Both the ROM and image filenames are split into words (2+ alphanumeric characters)
2. Each ROM word is compared against each image word (exact match, or substring)
3. The image is assigned to the ROM with the highest match score (minimum 1)
4. Unmatched images are reported but left untouched

For best results, name your cover images similarly to the ROM files. Exact basename matches always work perfectly.

---

## Sync Scripts

Both scripts are **safe by default** — they run in dry-run (simulation) mode and will only show what *would* change. You must explicitly opt in to apply modifications.

### What the scripts do

| Step | Action | Details |
|------|--------|---------|
| 1 | **Sanitize filenames** | Removes commas from ROM and image filenames (commas break the CSV format) |
| 2 | **Match cover images to ROMs** | Fuzzy keyword matching between image and ROM filenames, then renames and moves images into `images/` |
| 3 | **Remove duplicates** | When both `game.zip` and `game.gb` exist, keeps the `.zip` and deletes the other |
| 4 | **Clean orphan images** | Deletes images in `images/` that don't match any existing ROM |
| 5 | **Generate `filelist.csv`** | Creates or updates the per-platform game list based on actual ROM files |
| 6 | **Sync `allfiles.lst`** | Rebuilds the master game index to match real ROMs across all platforms |
| 7 | **Clean `favorites.lst` / `recent.lst`** | Removes entries that reference non-existent ROMs |

> **Key principle:** ROMs are the source of truth. Everything else (CSV, images, allfiles.lst) is derived from the ROMs actually present on the card.

### Typical workflow

1. Copy ROM files (`.zip`, `.gba`, etc.) into the appropriate platform folder
2. Drop cover images next to the ROMs (any filename — the script will match them)
3. Run the script in **dry-run mode** to preview changes
4. Run again with **execute mode** to apply
5. Safely eject the SD card and test on the console

---

## File Formats

### `filelist.csv` (per-platform game list)

```
filename.ext,Display Name,Chinese Name
```

- One line per ROM
- First field is the exact ROM filename (including extension)
- Filenames must **not** contain commas (the script renames them automatically)

### `allfiles.lst` (master game index)

```
Platform/filename.ext|Display Name|UPPERCASE NAME|Chinese Name|Abbreviated
```

- Pipe-delimited, one line per ROM across all platforms
- Existing display names and Chinese names are preserved when updating
- New entries use the ROM basename as a placeholder for all name fields

### `favorites.lst` / `recent.lst`

```
Platform/filename.ext
```

- One entry per line
- The script removes entries that reference non-existent ROMs

---

## Supported ROM Extensions

| Platform | Extensions |
|----------|-----------|
| ATARI | `.a26` `.a78` `.bin` `.zip` `.7z` |
| FC (NES) | `.nes` `.fds` `.zip` `.7z` |
| GB (Game Boy) | `.gb` `.zip` `.7z` |
| GBA (Game Boy Advance) | `.gba` `.zip` `.7z` |
| GBC (Game Boy Color) | `.gbc` `.zip` `.7z` |
| GG (Game Gear) | `.gg` `.sms` `.zip` `.7z` |
| MAME (Arcade) | `.fba` `.zip` `.7z` |
| MD (Mega Drive / Genesis) | `.md` `.gen` `.bin` `.zip` `.7z` `.smd` |
| NGPC (Neo Geo Pocket Color) | `.ngp` `.ngc` `.zip` `.7z` |
| PCE (PC Engine / TurboGrafx) | `.pce` `.zip` `.7z` |
| PS (PlayStation) | `.img` `.iso` `.bin` `.cue` `.pbp` `.chd` `.zip` `.7z` |
| SFC (Super Famicom / SNES) | `.sfc` `.smc` `.zip` `.7z` |

---

## Customizing Platform Backgrounds

The console displays a 640x480 background image for each platform in the main menu. These images are stored inside `cubegm/UI_Res.cpd`, which is a **ZIP archive** containing raw BGRA image files.

### Background files inside `UI_Res.cpd`

Each platform has a `.raw` file (640x480 pixels, 4 bytes per pixel in BGRA format = 1,228,800 bytes):

```
ATARI.raw  FC.raw  GB.raw  GBA.raw  GBC.raw  GG.raw  MAME.raw
MD.raw  NGPC.raw  PCE.raw  PS1.raw  SFC.raw  SMS.raw  SWC.raw
AllEMU.raw  DOWNLOAD.raw  FAVORITE.raw  HISTORY.raw
```

There are also icon sprite sheets (`Emu_Icon_0.raw`, `Emu_Icon_1.raw`) and other UI elements.

### How to replace a platform background

**Requirements:** PowerShell with .NET Framework (Windows)

#### Step 1 — Extract the current background (optional, for reference)

```powershell
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Drawing

# Extract raw file from CPD
$zip = [System.IO.Compression.ZipFile]::OpenRead("H:\cubegm\UI_Res.cpd")
$entry = $zip.GetEntry("GBA.raw")
$stream = $entry.Open()
$bytes = New-Object byte[] $entry.Length
$stream.Read($bytes, 0, $bytes.Length)
$stream.Close()
$zip.Dispose()

# Convert BGRA raw to PNG for viewing
$bmp = New-Object System.Drawing.Bitmap(640, 480, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$bmpData = $bmp.LockBits(
    (New-Object System.Drawing.Rectangle(0, 0, 640, 480)),
    [System.Drawing.Imaging.ImageLockMode]::WriteOnly,
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
)
[System.Runtime.InteropServices.Marshal]::Copy($bytes, 0, $bmpData.Scan0, $bytes.Length)
$bmp.UnlockBits($bmpData)
$bmp.Save("GBA_current.png", [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
```

#### Step 2 — Create your new background

Create a **640x480 PNG** image using any image editor (Photoshop, GIMP, Paint.NET, etc.). This will be the full-screen background shown when navigating to that platform.

#### Step 3 — Convert and inject

```powershell
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression.FileSystem

$pngPath  = "my_new_background.png"
$cpdPath  = "H:\cubegm\UI_Res.cpd"
$entryName = "GBA.raw"   # Change to target platform

# Backup original (first time only)
if (-not (Test-Path "$cpdPath.bak")) {
    Copy-Item $cpdPath "$cpdPath.bak"
}

# Load PNG and resize to 640x480
$img = New-Object System.Drawing.Bitmap($pngPath)
$bmp = New-Object System.Drawing.Bitmap(640, 480, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.DrawImage($img, 0, 0, 640, 480)
$g.Dispose()
$img.Dispose()

# Extract raw BGRA bytes
$bmpData = $bmp.LockBits(
    (New-Object System.Drawing.Rectangle(0, 0, 640, 480)),
    [System.Drawing.Imaging.ImageLockMode]::ReadOnly,
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
)
$rawBytes = New-Object byte[] (640 * 480 * 4)
[System.Runtime.InteropServices.Marshal]::Copy($bmpData.Scan0, $rawBytes, 0, $rawBytes.Length)
$bmp.UnlockBits($bmpData)
$bmp.Dispose()

# Replace inside CPD
$zip = [System.IO.Compression.ZipFile]::Open($cpdPath, [System.IO.Compression.ZipArchiveMode]::Update)
$entry = $zip.GetEntry($entryName)
$stream = $entry.Open()
$stream.SetLength(0)
$stream.Write($rawBytes, 0, $rawBytes.Length)
$stream.Close()
$zip.Dispose()

Write-Output "$entryName replaced. Eject SD card and test."
```

#### Restoring the original

```powershell
Copy-Item "H:\cubegm\UI_Res.cpd.bak" "H:\cubegm\UI_Res.cpd" -Force
```

---

## Firmware Internals

### Boot process

1. The device boots Linux from `rootfs/`
2. `cubegm/icube_start.sh` is called, which kills `hcprojector` (stock media player) and launches `cubegm/icube`
3. `icube` starts the main menu binary `cubegm/rkgame`
4. `rkgame` loads UI resources from `.cpd` archives and game lists from `allfiles.lst` / `filelist.csv`

### Key binaries

| File | Purpose |
|------|---------|
| `cubegm/rkgame` | Main menu engine (1.1 MB) — loads UI, browses games, launches emulators |
| `cubegm/icube` | Small launcher/wrapper (12 KB) |
| `cubegm/driver.so` | Display/hardware driver |

### Emulator cores

Cores are `.so` shared libraries in `cubegm/cores/`. The mapping between file extensions and cores is in `cubegm/cores/config.xml`. Notable cores:

| Core | Platforms |
|------|-----------|
| `libemu_mgba.so` | GBA, GB, GBC (mGBA) |
| `libemu_gpsp.so` | GBA (gpSP) |
| `libemu_tgbdual.so` | GBC, GB (TGB Dual) |
| `libemu_fceumm.so` | FC/NES |
| `libemu_snes9x2005.so` | SFC/SNES |
| `libemu_picodrive.so` | MD/Genesis |
| `libemu_pcsx_rearmed.so` | PS1 |
| `libemu_fbalpha.so` | MAME/Arcade |

Per-game core overrides can be set in `cubegm/cores/filelist.xml`:

```xml
<file name="GBA/SomeGame.zip" core="libemu_mgba.so" />
```

### UI resources

| File | Format | Contents |
|------|--------|----------|
| `UI_Res.cpd` | ZIP | Platform backgrounds (640x480 BGRA raw), icon sprite sheets, settings screens |
| `resource.cpd` | ZIP | Game list layout (`game.raw`), menu layout (`menu.raw`), no-data placeholder, `ui.cfg` |
| `ui_*.cpd` | ZIP | Language-specific overlays (26 languages) |
| `joystick.cpd` | ZIP | Controller mapping images |

### Screen specs

- **Screen resolution:** 640x480
- **Cover art display area:** ~320x240 (scaled from PNG at runtime)
- **No-data placeholder:** 320x240 RGB565 (`nodata.raw` inside `resource.cpd`)

### Settings

User settings are stored in `cubegm/setting.xml`:

- Language, volume, brightness, screen mode
- Hotkeys: SELECT+START (game menu), FN+A (quicksave), FN+B (quickload)

---

## Troubleshooting

### Wrong cover art showing on games

**Cause:** Cover images are too large or have inconsistent dimensions. The firmware's thumbnail renderer may fail to load oversized PNGs correctly.

**Fix:** Resize all cover images to **320x240** PNG. The `resize_covers.ps1` script or the sync scripts handle this.

### Games not appearing in menu

**Cause:** `allfiles.lst` is out of sync with actual ROM files.

**Fix:** Run the sync script. It rebuilds `allfiles.lst` from the ROMs actually present on the card.

### CSV parsing errors / broken game names

**Cause:** ROM filenames containing commas break the CSV format.

**Fix:** The sync script automatically removes commas from filenames. Run it to sanitize.

### Accented characters display wrong

**Cause:** The firmware's font rendering may not support all Unicode characters properly.

**Fix:** Rename ROMs to avoid accented characters (é→e, è→e, ê→e, etc.) before running the sync script.

### Save states missing after renaming ROMs

**Cause:** Save states are stored by ROM filename in `cubegm/states/PLATFORM/`. Renaming a ROM breaks the link to its save state.

**Fix:** Rename the corresponding save state files in `cubegm/states/` to match the new ROM name.

---

## Known Limitations

- **GBC and GBA share similar platform icons** in the sidebar. The small icons are packed into sprite sheets (`Emu_Icon_0.raw` / `Emu_Icon_1.raw`) inside `UI_Res.cpd` with an undocumented format. The full-screen platform backgrounds can be customized (see [Customizing Platform Backgrounds](#customizing-platform-backgrounds)).
- **Chinese names for new ROMs** are set to the ROM basename as a placeholder. Existing Chinese names in CSV and allfiles.lst are preserved on updates.
- **Image matching is heuristic.** For ROMs with very different names from their cover art (e.g., a date-named screenshot), manual renaming before running the script is recommended.
- **Platform list is hardcoded** in the `rkgame` binary. You cannot add new platforms, only manage ROMs within the existing ones.
- **No official documentation** exists for this device. All technical details were reverse-engineered from the firmware files.
