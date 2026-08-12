#include <FastLED.h>
#include <WiFi.h>
#include <time.h>
#include "secrets.h"

constexpr uint8_t    DATA_PIN   = 4;
constexpr int        NUM_LEDS   = 2;
constexpr uint8_t    BRIGHTNESS = 50;

// Central European Time with automatic DST (Sweden/CET)
constexpr const char TIMEZONE[]   = "CET-1CEST,M3.5.0,M10.5.0/3";
constexpr const char NTP_SERVER[] = "pool.ntp.org";

// Time boundaries (24-hour clock, HH:MM)
constexpr int NIGHT_ON_H    = 19, NIGHT_ON_M    =  0;  // LED1 on
constexpr int MORNING_ON_H  =  6, MORNING_ON_M  =  30;  // LED1 off, LED2 on
constexpr int MORNING_OFF_H = 10, MORNING_OFF_M =  0;  // LED2 off

constexpr unsigned long STATUS_INTERVAL_MS = 60000UL;
constexpr unsigned long NTP_SYNC_INTERVAL_MS = 3600000UL;  // 1 hour

CRGB leds[NUM_LEDS];
unsigned long lastStatusPrint = 0;
unsigned long lastNtpSync     = 0;

// ---------- helpers ----------

void ledsOff() {
  leds[0] = leds[1] = CRGB::Black;
  FastLED.show();
}

void connectWiFi() {
  Serial.printf("Connecting to WiFi: %s\n", WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.printf("\nConnected! IP: %s\n", WiFi.localIP().toString().c_str());
}

void syncNTP() {
  Serial.println("Syncing time via NTP...");
  configTzTime(TIMEZONE, NTP_SERVER);
  struct tm t;
  int tries = 0;
  while (!getLocalTime(&t) && tries < 20) {
    delay(500);
    Serial.print(".");
    tries++;
  }
  Serial.println();
  if (tries >= 20) {
    Serial.println("WARNING: NTP sync failed.");
  } else {
    char buf[32];
    strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S", &t);
    Serial.printf("NTP synced: %s\n", buf);
  }
}

void printStatus() {
  struct tm t;
  if (!getLocalTime(&t)) {
    Serial.println("Status: time unavailable");
    return;
  }
  char buf[32];
  strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S", &t);
  Serial.printf("Time: %s  LED1=%s  LED2=%s\n",
    buf,
    leds[0] == CRGB::Black ? "off" : "yellow",
    leds[1] == CRGB::Black ? "off" : "yellow");
}

// ---------- LED logic ----------

void updateLEDs() {
  struct tm t;
  if (!getLocalTime(&t)) {
    ledsOff();
    return;
  }

  int nowMin      = t.tm_hour * 60 + t.tm_min;
  int nightOnMin   = NIGHT_ON_H    * 60 + NIGHT_ON_M;
  int morningOnMin = MORNING_ON_H  * 60 + MORNING_ON_M;
  int morningOffMin= MORNING_OFF_H * 60 + MORNING_OFF_M;

  bool nightMode   = (nowMin >= nightOnMin) || (nowMin < morningOnMin);
  bool morningMode = (nowMin >= morningOnMin) && (nowMin < morningOffMin);

  CRGB next0 = nightMode   ? CRGB::Yellow : CRGB::Black;
  CRGB next1 = morningMode ? CRGB::Yellow : CRGB::Black;

  if (leds[0] != next0 || leds[1] != next1) {
    leds[0] = next0;
    leds[1] = next1;
    FastLED.show();
  }
}

// ---------- Arduino ----------

void setup() {
  Serial.begin(115200);
  FastLED.addLeds<WS2812, DATA_PIN, GRB>(leds, NUM_LEDS);
  FastLED.setBrightness(BRIGHTNESS);
  ledsOff();

  connectWiFi();
  syncNTP();
  lastNtpSync = millis();
  updateLEDs();
  printStatus();
}

void loop() {
  // Reconnect WiFi if dropped
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi lost — reconnecting...");
    connectWiFi();
  }

  updateLEDs();

  unsigned long now = millis();
  if (now - lastNtpSync >= NTP_SYNC_INTERVAL_MS) {
    lastNtpSync = now;
    syncNTP();
  }
  if (now - lastStatusPrint >= STATUS_INTERVAL_MS) {
    lastStatusPrint = now;
    printStatus();
  }

  delay(5000);  // re-check every 5 s
}
