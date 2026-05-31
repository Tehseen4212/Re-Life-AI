
#include <WiFi.h>
#include <HTTPClient.h>
#include "DHT.h"

// 🔥 OLED LIBRARIES
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

// ===== OLED SETTINGS =====
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);

// ===== WIFI =====
const char* ssid = "Nord 4";
const char* password = "87654321";

// ===== SUPABASE =====
const char* supabaseUrl = "https://nbmparowweqnanqzkdri.supabase.co/rest/v1/storage_telemetry_logs";
const char* supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5ibXBhcm93d2VxbmFucXprZHJpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYwOTE0MDUsImV4cCI6MjA5MTY2NzQwNX0.fUDCRQjYc4KRP--shV1xWpGezOkgJQrq0tXhMyXE61U";

// ===== STORAGE BIN ID =====
String storageBinId = "7ed66336-35eb-469c-bd11-e046e1923115";

// ===== DHT =====
#define DHTPIN 3
#define DHTTYPE DHT22
DHT dht(DHTPIN, DHTTYPE);

void setup() {
  Serial.begin(115200);
  delay(1000);

  dht.begin();

  // 🔥 I2C PINS (ESP32-C3)
  Wire.begin(7, 8);

  // 🔥 OLED INIT
  if(!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println("OLED Failed ❌");
    while(true);
  }

  display.clearDisplay();
  display.setTextColor(WHITE);

  // WIFI CONNECT
  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println("\nWiFi Connected ✅");
}

void loop() {
  float temp = dht.readTemperature();
  float hum = dht.readHumidity();

  if (isnan(temp) || isnan(hum)) {
    Serial.println("Failed to read from DHT ❌");
    delay(2000);
    return;
  }

  Serial.println("------");
  Serial.print("Temp: "); Serial.println(temp);
  Serial.print("Humidity: "); Serial.println(hum);

  // 🔥 OLED DISPLAY (PERFECT FIT)
  display.clearDisplay();

  // 🔥 BIG TEXT FOR ALL (perfect fit)
  display.setTextSize(2);

  // LINE 1 (Title)
  display.setCursor(0, 0);
  display.print("ENVMONITOR");

  // LINE 2 (Temp)
  display.setCursor(0, 22);
  display.print("TEM:");
  display.print(temp, 1);
  display.print((char)247); // °
  display.print("C");

  // LINE 3 (Humidity)
  display.setCursor(0, 44);
  display.print("HUM:");
  display.print(hum, 1);
  display.print("%");

  display.display();

  // 🔥 SEND TO SUPABASE
  if (WiFi.status() == WL_CONNECTED) {

    HTTPClient http;
    http.begin(supabaseUrl);

    http.addHeader("Content-Type", "application/json");
    http.addHeader("apikey", supabaseKey);
    http.addHeader("Authorization", "Bearer " + String(supabaseKey));
    http.addHeader("Prefer", "return=minimal");

    String body = "{";
    body += "\"storage_bin_id\":\"" + storageBinId + "\",";
    body += "\"temperature\":" + String(temp) + ",";
    body += "\"humidity\":" + String(hum);
    body += "}";

    Serial.println("Sending Payload: " + body);

    int httpResponseCode = http.POST(body);

    Serial.print("Response: ");
    Serial.println(httpResponseCode);

    http.end();
  }

  delay(10000);
}
