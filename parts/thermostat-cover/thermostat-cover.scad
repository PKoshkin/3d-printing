// Cover for an Aqara thermostat that physically blocks its controls. It replaces the
// stock cover (Pavel's photos show a tube with the label of Lumi, Aqara's maker): the
// same thin-walled cylinder with the same locks at the open end, but the other end is
// partly closed by a flat ring (a "donut").
//
// How it holds: a bayonet. Two recesses in the inner wall at the rim, opposite each
// other, each with an entry open to the rim and a pocket under a tab left at the rim.
// The thermostat's pins should go down the entries, and turning the cover takes them
// under the tabs. Looking into the open end, a pin travels clockwise from entry to
// pocket. The thermostat's side of the lock has not been seen yet, so there is no
// preview context.
//
// Sizes: the outer diameter, wall, height and lock sizes are Pavel's measurements. The
// thermostat measures D55.5 mm, so the inner D55.8 leaves 0.15 mm per side, between the
// friend's snug and slide clearances: Pavel wants it neither touching nor wobbling. The
// ring width is Pavel's 7 mm, measured radially from the outer surface; its thickness
// along Z is a placeholder equal to the wall. Of the lock widths, 7.2 mm is read as the
// entry at the rim and 11.4 mm as the whole recess below it, as the photos' proportions
// suggest, which leaves a 4.2 mm tab. In print the recess grows by clearance_slide() on
// every side but the floor, where the wall behind is already at the minimum. Something
// like a small detent under the tab shows in the photos; it is not modelled.
//
// fit_test builds a short open tube instead of the cover, to try the bore and the locks
// on the thermostat. It has no ring: a short piece with one would hit the thermostat's
// end long before its locks reach the pins.
//
// Modelled in print orientation: ring on the bed, open end up. The cylinder then goes
// straight up with no supports, and the ring's outer face comes out flat. The tab's
// underside is a 1.2 mm overhang, too short to need supports, and the clearance makes up
// for its droop. Pulling the cover off loads the layers apart in the thin wall behind
// the pockets.
//
// Printed on the friend's printer: it is free, and 61 x 61 x 74 mm fits it.

include <../../lib/printer.scad>

/* [Где печатать] */
// От этого зависят зазоры в замках, проверка размера и минимальная стенка
target = "friend"; // [friend:Принтер друга — FDM, craftcloud-fdm:Craftcloud — FDM, craftcloud-mjf:Craftcloud — нейлон PA12 MJF/SLS]

/* [Цилиндр] */
// Внешний диаметр, мм
outer_d = 60.7; // [30:0.05:180]
// Толщина стенки, мм: внутренний диаметр = внешний − 2 × стенка (у термостата 55,5)
wall = 2.45; // [1:0.05:6]
// Полная высота вместе с кольцом, мм
height = 74; // [10:1:150]

/* [Кольцо на закрытом торце] */
// Ширина кольца от внешней поверхности цилиндра к центру, мм
ring_width = 7; // [3:0.1:25]
// Толщина кольца по высоте, мм (предварительно — как стенка)
ring_t = 2.45; // [1:0.05:15]
// Скругление угла между кольцом и стенкой изнутри, мм
inner_fillet = 1; // [0:0.25:4]
// Фаска на кромках у стола против «слоновьей ноги», мм
chamfer = 0.5; // [0:0.1:1]

/* [Замки на открытом торце] */
// Полная высота выемки от кромки, мм (у родной 4,7). Зазор сборка добавит сама
lock_h = 4.7; // [3:0.1:10]
// Толщина перемычки у кромки, над карманом, мм (у родной 2,2). Зазор сборка вычтет сама
tab_h = 2.2; // [1:0.1:4]
// Сколько стенки остаётся за выемкой, мм (половина стенки: 1,225)
lock_skin = 1.225; // [1:0.025:2]
// Ширина выемки внизу, вместе с карманом под перемычкой, мм (у родной 11,4). Зазор сборка добавит сама
lock_width = 11.4; // [6:0.1:30]
// Ширина входа у кромки, мм (у родной 7,2). Зазор сборка добавит сама
entry_width = 7.2; // [3:0.1:25]

/* [Пробник] */
// Собрать вместо крышки низкую трубку без кольца: примерить на термостате посадку и замки
fit_test = false;
// Высота пробника, мм
fit_test_h = 15; // [8:1:30]

/* [Просмотр] */
// Разрез пополам (только для просмотра, перед экспортом выключить)
section = false;
// Поворот плоскости разреза, градусы. При 0 замок виден изнутри, как на фото
section_angle = 0; // [0:1:359]

