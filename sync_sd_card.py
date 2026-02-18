#!/usr/bin/env python3
"""
sync_sd_card.py
Synchronise une carte SD de console retro portable (iCube/cubegm).

Ce que fait le script :
  1. Renomme les ROMs et images contenant des virgules (incompatible CSV)
  2. Pour chaque dossier plateforme :
     - Detecte les ROMs reels presents
     - Associe les images aux ROMs (renomme + deplace dans images/)
     - Supprime les images orphelines (pas de ROM correspondant)
     - Genere/met a jour filelist.csv
  3. Synchronise cubegm/allfiles.lst avec les ROMs reels
  4. Nettoie favorites.lst et recent.lst (supprime les entrees fantomes)

Usage :
  python sync_sd_card.py                    # Simulation (dry run)
  python sync_sd_card.py --execute          # Execution reelle
  python sync_sd_card.py --root D:\\        # Autre lettre de lecteur
"""

import os
import sys
import shutil
import argparse
from pathlib import Path

ROM_EXT_MAP = {
    'ATARI': {'.a26', '.a78', '.bin', '.zip', '.7z'},
    'FC':    {'.nes', '.fds', '.zip', '.7z'},
    'GB':    {'.gb', '.zip', '.7z'},
    'GBA':   {'.gba', '.zip', '.7z'},
    'GBC':   {'.gbc', '.zip', '.7z'},
    'GG':    {'.gg', '.sms', '.zip', '.7z'},
    'MAME':  {'.fba', '.zip', '.7z'},
    'MD':    {'.md', '.gen', '.bin', '.zip', '.7z', '.smd'},
    'NGPC':  {'.ngp', '.ngc', '.zip', '.7z'},
    'PCE':   {'.pce', '.zip', '.7z'},
    'PS':    {'.img', '.iso', '.bin', '.cue', '.pbp', '.chd', '.zip', '.7z'},
    'SFC':   {'.sfc', '.smc', '.zip', '.7z'},
}

IMG_EXTENSIONS = {'.jpg', '.jpeg', '.png', '.bmp', '.gif'}


def get_roms(dir_path: Path, extensions: set) -> list:
    """Liste les fichiers ROM dans un dossier."""
    if not dir_path.exists():
        return []
    return sorted(
        [f for f in dir_path.iterdir() if f.is_file() and f.suffix.lower() in extensions],
        key=lambda f: f.name
    )


def get_images(dir_path: Path) -> list:
    """Liste les fichiers image dans un dossier."""
    if not dir_path.exists():
        return []
    return [f for f in dir_path.iterdir() if f.is_file() and f.suffix.lower() in IMG_EXTENSIONS]


def match_score(rom_name: str, img_name: str) -> int:
    """Calcule un score de correspondance entre un ROM et une image."""
    import re
    rom_words = set(re.findall(r'[a-z0-9]{2,}', rom_name.lower()))
    img_words = set(re.findall(r'[a-z0-9]{2,}', img_name.lower()))
    if not rom_words or not img_words:
        return 0
    score = 0
    for rw in rom_words:
        for iw in img_words:
            if rw == iw or rw in iw or iw in rw:
                score += 1
                break
    return score


def load_csv(csv_path: Path) -> dict:
    """Charge un fichier CSV et retourne un dict {rom_filename: rest_of_line}."""
    data = {}
    if not csv_path.exists():
        return data
    with open(csv_path, 'r', encoding='utf-8', errors='replace') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            idx = line.index(',') if ',' in line else -1
            if idx > 0:
                data[line[:idx].strip()] = line[idx + 1:]
    return data


