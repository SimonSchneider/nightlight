# Day/Night Indicator — Design

**Date:** 2026-08-08
**Status:** Approved design, ready for implementation planning

## Purpose

A bedside device that tells a pre-literate child whether it is night or day, readable in a
semi-dark bedroom. Home Assistant decides which state is current; the device only renders it.

## Requirements

1. Three states: **night** (moon lit), the **morning wake window** (sun lit), and **ordinary
   daytime** (both icons dark). At most one icon is ever lit; both lit is meaningless to a child
   and must be impossible.
2. State is set entirely by Home Assistant — by schedule, or manually at any time.
3. Readable in a fully dark room, and equally readable on a dark winter morning.
4. No LCD or screen.
5. Small, cheap controller on the device side.
6. USB power is acceptable.

## Non-Requirements

Explicitly out of scope. These are cheap to add later and adding them now would inflate the build:

- A third *icon* — an "almost morning" symbol — nap mode, or quiet hours. (Both icons dark is a
  state, but it needs no hardware and no extra symbol.)
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

Two apertures, at most one lit at a time, closes that hole for the cost of one extra pixel.

### Why two switches, and why both-dark is allowed

The first implementation had a single `night_mode` switch: on showed the moon, off showed the sun.
That makes "not night" and "sun lit" the same thing, so the sun burned at 80 % from wake-up until
bedtime. Nobody needs a lit sun at 2pm, and the child is at nursery or school for most of it.

Splitting it into one switch per icon adds the state the single switch could not express: **both
dark**. That is now the ordinary daytime state, deliberately, and it is no longer a fault
condition — during the day the room is light, so an unlit panel carries no risk of being read as
"unplugged". The device is only asked to answer a question in the dark.

The winter-morning case that justified two icons in the first place is untouched, because the sun
is lit *precisely* during the dark wake window — 06:30 to 08:30 on school days — which is exactly
the interval the argument above is about. By 08:30 in December the sky is doing the job the sun
pixel was there to do.

What the split must not do is let both icons light at once, which any automation-ordering mistake
would otherwise allow. Mutual exclusion therefore stays in the firmware, not in Home Assistant:
turning one switch on extinguishes the other icon and clears the other switch's reported state.
The invariant relaxes from "exactly one lit" to **at most one lit**.

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

### Why a yellow sun, and why not an RGBW pixel

The sun was originally warm white — `red: 100 %, green: 85 %, blue: 60 %`. In practice RGB "white"
is unsatisfying. An RGB LED builds white from three narrow spectral spikes with gaps where cyan and
amber should be, so it reads bluish and harsh rather than warm. The obvious fix is an SK6812 **RGBW**
strip with a dedicated warm-white die.

That was considered and rejected in favour of simply making the sun **yellow** — red and green, no
blue at all. Five reasons, which compound:

1. **A yellow sun is the better symbol.** Children draw suns yellow. This is not a compromise that
   costs legibility; the "compromise" is more legible to a pre-literate child than the warm white it
   replaced.
2. **It costs very little brightness.** Perceived luminance is dominated by the green channel and
   blue contributes little, so red + green retains most of the apparent output of red + green + blue.
3. **It embraces what the hardware was already doing.** Blue has the highest forward voltage of the
   three dies. On the deliberately-chosen 3.3 V rail it is the most starved channel, so the "white"
   sun was already drifting yellow. Choosing yellow turns a drift into an intention.
4. **It avoids a cascade of changes.** An RGBW white die needs more than 3.3 V to run properly, which
   would have forced the supply back up to 5 V, which would have pushed the WS2812 data threshold
   (0.7 × VDD) back above the C3's 3.3 V GPIO swing — the exact problem the 3.3 V rail was chosen to
   solve. Recovering from that costs a series diode on the supply or a level shifter on the data
   line. Yellow needs neither: no new parts, no change to the rail, no change to the wiring.
5. **The device now emits no blue light at any time.** Even a warm-white phosphor LED has a blue pump
   die behind the phosphor. Red + green has no blue emitter at all. In a child's bedroom, at the
   device whose night state was already chosen for being far from the melatonin-suppressing
   wavelengths, that is strictly better — and it now holds in the day state too.

The exact yellow cannot be predicted through a 1.2 mm printed diffuser, and reflashing to nudge it is
more friction than turning a slider. The sun's **green** percentage is therefore exposed as a `Sun
hue` number (55–100 %, default 85 %), sweeping deep amber → gold → lemon yellow. Red stays at 100 %
and blue at 0 %, so no setting can reintroduce blue.

**The 55 % floor is deliberate.** The moon is amber at `green: 45 %`. Without a floor a parent tuning
the sun downwards could land on nearly the moon's hue, and two icons of the same colour destroy the
one signal the whole device exists to send. The floor keeps a visible gap between them. It is the
same class of guard as `min_value: 1` on the brightness numbers: the slider is free to be wrong, but
not free to break the design.

## Architecture

```
Home Assistant                    Device
--------------                    ------
automations ─> switch.day_night_indicator_moon_icon ─┐
                                                     ├─(ESPHome API)─> ESP32-C3
            ─> switch.day_night_indicator_sun_icon  ─┘            │
                                                            GPIO4 (data)
                                                                 │
                                                        ┌────────┴────────┐
                                                   pixel 0            pixel 1
                                                     sun               moon
