#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["trimesh>=4", "networkx>=3", "pillow>=10.1"]
# ///
"""Build parts: export 3MF and STL, render previews, check the mesh and the size.

Usage: uv run tools/build.py [--target <id>] parts/<name> [parts/<name> ...]

A part lives in parts/<name>/<name>.scad; outputs go to parts/<name>/out/. The size
is checked against the part's print target (TARGETS in lib/printer.scad); --target
builds for another target instead, into parts/<name>/out/<id>/.
Exits non-zero if OpenSCAD prints warnings or errors, a mesh check fails, or the part
does not fit a strict target.
"""

import argparse
import json
import re
import subprocess
import sys
import tempfile
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


def part_target(scad: Path) -> str:
    """Return the print target a part declares on its top-level `target = "<id>";` line."""
    match = re.search(r'^target\s*=\s*"([^"]+)"', scad.read_text(), re.MULTILINE)
    if not match:
        raise RuntimeError(f'{scad.name} has no target = "<id>"; line: where it gets printed')
    return match.group(1)


def target_profile(target: str) -> dict:
    """Look a target up in lib/printer.scad, which echoes its row of TARGETS."""
    with tempfile.TemporaryDirectory() as tmp:
        echo = Path(tmp) / "target.echo"
        openscad(PRINTER_SCAD, echo, "--export-format=echo", f'-Dtarget="{target}"')
        text = echo.read_text()
    match = re.search(r"^ECHO: TARGET = (.+)$", text, re.MULTILINE)
    if not match:
        # An unknown id fails the assert in target_row(); its message lists the known ones.
        error = re.search(r'^ERROR: .*?failed: "(.*)" in file', text, re.MULTILINE)
        raise RuntimeError(error.group(1) if error else f"{PRINTER_SCAD.name} echoed no TARGET")
    target_id, process, bed, strict = json.loads(match.group(1))[:4]
    return {"id": target_id, "process": process, "bed": bed, "strict": strict}


def fits(size: tuple[float, ...], bed: list[float], any_orientation: bool) -> bool:
    """Whether a box of this size fits the build volume: turned on the bed, or any way."""
    if any_orientation:
        return all(s <= b for s, b in zip(sorted(size), sorted(bed)))
    (sx, sy, sz), (bx, by, bz) = size, bed
    return sz <= bz and ((sx <= bx and sy <= by) or (sx <= by and sy <= bx))


def contact_sheet(views: dict[str, Path], dest: Path) -> None:
    """Tile the view images 2x2, each labelled with its name."""
    sheet = Image.new("RGB", (2 * VIEW_W, 2 * VIEW_H), "white")
    draw = ImageDraw.Draw(sheet)
    for i, (name, png) in enumerate(views.items()):
        x, y = (i % 2) * VIEW_W, (i // 2) * VIEW_H
        sheet.paste(Image.open(png), (x, y))
        draw.text((x + 12, y + 8), name, fill="black", font_size=28)
    sheet.save(dest)


def check_mesh(
    stl: Path, summary: Path, target: dict
) -> tuple[list[str], list[str], list[str]]:
    """Return report lines, failed checks and warnings for the exported mesh."""
    mesh = trimesh.load_mesh(stl)
    bodies = len(mesh.split(only_watertight=False))
    sx, sy, sz = mesh.extents
    bx, by, bz = target["bed"]
    # FDM prints the model as oriented in the file; powder processes may turn it any way.
    in_volume = fits((sx, sy, sz), target["bed"], target["process"] != "FDM")
    strict = target["strict"]
    # OpenSCAD only reports "simple" after a CSG operation; a bare extrusion has none.
    simple = json.loads(summary.read_text())["geometry"].get("simple")
    report = [
        f"target:   {target['id']} ({target['process']}, "
        f"{'must fit' if strict else 'size is only a warning'})",
        f"size:     {sx:.1f} × {sy:.1f} × {sz:.1f} mm (build volume {bx:g} × {by:g} × {bz:g}: "
        f"{'fits' if in_volume else 'DOES NOT FIT' if strict else 'bigger'})",
        f"bodies:   {bodies}",
        f"volume:   {mesh.volume / 1000:.1f} cm³",
        f"mesh:     {'watertight' if mesh.is_watertight else 'NOT WATERTIGHT'}, "
        f"{'consistent winding' if mesh.is_winding_consistent else 'INCONSISTENT WINDING'}"
        + ("" if simple is None else f", {'manifold' if simple else 'NOT MANIFOLD'}"),
    ]
    checks = {
        f"does not fit the {target['id']} build volume": in_volume or not strict,
        "mesh is not watertight": mesh.is_watertight,
        "mesh has inconsistent face winding": mesh.is_winding_consistent,
        "OpenSCAD reports non-manifold geometry": simple is not False,
    }
    warnings = []
    if not in_volume and not strict:
        warnings.append(
            f"bigger than a typical {target['id']} printer: fewer vendors take it, "
            "check the offers after the upload"
        )
    return report, [msg for msg, ok in checks.items() if not ok], warnings


def build(part_dir: Path, target_override: str | None) -> bool:
    name = part_dir.name
    scad = part_dir / f"{name}.scad"
    if not scad.is_file():
        print(f"== {name}\nFAIL: {scad} not found")
        return False
    try:
        target = target_profile(target_override or part_target(scad))
    except RuntimeError as err:
        print(f"== {name}\nFAIL: {err}")
        return False
    # The part's own target is its Customizer default; another one goes in as -D.
    defines = [f'-Dtarget="{target_override}"'] if target_override else []
    out = part_dir / "out" / target_override if target_override else part_dir / "out"
    out.mkdir(parents=True, exist_ok=True)
    stl, summary = out / f"{name}.stl", out / "summary.json"

    problems = openscad(scad, out / f"{name}.3mf", *defines)
    problems += openscad(
        scad,
        stl,
        *defines,
        "--export-format=binstl",
        "--summary=all",
        f"--summary-file={summary}",
    )
    views = {}
    for view, ((rx, ry, rz), projection) in VIEWS.items():
        views[view] = out / f"view-{view}.png"
        problems += openscad(
            scad,
            views[view],
            *defines,
            "--render",
            f"--camera=0,0,0,{rx},{ry},{rz},0",
            "--viewall",
            "--autocenter",
            f"--projection={projection}",
            f"--imgsize={VIEW_W},{VIEW_H}",
        )
    contact_sheet(views, out / "preview.png")

    report, failures, warnings = check_mesh(stl, summary, target)
    problems = list(dict.fromkeys(problems))  # every OpenSCAD run repeats them
    print(f"== {name}")
    print(f"files:    {out.relative_to(ROOT)}/{name}.3mf, {name}.stl, preview.png")
    print(*report, sep="\n")
    print(f"openscad: {len(problems)} warning(s)" if problems else "openscad: clean")
    for line in problems:
        print(f"  {line}")
    for warning in warnings:
        print(f"WARN: {warning}")
    for failure in failures:
        print(f"FAIL: {failure}")
    return not problems and not failures


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("parts", nargs="+", type=Path, help="part directories, parts/<name>")
    parser.add_argument(
        "--target", help="build for this print target instead of the part's own, into out/<id>/"
    )
    args = parser.parse_args()
    results = [build(part.resolve(), args.target) for part in args.parts]
    return 0 if all(results) else 1


if __name__ == "__main__":
    sys.exit(main())
