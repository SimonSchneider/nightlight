include <params.scad>

// The back plate carries the board (foam tape, no printed retention). Cable
// strain relief is an assembly step, not printed geometry: a simple overhand
// knot tied in the USB-C cable inside the enclosure is wider than the slot
// mouth, so it cannot pull back out. The cable enters through a U-shaped slot
// open to the plate edge — it drops in sideways, so no connector ever has to
// pass through a closed opening, deliberately oversized with no tolerance to
// miss.

module backplate() {
    union() {
        // Plate proper: a lip that drops into the body's open back, on an
        // outer flange that seats against the body's rear edge.
        cube([body_w, body_h, backplate_t], center = true);
        translate([0, 0, backplate_t])
            cube([lip_w, lip_h, backplate_t], center = true);
    }
}

module backplate_with_slot() {
    difference() {
        backplate();
        // Oversized cable slot, open to the -Y edge so the cable drops in
        // sideways instead of threading a connector through a closed hole.
        hull() {
            translate([cable_slot_x, cable_slot_y, 0])
                cylinder(d = cable_slot_w, h = backplate_t * 6, center = true);
            translate([cable_slot_x, -body_h, 0])
                cylinder(d = cable_slot_w, h = backplate_t * 6, center = true);
        }

        // Wire pass-through. The cable slot and the board are both on the moon
        // side (x > 0), so the sun pixel's wiring has to cross the divider
        // line. The notch is cut here, through the full height of the lip and
        // right across it in Y, rather than into the divider: the divider stays
        // solid, so light still has to travel the long way round. The resulting
        // channel is wire_notch_w wide, the lip's full length in Y, and
        // backplate_t + divider_gap high once the parts are mated.
        // z: the cut floor sits exactly on the flange's top face
        // (backplate_t/2 = 1.2) and runs well clear of the lip's top.
        translate([0, 0, backplate_t + 1])
            cube([wire_notch_w, lip_h + 2, backplate_t + 2], center = true);
    }
}

backplate_with_slot();
