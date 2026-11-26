import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../../../engine/scan_mode.dart';
import '../../../engine/spatial_field_engine.dart';

/// Hardware-accelerated Pure-Dart radiometric thermal AR overlay.
/// Reuses pre-allocated Paint and TextPainter objects for zero hot-loop churn at 60-120 FPS.
class FluxHeatmapPainter extends CustomPainter {
  FluxHeatmapPainter({
    required this.mode,
    required this.hotspots,
    required this.elapsedSeconds,
  });

  final ScanMode mode;
  final List<ProjectedHotspot> hotspots;
  final double elapsedSeconds;

  final Paint _layerPaint = Paint();
  final Paint _blobPaint = Paint()..blendMode = BlendMode.plus;
  final Paint _contourPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  final Paint _leaderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  final Paint _tagBgPaint = Paint()
    ..color = const Color(0xDF0B0E14)
    ..style = PaintingStyle.fill;
  final Paint _tagBorderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8;
  final TextPainter _labelPainter = TextPainter(
    textDirection: TextDirection.ltr,
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (hotspots.isEmpty || size.isEmpty) return;

    final rect = Offset.zero & size;
    final minDim = math.min(size.width, size.height);
    final palette = mode.paletteColors;

    canvas.saveLayer(rect, _layerPaint);

    for (int i = 0; i < hotspots.length; i++) {
      final spot = hotspots[i];
      if (spot.intensity <= 0.04) continue;

      final center = Offset(spot.screenX * size.width, spot.screenY * size.height);
      final pulse = 1.0 + 0.035 * math.sin(elapsedSeconds * 3.8 + i);
      final radius = minDim * (0.13 + 0.17 * spot.intensity) * pulse;
      final alpha = (0.32 + 0.48 * spot.intensity).clamp(0.0, 0.84);

      final colors = <Color>[
        palette[3].withValues(alpha: alpha),
        palette[2].withValues(alpha: alpha * 0.78),
        palette[1].withValues(alpha: alpha * 0.44),
        palette[0].withValues(alpha: alpha * 0.18),
        palette[0].withValues(alpha: 0.0),
      ];

      _blobPaint
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.32)
        ..shader = ui.Gradient.radial(
          center,
          radius,
          colors,
          const <double>[0.0, 0.22, 0.52, 0.78, 1.0],
        );

      canvas.drawCircle(center, radius, _blobPaint);

      // Fine topographic iso-contour rings around strong radiometric cores
      if (spot.intensity > 0.35) {
        final ringCount = spot.intensity > 0.7 ? 3 : 2;
        for (int rIdx = 1; rIdx <= ringCount; rIdx++) {
          final ringRadius = radius * (0.24 * rIdx);
          _contourPaint.color = palette[3].withValues(
            alpha: (0.24 - rIdx * 0.05).clamp(0.06, 0.28),
          );
          canvas.drawCircle(center, ringRadius, _contourPaint);
        }
      }
    }

    canvas.restore();

    // Calibrated peak-delta callout anchored above the strongest hotspot with hairline leader
    final peak = hotspots.first;
    if (peak.intensity > 0.22) {
      final anchorX = (peak.screenX * size.width).clamp(24.0, size.width - 24.0);
      final anchorY = (peak.screenY * size.height).clamp(64.0, size.height - 64.0);
      final px = anchorX.clamp(58.0, size.width - 58.0);
      final py = (anchorY - 46.0).clamp(28.0, size.height - 40.0);

      final label = '+${peak.peakDelta.toStringAsFixed(1)} ${mode.unit}';
      _labelPainter.text = TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'monospace',
          fontFeatures: const <ui.FontFeature>[ui.FontFeature.tabularFigures()],
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: palette[3],
        ),
      );
      _labelPainter.layout();

      final boxTop = py - 4;
      final boxHeight = _labelPainter.height + 8;
      final badgeRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          px - _labelPainter.width * 0.5 - 8,
          boxTop,
          _labelPainter.width + 16,
          boxHeight,
        ),
        const Radius.circular(6),
      );

      _leaderPaint.color = palette[3].withValues(alpha: 0.45);
      canvas.drawLine(
        Offset(px, boxTop + boxHeight),
        Offset(anchorX, anchorY - 22.0),
        _leaderPaint,
      );

      _tagBorderPaint.color = palette[2].withValues(alpha: 0.65);
      canvas.drawRRect(badgeRect, _tagBgPaint);
      canvas.drawRRect(badgeRect, _tagBorderPaint);
      _labelPainter.paint(canvas, Offset(px - _labelPainter.width * 0.5, py));
    }
  }

  @override
  bool shouldRepaint(covariant FluxHeatmapPainter oldDelegate) {
    return oldDelegate.mode != mode ||
        oldDelegate.elapsedSeconds != elapsedSeconds ||
        oldDelegate.hotspots != hotspots;
  }
}
