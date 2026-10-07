#include <Arduino.h>
#include <NimBLEDevice.h>

// Device ID de 16 bits (sobrescreva com -DTAG_DEVICE_ID no platformio.ini)
#ifndef TAG_DEVICE_ID
#define TAG_DEVICE_ID 0x0001
#endif

static const uint16_t COMPANY_ID = 0xFFFF;
static const uint8_t ENERGY_MOVING = 0x01;
static const uint8_t ENERGY_IDLE = 0x02;
static const uint8_t ENERGY_LOST = 0x03;

static const uint32_t ADV_DURATION_MS = 200;
static const uint64_t SLEEP_US = 8ULL * 1000000ULL; // 8 s entre bursts

static uint8_t crc8(const uint8_t *data, size_t len) {
  uint8_t crc = 0x00;
  for (size_t i = 0; i < len; i++) {
    crc ^= data[i];
    for (uint8_t b = 0; b < 8; b++) {
      crc = (crc & 0x80) ? (uint8_t)((crc << 1) ^ 0x07) : (uint8_t)(crc << 1);
    }
  }
  return crc;
}

static uint8_t readBatteryPercent() {
  // Placeholder: mapear ADC da alimentação quando o hardware estiver definido.
  return 87;
}

static uint8_t buildStatus(uint8_t battery) {
  uint8_t status = 0;
  if (battery < 20) {
    status |= 0x02; // LOW_BATT
  }
  return status;
}

void setup() {
  Serial.begin(115200);
  delay(50);

  const uint8_t status = 0x01; // Normal (0x02 Botão, 0xFF Hard Reset)
  const uint8_t battery = readBatteryPercent();
  const uint8_t buzzerCount = 0; // Contador de bipes (placeholder)
  const uint8_t mode = ENERGY_MOVING; // 0x01 Movimento, 0x02 Repouso, 0x03 Perda

  uint8_t payload[6];
  payload[0] = status;              // Byte 0: Status
  payload[1] = battery;             // Byte 1: Bateria (0-100)
  payload[2] = buzzerCount;         // Byte 2: Contador de Bipes
  payload[3] = mode;                // Byte 3: Modo de Energia
  payload[4] = (uint8_t)(TAG_DEVICE_ID & 0xFF); // Byte 4: Device ID low
  payload[5] = (uint8_t)((TAG_DEVICE_ID >> 8) & 0xFF); // Byte 5: Device ID high

  NimBLEDevice::init("");
  NimBLEDevice::setPower(ESP_PWR_LVL_P9);

  NimBLEAdvertising *adv = NimBLEDevice::getAdvertising();
  NimBLEAdvertisementData advData;
  advData.setFlags(BLE_HS_ADV_F_DISC_GEN | BLE_HS_ADV_F_BREDR_UNSUP);
  advData.setManufacturerData(
      std::string(reinterpret_cast<const char *>(&COMPANY_ID), 2) +
      std::string(reinterpret_cast<const char *>(payload), sizeof(payload)));
  adv->setAdvertisementData(advData);
  adv->setMinInterval(32); // 20 ms
  adv->setMaxInterval(48); // 30 ms
  adv->start();

  delay(ADV_DURATION_MS);
  adv->stop();
  NimBLEDevice::deinit(true);

  esp_sleep_enable_timer_wakeup(SLEEP_US);
  esp_deep_sleep_start();
}

void loop() {
  // Unreachable: deep sleep reinicia em setup().
}
