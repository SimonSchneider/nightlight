# Day/Night Indicator — Design

**Date:** 2026-08-08
**Status:** Approved design, ready for implementation planning

## Purpose

A bedside device that tells a pre-literate child whether it is night or day, readable in a
semi-dark bedroom. Home Assistant decides which state is current; the device only renders it.

## Requirements

1. Two states only: **night** and **day**.
2. State is set entirely by Home Assistant — by schedule, or manually at any time.
3. Readable in a fully dark room, and equally readable on a dark winter morning.
4. No LCD or screen.
5. Small, cheap controller on the device side.
6. USB power is acceptable.

## Non-Requirements

Explicitly out of scope. These are cheap to add later and adding them now would inflate the build:

- An "almost morning" third state, nap mode, or quiet hours.
- Any clock, schedule, or sunrise logic on the device.
- Sound, buttons, or child-facing input of any kind.
- Battery operation.

## Design Rationale

### Why light, not a passive display

E-paper and a mechanical pointer are both *reflective* — they have no light of their own.
In a semi-dark room neither is readable, which defeats the purpose. Once you accept that the
device must emit light, a dim backlight is the simplest way to do it, and a servo arm becomes
added mechanical risk for theatre rather than function.

Ruled out for the same reason: **OpenEPaperLink** ESL tags. They are otherwise an excellent fit
for "tiny controller" — no device-side firmware, years on a coin cell, a single ESP32 access
point driving them from HA — but they are invisible in the dark, and they look like supermarket
price tags.

### Why two lit icons rather than one

The obvious simplification is a single light: lit means night, unlit means day. It fails on a
dark winter morning. At 07:00 in December the room is black, nothing is lit, and "day" is
indistinguishable from "unplugged" or "broken" — precisely when the child most needs an answer.

Two apertures, exactly one lit at a time, closes that hole for the cost of one extra pixel.

### Why WS2812 pixels on the 3.3 V rail

WS2812s are normally run at 5 V, where their data threshold is 0.7 × VDD = 3.5 V. The ESP32-C3's
GPIO swings to 3.3 V, which is marginally out of spec and a well-known source of intermittent
pixel glitches.

Powering the pixels from the board's 3.3 V rail instead drops the threshold to 2.3 V and makes
the data line comfortably valid. The cost is reduced peak brightness, which is irrelevant here —
night runs at roughly 2 % duty.

The alternative, discrete LEDs on PWM, would need a MOSFET per channel: warm-white LEDs have a
forward voltage of 3.0–3.2 V, leaving no usable headroom on a 3.3 V rail, and the C3's ~12 mA
recommended per-GPIO source current is tight for direct drive. Two pixels on one GPIO is fewer
parts, fewer failure modes, and moves all colour and brightness tuning into software.

## Architecture

```
Home Assistant                    Device
--------------                    ------
automations ─> switch.day_night_indicator_night_mode ─(ESPHome API)─> ESP32-C3
                                                                 │
                                                            GPIO4 (data)
                                                                 │
                                                        ┌────────┴────────┐
                                                   pixel 0            pixel 1
                                                     sun               moon
```

The device holds no schedule and no clock. It exposes one switch and renders whatever state that
switch is in. All timing logic lives in Home Assistant, where it is easy to change.

### Components

| Unit | Responsibility | Interface |
|---|---|---|
| HA automations | Decide when night begins and ends | Set `switch.day_night_indicator_night_mode` |
| ESPHome `night_mode` switch | Translate state into a light pair | On/off; drives both partition lights |
| Partition lights `sun_light` / `moon_light` | Own one pixel each | Standard ESPHome light API |
| Brightness `number` entities | Hold tuned levels across reboots | Read by the switch's actions |
| Enclosure | Diffuse and separate the two icons | Physical |

## Hardware

| Part | Choice | Notes |
|---|---|---|
| Controller | ESP32-C3 SuperMini | ~18 × 11 mm, USB-C, ~$3, native ESPHome support |
| Light | 2 × WS2812B or SK6812 | Powered from the board's 3.3 V pin, data on GPIO4 |
| Power | USB-C, captive cable | A few mA at night; the WiFi radio dominates |
| Enclosure | Custom body + back plate | Board lives inside; see Enclosure below |
| Fixings | Foam double-sided tape, opaque tape | Board mount, LED mask. Strain relief is a knot in the cable |

**Pin choice:** GPIO2, GPIO8 and GPIO9 are strapping pins on the ESP32-C3 and are sampled during
boot; hanging a WS2812 data line off one risks intermittent boot failures. GPIO4 is used instead.
GPIO3, 5, 6, 7 and 10 are equally safe substitutes.

