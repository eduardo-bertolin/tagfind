import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../models/ble_advertisement.dart';
import '../models/tag.dart';
import '../services/ble_service.dart';
import '../services/distance_estimator.dart';
import '../services/location_service.dart';
import '../services/supabase_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Tags list (Supabase)
// ─────────────────────────────────────────────────────────────────────────────

/// Async list of all tags from Supabase.
final tagsProvider =
    AsyncNotifierProvider<TagsNotifier, List<Tag>>(TagsNotifier.new);

class TagsNotifier extends AsyncNotifier<List<Tag>> {
  @override
  Future<List<Tag>> build() => SupabaseService.instance.fetchAllTags();

  /// Force a refresh from Supabase.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => SupabaseService.instance.fetchAllTags(),
    );
  }

  /// Toggle lost status of a tag and refresh the list.
  Future<void> toggleLost(Tag tag) async {
    await SupabaseService.instance.toggleLost(tag);
    await refresh();
  }

  /// Update contact info and refresh.
  Future<void> updateContact(
    String tagId, {
    required String mensagem,
    required String telefone,
  }) async {
    await SupabaseService.instance.updateContactInfo(
      tagId,
      mensagem: mensagem,
      telefone: telefone,
    );
    await refresh();
  }

  /// Update the display name and emoji.
  Future<void> updateNomeEmoji(
    String tagId, {
    required String nome,
    required String emoji,
  }) async {
    await SupabaseService.instance.updateNomeEmoji(
      tagId,
      nome: nome,
      emoji: emoji,
    );
    await refresh();
  }

  /// Register a new tag (from BLE scan flow).
  Future<void> register(String tagId, {String nome = '', String emoji = '📦'}) async {
    await SupabaseService.instance.registerTag(tagId, nome: nome, emoji: emoji);
    await refresh();
  }

  /// Securely unbind a tag:
  ///   1. Removes the OWNER_SECRET_KEY from local SharedPreferences.
  ///   2. Deletes the tag row from Supabase.
  ///   3. Refreshes the tag list.
  Future<void> unbindTag(String tagId) async {
    // Clear the local secret key.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('owner_key_$tagId');

    // Remove from Supabase.
    await SupabaseService.instance.unbindTag(tagId);
    await refresh();
  }

  /// Persist the OWNER_SECRET_KEY locally (received from server during first bind).
  Future<void> saveOwnerKey(String tagId, String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('owner_key_$tagId', key);
  }

  /// Retrieve the locally stored OWNER_SECRET_KEY for a given tag.
  Future<String?> getOwnerKey(String tagId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('owner_key_$tagId');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BLE Scanner State
// ─────────────────────────────────────────────────────────────────────────────

/// Whether the BLE scanner is currently active.
final bleScanningProvider =
    StateNotifierProvider<BleScanNotifier, bool>((ref) => BleScanNotifier(ref));

class BleScanNotifier extends StateNotifier<bool> {
  BleScanNotifier(this._ref) : super(false);

  final Ref _ref;
  StreamSubscription<BleAdvertisement>? _sub;

  /// Throttle map: tagId → last GPS/Supabase push timestamp.
  final Map<String, DateTime> _lastGpsPush = {};

  /// De-dup map for 0xFF alerts: tagId → last alert timestamp.
  final Map<String, DateTime> _lastAlertTime = {};

  Future<void> start() async {
    if (state) return;

    state = true;
    _lastGpsPush.clear();
    DistanceEstimator.instance.resetAll();

    await _sub?.cancel();
    _sub = BleService.instance.advertisements.listen((adv) async {
      // ── Security alert: status 0xFF (hard-reset attempt) ────────────────
      if (adv.isSecurityAlert) {
        _handleSecurityAlert(adv);
        return; // do not process further
      }

      // 1) Distance: local EWMA calculation per packet.
      final distance =
          await DistanceEstimator.instance.feed(adv.hexId, adv.rssi);

      // 2) Sightings list: upsert (keeps stable position in list).
      _ref
          .read(recentSightingsProvider.notifier)
          .upsert(adv.copyWith(distanceMeters: distance));

      // 3) GPS/Supabase: throttled (battery / network cost).
      final now = DateTime.now();
      final last = _lastGpsPush[adv.hexId];
      if (last == null ||
          now.difference(last).inSeconds >=
              AppConstants.updateThrottleSeconds) {
        _lastGpsPush[adv.hexId] = now;
        try {
          final position =
              await LocationService.instance.getCurrentPosition();
          if (position != null) {
            await SupabaseService.instance.updateLocation(
              adv.hexId,
              latitude: position.latitude,
              longitude: position.longitude,
            );
            _ref.read(tagsProvider.notifier).refresh();
          }
        } catch (e) {
          // Ignored in desktop / mock test mode
        }
      }
    });

    await BleService.instance.startScan();
  }

  Future<void> stop() async {
    await BleService.instance.stopScan();
    await _sub?.cancel();
    _sub = null;
    DistanceEstimator.instance.resetAll();
    state = false;
  }

  /// Handle a security alert (0xFF) received via BLE broadcast.
  /// Throttled to one alert per 60 s per tag to avoid Supabase spam.
  void _handleSecurityAlert(BleAdvertisement adv) {
    final now = DateTime.now();
    final last = _lastAlertTime[adv.hexId];
    if (last != null && now.difference(last).inSeconds < 60) return;

    _lastAlertTime[adv.hexId] = now;
    SupabaseService.instance.insertSecurityAlert(adv.hexId).catchError((_) {});

    // Notify UI via a dedicated provider.
    _ref.read(securityAlertsProvider.notifier).add(adv.hexId);
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recent BLE sightings (in-memory ring buffer)
// ─────────────────────────────────────────────────────────────────────────────

final recentSightingsProvider =
    StateNotifierProvider<RecentSightingsNotifier, List<BleAdvertisement>>(
  (_) => RecentSightingsNotifier(),
);

class RecentSightingsNotifier extends StateNotifier<List<BleAdvertisement>> {
  RecentSightingsNotifier() : super([]);

  static const _maxItems = 50;

  void add(BleAdvertisement adv) {
    state = [adv, ...state.take(_maxItems - 1)];
  }

  /// Substitutes an existing sighting for the same tag (stable position in
  /// the list) or adds at the top if new.
  void upsert(BleAdvertisement adv) {
    final index = state.indexWhere((a) => a.hexId == adv.hexId);
    if (index >= 0) {
      final next = [...state];
      next[index] = adv;
      state = next;
    } else {
      add(adv);
    }
  }

  void clear() => state = [];
}

// ─────────────────────────────────────────────────────────────────────────────
// Security Alerts (in-memory list of tag IDs that triggered 0xFF)
// ─────────────────────────────────────────────────────────────────────────────

/// List of tag IDs that have recently sent a 0xFF security alert.
final securityAlertsProvider =
    StateNotifierProvider<SecurityAlertsNotifier, List<String>>(
  (_) => SecurityAlertsNotifier(),
);

class SecurityAlertsNotifier extends StateNotifier<List<String>> {
  SecurityAlertsNotifier() : super([]);

  void add(String tagId) {
    if (!state.contains(tagId)) {
      state = [...state, tagId];
    }
  }

  void dismiss(String tagId) {
    state = state.where((id) => id != tagId).toList();
  }

  void clear() => state = [];
}
