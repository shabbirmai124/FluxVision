import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flux_vision/app/theme.dart';
import 'package:flux_vision/core/storage/local_vault_storage.dart';
import 'package:flux_vision/core/storage/vault_models.dart';
import 'package:flux_vision/engine/scan_mode.dart';
import 'package:flux_vision/features/blueprint/blueprint_png_exporter.dart';
import 'package:flux_vision/features/blueprint/blueprint_screen.dart';
import 'package:flux_vision/features/vault/vault_controller.dart';
import 'package:flux_vision/features/vault/vault_screen.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late Directory tempDir;
  late LocalVaultStorage storage;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('flux_vision_vb_test_');
    storage = LocalVaultStorage(rootDirectoryProvider: () async => tempDir);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('sampleBilinearGrid and interpolatePalette produce bounded smooth values', () {
    final grid = Float32List(16);
    grid[5] = 1.0;
    grid[6] = 0.5;
    final mid = sampleBilinearGrid(grid, 4, 0.5, 0.33);
    expect(mid, inInclusiveRange(0.0, 1.0));
    expect(interpolatePalette(ScanMode.em, 0.0).toARGB32(), equals(0xFF0A1019));
    expect(interpolatePalette(ScanMode.rf, 0.95).a, closeTo(1.0, 1e-6));
  });

  testWidgets('VaultScreen displays saved baselines and scan blueprints', (tester) async {
    await tester.runAsync(() async {
      await storage.saveBaseline(
        RoomBaseline(
          id: 'b1',
          roomName: 'Server Closet',
          mode: ScanMode.em,
          ambientValue: 48.5,
          createdAt: DateTime(2026, 11, 26, 10, 0),
        ),
      );
      await storage.saveSession(
        ScanSession(
          id: 's1',
          title: 'Router Sweep',
          mode: ScanMode.rf,
          peakValue: -38.0,
          peakDelta: 44.0,
          baselineValue: -82.0,
          gridSize: 32,
          anchorCount: 5,
          createdAt: DateTime(2026, 11, 26, 10, 5),
        ),
        Float32List(1024)..[512] = 0.9,
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localVaultStorageProvider.overrideWithValue(storage),
        ],
        child: MaterialApp(
          theme: FluxTheme.dark(),
          home: const VaultScreen(),
        ),
      ),
    );

    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    await tester.pump();

    expect(find.text('Server Closet'), findsOneWidget);

    await tester.tap(find.text('Scan Blueprints'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Router Sweep'), findsOneWidget);
  });

  testWidgets('BlueprintScreen loads session grid and renders 2D heatmap viewer', (tester) async {
    await tester.runAsync(() async {
      await storage.saveSession(
        ScanSession(
          id: 's2',
          title: 'Acoustic Vent Check',
          mode: ScanMode.acoustic,
          peakValue: 74.2,
          peakDelta: 32.2,
          baselineValue: 42.0,
          gridSize: 32,
          anchorCount: 3,
          createdAt: DateTime(2026, 11, 26, 11, 0),
        ),
        Float32List(1024)..[256] = 0.85,
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localVaultStorageProvider.overrideWithValue(storage),
        ],
        child: MaterialApp(
          theme: FluxTheme.dark(),
          home: const BlueprintScreen(sessionId: 's2'),
        ),
      ),
    );

    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    await tester.pump();

    expect(find.text('Acoustic Vent Check'), findsOneWidget);
    expect(find.text('Save PNG'), findsOneWidget);
    expect(find.text('Share PNG'), findsOneWidget);
  });
}
