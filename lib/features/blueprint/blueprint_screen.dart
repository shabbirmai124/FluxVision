import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/storage/vault_models.dart';
import '../../engine/scan_mode.dart';
import '../vault/vault_controller.dart';
import 'blueprint_png_exporter.dart';

/// Interactive 2D top-down spatial blueprint viewer with hairline telemetry
/// strip, calibrated polar grid, radiometric scale bar, and PNG export/share.
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
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 0.6, color: FluxTheme.borderSubtle),
        ),
        actions: <Widget>[
          if (session != null) ...<Widget>[
            IconButton(
              tooltip: 'Save PNG',
              onPressed: _exporting ? null : () => unawaited(_exportPng(shareAfter: false)),
              icon: const Icon(Icons.download_outlined, size: 20),
            ),
            IconButton(
              tooltip: 'Share PNG',
              onPressed: _exporting ? null : () => unawaited(_exportPng(shareAfter: true)),
              icon: const Icon(Icons.ios_share, size: 19),
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : (session == null || grid == null)
              ? const Center(
                  child: Text(
                    'Blueprint session not found.',
                    style: TextStyle(color: FluxTheme.textSecondary),
                  ),
                )
              : SafeArea(
                  top: false,
                  child: Column(
                    children: <Widget>[
                      _TelemetrySummaryStrip(session: session),
                      const Divider(height: 1, thickness: 0.6, color: FluxTheme.borderSubtle),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                          child: Column(
                            children: <Widget>[
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: FluxTheme.surface,
                                    borderRadius: BorderRadius.circular(FluxTheme.radiusOuter),
                                    border: Border.all(color: FluxTheme.border, width: 0.8),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: InteractiveViewer(
                                    minScale: 0.9,
                                    maxScale: 5.0,
                                    child: Center(
                                      child: AspectRatio(
                                        aspectRatio: 1.0,
                                        child: Padding(
                                          padding: const EdgeInsets.all(14),
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
                              const SizedBox(height: 14),
                              _PaletteLegendBar(mode: session.mode),
                              const SizedBox(height: 16),
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _exporting
                                          ? null
                                          : () => unawaited(_exportPng(shareAfter: false)),
                                      icon: const Icon(Icons.save_alt, size: 17),
                                      label: const Text('Save PNG'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: _exporting
                                          ? null
                                          : () => unawaited(_exportPng(shareAfter: true)),
                                      icon: const Icon(Icons.ios_share, size: 17),
                                      label: const Text('Share PNG'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _TelemetrySummaryStrip extends StatelessWidget {
  const _TelemetrySummaryStrip({required this.session});

  final ScanSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: FluxTheme.background,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: IntrinsicHeight(
        child: Row(
          children: <Widget>[
            Expanded(
              child: _MetricCol(
                label: 'Mode',
                value: session.mode.shortLabel,
                color: session.mode.accentColor,
              ),
            ),
            const VerticalDivider(width: 1, thickness: 0.6, color: FluxTheme.borderSubtle),
            Expanded(
              child: _MetricCol(
                label: 'Peak',
                value: '${session.peakValue.toStringAsFixed(1)} ${session.mode.unit}',
              ),
            ),
            const VerticalDivider(width: 1, thickness: 0.6, color: FluxTheme.borderSubtle),
            Expanded(
              child: _MetricCol(
                label: 'Max Delta',
                value: '+${session.peakDelta.toStringAsFixed(1)} ${session.mode.unit}',
                color: FluxTheme.anomalyAmber,
              ),
            ),
            const VerticalDivider(width: 1, thickness: 0.6, color: FluxTheme.borderSubtle),
            Expanded(
              child: _MetricCol(
                label: 'Anchors',
                value: '${session.anchorCount}',
              ),
            ),
          ],
        ),
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
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: FluxTheme.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: FluxTheme.monoNumeric.copyWith(
            fontSize: 13,
            color: color ?? FluxTheme.textPrimary,
          ),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: LinearGradient(
              colors: <Color>[const Color(0xFF0A0E14), ...mode.paletteColors],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              '0% Floor',
              style: FluxTheme.monoNumeric.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: FluxTheme.textMuted,
              ),
            ),
            Text(
              '50% Mid',
              style: FluxTheme.monoNumeric.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: FluxTheme.textMuted,
              ),
            ),
            Text(
              '100% Peak',
              style: FluxTheme.monoNumeric.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: FluxTheme.textSecondary,
              ),
            ),
          ],
        ),
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
  final Paint _gridPaint = Paint()..strokeWidth = 0.7;
  final Paint _radarPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8;
  final Paint _borderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0
    ..color = FluxTheme.border;

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

    _gridPaint.color = const Color(0x22F3F5F7);
    for (int i = 1; i < 8; i++) {
      final px = size.width * (i / 8.0);
      final py = size.height * (i / 8.0);
      canvas.drawLine(Offset(px, 0), Offset(px, size.height), _gridPaint);
      canvas.drawLine(Offset(0, py), Offset(size.width, py), _gridPaint);
    }

    // Polar range rings centered on observer origin
    final center = Offset(size.width * 0.5, size.height * 0.5);
    _radarPaint.color = const Color(0x38F3F5F7);
    canvas.drawCircle(center, size.width * 0.18, _radarPaint);
    canvas.drawCircle(center, size.width * 0.36, _radarPaint);
    canvas.drawLine(
      Offset(center.dx - 6, center.dy),
      Offset(center.dx + 6, center.dy),
      _radarPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 6),
      Offset(center.dx, center.dy + 6),
      _radarPaint,
    );

    canvas.drawRect(Offset.zero & size, _borderPaint);
  }

  @override
  bool shouldRepaint(covariant _BlueprintHeatmapPainter oldDelegate) =>
      oldDelegate.mode != mode || oldDelegate.grid != grid;
}