/* [Hidden] */
thermostat_d = 55.5;   // measured
h = fit_test ? fit_test_h : height;
outer_r = outer_d / 2;
inner_r = outer_r - wall;
hole_r = outer_r - ring_width;
bore_r = fit_test ? inner_r : hole_r;  // the inner edge at the bed
fillet_steps = 16;

lock_gap = clearance_slide();          // the pins have to turn freely
lock_floor_r = outer_r - lock_skin;
z_lock = h - lock_h - lock_gap;        // bottom of the recess
z_tab = h - tab_h + lock_gap;          // underside of the tab

function arc_deg(w) = w / inner_r * 180 / PI;

// Lock angles around +Y; the printed tab keeps its stock width.
lock_a = arc_deg(lock_width + 2 * lock_gap);
a_pocket_end = 90 - lock_a / 2;
a_tab_edge = a_pocket_end + arc_deg(lock_width - entry_width);
a_entry_end = 90 + lock_a / 2;

assert(wall >= min_wall(), str("the wall is thinner than ", min_wall(), " mm, the minimum for ", target));
assert(ring_t >= min_wall(), str("the ring is thinner than ", min_wall(), " mm, the minimum for ", target));
assert(2 * inner_r > thermostat_d, str("the inner diameter does not clear the thermostat, ", thermostat_d, " mm"));
assert(hole_r > 0, "the ring is wider than the cylinder's radius");
assert(ring_width - wall > inner_fillet, "the ring does not reach past the fillet into the cylinder");
assert(height > ring_t + inner_fillet, "the cylinder is lower than its ring and fillet");
assert(chamfer < ring_t, "the chamfer is bigger than the ring's thickness");
assert(lock_skin >= min_wall(), str("the wall behind the locks is thinner than ", min_wall(), " mm, the minimum for ", target));
assert(lock_skin < wall, "the locks have no depth: nothing is left to cut from the wall");
assert(tab_h - lock_gap >= 0.8, "the printed tab would be thinner than 0.8 mm");
assert(z_tab > z_lock, "the tab leaves no pocket under it");
assert(entry_width < lock_width, "the entry is as wide as the whole recess: no tab is left");
assert(z_lock > (fit_test ? chamfer : ring_t + inner_fillet), "the locks run into the bottom of the part");

// Half section as [r, z] points, going around from the inner edge at the bed.
profile = concat(
    chamfer > 0
        ? [[bore_r, chamfer], [bore_r + chamfer, 0], [outer_r - chamfer, 0], [outer_r, chamfer]]
        : [[bore_r, 0], [outer_r, 0]],
    [[outer_r, h], [inner_r, h]],
    fit_test ? [] : concat(
        inner_fillet > 0
            ? [for (i = [0 : fillet_steps]) let(a = -90 * i / fillet_steps)
                [inner_r - inner_fillet, ring_t + inner_fillet] + inner_fillet * [cos(a), sin(a)]]
            : [[inner_r, ring_t]],
        [[hole_r, ring_t]]));

// Layer of the wall between two heights, from inside the cavity to the recess floor.
module lock_layer(z1, z2) {
    rotate_extrude()
        translate([inner_r - 1, z1])
            square([lock_floor_r - inner_r + 1, z2 - z1]);
}

// Everything between two angles around Z.
module wedge(a1, a2) {
    r = 2 * outer_r;
    mid = (a1 + a2) / 2;
    translate([0, 0, -1])
        linear_extrude(h + 3)
            polygon([[0, 0], r * [cos(a1), sin(a1)], r * [cos(mid), sin(mid)], r * [cos(a2), sin(a2)]]);
}

// One lock's recess on the +Y side. Seen from inside with the rim up: the entry on the
// left, open to the rim, and the pocket on the right, under the tab.
module lock_cut() {
    intersection() {
        lock_layer(z_lock, z_tab);
        wedge(a_pocket_end, a_entry_end);
    }
    intersection() {
        lock_layer(z_lock, h + 1);
        wedge(a_tab_edge, a_entry_end);
    }
}

module cover() {
    difference() {
        rotate_extrude() polygon(profile);
        // A bayonet needs both locks turning the same way: rotated, not mirrored.
        for (a = [0, 180]) rotate(a) lock_cut();
    }
}

// Keep only the half behind the cutting plane, so the view along it looks at the cut.
module cut() {
    if (section) intersection() {
        children();
        rotate(section_angle) translate([-500, 0, -500]) cube(1000);
    }
    else children();
}

cut() cover();
