/*
  ===================================================================
  ESP32 PV MONITORING AND FAULT DETECTION SYSTEM
  RASID — Full Build (Temp + Voltage + Current + Pyranometer)
  ===================================================================
*/

#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <time.h>
#include <Wire.h>
#include <Adafruit_ADS1X15.h>
#include "addons/TokenHelper.h"
#include "addons/RTDBHelper.h"

Adafruit_ADS1115 ads1;  // current sensors
Adafruit_ADS1115 ads2;  // pyranometer + voltage dividers

const char* ssid     = "SA";
const char* password = "30y5781kxkaye";

const char* FIREBASE_API_KEY      = "AIzaSyDI_o5Rd6XpcaWS8haMlzfurE9v8eLcAUo";
const char* FIREBASE_DATABASE_URL = "https://pv-monitoring-system-d1ade-default-rtdb.firebaseio.com";

FirebaseData   fbdo;
FirebaseAuth   auth;
FirebaseConfig config;

#define SENSOR1_PIN  33    // ambientTemp
#define SENSOR2_PIN   25 // string1Temp
#define SENSOR3_PIN 26    // string2Temp

OneWire oneWire1(SENSOR1_PIN);
OneWire oneWire2(SENSOR2_PIN);
OneWire oneWire3(SENSOR3_PIN);

DallasTemperature sensor1(&oneWire1);
DallasTemperature sensor2(&oneWire2);
DallasTemperature sensor3(&oneWire3);

const float Voltage_DIVIDER_RATIO = 7.8;

const float R1 = 4700.0; // current
const float R2 = 6800.0; // current
const int NUM_SAMPLES = 50;
const float WCS1800_SENSITIVITY_V = 0.052;
const float WCS1800_Zero_C_0      = 1.674;    // powered from 3.3V
const float WCS1800_Zero_C_1      = 1.686; 
const float WCS1800_DIVIDER_RATIO = R2 / (R1 + R2);
const float PYRANOMETER_SENSITIVITY_V = 0.00002287;

const float VOLTAGE_MIN           = 10.0;
const float VOLTAGE_MAX           = 500.0;
const float CURRENT_MAX           = 25.0;
const float TEMP_CRITICAL         = 80.0; 
const float TEMP_WARNING          = 70.0; 
const float TEMP_IMBALANCE_DELTA  = 15.0; 
const float TEMP_RISE_THRESHOLD   = 10.0;  // Early warning temp rise above ambient
const float HOTSPOT_RISE_THRESHOLD = 25.0; // Dedicated hotspot: severe rise above ambient
const float IRRADIANCE_MIN        = 50.0;
const float EFFICIENCY_MIN        = 70.0;

// New fault detection thresholds
const float SHORT_CIRCUIT_VOLTAGE      = 2.0;   // V — voltage collapses while current flows
const float SHORT_CIRCUIT_CURRENT_MIN  = 0.5;   // A — minimum current to distinguish from open
const float SHADING_IRRADIANCE_MIN     = 250.0; // W/m² — irradiance must be strong for shading check
const float SHADING_IMBALANCE_RATIO    = 0.35;  // 35% drop on one string vs max string current
const float SOILING_IRRADIANCE_MIN     = 300.0; // W/m² — irradiance must be strong for soiling check
const float SOILING_POWER_RATIO_MIN    = 0.08;  // W per W/m² — min expected output (adjustable)

const unsigned long SENSOR_READ_INTERVAL     = 3000;
const unsigned long FIREBASE_UPLOAD_INTERVAL = 5000;
const unsigned long FAULT_DETECTION_INTERVAL = 2000;

// Time-based history logging interval (independent of change detection).
// Fires on a fixed clock so /pv_history gets an evenly spaced time series.
const unsigned long HISTORY_LOG_INTERVAL = 300000; // 5 minutes (adjust as needed)

unsigned long lastSensorReadTime     = 0;
unsigned long lastFirebaseUploadTime = 0;
unsigned long lastFaultDetectionTime = 0;
unsigned long lastHistoryLogTime     = 0;
unsigned long systemStartTime        = 0;

