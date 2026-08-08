// All dimensions in millimetres.
// Thicknesses are whole multiples of a 0.4 mm nozzle.

// --- Apertures -------------------------------------------------------------
aperture_d    = 40;    // diameter of the circle each icon fits inside
face_t        = 1.2;   // translucent face left at the icons (3 x 0.4)

// --- Shell -----------------------------------------------------------------
wall          = 2.4;   // outer wall, opaque at this thickness (6 x 0.4)
divider_t     = 2.4;   // wall between the two chambers
chamber_depth = 40;    // pixel-to-face standoff; governs how evenly light spreads.
                       // Raised from 25 after coupon testing: 20-30 mm was needed
                       // for even diffusion behind a 20 mm window, and the sun's
                       // core disc is 24 mm. 40 mm gives a standoff/aperture ratio
                       // of ~1.7 on that disc, comfortably past what was measured.
                       // Costs light: illuminance falls with the square of this,
                       // so 25 -> 40 keeps only ~(25/40)^2 = 39%. day_brightness
                       // has headroom (default 80 of 100) to absorb it.
aperture_gap  = 16;    // flat space between the two aperture circles
margin        = 12;    // border around the apertures
backplate_t   = 2.4;

// --- Back plate features, slot open to the plate edge ------------------------
cable_slot_w  = 8.0;   // deliberately oversized; no tolerance to miss
wire_notch_w  = 6.0;   // gap cut in the lip on the divider line, for wiring

// --- Fit -------------------------------------------------------------------
clearance     = 0.6;   // total lip clearance (0.3 mm per side against cavity)
divider_gap   = 0.2;   // divider stops short of the lip; keeps the two apart

$fn = 96;

// --- Derived ---------------------------------------------------------------
body_w = 2 * margin + 2 * aperture_d + aperture_gap;   // 120
body_h = 2 * margin + aperture_d;                      // 64
body_d = wall + chamber_depth;                         // 42.4
ap_x   = (aperture_d + aperture_gap) / 2;              // 28, aperture centre offset

// The lip is the raised pad on the back plate that drops into the body's open
// back. It is the cavity footprint less the fit clearance.
lip_w  = body_w - 2 * wall - clearance;                // 114.6
lip_h  = body_h - 2 * wall - clearance;                // 58.6

// The divider runs from the inner surface of the front wall back to just short
// of the lip's top face, so the two can never fight for the same space:
//   front face  =  body_d/2 - wall                       =  13.7 - 2.4 =  11.3
//   rear face   = -body_d/2 + backplate_t + divider_gap  = -13.7 + 2.6 = -11.1
//   height      = body_d - wall - backplate_t - divider_gap            =  22.4
divider_h = body_d - wall - backplate_t - divider_gap; // 22.4

// Cable slot centre, off to the moon side of the plate.
cable_slot_x = body_w * 0.28;                          // 33.6
cable_slot_y = -body_h * 0.38;                         // -24.32

// --- Sanity ----------------------------------------------------------------
assert(divider_t <= aperture_gap,
       "Divider is wider than the gap between apertures; they would overlap.");
assert(face_t < wall,
       "Face must be thinner than the wall, or there is nothing left to thin.");
assert(face_t >= 0.8,
       "A face thinner than 0.8 mm will not print reliably and may be translucent enough to show the pixel as a hot spot.");
assert(divider_h > 0 && divider_gap > 0,
       "Divider must stop clear of the back plate lip, or the box will not close.");
// The wire notch is why the two chambers are not hermetically sealed. The board
// and the cable slot both live in the moon chamber (x > 0), so three wires must
// reach the sun pixel and three more return from it. They cross under the
// divider through this gap in the lip. It is cut in the lip and NOT in the
// divider: the divider stays solid, which keeps the light path between chambers
// as long as possible — around the back, ~25 mm behind the faces.
assert(wire_notch_w > 0 && wire_notch_w < lip_h,
       "Wire notch must be positive and narrower than the lip is long, or there is no lip left to locate the back plate.");
assert(wire_notch_w / 2 + cable_slot_w / 2 < cable_slot_x,
       "Wire notch and cable slot overlap; the lip would be cut away between them.");
