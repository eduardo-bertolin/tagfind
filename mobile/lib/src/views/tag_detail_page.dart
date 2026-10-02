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
                // ── Status card ──────────────────────────────────────
                _StatusBanner(tag: tag),
                const SizedBox(height: 24),

                // ── Toggle lost button ───────────────────────────────
                _ToggleLostButton(tag: tag),
                const SizedBox(height: 28),

                // ── Contact info section ─────────────────────────────
                Text(
                  'Informações de resgate',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textMuted,
                        letterSpacing: 0.8,
                      ),
                ),
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

                // ── Location info ────────────────────────────────────
                if (tag.latitude != null && tag.longitude != null) ...[
                  Text(
                    'Última localização conhecida',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.textMuted,
                          letterSpacing: 0.8,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Card(
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
                                style:
                                    const TextStyle(color: AppColors.textMuted),
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
                            onPressed: () => _openMap(
                                tag.latitude!, tag.longitude!),
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('Abrir no mapa'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.amber,
                              side:
                                  const BorderSide(color: AppColors.cardBorder),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
          const SnackBar(content: Text('Salvo com sucesso!')),
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

  Future<void> _openMap(double lat, double lng) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
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
          Icon(
            isLost
                ? Icons.warning_amber_rounded
                : Icons.verified_rounded,
            color: color,
            size: 36,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLost ? 'PERDIDO' : 'NORMAL',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: color,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isLost
                      ? 'Este objeto foi marcado como desaparecido.'
                      : 'Nenhum alerta de perda ativo.',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 13),
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
            : Icon(isLost ? Icons.check_circle_outline : Icons.report_outlined),
        label: Text(isLost ? 'Marcar como Normal' : 'Marcar como Perdido'),
        style: ElevatedButton.styleFrom(
          backgroundColor: isLost ? AppColors.success : AppColors.danger,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Future<void> _toggle() async {
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
