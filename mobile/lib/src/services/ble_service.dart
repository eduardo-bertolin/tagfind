import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:win_ble/win_ble.dart';

import '../config/constants.dart';
import '../models/ble_advertisement.dart';

/// BLE scan service — connectionless observer for TagFind ESP32 advertising.
///
/// Supports:
/// - Windows: Native WinBle via WinRT BLE
/// - Android / iOS: flutter_blue_plus
///
/// Payload layout (6 bytes after the 2-byte Company ID):
///   [0] Status         : 0x01 Normal | 0x02 Button pressed | 0xFF Hard-reset
///   [1] Battery %      : 0x00–0x64 (0–100)
///   [2] Buzzer counter : cumulative beep count
///   [3] Energy mode    : 0x01 Moving | 0x02 Idle | 0x03 Lost
///   [4] Device ID low byte
///   [5] Device ID high byte
class BleService {
  BleService._();
  static final BleService instance = BleService._();

  final _controller = StreamController<BleAdvertisement>.broadcast();

  /// Stream of parsed TagFind advertisements.
  Stream<BleAdvertisement> get advertisements => _controller.stream;

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BleDevice>? _winScanSub;
  bool _isScanning = false;

  bool get isScanning => _isScanning;

  // ── Public API ──────────────────────────────────────────────────────────

  /// Start continuous BLE scan. Safe to call multiple times.
  Future<void> startScan() async {
    if (_isScanning) return;
    _isScanning = true;

    // ── Windows Desktop Native BLE ─────────────────────────────────────────
    if (Platform.isWindows) {
      try {
        WinBle.startScanning();
        _winScanSub = WinBle.scanStream.listen(
          (device) {
            final adv = _parseWinBleDevice(device);
            if (adv != null) {
              _controller.add(adv);
            }
          },
          onError: (e) => debugPrint('[WinBle] Scan error: $e'),
        );
      } catch (e) {
        debugPrint('[WinBle] Start scanning error: $e');
      }
      return;
    }

    // ── Android / iOS Native BLE ───────────────────────────────────────────
    try {
      // Make sure adapter is on.
      final state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) {
        throw const BleServiceException('Bluetooth está desligado.');
      }

      // Start a continuous scan (continuousUpdates lets us pick up repeated advs).
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
      debugPrint('[BleService] Scan nativo indisponível ($e).');
    }
  }

  /// Stop scanning.
  Future<void> stopScan() async {
    if (!_isScanning) return;
    _isScanning = false;

    if (Platform.isWindows) {
      try {
        WinBle.stopScanning();
      } catch (_) {}
      await _winScanSub?.cancel();
      _winScanSub = null;
      return;
    }

    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    await _scanSub?.cancel();
    _scanSub = null;
  }

  /// Release resources.
  void dispose() {
    stopScan();
    _winScanSub?.cancel();
    _controller.close();
  }

  /// Inject a mock advertisement into the stream for debugging/testing without hardware.
  void injectMockTag({
    String hexId = '0x0002',
    int deviceId = 2,
    int status = 0x01,
    int battery = 92,
    int buzzerCount = 3,
    int energyMode = 0x01,
    int rssi = -64,
  }) {
    _controller.add(
      BleAdvertisement(
        hexId: hexId,
        deviceId: deviceId,
        status: status,
        battery: battery,
        buzzerCount: buzzerCount,
        energyMode: energyMode,
        rssi: rssi,
      ),
    );
  }

  /// Inject a mock security alert (0xFF) for testing the violation detection.
  void injectSecurityAlert({String hexId = '0x0002', int deviceId = 2}) {
    _controller.add(
      BleAdvertisement(
        hexId: hexId,
        deviceId: deviceId,
        status: 0xFF,
        battery: 80,
        buzzerCount: 0,
        energyMode: 0x01,
        rssi: -60,
      ),
    );
  }

  // ── Packet parsing ──────────────────────────────────────────────────────

  /// Windows BleDevice parser.
  BleAdvertisement? _parseWinBleDevice(BleDevice device) {
    final rssi = int.tryParse(device.rssi) ?? -70;

    // 1. ESP32 Manufacturer Data format (Company ID = 2 bytes, then 6-byte payload)
    final msd = device.manufacturerData;
    if (msd.length >= 8) {
      final companyId = msd[0] | (msd[1] << 8);
      if (companyId == AppConstants.bleCompanyId) {
        final payload = Uint8List.fromList(msd.sublist(2, 8));
        final adv = _decodePayload(payload, rssi);
        if (adv != null) return adv;
      }
    }

    // 2. iOS Service UUID fallback
    for (final uuid in device.serviceUuids) {
      final str = uuid.toString().toLowerCase();
      if (str == '0002' || str.contains('00000002-') || str.endsWith('0002')) {
        return BleAdvertisement(
          hexId: '0x0002',
          deviceId: 2,
          status: 0x01,
          battery: 95,
          buzzerCount: 0,
          energyMode: 0x01,
          rssi: rssi,
        );
      }
    }

    return null;
  }

  /// Attempt to extract a TagFind advertisement from a generic scan result (Android/iOS).
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

    // 2. iOS Service UUID fallback
    for (final uuid in result.advertisementData.serviceUuids) {
      final str = uuid.toString().toLowerCase();
      if (str == '0002' || str.contains('00000002-') || str.endsWith('0002')) {
        return BleAdvertisement(
          hexId: '0x0002',
          deviceId: 2,
          status: 0x01,
          battery: 95,
          buzzerCount: 0,
          energyMode: 0x01,
          rssi: result.rssi,
        );
      }
    }

    return null;
  }

  /// Decode the 6-byte payload after the Company ID has been stripped.
  ///
  /// Byte mapping per spec:
  ///   [0] Status / Button
  ///   [1] Battery %
  ///   [2] Buzzer counter
  ///   [3] Energy mode
  ///   [4] Device ID low byte
  ///   [5] Device ID high byte
  BleAdvertisement? _decodePayload(Uint8List payload, int rssi) {
    if (payload.length < AppConstants.blePayloadLength) return null;

    final statusByte  = payload[0]; // 0x01 | 0x02 | 0xFF
    final battery     = payload[1]; // 0–100
    final buzzerCount = payload[2]; // cumulative
    final energyMode  = payload[3]; // 0x01 | 0x02 | 0x03
    final deviceId    = payload[4] | (payload[5] << 8);
    final hexId =
        '0x${deviceId.toRadixString(16).padLeft(4, '0').toUpperCase()}';

    return BleAdvertisement(
      hexId: hexId,
      deviceId: deviceId,
      status: statusByte,
      battery: battery,
      buzzerCount: buzzerCount,
      energyMode: energyMode,
      rssi: rssi,
    );
  }

  /// CRC-8 matching the ESP32 firmware (`crc8` in main.cpp).
  static int crc8(Uint8List data) {
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
