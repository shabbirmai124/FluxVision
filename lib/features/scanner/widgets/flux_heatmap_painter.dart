import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:material_ui/material_ui.dart';

import '../../../engine/scan_mode.dart';
import '../../../engine/spatial_field_engine.dart';

/// Hardware-accelerated Pure-Dart AR thermal/plasma heatmap painter.
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
    ..strokeWidth = 1.2;
  final Paint _tagBgPaint = Paint()
    ..color = const Color(0xCC080C12)
    ..style = PaintingStyle.fill;
  final Paint _tagBorderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
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
      final pulse = 1.0 + 0.05 * math.sin(elapsedSeconds * 4.5 + i);
      final radius = minDim * (0.14 + 0.18 * spot.intensity) * pulse;
      final alpha = (0.35 + 0.50 * spot.intensity).clamp(0.0, 0.88);

      final colors = <Color>[
        palette[3].withValues(alpha: alpha),
        palette[2].withValues(alpha: alpha * 0.82),
        palette[1].withValues(alpha: alpha * 0.48),
        palette[0].withValues(alpha: alpha * 0.22),
        palette[0].withValues(alpha: 0.0),
      ];

      _blobPaint
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.35)
        ..shader = ui.Gradient.radial(
          center,
          radius,
          colors,
          const <double>[0.0, 0.24, 0.54, 0.78, 1.0],
        );

      canvas.drawCircle(center, radius, _blobPaint);

      // Topographic iso-contour rings around strong cores
      if (spot.intensity > 0.35) {
        final ringCount = spot.intensity > 0.7 ? 3 : 2;
        for (int rIdx = 1; rIdx <= ringCount; rIdx++) {
          final ringRadius = radius * (0.24 * rIdx);
          _contourPaint.color = palette[3].withValues(
            alpha: (0.28 - rIdx * 0.06).clamp(0.06, 0.35),
          );
          canvas.drawCircle(center, ringRadius, _contourPaint);
        }
      }
    }

    canvas.restore();

    // Micro peak-delta telemetry badge beside the strongest active hotspot
    final peak = hotspots.first;
    if (peak.intensity > 0.22) {
      final px = (peak.screenX * size.width).clamp(54.0, size.width - 78.0);
      final py = (peak.screenY * size.height - 34.0).clamp(28.0, size.height - 28.0);
      final label = '+${peak.peakDelta.toStringAsFixed(1)} ${mode.unit}';
      _labelPainter.text = TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'monospace',
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: palette[3],
        ),
      );
      _labelPainter.layout();

      final badgeRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          px - _labelPainter.width * 0.5 - 6,
          py - 3,
          _labelPainter.width + 12,
          _labelPainter.height + 6,
        ),
        const Radius.circular(6),
      );
      _tagBorderPaint.color = palette[2].withValues(alpha: 0.75);
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
