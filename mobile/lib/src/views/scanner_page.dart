import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../models/ble_advertisement.dart';
import '../providers/providers.dart';
import '../services/ble_service.dart';
import '../services/distance_estimator.dart';
import 'tag_detail_page.dart';

/// Second tab: BLE scanner with live feed of detected TagFind devices.
class ScannerPage extends ConsumerWidget {
  const ScannerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isScanning = ref.watch(bleScanningProvider);
    final sightings = ref.watch(recentSightingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner BLE'),
        actions: [
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.bolt_rounded, color: AppColors.amber),
              tooltip: 'Simular Tag (Debug)',
              onPressed: () async {
                if (!isScanning) {
                  await ref.read(bleScanningProvider.notifier).start();
                }
                BleService.instance.injectMockTag();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('⚡ Tag 0x0002 detectada!'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
            ),
          if (sightings.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Limpar lista',
              onPressed: () =>
                  ref.read(recentSightingsProvider.notifier).clear(),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Scan toggle banner ─────────────────────────────────────
          _ScanBanner(isScanning: isScanning),

          // ── Sightings list ─────────────────────────────────────────
          Expanded(
            child: sightings.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bluetooth_searching_rounded,
                          size: 64,
                          color: AppColors.amber.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isScanning
                              ? 'Procurando dispositivos TagFind…'
                              : 'Inicie o scanner para detectar tags.',
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: sightings.length,
                    itemBuilder: (_, i) {
                      final adv = sightings[i];
                      if (adv == null) {
                        // Segurança nula: pular entradas nulas (defesa extra).
                        return const SizedBox.shrink();
                      }
                      return _SightingTile(adv: adv);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final notifier = ref.read(bleScanningProvider.notifier);
          if (isScanning) {
            notifier.stop();
          } else {
            notifier.start();
          }
        },
        icon: Icon(isScanning ? Icons.stop_rounded : Icons.play_arrow_rounded),
        label: Text(isScanning ? 'Parar' : 'Iniciar Scan'),
        backgroundColor: isScanning ? AppColors.danger : AppColors.amber,
        foregroundColor: isScanning ? Colors.white : Colors.black,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Scan status banner
// ─────────────────────────────────────────────────────────────────────────────

class _ScanBanner extends StatelessWidget {
  final bool isScanning;
  const _ScanBanner({required this.isScanning});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: (isScanning ? AppColors.amber : AppColors.surface)
            .withValues(alpha: isScanning ? 0.1 : 1.0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isScanning
              ? AppColors.amber.withValues(alpha: 0.3)
              : AppColors.cardBorder,
        ),
      ),
      child: Row(
        children: [
          if (isScanning)
            const _PulsingDot()
          else
            const Icon(Icons.bluetooth_disabled_rounded,
                color: AppColors.textMuted, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isScanning
                  ? 'Escutando pacotes Advertising…'
                  : 'Scanner BLE inativo',
              style: TextStyle(
                color: isScanning ? AppColors.amber : AppColors.textMuted,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pulsing dot animation
// ─────────────────────────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.amber.withValues(alpha: 0.4 + _ctrl.value * 0.6),
          boxShadow: [
            BoxShadow(
              color: AppColors.amber.withValues(alpha: _ctrl.value * 0.5),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sighting list tile
// ─────────────────────────────────────────────────────────────────────────────

class _SightingTile extends StatelessWidget {
  final BleAdvertisement adv;
  const _SightingTile({required this.adv});

  @override
  Widget build(BuildContext context) {
    final distance = adv.distanceMeters;
    final trend = DistanceEstimator.instance.trend(adv.hexId);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TagDetailPage(tagId: adv.hexId),
            ),
          );
        },
        onLongPress: () => _calibrate(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
          children: [
            // Tag ID
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                adv.hexId,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.amber,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _InfoChip(
                        icon: Icons.battery_std_rounded,
                        label: '${adv.battery}%',
                        color: adv.isLowBattery
                            ? AppColors.danger
                            : AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      _InfoChip(
                        icon: Icons.near_me_rounded,
                        label: _formatDistance(distance),
                        color: _distanceColor(distance),
                      ),
                      if (trend != 0) ...[
                        const SizedBox(width: 8),
                        _InfoChip(
                          icon: trend == 1
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          label: trend == 1 ? 'Mais perto' : 'Mais longe',
                          color:
                              trend == 1 ? AppColors.success : AppColors.danger,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Modo: ${adv.energyModeLabel}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),

            // GPS sent indicator
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted, size: 22),
          ],
        ),
      ),
    ),
  );
  }

  /// Distância formatada para exibição (precisão honesta: 1 decimal < 10 m).
  String _formatDistance(double? distance) {
    if (distance == null) return '— m';
    if (distance >= 10) return '≈ ${distance.round()} m';
    return '≈ ${distance.toStringAsFixed(1)} m';
  }

  /// Cor por proximidade: verde = muito perto, âmbar = perto, cinza = longe.
  Color _distanceColor(double? distance) {
    if (distance == null) return AppColors.textMuted;
    if (distance < 1.5) return AppColors.success;
    if (distance < 6) return AppColors.amber;
    return AppColors.textMuted;
  }

  /// Calibrar a distância de referência assumindo que o usuário está a
  /// ~1 m da tag neste momento.
  Future<void> _calibrate(BuildContext context) async {
    await DistanceEstimator.instance.calibrate(
      adv.hexId,
      rssi: adv.rssi,
      realDistanceMeters: 1.0,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Calibrado: assumindo 1 m da tag agora.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small info chip
// ─────────────────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}
