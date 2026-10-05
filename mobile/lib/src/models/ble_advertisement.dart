/// Parsed result from a single BLE advertising packet.
///
/// Payload layout — 6 bytes (Manufacturer Data, after the 2-byte Company ID):
///   [0] Status / Button  : 0x01 Normal | 0x02 Button pressed | 0xFF Hard-reset
///   [1] Battery level    : 0x00–0x64  (0–100%)
///   [2] Buzzer counter   : cumulative beep count
///   [3] Energy mode      : 0x01 Moving | 0x02 Idle/Sleep | 0x03 Lost mode
///   [4] Device ID low byte
///   [5] Device ID high byte
class BleAdvertisement {
  /// 16-bit device ID in hex (e.g. '0x0002').
  final String hexId;

  /// Raw 16-bit numeric device ID (bytes 4-5).
  final int deviceId;

  /// Status byte from the firmware:
  ///   0x01 = Normal
  ///   0x02 = Button pressed (short click)
  ///   0xFF = Hard-reset attempted (10 s hold)
  final int status;

  /// Battery percentage reported by the ESP32 ADC (0–100).
  final int battery;

  /// Cumulative buzzer activation counter (byte 2).
  final int buzzerCount;

  /// Energy mode:
  ///   0x01 = Moving  (pulse every 2–5 s)
  ///   0x02 = Idle    (pulse every 5 min, deep sleep)
  ///   0x03 = Lost    (pulse every 1 s, max power)
  final int energyMode;

  /// RSSI of the received packet (dBm).
  final int rssi;

  /// Estimated distance in metres (RSSI-smoothed → path-loss).
  /// `null` when not yet calculated.
  final double? distanceMeters;

  const BleAdvertisement({
    required this.hexId,
    required this.deviceId,
    required this.status,
    required this.battery,
    required this.energyMode,
    this.buzzerCount = 0,
    this.rssi = 0,
    this.distanceMeters,
  });

  BleAdvertisement copyWith({
    int? status,
    int? battery,
    int? buzzerCount,
    int? energyMode,
    int? rssi,
    double? distanceMeters,
  }) {
    return BleAdvertisement(
      hexId: hexId,
      deviceId: deviceId,
      status: status ?? this.status,
      battery: battery ?? this.battery,
      buzzerCount: buzzerCount ?? this.buzzerCount,
      energyMode: energyMode ?? this.energyMode,
      rssi: rssi ?? this.rssi,
      distanceMeters: distanceMeters ?? this.distanceMeters,
    );
  }

  /// True when battery is below 20 %.
  bool get isLowBattery => battery < 20;

  /// True when the firmware sent the hard-reset alert byte (0xFF).
  bool get isSecurityAlert => status == 0xFF;

  /// True when the user physically pressed the button.
  bool get isButtonPressed => status == 0x02;

  /// Human-readable energy mode label.
  String get energyModeLabel {
    switch (energyMode) {
      case 0x01:
        return 'Movimento';
      case 0x02:
        return 'Repouso';
      case 0x03:
        return 'Modo Perda';
      default:
        return 'Normal';
    }
  }

  @override
  String toString() =>
      'BleAdvertisement($hexId, bat=$battery%, mode=$energyModeLabel, rssi=$rssi, buzzer=$buzzerCount)';
}
