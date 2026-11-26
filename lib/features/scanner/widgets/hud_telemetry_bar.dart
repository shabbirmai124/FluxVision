import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../engine/scan_mode.dart';
import '../scanner_state.dart';

/// Precision instrument telemetry bar with clean tabular numeric hierarchy,
/// unboxed metadata separators, and generous 44px touch targets.
class HudTelemetryBar extends StatelessWidget {
  const HudTelemetryBar({
    super.key,
    required this.state,
    required this.onToggleDemo,
    required this.onOpenVault,
    required this.onClearBaseline,
  });

  final ScannerState state;
  final VoidCallback onToggleDemo;
  final VoidCallback onOpenVault;
  final VoidCallback onClearBaseline;

  @override
  Widget build(BuildContext context) {
    final mode = state.mode;
    final frame = state.frame;
    final accent = mode.accentColor;
    final isAlert = frame.anomalyDetected;

    return Container(
      decoration: BoxDecoration(
        color: FluxTheme.surfaceGlass,
        borderRadius: BorderRadius.circular(FluxTheme.radiusOuter),
        border: Border.all(
          color: isAlert
              ? FluxTheme.anomalyAmber.withValues(alpha: 0.65)
              : FluxTheme.border,
          width: 0.8,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 10, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                // Primary tabular measurement + unboxed unit & delta (overflow-proof)
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Text(
                          frame.filteredValue.toStringAsFixed(1),
                          style: FluxTheme.monoNumeric.copyWith(
                            fontSize: 26,
                            height: 1.05,
                            letterSpacing: -0.6,
                            color: FluxTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${mode.shortLabel} ${mode.unit}',
                          style: FluxTheme.monoNumeric.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: accent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${isAlert ? '▲ ' : ''}+${frame.anomalyDelta.toStringAsFixed(1)}',
                          style: FluxTheme.monoNumeric.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isAlert
                                ? FluxTheme.anomalyAmber
                                : FluxTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Tactile Live/Demo toggle (44px hitbox)
                _TopBarAction(
                  onTap: onToggleDemo,
                  active: state.demoMode,
                  accent: FluxTheme.cyanAccent,
                  child: Text(
                    state.demoMode ? 'DEMO ON' : 'LIVE',
                    style: FluxTheme.monoNumeric.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: state.demoMode
                          ? FluxTheme.cyanAccent
                          : FluxTheme.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Vault navigation trigger (44px hitbox)
                _TopBarAction(
                  onTap: onOpenVault,
                  active: false,
                  accent: FluxTheme.textPrimary,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 15,
                        color: FluxTheme.textPrimary,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Vault',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: FluxTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Hairline separator
          const Divider(height: 1, thickness: 0.6, color: FluxTheme.borderSubtle),

          // Quiet unboxed instrument metadata strip (zero pill clutter)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _buildMetadataLine(mode, frame.baselineValue),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FluxTheme.monoNumeric.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: FluxTheme.textMuted,
                    ),
                  ),
                ),
                if (state.activeBaseline != null) ...<Widget>[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onClearBaseline,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'Diff · ${state.activeBaseline!.roomName}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: FluxTheme.anomalyAmber,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.close,
                          size: 13,
                          color: FluxTheme.anomalyAmber,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildMetadataLine(ScanMode mode, double baselineValue) {
    final parts = <String>[
      'Floor ${baselineValue.toStringAsFixed(1)} ${mode.unit}',
      if (mode == ScanMode.rf) 'BLE ${state.bleDeviceCount}',
      '${state.fps} fps',
    ];
    return parts.join('  ·  ');
  }
}

class _TopBarAction extends StatelessWidget {
  const _TopBarAction({
    required this.onTap,
    required this.active,
    required this.accent,
    required this.child,
  });

  final VoidCallback onTap;
  final bool active;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FluxTheme.radiusControl),
        child: Container(
          constraints: const BoxConstraints(minHeight: 40, minWidth: 44),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? accent.withValues(alpha: 0.14)
                : FluxTheme.surfaceElevated.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(FluxTheme.radiusControl),
            border: Border.all(
              color: active ? accent.withValues(alpha: 0.55) : FluxTheme.border,
              width: 0.8,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
