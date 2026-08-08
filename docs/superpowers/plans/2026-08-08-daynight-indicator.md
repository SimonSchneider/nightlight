# Day/Night Indicator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a bedside device showing a lit sun or a lit moon, telling a pre-literate child whether it is night or day, with the state driven entirely from Home Assistant.

**Architecture:** An ESP32-C3 drives two WS2812 pixels on one GPIO, split into two independently controllable lights via ESPHome's `partition` platform. A template switch exposed to Home Assistant selects which of two scripts runs; each script lights one pixel and extinguishes the other. The device holds no clock and no schedule — all timing lives in Home Assistant automations. The enclosure is two ordered 3D prints, designed to be tolerant rather than precise because iteration is not affordable.

**Tech Stack:** OpenSCAD (parametric enclosure), ESPHome via the Home Assistant ESPHome Builder add-on, Home Assistant automations, ESP32-C3 SuperMini, WS2812B pixels.

**Spec:** `docs/superpowers/specs/2026-08-08-daynight-indicator-design.md`

## Global Constraints

Every task's requirements implicitly include these.

- **Data pin is GPIO4.** GPIO2, GPIO8 and GPIO9 are ESP32-C3 strapping pins sampled at boot; a WS2812 data line on one risks intermittent boot failure. GPIO3, 5, 6, 7 and 10 are safe substitutes if GPIO4 is unavailable.
- **Pixels are powered from the board's 3.3 V pin, never 5 V.** At 5 V the WS2812 data threshold is 3.5 V and the C3's 3.3 V GPIO is out of spec. Reduced peak brightness is irrelevant — night runs at ~2 %.
- **Pixel index 0 is the sun, pixel index 1 is the moon.** Fixed throughout firmware and assembly.
- **Exactly one icon is lit at any time.** Never both, never neither.
- **Night colour is deep amber** (`red: 100%, green: 45%, blue: 0%`) at ~2 % brightness. **Day colour is warm white** (`red: 100%, green: 85%, blue: 60%`) at ~80 % brightness.
- **Transitions crossfade over 20 s.**
- **No clock, schedule, sunrise logic, or time source on the device.**
- **Printed features exist only for irrecoverable failures.** If a failure can be fixed at assembly with tape, paper or a knife, it belongs in the assembly instructions, not the geometry.
- **All dimensions in millimetres.** Wall and face thicknesses are whole multiples of a 0.4 mm nozzle.
- **ESPHome YAML in this repo is the source of truth.** The add-on's copy is a deployment target, not the master.

---

## File Structure

| File | Responsibility |
|---|---|
| `cad/params.scad` | Every tunable dimension, and assertions that they are self-consistent |
| `cad/icons.scad` | 2D sun and moon profiles, nothing else |
| `cad/body.scad` | The front shell: icon windows, thinned faces, light divider |
| `cad/backplate.scad` | The back plate: cable hole, zip-tie post |
| `cad/render.sh` | Export STLs and preview PNGs |
| `firmware/daynight.yaml` | Complete ESPHome device configuration |
| `firmware/secrets.example.yaml` | Template for the secrets the config expects |
| `homeassistant/automations.yaml` | The three scheduling automations |
| `docs/BUILD.md` | Bill of materials, wiring, assembly order, tuning |

---

## Task 1: Bill of Materials and Ordering

Nothing else can be verified physically until parts are moving. This task is first so shipping time overlaps the software work.

**Files:**
- Create: `docs/BUILD.md`

**Interfaces:**
- Consumes: nothing
- Produces: `docs/BUILD.md` with a `## Wiring` section that Task 6 extends

- [ ] **Step 1: Create the repo structure**

```bash
cd ~/repos/daynight-indicator
mkdir -p cad firmware homeassistant docs
cat > .gitignore <<'EOF'
# Scratch preview files rendered during CAD work
cad/_*.scad
cad/preview/
# Never commit real credentials
firmware/secrets.yaml
EOF
```

- [ ] **Step 2: Write `docs/BUILD.md`**

````markdown
# Day/Night Indicator — Build Notes

## Bill of Materials

