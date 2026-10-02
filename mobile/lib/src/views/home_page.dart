import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/theme.dart';
import '../providers/providers.dart';
import '../models/tag.dart';
import 'tag_detail_page.dart';
import 'scanner_page.dart';

/// Main screen: list of user's registered tags + bottom nav to scanner.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _navIndex,
        children: const [
          _TagListView(),
          ScannerPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.card,
        indicatorColor: AppColors.amber.withValues(alpha: 0.15),
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.sell_outlined),
            selectedIcon: Icon(Icons.sell, color: AppColors.amber),
            label: 'Minhas Tags',
          ),
          NavigationDestination(
            icon: Icon(Icons.radar_outlined),
            selectedIcon: Icon(Icons.radar, color: AppColors.amber),
            label: 'Scanner',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tag list tab
// ─────────────────────────────────────────────────────────────────────────────

class _TagListView extends ConsumerWidget {
  const _TagListView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('TagFind'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Atualizar',
            onPressed: () => ref.read(tagsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: tagsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.amber),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded,
                    size: 48, color: AppColors.danger),
                const SizedBox(height: 16),
                Text(
                  'Erro ao carregar tags',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => ref.read(tagsProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
        data: (tags) {
          if (tags.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.nfc_rounded,
                      size: 64, color: AppColors.amber.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma tag cadastrada',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Cadastre uma tag no Supabase para começar.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.amber,
            onRefresh: () => ref.read(tagsProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 100),
              itemCount: tags.length,
              itemBuilder: (_, i) => _TagCard(tag: tags[i]),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tag card widget
// ─────────────────────────────────────────────────────────────────────────────

class _TagCard extends ConsumerWidget {
  final Tag tag;
  const _TagCard({required this.tag});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TagDetailPage(tagId: tag.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (tag.isLost ? AppColors.danger : AppColors.success)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  tag.isLost
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline_rounded,
                  color: tag.isLost ? AppColors.danger : AppColors.success,
                ),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tag.id,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.amber,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tag.isLost ? 'PERDIDO' : 'NORMAL',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color:
                            tag.isLost ? AppColors.danger : AppColors.success,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (tag.mensagem.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        tag.mensagem,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Chevron
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
