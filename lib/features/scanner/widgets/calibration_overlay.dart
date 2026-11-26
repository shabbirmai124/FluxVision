import 'package:material_ui/material_ui.dart';
import '../../../app/theme.dart';

/// 1-second animated calibration progress overlay & hardware fallback banner.
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: FluxTheme.surfaceGlass,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FluxTheme.anomalyAmber.withValues(alpha: 0.7)),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.sensors_off, size: 18, color: FluxTheme.anomalyAmber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sensorAlert!,
                    style: const TextStyle(fontSize: 12, color: FluxTheme.textPrimary),
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
                    child: const Text('Demo'),
                  ),
                if (onDismissAlert != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: onDismissAlert,
                    icon: const Icon(Icons.close, size: 16, color: FluxTheme.textMuted),
                  ),
              ],
            ),
          ),
        if (isCalibrating)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: FluxTheme.surfaceGlass,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accentColor.withValues(alpha: 0.8)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    value: progress > 0.02 ? progress : null,
                    strokeWidth: 3,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text(
                      'Calibrating Ambient Baseline...',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Hold steady for 1 second (${(progress * 100).round()}%)',
                      style: const TextStyle(fontSize: 11, color: FluxTheme.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
