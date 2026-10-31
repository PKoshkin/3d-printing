#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["trimesh>=4", "networkx>=3", "pillow>=10.1"]
# ///
"""Build parts: export 3MF and STL, render previews, check the mesh.

Usage: uv run tools/build.py parts/<name> [parts/<name> ...]

A part lives in parts/<name>/<name>.scad; outputs go to parts/<name>/out/.
Exits non-zero if OpenSCAD prints warnings or errors, or a mesh check fails.
"""

import json
import re
import subprocess
import sys
from pathlib import Path

import trimesh
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
PRINTER_SCAD = ROOT / "lib" / "printer.scad"
OPENSCAD = ["openscad", "--backend=Manifold"]

# view name -> (gimbal camera rotation x, y, z; projection: p = perspective, o = ortho)
VIEWS = {
    "iso": ((55, 0, 25), "p"),
    "iso-back": ((55, 0, 205), "p"),
    "top": ((0, 0, 0), "o"),
    "front": ((90, 0, 0), "o"),
}
VIEW_W, VIEW_H = 800, 600


def openscad(scad: Path, out: Path, *args: str) -> list[str]:
    """Run OpenSCAD with one output file; return its warning and error lines."""
    proc = subprocess.run(
        [*OPENSCAD, *args, "-o", str(out), str(scad)], capture_output=True, text=True
    )
    if proc.returncode != 0:
        raise RuntimeError(f"openscad failed on {out.name}:\n{proc.stderr}")
    return [
        line
        for line in proc.stderr.splitlines()
        if line.startswith(("WARNING", "ERROR", "DEPRECATED"))
    ]


def bed_size() -> tuple[float, ...]:
    """Read BED = [x, y, z] from lib/printer.scad."""
    match = re.search(r"^BED\s*=\s*\[([^\]]+)\]", PRINTER_SCAD.read_text(), re.MULTILINE)
    if not match:
        raise RuntimeError(f"BED = [x, y, z] not found in {PRINTER_SCAD}")
    return tuple(float(v) for v in match.group(1).split(","))


def contact_sheet(views: dict[str, Path], dest: Path) -> None:
    """Tile the view images 2x2, each labelled with its name."""
    sheet = Image.new("RGB", (2 * VIEW_W, 2 * VIEW_H), "white")
    draw = ImageDraw.Draw(sheet)
    for i, (name, png) in enumerate(views.items()):
        x, y = (i % 2) * VIEW_W, (i // 2) * VIEW_H
        sheet.paste(Image.open(png), (x, y))
        draw.text((x + 12, y + 8), name, fill="black", font_size=28)
    sheet.save(dest)


def check_mesh(stl: Path, summary: Path) -> tuple[list[str], list[str]]:
    """Return report lines and failed checks for the exported mesh."""
    mesh = trimesh.load_mesh(stl)
    bodies = len(mesh.split(only_watertight=False))
    sx, sy, sz = mesh.extents
    bx, by, bz = bed_size()
    fits = sz <= bz and ((sx <= bx and sy <= by) or (sx <= by and sy <= bx))
    manifold = json.loads(summary.read_text())["geometry"].get("simple", False)
    report = [
        f"size:     {sx:.1f} × {sy:.1f} × {sz:.1f} mm "
        f"(bed {bx:g} × {by:g} × {bz:g}: {'fits' if fits else 'DOES NOT FIT'})",
        f"bodies:   {bodies}",
        f"volume:   {mesh.volume / 1000:.1f} cm³",
        f"mesh:     {'watertight' if mesh.is_watertight else 'NOT WATERTIGHT'}, "
        f"{'manifold' if manifold else 'NOT MANIFOLD'}",
    ]
    checks = {
        "does not fit the bed": fits,
        "mesh is not watertight": mesh.is_watertight,
        "OpenSCAD reports non-manifold geometry": manifold,
    }
    return report, [msg for msg, ok in checks.items() if not ok]


def build(part_dir: Path) -> bool:
    name = part_dir.name
    scad = part_dir / f"{name}.scad"
    if not scad.is_file():
        print(f"== {name}\nFAIL: {scad} not found")
        return False
    out = part_dir / "out"
    out.mkdir(exist_ok=True)
    stl, summary = out / f"{name}.stl", out / "summary.json"

    problems = openscad(scad, out / f"{name}.3mf")
    problems += openscad(
        scad, stl, "--export-format=binstl", "--summary=all", f"--summary-file={summary}"
    )
    views = {}
    for view, ((rx, ry, rz), projection) in VIEWS.items():
        views[view] = out / f"view-{view}.png"
        problems += openscad(
            scad,
            views[view],
            "--render",
            f"--camera=0,0,0,{rx},{ry},{rz},0",
            "--viewall",
            "--autocenter",
            f"--projection={projection}",
            f"--imgsize={VIEW_W},{VIEW_H}",
        )
    contact_sheet(views, out / "preview.png")

    report, failures = check_mesh(stl, summary)
    problems = list(dict.fromkeys(problems))  # every OpenSCAD run repeats them
    print(f"== {name}")
    print(f"files:    {out.relative_to(ROOT)}/{name}.3mf, {name}.stl, preview.png")
    print(*report, sep="\n")
    print(f"openscad: {len(problems)} warning(s)" if problems else "openscad: clean")
    for line in problems:
        print(f"  {line}")
    for failure in failures:
        print(f"FAIL: {failure}")
    return not problems and not failures


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    results = [build(Path(arg).resolve()) for arg in sys.argv[1:]]
    return 0 if all(results) else 1


if __name__ == "__main__":
    sys.exit(main())
