#!/usr/bin/env python3
"""Bake the hex floor into a Lumetry room scene.

Writes one Floor sprite per grid cell into a target level `.tscn` (under its
`Floor` node) so the hex grid is visible in the Godot editor while you author a
room -- letting you see where to place objects -- instead of the floor only
appearing at runtime.

The tiles are plain: wall-cell dimming is applied at runtime by levels/level.gd
(it knows the live wall positions), so you only need to re-run this tool when a
room's grid *size* changes, not when its walls move.

Re-run it after changing a room's grid size; it replaces any floor tiles it
generated before (every child of the `Floor` node), so it is safe to run
repeatedly.

Geometry mirrors Room.Grid in levels/room.gd (SIZE / START and the odd-column
half-cell shift). The grid size comes from --width/--height, else from the
scene's Room node (grid_width / grid_height), else the 23x12 default.

Usage:
    python3 tools/generate_floor.py levels/level1/level_1.tscn
    python3 tools/generate_floor.py path/to/room.tscn --width 30 --height 16
"""
import argparse
import re
import sys
from pathlib import Path

# Grid geometry -- keep in sync with Room.Grid (levels/room.gd).
SIZE = (168.0, 192.0)   # pixels between columns / rows
START = (79.0, -17.0)   # center of cell (0, 0)

FLOOR_TEX_PATH = "res://tileset/floor/Floor.png"
FLOOR_TEX_UID = "uid://bqgn8qi0u7dg4"
FLOOR_TEX_ID = "floor_tile_tex"


def cell_center(c: int, r: int) -> tuple[float, float]:
    x = START[0] + SIZE[0] * c
    y = START[1] + SIZE[1] * r + (SIZE[1] / 2.0 if c % 2 == 1 else 0.0)
    return x, y


def num(v: float) -> str:
    return str(int(v)) if float(v).is_integer() else repr(v)


def split_chunks(text: str) -> list[list[str]]:
    """Split a .tscn into chunks; each chunk is a header line starting with '['
    plus the following property/body lines up to the next header."""
    chunks: list[list[str]] = []
    cur: list[str] | None = None
    for line in text.split("\n"):
        if line.startswith("["):
            if cur is not None:
                chunks.append(cur)
            cur = [line]
        elif cur is None:
            cur = [line]
        else:
            cur.append(line)
    if cur is not None:
        chunks.append(cur)
    return chunks


def header(chunk: list[str]) -> str:
    return chunk[0]


def body_value(chunk: list[str], key: str):
    for line in chunk[1:]:
        m = re.match(rf"\s*{re.escape(key)}\s*=\s*(.+)$", line)
        if m:
            return m.group(1).strip()
    return None


def main() -> int:
    ap = argparse.ArgumentParser(description="Bake the hex floor into a room scene.")
    ap.add_argument("scene", help="target .tscn (e.g. levels/level1/level_1.tscn)")
    ap.add_argument("--width", type=int, default=None)
    ap.add_argument("--height", type=int, default=None)
    args = ap.parse_args()

    path = Path(args.scene)
    if not path.is_file():
        print(f"error: {path} not found", file=sys.stderr)
        return 1
    chunks = split_chunks(path.read_text())

    # Reuse an existing Floor.png ext_resource id if present (\b avoids matching
    # the id= inside uid=), otherwise we add one.
    floor_id = None
    for ch in chunks:
        h = header(ch)
        if h.startswith("[ext_resource") and FLOOR_TEX_PATH in h:
            m = re.search(r'\bid="([^"]+)"', h)
            floor_id = m.group(1) if m else floor_id

    # Grid size: CLI overrides, else the Room node's exports, else 23x12.
    width, height = args.width, args.height
    if width is None or height is None:
        for ch in chunks:
            if header(ch).startswith("[node") and 'name="Room"' in header(ch):
                if width is None:
                    gw = body_value(ch, "grid_width")
                    width = int(gw) if gw is not None else 23
                if height is None:
                    gh = body_value(ch, "grid_height")
                    height = int(gh) if gh is not None else 12
                break
    width = width if width is not None else 23
    height = height if height is not None else 12

    added_ext = floor_id is None
    if added_ext:
        floor_id = FLOOR_TEX_ID

    def floor_tiles() -> list[list[str]]:
        tiles: list[list[str]] = []
        for c in range(width):
            for r in range(height):
                x, y = cell_center(c, r)
                tiles.append([
                    f'[node name="floor_{c}_{r}" type="Sprite2D" parent="Floor"]',
                    f"position = Vector2({num(x)}, {num(y)})",
                    f'texture = ExtResource("{floor_id}")',
                    "",
                ])
        return tiles

    have_floor_node = any(
        header(c).startswith("[node") and 'name="Floor"' in header(c) and 'parent="."' in header(c)
        for c in chunks
    )

    # Rebuild: drop previously generated tiles, insert fresh ones right after the
    # Floor node (creating that node before Room if the scene lacks it).
    out: list[list[str]] = []
    inserted = False
    for ch in chunks:
        h = header(ch)
        if h.startswith("[node") and 'parent="Floor"' in h:
            continue  # drop previously generated tiles
        if (not have_floor_node and not inserted and h.startswith("[node")
                and 'name="Room"' in h and 'parent="."' in h):
            out.append(['[node name="Floor" type="Node2D" parent="."]', ""])
            out.extend(floor_tiles())
            inserted = True
        out.append(ch)
        if (have_floor_node and not inserted and h.startswith("[node")
                and 'name="Floor"' in h and 'parent="."' in h):
            out.extend(floor_tiles())
            inserted = True

    if added_ext:
        out.insert(1, [f'[ext_resource type="Texture2D" uid="{FLOOR_TEX_UID}" path="{FLOOR_TEX_PATH}" id="{floor_id}"]'])

    # load_steps = (#ext_resource + #sub_resource) + 1
    res_count = sum(1 for c in out if header(c).startswith(("[ext_resource", "[sub_resource")))
    text = "\n".join(line for ch in out for line in ch)
    text = re.sub(r"load_steps=\d+", f"load_steps={res_count + 1}", text, count=1)
    path.write_text(text)

    print(f"[generate_floor] {path}: {width}x{height} = {width * height} tiles"
          f"{' (added Floor.png ext_resource)' if added_ext else ''}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
