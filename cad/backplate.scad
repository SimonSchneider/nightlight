include <params.scad>

// The back plate carries the board (foam tape, no printed retention) and the
// zip-tie post that takes cable strain. The cable enters through a U-shaped
// slot open to the plate edge — it drops in sideways, so no connector ever
// has to pass through a closed opening. The zip tie cinched around the cable
// just inboard of the slot is far wider than the slot mouth, so the cable
// cannot pull back out; the slot only has to admit the cable, deliberately
// oversized with no tolerance to miss.

module backplate() {
    inner_w = body_w - 2 * wall - clearance;
    inner_h = body_h - 2 * wall - clearance;

    union() {
        // Plate proper: a lip that drops into the body's open back, on an
        // outer flange that seats against the body's rear edge.
        cube([body_w, body_h, backplate_t], center = true);
        translate([0, 0, backplate_t])
            cube([inner_w, inner_h, backplate_t], center = true);

        // Zip-tie post, offset to one side so it clears the board.
        difference() {
            translate([body_w * 0.28, -body_h * 0.25, backplate_t / 2 + post_h / 2])
                cylinder(d = post_d, h = post_h, center = true);
            translate([body_w * 0.28, -body_h * 0.25, backplate_t / 2 + post_h / 2])
                cube([post_d + 2, post_slot_w, post_h * 0.5], center = true);
        }
    }
}

module backplate_with_holes() {
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

backplate_with_holes();