| # | Part | Qty | Notes |
|---|---|-----|-------|
| 1 | ESP32-C3 SuperMini | 1 | Buy the **headerless** version if offered — nothing is plugged into the pins, and it is ~8 mm thinner. |
| 2 | WS2812B LED strip, 60 LEDs/m | 1 short offcut | Cut a run of exactly 2 pixels. Buying a strip is easier to wire than individual breakouts — it has solder pads and holds the pixels at fixed spacing. |
| 3 | Silicone hookup wire, 26 AWG | 3 colours, ~30 cm each | Red (3.3 V), black (GND), any third colour (data). |
| 4 | USB-C cable, 1–2 m | 1 | Becomes captive inside the enclosure. Pick the length you actually want. |
| 5 | USB power supply, 5 V | 1 | Any phone charger. Current draw is a few tens of mA. |
| 6 | Zip ties, small | a few | Cable strain relief. |
| 7 | Foam double-sided tape | 1 roll | Mounts the board to the back plate. |
| 8 | Opaque tape (electrical or gaffer) | 1 roll | Masks the board's power LED. |
| 9 | Tracing paper or baking parchment | a sheet | Spare diffuser, only if the printed face reads wrong. |

**Tools:** soldering iron, wire strippers, scissors, small screwdriver.

**Substitution note:** some ESP32-C3 SuperMini clones ship with a poorly tuned antenna
and show weak WiFi. If range is a problem, an ESP32-C3-DevKitM-1 or a Wemos D1 Mini
drops in with no change other than possibly the GPIO number.

## Wiring

Three wires from the 2-pixel strip to the board. Note the strip has a direction —
arrows printed on it point *away* from the input end. Solder to the input end.

| Strip pad | Board pin | Wire |
|---|---|---|
| 5V / VCC | **3V3** (not 5V) | red |
| GND | GND | black |
| DIN | GPIO4 | data |

**The 3.3 V connection is deliberate, not a mistake.** See the spec's rationale section.

Pixel order along the strip, starting from the input end:

- Pixel **0** = **sun**
- Pixel **1** = **moon**
````

- [ ] **Step 3: Order the parts**

Order items 1–9. Item 2 only needs a short offcut; the shortest strip sold will be far more than enough.

- [ ] **Step 4: Commit**

```bash
cd ~/repos/daynight-indicator
git add .gitignore docs/BUILD.md
git commit -m "docs: add bill of materials and wiring"
```

---

## Task 2: OpenSCAD Environment and Parameters

**Files:**
- Create: `cad/params.scad`
- Create: `cad/icons.scad`

**Interfaces:**
- Consumes: nothing
- Produces: variables `aperture_d`, `face_t`, `wall`, `chamber_depth`, `divider_t`, `aperture_gap`, `margin`, `backplate_t`, `clearance`, `cable_hole_d`, `post_h`, `post_d`, `post_slot_w`, `body_w`, `body_h`, `body_d`, `ap_x`; modules `sun_2d(d)` and `moon_2d(d)`

- [ ] **Step 1: Install OpenSCAD**

```bash
brew install --cask openscad
```

- [ ] **Step 2: Verify the CLI is reachable and note its path**

```bash
/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD --version
```

Expected: a version string such as `OpenSCAD version 2021.01`. The GUI app bundle contains the CLI binary; there is no bare `openscad` on `PATH` after a cask install.

- [ ] **Step 3: Write `cad/params.scad`**

```openscad
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

// --- Back plate features ---------------------------------------------------
cable_hole_d  = 8.0;   // deliberately oversized; no tolerance to miss
post_h        = 8.0;   // zip-tie post height
post_d        = 6.0;   // zip-tie post diameter
post_slot_w   = 3.5;   // slot through the post for the zip tie

// --- Fit -------------------------------------------------------------------
clearance     = 0.3;   // back plate lip to body cavity

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
assert(post_slot_w < post_d,
       "Zip-tie slot is wider than the post it passes through.");
assert(face_t >= 0.8,
       "A face thinner than 0.8 mm will not print reliably and may be translucent enough to show the pixel as a hot spot.");
```

- [ ] **Step 4: Verify the parameter file parses and the assertions pass**

