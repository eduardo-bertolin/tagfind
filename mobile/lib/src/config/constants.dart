/// App-wide constants — centralised so credentials live in one file.
class AppConstants {
  AppConstants._();

  // ── Supabase ──────────────────────────────────────────────────────────────
  static const String supabaseUrl =
      'https://kzlphhmyyxtujqcfgslr.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_4Zcucs4FqucvNfDcBlY5rw_v5KVjSrN';

  // ── BLE Advertising ───────────────────────────────────────────────────────
  /// Manufacturer Company ID used by the ESP32 firmware (0xFFFF = reserved).
  static const int bleCompanyId = 0xFFFF;

  /// Number of raw payload bytes after the 2-byte Company ID.
  static const int blePayloadLength = 6;

  // ── RSSI → distância ──────────────────────────────────────────────────────
  /// RSSI de referência a 1 m (default), medido para o TX power do firmware
  /// (`ESP_PWR_LVL_P9` = +9 dBm). Pode ser sobrescrito por tag via calibração
  /// do usuário (DistanceTracker.calibrate).
  static const double bleRefRssiAt1m = -59.0;

  /// Expoente de path-loss: 2.0 = espaço livre; 2.5–4.0 = ambiente interno.
  static const double blePathLossExponent = 2.5;

  /// Distância máxima exibida (acima disso o RSSI é considerado ruído).
  static const double maxDisplayDistance = 30.0;

  // ── Misc ───────────────────────────────────────────────────────────────────
  /// Minimum seconds between location updates sent for the same tag.
  static const int updateThrottleSeconds = 30;
}
