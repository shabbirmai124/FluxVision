import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../engine/scan_mode.dart';

/// Bottom tactical control dock with 3-way vision mode switcher and spatial scan actions.
class ModeSelectorDock extends StatelessWidget {
  const ModeSelectorDock({
    super.key,
    required this.activeMode,
    required this.trailLock,
    required this.isCalibrating,
    required this.calibrationProgress,
    required this.anchorCount,
    required this.onSelectMode,
    required this.onCalibrate,
    required this.onToggleTrailLock,
    required this.onClearTrails,
    required this.onSaveBaseline,
    required this.onSaveBlueprint,
  });

  final ScanMode activeMode;
  final bool trailLock;
  final bool isCalibrating;
  final double calibrationProgress;
  final int anchorCount;
  final ValueChanged<ScanMode> onSelectMode;
  final VoidCallback onCalibrate;
  final VoidCallback onToggleTrailLock;
  final VoidCallback onClearTrails;
  final VoidCallback onSaveBaseline;
  final VoidCallback onSaveBlueprint;

  @override
  Widget build(BuildContext context) {
    final accent = activeMode.accentColor;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: FluxTheme.surfaceGlass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FluxTheme.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Segmented Vision Mode Selector (EM | RF | SND)
          Row(
            children: ScanMode.values.map((ScanMode mode) {
              final selected = mode == activeMode;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    onTap: () => onSelectMode(mode),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? mode.accentColor.withValues(alpha: 0.20)
                            : FluxTheme.background.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? mode.accentColor
                              : FluxTheme.border,
                        ),
                      ),
                      child: Text(
                        mode.shortLabel,
                        style: FluxTheme.monoNumeric.copyWith(
                          fontSize: 12,
                          color: selected
                              ? mode.accentColor
                              : FluxTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 10),
          // Spatial Action Row
          Row(
            children: <Widget>[
              Expanded(
                child: _DockActionButton(
                  label: 'Calibrate',
                  accent: accent,
                  highlighted: isCalibrating,
                  onTap: onCalibrate,
                  icon: isCalibrating
                      ? SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            value: calibrationProgress > 0.02 ? calibrationProgress : null,
                            strokeWidth: 2,
                            color: accent,
                          ),
                        )
                      : Icon(Icons.track_changes, size: 16, color: accent),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _DockActionButton(
                  label: trailLock ? 'Locked' : 'Trail Lock',
                  accent: FluxTheme.anomalyAmber,
                  highlighted: trailLock,
                  onTap: onToggleTrailLock,
                  icon: Icon(
                    trailLock ? Icons.lock : Icons.lock_open,
                    size: 16,
                    color: trailLock ? FluxTheme.anomalyAmber : FluxTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _DockActionButton(
                  label: 'Clear',
                  accent: FluxTheme.textMuted,
                  highlighted: false,
                  onTap: onClearTrails,
                  icon: const Icon(
                    Icons.layers_clear_outlined,
                    size: 16,
                    color: FluxTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _DockActionButton(
                  label: 'Baseline',
                  accent: FluxTheme.cyanAccent,
                  highlighted: false,
                  onTap: onSaveBaseline,
                  icon: const Icon(
                    Icons.bookmark_add_outlined,
                    size: 16,
                    color: FluxTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _DockActionButton(
                  label: anchorCount > 0 ? 'Map ($anchorCount)' : 'Blueprint',
                  accent: FluxTheme.nominalGreen,
                  highlighted: anchorCount > 0,
                  onTap: onSaveBlueprint,
                  icon: Icon(
                    Icons.map_outlined,
                    size: 16,
                    color: anchorCount > 0 ? FluxTheme.nominalGreen : FluxTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DockActionButton extends StatelessWidget {
  const _DockActionButton({
    required this.label,
    required this.accent,
    required this.highlighted,
    required this.onTap,
    required this.icon,
  });

  final String label;
  final Color accent;
  final bool highlighted;
  final VoidCallback onTap;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: highlighted
              ? accent.withValues(alpha: 0.16)
              : FluxTheme.background.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: highlighted ? accent : FluxTheme.border,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            icon,
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: highlighted ? accent : FluxTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
