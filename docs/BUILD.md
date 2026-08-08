# Day/Night Indicator — Build Notes

## Bill of Materials

| # | Part | Qty | Notes |
|---|---|-----|-------|
| 1 | ESP32-C3 SuperMini | 1 | Buy the **headerless** version if offered — nothing is plugged into the pins, and it is ~8 mm thinner. |
| 2 | WS2812B (or SK6812) LED strip, **5 V**, **IP30**, 60 LEDs/m | 1 short offcut | Cut **two separate single pixels**, one per icon — not a 2-pixel run. See "Cutting the pixels" below. Two things to check in the listing: **(a) 5 V, not 12 V** — the exact chip is not critical and SK6812 is a fine, arguably better substitute, but a 12 V strip (WS2811, WS2815) looks nearly identical and **cannot run from the board's 3.3 V rail**, which this whole design depends on. **(b) IP30, not IP65/IP67** — the higher ratings are sleeved or potted in silicone, so freeing a single pixel means carving the coating off the pads with a knife. IP30 is bare PCB with exposed pads. Indoors there is no reason to want the coating. **(c) plain RGB, not RGBW** — see the note below. |
| 3 | Silicone hookup wire, 26 AWG | 3 colours, ~60 cm each | Red (3.3 V), black (GND), any third colour (data). Two 3-wire runs are needed: roughly 100 mm each for board→sun, and 90 mm each for sun→moon. 60 cm per colour leaves comfortable margin for mistakes. |
| 4 | USB-C cable, 1–2 m | 1 | Becomes captive inside the enclosure. Pick the length you actually want. |
| 5 | USB power supply, 5 V | 1 | Any phone charger. Current draw is a few tens of mA. |
| 6 | Foam double-sided tape | 1 roll | Mounts the board and both pixels to the back plate; can also retain the plate. |
| 7 | Opaque tape (electrical or gaffer) | 1 roll | Masks the board's power LED. |
| 8 | Tracing paper or baking parchment | a sheet | Spare diffuser, only if the printed face reads wrong. |
| 8b | Aluminium or black gaffer tape | 1 roll | Contingency only — lines the chamber walls if coupon sample 6 shows the walls passing light. Most kitchens and toolboxes already have one. |
| 9 | Hot-melt glue | a few sticks | Retains the back plate. Optional if you use tape instead — see Assembly. |

**Tools:** soldering iron, wire strippers, scissors, small screwdriver, hot-glue gun
(if retaining the plate with glue).

**Do not "upgrade" to an RGBW strip.** SK6812 **RGB** is a fine substitute for WS2812B; SK6812
**RGBW** (the variant with a fourth, white die) is not. Its white die needs more than 3.3 V to run
properly, which forces the supply back to 5 V and puts the WS2812 data threshold above the C3's
3.3 V GPIO — the exact problem the 3.3 V rail was chosen to avoid, and recovering from it costs a
series diode or a level shifter. The sun is yellow (red + green, no blue) precisely so no white die
is needed; see the spec's "Why a yellow sun, and why not an RGBW pixel".

**Substitution note:** some ESP32-C3 SuperMini clones ship with a poorly tuned antenna
and show weak WiFi. If range is a problem, an ESP32-C3-DevKitM-1 or a Wemos D1 Mini
drops in with no change other than possibly the GPIO number.

## Print the diffuser coupon first

`cad/stl/coupon.stl` — ~12 g, about 25 minutes. **Print it before the enclosure.**

The design depends on two *opposite* properties of the same filament, and one spool
has to satisfy both:

- The **1.2 mm face** over each icon must **transmit** enough light to read. This
  cannot be adjusted after assembly — the face is an icon-shaped membrane, and
  thinning it in place means shaving it with a knife and hoping not to punch through.
- The **2.4 mm walls and divider** must **block** light. If 2.4 mm glows even faintly
  the whole panel lights up instead of just the icon, the sun and moon stop being
  distinguishable, and the device fails from the other direction. This one is not
  adjustable at all — it is the same thickness everywhere the enclosure is solid.

Whether 1.2 mm is right depends on things no calculation settles: how heavily your
particular white filament is pigmented, how bright the room gets, and how much output
the pixels give on the 3.3 V rail. Lithophanes suggest 1.2 mm should transmit well
(they run 0.8 mm bright to 3 mm nearly opaque), but that is an argument, not a
measurement.

