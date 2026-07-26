#!/usr/bin/env python3
"""
Remove background from ALL sprite images using rembg (U²-Net).
Saves output as <name>_sin.png alongside the original.

Usage:
    python remove_bg.py [-r] <path-to-image>
    python remove_bg.py [-r] <path-to-directory>
    
    -r    recursive: scan all subdirectories for images
    
Examples:
    python remove_bg.py sprites/entorno/alpaca/alpaca.png
    python remove_bg.py sprites/base/
    python remove_bg.py -r sprites/        # ALL images recursively
"""

import sys
import argparse
from pathlib import Path

from rembg import remove
from PIL import Image

# Skip these patterns — we don't want to re-process already-cleaned images,
# and the _gen.png (4x originals) are intermediates, not game sprites.
SKIP_PATTERNS = ("_sin.", "_gen.", "_512.")


def _should_skip(filename: str) -> bool:
    return any(p in filename for p in SKIP_PATTERNS)


def process_image(image_path: Path) -> Path | None:
    """Remove background from a single image, save as _sin.png."""
    if not image_path.is_file():
        print(f"  ✗ Not a file: {image_path}")
        return None

    suffix = image_path.suffix.lower()
    if suffix not in (".png", ".jpg", ".jpeg"):
        return None  # skip non-image files

    if _should_skip(image_path.name):
        return None  # skip gen/sin/512 variants

    output_path = image_path.with_stem(image_path.stem + "_sin")

    if output_path.exists():
        return None  # already done

    print(f"    {image_path.name} ...", end=" ", flush=True)
    try:
        input_img = Image.open(image_path)
        output_img = remove(input_img)
        output_img.save(output_path, "PNG")
        print("✓")
        return output_path
    except Exception as e:
        print(f"✗ {e}")
        return None


def collect_images(root: Path, recursive: bool) -> list[Path]:
    """Gather all target images, sorted, excluding SKIP_PATTERNS."""
    if recursive:
        images = sorted(
            p for p in root.rglob("*")
            if p.suffix.lower() in (".png", ".jpg", ".jpeg")
            and not _should_skip(p.name)
            and not p.name.startswith(".")
        )
    else:
        images = sorted(
            p for p in root.iterdir()
            if p.suffix.lower() in (".png", ".jpg", ".jpeg")
            and not _should_skip(p.name)
            and not p.name.startswith(".")
        )
    return images


def main():
    parser = argparse.ArgumentParser(
        description="Remove background from sprites using rembg (U²-Net)"
    )
    parser.add_argument("target", type=Path, help="Image file or directory")
    parser.add_argument(
        "-r", "--recursive", action="store_true",
        help="Scan directories recursively"
    )
    args = parser.parse_args()

    target: Path = args.target

    if target.is_dir():
        images = collect_images(target, args.recursive)
        if not images:
            print(f"No processable images found in {target}")
            return

        # Show tree overview
        if args.recursive:
            dirs = sorted({p.parent for p in images})
            print(f"Scanning {len(dirs)} director(ies), "
                  f"{len(images)} image(s) total\n")
        else:
            print(f"Processing {len(images)} image(s) in {target}/ ...\n")

        ok = 0
        skipped = 0
        for img in images:
            out = img.with_stem(img.stem + "_sin")
            if out.exists():
                skipped += 1
                continue
            if process_image(img):
                ok += 1

        print(f"\nDone: {ok} processed, {skipped} already existed, "
              f"{len(images) - ok - skipped} failed.")
    else:
        process_image(target)


if __name__ == "__main__":
    main()
