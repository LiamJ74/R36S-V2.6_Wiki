# R36S / R36SX Firmware Variants — Deep Dive

Devices marketed as "R36S" or "R36SX" share a case shape but ship with at least **four distinct hardware platforms**. Custom firmware (CFW) compatibility depends entirely on the SoC and board revision. Mixing them = brick.

This document explains how to identify your variant from the SD card alone (no soldering iron, no disassembly required) and what each variant can do.

---

## TL;DR — Decision Tree

```
                  Does cubegm/rkgame exist on the SD?
                       /                      \
                      no                       yes
                      |                         |
              Not a cubegm device         Run detect_hardware.sh
              (probably EmuELEC                 /         \
              or RetroArch-based)          MIPS         ARM
              → see handhelds.wiki          |            |
                                            |     Check DTB files
                                            |     on BOOT partition
                                            |            |
                                  No CFW possible    rk3326-*.dtb
                                  ever. Stop here.    → ArkOS/muOS OK
                                                     rk3128-*.dtb
                                                     → ROCKNIX (partial)
                                                     no .dtb / weird
                                                     → research first
```

---

## Why "R36SX" doesn't mean a single device

The "R36S" form factor was originally a clone of the Anbernic RG353P, sold by no-name Shenzhen factories using whatever cheap SoC was lying around. By 2025-2026 there are at least:

1. **Genuine R36S (Anbernic-branded later runs)** — Rockchip RK3326, well-supported.
2. **R36SX v2.6 / v2.7 RK3326 clones** — Same SoC as genuine, slightly different DTB.
3. **R36SX RK3128 clones** — Cheaper Rockchip chip, reduced performance.
4. **AllWinner A33 clones** — Different SoC family entirely, very limited CFW.
5. **MIPS32 clones (this wiki's device)** — Obscure Ingenic-class MIPS SoC, no ARM compatibility at all. The deepest tier of clone.

Sellers on AliExpress, Amazon, Temu rotate stock without notice. Two units bought from the same listing one month apart can be different variants.

---

## How to identify your variant from the SD card

### Step 1 — Mount the SD card on a computer

The SD typically appears with a volume name like `NOUVEAU NOM`, `SDCARD`, or unlabeled.

### Step 2 — Run the detection script

```bash
./detect_hardware.sh /Volumes/NOUVEAU\ NOM    # macOS
./detect_hardware.sh /media/$USER/SDCARD      # Linux
```

```powershell
.\detect_hardware.ps1 -RootPath "H:\"         # Windows
```

The script reads the ELF header of `cubegm/rkgame` and reports the CPU architecture (MIPS vs ARM).

### Step 3 — If ARM: look for DTB files

DTB (Device Tree Blob) filenames reveal the exact SoC:

```bash
find /Volumes/NOUVEAU\ NOM -maxdepth 4 -iname "*.dtb"
```

| DTB filename pattern | SoC | Notes |
|----------------------|-----|-------|
| `rk3326-*.dtb` | RK3326 | Most common R36S variant |
| `rk3128-*.dtb` | RK3128 | Weaker variant, limited CFW |
| `sun8i-*.dtb` | AllWinner A33 (sun8i family) | Very limited |
| no DTB anywhere | Likely EmuELEC clone or stock cubegm | Check `rkgame` arch |

### Step 4 — If MIPS: stop here

No CFW exists. See "Why MIPS variants have no CFW path" below.

---

## Manual verification (without the script)

If you don't trust the script or want to verify yourself, on macOS/Linux:

```bash
file /Volumes/NOUVEAU\ NOM/cubegm/rkgame
```

Outputs you might see:

```
ELF 32-bit LSB executable, MIPS, MIPS32 rel2 version 1 (SYSV), ...
  → MIPS variant (no CFW possible)

ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV), ...
  → ARM32 variant (probably Rockchip — check DTB)

ELF 64-bit LSB executable, ARM aarch64, ...
  → ARM64 variant (rarer on R36S-class hardware)
```

On Windows without WSL: use `detect_hardware.ps1` (reads the ELF header directly).

---

## Why MIPS variants have no CFW path

The CFW projects (ArkOS, muOS, ROCKNIX, dArkOSRE, ArkOS4Clone) are full Linux distributions compiled for **specific ARM SoCs**. Replacing the stock firmware means:

1. **The kernel** must be built for the SoC's architecture and peripherals.
2. **The bootloader** must accept the new kernel image.
3. **All hardware drivers** (display, audio, input, battery gauge, SD/eMMC) must have working open-source equivalents.

For RK3326, all three pieces exist (mainline Linux supports the SoC well). For the MIPS variant here:

- The kernel would need to be cross-compiled for **MIPS32 rel2**. Possible but nobody is doing it for handhelds.
- The bootloader is unknown — there's no documentation, and the rootfs has no recovery image.
- **The display driver is `dsc.ko`** — a closed-source kernel module shipped only as a binary blob. Without source, you can't port it to a new kernel. Without it, the screen doesn't initialize.

A skilled embedded developer could theoretically reverse-engineer `dsc.ko`, but the unit cost (~25 €) makes the effort uneconomic compared to just buying a properly-supported handheld.

**Practical conclusion: the MIPS R36SX is permanently locked on stock cubegm.**

---

## What you CAN do on each variant

| Capability | MIPS cubegm | ARM stock cubegm | ARM + CFW (ArkOS/muOS/ROCKNIX) |
|------------|:-----------:|:----------------:|:------------------------------:|
| Add/remove ROMs | ✓ | ✓ | ✓ |
| Custom cover art | ✓ | ✓ | ✓ |
| Customize platform backgrounds | ✓ | ✓ | ✓ |
| Save state / load state hotkeys | ✓ (FN+A / FN+B) | ✓ | ✓ |
| **Fast-forward / speed control** | **✗** | **✗** | **✓** (L2 by default) |
| RetroArch quick menu (shaders, config) | ✗ | ✗ | ✓ |
| Cheats / runahead | ✗ | ✗ | ✓ |
| Real-time clock | ✗ (FAT32 1979 timestamp) | varies | ✓ |
| Bluetooth controllers | ✗ | ✗ | ✓ (varies) |
| WiFi netplay | ✗ | ✗ | ✓ (varies) |

---

## If you have the MIPS variant and want fast-forward

The honest path:

1. **PC-assisted grinding.** Copy your `.sav` from `cubegm/saves/` to a PC. Run mGBA or VBA-M, enable fast-forward (Tab key by default in mGBA), grind, save in the emulator. The `.sav` format is a raw SRAM dump — identical between the R36SX and PC emulators. Copy it back to the SD when done.

2. **Buy a different handheld.** Practical options as of June 2026:
   - **Anbernic R36S genuine** (~40 €) — Same form factor, ARM RK3326, ArkOS officially supported.
   - **Anbernic RG35XX H** (~55 €) — Slightly better hardware, ROCKNIX/muOS official builds, horizontal layout.
   - **Anbernic RG353P** (~80 €) — The device the R36S clones the case of.

Treat the R36SX MIPS as a sturdy ROM/save courier and a casual play device. For grinding sessions, use a PC.

---

## Contributing

If you have a variant not listed here (different ELF arch, different DTB pattern, different SoC marking on the PCB), please open an issue with:

- Output of `./detect_hardware.sh` (or `.ps1`)
- Output of `file cubegm/rkgame`
- Output of `ls cubegm/*.dtb` (and any other `.dtb` paths found)
- Photo of the main SoC on the PCB (the largest chip, usually with a heat-sink sticker)

The variant table will be extended.