```

The device holds no schedule and no clock. It exposes two switches, one per icon, and renders
whatever state they are in — with mutual exclusion enforced on the device so at most one icon is
ever lit. All timing logic lives in Home Assistant, where it is easy to change.

### Components

| Unit | Responsibility | Interface |
|---|---|---|
| HA automations | Decide when night begins, when the wake window opens, and when it closes | Set `switch.day_night_indicator_moon_icon` and `switch.day_night_indicator_sun_icon` |
| ESPHome `moon_icon` switch | Light the moon; extinguish the sun and clear its switch | On/off |
| ESPHome `sun_icon` switch | Light the sun; extinguish the moon and clear its switch | On/off |
| Scripts `show_moon` / `show_sun` / `apply_state` | Own the mutual-exclusion rule and the boot/brightness re-apply | Internal |
| Partition lights `sun_light` / `moon_light` | Own one pixel each | Internal, not exposed to HA |
| Brightness `number` entities (`night_brightness`, `day_brightness`) | Hold tuned levels across reboots | Read by the display scripts |
| `sun_hue` `number` entity | Hold the sun's green percentage (its yellow) across reboots | Read by `show_sun` |
| Enclosure | Diffuse and separate the two icons | Physical |

## Hardware

| Part | Choice | Notes |
|---|---|---|
| Controller | ESP32-C3 SuperMini | ~18 × 11 mm, USB-C, ~$3, native ESPHome support |
| Light | 2 × WS2812B or SK6812 (RGB, **not** RGBW) | Powered from the board's 3.3 V pin, data on GPIO4 |
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
  one pixel". It was dropped during the build and is superseded by `chamber_depth = 30` with both
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

| State | Sun pixel | Moon pixel | Set by |
|---|---|---|---|
| Night | off | deep amber (R 100 %, G 45 %, B 0 %), ~2 % brightness | Moon switch on |
| Morning wake window | yellow (R 100 %, G tunable 55–100 %, B 0 %), ~80 % brightness | off | Sun switch on |
| Ordinary daytime | off | off | Both switches off |

Both lit is not in the table because it is unreachable: turning either switch on extinguishes the
other icon and clears the other switch. Both dark is a normal, expected state — the panel only has
a question to answer in the dark.

Transitions crossfade over 20 seconds, so a child who happens to be awake catches it changing.

Deep amber is chosen for night deliberately: it is at the far end of the spectrum from the blue
wavelengths that suppress melatonin, and at 2 % it is readable in a black room without rousing a
sleeping child. Neither icon has any blue component in any state — see "Why a yellow sun" above.

Both brightness levels and the sun's hue are exposed to Home Assistant as `number` entities and
persist across reboots. Given that the enclosure geometry is fixed once ordered, these three are the
primary tuning mechanism and will need adjusting after first assembly.

## State Persistence and Failure Modes

| Failure | Behaviour | Mitigation |
|---|---|---|
| Power loss | Both switches restore their last state on boot via `restore_mode`; if both somehow restore on, the moon wins | Built in — the moon switch is declared second in the firmware, and at boot the second one wins; see the comment on the `switch:` block |
| WiFi or HA down overnight | Device holds last state; will not flip in the morning | **Accepted gap** |
| Weak WiFi from C3 clone | Intermittent connection | Substitute a different board |
| Diffuser too harsh, or pixel visible as a hot spot | Poor readability | Tape paper behind the window |
| Light bleed between icons | Both icons glow, signal lost | Internal dividing wall |
| Board power LED leaks | Blue/red point of light at night | Opaque tape over the LED at assembly |
| Cable yanked | USB-C pads tear off the PCB | Knot in the cable catches on the slot |
| Back plate gaps or drops out | Wiring exposed in a child's bedroom | Hot-glue dabs or foam tape at assembly; prisable for servicing |
| Brightness set to 0 in HA | A *lit* icon renders dark — indistinguishable from a dead device, the failure the design exists to prevent | `min_value: 1` on both brightness numbers |
| Sun hue tuned down towards the moon's amber | The two icons become the same colour and the signal is lost | `min_value: 55` on `sun_hue`, against the moon's fixed `green: 45 %` |
| Automation order mistake sets both switches on | Both icons lit, signal meaningless | Firmware mutual exclusion: each switch clears the other |

### The accepted gap

If Home Assistant or the network is down overnight, the device will still be showing the moon in
the morning. The fix is an on-device `time` plus `sun` fallback schedule, which is real added
complexity — SNTP, latitude and longitude, a second source of truth, and the question of which
one wins.

The decision is to ship without it and add it only if it actually bites in practice. It is
straightforward to retrofit and requires no hardware change.

## Home Assistant Integration

Two switch entities, both toggleable by hand at any time:

| Entity | Meaning |
|---|---|
| `switch.day_night_indicator_moon_icon` | On = moon lit = night |
| `switch.day_night_indicator_sun_icon` | On = sun lit = the morning wake window |

Plus the two brightness numbers and `Sun hue`. That is the whole interface — the partition lights are `internal`
and deliberately not exposed, so there is exactly one control per icon rather than a switch and a
light entity competing for the same pixel.

**On those entity IDs.** Home Assistant derives them from the device's `friendly_name` ("Day/Night
Indicator") plus each component name ("Moon icon", "Sun icon"), not from the ESPHome node name
(`daynight`). This changed in HA 2025.5, which removed a legacy exception — older material
describing `switch.daynight_*` reflects the removed behaviour. Entity IDs are also assigned once at
first registration and never auto-migrate, so a device first paired under an older version may
still carry the old ID. A device flashed with the earlier single-switch firmware will additionally
show `switch.day_night_indicator_night_mode` as an unavailable leftover. Confirm against the
running instance before relying on these IDs; automations targeting a non-existent entity report
success and do nothing.

Four automations drive them: moon on at bedtime (19:00), sun on at wake time (06:30 weekdays,
07:30 weekends), and **both** switches off at 08:30 every day, leaving both icons dark for the
rest of the day. Turning the sun on needs no accompanying moon-off action — the firmware does
that. The 08:30 automation nonetheless targets both switches deliberately: it is the schedule's
only self-healing point. HA does not replay missed time triggers, so a 06:30 sun-on lost to an HA
restart or a device reconnect would otherwise leave the moon lit until 19:00 — thirteen daylight
hours answering "night". A stuck-on sun already self-heals at 19:00; a stuck-on moon has no other
recovery. No helper `input_boolean` is needed; the ESPHome switches are the state.

## Firmware Sketch

Roughly 60 lines of ESPHome YAML:

- `esp32_rmt_led_strip` driving 2 pixels on GPIO4, marked `internal`.
- Two `partition` lights, one pixel each, both `internal`, with a 20 s default transition.
- Three template `number` entities holding day brightness, night brightness and the sun's hue (its
  green percentage), all with `restore_value: true`. Each one's `on_value` runs `apply_state`, so a
  change takes effect live.
- Two scripts, `show_moon` and `show_sun`: each lights its own icon at the colour and brightness
  in the table above, turns the other icon's pixel off, and clears the other switch.
- A third script, `apply_state`, dispatching on the two switches for boot and number changes:
  moon lit, sun lit, or both dark, with the moon winning if both are somehow on.
- Two template `switch`es with `restore_mode: RESTORE_DEFAULT_OFF`. Each `turn_on_action` runs its
  display script; each `turn_off_action` turns off only its own icon.

**Resolved during planning:**

- **A template switch fires its action *before* publishing its new state.** Any action reading
  `switch.is_on` from inside `turn_on_action` therefore sees the *old* value and would display
  the wrong icon on every toggle. Each switch's actions call `show_moon` / `show_sun` directly
  rather than going through the state-reading `apply_state`, and no action reads the state of the
  switch it belongs to.
- **Clearing the other switch uses `publish_state(false)` in a lambda, not `switch.turn_off`.**
  `publish_state` updates the reported state without firing that switch's `turn_off_action`, so
  the two switches cannot trigger each other in a loop. The other icon's pixel is already
  extinguished explicitly by the same script, so no action needs to run on its behalf.
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
4. **Power-loss restore** — turn the moon switch on, pull USB, restore power, confirm the moon
   returns. Repeat with both switches off and confirm the panel stays dark.
5. **HA round trip** — toggle both switches from HA; confirm both work and the crossfade runs.
6. **Winter-morning case** — with the room fully dark, turn the sun switch on and confirm the sun
   is unambiguously lit.
7. **Mutual exclusion** — with the moon lit, turn the sun switch on. The moon *switch* must report
   off in HA within a second or two; the moon *pixel* then fades out over the full 20 s crossfade,
   so watching the panel alone looks like both icons are lit for those 20 seconds. That is
   expected, not a fault — judge mutual exclusion by the switch states, and give the panel 20 s
   before judging it. Repeat in the other direction. Then turn the lit icon off and confirm both
   switches report off and, 20 s later, both apertures are dark.

## Build Order

1. Write and render the OpenSCAD body and back plate; export STLs.
2. Order both prints in white PLA or PETG.
3. Write and flash the ESPHome configuration; verify entities appear in HA with bare pixels on
   the bench. **Do this before the prints arrive** — it needs no enclosure, and finding a
   firmware problem while waiting on shipping costs nothing.
4. Assemble per the order in Power Entry; run verification steps 1–3 and tune brightness.
5. Write the HA automations; run verification steps 4–7.
