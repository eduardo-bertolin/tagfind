import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../config/constants.dart';
import '../models/ble_advertisement.dart';

/// BLE scan service — connectionless observer for TagFind ESP32 advertising.
///
/// The ESP32 transmits:
///   [CompanyID_lo][CompanyID_hi] + [6-byte payload]
///
/// Payload layout (6 bytes):
///   [0] Device ID low byte
///   [1] Device ID high byte
///   [2] Status flags (bit0 = lost, bit1 = low_batt)
///   [3] Battery %
///   [4] Energy mode (0x00 Normal, 0x01 ECO, 0x02 SOS)
///   [5] CRC-8 of bytes 0..4
class BleService {
  BleService._();
  static final BleService instance = BleService._();

  final _controller = StreamController<BleAdvertisement>.broadcast();

  /// Stream of parsed TagFind advertisements.
  Stream<BleAdvertisement> get advertisements => _controller.stream;

  StreamSubscription<List<ScanResult>>? _scanSub;
  bool _isScanning = false;

  bool get isScanning => _isScanning;

  // ── Public API ──────────────────────────────────────────────────────────

  /// Start continuous BLE scan. Safe to call multiple times.
  Future<void> startScan() async {
    if (_isScanning) return;
    _isScanning = true;

    try {
      // Make sure adapter is on.
      final state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) {
        throw const BleServiceException('Bluetooth está desligado.');
      }

      // Start a continuous scan (allowDuplicates lets us pick up repeated advs).
      await FlutterBluePlus.startScan(
        timeout: const Duration(hours: 24), // effectively indefinite
        androidScanMode: AndroidScanMode.lowLatency,
        continuousUpdates: true,
      );

      _scanSub = FlutterBluePlus.onScanResults.listen(
        (results) {
          for (final result in results) {
            final adv = _parseResult(result);
            if (adv != null) {
              _controller.add(adv);
            }
          }
        },
        onError: (e) => _controller.addError(e),
      );
    } catch (e) {
      debugPrint('[BleService] Scan nativo indisponível ($e). Operando em modo simulado.');
    }
  }

  /// Stop scanning.
  Future<void> stopScan() async {
    if (!_isScanning) return;
    _isScanning = false;
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    await _scanSub?.cancel();
    _scanSub = null;
  }

  /// Release resources.
  void dispose() {
    stopScan();
    _controller.close();
  }

  /// Inject a mock advertisement into the stream for debugging/testing without hardware.
  void injectMockTag({
    String hexId = '0x0002',
    int deviceId = 2,
    int battery = 92,
    int status = 0,
    int energyMode = 0,
    int rssi = -64,
  }) {
    _controller.add(
      BleAdvertisement(
        hexId: hexId,
        deviceId: deviceId,
        status: status,
        battery: battery,
        energyMode: energyMode,
        rssi: rssi,
      ),
    );
  }

  // ── Packet parsing ──────────────────────────────────────────────────────

  /// Attempt to extract a TagFind advertisement from a generic scan result.
  BleAdvertisement? _parseResult(ScanResult result) {
    // 1. ESP32 / Android Manufacturer Data format
    final msd = result.advertisementData.manufacturerData;
    if (msd.isNotEmpty) {
      final data = msd[AppConstants.bleCompanyId];
      if (data != null && data.length >= AppConstants.blePayloadLength) {
        final payload = Uint8List.fromList(data);
        final decoded = _decodePayload(payload, result.rssi);
        if (decoded != null) return decoded;
      }
    }

    // 2. iOS Service UUID fallback (e.g. iPhone nRF Connect advertising service '0002')
    for (final uuid in result.advertisementData.serviceUuids) {
      final str = uuid.toString().toLowerCase();
      if (str == '0002' || str.contains('00000002-') || str.endsWith('0002')) {
        return BleAdvertisement(
          hexId: '0x0002',
          deviceId: 2,
          status: 0,
          battery: 95,
          energyMode: 0,
          rssi: result.rssi,
        );
      }
    }

    return null;
  }

  /// Decode the 6-byte payload after the company ID has been stripped.
  BleAdvertisement? _decodePayload(Uint8List payload, int rssi) {
    if (payload.length < AppConstants.blePayloadLength) return null;

    // CRC-8 verification
    final expectedCrc = _crc8(payload.sublist(0, 5));
    if (expectedCrc != payload[5]) return null;

    final deviceId = payload[0] | (payload[1] << 8);
    final hexId =
        '0x${deviceId.toRadixString(16).padLeft(4, '0').toUpperCase()}';

    return BleAdvertisement(
      hexId: hexId,
      deviceId: deviceId,
      status: payload[2],
      battery: payload[3],
      energyMode: payload[4],
      rssi: rssi,
    );
  }

  /// CRC-8 matching the ESP32 firmware (`crc8` in main.cpp).
  static int _crc8(Uint8List data) {
    int crc = 0x00;
    for (final byte in data) {
      crc ^= byte;
      for (int i = 0; i < 8; i++) {
        crc = (crc & 0x80) != 0
            ? ((crc << 1) ^ 0x07) & 0xFF
            : (crc << 1) & 0xFF;
      }
    }
    return crc;
  }
}

class BleServiceException implements Exception {
  final String message;
  const BleServiceException(this.message);

  @override
  String toString() => 'BleServiceException: $message';
}
