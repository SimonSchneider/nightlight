#include <FastLED.h>

#define DATA_PIN    4
#define NUM_LEDS    2
#define BRIGHTNESS  50
#define BLINK_MS    2000
#define BLINK_MS_SHORT    500


CRGB leds[NUM_LEDS];

bool staticMode = false;
CRGB staticColor = CRGB::Black;

void setAll(CRGB color) {
  for (int i = 0; i < NUM_LEDS; i++) leds[i] = color;
  FastLED.show();
}

void checkSerial() {
  if (!Serial.available()) return;
  String line = Serial.readStringUntil('\n');
  line.trim();

  // Expected format: "<intensity> <RRGGBB>"  e.g. "80 FF4400"
  int spaceIdx = line.indexOf(' ');
  if (spaceIdx < 1) {
    Serial.println("ERROR: expected \"<intensity 0-255> <RRGGBB>\"");
    return;
  }

  int intensity = line.substring(0, spaceIdx).toInt();
  String hexStr = line.substring(spaceIdx + 1);
  hexStr.trim();

  if (hexStr.length() != 6) {
    Serial.println("ERROR: hex color must be 6 digits, e.g. FF4400");
    return;
  }

  uint32_t rgb = strtoul(hexStr.c_str(), nullptr, 16);
  uint8_t r = (rgb >> 16) & 0xFF;
  uint8_t g = (rgb >> 8)  & 0xFF;
  uint8_t b =  rgb        & 0xFF;

  intensity = constrain(intensity, 0, 255);
  FastLED.setBrightness(intensity);
  staticColor = CRGB(r, g, b);
  staticMode = true;

  Serial.print("OK: intensity=");
  Serial.print(intensity);
  Serial.print(" color=#");
  Serial.println(hexStr);
}

void setup() {
  Serial.begin(115200);
  FastLED.addLeds<WS2812, DATA_PIN, GRB>(leds, NUM_LEDS);
  FastLED.setBrightness(BRIGHTNESS);
  Serial.println("Ready. Send \"<intensity> <RRGGBB>\" to set static color.");
}

void loop() {
  checkSerial();

  if (staticMode) {
    setAll(staticColor);
    delay(50); // just keep checking serial
    return;
  }

  // Blink LED 1
  leds[0] = CRGB::Yellow;
  leds[1] = CRGB::Black;
  FastLED.show();
  for (int i = 0; i < BLINK_MS / 10; i++) { checkSerial(); if (staticMode) return; delay(10); }

  leds[0] = CRGB::Black;
  FastLED.show();
  for (int i = 0; i < BLINK_MS_SHORT / 10; i++) { checkSerial(); if (staticMode) return; delay(10); }

  // Blink LED 2
  leds[1] = CRGB::Yellow;
  FastLED.show();
  for (int i = 0; i < BLINK_MS / 10; i++) { checkSerial(); if (staticMode) return; delay(10); }

  leds[1] = CRGB::Black;
  FastLED.show();
  for (int i = 0; i < BLINK_MS_SHORT / 10; i++) { checkSerial(); if (staticMode) return; delay(10); }
}