The coupon carries six samples, thinnest first, with a notch at the thin end so the
orientation survives being put down:

| # | Thickness | What it is |
|---|---|---|
| 1 | 0.4 mm | face candidate |
| 2 | 0.8 mm | face candidate |
| 3 | **1.2 mm** | face candidate — the current design |
| 4 | 1.6 mm | face candidate |
| 5 | 2.0 mm | face candidate |
| 6 | **2.4 mm, solid** | **the opacity control** — marked by a tick in each long edge, since it has no recess to see |

To use it:

1. Print it in the **same spool** the enclosure will use. Different white filaments
   differ a lot in pigment loading; a coupon from another spool proves nothing.
2. Wire up one pixel and hold the coupon **25 mm above it** — the real chamber depth.
3. **Judge samples 1–5 for transmission**, in the room and the lighting the finished
   device will live in. Two states, because they pull in opposite directions:
   - **Night**, pixel at ~2 % amber, room fully dark: readable but not room-lighting.
   - **Day**, pixel at ~80 % yellow (red + green, no blue), room lit as it will be on a winter morning:
     legible from across the room.
4. **Judge sample 6 for opacity**, and judge it hard. Set the pixel to **~80 % yellow**
   (the brightest the device ever gets) and view it in a **fully dark room**
   with dark-adapted eyes. That is the worst case — the winter-morning sun state —
   and it is when any wall glow would show. Sample 6 must look **dark**. A faint
   even glow is tolerable; a clearly visible disc is not.
5. If a thickness other than 1.2 mm wins, set `face_t` in `cad/params.scad` and re-run
   `./render.sh` before printing the body. Nothing else needs changing.

**Sample 6 will most likely pass.** Transmission through a pigmented medium falls
roughly exponentially with thickness, so doubling the thickness roughly squares it: a
filament passing 20 % at 1.2 mm passes around 4 % at 2.4 mm. That 5:1 contrast between
icon and wall comes from the geometry, not from picking a special spool.

**If it does glow, line the chambers — do not buy another spool, and do not thicken
the walls.** In order of preference:

1. **Line the inside of the chamber walls** with aluminium tape, black gaffer tape, or
   a brush of acrylic paint. The walls are flat and fully accessible with the back
   plate off, and nowhere near the face. This costs a roll of tape and fixes it
   completely. It is the same recoverable-at-assembly principle used for the board's
   power LED and the paper diffuser.
2. Only if lining somehow fails, try a more heavily pigmented white.

Do **not** raise `wall` to chase opacity. `face_t` and `wall` are related — the face is
the wall thinned from behind — so thickening the wall pushes you toward a thicker face
and you lose transmission at the other end. You cannot win both by adding plastic.

Bias thinner on the face when it is close. Too bright is fixed with a slider or a
scrap of tracing paper; too dim is fixed only by reprinting.

## Cutting the pixels

**Why two separate pixels and not a 2-pixel length of strip.** At 60 LEDs/m the pixel
pitch is 16.7 mm. The two apertures are **56 mm apart**, and a solid printed divider
runs between the chambers, so a continuous strip could neither reach nor pass. Each
pixel has to be freed and placed on its own, joined by a 3-wire run that crosses
through the notch in the back plate's lip.

A 5 V WS2812B strip is a chain of independent pixels with a **marked cut line between
every one** — a dotted line crossing the three pairs of copper pads that join one pixel
to the next. Cut along it with scissors and each pixel comes away as its own small PCB
with **three solder pads at each end** — one half of each pad-pair stays with each
neighbour:

```
        ┌──────────────────┐
   VCC ─┤                  ├─ VCC
  DATA ─┤   one WS2812B    ├─ DATA
   GND ─┤   ───► data ───► ├─ GND
        └──────────────────┘
     input side (DIN)   output side (DOUT)
```

**Go by the silkscreen, not by this drawing.** The vertical order of the three pads
varies between strips and manufacturers; every strip prints its own labels next to
them (5V or VCC, DIN/DI and DOUT/DO, GND). Read them under good light, with a magnifier
if needed, and identify each pad before soldering. Mistaking GND for DIN puts the supply
across the data input and destroys the pixel — this is the one error here with no
recovery, and it is invisible until nothing lights.

That is all the preparation needed — no extra parts, and nothing to add to the pixel
itself. Cut two of them, and cut a spare if the offcut allows; they cost nothing and
a mis-soldered pad is easier to replace than to rework.

