# detect_hardware.ps1 — Identify the SoC architecture of an R36S/R36SX clone
# from its SD card. Determines whether custom firmware (ArkOS, muOS, ROCKNIX,
# dArkOSRE, ArkOS4Clone) can be flashed.
#
# Usage:
#   .\detect_hardware.ps1 -RootPath "H:\"
#   .\detect_hardware.ps1                       # defaults to H:\

[CmdletBinding()]
param(
    [string]$RootPath = "H:\"
)

$ErrorActionPreference = 'Stop'

Write-Host "=== R36S / R36SX hardware detection ==="
Write-Host "SD root: $RootPath"
Write-Host ""

$rkgame = Join-Path $RootPath "cubegm\rkgame"
$kernel = Join-Path $RootPath "cubegm\vmlinux.uImage"

if (-not (Test-Path $rkgame)) {
    Write-Host "X Not a cubegm-based device — '$rkgame' not found." -ForegroundColor Red
    Write-Host "  This script only works on stock-firmware SDs that contain cubegm\."
    exit 1
}

# Read first 64 bytes (ELF header is 52 bytes, we grab a bit more)
function Get-ElfMachine {
    param([string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)[0..63]

    # ELF magic check: 0x7F 'E' 'L' 'F'
    if ($bytes[0] -ne 0x7F -or $bytes[1] -ne 0x45 -or $bytes[2] -ne 0x4C -or $bytes[3] -ne 0x46) {
        return @{ Valid = $false; Machine = "not-an-ELF" }
    }

    # e_machine is at offset 0x12 (little-endian, 2 bytes)
    $eMachine = $bytes[0x12] -bor ($bytes[0x13] -shl 8)

    # ELF machine codes (subset relevant to retro handhelds)
    $machineMap = @{
        0x03  = "x86 (Intel 80386)"
        0x08  = "MIPS"
        0x28  = "ARM (32-bit)"
        0xB7  = "ARM64 (aarch64)"
        0xF3  = "RISC-V"
    }

    $name = if ($machineMap.ContainsKey($eMachine)) { $machineMap[$eMachine] } else { "unknown (e_machine=0x{0:X})" -f $eMachine }
    return @{ Valid = $true; Machine = $name; Code = $eMachine }
}

$rk = Get-ElfMachine -Path $rkgame
if (-not $rk.Valid) {
    Write-Host "X '$rkgame' is not a valid ELF binary." -ForegroundColor Red
    exit 1
}

Write-Host "rkgame ELF machine : $($rk.Machine)"

$arch = switch ($rk.Code) {
    0x08  { "MIPS" }
    0x28  { "ARM32" }
    0xB7  { "ARM64" }
    default { "UNKNOWN" }
}

Write-Host ""
Write-Host "Detected CPU architecture: $arch" -ForegroundColor Cyan
Write-Host ""

switch ($arch) {
    "MIPS" {
        Write-Host "X CUSTOM FIRMWARE NOT SUPPORTED" -ForegroundColor Red
        Write-Host @"

This device uses a MIPS32 SoC (likely an Ingenic JZ-series or comparable
Chinese chip). It is NOT a Rockchip RK3326/RK3128 R36S — it shares only
the case shape.

All popular custom firmwares (ArkOS, muOS, ROCKNIX, dArkOSRE, ArkOS4Clone)
are ARM-only and will refuse to boot. The proprietary 'dsc.ko' display
driver has no public source, so porting is impractical.

You are LOCKED on stock cubegm firmware permanently.

Implications:
- No fast-forward (rkgame binary doesn't implement it)
- No RetroArch features (shaders, runahead, netplay)
- Only 4 configurable hotkeys (see README "Settings")

If you need fast-forward / advanced emulator features, your options are:
- Use a PC emulator (mGBA, VBA-M) — transfer .sav files via SD card
- Buy a different handheld:
    * Genuine Anbernic R36S (~40 EUR, ARM RK3326)
    * Anbernic RG35XX H (~50 EUR, ARM, official ROCKNIX support)
"@
    }
    { $_ -in "ARM32","ARM64" } {
        Write-Host "OK Possibly CFW-compatible (ARM architecture detected)" -ForegroundColor Green
        Write-Host @"

Your device has an ARM SoC. To know which CFW image to flash, you still
need to identify the exact SoC (RK3326 vs RK3128 vs AllWinner A33) and
the board revision.

Next steps:
1. Look for DTB files on the BOOT partition of the SD.
   The DTB filename reveals the SoC (e.g., 'rk3326-*.dtb' = RK3326).

2. Check the handhelds.wiki "R36S Clones" page:
   https://handhelds.wiki/R36S_Clones

3. WARNING: never flash before identifying the exact variant. Wrong image
   = brick. Always work on a SECOND SD card and keep the original intact.

Recommended CFWs by SoC:
- RK3326   -> ArkOS, muOS, ROCKNIX, dArkOSRE
- RK3128   -> ROCKNIX, dArkOSRE (limited)
- A33      -> very limited; check community forums
"@
    }
    default {
        Write-Host "! Architecture not recognized." -ForegroundColor Yellow
        Write-Host "  Raw e_machine code: 0x{0:X}" -f $rk.Code
        Write-Host "  Please open an issue with this output and a PCB photo."
    }
}