bool firebaseReady = false;
bool wifiConnected = false;

struct SensorData {
  float ambientTemp    = 0.0;
  float string1Temp    = 0.0;
  float string2Temp    = 0.0;
  float string1Voltage = 0.0;
  float string2Voltage = 0.0;
  float string1Current = 0.0;
  float string2Current = 0.0;
  float voltage        = 0.0;   // sum of strings if series
  float current        = 0.0;   // average of strings if parallel
  float irradiance     = 0.0;
};

struct FaultData {
  String systemStatus  = "NORMAL";
  String faultType     = "--";
  String faultLocation = "--";
  String recentAlert   = "No alerts yet.";
  unsigned long alertTimestamp = 0;
};

struct SystemMetrics {
  float dcPower          = 0.0;
  float systemEfficiency = 0.0;
};

SensorData    currentData;
SensorData    lastUploadedData;
FaultData     faultData;
FaultData     lastUploadedFault;
SystemMetrics metrics;

void initializeWiFi();
void reconnectWiFi();
void initializeFirebase();
void initializeTemperatureSensors();
void readAllSensors();
float readPyranometer();
void detectFaults();
void uploadToFirebase();
void logSensorData();
void logFaultDetection();
void logHistoryToFirebase();
void logAlertToFirebase(); // Alignment: Prototype declared

void setup() {
  Serial.begin(115200);
  delay(500);

  WiFi.setTxPower(WIFI_POWER_8_5dBm); 

  Serial.println("\n========================================");
  Serial.println("  RASID — PV MONITORING SYSTEM");
  Serial.println("  Temp + Voltage + Current + Pyranometer");
  Serial.println("========================================");

  Wire.begin(); // SDA = GPIO 21, SCL = GPIO 22

  if (!ads1.begin(0x48)) {
    Serial.println("FATAL: ADS1115 at 0x48 not found. Check wiring.");
    while (1) { delay(700); }
  }
  ads1.setGain(GAIN_ONE);
  Serial.println("ADS1115 (0x48) initialized — GAIN_ONE");

  if (!ads2.begin(0x49)) {
    Serial.println("FATAL: ADS1115 at 0x49 not found. Check wiring.");
    while (1) { delay(700); }
  }
  ads2.setGain(GAIN_ONE);
  Serial.println("ADS1115 (0x49) initialized — GAIN_ONE");

  initializeTemperatureSensors();
  initializeWiFi();

  configTime(0, 0, "pool.ntp.org", "time.nist.gov");
  Serial.println("Waiting for NTP time sync...");
  delay(1000);

  initializeFirebase();

  systemStartTime = millis();

  // Prime the history timer so the first snapshot happens one full
  // interval after boot (not immediately, since sensors settle over time).
  lastHistoryLogTime = systemStartTime;

  Serial.println("Initialization complete!\n");
}

void loop() {
  unsigned long currentMillis = millis();

  if (!wifiConnected)
    reconnectWiFi();

  if (!firebaseReady && wifiConnected)
    initializeFirebase();

  if (currentMillis - lastSensorReadTime >= SENSOR_READ_INTERVAL) {
    readAllSensors();
    lastSensorReadTime = currentMillis;
  }

  if (currentMillis - lastFaultDetectionTime >= FAULT_DETECTION_INTERVAL) {
    detectFaults();
    lastFaultDetectionTime = currentMillis;
  }

  if (currentMillis - lastFirebaseUploadTime >= FIREBASE_UPLOAD_INTERVAL && firebaseReady) {
    uploadToFirebase();
    lastFirebaseUploadTime = currentMillis;
  }

  if (currentMillis - lastHistoryLogTime >= HISTORY_LOG_INTERVAL && firebaseReady) {
    logHistoryToFirebase();
    lastHistoryLogTime = currentMillis;
  }

  delay(100);
}

void initializeWiFi() {
  Serial.print("Connecting to WiFi: ");
  Serial.println(ssid);
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    wifiConnected = true;
    Serial.println("\nWiFi connected!");
    Serial.print("IP: "); Serial.println(WiFi.localIP());
  } else {
    wifiConnected = false;
    Serial.println("\nFailed to connect to WiFi.");
  }
}

