// All dimensions in millimetres.
// Thicknesses are whole multiples of a 0.4 mm nozzle.

// --- Apertures -------------------------------------------------------------
aperture_d    = 40;    // diameter of the circle each icon fits inside
face_t        = 1.2;   // translucent face left at the icons (3 x 0.4)

// --- Shell -----------------------------------------------------------------
wall          = 2.4;   // outer wall, opaque at this thickness (6 x 0.4)
divider_t     = 2.4;   // wall between the two chambers
chamber_depth = 25;    // pixel-to-face standoff; governs how evenly light spreads
aperture_gap  = 16;    // flat space between the two aperture circles
margin        = 12;    // border around the apertures
backplate_t   = 2.4;

// --- Back plate features, slot open to the plate edge ------------------------
cable_slot_w  = 8.0;   // deliberately oversized; no tolerance to miss

// --- Fit -------------------------------------------------------------------
clearance     = 0.6;   // total lip clearance (0.3 mm per side against cavity)

$fn = 96;

// --- Derived ---------------------------------------------------------------
body_w = 2 * margin + 2 * aperture_d + aperture_gap;   // 120
body_h = 2 * margin + aperture_d;                      // 64
body_d = wall + chamber_depth;                         // 27.4
ap_x   = (aperture_d + aperture_gap) / 2;              // 28, aperture centre offset

// --- Sanity ----------------------------------------------------------------
assert(divider_t <= aperture_gap,
       "Divider is wider than the gap between apertures; they would overlap.");
assert(face_t < wall,
       "Face must be thinner than the wall, or there is nothing left to thin.");
assert(face_t >= 0.8,
       "A face thinner than 0.8 mm will not print reliably and may be translucent enough to show the pixel as a hot spot.");
