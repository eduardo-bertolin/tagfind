import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  /// Throttle map: tagId → last GPS/Supabase push timestamp.
  final Map<String, DateTime> _lastGpsPush = {};

  Future<void> start() async {
    if (state) return;

    state = true;
    _lastGpsPush.clear();
    DistanceEstimator.instance.resetAll();

    await _sub?.cancel();
    _sub = BleService.instance.advertisements.listen((adv) async {
      // 1) Distância: cálculo local em cada pacote (suavizado via EWMA).
      final distance =
          await DistanceEstimator.instance.feed(adv.hexId, adv.rssi);

      // 2) Lista de sightings: upsert (mantém a posição estável na lista).
      _ref
          .read(recentSightingsProvider.notifier)
          .upsert(adv.copyWith(distanceMeters: distance));

      // 3) GPS/Supabase: throttle (custo de bateria/rede). A exibição da
      //    distância não depende disto — ela é 100% local.
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

  /// Substitui a sighting de uma tag já existente (mantendo a posição na
  /// lista) ou adiciona no topo se for nova.
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