```bash
cd ~/repos/daynight-indicator
/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD -o /dev/null cad/params.scad 2>&1 | tee /tmp/scad.log
```

Expected: no `ERROR:` and no `Assertion` failure in the output. A warning that the design is empty is expected and correct — this file defines variables only.

- [ ] **Step 5: Write `cad/icons.scad`**

```openscad
// 2D icon profiles. Both are sized to fit within a circle of diameter d.

module sun_2d(d) {
    r    = d / 2;
    core = r * 0.60;
    union() {
        circle(r = core);
        for (i = [0 : 11])
            rotate(i * 30)
                translate([0, core - 0.5])
                    polygon([[-r * 0.09, 0],
                             [ r * 0.09, 0],
                             [ 0,        r * 0.40]]);
    }
}

module moon_2d(d) {
    r = d / 2;
    // A fat crescent. Thin crescents light unevenly and print poorly at this scale.
    rotate(-30)
        difference() {
            circle(r = r);
            translate([r * 0.46, 0]) circle(r = r * 0.82);
        }
}
```

- [ ] **Step 6: Render both icons to a PNG and look at them**

The preview file must live in `cad/` — OpenSCAD resolves `include`/`use` paths relative to the including file, so a scratch file in `/tmp` cannot find `params.scad`.

```bash
cd ~/repos/daynight-indicator/cad
cat > _preview_icons.scad <<'EOF'
include <params.scad>
use <icons.scad>
translate([-30, 0]) sun_2d(aperture_d);
translate([ 30, 0]) moon_2d(aperture_d);
EOF
/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD \
  --projection=ortho --camera=0,0,0,0,0,0,220 --imgsize=800,400 \
  -o /tmp/icons.png _preview_icons.scad
open /tmp/icons.png
```

Expected: a recognisable sun with twelve rays on the left, a crescent moon on the right, both roughly 40 mm across and neither self-intersecting.

**This is a judgement step, not a pass/fail one.** If the sun's rays look spindly or the crescent looks like a bitten biscuit, adjust the multipliers in `icons.scad` and re-render. Iterate here freely — it costs nothing now and cannot be changed after the print is ordered.

- [ ] **Step 7: Commit**

```bash
cd ~/repos/daynight-indicator
git add cad/params.scad cad/icons.scad
git commit -m "cad: add parameters and sun/moon icon profiles"
```

---

## Task 3: Enclosure Body

**Files:**
- Create: `cad/body.scad`

**Interfaces:**
- Consumes: `cad/params.scad` variables, `sun_2d(d)` and `moon_2d(d)` from `cad/icons.scad`
- Produces: module `body()`, and a top-level call to it so the file renders standalone

- [ ] **Step 1: Write `cad/body.scad`**

```openscad
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
            // Divider, from the inner surface of the front wall to the open
            // back edge. This is the feature that cannot be fixed later.
            translate([0, 0, -wall / 2])
                cube([divider_t, body_h - 2 * wall, body_d - wall],
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
```

- [ ] **Step 2: Verify it renders without error**

```bash
cd ~/repos/daynight-indicator/cad
/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD -o /tmp/body.stl body.scad 2>&1 | tee /tmp/body.log
grep -iE "error|warning" /tmp/body.log || echo "CLEAN"
```

Expected: `CLEAN`, or at most warnings unrelated to manifoldness. Any line containing `Object may not be a valid 2-manifold` is a **failure** — the print service will reject the file. If it appears, the usual cause is two coincident faces; nudge the offending `linear_extrude` height by 0.01 mm and re-render.

- [ ] **Step 3: Render a preview from the front and look at it**

```bash
/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD \
  --camera=0,0,0,55,0,25,320 --imgsize=1000,700 \
  -o /tmp/body_front.png body.scad
open /tmp/body_front.png
```

Expected: a shallow box with a sun window on the left and a moon window on the right, a visible wall between the two chambers, and the back open.

- [ ] **Step 4: Confirm the divider actually seals**

This cuts the rendered STL in half and looks down the cut. It imports the STL, so it needs no `include` and can live anywhere.

