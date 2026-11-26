import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

import '../../../engine/scan_mode.dart';
import '../../../engine/spatial_field_engine.dart';

/// Precision optical rangefinder reticle: subtle corner viewfinder brackets,
/// broken center crosshair, calibrated pitch horizon ticks, azimuth readout,
/// and 4-corner caliper target-lock brackets around the strongest anomaly.
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

  final Paint _framePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0
    ..color = const Color(0x38F3F5F7);

  final Paint _horizonPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  final Paint _reticlePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.15;

  final Paint _lockPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6;

  final TextPainter _azimuthPainter = TextPainter(
    textDirection: TextDirection.ltr,
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final accent = mode.accentColor;
    final center = Offset(size.width * 0.5, size.height * 0.5);

    // Subtle corner viewfinder L-brackets (unobtrusive optical framing)
    _drawViewfinderCorners(canvas, size);

    // Calibrated azimuth & pitch readout strip above reticle
    _drawAzimuthIndicator(canvas, size, center);

    // Calibrated pitch horizon flanks with micro degree graduations
    final pitchOffset = (pitchDegrees.clamp(-45.0, 45.0) / 45.0) * (size.height * 0.18);
    final horizonY = center.dy + pitchOffset;
    _horizonPaint.color = const Color(0x4CF3F5F7);
    canvas.drawLine(
      Offset(center.dx - 76, horizonY),
      Offset(center.dx - 30, horizonY),
      _horizonPaint,
    );
    canvas.drawLine(
      Offset(center.dx + 30, horizonY),
      Offset(center.dx + 76, horizonY),
      _horizonPaint,
    );
    // Vertical pitch end ticks
    canvas.drawLine(
      Offset(center.dx - 76, horizonY - 4),
      Offset(center.dx - 76, horizonY + 4),
      _horizonPaint,
    );
    canvas.drawLine(
      Offset(center.dx + 76, horizonY - 4),
      Offset(center.dx + 76, horizonY + 4),
      _horizonPaint,
    );

    // Minimalist broken center optical crosshair (clear center aperture)
    _reticlePaint.color = const Color(0xB3F3F5F7);
    canvas.drawLine(
      Offset(center.dx - 20, center.dy),
      Offset(center.dx - 7, center.dy),
      _reticlePaint,
    );
    canvas.drawLine(
      Offset(center.dx + 7, center.dy),
      Offset(center.dx + 20, center.dy),
      _reticlePaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 20),
      Offset(center.dx, center.dy - 7),
      _reticlePaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy + 7),
      Offset(center.dx, center.dy + 20),
      _reticlePaint,
    );

    // Subtle mode-colored micro center reticle ring
    _reticlePaint.color = accent.withValues(alpha: 0.48);
    canvas.drawCircle(center, 14, _reticlePaint);

    // Precision 4-corner caliper brackets around peak anomaly
    final peak = peakHotspot;
    if (peak != null && peak.intensity > 0.16) {
      final target = Offset(peak.screenX * size.width, peak.screenY * size.height);
      final breathe = 1.0 + 0.06 * math.sin(elapsedSeconds * 4.5);
      final half = 22.0 * breathe;
      const cornerLen = 8.0;

      _lockPaint.color = mode.paletteColors.last.withValues(alpha: 0.88);
      _drawCaliperCorners(canvas, target, half, cornerLen, _lockPaint);
    }
  }

  void _drawViewfinderCorners(Canvas canvas, Size size) {
    const insetX = 20.0;
    final topY = math.max(132.0, size.height * 0.19);
    final bottomY = math.min(size.height - 154.0, size.height * 0.78);
    if (bottomY - topY < 80) return;

    const len = 14.0;
    // Top-left
    canvas.drawLine(Offset(insetX, topY), Offset(insetX + len, topY), _framePaint);
    canvas.drawLine(Offset(insetX, topY), Offset(insetX, topY + len), _framePaint);
    // Top-right
    canvas.drawLine(
      Offset(size.width - insetX, topY),
      Offset(size.width - insetX - len, topY),
      _framePaint,
    );
    canvas.drawLine(
      Offset(size.width - insetX, topY),
      Offset(size.width - insetX, topY + len),
      _framePaint,
    );
    // Bottom-left
    canvas.drawLine(Offset(insetX, bottomY), Offset(insetX + len, bottomY), _framePaint);
    canvas.drawLine(Offset(insetX, bottomY), Offset(insetX, bottomY - len), _framePaint);
    // Bottom-right
    canvas.drawLine(
      Offset(size.width - insetX, bottomY),
      Offset(size.width - insetX - len, bottomY),
      _framePaint,
    );
    canvas.drawLine(
      Offset(size.width - insetX, bottomY),
      Offset(size.width - insetX, bottomY - len),
      _framePaint,
    );
  }

  void _drawCaliperCorners(
    Canvas canvas,
    Offset center,
    double half,
    double len,
    Paint paint,
  ) {
    final l = center.dx - half;
    final r = center.dx + half;
    final t = center.dy - half;
    final b = center.dy + half;

    // Top-left
    canvas.drawLine(Offset(l, t), Offset(l + len, t), paint);
    canvas.drawLine(Offset(l, t), Offset(l, t + len), paint);
    // Top-right
    canvas.drawLine(Offset(r, t), Offset(r - len, t), paint);
    canvas.drawLine(Offset(r, t), Offset(r, t + len), paint);
    // Bottom-left
    canvas.drawLine(Offset(l, b), Offset(l + len, b), paint);
    canvas.drawLine(Offset(l, b), Offset(l, b - len), paint);
    // Bottom-right
    canvas.drawLine(Offset(r, b), Offset(r - len, b), paint);
    canvas.drawLine(Offset(r, b), Offset(r, b - len), paint);
  }

  void _drawAzimuthIndicator(Canvas canvas, Size size, Offset center) {
    final normalizedYaw = ((yawDegrees % 360.0) + 360.0) % 360.0;
    final pitchSign = pitchDegrees >= 0 ? '+' : '';
    final yawStr =
        'HDG ${normalizedYaw.toStringAsFixed(0).padLeft(3, '0')}°  ·  ELEV $pitchSign${pitchDegrees.toStringAsFixed(0)}°';
    _azimuthPainter.text = TextSpan(
      text: yawStr,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.6,
        color: Color(0x99F3F5F7),
      ),
    );
    _azimuthPainter.layout();
    final yPos = (center.dy - 50.0).clamp(116.0, size.height - 170.0);
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
