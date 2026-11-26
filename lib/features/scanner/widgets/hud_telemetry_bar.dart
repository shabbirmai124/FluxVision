import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../engine/scan_mode.dart';
import '../scanner_state.dart';

/// Top tactical HUD telemetry readout displaying active scan mode, tabular live
/// signal measurement, baseline delta, BLE beacon count, FPS, Demo toggle, and Vault shortcut.
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: FluxTheme.surfaceGlass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAlert
              ? FluxTheme.anomalyAmber.withValues(alpha: 0.78)
              : FluxTheme.border,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              // Active mode & unit badge (e.g. "EM µT", "RF dBm", "SND dB")
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: accent.withValues(alpha: 0.6)),
                ),
                child: Text(
                  '${mode.shortLabel} ${mode.unit}',
                  style: FluxTheme.monoNumeric.copyWith(
                    fontSize: 11,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Primary tabular numeric reading
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Text(
                      frame.filteredValue.toStringAsFixed(1),
                      style: FluxTheme.monoNumeric.copyWith(
                        fontSize: 22,
                        color: FluxTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '+${frame.anomalyDelta.toStringAsFixed(1)}',
                      style: FluxTheme.monoNumeric.copyWith(
                        fontSize: 12,
                        color: isAlert ? FluxTheme.anomalyAmber : FluxTheme.nominalGreen,
                      ),
                    ),
                  ],
                ),
              ),
              // Demo Mode toggle chip
              InkWell(
                onTap: onToggleDemo,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: state.demoMode
                        ? FluxTheme.cyanAccent.withValues(alpha: 0.18)
                        : FluxTheme.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: state.demoMode
                          ? FluxTheme.cyanAccent
                          : FluxTheme.border,
                    ),
                  ),
                  child: Text(
                    state.demoMode ? 'DEMO ON' : 'LIVE',
                    style: FluxTheme.monoNumeric.copyWith(
                      fontSize: 10,
                      color: state.demoMode
                          ? FluxTheme.cyanAccent
                          : FluxTheme.textMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Vault shortcut button
              InkWell(
                onTap: onOpenVault,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: FluxTheme.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: FluxTheme.border),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.folder_outlined, size: 13, color: FluxTheme.textPrimary),
                      SizedBox(width: 4),
                      Text(
                        'Vault',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: FluxTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Text(
                'FLOOR ${frame.baselineValue.toStringAsFixed(1)} ${mode.unit}',
                style: FluxTheme.monoNumeric.copyWith(
                  fontSize: 10,
                  color: FluxTheme.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (mode == ScanMode.rf) ...<Widget>[
                const SizedBox(width: 10),
                Text(
                  'BLE ${state.bleDeviceCount}',
                  style: FluxTheme.monoNumeric.copyWith(
                    fontSize: 10,
                    color: FluxTheme.cyanAccent,
                  ),
                ),
              ],
              const Spacer(),
              if (state.activeBaseline != null) ...<Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: FluxTheme.anomalyAmber.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: FluxTheme.anomalyAmber.withValues(alpha: 0.65),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'DIFF: ${state.activeBaseline!.roomName}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: FluxTheme.anomalyAmber,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: onClearBaseline,
                        child: const Icon(
                          Icons.close,
                          size: 12,
                          color: FluxTheme.anomalyAmber,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                '${state.fps} FPS',
                style: FluxTheme.monoNumeric.copyWith(
                  fontSize: 10,
                  color: FluxTheme.nominalGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
