
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/theme.dart';
import '../models/tag.dart';
import '../providers/providers.dart';

/// Detail / edit page for a single tag.
class TagDetailPage extends ConsumerStatefulWidget {
  final String tagId;
  const TagDetailPage({super.key, required this.tagId});

  @override
  ConsumerState<TagDetailPage> createState() => _TagDetailPageState();
}

class _TagDetailPageState extends ConsumerState<TagDetailPage> {
  late TextEditingController _msgCtrl;
  late TextEditingController _phoneCtrl;
  bool _saving = false;

  /// BLE pulse interval in seconds (1s – 600s / 10 min).
  double _intervalSeconds = 5.0;

  /// Whether dynamic energy mode is enabled.
  bool _dynamicMode = true;

  @override
  void initState() {
    super.initState();
    _msgCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Tag? _findTag(List<Tag> tags) {
    try {
      return tags.firstWhere((t) => t.id == widget.tagId);
    } catch (_) {
      return null;
    }
  }

  /// Estimate battery life in months based on the current pulse interval.
  ///
  /// Model:
  ///   CR2032 capacity  ≈ 220 mAh
  ///   TX active current ≈ 8 mA for ~5 ms per pulse
  ///   Deep sleep current ≈ 5 µA
  double _estimateAutonomyMonths(double intervalSeconds) {
    const double capacityMah = 220.0;
    const double txCurrentMa = 8.0;
    const double txDurationS = 0.005; // 5 ms per pulse
    const double sleepCurrentMa = 0.005; // 5 µA

    final txDutyCycle = txDurationS / intervalSeconds;
    final avgCurrentMa =
        txCurrentMa * txDutyCycle + sleepCurrentMa * (1 - txDutyCycle);

    // Hours of life = capacity / average current
    final hoursOfLife = capacityMah / avgCurrentMa;
    final months = hoursOfLife / (24 * 30);
    return months;
  }

  String _formatInterval(double seconds) {
    if (seconds < 60) return '${seconds.round()} s';
    final mins = (seconds / 60).round();
    return '$mins min';
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(widget.tagId)),
      body: tagsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.amber),
        ),
        error: (err, _) => Center(child: Text('Erro: $err')),
        data: (tags) {
          final tag = _findTag(tags);
          if (tag == null) {
            return const Center(child: Text('Tag não encontrada.'));
          }

          // Sync text fields only when they haven't been edited yet.
          if (_msgCtrl.text.isEmpty && tag.mensagem.isNotEmpty) {
            _msgCtrl.text = tag.mensagem;
          }
          if (_phoneCtrl.text.isEmpty && tag.telefone.isNotEmpty) {
            _phoneCtrl.text = tag.telefone;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Status banner ────────────────────────────────────────
                _StatusBanner(tag: tag),
                const SizedBox(height: 20),

                // ── Toggle lost button ───────────────────────────────────
                _ToggleLostButton(tag: tag),
                const SizedBox(height: 28),

                // ── BLE Frequency Slider ─────────────────────────────────
                _SectionTitle(
                    'Gerenciamento de Energia', Icons.bolt_rounded),
                const SizedBox(height: 14),
                _FrequencySliderCard(
                  intervalSeconds: _intervalSeconds,
                  dynamicMode: _dynamicMode,
                  autonomyMonths: _estimateAutonomyMonths(_intervalSeconds),
                  onIntervalChanged: (v) =>
                      setState(() => _intervalSeconds = v),
                  onDynamicToggled: (v) => setState(() => _dynamicMode = v),
                  formatInterval: _formatInterval,
                ),
                const SizedBox(height: 28),

                // ── Modo Perda rescue link ───────────────────────────────
                if (tag.isLost) ...[
                  _SectionTitle('Página de Resgate', Icons.public_rounded),
                  const SizedBox(height: 14),
                  _RescueLinkCard(tag: tag),
                  const SizedBox(height: 28),
                ],

                // ── Contact info section ─────────────────────────────────
                _SectionTitle('Informações de Resgate', Icons.message_outlined),
                const SizedBox(height: 14),

                TextField(
                  controller: _msgCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Mensagem pública',
                    hintText: 'Ex: Perdi minha mochila na FAG...',
                    prefixIcon: Icon(Icons.message_outlined),
                  ),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefone / WhatsApp',
                    hintText: '45999999999',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 20),

                ElevatedButton.icon(
                  onPressed: _saving ? null : () => _save(tag),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(_saving ? 'Salvando...' : 'Salvar alterações'),
                ),
                const SizedBox(height: 28),

                // ── Location info ────────────────────────────────────────
                if (tag.latitude != null && tag.longitude != null) ...[
                  _SectionTitle(
                      'Última Localização', Icons.location_on_outlined),
                  const SizedBox(height: 14),
                  _LocationCard(tag: tag),
                ],
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _save(Tag tag) async {
    setState(() => _saving = true);
    try {
      await ref.read(tagsProvider.notifier).updateContact(
            tag.id,
            mensagem: _msgCtrl.text.trim(),
            telefone: _phoneCtrl.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Salvo com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section title helper
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle(this.title, this.icon);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.amber),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.textMuted,
                letterSpacing: 0.8,
                fontSize: 11,
              ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BLE Frequency Slider Card
// ─────────────────────────────────────────────────────────────────────────────

class _FrequencySliderCard extends StatelessWidget {
  final double intervalSeconds;
  final bool dynamicMode;
  final double autonomyMonths;
  final ValueChanged<double> onIntervalChanged;
  final ValueChanged<bool> onDynamicToggled;
  final String Function(double) formatInterval;

  const _FrequencySliderCard({
    required this.intervalSeconds,
    required this.dynamicMode,
    required this.autonomyMonths,
    required this.onIntervalChanged,
    required this.onDynamicToggled,
    required this.formatInterval,
  });

  Color _autonomyColor(double months) {
    if (months >= 6) return AppColors.success;
    if (months >= 2) return AppColors.amber;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dynamic mode toggle
            Row(
              children: [
                const Icon(Icons.auto_mode_rounded,
                    color: AppColors.amber, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Modo Dinâmico',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Ajusta a frequência com base no movimento',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: dynamicMode,
                  onChanged: onDynamicToggled,
                  activeThumbColor: AppColors.amber,
                  activeTrackColor: AppColors.amber.withValues(alpha: 0.4),
                ),
              ],
            ),

            if (!dynamicMode) ...[
              const Divider(color: AppColors.cardBorder, height: 24),

              // Interval label
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Intervalo de Pulso BLE:',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      formatInterval(intervalSeconds),
                      style: const TextStyle(
                        color: AppColors.amber,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Slider (1 s to 600 s / 10 min) — logarithmic feel via sqrt.
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.amber,
                  inactiveTrackColor: AppColors.cardBorder,
                  thumbColor: AppColors.amber,
                  overlayColor: AppColors.amber.withValues(alpha: 0.15),
                  trackHeight: 4,
                ),
                child: Slider(
                  min: 1,
                  max: 600,
                  value: intervalSeconds.clamp(1, 600),
                  onChanged: onIntervalChanged,
                ),
              ),

              // Min/Max labels
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('1 s',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  Text('10 min',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ],

            const Divider(color: AppColors.cardBorder, height: 24),

            // Battery autonomy estimate
            Row(
              children: [
                const Icon(Icons.battery_charging_full_rounded,
                    color: AppColors.textMuted, size: 18),
                const SizedBox(width: 8),
                const Text('Autonomia estimada:',
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 13)),
                const Spacer(),
                Text(
                  dynamicMode
                      ? '≈ 3–8 meses'
                      : '≈ ${autonomyMonths >= 1 ? '${autonomyMonths.toStringAsFixed(1)} meses' : '${(autonomyMonths * 30).round()} dias'}',
                  style: TextStyle(
                    color: dynamicMode
                        ? AppColors.success
                        : _autonomyColor(autonomyMonths),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),

            if (!dynamicMode) ...[
              const SizedBox(height: 4),
              // Energy mode breakdown
              const _EnergyModeInfo(),
            ],
          ],
        ),
      ),
    );
  }
}

class _EnergyModeInfo extends StatelessWidget {
  const _EnergyModeInfo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ModeRow(icon: '🏃', label: 'Em Movimento', interval: '2–5 s'),
        _ModeRow(icon: '😴', label: 'Em Repouso', interval: '5 min'),
        _ModeRow(icon: '🔴', label: 'Modo Perda', interval: '1 s'),
      ],
    );
  }
}