**Known risk:** some ESP32-C3 SuperMini clones ship with a poorly tuned antenna and show weak
WiFi. If range is a problem, substitute an ESP32-C3-DevKitM-1 or a Wemos D1 Mini. Nothing else
in the design changes.

## Enclosure

Two ordered prints — body and back plate — forming one integrated object. There is no 3D printer
on hand, so iteration is slow and expensive, and the design is built to be right on arrival.
Every dimension that could be wrong is made tolerant rather than precise.

The ESP32-C3 lives **inside** the enclosure, stuck to the back plate with foam double-sided tape.
At 18 × 11 mm it fits easily in depth the panel already needs for light mixing, and integrating
it removes an external cable run between two separate objects.

### Design principle: recoverable vs. irrecoverable

Prints are ordered and cannot be iterated cheaply, so the rule is:

- **Irrecoverable after printing** → design it out of the geometry.
- **Recoverable at assembly with tape, paper, or a knife** → leave it to the assembly
  instructions and keep the part simple.

This is why the sun/moon divider is a printed wall but the board's power LED is a piece of tape.

### Body (custom, parametric OpenSCAD)

Two internal chambers, one per aperture, separated by a dividing wall. The board sits in whichever
chamber is convenient — **not directly behind an aperture**, or it shadows the diffuser.

Features:

- A sun aperture and a moon aperture, side by side.
- A **1.2 mm translucent printed face** across each aperture, acting as the primary diffuser.
  This is three passes of a 0.4 mm nozzle. An earlier revision of this document said 1.0 mm,
  which is not a whole multiple of 0.4 and so could not be built as written; `face_t = 1.2`
  in `cad/params.scad` is the value that was built and is the one that governs.
- **No printed diffuser ledge.** An earlier revision specified a recess behind each aperture to
  hold a paper diffuser disc. It does not work: retaining a disc requires a rim behind it, while
  inserting one from behind requires an opening larger than the disc. Thickening the wall enough
  to satisfy both leaves a thin translucent halo around each icon that glows unintentionally.
  Since a paper diffuser is a recoverable fix, it is taped to the inside of the front wall at
  assembly instead — consistent with the principle above.
- An **internal dividing wall** between the two apertures. Without it the lit moon bleeds through
  the sun and both glow faintly, destroying the signal. This is the single most important feature
  of the part, and the one thing that cannot be fixed after printing.
- **No printed pixel pocket.** An earlier revision listed "a pocket behind each aperture locating
  one pixel". It was dropped during the build and is superseded by `chamber_depth = 25` with both
  pixels taped to the back plate. The reason: a pocket in the body would fix the pixel's standoff
  from the face, but 25 mm of chamber is already enough for the light to spread evenly, so the
  pocket buys nothing optically — while its depth, width and the pixel's own carrier dimensions
  are three guessed numbers on a print that cannot be re-ordered cheaply. Lateral centring, which
  is the part that actually matters, is a recoverable assembly step: place each pixel at
  x = ±28 mm, centred behind its window. Consistent with the principle above.
- A **wire pass-through notch cut in the back plate's lip**, on the divider line. The board and
  the cable slot are both in the moon chamber, so the sun pixel's wiring has to cross the divider.
  The notch is in the *lip*, never in the divider: the divider stays solid, so light between the
  chambers still has to travel the long way round, ~25 mm behind the faces and through a 6 × 2.6 mm
  gap. At the 2 % night duty that leak is negligible.
- A **U-shaped cable slot open to the back plate's edge**, generously oversized. Strain relief is
  a knot tied in the cable at assembly, not a printed feature.
- **No printed fasteners.** Nothing retains the back plate in the geometry; it is held by hot-glue
  dabs or double-sided tape at assembly, chosen so it can still be prised off for servicing. A
  plate that comes loose is recoverable, so per the principle above it earns an instruction rather
  than printed clips or screw bosses.

Parametric so aperture diameter, face thickness, wall height, chamber depth, divider clearance and
wire-notch width are all variables rather than baked geometry.

### Board mounting

Foam double-sided tape onto the back plate. No pocket, no clips, no dedicated compartment — the
board is 18 × 11 mm and light enough that tape is sufficient, and every printed retention feature
is a dimension that could be wrong on arrival.

Three assembly rules, none of which affect the printed geometry:

