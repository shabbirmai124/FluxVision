import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../core/storage/local_vault_storage.dart';
import '../../core/storage/vault_models.dart';
import '../../engine/scan_mode.dart';

/// Samples a `gridSize x gridSize` normalized matrix using bilinear interpolation.
double sampleBilinearGrid(Float32List grid, int gridSize, double nx, double ny) {
  if (grid.isEmpty || gridSize <= 0) return 0.0;
  final gx = (nx * (gridSize - 1)).clamp(0.0, (gridSize - 1).toDouble());
  final gy = (ny * (gridSize - 1)).clamp(0.0, (gridSize - 1).toDouble());

  final x0 = gx.floor();
  final y0 = gy.floor();
  final x1 = (x0 + 1).clamp(0, gridSize - 1);
  final y1 = (y0 + 1).clamp(0, gridSize - 1);
  final tx = gx - x0;
  final ty = gy - y0;

  final v00 = grid[y0 * gridSize + x0];
  final v10 = grid[y0 * gridSize + x1];
  final v01 = grid[y1 * gridSize + x0];
  final v11 = grid[y1 * gridSize + x1];

  final top = v00 + (v10 - v00) * tx;
  final bottom = v01 + (v11 - v01) * tx;
  return (top + (bottom - top) * ty).clamp(0.0, 1.0);
}

Color interpolatePalette(ScanMode mode, double t) {
  final palette = mode.paletteColors;
  final clamped = t.clamp(0.0, 1.0);
  if (clamped < 0.04) {
    return const Color(0xFF0A1019);
  }
  if (clamped < 0.35) {
    return Color.lerp(palette[0], palette[1], (clamped - 0.04) / 0.31)!;
  }
  if (clamped < 0.70) {
    return Color.lerp(palette[1], palette[2], (clamped - 0.35) / 0.35)!;
  }
  return Color.lerp(palette[2], palette[3], (clamped - 0.70) / 0.30)!;
}

/// Renders the 32x32 matrix onto a `ui.PictureRecorder` with bilinear smoothing,
/// grid lines, telemetry legend, and exports an offline PNG file.
class BlueprintPngExporter {
  const BlueprintPngExporter(this._storage);

  final LocalVaultStorage _storage;

