# Day/Night Indicator — Build Notes

## Bill of Materials

| # | Part | Qty | Notes |
|---|---|-----|-------|
| 1 | ESP32-C3 SuperMini | 1 | Buy the **headerless** version if offered — nothing is plugged into the pins, and it is ~8 mm thinner. |
| 2 | WS2812B LED strip, 60 LEDs/m | 1 short offcut | Cut a run of exactly 2 pixels. Buying a strip is easier to wire than individual breakouts — it has solder pads and holds the pixels at fixed spacing. |
| 3 | Silicone hookup wire, 26 AWG | 3 colours, ~30 cm each | Red (3.3 V), black (GND), any third colour (data). |
| 4 | USB-C cable, 1–2 m | 1 | Becomes captive inside the enclosure. Pick the length you actually want. |
| 5 | USB power supply, 5 V | 1 | Any phone charger. Current draw is a few tens of mA. |
| 6 | Foam double-sided tape | 1 roll | Mounts the board to the back plate. |
| 7 | Opaque tape (electrical or gaffer) | 1 roll | Masks the board's power LED. |
| 8 | Tracing paper or baking parchment | a sheet | Spare diffuser, only if the printed face reads wrong. |

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