void reconnectWiFi() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi disconnected. Reconnecting...");
    WiFi.disconnect();
    delay(500);
    WiFi.begin(ssid, password);

    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 10) {
      delay(500);
      Serial.print(".");
      attempts++;
    }

    wifiConnected = (WiFi.status() == WL_CONNECTED);
    if (wifiConnected) Serial.println("\nWiFi reconnected!");
  }
}

void initializeFirebase() {
  if (!wifiConnected) return;

  Serial.println("Initializing Firebase...");
  config.api_key                = FIREBASE_API_KEY;
  config.database_url           = FIREBASE_DATABASE_URL;
  config.token_status_callback  = tokenStatusCallback;
  config.timeout.serverResponse = 30 * 1000;
  auth.user.email    = "";
  auth.user.password = "";

  Firebase.reconnectNetwork(true);
  Firebase.begin(&config, &auth);
  Firebase.signUp(&config, &auth, "", "");

  Serial.print("Waiting for Firebase authentication");
  int attempts = 0;
  while (!Firebase.ready() && attempts < 30) {
    Serial.print(".");
    delay(500);
    attempts++;
  }

  firebaseReady = Firebase.ready();
  Serial.println(firebaseReady ? "\n✓ Firebase ready!" : "\n⚠ Firebase not ready — will retry");
}

//Temperature Sensors
void initializeTemperatureSensors() {
  Serial.println("Initializing DS18B20 sensors...");

  sensor1.begin();
  sensor2.begin();
  sensor3.begin();

  Serial.printf("  GPIO %d  (D33)  → ambientTemp  | found: %d\n",
                SENSOR1_PIN, sensor1.getDeviceCount());
  Serial.printf("  GPIO %d (D25) → string1Temp  | found: %d\n",
                SENSOR2_PIN, sensor2.getDeviceCount());
  Serial.printf("  GPIO %d (D26) → string2Temp  | found: %d\n",
                SENSOR3_PIN, sensor3.getDeviceCount());

  if (sensor1.getDeviceCount() < 1) Serial.println("WARNING: No sensor on GPIO 33!");
  if (sensor2.getDeviceCount() < 1) Serial.println("WARNING: No sensor on GPIO 25!");
  if (sensor3.getDeviceCount() < 1) Serial.println("WARNING: No sensor on GPIO 26!");

  sensor1.setResolution(12);
  sensor2.setResolution(12);
  sensor3.setResolution(12);
}

void readAllSensors() {

  sensor1.requestTemperatures();
  sensor2.requestTemperatures();
  sensor3.requestTemperatures();

  float t0 = sensor1.getTempCByIndex(0);
  float t1 = sensor2.getTempCByIndex(0);
  float t2 = sensor3.getTempCByIndex(0);

  currentData.ambientTemp = (t0 == DEVICE_DISCONNECTED_C) ? 0.0 : t0;
  currentData.string1Temp = (t1 == DEVICE_DISCONNECTED_C) ? 0.0 : t1;
  currentData.string2Temp = (t2 == DEVICE_DISCONNECTED_C) ? 0.0 : t2;


//Voltage Sensors
  int16_t rawV1 = ads2.readADC_SingleEnded(0);
  int16_t rawV2 = ads2.readADC_SingleEnded(1);

  float adcV1 = ads2.computeVolts(rawV1);
  float adcV2 = ads2.computeVolts(rawV2);

  currentData.string1Voltage = adcV1 * Voltage_DIVIDER_RATIO;
  currentData.string2Voltage = adcV2 * Voltage_DIVIDER_RATIO;

  currentData.voltage = currentData.string1Voltage + currentData.string2Voltage;
  
//Current Sensors
  long rawSum1 = 0;
  for (int i = 0; i < NUM_SAMPLES; i++)
  {
      rawSum1 += ads1.readADC_SingleEnded(0);
      delay(2);
  }

  int16_t rawI1 = rawSum1 / NUM_SAMPLES;

  long rawSum2 = 0;
  for (int i = 0; i < NUM_SAMPLES; i++)
  {
      rawSum2 += ads1.readADC_SingleEnded(1);
      delay(2);
  }

  int16_t rawI2 = rawSum2 / NUM_SAMPLES;
  
  float adcI1_V = ads1.computeVolts(rawI1);
  float adcI2_V = ads1.computeVolts(rawI2);

  float WCS1800_1_Voltage = adcI1_V / WCS1800_DIVIDER_RATIO;
  float WCS1800_2_Voltage = adcI2_V / WCS1800_DIVIDER_RATIO;

  currentData.string1Current = (WCS1800_1_Voltage - WCS1800_Zero_C_0) / WCS1800_SENSITIVITY_V;
  currentData.string2Current = (WCS1800_2_Voltage - WCS1800_Zero_C_1) / WCS1800_SENSITIVITY_V;

  if ((currentData.string1Current) < 0) currentData.string1Current = 0.0;
  if ((currentData.string2Current) < 0) currentData.string2Current = 0.0;

  currentData.current = (currentData.string1Current + currentData.string2Current);

  currentData.irradiance = readPyranometer();

  // Alignment: Compute actual DC power as the sum of power from both strings
  metrics.dcPower = (currentData.string1Voltage * currentData.string1Current) + 
                    (currentData.string2Voltage * currentData.string2Current);

  logSensorData();
}


