import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../core/storage/vault_models.dart';
import '../../engine/scan_mode.dart';
import '../vault/vault_controller.dart';
import 'blueprint_png_exporter.dart';

/// Interactive 2D top-down room heatmap viewer with pinch-zoom, palette legend,
/// PNG export, and native Share sheet action.
class BlueprintScreen extends ConsumerStatefulWidget {
  const BlueprintScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<BlueprintScreen> createState() => _BlueprintScreenState();
}

class _BlueprintScreenState extends ConsumerState<BlueprintScreen> {
  ScanSession? _session;
  Float32List? _grid;
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadData());
  }

  Future<void> _loadData() async {
    final storage = ref.read(localVaultStorageProvider);
    final session = await storage.getSessionById(widget.sessionId);
    final grid = session != null
        ? await storage.loadSessionGrid(session.id, expectedSize: session.gridSize)
        : null;
    if (!mounted) return;
    setState(() {
      _session = session;
      _grid = grid;
      _loading = false;
    });
  }

  Future<void> _exportPng({required bool shareAfter}) async {
    final session = _session;
    final grid = _grid;
    if (session == null || grid == null || _exporting) return;

    setState(() => _exporting = true);
    try {
      final exporter = BlueprintPngExporter(ref.read(localVaultStorageProvider));
      final pngFile = await exporter.exportToPng(session: session, grid: grid);
      if (!mounted) return;
      if (shareAfter) {
        await exporter.sharePngFile(pngFile, session);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported PNG to ${pngFile.path}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final grid = _grid;

    return Scaffold(
      appBar: AppBar(
        title: Text(session?.title ?? '2D Blueprint'),
        actions: <Widget>[
          if (session != null) ...<Widget>[
            IconButton(
              tooltip: 'Save PNG',
              onPressed: _exporting ? null : () => unawaited(_exportPng(shareAfter: false)),
              icon: const Icon(Icons.download_outlined),
            ),
            IconButton(
              tooltip: 'Share PNG',
              onPressed: _exporting ? null : () => unawaited(_exportPng(shareAfter: true)),
              icon: const Icon(Icons.share_outlined),
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (session == null || grid == null)
              ? const Center(child: Text('Blueprint session not found.'))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: <Widget>[
                      _TelemetrySummaryCard(session: session),
                      const SizedBox(height: 14),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: FluxTheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: FluxTheme.border),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InteractiveViewer(
                            minScale: 0.8,
                            maxScale: 5.0,
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: 1.0,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: CustomPaint(
                                    painter: _BlueprintHeatmapPainter(
                                      mode: session.mode,
                                      grid: grid,
                                      gridSize: session.gridSize,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _PaletteLegendBar(mode: session.mode),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _exporting
                                  ? null
                                  : () => unawaited(_exportPng(shareAfter: false)),
                              icon: const Icon(Icons.save_alt),
                              label: const Text('Save PNG'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _exporting
                                  ? null
                                  : () => unawaited(_exportPng(shareAfter: true)),
                              icon: const Icon(Icons.ios_share),
                              label: const Text('Share PNG'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _TelemetrySummaryCard extends StatelessWidget {
  const _TelemetrySummaryCard({required this.session});

  final ScanSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FluxTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FluxTheme.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          _MetricCol(
            label: 'MODE',
            value: session.mode.shortLabel,
            color: session.mode.accentColor,
          ),
          _MetricCol(
            label: 'PEAK',
            value: '${session.peakValue.toStringAsFixed(1)} ${session.mode.unit}',
          ),
          _MetricCol(
            label: 'MAX DELTA',
            value: '+${session.peakDelta.toStringAsFixed(1)} ${session.mode.unit}',
            color: FluxTheme.anomalyAmber,
          ),
          _MetricCol(
            label: 'ANCHORS',
            value: '${session.anchorCount}',
          ),
        ],
      ),
    );
  }
}

class _MetricCol extends StatelessWidget {
  const _MetricCol({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label, style: const TextStyle(fontSize: 10, color: FluxTheme.textMuted)),
        const SizedBox(height: 3),
        Text(
          value,
          style: FluxTheme.monoNumeric.copyWith(fontSize: 13, color: color ?? FluxTheme.textPrimary),
        ),
      ],
    );
  }
}

class _PaletteLegendBar extends StatelessWidget {
  const _PaletteLegendBar({required this.mode});

  final ScanMode mode;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Text('FLOOR', style: TextStyle(fontSize: 11, color: FluxTheme.textMuted)),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: LinearGradient(colors: mode.paletteColors),
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Text('PEAK', style: TextStyle(fontSize: 11, color: FluxTheme.textPrimary)),
      ],
    );
  }
}

class _BlueprintHeatmapPainter extends CustomPainter {
  _BlueprintHeatmapPainter({
    required this.mode,
    required this.grid,
    required this.gridSize,
  });

  final ScanMode mode;
  final Float32List grid;
  final int gridSize;

  final Paint _cellPaint = Paint()..style = PaintingStyle.fill;
  final Paint _gridPaint = Paint()..strokeWidth = 0.9;
  final Paint _radarPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.9;

  @override
  void paint(Canvas canvas, Size size) {
    const int renderRes = 64;
    final cw = size.width / renderRes;
    final ch = size.height / renderRes;

    for (int y = 0; y < renderRes; y++) {
      final ny = y / (renderRes - 1);
      for (int x = 0; x < renderRes; x++) {
        final nx = x / (renderRes - 1);
        final val = sampleBilinearGrid(grid, gridSize, nx, ny);
        _cellPaint.color = interpolatePalette(mode, val);
        canvas.drawRect(Rect.fromLTWH(x * cw, y * ch, cw + 0.5, ch + 0.5), _cellPaint);
      }
    }

    final accent = mode.accentColor;
    _gridPaint.color = accent.withValues(alpha: 0.18);
    for (int i = 0; i <= 8; i++) {
      final px = size.width * (i / 8.0);
      final py = size.height * (i / 8.0);
      canvas.drawLine(Offset(px, 0), Offset(px, size.height), _gridPaint);
      canvas.drawLine(Offset(0, py), Offset(size.width, py), _gridPaint);
    }

    // Polar radar reference rings centered on observer origin
    final center = Offset(size.width * 0.5, size.height * 0.5);
    _radarPaint.color = accent.withValues(alpha: 0.25);
    canvas.drawCircle(center, size.width * 0.18, _radarPaint);
    canvas.drawCircle(center, size.width * 0.36, _radarPaint);
  }

  @override
  bool shouldRepaint(covariant _BlueprintHeatmapPainter oldDelegate) =>
      oldDelegate.mode != mode || oldDelegate.grid != grid;
}
