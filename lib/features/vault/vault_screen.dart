import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/storage/vault_models.dart';
import '../../engine/scan_mode.dart';
import '../scanner/scanner_controller.dart';
import 'vault_controller.dart';

/// Offline vault screen using clean hairline list rows, quiet unboxed metadata,
/// and zero nested card clutter for saved Room Baselines and Scan Blueprints.
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
            tabs: <Tab>[
              Tab(text: 'Room Baselines'),
              Tab(text: 'Scan Blueprints'),
            ],
          ),
        ),
        body: vaultAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (Object error, StackTrace _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.error_outline,
                    size: 32,
                    color: FluxTheme.criticalRed,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Unable to read local vault: $error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: FluxTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () =>
                        unawaited(ref.read(vaultControllerProvider.notifier).refresh()),
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
        subtitle:
            'Calibrate a clean room on the scanner and tap Baseline to enable Privacy Diff sweeps.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: baselines.length,
      separatorBuilder: (BuildContext context, int index) => const Divider(
        height: 1,
        thickness: 0.6,
        indent: 68,
        color: FluxTheme.borderSubtle,
      ),
      itemBuilder: (BuildContext context, int index) {
        final item = baselines[index];
        final isActive = item.id == activeBaselineId;

        return InkWell(
          onTap: () => onActivate(item),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: <Widget>[
                _ModeGlyph(mode: item.mode),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.roomName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: FluxTheme.textPrimary,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isActive
                            ? 'Floor ${item.ambientValue.toStringAsFixed(1)} ${item.mode.unit}  ·  Active Diff'
                            : 'Floor ${item.ambientValue.toStringAsFixed(1)} ${item.mode.unit}  ·  ${item.mode.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FluxTheme.monoNumeric.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: isActive
                              ? FluxTheme.anomalyAmber
                              : FluxTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Delete baseline',
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  onPressed: () => onDelete(item.id),
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 19,
                    color: FluxTheme.textMuted,
                  ),
                ),
              ],
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
        icon: Icons.grid_view_outlined,
        title: 'No 2D Blueprints Yet',
        subtitle:
            'Sweep a space and tap Blueprint on the scanner console to archive a 32×32 top-down heatmap.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sessions.length,
      separatorBuilder: (BuildContext context, int index) => const Divider(
        height: 1,
        thickness: 0.6,
        indent: 68,
        color: FluxTheme.borderSubtle,
      ),
      itemBuilder: (BuildContext context, int index) {
        final session = sessions[index];

        return InkWell(
          onTap: () => onOpenBlueprint(session),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: <Widget>[
                _ModeGlyph(mode: session.mode),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        session.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: FluxTheme.textPrimary,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Peak ${session.peakValue.toStringAsFixed(1)} ${session.mode.unit}  ·  '
                        '+${session.peakDelta.toStringAsFixed(1)}  ·  '
                        '${session.anchorCount} anchors',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FluxTheme.monoNumeric.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: FluxTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Delete blueprint',
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  onPressed: () => onDelete(session.id),
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 19,
                    color: FluxTheme.textMuted,
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: FluxTheme.textMuted,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ModeGlyph extends StatelessWidget {
  const _ModeGlyph({required this.mode});

  final ScanMode mode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: FluxTheme.surface,
        borderRadius: BorderRadius.circular(FluxTheme.radiusControl),
        border: Border.all(color: FluxTheme.border, width: 0.8),
      ),
      child: Text(
        mode.shortLabel,
        style: FluxTheme.monoNumeric.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
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
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 36, color: FluxTheme.textMuted),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: FluxTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: FluxTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
