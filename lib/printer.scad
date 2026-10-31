// Shared printer and material constants for the parts in this repo.
// Include from a part: include <../../lib/printer.scad>
// tools/build.py also reads BED from here for the "fits the bed" check.

NOZZLE = 0.4;           // mm
LAYER = 0.2;            // mm
BED = [256, 256, 256];  // build volume X, Y, Z in mm; assumed Bambu-class until we know the friend's printers

// Per-side clearances in mm: hole = shaft + 2 * clearance.
// Placeholders: replace with the results of parts/tolerance-test.
CLEARANCE_SLIDE = 0.2;  // moves or rotates freely
CLEARANCE_SNUG = 0.1;   // goes in by hand and holds

$fa = 1;
$fs = 0.25;
