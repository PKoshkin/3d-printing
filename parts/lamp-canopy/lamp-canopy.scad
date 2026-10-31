// Ceiling canopy for the IKEA SINNERLIG pendant (and other IKEA lamps with the same
// hook bracket and cord-grip nut), wider than the stock one so that it covers a
// ceiling hook drilled away from the wire outlet.
//
// How the lamp hangs (IKEA assembly instructions AA-2212219): a hook in the ceiling
// carries a metal bracket; the cord is wound through it and the bracket ends in a
// threaded plastic stem. The stem pokes through the hole in the bottom of the canopy,
// and the cord grip (a flanged nut) is screwed onto it from below, pressing the canopy
// rim to the ceiling. So the canopy is centred on the hook and only has to cover the
// hook, the bracket and the wire outlet, and repeat the stock stepped hole the nut
// fits: a through hole with a shallow recess around it on the outside.
//
// Modelled in print orientation: rim (ceiling side) on the bed, bottom face up. The
// visible outer surface then faces up and prints clean; supports, if any, stay inside.

include <../../lib/printer.scad>

/* [Размер] */
// Внутренний радиус у потолка: от точки крюка до внутренней стенки, мм
inner_r = 112; // [30:1:130]

/* [Колпак] */
// Форма
style = "dome"; // [dome:Купол, cone:Конус]
// Высота колпака, мм (как у родного, ЗАМЕРИТЬ)
height = 60; // [30:1:100]
// Толщина стенки, мм
wall = 2.4; // [1.6:0.2:4]
// Скругление нижней кромки конуса, мм
cone_fillet = 10; // [0:1:25]
// Полнота купола: больше — ближе к полусфере
dome_fullness = 0.5; // [0.2:0.05:0.8]
// Поддержки внутри при печати. Без них низ полости сужается (только для конуса)
supports_inside = true;

/* [Низ: отверстие под фиксатор] */
// Диаметр сквозного отверстия, мм (у родного 30,9)
hole_d = 30.9; // [10:0.1:40]
// Диаметр ступеньки снаружи, мм (у родного 35)
recess_d = 35; // [10:0.1:45]
// Глубина ступеньки, мм (у родного 0,8)
recess_depth = 0.8; // [0:0.1:3]
// Толщина дна у отверстия, мм
bottom_t = 2.4; // [1.2:0.2:6]

/* [Просмотр] */
// Разрез пополам (только для просмотра, перед экспортом выключить)
section = false;
// Потолок, крюк и родной колпак (только в предпросмотре F5)
show_context = true;

/* [Hidden] */
installed = false;    // flip to the hanging position, for comparison renders only
stock_d = 75;         // stock canopy, estimated from the IKEA measurement drawing
stock_h = 60;
hook_len = 40;        // IKEA: the hook sticks out 20-40 mm
// Hidden inner surface, degrees from vertical. With supports the wall stays uniform and
// the cavity contains the stock canopy's; without them the cavity narrows towards the
// hole (a dome's flat bottom would then fill up with solid material).
max_overhang = supports_inside ? 89 : 60;

r_top = inner_r + wall;                  // outer radius at the ceiling
// Stock hole sizes plus print compensation: printed holes come out a bit small.
r_hole = hole_d / 2 + CLEARANCE_SNUG;
r_recess = recess_d / 2 + CLEARANCE_SNUG;
r_seat = r_recess + 1;                   // flat ring around the recess
z_top = height - bottom_t;               // top of the inner cavity, at the hole

assert(bottom_t >= recess_depth + 0.8, "the bottom under the recess would be too thin to print");

function unit(v) = v / norm(v);
function wrap(a) = a > 180 ? a - 360 : a <= -180 ? a + 360 : a;

