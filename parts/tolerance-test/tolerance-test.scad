// Clearance test: a plate with holes sized peg + 2 * clearance, and a peg to try in each.
// Modelled in print orientation: the plate lies flat, the peg stands on its flange.
// Self-contained on purpose (only BOSL2), so the file can be shared as is.

include <BOSL2/std.scad>

/* [Пробник] */
// Диаметр штифта, мм
peg_d = 10; // [6:0.5:20]
// Зазоры на сторону, мм (отверстие = штифт + 2 × зазор)
clearances = [0.1, 0.15, 0.2, 0.25, 0.3, 0.4];
// Толщина пластины, мм
plate_t = 5; // [3:0.5:10]

/* [Hidden] */
$fa = 1;
$fs = 0.25;

wall = 4;              // between the holes and to the plate edges
text_size = 4;
text_depth = 0.6;      // 3 layers at 0.2 mm
text_gap = 2;          // between the hole row and the labels
hole_chamfer = 0.4;    // eats the elephant foot at the bottom, lead-in at the top
peg_chamfer = 0.6;
flange_h = 2.4;
flange_d = peg_d + 6;
shaft_h = plate_t + 6; // sticks out of the plate so the peg can be pushed back out
eps = 0.01;

n = len(clearances);
hole_max = peg_d + 2 * max(clearances);
pitch = hole_max + wall;
plate_l = n * pitch + wall;
plate_w = wall + hole_max + text_gap + text_size + wall;
hole_y = plate_w / 2 - wall - hole_max / 2;
text_y = -plate_w / 2 + wall + text_size / 2;

function hole_x(i) = (i - (n - 1) / 2) * pitch;

// Through-hole along Z from z=0 to z=h with 45° chamfers at both ends.
module chamfered_hole(d, h, c) {
    translate([0, 0, -eps]) cylinder(d = d, h = h + 2 * eps);
    translate([0, 0, -eps]) cylinder(d1 = d + 2 * (c + eps), d2 = d, h = c + eps);
    translate([0, 0, h - c]) cylinder(d1 = d, d2 = d + 2 * (c + eps), h = c + eps);
}

module plate() {
    difference() {
        cuboid([plate_l, plate_w, plate_t], rounding = 2, edges = "Z", anchor = BOTTOM);
        for (i = [0 : n - 1]) {
            translate([hole_x(i), hole_y, 0])
                chamfered_hole(peg_d + 2 * clearances[i], plate_t, hole_chamfer);
            translate([hole_x(i), text_y, plate_t - text_depth])
                linear_extrude(text_depth + eps)
                    text(str(clearances[i]), size = text_size, font = "Liberation Sans:style=Bold",
                         halign = "center", valign = "center");
        }
    }
}

module peg() {
    cyl(h = flange_h, d = flange_d, rounding2 = 0.8, anchor = BOTTOM);
    up(flange_h - eps) cyl(h = shaft_h + eps, d = peg_d, chamfer2 = peg_chamfer, anchor = BOTTOM);
}

plate();
back(plate_w / 2 + wall + flange_d / 2) peg();