//Pyranometer
float readPyranometer() {
  int16_t rawPyr = ads2.readADC_Differential_2_3();
  float pyrVoltage = ads2.computeVolts(rawPyr);

  float irradiance = pyrVoltage / PYRANOMETER_SENSITIVITY_V;
  if (irradiance < 0.0)    irradiance = 0.0;
  if (irradiance > 1500.0) irradiance = 1500.0;

  Serial.printf("[Pyranometer] Raw: %d | Voltage: %.6f V | Irradiance: %.2f W/m²\n", rawPyr, pyrVoltage, irradiance);
  return irradiance;
}

void detectFaults() {
  String newStatus        = "NORMAL";
  String newFaultType     = "--";
  String newFaultLocation = "--";
  String newAlert         = "No alerts yet.";

  // ── Rule 1: Critical temperature → FAULT ──
  if (currentData.ambientTemp > TEMP_CRITICAL) {
    newStatus = "FAULT"; newFaultType = "Critical Temperature"; newFaultLocation = "Ambient";
    newAlert  = "Ambient temp critical (" + String(currentData.ambientTemp, 1) + " °C)";
  }
  if (currentData.string1Temp > TEMP_CRITICAL) {
    newStatus = "FAULT"; newFaultType = "Critical Temperature"; newFaultLocation = "String 1";
    newAlert  = "String 1 temp critical (" + String(currentData.string1Temp, 1) + " °C)";
  }
  if (currentData.string2Temp > TEMP_CRITICAL) {
    newStatus = "FAULT"; newFaultType = "Critical Temperature"; newFaultLocation = "String 2";
    newAlert  = "String 2 temp critical (" + String(currentData.string2Temp, 1) + " °C)";
  }

  // ── Rule 2: Warning temperature (only if no FAULT yet) ──
  if (newStatus != "FAULT") {
    if (currentData.ambientTemp > TEMP_WARNING) {
      newStatus = "WARNING"; newFaultType = "High Temperature"; newFaultLocation = "Ambient";
      newAlert  = "Ambient temp warning (" + String(currentData.ambientTemp, 1) + " °C)";
    }
    if (currentData.string1Temp > TEMP_WARNING) {
      newStatus = "WARNING"; newFaultType = "High Temperature"; newFaultLocation = "String 1";
      newAlert  = "String 1 temp warning (" + String(currentData.string1Temp, 1) + " °C)";
    }
    if (currentData.string2Temp > TEMP_WARNING) {
      newStatus = "WARNING"; newFaultType = "High Temperature"; newFaultLocation = "String 2";
      newAlert  = "String 2 temp warning (" + String(currentData.string2Temp, 1) + " °C)";
    }
  }

  // ── Rule 3: Overvoltage / low voltage ──
  if (currentData.voltage > VOLTAGE_MAX) {
    newStatus = "FAULT"; newFaultType = "Overvoltage"; newFaultLocation = "System";
    newAlert  = "System voltage exceeds max (" + String(currentData.voltage, 1) + " V)";
  }
  if (currentData.voltage > 0.0 && currentData.voltage < VOLTAGE_MIN && newStatus != "FAULT") {
    newStatus = "WARNING"; newFaultType = "Low Voltage"; newFaultLocation = "System";
    newAlert  = "System voltage below min (" + String(currentData.voltage, 1) + " V)";
  }

  // ── Rule 4: Overcurrent ──
  if (currentData.string1Current > CURRENT_MAX || currentData.string2Current > CURRENT_MAX) {
    newStatus = "FAULT"; newFaultType = "Overcurrent"; newFaultLocation = "Strings";
    newAlert  = "String current exceeds max (" + String(CURRENT_MAX, 0) + " A)";
  }

  // ── Rule 5: String temperature imbalance (only if no FAULT yet) ──
  if (newStatus != "FAULT") {
    float tempDiff = abs(currentData.string1Temp - currentData.string2Temp);
    if (tempDiff > TEMP_IMBALANCE_DELTA) {
      newStatus = "WARNING"; newFaultType = "Temperature Imbalance"; newFaultLocation = "Strings";
      newAlert  = "String temp imbalance: " + String(tempDiff, 1) +
                  " °C diff (S1=" + String(currentData.string1Temp, 1) +
                  " S2=" + String(currentData.string2Temp, 1) + " °C)";
    }
  }

  // ── Rule 6: Abnormal temp rise above ambient (hotspot) ──
  if (newStatus != "FAULT" && currentData.ambientTemp > 0.0) {
    float rise1 = currentData.string1Temp - currentData.ambientTemp;
    float rise2 = currentData.string2Temp - currentData.ambientTemp;
    if (rise1 > TEMP_RISE_THRESHOLD) {
      newStatus = "WARNING"; newFaultType = "Abnormal Temp Rise"; newFaultLocation = "String 1";
      newAlert  = "String 1 is " + String(rise1, 1) + " °C above ambient — possible hotspot";
    }
    if (rise2 > TEMP_RISE_THRESHOLD && newStatus != "FAULT") {
      newStatus = "WARNING"; newFaultType = "Abnormal Temp Rise"; newFaultLocation = "String 2";
      newAlert  = "String 2 is " + String(rise2, 1) + " °C above ambient — possible hotspot";
    }
  }

  // ── Rule 7: Voltage imbalance between strings ──
  if (newStatus != "FAULT") {
    float vDiff = abs(currentData.string1Voltage - currentData.string2Voltage);
    if (currentData.voltage > 0.0 && vDiff > (currentData.voltage * 0.15)) {
      newStatus = "WARNING"; newFaultType = "Voltage Imbalance"; newFaultLocation = "Strings";
      newAlert  = "String voltage imbalance: " + String(vDiff, 1) + " V diff";
    }
  }

  // ── Rule 8: Current imbalance between strings ──
  if (newStatus != "FAULT") {
    float iDiff = abs(currentData.string1Current - currentData.string2Current);
    if (currentData.current > 0.0 && iDiff > (currentData.current * 0.20)) {
      newStatus = "WARNING"; newFaultType = "Current Imbalance"; newFaultLocation = "Strings";
      newAlert  = "String current imbalance: " + String(iDiff, 2) + " A diff";
    }
  }

  // ── Rule 9: Open circuit (voltage present, no current, good irradiance) ──
  if (currentData.voltage > 10.0 &&
      currentData.current < 0.1 &&
      currentData.irradiance > 200.0) {
    newStatus = "FAULT"; newFaultType = "Open Circuit"; newFaultLocation = "System";
    newAlert  = "Open circuit — no current at " +
                String(currentData.irradiance, 1) + " W/m²";
  }

  // ── Rule 10: Low irradiance ──
  if (currentData.irradiance > 0.0 &&
      currentData.irradiance < IRRADIANCE_MIN &&
      newStatus == "NORMAL") {
    newStatus = "WARNING"; newFaultType = "Low Irradiance"; newFaultLocation = "Environment";
    newAlert  = "Irradiance below minimum (" + String(currentData.irradiance, 1) + " W/m²)";
  }

  // ── Rule 11: Sensor disconnected (only if still NORMAL) ──
  if (currentData.ambientTemp == 0.0 && newStatus == "NORMAL") {
    newStatus = "WARNING"; newFaultType = "Sensor Fault"; newFaultLocation = "Ambient (GPIO 33)";
    newAlert  = "Ambient temp sensor disconnected or reading 0";
  }
  if (currentData.string1Temp == 0.0 && newStatus == "NORMAL") {
    newStatus = "WARNING"; newFaultType = "Sensor Fault"; newFaultLocation = "String 1 (GPIO 25)";
    newAlert  = "String 1 temp sensor disconnected or reading 0";
  }
  if (currentData.string2Temp == 0.0 && newStatus == "NORMAL") {
    newStatus = "WARNING"; newFaultType = "Sensor Fault"; newFaultLocation = "String 2 (GPIO 26)";
    newAlert  = "String 2 temp sensor disconnected or reading 0";
  }

  // ── Rule 12: Short Circuit ──
  // Voltage collapses near zero while current is still flowing under irradiance.
  // Distinct from open circuit: open = voltage OK but no current; short = no voltage but current.
  if (currentData.voltage < SHORT_CIRCUIT_VOLTAGE &&
      currentData.current > SHORT_CIRCUIT_CURRENT_MIN &&
      currentData.irradiance > IRRADIANCE_MIN) {
    newStatus = "FAULT"; newFaultType = "Short Circuit"; newFaultLocation = "System";
    newAlert  = "Short circuit suspected — voltage collapsed to " +
                String(currentData.voltage, 2) + " V with " +
                String(currentData.current, 2) + " A flowing";
  }

  // ── Rule 13: Hotspot (dedicated, higher threshold than Rule 6 early warning) ──
  // A string temp exceeding ambient by 25°C+ indicates localised cell heating (hotspot).
  if (newStatus != "FAULT" && currentData.ambientTemp > 0.0) {
    float rise1 = currentData.string1Temp - currentData.ambientTemp;
    float rise2 = currentData.string2Temp - currentData.ambientTemp;
    if (rise1 > HOTSPOT_RISE_THRESHOLD) {
      newStatus = "FAULT"; newFaultType = "Hotspot"; newFaultLocation = "String 1";
      newAlert  = "Hotspot on String 1: " + String(rise1, 1) +
                  " °C above ambient (" + String(currentData.string1Temp, 1) + " °C)";
    }
    if (rise2 > HOTSPOT_RISE_THRESHOLD && newStatus != "FAULT") {
      newStatus = "FAULT"; newFaultType = "Hotspot"; newFaultLocation = "String 2";
      newAlert  = "Hotspot on String 2: " + String(rise2, 1) +
                  " °C above ambient (" + String(currentData.string2Temp, 1) + " °C)";
    }
  }

  // ── Rule 14: Partial Shading ──
  // Under strong irradiance, one string produces significantly less current than the other.
  // This asymmetric current drop is a key signature of partial shading.
  if (newStatus != "FAULT" && currentData.irradiance > SHADING_IRRADIANCE_MIN) {
    float maxI = max(currentData.string1Current, currentData.string2Current);
    float iDiffShading = abs(currentData.string1Current - currentData.string2Current);
    if (maxI > 0.5 && iDiffShading > (maxI * SHADING_IMBALANCE_RATIO)) {
      String shadedStr = (currentData.string1Current < currentData.string2Current) ? "String 1" : "String 2";
      newStatus = "WARNING"; newFaultType = "Partial Shading"; newFaultLocation = shadedStr;
      newAlert  = "Partial shading likely on " + shadedStr +
                  " — current drop: " + String(iDiffShading, 2) +
                  " A at " + String(currentData.irradiance, 1) + " W/m\u00b2";
    }
  }

  // ── Rule 15: Soiling / Dust ──
  // Under strong irradiance the system DC power output is disproportionately low.
  // Power ratio = dcPower / irradiance (W output per W/m² received).
  // Adjust SOILING_POWER_RATIO_MIN based on your panel area and STC efficiency.
  if (newStatus == "NORMAL" && currentData.irradiance > SOILING_IRRADIANCE_MIN) {
    float powerRatio = metrics.dcPower / currentData.irradiance;
    if (powerRatio < SOILING_POWER_RATIO_MIN && metrics.dcPower > 0.0) {
      newStatus = "WARNING"; newFaultType = "Soiling / Dust"; newFaultLocation = "Panels";
      newAlert  = "Low power-to-irradiance ratio (" + String(powerRatio, 3) +
                  " W/W/m\u00b2) — possible dust or soiling on panels";
    }
  }

  // Only update if something changed
  if (newStatus != faultData.systemStatus || newFaultType != faultData.faultType) {
    faultData.systemStatus   = newStatus;
    faultData.faultType      = newFaultType;
    faultData.faultLocation  = newFaultLocation;
    faultData.recentAlert    = newAlert;
    faultData.alertTimestamp = time(nullptr);
    logFaultDetection();

    // Force an immediate time-based history entry whenever the fault
    // status/type changes, so short-lived faults that start and clear
    // between two periodic snapshots still get captured.
    if (firebaseReady && wifiConnected) {
      logHistoryToFirebase();
      if (newStatus == "FAULT" || newStatus == "WARNING") {
        logAlertToFirebase(); // Alignment: Log historical alert to Firebase RTDB path /pv_alerts
      }
      lastHistoryLogTime = millis();  // resets the periodic timer too
    }
  }
}