```bash
cat > /tmp/section.scad <<'EOF'
difference() {
    import("/tmp/body.stl");
    translate([-200, 0, -200]) cube([400, 400, 400]);
}
EOF
/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD \
  --camera=0,0,0,60,0,20,320 --imgsize=1000,700 \
  -o /tmp/body_section.png /tmp/section.scad
open /tmp/body_section.png
```

Expected: a cutaway showing the divider running from the front face all the way to the open back edge with no gap. **This is the one feature that cannot be fixed after printing** — if light can get past the divider, the device does not work. Check it deliberately.

- [ ] **Step 5: Commit**

```bash
cd ~/repos/daynight-indicator
git add cad/body.scad
git commit -m "cad: add enclosure body with icon windows and light divider"
```

---

## Task 4: Back Plate

**Files:**
- Create: `cad/backplate.scad`

**Interfaces:**
- Consumes: `cad/params.scad` variables
- Produces: modules `backplate()` (plate, lip and post) and `backplate_with_holes()` (the former, minus the cable entry); the file calls `backplate_with_holes()` at top level

- [ ] **Step 1: Write `cad/backplate.scad`**

```openscad
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
```

- [ ] **Step 2: Verify it renders without error**

```bash
cd ~/repos/daynight-indicator/cad
/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD -o /tmp/backplate.stl backplate.scad 2>&1 | tee /tmp/bp.log
grep -iE "error|not be a valid 2-manifold" /tmp/bp.log || echo "CLEAN"
```

Expected: `CLEAN`.

- [ ] **Step 3: Render a preview and look at it**

```bash
/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD \
  --camera=0,0,0,55,0,205,320 --imgsize=1000,700 \
  -o /tmp/backplate.png backplate.scad
open /tmp/backplate.png
```

Expected: a flat plate with a raised inner lip, a round hole near one corner, and a short post beside it with a slot through its upper half.

- [ ] **Step 4: Check the cable hole and the post are near each other but not overlapping**

Read the preview. The hole and the post must be within about 15 mm of each other — the zip tie has to reach from the cable where it enters to the post — but their edges must not intersect. If they do, increase the separation in the two `translate` calls in `backplate.scad` and re-render.

- [ ] **Step 5: Commit**

```bash
cd ~/repos/daynight-indicator
git add cad/backplate.scad
git commit -m "cad: add back plate with captive cable entry and zip-tie post"
```

---

## Task 5: Export STLs and Order the Prints

**Files:**
- Create: `cad/render.sh`
- Create: `cad/stl/` (output directory)

**Interfaces:**
- Consumes: `cad/body.scad`, `cad/backplate.scad`
- Produces: `cad/stl/body.stl`, `cad/stl/backplate.stl`

- [ ] **Step 1: Write `cad/render.sh`**

```bash
#!/usr/bin/env bash
# Export print-ready STLs and preview PNGs.
set -euo pipefail

SCAD="/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD"
cd "$(dirname "$0")"
mkdir -p stl preview

fail=0
for part in body backplate; do
    echo "--- $part"
    if ! "$SCAD" -o "stl/${part}.stl" "${part}.scad" 2> "preview/${part}.log"; then
        echo "RENDER FAILED: $part"; fail=1; continue
    fi
    if grep -qi "not be a valid 2-manifold" "preview/${part}.log"; then
        echo "NOT MANIFOLD: $part — print services will reject this"; fail=1
    fi
    "$SCAD" --camera=0,0,0,55,0,25,320 --imgsize=1000,700 \
            -o "preview/${part}.png" "${part}.scad" 2>/dev/null
done

exit $fail
```

- [ ] **Step 2: Make it executable and run it**

```bash
cd ~/repos/daynight-indicator/cad
chmod +x render.sh
./render.sh && echo "ALL PARTS OK"
```

Expected: `ALL PARTS OK`, and two files in `cad/stl/`.

- [ ] **Step 3: Check the exported file sizes are plausible**

```bash
ls -la ~/repos/daynight-indicator/cad/stl/
```

Expected: both files are tens to hundreds of kilobytes. A file under about 1 KB means an empty render — the geometry did not survive, and the STL is useless despite the render "succeeding".

- [ ] **Step 4: Order the prints**

Upload both STLs to a print service (JLC3DP, Craftcloud, PCBWay, or a local service).