1. **Mask the power LED.** The C3 SuperMini has an always-on power LED. Inside a box with a
   translucent face it leaks through, putting a blue or red point of light next to a 2 % amber
   moon — the exact wavelength the night state exists to avoid. Cover it with opaque tape, paint,
   or nail polish. Recoverable at any time by opening the back plate, so it does not warrant a
   printed compartment.
2. **Keep the board off the apertures.** Mount it to one side. Directly behind an aperture it
   casts a shadow on the diffuser.
3. **Antenna clearance.** Plastic is RF-transparent so enclosure is fine in itself, but the PCB
   antenna must not sit against the pixel wiring. Orient the board with the antenna end facing
   open volume and the wiring running the other way. The SuperMini's weak-antenna reputation
   means there may be no margin to spare.

### Power entry

**A captive USB-C cable laid into a U-slot open to the back plate's edge, retained by a knot tied
in the cable.**

A fitted USB-C port cutout was rejected: its position is fixed relative to wherever the board
happens to be taped, which is not a dimension the print can know in advance, and
being 1 mm out on a print that cannot be re-ordered cheaply means filing plastic or paying again.
A seam-clamped "pinch" hole was rejected for the same class of reason — it depends on hitting a
tolerance against a guessed cable jacket diameter, where too tight prevents the back plate
closing and too loose grips nothing.

**A closed round hole was also rejected, and this one was a live defect caught during the build.**
An 8 mm hole cannot be assembled at all: a USB-C plug is roughly 12 × 6.5 mm bare and ~15 × 8 mm
overmoulded, and the cable's far end carries a connector too, so neither end passes through in
either direction. Enlarging the hole enough to admit a plug would make it conspicuous and leak
light. A slot open to the edge sidesteps the problem entirely — the cable drops in sideways and
no connector passes through anything.

The slot is generously oversized, so there is no tolerance to miss. It also leaves no exposed
port for a child to poke.

**Strain relief is a knot, not a printed feature.** An earlier revision specified an internal
zip-tie post. It was removed once the device's location was settled — a high shelf, out of
children's reach. A simple overhand knot tied in the cable inside the enclosure is roughly 10 mm
across and cannot pass back through the 8 mm slot, so it performs the same job for free. This
still matters even out of reach: the board's USB-C connector is surface-mounted, its pads tear
off the PCB under a hard pull, and that destroys the board with no recovery — so the pull must
land on something other than the connector.

Assembly order: back plate off → mask the board's power LED → tape board to back plate (moon
side) → tape the two pixels at x = ±28 mm → route the sun pixel's wiring through the lip notch →
lay cable into the slot → plug into board → tie the knot inside → back plate on and retained with
hot-glue dabs or double-sided tape. `docs/BUILD.md` carries the working version of this list.

### Material

White PLA or PETG, FDM, from a print service. White FDM material diffuses light well at around a
millimetre; the face is 1.2 mm. Face thickness is specified as a whole multiple of a 0.4 mm
nozzle. The part is designed support-free.

### Prior art considered and rejected

