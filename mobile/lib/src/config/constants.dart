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

  // ── Misc ───────────────────────────────────────────────────────────────────
  /// Minimum seconds between location updates sent for the same tag.
  static const int updateThrottleSeconds = 30;
}