void uploadToFirebase() {
  if (!firebaseReady || !wifiConnected) {
    Serial.println("Firebase/WiFi not ready. Skipping upload.");
    return;
  }

  bool dataChanged =
    (currentData.ambientTemp    != lastUploadedData.ambientTemp    ||
     currentData.string1Temp    != lastUploadedData.string1Temp    ||
     currentData.string2Temp    != lastUploadedData.string2Temp    ||
     currentData.string1Voltage != lastUploadedData.string1Voltage ||
     currentData.string2Voltage != lastUploadedData.string2Voltage ||
     currentData.string1Current != lastUploadedData.string1Current ||
     currentData.string2Current != lastUploadedData.string2Current ||
     currentData.irradiance     != lastUploadedData.irradiance);

  bool faultChanged =
    (faultData.systemStatus != lastUploadedFault.systemStatus ||
     faultData.faultType    != lastUploadedFault.faultType);

  if (!dataChanged && !faultChanged) {
    Serial.println("No change — skipping Firebase upload.");
    return;
  }

  FirebaseJson json;

  json.set("ambient_temp",    currentData.ambientTemp);
  json.set("string1_temp",    currentData.string1Temp);
  json.set("string2_temp",    currentData.string2Temp);

  json.set("string1_voltage", currentData.string1Voltage);
  json.set("string2_voltage", currentData.string2Voltage);
  json.set("voltage",         currentData.voltage);

  json.set("string1_current", currentData.string1Current);
  json.set("string2_current", currentData.string2Current);
  json.set("current",         currentData.current);

  json.set("dc_power",        metrics.dcPower);

  json.set("irradiance",      currentData.irradiance);

  json.set("system_status",   faultData.systemStatus.c_str());
  json.set("fault_type",      faultData.faultType.c_str());
  json.set("fault_location",  faultData.faultLocation.c_str());
  json.set("recent_alert",    faultData.recentAlert.c_str());

  json.set("timestamp",       (unsigned long)time(nullptr));
  json.set("uptime_seconds",  (millis() - systemStartTime) / 1000);

  if (Firebase.RTDB.setJSON(&fbdo, "/pv_data", &json)) {
    Serial.println("✓ Firebase upload OK");
    lastUploadedData  = currentData;
    lastUploadedFault = faultData;
  } else {
    Serial.print("✗ Firebase upload failed: ");
    Serial.println(fbdo.errorReason().c_str());
  }
}