Both pixels mount on the **back plate**, 56 mm apart, not on the front. The 25 mm
chamber depth does the light-spreading, so the wires between them lie flat across the
plate and pass through the notch. They stay short.

## Wiring

The two pixels are wired as a chain of two separate parts, with **two 3-wire runs**:

1. **Board → sun pixel.** This run crosses the divider through the notch in the
   back plate's lip.
2. **Sun pixel DOUT → moon pixel DIN.** This run crosses back through the same notch.

| Run | From | To | Wire |
|---|---|---|---|
| 1 | Board **3V3** (not 5V) | Sun pixel 5V / VCC | red |
| 1 | Board GND | Sun pixel GND | black |
| 1 | Board GPIO4 | Sun pixel **DIN** | data |
| 2 | Sun pixel 5V / VCC | Moon pixel 5V / VCC | red |
| 2 | Sun pixel GND | Moon pixel GND | black |
| 2 | Sun pixel **DOUT** | Moon pixel **DIN** | data |

**The 3.3 V connection is deliberate, not a mistake.** See the spec's rationale section.

### Direction matters — get the chain order right

WS2812 pixels are **directional**. Data enters at **DIN**, is consumed by that pixel,
and what is left leaves at **DOUT** for the next pixel down the chain. The arrows
printed on the strip point from DIN towards DOUT, i.e. in the direction data flows.

The chain order *is* the pixel index. The first pixel the data reaches is pixel 0.
The firmware drives **pixel 0 as the sun** and **pixel 1 as the moon**, so:

- GPIO4 must go to the **sun** pixel's DIN.
- The **sun** pixel's DOUT must go to the **moon** pixel's DIN.

Wire it the other way round and the icons are swapped — the device shows a sun at
bedtime. It is fixable in firmware by swapping the two `partition` segments, but it
is far easier to solder it right.

Do not connect anything to the moon pixel's DOUT; it is the end of the chain.

## Assembly

Order of work:

1. **Mask the board's power LED** with opaque tape. Inside a box with a translucent
   face it leaks a blue or red point of light next to a 2 % amber moon.
2. **Tape the board to the back plate** with foam double-sided tape. Put it on the
   **moon side** (the same side as the cable slot) and *not* directly behind an
   aperture, where it would shadow the diffuser. Orient the PCB antenna towards open
   volume, away from the pixel wiring.
3. **Place the pixels.** They must sit at **x = ±28 mm from the panel centre —
   56 mm apart** — each centred behind its own window, one per chamber. Identify the
   chambers by the windows themselves, not by left and right: with the back plate off
   you are looking at the panel from behind and left/right are mirrored. **The moon
   chamber is the one containing the cable slot; the sun chamber is the other one.**
   Foam tape holds the pixels to the back plate. There is no printed pixel pocket; the
   25 mm chamber depth does the light-spreading work, so exact standoff is not
   critical, but lateral centring is — an off-centre pixel shows as a bright edge on
   the icon.
4. **Route the wiring through the notch in the lip.** The notch is the 6 mm wide slot
   cut across the lip on the divider line, at the centre of the plate. It runs the
   lip's full length, so wires can cross at whatever height suits. Once the parts are
   mated the clear opening under the divider is **2.6 mm high × 58.6 mm long** — ample
   for all six wires side by side. Keep the wires down in the notch; if any ride up
   onto the lip the plate will not seat and the box will stand proud.
5. **Lay the USB-C cable into the slot**, plug it into the board, and **tie an overhand
   knot inside the enclosure**. The knot is the strain relief — it is wider than the
   8 mm slot mouth and cannot pull back out.
6. **Close and retain the back plate.** The lip locates it but nothing holds it in.
   Standing on a shelf the panel is vertical and the plate faces backwards, so left
   loose it can gap open or drop out and expose the wiring. Retain it with either:
   - **four or five dabs of hot glue** around the flange, one per corner plus one at
     the cable slot; or
   - **double-sided foam tape** in short strips around the lip.

   Both are deliberately chosen to be prisable — put a thumbnail or a plastic spudger
   into the seam and the plate comes off for servicing. **Do not use superglue or
   epoxy**: the brightness numbers will need re-tuning after first assembly, and the
   board is the only thing in there that can fail.

Before gluing anything, power it up and run verification steps 1–3 in the spec, so
the brightness is roughly tuned while the box still opens freely.
