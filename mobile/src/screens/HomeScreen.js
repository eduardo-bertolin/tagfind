import { decodeManufacturerData } from "../ble/scanner";
import { reportSighting } from "../lib/supabase";

/**
 * Esqueleto da tela principal.
 * Conecte o scan BLE nativo e chame onAdvertisement() a cada pacote.
 */
export async function onAdvertisement(manufacturerBytes, { lat, lng, rssi }) {
  const ping = decodeManufacturerData(manufacturerBytes);
  if (!ping) {
    return null;
  }

  await reportSighting({
    tagId: ping.hexId,
    lat,
    lng,
    rssi,
    battery: ping.battery,
    status: ping.status,
  });

  return ping;
}

export default function HomeScreen() {
  return null;
}