class _ModeRow extends StatelessWidget {
  final String icon;
  final String label;
  final String interval;
  const _ModeRow(
      {required this.icon, required this.label, required this.interval});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const Spacer(),
          Text(interval,
              style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rescue Link Card (Modo Perda)
// ─────────────────────────────────────────────────────────────────────────────

class _RescueLinkCard extends StatelessWidget {
  final Tag tag;
  const _RescueLinkCard({required this.tag});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.public_rounded,
                    color: AppColors.amber, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Página ativa para quem encontrar',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tag.rescueUrl,
                      style: const TextStyle(
                        color: AppColors.amber,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.open_in_new_rounded,
                        color: AppColors.amber, size: 18),
                    onPressed: () => _openRescuePage(tag.rescueUrl),
                    tooltip: 'Abrir página',
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Quem encontrar a tag pode aproximar o smartphone (NFC) ou '
              'ler o QR Code na carcaça para acessar esta página e contatar você.',
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openRescuePage(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status banner
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final Tag tag;
  const _StatusBanner({required this.tag});

  @override
  Widget build(BuildContext context) {
    final isLost = tag.isLost;
    final color = isLost ? AppColors.danger : AppColors.success;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Text(
            tag.emoji.isNotEmpty ? tag.emoji : '📦',
            style: const TextStyle(fontSize: 36),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tag.nome.isNotEmpty ? tag.nome : tag.id,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isLost ? 'PERDIDO' : 'NORMAL',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: color,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isLost
                      ? 'Este objeto foi marcado como desaparecido.'
                      : 'Nenhum alerta de perda ativo.',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toggle lost / normal button
// ─────────────────────────────────────────────────────────────────────────────

class _ToggleLostButton extends ConsumerStatefulWidget {
  final Tag tag;
  const _ToggleLostButton({required this.tag});

  @override
  ConsumerState<_ToggleLostButton> createState() => _ToggleLostButtonState();
}

class _ToggleLostButtonState extends ConsumerState<_ToggleLostButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final isLost = widget.tag.isLost;

    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _toggle,
        icon: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.black),
              )
            : Icon(isLost
                ? Icons.check_circle_outline
                : Icons.location_searching_rounded),
        label: Text(isLost ? 'Desativar Modo Perda' : '🔴 Ativar Modo Perda'),
        style: ElevatedButton.styleFrom(
          backgroundColor: isLost ? AppColors.success : AppColors.danger,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Future<void> _toggle() async {
    // Activating lost mode → confirmation dialog
    if (!widget.tag.isLost) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => _LostConfirmMiniDialog(rescueUrl: widget.tag.rescueUrl),
      );
      if (confirmed != true) return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(tagsProvider.notifier).toggleLost(widget.tag);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _LostConfirmMiniDialog extends StatelessWidget {
  final String rescueUrl;
  const _LostConfirmMiniDialog({required this.rescueUrl});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Ativar Modo Perda?',
          style: TextStyle(color: AppColors.danger)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• Pulso BLE aumenta para 1 segundo.\n'
            '• Página de resgate pública será ativada.',
            style: TextStyle(color: AppColors.textMuted, height: 1.6),
          ),
          const SizedBox(height: 10),
          Text(
            rescueUrl,
            style: const TextStyle(
                color: AppColors.amber,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar',
              style: TextStyle(color: AppColors.textMuted)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
          ),
          child: const Text('Ativar'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Location card
// ─────────────────────────────────────────────────────────────────────────────

class _LocationCard extends StatelessWidget {
  final Tag tag;
  const _LocationCard({required this.tag});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    color: AppColors.amber, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${tag.latitude!.toStringAsFixed(6)}, '
                  '${tag.longitude!.toStringAsFixed(6)}',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
            if (tag.updatedAt != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time_rounded,
                      color: AppColors.textMuted, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm')
                        .format(tag.updatedAt!.toLocal()),
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openMap(tag.latitude!, tag.longitude!),
              icon: const Icon(Icons.map_outlined),
              label: const Text('Abrir no mapa'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.amber,
                side: const BorderSide(color: AppColors.cardBorder),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMap(double lat, double lng) async {
    final uri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
