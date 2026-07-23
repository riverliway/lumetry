#!/usr/bin/env python3
"""Expand `*.halftile.png` sprites into full, horizontally-symmetric tiles.

A `*.halftile.png` holds the LEFT half of a sprite. This script mirrors it to
build the right half and writes `<name>.png` (dropping the `.halftile` pseudo
extension). Because the result is exactly symmetric, its content is perfectly
centered on the texture, so rotating the sprite about its center never shifts
it off-axis -- which is what caused the sub-pixel seam on angled lasers.

Draw only the left half of any centered sprite as `foo.halftile.png`, then run
this to (re)generate `foo.png`.

Usage (from the project root):
    python3 tools/build_halftiles.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SEARCH_DIRS = ("tileset", "ui", "player")
SUFFIX = ".halftile.png"


def full_from_half(half: Image.Image) -> Image.Image:
    """Return a full tile: the left half plus its horizontal mirror."""
    w, h = half.size
    full = Image.new("RGBA", (w * 2, h), (0, 0, 0, 0))
    full.paste(half, (0, 0))
    full.paste(half.transpose(Image.FLIP_LEFT_RIGHT), (w, 0))
    return full


def main() -> int:
    count = 0
    for name in SEARCH_DIRS:
        root = ROOT / name
        if not root.is_dir():
            continue
        for half_path in sorted(root.rglob("*" + SUFFIX)):
            out_path = half_path.with_name(half_path.name[: -len(SUFFIX)] + ".png")
            half = Image.open(half_path).convert("RGBA")
            full = full_from_half(half)
            full.save(out_path)
            count += 1
            print(
                f"{half_path.relative_to(ROOT)} ({half.width}x{half.height})"
                f"  ->  {out_path.relative_to(ROOT)} ({full.width}x{full.height})"
            )

    if count == 0:
        print("No *.halftile.png files found under: " + ", ".join(SEARCH_DIRS))
    else:
        print(f"\nExpanded {count} half-tile(s) into full symmetric tiles.")
    return count


if __name__ == "__main__":
    main()
