// Bring-up test: proves the wiring before anything is assembled.
// No WiFi, no secrets.h — flash it and watch.
//
// Answers in one run: is the data line alive, which physical pixel is index 0,
// is the colour order right, and is the second pixel connected?

#include <FastLED.h>

#define DATA_PIN 4
#define NUM_LEDS 2

CRGB leds[NUM_LEDS];
int step = 0;

void setup() {
  Serial.begin(115200);
  FastLED.addLeds<WS2812, DATA_PIN, GRB>(leds, NUM_LEDS);
  FastLED.setBrightness(60);
}

void loop() {
  fill_solid(leds, NUM_LEDS, CRGB::Black);

  switch (step) {
    case 0: leds[0] = CRGB::Red;   Serial.println("pixel 0 RED");   break;
    case 1: leds[0] = CRGB::Green; Serial.println("pixel 0 GREEN"); break;
    case 2: leds[0] = CRGB::Blue;  Serial.println("pixel 0 BLUE");  break;
    case 3: leds[1] = CRGB::Red;   Serial.println("pixel 1 RED");   break;
    case 4: leds[1] = CRGB::Green; Serial.println("pixel 1 GREEN"); break;
    case 5: leds[1] = CRGB::Blue;  Serial.println("pixel 1 BLUE");  break;
    case 6: fill_solid(leds, NUM_LEDS, CRGB::White);
            Serial.println("both WHITE"); break;
    default: Serial.println("both off"); break;
  }

  FastLED.show();
  step = (step + 1) % 8;
  delay(700);
}
