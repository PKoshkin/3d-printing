#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow>=10.1"]
# ///
"""Render labelled views of a part into one sheet: close-ups, sections, variants.

Usage:
  uv run sheet.py parts/<name> <sheet> --view "Label" [openscad args ...] [--view ...]

Every --view starts a tile; the arguments after its label go to OpenSCAD as is:
--camera=..., --projection=o|p, --render, -Dname=value, --viewall, --autocenter.
Without --render OpenSCAD draws the preview, which also shows %-modifier context.
Writes parts/<name>/out/<sheet>.png and prints its path.
"""

import math
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

TILE_W, TILE_H = 900, 600
# Labels are in Russian, and Pillow's built-in font has no Cyrillic.
FONT_PATH = "/System/Library/Fonts/Supplemental/Arial.ttf"


def parse_views(args: list[str]) -> list[tuple[str, list[str]]]:
    """Split the arguments into (label, openscad args) per --view."""
    views: list[tuple[str, list[str]]] = []
    it = iter(args)
    for arg in it:
        if arg == "--view":
            label = next(it, None)
            if label is None:
                raise SystemExit("--view needs a label")
            views.append((label, []))
        elif not views:
            raise SystemExit(f"{arg!r} comes before the first --view")
        else:
            views[-1][1].append(arg)
    if not views:
        raise SystemExit(__doc__)
    return views


def render(scad: Path, png: Path, args: list[str]) -> list[str]:
    """Render one view; return OpenSCAD's warning and error lines."""
    proc = subprocess.run(
        ["openscad", "--backend=Manifold", *args, f"--imgsize={TILE_W},{TILE_H}",
         "-o", str(png), str(scad)],
        capture_output=True, text=True,
    )
    if proc.returncode != 0:
        raise SystemExit(f"openscad failed:\n{proc.stderr}")
    return [line for line in proc.stderr.splitlines() if line.startswith(("WARNING", "ERROR"))]


def main() -> None:
    if len(sys.argv) < 4:
        raise SystemExit(__doc__)
    part_dir, sheet_name = Path(sys.argv[1]), sys.argv[2]
    views = parse_views(sys.argv[3:])
    scad = part_dir / f"{part_dir.name}.scad"
    if not scad.is_file():
        raise SystemExit(f"{scad} not found")
    out = part_dir / "out"
    out.mkdir(exist_ok=True)

    cols = len(views) if len(views) <= 3 else math.ceil(math.sqrt(len(views)))
    rows = math.ceil(len(views) / cols)
    sheet = Image.new("RGB", (cols * TILE_W, rows * TILE_H), "white")
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype(FONT_PATH, 28)
    except OSError:
        font = ImageFont.load_default(28)
    problems = []
    with tempfile.TemporaryDirectory() as tmp:
        for i, (label, args) in enumerate(views):
            png = Path(tmp) / f"{i}.png"
            problems += render(scad, png, args)
            x, y = (i % cols) * TILE_W, (i // cols) * TILE_H
            sheet.paste(Image.open(png), (x, y))
            draw.text((x + 12, y + 8), label, fill="black", font=font)
    dest = out / f"{sheet_name}.png"
    sheet.save(dest)
    for line in dict.fromkeys(problems):  # every OpenSCAD run repeats them
        print(line)
    print(dest)


if __name__ == "__main__":
    main()
