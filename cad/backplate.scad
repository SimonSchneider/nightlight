include <params.scad>

// The back plate carries the board (foam tape, no printed retention). Cable
// strain relief is an assembly step, not printed geometry: a simple overhand
// knot tied in the USB-C cable inside the enclosure is wider than the slot
// mouth, so it cannot pull back out. The cable enters through a U-shaped slot
// open to the plate edge — it drops in sideways, so no connector ever has to
// pass through a closed opening, deliberately oversized with no tolerance to
// miss.

module backplate() {
    inner_w = body_w - 2 * wall - clearance;
    inner_h = body_h - 2 * wall - clearance;

    union() {
        // Plate proper: a lip that drops into the body's open back, on an
        // outer flange that seats against the body's rear edge.
        cube([body_w, body_h, backplate_t], center = true);
        translate([0, 0, backplate_t])
            cube([inner_w, inner_h, backplate_t], center = true);
    }
}

module backplate_with_slot() {
    difference() {
        backplate();
        // Oversized cable slot, open to the -Y edge so the cable drops in
        // sideways instead of threading a connector through a closed hole.
        hull() {
            translate([body_w * 0.28, -body_h * 0.38, 0])
                cylinder(d = cable_slot_w, h = backplate_t * 6, center = true);
            translate([body_w * 0.28, -body_h, 0])
                cylinder(d = cable_slot_w, h = backplate_t * 6, center = true);
        }
    }
}

backplate_with_slot();
