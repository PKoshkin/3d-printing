// Shared settings and print targets for the parts in this repo.
// Include from a part: include <../../lib/printer.scad>
//
// A target is where a part gets printed: the friend's printer or a print service.
// Every part declares one on a top-level line, as the first group of its Customizer,
// offering the targets that make sense for it (Customizer drops parentheses from
// the labels, so there are none):
//
//   /* [Где печатать] */
//   // От этого зависят зазоры посадок и проверка размера
//   target = "friend"; // [friend:Принтер друга — FDM, craftcloud-fdm:Craftcloud — FDM, craftcloud-mjf:Craftcloud — нейлон PA12 MJF/SLS]
//
// and reads the target's numbers through the functions below. They are functions,
// not constants: a constant here is evaluated before the part sets target.
// tools/build.py reads the part's target line, runs this file with -Dtarget=<id> and
// takes the row from the TARGET echo at the bottom for its size check.

// Columns: id, process, build volume X/Y/Z mm, strict, per-side clearances
// slide/snug mm, min wall mm.
// - strict: a printer we know, so the part must fit. For a service the size is only
//   a warning: its vendors have different machines, and Craftcloud shows who takes
//   the part after the upload.
// - FDM prints the model as oriented in the file; powder processes (MJF, SLS) may
//   turn it any way.
// - Clearances: hole = shaft + 2 * clearance. Only the friend's printer can be
//   calibrated (parts/tolerance-test); a service's printer is unknown, hence a margin.
TARGETS = [
    // Max 20 cm, Z assumed. Clearances are placeholders until the tolerance test.
    ["friend",         "FDM", [200, 200, 200], true,  0.2, 0.1,  1.2],
    // A typical vendor FDM printer; bigger ones exist at fewer vendors.
    ["craftcloud-fdm", "FDM", [250, 250, 250], false, 0.3, 0.15, 1.2],
    // HP MJF usable volume; SLS machines are often larger.
    ["craftcloud-mjf", "MJF", [370, 274, 375], false, 0.4, 0.2,  1.0],
];

function target_row() =
    assert(!is_undef(target), "set target in the part's Customizer: where it gets printed")
    let(i = search([target], TARGETS)[0])
    assert(i != [], str("unknown target \"", target, "\", known: ", [for (t = TARGETS) t[0]]))
    TARGETS[i];

function target_process() = target_row()[1];
function target_bed() = target_row()[2];
function clearance_slide() = target_row()[4];  // moves or rotates freely
function clearance_snug() = target_row()[5];   // goes in by hand and holds
function min_wall() = target_row()[6];

$fa = 1;
$fs = 0.25;

// Runs after every assignment, so it sees the part's target; also shows it in the console.
echo(TARGET = target_row());
