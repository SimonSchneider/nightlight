// Diffuser test coupon.
//
// Purpose: settle `face_t` empirically before committing to a full body print.
// The face thickness governs how much light reaches the child's eye, and it is
// the one value that cannot be adjusted after the enclosure is assembled — the
// face is an icon-shaped membrane, and thinning it in place means shaving it
// with a knife.
//
// This coupon carries five windows at different thicknesses. Hold it 25 mm above
// a lit pixel (the real chamber depth) and look at each in turn, in the room and
// the lighting the finished device will live in.
//
// Windows run THINNEST to THICKEST, left to right. The thin end is marked with a
// notch in the plate edge so the orientation survives being put down.
//
//   1: 0.4 mm   2: 0.8 mm   3: 1.2 mm (current design)   4: 1.6 mm   5: 2.0 mm
//
// Print flat, face down, in the SAME white filament the enclosure will use.
// Different white filaments differ substantially in pigment loading, so a
// coupon printed in another spool proves nothing about the one you will use.
//
// ~11 g, roughly 20 minutes.

include <params.scad>

thicknesses = [0.4, 0.8, 1.2, 1.6, 2.0];

window_d    = 20;    // smaller than the real 40 mm aperture, but the same
                     // standoff, so transmission is comparable
pitch       = 24;
margin_x    = 8;
margin_y    = 5;
base_t      = 2.4;   // must be at least max(thicknesses)

n      = len(thicknesses);
plate_w = 2 * margin_x + (n - 1) * pitch + window_d;
plate_h = 2 * margin_y + window_d;

assert(base_t >= max(thicknesses),
       "Base is thinner than the thickest sample; that window would be a hole.");
assert(pitch > window_d,
       "Windows overlap.");

module coupon() {
    difference() {
        cube([plate_w, plate_h, base_t], center = true);

        // Each window is a recess cut from the BACK, leaving `t` of material at
        // the front — exactly how the real body's icons are formed.
        for (i = [0 : n - 1]) {
            t = thicknesses[i];
            x = -plate_w / 2 + margin_x + window_d / 2 + i * pitch;
            translate([x, 0, -base_t / 2 + (base_t - t) / 2 - 0.01])
                cylinder(d = window_d, h = base_t - t + 0.02, center = true);
        }

        // Orientation notch at the thin end. Asymmetric on purpose: a coupon you
        // can put down and pick up the wrong way round is a coupon that lies.
        translate([-plate_w / 2, -plate_h / 2, 0])
            rotate([0, 0, 45])
                cube([5, 5, base_t + 2], center = true);
    }
}

coupon();
