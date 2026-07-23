#!/usr/bin/env python3
"""Image compiler for Lumetry sprite sources.

Runs a small pipeline of asset-generation steps from hand-drawn source art:

  1. expand_halftiles -- mirror every `*.halftile.png` (the LEFT half of a
     sprite) into a full, horizontally symmetric `<name>.png`. Symmetric
     content is perfectly centered on the texture, so rotating the sprite
     about its center never shifts it off-axis (no sub-pixel rotation seam).

  2. compile_laser_mirror_cuts -- from the white laser tiles, generate the
     "beam meets a mirror" sprites: the beam sliced in half along the mirror's
     reflecting surface. One set per mirror type, because each type fixes the
     angle at which the beam meets the surface:
       * short mirror -> 120 deg bounce -> beam meets surface at 60 deg
       * long mirror  ->  60 deg bounce -> beam meets surface at 30 deg
     In Godot the mirror cell gets two of these (incoming + reflected, the
     reflected one flipped) so the bounce is drawn inside the mirror cell.

Usage (from the project root):
    python3 tools/image_compiler.py
"""
from pathlib import Path
import math

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent


# --------------------------------------------------------------------------- #
# Step 1: expand *.halftile.png -> full symmetric <name>.png
# --------------------------------------------------------------------------- #
HALFTILE_DIRS = ("tileset", "ui", "player")
HALFTILE_SUFFIX = ".halftile.png"


def full_from_half(half: Image.Image) -> Image.Image:
    """Return a full tile: the left half plus its horizontal mirror."""
    w, h = half.size
    full = Image.new("RGBA", (w * 2, h), (0, 0, 0, 0))
    full.paste(half, (0, 0))
    full.paste(half.transpose(Image.FLIP_LEFT_RIGHT), (w, 0))
    return full


def expand_halftiles() -> int:
    count = 0
    for name in HALFTILE_DIRS:
        root = ROOT / name
        if not root.is_dir():
            continue
        for half_path in sorted(root.rglob("*" + HALFTILE_SUFFIX)):
            out_path = half_path.with_name(half_path.name[: -len(HALFTILE_SUFFIX)] + ".png")
            half = Image.open(half_path).convert("RGBA")
            full_from_half(half).save(out_path)
            count += 1
            print(f"  {half_path.relative_to(ROOT)} -> {out_path.relative_to(ROOT)}")
    print(f"[halftiles] expanded {count} half-tile(s)\n" if count
          else "[halftiles] no *.halftile.png found\n")
    return count


# --------------------------------------------------------------------------- #
# Step 2: laser mirror-cut sprites
# --------------------------------------------------------------------------- #
LASER_DIR = ROOT / "tileset" / "laser" / "white_laser"
LASER_FRAMES = ("laser_white_1.png", "laser_white_2.png")

# Angle (degrees) between the vertical beam axis and the mirror surface it stops
# against. Derived from the reflection turn: surface_angle = turn / 2.
MIRROR_SURFACE_DEG = {"short": 60.0, "long": 30.0}


def mirror_cut(tile: Image.Image, surface_deg: float) -> Image.Image:
    """Keep the entry (top) half of a vertical beam, sliced along the mirror
    surface through the tile center. The surface passes through the center at
    `surface_deg` from the vertical beam axis; the far (bottom) half is erased.
    The cut edge is anti-aliased over ~1px so it stays smooth once rotated."""
    im = tile.copy()
    px = im.load()
    w, h = im.size
    cx, cy = w / 2.0, h / 2.0
    phi = math.radians(surface_deg)
    # Unit normal to the surface, pointing toward the kept (top/entry) side.
    nx, ny = math.cos(phi), -math.sin(phi)
    for y in range(h):
        for x in range(w):
            dist = (x - cx) * nx + (y - cy) * ny   # signed px distance to surface
            coverage = min(1.0, max(0.0, dist + 0.5))
            if coverage < 1.0:
                r, g, b, a = px[x, y]
                px[x, y] = (r, g, b, int(a * coverage))
    return im


def compile_laser_mirror_cuts() -> int:
    count = 0
    for kind, surface_deg in MIRROR_SURFACE_DEG.items():
        out_dir = ROOT / "tileset" / "laser" / f"white_laser_mirrored_{kind}"
        out_dir.mkdir(parents=True, exist_ok=True)
        for i, frame in enumerate(LASER_FRAMES, start=1):
            src = LASER_DIR / frame
            if not src.is_file():
                print(f"[mirror-cut] missing source {src.relative_to(ROOT)}, skipping")
                continue
            tile = Image.open(src).convert("RGBA")
            out = out_dir / f"laser_white_mirrored_{kind}_{i}.png"
            mirror_cut(tile, surface_deg).save(out)
            count += 1
            print(f"  {kind} ({surface_deg:g} deg): {out.relative_to(ROOT)}")
    print(f"[mirror-cut] wrote {count} sprite(s)\n" if count
          else "[mirror-cut] nothing generated\n")
    return count


def main() -> None:
    print("== image compiler ==")
    expand_halftiles()
    compile_laser_mirror_cuts()


if __name__ == "__main__":
    main()
