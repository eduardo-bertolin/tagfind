/// Parsed result from a single BLE advertising packet.
class BleAdvertisement {
  /// 16-bit device ID in hex (e.g. '0x0002').
  final String hexId;

  /// Raw 16-bit numeric device ID.
  final int deviceId;

  /// Status byte from the firmware (bit 0 = lost flag from ESP32, bit 1 = low battery).
  final int status;

  /// Battery percentage reported by the ESP32 ADC.
  final int battery;

  /// Energy mode: 0x00 = NORMAL, 0x01 = ECO, 0x02 = SOS.
  final int energyMode;

  /// RSSI of the received packet (dBm).
  final int rssi;

  const BleAdvertisement({
    required this.hexId,
    required this.deviceId,
    required this.status,
    required this.battery,
    required this.energyMode,
    this.rssi = 0,
  });

  bool get isLowBattery => (status & 0x02) != 0;

  String get energyModeLabel {
    switch (energyMode) {
      case 0x01:
        return 'ECO';
      case 0x02:
        return 'SOS';
      default:
        return 'Normal';
    }
  }

  @override
  String toString() =>
      'BleAdvertisement($hexId, bat=$battery%, mode=$energyModeLabel, rssi=$rssi)';
}
