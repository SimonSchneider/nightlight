include <params.scad>

// The back plate carries the board (foam tape, no printed retention) and the
// zip-tie post that takes cable strain. It has no port cutout: the USB-C cable
// is captive, passing through an oversized hole with no tolerance to miss.

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
        // Oversized cable entry.
        translate([body_w * 0.28, -body_h * 0.38, 0])
            cylinder(d = cable_hole_d, h = backplate_t * 6, center = true);
    }
}

backplate_with_holes();