void logHistoryToFirebase() {
  if (!firebaseReady || !wifiConnected) {
    Serial.println("Firebase/WiFi not ready. Skipping history log.");
    return;
  }

  FirebaseJson json;

  json.set("ambient_temp",    currentData.ambientTemp);
  json.set("string1_temp",    currentData.string1Temp);
  json.set("string2_temp",    currentData.string2Temp);

  json.set("string1_voltage", currentData.string1Voltage);
  json.set("string2_voltage", currentData.string2Voltage);
  json.set("voltage",         currentData.voltage);

  json.set("string1_current", currentData.string1Current);
  json.set("string2_current", currentData.string2Current);
  json.set("current",         currentData.current);

  json.set("dc_power",        metrics.dcPower);

  json.set("irradiance",      currentData.irradiance);

  json.set("system_status",   faultData.systemStatus.c_str());
  json.set("fault_type",      faultData.faultType.c_str());
  json.set("fault_location",  faultData.faultLocation.c_str());
  json.set("recent_alert",    faultData.recentAlert.c_str());

  unsigned long ts = (unsigned long)time(nullptr);
  json.set("timestamp",       ts);
  json.set("uptime_seconds",  (millis() - systemStartTime) / 1000);

  String histPath = "/pv_history/" + String(ts);
  if (Firebase.RTDB.setJSON(&fbdo, histPath.c_str(), &json)) {
    Serial.printf("✓ Time-based history entry saved (every %lu min) at %s\n",
                  HISTORY_LOG_INTERVAL / 60000, histPath.c_str());
  } else {
    Serial.print("✗ History write failed: ");
    Serial.println(fbdo.errorReason().c_str());
  }
}

