# Day/Night Indicator — Build Notes

## Bill of Materials

| # | Part | Qty | Notes |
|---|---|-----|-------|
| 1 | ESP32-C3 SuperMini | 1 | Buy the **headerless** version if offered — nothing is plugged into the pins, and it is ~8 mm thinner. |
| 2 | WS2812B LED strip, 60 LEDs/m | 1 short offcut | Cut **two separate single pixels**, one per icon — not a 2-pixel run. At 60 LEDs/m the pitch is 16.7 mm, but the apertures are 56 mm apart and a solid divider runs between them, so an intact run cannot reach both. A strip is still the easiest source: each cut segment arrives with solder pads on both ends. |
| 3 | Silicone hookup wire, 26 AWG | 3 colours, ~60 cm each | Red (3.3 V), black (GND), any third colour (data). Two 3-wire runs are needed, and one of them crosses the enclosure. |
| 4 | USB-C cable, 1–2 m | 1 | Becomes captive inside the enclosure. Pick the length you actually want. |
| 5 | USB power supply, 5 V | 1 | Any phone charger. Current draw is a few tens of mA. |
| 6 | Foam double-sided tape | 1 roll | Mounts the board and both pixels to the back plate; can also retain the plate. |
| 7 | Opaque tape (electrical or gaffer) | 1 roll | Masks the board's power LED. |
| 8 | Tracing paper or baking parchment | a sheet | Spare diffuser, only if the printed face reads wrong. |
| 9 | Hot-melt glue | a few sticks | Retains the back plate. Optional if you use tape instead — see Assembly. |

**Tools:** soldering iron, wire strippers, scissors, small screwdriver, hot-glue gun
(if retaining the plate with glue).

**Substitution note:** some ESP32-C3 SuperMini clones ship with a poorly tuned antenna
and show weak WiFi. If range is a problem, an ESP32-C3-DevKitM-1 or a Wemos D1 Mini
drops in with no change other than possibly the GPIO number.

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