def sync_sd_card(root_path: str, dry_run: bool = True):
    root = Path(root_path)
    platforms = sorted(ROM_EXT_MAP.keys())

    print("=" * 50)
    print(f" SYNC SD CARD - {'SIMULATION' if dry_run else 'EXECUTION'}")
    print(f" Racine: {root}")
    print("=" * 50)
    print()

    # =========================================================================
    # ETAPE 1 : Renommer les fichiers avec virgules
    # =========================================================================
    print("--- ETAPE 1 : Renommage fichiers avec virgules ---")

    for platform in platforms:
        dir_path = root / platform
        if not dir_path.exists():
            continue
        images_path = dir_path / "images"

        # ROMs
        exts = ROM_EXT_MAP[platform]
        for f in dir_path.iterdir():
            if f.is_file() and f.suffix.lower() in exts and ',' in f.name:
                new_name = f.name.replace(',', '')
                print(f"  [{platform}] ROM: {f.name} -> {new_name}")
                if not dry_run:
                    f.rename(dir_path / new_name)

        # Images dans images/
        if images_path.exists():
            for f in images_path.iterdir():
                if f.is_file() and ',' in f.name:
                    new_name = f.name.replace(',', '')
                    print(f"  [{platform}] IMG: {f.name} -> {new_name}")
                    if not dry_run:
                        f.rename(images_path / new_name)

    print()

    # =========================================================================
    # ETAPE 2 : Synchronisation ROMs / images / CSV
    # =========================================================================
    print("--- ETAPE 2 : Synchronisation ROMs / images / CSV ---")

    for platform in platforms:
        dir_path = root / platform
        if not dir_path.exists():
            continue
        images_path = dir_path / "images"
        csv_path = dir_path / "filelist.csv"
        exts = ROM_EXT_MAP[platform]

        rom_files = get_roms(dir_path, exts)
        rom_base_names = {f.stem: f.name for f in rom_files}
        direct_images = get_images(dir_path)

        print(f"\n  === {platform} : {len(rom_files)} ROMs ===")

        # Creer images/ si necessaire
        if not images_path.exists() and rom_files:
            if not dry_run:
                images_path.mkdir(parents=True, exist_ok=True)
            print("    Dossier images/ cree")

        # Deplacer les images directes dans images/
        if direct_images and rom_files:
            used_roms = set()
            for img in direct_images:
                best_match = None
                best_score = 0
                for rom in rom_files:
                    if rom.name in used_roms:
                        continue
                    score = match_score(rom.stem, img.stem)
                    if score > best_score:
                        best_score = score
                        best_match = rom
                if best_match and best_score >= 1:
                    used_roms.add(best_match.name)
                    target_name = f"{best_match.stem}.png"
                    target_path = images_path / target_name
                    action = "DEPLACER" if dry_run else "DEPLACE"
                    print(f"    [{action}] {img.name} -> images/{target_name} (score:{best_score})")
                    if not dry_run:
                        try:
                            shutil.copy2(str(img), str(target_path))
                            img.unlink()
                        except Exception as e:
                            print(f"    [ERREUR] {e}")
                else:
                    print(f"    [?] Pas de ROM pour: {img.name}")

        # Supprimer les doublons (.gb/.gbc quand .zip existe)
        if rom_files:
            zip_stems = {f.stem for f in rom_files if f.suffix == '.zip'}
            for rom in rom_files:
                if rom.suffix != '.zip' and rom.stem in zip_stems:
                    print(f"    [DOUBLON] {rom.name}")
                    if not dry_run:
                        try:
                            rom.unlink()
                        except Exception:
                            pass

        # Nettoyer images orphelines
        if images_path.exists():
            current_roms = get_roms(dir_path, exts)
            valid_stems = {f.stem for f in current_roms}

            if current_roms:
                img_files = list(images_path.iterdir())
                kept = sum(1 for f in img_files if f.is_file() and f.stem in valid_stems)
                deleted = 0
                for f in img_files:
                    if f.is_file() and f.stem not in valid_stems:
                        deleted += 1
                        if not dry_run:
                            try:
                                f.unlink()
                            except Exception:
                                pass
                print(f"    Images: {kept} conservees, {deleted} {'a supprimer' if dry_run else 'supprimees'}")
            elif any(images_path.iterdir()):
                img_count = sum(1 for f in images_path.iterdir() if f.is_file())
                if img_count > 0:
                    print(f"    {img_count} images a nettoyer (0 ROMs)")
                    if not dry_run:
                        for f in images_path.iterdir():
                            if f.is_file():
                                try:
                                    f.unlink()
                                except Exception:
                                    pass

        # Generer CSV
        current_roms = get_roms(dir_path, exts)
        old_csv = load_csv(csv_path)

        if current_roms:
            csv_lines = []
            for rom in current_roms:
                if rom.name in old_csv:
                    csv_lines.append(f"{rom.name},{old_csv[rom.name]}")
                else:
                    csv_lines.append(f"{rom.name},{rom.stem},{rom.stem}")

            if dry_run:
                print(f"    CSV: {len(csv_lines)} entrees")
            else:
                with open(csv_path, 'w', encoding='utf-8') as f:
                    f.write('\n'.join(csv_lines) + '\n')
                print(f"    CSV cree: {len(csv_lines)} entrees")
        elif csv_path.exists():
            if dry_run:
                print("    CSV a vider (0 ROMs)")
            else:
                csv_path.write_text('', encoding='utf-8')
                print("    CSV vide (0 ROMs)")

    print()

    # =========================================================================
    # ETAPE 3 : Synchroniser allfiles.lst
    # =========================================================================
    print("--- ETAPE 3 : Synchronisation allfiles.lst ---")

    allfiles_path = root / "cubegm" / "allfiles.lst"
    if allfiles_path.exists():
        old_allfiles = {}
        with open(allfiles_path, 'r', encoding='utf-8', errors='replace') as f:
            for line in f:
                line = line.strip()
                if line:
                    parts = line.split('|')
                    if parts:
                        old_allfiles[parts[0]] = line

        new_lines = []
        for platform in platforms:
            dir_path = root / platform
            if not dir_path.exists():
                continue
            exts = ROM_EXT_MAP[platform]
            roms = get_roms(dir_path, exts)
            for rom in roms:
                key = f"{platform}/{rom.name}"
                if key in old_allfiles:
                    new_lines.append(old_allfiles[key])
                else:
                    dn = rom.stem
                    up = dn.upper()
                    new_lines.append(f"{key}|{dn}|{up}|{dn}|{dn}")

        old_count = len(old_allfiles)
        if dry_run:
            print(f"  allfiles.lst: {len(new_lines)} entrees (avant: {old_count})")
        else:
            with open(allfiles_path, 'w', encoding='utf-8') as f:
                f.write('\n'.join(new_lines) + '\n')
            print(f"  allfiles.lst mis a jour: {len(new_lines)} entrees (avant: {old_count})")

    print()

    # =========================================================================
    # ETAPE 4 : Nettoyer favoris et recents
    # =========================================================================
    print("--- ETAPE 4 : Nettoyage favoris et recents ---")

    valid_roms = set()
    for platform in platforms:
        dir_path = root / platform
        if not dir_path.exists():
            continue
        exts = ROM_EXT_MAP[platform]
        for rom in get_roms(dir_path, exts):
            valid_roms.add(f"{platform}/{rom.name}")

    for lst_name in ['favorites.lst', 'recent.lst']:
        lst_path = root / "cubegm" / lst_name
        if not lst_path.exists():
            continue

        with open(lst_path, 'r', encoding='utf-8', errors='replace') as f:
            lines = [l.strip() for l in f if l.strip()]

        kept = []
        removed = 0
        for line in lines:
            key = line.split('|')[0]
            if key in valid_roms:
                kept.append(line)
            else:
                removed += 1

        if dry_run:
            print(f"  {lst_name}: {len(kept)} gardes, {removed} a retirer")
        else:
            with open(lst_path, 'w', encoding='utf-8') as f:
                f.write('\n'.join(kept) + '\n' if kept else '')
            print(f"  {lst_name}: {len(kept)} gardes, {removed} retires")

    print()

    # =========================================================================
    # RESUME
    # =========================================================================
    print("=" * 50)
    print(" RESUME")
    print("=" * 50)

    for platform in platforms:
        dir_path = root / platform
        if not dir_path.exists():
            continue

        exts = ROM_EXT_MAP[platform]
        rom_count = len(get_roms(dir_path, exts))
        images_path = dir_path / "images"
        img_count = sum(1 for f in images_path.iterdir() if f.is_file()) if images_path.exists() else 0
        csv_path = dir_path / "filelist.csv"
        csv_count = 0
        if csv_path.exists():
            with open(csv_path, 'r', encoding='utf-8', errors='replace') as f:
                csv_count = sum(1 for l in f if l.strip())

        if rom_count == 0 and img_count == 0:
            status = "VIDE"
        elif rom_count == 0:
            status = "PAS DE ROMS"
        elif rom_count == csv_count == img_count:
            status = "OK"
        else:
            status = "MISMATCH"

        print(f"  {platform}: ROMs={rom_count} CSV={csv_count} Img={img_count} [{status}]")

    if dry_run:
        print()
        print(">>> SIMULATION - Relancer avec --execute pour appliquer <<<")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Synchronise une carte SD retro gaming')
    parser.add_argument('--root', default='H:\\', help='Chemin racine de la carte SD (defaut: H:\\)')
    parser.add_argument('--execute', action='store_true', help='Executer reellement (sinon simulation)')
    args = parser.parse_args()

    sync_sd_card(args.root, dry_run=not args.execute)
