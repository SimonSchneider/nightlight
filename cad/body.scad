include <params.scad>
use <icons.scad>

// The body is an open-backed box with a solid front wall. At each icon the
// front wall is thinned from behind, from `wall` down to `face_t`, leaving a
// translucent window in the shape of the icon while the rest of the panel
// stays opaque. A full-depth divider stops one lit icon bleeding into the
// other.
//
// Note there is no separate "restore the face" step: the face is simply the
// material left behind by an incomplete cut. Cutting through and adding the
// face back would create coincident surfaces and risk a non-manifold export.

// s = -1 is the sun (left), s = +1 is the moon (right).
module icon(s, d) {
    if (s < 0) sun_2d(d); else moon_2d(d);
}

module body() {
    difference() {
        union() {
            // Outer shell: solid front wall, open back.
            difference() {
                cube([body_w, body_h, body_d], center = true);
                // Cavity. Offsetting by -wall puts its front face exactly at
                // the inner surface of the front wall, and lets it run out
                // past the open back.
                translate([0, 0, -wall])
                    cube([body_w - 2 * wall,
                          body_h - 2 * wall,
                          body_d], center = true);
            }
            // Divider, from the inner surface of the front wall back to just
            // short of the back plate's lip. It must NOT run to the open back
            // edge: the lip drops into that same volume for backplate_t, and a
            // full-depth divider would collide with it and hold the box open.
            //
            //   front face  =  body_d/2 - wall                      =  11.3
            //   rear face   = -body_d/2 + backplate_t + divider_gap = -11.1
            //   height      = divider_h                             =  22.4
            //   centre z    = (11.3 + -11.1) / 2                    =   0.1
            //             = (backplate_t + divider_gap - wall) / 2
            //
            // This is the feature that cannot be fixed later.
            translate([0, 0, (backplate_t + divider_gap - wall) / 2])
                cube([divider_t, body_h - 2 * wall, divider_h],
                     center = true);
        }

        // Thin the front wall to face_t at each icon, cutting from behind.
        // The cut is deliberately run 1 mm into the cavity so its back face
        // is not coplanar with the cavity's front face.
        for (s = [-1, 1])
            translate([s * ap_x, 0,
                       body_d / 2 - face_t - (wall - face_t + 1) / 2])
                linear_extrude(height = wall - face_t + 1, center = true)
                    icon(s, aperture_d);
    }
}

body();