Specify:
- **Material:** white PLA or white PETG. White is required — it is the diffuser.
- **Process:** FDM.
- **Layer height:** 0.2 mm.
- **Infill:** 20 % is ample.
- **Supports:** none needed; both parts are designed support-free.
- **Quantity:** 1 each.

**Do not order a coloured or black part.** The translucent face only works in white.

- [ ] **Step 5: Commit**

```bash
cd ~/repos/daynight-indicator
git add cad/render.sh cad/stl
git commit -m "cad: add render script and export print-ready STLs"
```

---

## Task 6: ESPHome Firmware

Do this while the prints and parts are shipping. It needs no enclosure.

**Files:**
- Create: `firmware/daynight.yaml`
- Create: `firmware/secrets.example.yaml`

**Interfaces:**
- Consumes: GPIO4 and the pixel ordering from Task 1's wiring table
- Produces: HA entities `switch.daynight_night_mode`, `number.daynight_night_brightness`, `number.daynight_day_brightness`, `light.daynight_sun`, `light.daynight_moon`

- [ ] **Step 1: Write `firmware/secrets.example.yaml`**

```yaml
# Copy these keys into the ESPHome add-on's own secrets.yaml.
# Never commit real values to this repo.
wifi_ssid: "YourNetwork"
wifi_password: "yourpassword"
fallback_password: "achangedpassword"
api_encryption_key: "generate with: openssl rand -base64 32"
ota_password: "anotherpassword"
```

- [ ] **Step 2: Write `firmware/daynight.yaml`**

```yaml
substitutions:
  device_name: daynight
  friendly_name: "Day/Night Indicator"

esphome:
  name: ${device_name}
  friendly_name: ${friendly_name}
  on_boot:
    # -100 runs last, after switch and number components have restored their
    # values from flash. Re-applying here removes any dependence on the order
    # in which those two components come up.
    priority: -100
    then:
      - script.execute: apply_state

esp32:
  board: esp32-c3-devkitm-1
  framework:
    type: esp-idf

# Default settings are correct for the C3. It logs over USB CDC when plugged
# in, and over the API to Home Assistant otherwise. No hardware_uart setting
# is needed with the esp-idf framework.
logger:

api:
  encryption:
    key: !secret api_encryption_key

ota:
  - platform: esphome
    password: !secret ota_password

wifi:
  ssid: !secret wifi_ssid
  password: !secret wifi_password
  ap:
    ssid: "DayNight Fallback"
    password: !secret fallback_password

captive_portal:

light:
  # The physical strip. Never exposed to Home Assistant directly — the two
  # partitions below are the user-facing entities.
  - platform: esp32_rmt_led_strip
    id: strip
    pin: GPIO4
    num_leds: 2
    chipset: WS2812
    rgb_order: GRB
    internal: true

  - platform: partition
    id: sun_light
    name: "Sun"
    default_transition_length: 20s
    segments:
      - id: strip
        from: 0
        to: 0

  - platform: partition
    id: moon_light
    name: "Moon"
    default_transition_length: 20s
    segments:
      - id: strip
        from: 1
        to: 1

number:
  - platform: template
    id: night_brightness
    name: "Night brightness"
    optimistic: true
    restore_value: true
    initial_value: 2
    min_value: 0
    max_value: 100
    step: 1
    unit_of_measurement: "%"
    on_value:
      - script.execute: apply_state

  - platform: template
    id: day_brightness
    name: "Day brightness"
    optimistic: true
    restore_value: true
    initial_value: 80
    min_value: 0
    max_value: 100
    step: 1
    unit_of_measurement: "%"
    on_value:
      - script.execute: apply_state

script:
  - id: show_night
    mode: restart
    then:
      - light.turn_off: sun_light
      - light.turn_on:
          id: moon_light
          red: 100%
          green: 45%
          blue: 0%
          brightness: !lambda 'return id(night_brightness).state / 100.0;'

  - id: show_day
    mode: restart
    then:
      - light.turn_off: moon_light
      - light.turn_on:
          id: sun_light
          red: 100%
          green: 85%
          blue: 60%
          brightness: !lambda 'return id(day_brightness).state / 100.0;'

  # Used only where the switch's state is already settled: at boot, and when a
  # brightness number changes. NOT used from the switch's own actions.
  - id: apply_state
    mode: restart
    then:
      - if:
          condition:
            switch.is_on: night_mode
          then:
            - script.execute: show_night
          else:
            - script.execute: show_day

switch:
  - platform: template
    id: night_mode
    name: "Night mode"
    optimistic: true
    restore_mode: RESTORE_DEFAULT_OFF
    # These call show_night/show_day directly rather than apply_state.
    # A template switch fires its action BEFORE publishing its new state, so
    # anything reading switch.is_on from in here would read the OLD value and
    # display the wrong icon on every toggle.
    turn_on_action:
      - script.execute: show_night
    turn_off_action:
      - script.execute: show_day
```