- [Kids Clock — ESP32 LED Symbols by Remindi](https://www.printables.com/model/1518948-kids-clock-esp32-led-symbols-time-events-weather) —
  has the right sun and moon iconography, but is a full symbol clock with weather, weekday dots,
  seasons and birthday countdowns, running its own clock logic and WebUI. Wrong architecture:
  we want the device to take orders from HA, not to be authoritative. Appears to be a paid model.
- [rparish toddler nightlight](https://www.printables.com/model/625681-nightlighttoddler-clockok-to-wake-lightsleep-train) —
  free and close in spirit, but uses a single diffused window with colour carrying the meaning,
  which is the variant rejected above.
- [Moon & Sun Art Wall by AJ Print](https://www.printables.com/model/906375-moon-sun-art-wall/related) —
  free flat 170 × 170 × 2 mm plaque. Solid decorative geometry with no apertures, diffuser, or
  backlighting provision. Usable only as silhouette reference.

## Behaviour

| State | Sun pixel | Moon pixel |
|---|---|---|
| Night | off | deep amber, ~2 % brightness |
| Day | warm white, ~80 % brightness | off |

Transitions crossfade over 20 seconds, so a child who happens to be awake catches it changing.

Deep amber is chosen for night deliberately: it is at the far end of the spectrum from the blue
wavelengths that suppress melatonin, and at 2 % it is readable in a black room without rousing a
sleeping child.

Both brightness levels are exposed to Home Assistant as `number` entities and persist across
reboots. Given that the enclosure geometry is fixed once ordered, these are the primary tuning
mechanism and will need adjusting after first assembly.

## State Persistence and Failure Modes

| Failure | Behaviour | Mitigation |
|---|---|---|
| Power loss | Switch restores its last state on boot via `restore_mode` | Built in |
| WiFi or HA down overnight | Device holds last state; will not flip in the morning | **Accepted gap** |
| Weak WiFi from C3 clone | Intermittent connection | Substitute a different board |
| Diffuser too harsh, or pixel visible as a hot spot | Poor readability | Tape paper behind the window |
| Light bleed between icons | Both icons glow, signal lost | Internal dividing wall |
| Board power LED leaks | Blue/red point of light at night | Opaque tape over the LED at assembly |
| Cable yanked | USB-C pads tear off the PCB | Knot in the cable catches on the slot |
| Back plate gaps or drops out | Wiring exposed in a child's bedroom | Hot-glue dabs or foam tape at assembly; prisable for servicing |
| Brightness set to 0 in HA | Neither icon lit — the failure the design exists to prevent | `min_value: 1` on both brightness numbers |

### The accepted gap

If Home Assistant or the network is down overnight, the device will still be showing the moon in
the morning. The fix is an on-device `time` plus `sun` fallback schedule, which is real added
complexity — SNTP, latitude and longitude, a second source of truth, and the question of which
one wins.

The decision is to ship without it and add it only if it actually bites in practice. It is
straightforward to retrofit and requires no hardware change.

## Home Assistant Integration

A single entity, `switch.day_night_indicator_night_mode`, toggleable by hand at any time.

**On that entity ID.** Home Assistant derives it from the device's `friendly_name` ("Day/Night
Indicator") plus the component name ("Night mode"), not from the ESPHome node name (`daynight`).
This changed in HA 2025.5, which removed a legacy exception — older material describing
`switch.daynight_night_mode` reflects the removed behaviour. Entity IDs are also assigned once at
first registration and never auto-migrate, so a device first paired under an older version may
still carry the old ID. Confirm against the running instance before relying on it; automations
targeting a non-existent entity report success and do nothing.

Two automations flip it on schedule — on at bedtime, off at wake time — with a separate weekend
wake time if wanted. No helper `input_boolean` is needed; the ESPHome switch is the state.

## Firmware Sketch

Approximately 40 lines of ESPHome YAML:

- `esp32_rmt_led_strip` driving 2 pixels on GPIO4, marked `internal`.
- Two `partition` lights, one pixel each, named Sun and Moon, with a 20 s default transition.
- Two template `number` entities holding day and night brightness, with `restore_value: true`.
- A template `switch` with `restore_mode: RESTORE_DEFAULT_OFF`, whose `turn_on_action` and
  `turn_off_action` set the pair to the table above, reading brightness from the numbers via
  lambda.

**Resolved during planning:**

- **A template switch fires its action *before* publishing its new state.** Any action reading
  `switch.is_on` from inside `turn_on_action` therefore sees the *old* value and would display
  the wrong icon on every toggle. The switch's actions call `show_night` / `show_day` directly
  rather than going through a state-reading dispatcher.
- **Boot ordering between `number` and `switch` restore** is sidestepped by an `on_boot` handler
  at priority `-100`, which runs after all components have restored and re-applies state.
- **`rmt_channel` is not required** — current ESPHome manages RMT allocation itself.
- **No `hardware_uart` setting is needed** for logging on the C3 under the esp-idf framework.

## Verification

1. **Dark-room readability** — with the panel assembled but before final closure, view the moon
   at 2 % in a fully dark room. Tune the night brightness number until readable but not rousing.
2. **Lit-room readability** — confirm the sun is legible across a daylit room at the chosen day
   brightness.
3. **Light bleed** — in a dark room with only the moon lit, confirm the sun aperture is fully
   dark, and that no stray point of light shows from the board's power LED. This validates the
   dividing wall and the LED masking.
4. **Power-loss restore** — set night mode, pull USB, restore power, confirm the moon returns.
5. **HA round trip** — toggle from HA and from the device's own entity; confirm both work and the
   crossfade runs.
6. **Winter-morning case** — with the room fully dark, set day mode and confirm the sun is
   unambiguously lit.

## Build Order

1. Write and render the OpenSCAD body and back plate; export STLs.
2. Order both prints in white PLA or PETG.
3. Write and flash the ESPHome configuration; verify entities appear in HA with bare pixels on
   the bench. **Do this before the prints arrive** — it needs no enclosure, and finding a
   firmware problem while waiting on shipping costs nothing.
4. Assemble per the order in Power Entry; run verification steps 1–3 and tune brightness.
5. Write the HA automations; run verification steps 4–6.