  Future<File> exportToPng({
    required ScanSession session,
    required Float32List grid,
  }) async {
    const int canvasWidth = 800;
    const int canvasHeight = 920;
    const double mapLeft = 48.0;
    const double mapTop = 104.0;
    const double mapSize = 640.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, canvasWidth.toDouble(), canvasHeight.toDouble()),
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, canvasWidth.toDouble(), canvasHeight.toDouble()),
      Paint()..color = const Color(0xFF080C12),
    );

    _drawHeader(canvas, session);
    _drawHeatmapPixels(
      canvas: canvas,
      grid: grid,
      gridSize: session.gridSize,
      mode: session.mode,
      origin: const Offset(mapLeft, mapTop),
      mapSize: mapSize,
    );
    _drawGridOverlay(canvas, const Offset(mapLeft, mapTop), mapSize, session.mode.accentColor);
    _drawLegendBar(canvas, session.mode, const Offset(mapLeft + mapSize + 24, mapTop), mapSize);
    _drawFooter(canvas, session, mapLeft, mapTop + mapSize + 28);

    final picture = recorder.endRecording();
    final image = await picture.toImage(canvasWidth, canvasHeight);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();

    final pngBytes = byteData!.buffer.asUint8List();
    final exportDir = await _storage.exportDirPath();
    final file = File(p.join(exportDir, 'flux_blueprint_${session.id}.png'));
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsBytes(pngBytes, flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tmp.rename(file.path);
    return file;
  }

  Future<void> sharePngFile(File pngFile, ScanSession session) async {
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(pngFile.path)],
        title: 'FluxVision 2D Spatial Heatmap',
        text:
            'FluxVision ${session.mode.label} Blueprint — Peak ${session.peakValue.toStringAsFixed(1)} ${session.mode.unit}',
      ),
    );
  }

  void _drawHeader(Canvas canvas, ScanSession session) {
    final titlePainter = TextPainter(
      text: TextSpan(
        text: 'FLUXVISION // 2D SPATIAL BLUEPRINT',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: session.mode.accentColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    titlePainter.paint(canvas, const Offset(48, 28));

    final subPainter = TextPainter(
      text: TextSpan(
        text:
            '${session.title}  |  MODE: ${session.mode.label.toUpperCase()}  |  PEAK: ${session.peakValue.toStringAsFixed(1)} ${session.mode.unit}',
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: Color(0xFF94A3B8),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    subPainter.paint(canvas, const Offset(48, 60));
  }

  void _drawHeatmapPixels({
    required Canvas canvas,
    required Float32List grid,
    required int gridSize,
    required ScanMode mode,
    required Offset origin,
    required double mapSize,
  }) {
    const int renderCells = 96;
    final cellSize = mapSize / renderCells;
    final paint = Paint()..style = PaintingStyle.fill;

    for (int y = 0; y < renderCells; y++) {
      final ny = y / (renderCells - 1);
      for (int x = 0; x < renderCells; x++) {
        final nx = x / (renderCells - 1);
        final energy = sampleBilinearGrid(grid, gridSize, nx, ny);
        paint.color = interpolatePalette(mode, energy);
        canvas.drawRect(
          Rect.fromLTWH(
            origin.dx + x * cellSize,
            origin.dy + y * cellSize,
            cellSize + 0.5,
            cellSize + 0.5,
          ),
          paint,
        );
      }
    }
  }

  void _drawGridOverlay(Canvas canvas, Offset origin, double mapSize, Color accent) {
    final linePaint = Paint()
      ..color = accent.withValues(alpha: 0.22)
      ..strokeWidth = 1.0;

    for (int i = 0; i <= 8; i++) {
      final offset = mapSize * (i / 8.0);
      canvas.drawLine(
        Offset(origin.dx + offset, origin.dy),
        Offset(origin.dx + offset, origin.dy + mapSize),
        linePaint,
      );
      canvas.drawLine(
        Offset(origin.dx, origin.dy + offset),
        Offset(origin.dx + mapSize, origin.dy + offset),
        linePaint,
      );
    }

    canvas.drawRect(
      Rect.fromLTWH(origin.dx, origin.dy, mapSize, mapSize),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = accent.withValues(alpha: 0.7),
    );
  }

  void _drawLegendBar(Canvas canvas, ScanMode mode, Offset origin, double height) {
    const width = 26.0;
    const steps = 64;
    final sliceH = height / steps;
    final paint = Paint();

    for (int i = 0; i < steps; i++) {
      final t = 1.0 - (i / (steps - 1));
      paint.color = interpolatePalette(mode, t);
      canvas.drawRect(
        Rect.fromLTWH(origin.dx, origin.dy + i * sliceH, width, sliceH + 0.5),
        paint,
      );
    }

    final hiPainter = TextPainter(
      text: const TextSpan(
        text: 'PEAK',
        style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFFF1F5F9)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    hiPainter.paint(canvas, Offset(origin.dx - 4, origin.dy - 20));

    final loPainter = TextPainter(
      text: const TextSpan(
        text: 'FLOOR',
        style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF94A3B8)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    loPainter.paint(canvas, Offset(origin.dx - 8, origin.dy + height + 8));
  }

  void _drawFooter(Canvas canvas, ScanSession session, double left, double top) {
    final footerPainter = TextPainter(
      text: TextSpan(
        text:
            'BASELINE: ${session.baselineValue.toStringAsFixed(1)} ${session.mode.unit}  •  '
            'MAX DELTA: +${session.peakDelta.toStringAsFixed(1)} ${session.mode.unit}  •  '
            'ANCHORS: ${session.anchorCount}  •  100% OFFLINE VAULT',
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: Color(0xFF94A3B8),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    footerPainter.paint(canvas, Offset(left, top));
  }
}
