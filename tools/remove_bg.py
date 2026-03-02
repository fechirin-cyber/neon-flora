#!/usr/bin/env python3
"""
NEON FLORA - Character Background Remover
Uses rembg to automatically remove backgrounds from character images.
Originals are backed up to _backup_with_bg/ before processing.

Prerequisites:
  pip install rembg Pillow onnxruntime

Usage:
  python remove_bg.py           # Process all character images
  python remove_bg.py --char hikari  # Process only hikari images
"""

import os
import sys
import glob
from shutil import copy2

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

CHAR_DIR = "C:/xampp/htdocs/rpg_game/neon_flora/assets/images/characters"
BACKUP_DIR = "C:/xampp/htdocs/rpg_game/neon_flora/assets/images/characters/_backup_with_bg"

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--char", type=str, help="Only process specific character (hikari/luna/koharu)")
    args = parser.parse_args()

    # Check rembg
    try:
        from rembg import remove
        from PIL import Image
    except ImportError:
        print("ERROR: rembg not installed. Run:")
        print("  pip install rembg Pillow onnxruntime")
        sys.exit(1)

    os.makedirs(BACKUP_DIR, exist_ok=True)

    # Find target files
    pattern = os.path.join(CHAR_DIR, "*.png")
    all_files = sorted(glob.glob(pattern))

    # Exclude backup dir and non-character files
    targets = []
    for f in all_files:
        basename = os.path.basename(f)
        if basename.startswith("_"):
            continue
        if args.char and not basename.startswith(args.char):
            continue
        targets.append(f)

    if not targets:
        print("No character images found to process.")
        sys.exit(0)

    print("NEON FLORA - Background Remover")
    print(f"Source: {CHAR_DIR}")
    print(f"Backup: {BACKUP_DIR}")
    print(f"Targets: {len(targets)} images")
    print("=" * 60)

    results = []

    for idx, filepath in enumerate(targets, 1):
        basename = os.path.basename(filepath)
        print(f"\n[{idx}/{len(targets)}] {basename}")

        # Backup original
        backup_path = os.path.join(BACKUP_DIR, basename)
        if not os.path.exists(backup_path):
            copy2(filepath, backup_path)
            print(f"  Backed up to {backup_path}")

        try:
            img = Image.open(filepath)
            original_size = img.size
            print(f"  Input: {original_size} mode={img.mode}")

            # Remove background
            result = remove(img)
            result = result.convert("RGBA")

            # Save
            result.save(filepath, "PNG")
            fsize = os.path.getsize(filepath)
            print(f"  Output: {result.size} RGBA, {fsize:,} bytes")
            results.append((basename, "OK", fsize))

        except Exception as e:
            print(f"  FAILED: {e}")
            results.append((basename, f"FAILED: {e}", 0))

    # Summary
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    for fname, status, size in results:
        print(f"  {fname:<25} {size:>10,} bytes  {status}")

    failed = [r for r in results if "FAILED" in r[1]]
    if failed:
        print(f"\n{len(failed)} file(s) FAILED.")
        sys.exit(1)
    else:
        print(f"\nAll {len(targets)} images processed.")


if __name__ == "__main__":
    main()
