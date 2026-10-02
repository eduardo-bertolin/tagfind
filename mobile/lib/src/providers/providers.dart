import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/constants.dart';
import '../models/ble_advertisement.dart';
import '../models/tag.dart';
import '../services/ble_service.dart';
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

  /// Register a new tag.
  Future<void> register(String tagId) async {
    await SupabaseService.instance.registerTag(tagId);
    await refresh();
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

  /// Throttle map: tagId → last update timestamp.
  final Map<String, DateTime> _lastUpdated = {};

  Future<void> start() async {
    if (state) return;

    state = true;
    _lastUpdated.clear();

    await _sub?.cancel();
    _sub = BleService.instance.advertisements.listen((adv) async {
      // Throttle: only update once every N seconds per tag.
      final now = DateTime.now();
      final last = _lastUpdated[adv.hexId];
      if (last != null &&
          now.difference(last).inSeconds <
              AppConstants.updateThrottleSeconds) {
        return;
      }
      _lastUpdated[adv.hexId] = now;

      // Append to recent sightings list.
      _ref.read(recentSightingsProvider.notifier).add(adv);

      // Silently push GPS location to Supabase.
      try {
        final position = await LocationService.instance.getCurrentPosition();
        if (position != null) {
          await SupabaseService.instance.updateLocation(
            adv.hexId,
            latitude: position.latitude,
            longitude: position.longitude,
          );
        }
      } catch (e) {
        // Ignored in desktop / mock test mode
      }
    });

    await BleService.instance.startScan();
  }

  Future<void> stop() async {
    await BleService.instance.stopScan();
    await _sub?.cancel();
    _sub = null;
    state = false;
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

  void clear() => state = [];
}