// Alignment: Write alert record to historical /pv_alerts log when triggered
void logAlertToFirebase() {
  if (!firebaseReady || !wifiConnected) {
    Serial.println("Firebase/WiFi not ready. Skipping alert log.");
    return;
  }

  FirebaseJson json;

  json.set("fault_type",      faultData.faultType.c_str());
  json.set("fault_location",  faultData.faultLocation.c_str());
  json.set("recent_alert",    faultData.recentAlert.c_str());

  unsigned long ts = (unsigned long)time(nullptr);
  json.set("timestamp",       ts);

  String alertPath = "/pv_alerts/" + String(ts);
  if (Firebase.RTDB.setJSON(&fbdo, alertPath.c_str(), &json)) {
    Serial.printf("✓ Alert entry saved at %s\n", alertPath.c_str());
  } else {
    Serial.print("✗ Alert write failed: ");
    Serial.println(fbdo.errorReason().c_str());
  }
}

void logSensorData() {
  Serial.println("\n--- SENSOR DATA ---");
  Serial.printf("Ambient: %.1f °C | String1: %.1f °C | String2: %.1f °C\n",
                currentData.ambientTemp, currentData.string1Temp, currentData.string2Temp);
  Serial.printf("String1 [V: %.2f V | I: %.2f A]  String2 [V: %.2f V | I: %.2f A]\n",
                currentData.string1Voltage, currentData.string1Current,
                currentData.string2Voltage, currentData.string2Current);
  Serial.printf("System  [V: %.2f V | I: %.2f A | P: %.1f W]\n",
                currentData.voltage, currentData.current, metrics.dcPower);
  Serial.printf("Irradiance: %.1f W/m²\n", currentData.irradiance);
}

void logFaultDetection() {
  Serial.println("\n### FAULT DETECTION ###");
  Serial.printf("Status: %s  |  Fault: %s  |  Location: %s\n",
                faultData.systemStatus.c_str(),
                faultData.faultType.c_str(),
                faultData.faultLocation.c_str());
  Serial.print("Alert: ");
  Serial.println(faultData.recentAlert);
}
