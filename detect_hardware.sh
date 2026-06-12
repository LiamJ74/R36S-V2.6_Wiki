#!/usr/bin/env bash
# detect_hardware.sh — Identify the SoC architecture of an R36S/R36SX clone
# from its SD card. Determines whether custom firmware (ArkOS, muOS, ROCKNIX,
# dArkOSRE, ArkOS4Clone) can be flashed.
#
# Usage:
#   ./detect_hardware.sh /path/to/sd
#   ./detect_hardware.sh /Volumes/NOUVEAU\ NOM      (macOS)
#   ./detect_hardware.sh /media/$USER/SDCARD       (Linux)

set -u

SD_ROOT="${1:-}"

if [[ -z "$SD_ROOT" ]]; then
  echo "Usage: $0 <path-to-mounted-SD-root>" >&2
  exit 2
fi

if [[ ! -d "$SD_ROOT" ]]; then
  echo "Error: '$SD_ROOT' is not a directory." >&2
  exit 2
fi

RKGAME="$SD_ROOT/cubegm/rkgame"
KERNEL="$SD_ROOT/cubegm/vmlinux.uImage"
DRIVER="$SD_ROOT/cubegm/driver.so"

echo "=== R36S / R36SX hardware detection ==="
echo "SD root: $SD_ROOT"
echo

if [[ ! -f "$RKGAME" ]]; then
  echo "✗ Not a cubegm-based device — '$RKGAME' not found."
  echo "  This script only works on stock-firmware SDs that contain cubegm/."
  exit 1
fi

if ! command -v file >/dev/null 2>&1; then
  echo "Error: 'file' command not available. Install it (e.g., 'brew install file-formula' on macOS minimal setups)." >&2
  exit 2
fi

RKGAME_DESC="$(file -b "$RKGAME")"
KERNEL_DESC=""
[[ -f "$KERNEL" ]] && KERNEL_DESC="$(file -b "$KERNEL")"

echo "rkgame binary : $RKGAME_DESC"
[[ -n "$KERNEL_DESC" ]] && echo "kernel image  : $KERNEL_DESC"
echo

ARCH=""
case "$RKGAME_DESC" in
  *MIPS*)          ARCH="MIPS" ;;
  *ARM\ aarch64*|*"ARM aarch64"*) ARCH="ARM64" ;;
  *ARM*)           ARCH="ARM32" ;;
  *)               ARCH="UNKNOWN" ;;
esac

echo "Detected CPU architecture: $ARCH"
echo

case "$ARCH" in
  MIPS)
    cat <<EOF
✗ CUSTOM FIRMWARE NOT SUPPORTED

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
    * Genuine Anbernic R36S (~40 €, ARM RK3326)
    * Anbernic RG35XX H (~50 €, ARM, official ROCKNIX support)
EOF
    exit 0
    ;;

  ARM32|ARM64)
    cat <<EOF
✓ Possibly CFW-compatible (ARM architecture detected)

Your device has an ARM SoC. To know which CFW image to flash, you still
need to identify the exact SoC (RK3326 vs RK3128 vs AllWinner A33) and
the board revision.

Next steps:
1. Look for DTB files on the BOOT partition of the SD:
   ls $SD_ROOT/*.dtb $SD_ROOT/boot/*.dtb 2>/dev/null
   The DTB filename reveals the SoC (e.g., 'rk3326-*.dtb' = RK3326).

2. Check the handhelds.wiki "R36S Clones" page:
   https://handhelds.wiki/R36S_Clones

3. WARNING: never flash before identifying the exact variant. Wrong image
   = brick. Always work on a SECOND SD card and keep the original intact.

Recommended CFWs by SoC:
- RK3326   → ArkOS, muOS, ROCKNIX, dArkOSRE
- RK3128   → ROCKNIX, dArkOSRE (limited)
- A33      → very limited; check community forums
EOF
    exit 0
    ;;

  *)
    cat <<EOF
⚠ Architecture not recognized.

Raw 'file' output for rkgame:
    $RKGAME_DESC

Please open an issue on the wiki repo with this output and a photo of the
PCB (chip markings) so the table can be extended.
EOF
    exit 1
    ;;
esac