- [ ] **Step 3: Create the device in the ESPHome Builder add-on**

In Home Assistant: **Settings → Add-ons → ESPHome Builder → Open Web UI → New Device**. Name it `daynight`. Choose **ESP32-C3** when asked for the board. Skip the initial install prompt.

- [ ] **Step 4: Add the secrets**

In the add-on's Web UI, open the **secrets** editor (top right) and add every key from `firmware/secrets.example.yaml` with real values. Generate the API key with:

```bash
openssl rand -base64 32
```

- [ ] **Step 5: Paste the config and validate**

Open `daynight` in the add-on, replace its entire contents with `firmware/daynight.yaml`, save, then click **Validate**.

Expected: `INFO Configuration is valid!`

If validation fails, the error names the offending key and line. Fix it in the repo copy first, then re-paste — the repo is the source of truth.

- [ ] **Step 6: Flash the board**

Connect the ESP32-C3 to the machine running the browser by USB. In the add-on choose **Install → Plug into this computer**, and follow the prompts.

Expected: the build completes and the log shows the device connecting to WiFi and obtaining an IP.

Subsequent flashes are over the air; USB is only needed this once.

- [ ] **Step 7: Commit**

```bash
cd ~/repos/daynight-indicator
git add firmware/daynight.yaml firmware/secrets.example.yaml
git commit -m "firmware: add ESPHome config for two-pixel day/night indicator"
```

---

## Task 7: Bench Test on Bare Pixels

Everything verifiable without the enclosure gets verified here, before assembly makes mistakes expensive to reach.

**Files:**
- Modify: `docs/BUILD.md` (append a `## Bench test` section)

**Interfaces:**
- Consumes: entities produced by Task 6
- Produces: a known-good board and pixel pair

- [ ] **Step 1: Solder the pixels to the board**

Cut a 2-pixel run from the strip. Solder per the wiring table in `docs/BUILD.md`. Double-check the 3.3 V connection — **not 5 V**.

- [ ] **Step 2: Confirm the entities appeared in Home Assistant**

In HA: **Settings → Devices & Services → ESPHome**. The `daynight` device should be listed with five entities: two lights, two numbers, one switch.

Expected: all five present. If the device is missing, HA usually offers it under **discovered integrations** and needs one click to adopt.

- [ ] **Step 3: Verify the correct pixel lights for each state**

Toggle `switch.daynight_night_mode` on. Expected: the **second** pixel from the strip's input end lights amber; the first is dark.

Toggle it off. Expected: the **first** pixel lights warm white; the second is dark.

If they are swapped, do **not** change the firmware — physically note which end is which and mount pixel 0 behind the sun. The firmware's indices are a global constraint.

- [ ] **Step 4: Verify exactly one is ever lit**

Toggle back and forth several times, watching through the 20 s crossfade. At no point should both pixels be lit at full brightness simultaneously, and at no point should both be dark once the fade completes.

A brief overlap *during* the crossfade is expected and correct — one is fading down while the other fades up.

- [ ] **Step 5: Verify the boot-restore path**

Set night mode on. Pull the USB cable. Wait five seconds. Reconnect.

Expected: after the device boots and reconnects, the moon pixel is lit amber again — not the sun. This exercises the `on_boot` priority `-100` handler, which is the one piece of the firmware most likely to be subtly wrong.

- [ ] **Step 6: Verify brightness changes take effect live**

