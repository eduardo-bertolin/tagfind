/**
 * BLE observing connectionless (sem GATT).
 * Integre com react-native-ble-plx ou expo-ble no scaffold do app.
 */

export const COMPANY_ID = 0xffff;

export function crc8(bytes) {
  let crc = 0x00;
  for (const value of bytes) {
    crc ^= value;
    for (let i = 0; i < 8; i++) {
      crc = (crc & 0x80) ? ((crc << 1) ^ 0x07) & 0xff : (crc << 1) & 0xff;
    }
  }
  return crc;
}

export function decodeManufacturerData(data) {
  if (!data || data.length < 8) {
    return null;
  }
  const company = data[0] | (data[1] << 8);
  if (company !== COMPANY_ID) {
    return null;
  }
  const payload = data.slice(2, 8);
  if (crc8(payload.slice(0, 5)) !== payload[5]) {
    return null;
  }
  const deviceId = payload[0] | (payload[1] << 8);
  return {
    deviceId,
    hexId: "0x" + deviceId.toString(16).padStart(4, "0").toUpperCase(),
    status: payload[2],
    battery: payload[3],
    energyMode: payload[4],
  };
}

export function isLostFlag(status) {
  return (status & 0x01) !== 0;
}
