// Diffuser test coupon.
//
// Purpose: settle `face_t` empirically, and confirm the opaque walls really are
// opaque, before committing to a full body print.
//
// The design depends on TWO opposite properties of the same filament:
//
//   1. The 1.2 mm face over each icon must TRANSMIT enough light to read.
//      This is the one dimension that cannot be adjusted after assembly — the
//      face is an icon-shaped membrane, and thinning it in place means shaving
//      it with a knife and hoping not to punch through.
//
//   2. The 2.4 mm walls, and the divider between the chambers, must BLOCK light.
//      If 2.4 mm glows even faintly, the whole panel lights up instead of just
//      the icon, the sun and moon stop being distinguishable, and the device
//      fails from the other direction. This one is not adjustable at all: it is
//      the same thickness everywhere the enclosure needs to be solid.
//
// A single filament has to satisfy both, and nothing but a test settles it.
//
// Windows run THINNEST to THICKEST, left to right. The thin end is marked with a
// notch in the plate corner so the orientation survives being put down.
//
//   1: 0.4 mm   2: 0.8 mm   3: 1.2 mm (current design)   4: 1.6 mm   5: 2.0 mm
//   6: 2.4 mm — SOLID, no recess. This is the opacity check, not a face
//      candidate. It is marked by a tick cut into the top and bottom edges,
//      since it has no recess to see. It must look DARK.
//
// Print flat, face down, in the SAME white filament the enclosure will use.
// Different white filaments differ substantially in pigment loading, so a
// coupon printed in another spool proves nothing about the one you will use.
//
// ~12 g, roughly 25 minutes.

include <params.scad>

base_t = 2.4;   // the enclosure's opaque wall thickness — sample 6 is this, solid

// Face candidates, then the wall thickness itself as the opacity control.
samples = [0.4, 0.8, 1.2, 1.6, 2.0, base_t];

window_d = 20;   // smaller than the real 40 mm aperture, but tested at the same
                 // standoff, so transmission is comparable
pitch    = 24;
margin_x = 8;
margin_y = 5;

tick_w = 3;      // edge tick marking the solid sample
tick_d = 2;

n       = len(samples);
plate_w = 2 * margin_x + (n - 1) * pitch + window_d;
plate_h = 2 * margin_y + window_d;

function sample_x(i) = -plate_w / 2 + margin_x + window_d / 2 + i * pitch;

assert(base_t >= max(samples),
       "A sample is thicker than the plate; that recess would not leave material.");
assert(pitch > window_d,
       "Windows overlap.");
assert(tick_d < margin_y,
       "Edge tick reaches into the window area and would thin the sample.");

module coupon() {
    difference() {
        cube([plate_w, plate_h, base_t], center = true);

        for (i = [0 : n - 1]) {
            t = samples[i];
            x = sample_x(i);

            if (t < base_t) {
                // Recess cut from the BACK, leaving `t` of material at the front
                // — exactly how the real body's icons are formed.
                translate([x, 0, -base_t / 2 + (base_t - t) / 2 - 0.01])
                    cylinder(d = window_d, h = base_t - t + 0.02, center = true);
            } else {
                // Solid sample: no recess at all. Mark it with a tick in each
                // long edge so it can be found and held over the pixel.
                for (s = [-1, 1])
                    translate([x, s * (plate_h / 2), 0])
                        cube([tick_w, tick_d * 2, base_t + 2], center = true);
            }
        }

        // Orientation notch at the thin end. Asymmetric on purpose: a coupon you
        // can put down and pick up the wrong way round is a coupon that lies.
        translate([-plate_w / 2, -plate_h / 2, 0])
            rotate([0, 0, 45])
                cube([5, 5, base_t + 2], center = true);
    }
}

coupon();