Set `number.daynight_night_brightness` to 50. Expected: the amber pixel brightens noticeably within a second or two, without needing the switch toggled.

Set it back to 2.

- [ ] **Step 7: Append the results to `docs/BUILD.md`**

````markdown
## Bench test

Completed before assembly. All of the following were confirmed working with
bare pixels:

- Five entities present in Home Assistant.
- Pixel 0 lights warm white for day, pixel 1 lights amber for night.
- Exactly one pixel lit once each crossfade completes.
- State survives a power cycle.
- Brightness numbers take effect without toggling the switch.
````

- [ ] **Step 8: Commit**

```bash
cd ~/repos/daynight-indicator
git add docs/BUILD.md
git commit -m "docs: record bench test results"
```

---

## Task 8: Home Assistant Automations

**Files:**
- Create: `homeassistant/automations.yaml`

**Interfaces:**
- Consumes: `switch.daynight_night_mode` from Task 6
- Produces: three automations

- [ ] **Step 1: Write `homeassistant/automations.yaml`**

```yaml
# Reference copy. Paste into Home Assistant via Settings → Automations →
# Create Automation → Edit in YAML, one automation per entry.
#
# Times are the starting point, not gospel. Adjust to suit.

- alias: "Day/Night — night at bedtime"
  description: "Show the moon from bedtime."
  triggers:
    - trigger: time
      at: "19:00:00"
  actions:
    - action: switch.turn_on
      target:
        entity_id: switch.daynight_night_mode
  mode: single

- alias: "Day/Night — day at wake time (weekdays)"
  description: "Show the sun on school mornings."
  triggers:
    - trigger: time
      at: "06:30:00"
  conditions:
    - condition: time
      weekday: [mon, tue, wed, thu, fri]
  actions:
    - action: switch.turn_off
      target:
        entity_id: switch.daynight_night_mode
  mode: single

- alias: "Day/Night — day at wake time (weekend)"
  description: "Show the sun later at weekends."
  triggers:
    - trigger: time
      at: "07:30:00"
  conditions:
    - condition: time
      weekday: [sat, sun]
  actions:
    - action: switch.turn_off
      target:
        entity_id: switch.daynight_night_mode
  mode: single
```

**Syntax note:** this uses the modern `triggers:` / `conditions:` / `actions:` plural keys with `trigger:` and `action:` inside. Older Home Assistant releases use singular `trigger:` / `condition:` / `action:` blocks with `platform:` and `service:` keys instead. The UI editor will normalise whichever it is given.

- [ ] **Step 2: Add the automations to Home Assistant**

For each of the three: **Settings → Automations & Scenes → Create Automation → Create new automation → ⋮ → Edit in YAML**, paste one entry (without the leading `-`), and save.

- [ ] **Step 3: Verify each automation targets a real entity**

In **Developer Tools → Template**, run:

```jinja
{{ states('switch.daynight_night_mode') }}
```

Expected: `on` or `off`, not `unknown` or `unavailable`. If it is `unknown`, the entity ID differs from the plan's — check the actual ID under **Settings → Devices & Services → ESPHome → daynight** and correct all three automations.

- [ ] **Step 4: Test each automation without waiting for the clock**

For each automation: open it, then **⋮ → Run**. Confirm the switch changes state and the correct pixel lights.

Note that **Run** skips conditions, so both wake-time automations will fire regardless of the day. That is expected — this checks the action, not the schedule.

- [ ] **Step 5: Commit**

```bash
cd ~/repos/daynight-indicator
git add homeassistant/automations.yaml
git commit -m "ha: add bedtime and wake-time automations"
```

---

## Task 9: Assembly and Final Verification

Do this when the prints arrive.

**Files:**
- Modify: `docs/BUILD.md` (append `## Assembly` and `## Tuning`)

**Interfaces:**
- Consumes: everything above
- Produces: a finished device

- [ ] **Step 1: Dry-fit the parts before committing anything**

Check the back plate's lip drops into the body's open back. If it is tight, a few passes with sandpaper on the lip is the fix — do this before any electronics are attached.

- [ ] **Step 2: Mask the board's power LED**

