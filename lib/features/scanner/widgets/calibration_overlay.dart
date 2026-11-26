import 'package:flutter/material.dart';
import '../../../app/theme.dart';

/// Precision calibration progress bar and actionable hardware fallback banner.
class CalibrationOverlay extends StatelessWidget {
  const CalibrationOverlay({
    super.key,
    required this.isCalibrating,
    required this.progress,
    required this.accentColor,
    this.sensorAlert,
    this.demoMode = false,
    this.permissionPermanentlyDenied = false,
    this.onEnableDemoMode,
    this.onOpenSettings,
    this.onDismissAlert,
  });

  final bool isCalibrating;
  final double progress;
  final Color accentColor;
  final String? sensorAlert;
  final bool demoMode;
  final bool permissionPermanentlyDenied;
  final VoidCallback? onEnableDemoMode;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onDismissAlert;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (sensorAlert != null && !demoMode)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            decoration: BoxDecoration(
              color: FluxTheme.surfaceGlass,
              borderRadius: BorderRadius.circular(FluxTheme.radiusControl),
              border: Border.all(
                color: FluxTheme.anomalyAmber.withValues(alpha: 0.55),
                width: 0.8,
              ),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.sensors_off_outlined,
                  size: 18,
                  color: FluxTheme.anomalyAmber,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    sensorAlert!,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: FluxTheme.textPrimary,
                    ),
                  ),
                ),
                if (permissionPermanentlyDenied && onOpenSettings != null)
                  TextButton(
                    onPressed: onOpenSettings,
                    child: const Text('Settings'),
                  ),
                if (onEnableDemoMode != null)
                  TextButton(
                    onPressed: onEnableDemoMode,
                    style: TextButton.styleFrom(
                      foregroundColor: FluxTheme.cyanAccent,
                    ),
                    child: const Text('Demo'),
                  ),
                if (onDismissAlert != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: onDismissAlert,
                    icon: const Icon(
                      Icons.close,
                      size: 16,
                      color: FluxTheme.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        if (isCalibrating)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: FluxTheme.surfaceGlass,
              borderRadius: BorderRadius.circular(FluxTheme.radiusControl),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.6),
                width: 0.8,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        'Calibrating Ambient Baseline',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: FluxTheme.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: FluxTheme.monoNumeric.copyWith(
                        fontSize: 12,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Hold device steady for trimmed-mean floor sampling',
                  style: TextStyle(
                    fontSize: 11,
                    color: FluxTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress > 0.02 ? progress : null,
                    minHeight: 3,
                    backgroundColor: FluxTheme.border,
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
