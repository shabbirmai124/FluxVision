import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/storage/vault_models.dart';
import '../../engine/scan_mode.dart';
import '../scanner/scanner_controller.dart';
import 'vault_controller.dart';

/// Offline vault screen displaying saved Room Baselines (for Privacy Diff Mode)
/// and persisted 2D Scan Blueprints.
class VaultScreen extends ConsumerWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vaultAsync = ref.watch(vaultControllerProvider);
    final activeBaseline = ref.watch(
      scannerControllerProvider.select((s) => s.activeBaseline),
    );

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Offline Vault'),
          bottom: const TabBar(
            indicatorColor: FluxTheme.cyanAccent,
            labelColor: FluxTheme.textPrimary,
            unselectedLabelColor: FluxTheme.textMuted,
            tabs: <Tab>[
              Tab(text: 'Room Baselines'),
              Tab(text: 'Scan Blueprints'),
            ],
          ),
        ),
        body: vaultAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.error_outline, size: 36, color: FluxTheme.criticalRed),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to read local vault: $error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: FluxTheme.textMuted),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => unawaited(ref.read(vaultControllerProvider.notifier).refresh()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (VaultState vault) => TabBarView(
            children: <Widget>[
              _BaselinesTab(
                baselines: vault.baselines,
                activeBaselineId: activeBaseline?.id,
                onActivate: (RoomBaseline baseline) {
                  ref.read(scannerControllerProvider.notifier).applyBaseline(baseline);
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
                onDelete: (String id) => unawaited(
                  ref.read(vaultControllerProvider.notifier).deleteBaseline(id),
                ),
              ),
              _SessionsTab(
                sessions: vault.sessions,
                onOpenBlueprint: (ScanSession session) {
                  unawaited(context.push('/blueprint/${session.id}'));
                },
                onDelete: (String id) => unawaited(
                  ref.read(vaultControllerProvider.notifier).deleteSession(id),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BaselinesTab extends StatelessWidget {
  const _BaselinesTab({
    required this.baselines,
    required this.activeBaselineId,
    required this.onActivate,
    required this.onDelete,
  });

  final List<RoomBaseline> baselines;
  final String? activeBaselineId;
  final ValueChanged<RoomBaseline> onActivate;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    if (baselines.isEmpty) {
      return const _EmptyVaultMessage(
        icon: Icons.shield_outlined,
        title: 'No Room Baselines Saved',
        subtitle: 'Calibrate a clean room on the scanner and tap Baseline to enable Privacy Diff sweeps.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: baselines.length,
      separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        final item = baselines[index];
        final isActive = item.id == activeBaselineId;

        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onActivate(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: <Widget>[
                  _ModeBadge(mode: item.mode),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                item.roomName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: FluxTheme.textPrimary,
                                ),
                              ),
                            ),
                            if (isActive) ...<Widget>[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: FluxTheme.cyanAccent.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: FluxTheme.cyanAccent.withValues(alpha: 0.7),
                                  ),
                                ),
                                child: const Text(
                                  'ACTIVE DIFF',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: FluxTheme.cyanAccent,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ambient Floor: ${item.ambientValue.toStringAsFixed(1)} ${item.mode.unit}',
                          style: FluxTheme.monoNumeric.copyWith(
                            fontSize: 12,
                            color: FluxTheme.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete baseline',
                    onPressed: () => onDelete(item.id),
                    icon: const Icon(Icons.delete_outline, color: FluxTheme.textMuted),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SessionsTab extends StatelessWidget {
  const _SessionsTab({
    required this.sessions,
    required this.onOpenBlueprint,
    required this.onDelete,
  });

  final List<ScanSession> sessions;
  final ValueChanged<ScanSession> onOpenBlueprint;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const _EmptyVaultMessage(
        icon: Icons.grid_on_outlined,
        title: 'No 2D Blueprints Yet',
        subtitle: 'Sweep a room and tap Blueprint on the scanner dock to archive a 32x32 top-down heatmap.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sessions.length,
      separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        final session = sessions[index];

        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onOpenBlueprint(session),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: <Widget>[
                  _ModeBadge(mode: session.mode),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          session.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: FluxTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Peak ${session.peakValue.toStringAsFixed(1)} ${session.mode.unit}  •  '
                          '+${session.peakDelta.toStringAsFixed(1)}  •  '
                          '${session.anchorCount} anchors',
                          style: FluxTheme.monoNumeric.copyWith(
                            fontSize: 11,
                            color: FluxTheme.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete blueprint',
                    onPressed: () => onDelete(session.id),
                    icon: const Icon(Icons.delete_outline, color: FluxTheme.textMuted),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.mode});

  final ScanMode mode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: mode.accentColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: mode.accentColor.withValues(alpha: 0.55)),
      ),
      child: Text(
        mode.shortLabel,
        style: FluxTheme.monoNumeric.copyWith(
          fontSize: 12,
          color: mode.accentColor,
        ),
      ),
    );
  }
}

class _EmptyVaultMessage extends StatelessWidget {
  const _EmptyVaultMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 42, color: FluxTheme.textMuted),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: FluxTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: FluxTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