Find the always-on power LED on the ESP32-C3 (a small SMD LED near the USB connector, usually blue or red). Cover it with a scrap of opaque tape.

**Do not skip this.** Inside a box with a translucent face it leaks through as a coloured point of light next to a 2 % amber moon — the exact wavelength the night state exists to avoid.

- [ ] **Step 3: Assemble in this order**

1. Tape the board to the back plate with foam tape, off to one side — **not directly behind either aperture**, or it shadows the diffuser.
2. Orient the board so the PCB antenna end faces open volume, with the pixel wiring running the other way.
3. Feed the USB-C cable through the cable hole from outside.
4. Plug it into the board.
5. Loop a zip tie around the cable just inside the hole and cinch it to the post. Tug the cable from outside — the pull must be taken by the post, not the connector.
6. Seat pixel 0 behind the **sun** window and pixel 1 behind the **moon** window, in their respective chambers.
7. Close the back plate.

- [ ] **Step 4: Verify dark-room readability (spec verification 1)**

In a fully dark room, set night mode. Adjust `number.daynight_night_brightness` until the moon is clearly readable but does not light the room.

Expected: readable at somewhere between 1 % and 5 %. If it is still too bright at 1 %, or if the pixel shows as a visible hot spot rather than an even glow, tape a piece of tracing paper or baking parchment to the inside of the front wall behind that window.

- [ ] **Step 5: Verify lit-room readability (spec verification 2)**

In a normally lit room, set day mode. Adjust `number.daynight_day_brightness` until the sun is legible from across the room.

- [ ] **Step 6: Verify no light bleed (spec verification 3)**

In a fully dark room with night mode set, look at the sun window and at the seams.

Expected: the sun window is completely dark, and no light escapes around the back plate or the cable hole. Any glow at the sun window means the divider is not sealing. Any coloured point elsewhere means the power LED mask has come loose.

- [ ] **Step 7: Verify power-loss restore (spec verification 4)**

Set night mode, unplug at the wall, wait ten seconds, plug back in.

Expected: the moon returns, not the sun.

- [ ] **Step 8: Verify the HA round trip (spec verification 5)**

Toggle from the HA dashboard and confirm the 20 s crossfade runs smoothly with no flicker or stepping.

- [ ] **Step 9: Verify the winter-morning case (spec verification 6)**

In a fully dark room, set day mode.

Expected: the sun is unambiguously lit. **This is the requirement that justified two icons instead of one** — confirm it explicitly rather than assuming it.

- [ ] **Step 10: Append assembly and tuning notes to `docs/BUILD.md`**

````markdown
## Assembly

1. Mask the board's power LED with opaque tape.
2. Foam-tape the board to the back plate, off to one side, clear of both apertures.
3. Orient the antenna end toward open space, away from the pixel wiring.
4. Feed the USB-C cable in through the hole, plug it into the board.
5. Zip-tie the cable to the post. Tug to confirm the post takes the load.
6. Pixel 0 behind the sun, pixel 1 behind the moon.
7. Close the back plate.

## Tuning

Both brightness levels are `number` entities in Home Assistant and persist
across reboots. The enclosure geometry is fixed once printed, so these are the
primary adjustment.

- Night: start at 2 %. Readable in a black room without lighting it.
- Day: start at 80 %. Legible across a lit room.

If the printed face reads too harsh, or the pixel shows as a hot spot rather
than an even glow, tape a piece of tracing paper or baking parchment to the
inside of the front wall behind that window. Tape rather than a printed ledge
is deliberate: it is a recoverable failure, so it does not earn geometry in a
part that cannot be reprinted.
````

- [ ] **Step 11: Commit**

```bash
cd ~/repos/daynight-indicator
git add docs/BUILD.md
git commit -m "docs: add assembly and tuning notes"
```

---

## Deferred

Recorded in the spec as a deliberate omission, not an oversight:

**On-device fallback schedule.** If Home Assistant or the network is down overnight, the device holds its last state and will still show the moon in the morning. Fixing it means adding `time` (SNTP) and `sun` components with latitude and longitude, plus a rule for which source wins when both have an opinion. It requires no hardware change and can be retrofitted at any time. Ship without it; add it only if it actually bites.
