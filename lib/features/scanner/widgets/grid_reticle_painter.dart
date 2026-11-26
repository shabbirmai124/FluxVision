import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

import '../../../engine/scan_mode.dart';
import '../../../engine/spatial_field_engine.dart';

/// Sci-fi targeting reticle, yaw azimuth tape, horizon pitch ticks,
/// corner viewfinder brackets, and peak anomaly target lock ring.
class GridReticlePainter extends CustomPainter {
  GridReticlePainter({
    required this.mode,
    required this.elapsedSeconds,
    required this.pitchDegrees,
    required this.yawDegrees,
    this.peakHotspot,
  });

  final ScanMode mode;
  final double elapsedSeconds;
  final double pitchDegrees;
  final double yawDegrees;
  final ProjectedHotspot? peakHotspot;

  final Paint _gridPaint = Paint()..strokeWidth = 0.8;
  final Paint _reticlePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;
  final Paint _lockPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;
  final TextPainter _azimuthPainter = TextPainter(
    textDirection: TextDirection.ltr,
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final accent = mode.accentColor;
    final center = Offset(size.width * 0.5, size.height * 0.5);

    // Subtle spatial reference grid
    _gridPaint.color = accent.withValues(alpha: 0.08);
    const cols = 6;
    const rows = 8;
    for (int i = 1; i < cols; i++) {
      final x = size.width * (i / cols);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), _gridPaint);
    }
    for (int j = 1; j < rows; j++) {
      final y = size.height * (j / rows);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), _gridPaint);
    }

    // Compact yaw/pitch telemetry azimuth strip above center reticle
    _drawAzimuthIndicator(canvas, size, center, accent);

    // Horizon pitch indicator line
    final pitchOffset = (pitchDegrees.clamp(-45.0, 45.0) / 45.0) * (size.height * 0.2);
    final horizonY = center.dy + pitchOffset;
    _gridPaint.color = accent.withValues(alpha: 0.30);
    canvas.drawLine(
      Offset(center.dx - 64, horizonY),
      Offset(center.dx - 24, horizonY),
      _gridPaint,
    );
    canvas.drawLine(
      Offset(center.dx + 24, horizonY),
      Offset(center.dx + 64, horizonY),
      _gridPaint,
    );

    // Center reticle circle & ticks
    _reticlePaint.color = accent.withValues(alpha: 0.58);
    canvas.drawCircle(center, 18, _reticlePaint);
    canvas.drawLine(Offset(center.dx - 28, center.dy), Offset(center.dx - 10, center.dy), _reticlePaint);
    canvas.drawLine(Offset(center.dx + 10, center.dy), Offset(center.dx + 28, center.dy), _reticlePaint);
    canvas.drawLine(Offset(center.dx, center.dy - 28), Offset(center.dx, center.dy - 10), _reticlePaint);
    canvas.drawLine(Offset(center.dx, center.dy + 10), Offset(center.dx, center.dy + 28), _reticlePaint);

    // Target lock ring around peak hotspot
    final peak = peakHotspot;
    if (peak != null && peak.intensity > 0.16) {
      final target = Offset(peak.screenX * size.width, peak.screenY * size.height);
      final pulse = 1.0 + 0.12 * math.sin(elapsedSeconds * 6.0);
      final lockRadius = 24.0 * pulse;
      _lockPaint.color = mode.paletteColors.last.withValues(alpha: 0.85);

      canvas.drawArc(
        Rect.fromCircle(center: target, radius: lockRadius),
        0.2,
        1.1,
        false,
        _lockPaint,
      );
      canvas.drawArc(
        Rect.fromCircle(center: target, radius: lockRadius),
        math.pi + 0.2,
        1.1,
        false,
        _lockPaint,
      );
    }
  }

  void _drawAzimuthIndicator(Canvas canvas, Size size, Offset center, Color accent) {
    final normalizedYaw = ((yawDegrees % 360.0) + 360.0) % 360.0;
    final yawStr =
        'YAW ${normalizedYaw.toStringAsFixed(0).padLeft(3, '0')}°  •  PITCH ${pitchDegrees.toStringAsFixed(0)}°';
    _azimuthPainter.text = TextSpan(
      text: yawStr,
      style: TextStyle(
        fontFamily: 'monospace',
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        fontSize: 10,
        letterSpacing: 0.8,
        color: accent.withValues(alpha: 0.65),
      ),
    );
    _azimuthPainter.layout();
    final yPos = (center.dy - 54.0).clamp(90.0, size.height - 140.0);
    _azimuthPainter.paint(canvas, Offset(center.dx - _azimuthPainter.width * 0.5, yPos));
  }

  @override
  bool shouldRepaint(covariant GridReticlePainter oldDelegate) {
    return oldDelegate.mode != mode ||
        oldDelegate.elapsedSeconds != elapsedSeconds ||
        oldDelegate.pitchDegrees != pitchDegrees ||
        oldDelegate.yawDegrees != yawDegrees ||
        oldDelegate.peakHotspot != peakHotspot;
  }
}