// Arc of radius rf replacing the corner b between the directions to p and q.
function fillet(p, b, q, rf, n = 24) =
    let(u1 = unit(p - b), u2 = unit(q - b),
        half = acos(u1 * u2) / 2,
        c = b + unit(u1 + u2) * rf / sin(half),
        t1 = b + u1 * rf / tan(half),
        t2 = b + u2 * rf / tan(half),
        a1 = atan2(t1.y - c.y, t1.x - c.x),
        sweep = wrap(atan2(t2.y - c.y, t2.x - c.x) - a1))
    [for (i = [0 : n]) c + rf * [cos(a1 + sweep * i / n), sin(a1 + sweep * i / n)]];

function bezier(p0, p1, p2, p3, n = 64) =
    [for (i = [0 : n]) let(t = i / n)
        pow(1 - t, 3) * p0 + 3 * pow(1 - t, 2) * t * p1 + 3 * (1 - t) * t * t * p2 + pow(t, 3) * p3];

// Outer side surface as [r, z] points from the rim (z = 0) to the bottom face (z = height).
function cone_side() =
    let(a = [r_top, 0],
        half = acos(unit(a - [r_seat, height]) * [-1, 0]) / 2,
        b = [r_seat + cone_fillet / tan(half), height])  // fillet ends at the seat edge
    cone_fillet > 0 ? concat([a], fillet(a, b, [0, height], cone_fillet)) : [a, [r_seat, height]];

function dome_side() =
    bezier([r_top, 0], [r_top, dome_fullness * height],
           [r_seat + dome_fullness * (r_top - r_seat), height], [r_seat, height]);

side = style == "dome" ? dome_side() : cone_side();

// Uniform-wall inner surface: every outer point moved inwards along the normal.
inner = [for (i = [0 : len(side) - 1])
    let(d = unit(side[min(i + 1, len(side) - 1)] - side[max(i - 1, 0)]))
    side[i] + wall * [-d.y, d.x]];

// Drop points that would break the z order lookup() needs.
function increasing(pts, i = 0, last = -1e9) =
    i == len(pts) ? [] :
    pts[i].y > last ? concat([pts[i]], increasing(pts, i + 1, pts[i].y)) : increasing(pts, i + 1, last);

inner_table = [for (p = increasing(inner)) [p.y, p.x]];

// Scan from the cavity top down: the cavity may widen downwards by at most
// tan(max_overhang) per mm, so its ceiling never needs supports.
steps = ceil(z_top / 0.5);
dz = z_top / steps;
function cavity_wall(i = 0, prev = undef) =
    i > steps ? [] :
    let(z = z_top - i * dz,
        r = min(lookup(z, inner_table), is_undef(prev) ? r_hole : prev + dz * tan(max_overhang)))
    concat([[r, z]], cavity_wall(i + 1, r));

cav = cavity_wall();  // from the top of the cavity down to the rim

outer_profile = concat([[0, 0]], side, [[0, height]]);
cavity_profile = concat(
    [[0, -1], [cav[len(cav) - 1].x, -1]],
    [for (i = [len(cav) - 1 : -1 : 0]) cav[i]],
    [[r_hole, height - recess_depth], [r_recess, height - recess_depth],
     [r_recess, height + 1], [0, height + 1]]);

module canopy() {
    rotate_extrude()
        difference() {
            polygon(outer_profile);
            polygon(cavity_profile);
        }
}

// Preview-only context: the ceiling, the hook and the stock canopy.
module context() {
    translate([0, 0, -3]) cylinder(r = r_top + 30, h = 3);
    cylinder(d = 5, h = hook_len);
    intersection() {
        scale([stock_d / 2, stock_d / 2, stock_h]) sphere(1, $fn = 64);
        cylinder(d = stock_d + 1, h = stock_h + 1);
    }
}

// Hanging position (rim up) for comparison renders; print orientation otherwise.
module oriented() {
    if (installed) translate([0, 0, height]) rotate([180, 0, 0]) children();
    else children();
}

// Keep only the half behind the y = 0 plane, so the front view looks at the cut.
module cut() {
    if (section) intersection() {
        children();
        translate([-500, 0, -500]) cube(1000);
    }
    else children();
}

cut() oriented() canopy();
if (show_context) %cut() oriented() context();
