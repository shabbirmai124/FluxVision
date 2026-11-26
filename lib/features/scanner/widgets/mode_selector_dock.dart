import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../engine/scan_mode.dart';

/// Ergonomic thumb-zone hardware console featuring a recessed segmented vision
/// selector and clear primary/secondary action hierarchy (44px+ hit targets).
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
        borderRadius: BorderRadius.circular(FluxTheme.radiusOuter),
        border: Border.all(color: FluxTheme.border, width: 0.8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Recessed segmented instrument selector (EM | RF | SND)
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: FluxTheme.background.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(FluxTheme.radiusControl + 2),
              border: Border.all(color: FluxTheme.borderSubtle, width: 0.8),
            ),
            child: Row(
              children: ScanMode.values.map((ScanMode mode) {
                final selected = mode == activeMode;
                return Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onSelectMode(mode),
                      borderRadius: BorderRadius.circular(FluxTheme.radiusControl),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOutCubic,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? FluxTheme.surfaceElevated
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(FluxTheme.radiusControl),
                          border: selected
                              ? Border.all(
                                  color: mode.accentColor.withValues(alpha: 0.55),
                                  width: 0.8,
                                )
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (selected) ...<Widget>[
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: mode.accentColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              mode.shortLabel,
                              style: FluxTheme.monoNumeric.copyWith(
                                fontSize: 12,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                color: selected
                                    ? FluxTheme.textPrimary
                                    : FluxTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
          ),

          const SizedBox(height: 10),

          // Action strip: 4 clean unboxed utility buttons + 1 primary Blueprint CTA
          Row(
            children: <Widget>[
              Expanded(
                child: _ConsoleAction(
                  label: 'Calibrate',
                  highlighted: isCalibrating,
                  highlightColor: accent,
                  onTap: onCalibrate,
                  icon: isCalibrating
                      ? SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            value: calibrationProgress > 0.02
                                ? calibrationProgress
                                : null,
                            strokeWidth: 2,
                            color: accent,
                          ),
                        )
                      : Icon(
                          Icons.center_focus_strong_outlined,
                          size: 18,
                          color: FluxTheme.textPrimary,
                        ),
                ),
              ),
              Expanded(
                child: _ConsoleAction(
                  label: trailLock ? 'Locked' : 'Trail Lock',
                  highlighted: trailLock,
                  highlightColor: FluxTheme.anomalyAmber,
                  onTap: onToggleTrailLock,
                  icon: Icon(
                    trailLock ? Icons.lock_rounded : Icons.lock_open_rounded,
                    size: 18,
                    color: trailLock
                        ? FluxTheme.anomalyAmber
                        : FluxTheme.textPrimary,
                  ),
                ),
              ),
              Expanded(
                child: _ConsoleAction(
                  label: 'Clear',
                  highlighted: false,
                  highlightColor: FluxTheme.textSecondary,
                  onTap: onClearTrails,
                  icon: const Icon(
                    Icons.layers_clear_outlined,
                    size: 18,
                    color: FluxTheme.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: _ConsoleAction(
                  label: 'Baseline',
                  highlighted: false,
                  highlightColor: FluxTheme.textSecondary,
                  onTap: onSaveBaseline,
                  icon: const Icon(
                    Icons.bookmark_add_outlined,
                    size: 18,
                    color: FluxTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Single clear primary capture CTA
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onSaveBlueprint,
                  borderRadius: BorderRadius.circular(FluxTheme.radiusControl),
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: FluxTheme.textPrimary,
                      borderRadius: BorderRadius.circular(FluxTheme.radiusControl),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.grid_view_rounded,
                          size: 16,
                          color: FluxTheme.background,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          anchorCount > 0 ? 'Map ($anchorCount)' : 'Blueprint',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: FluxTheme.background,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
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

class _ConsoleAction extends StatelessWidget {
  const _ConsoleAction({
    required this.label,
    required this.highlighted,
    required this.highlightColor,
    required this.onTap,
    required this.icon,
  });

  final String label;
  final bool highlighted;
  final Color highlightColor;
  final VoidCallback onTap;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FluxTheme.radiusControl),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          alignment: Alignment.center,
          decoration: highlighted
              ? BoxDecoration(
                  color: highlightColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(FluxTheme.radiusControl),
                )
              : null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
                  fontWeight: highlighted ? FontWeight.w600 : FontWeight.w500,
                  color: highlighted ? highlightColor : FluxTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
