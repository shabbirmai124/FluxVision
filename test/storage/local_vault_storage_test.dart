import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flux_vision/core/storage/local_vault_storage.dart';
import 'package:flux_vision/core/storage/vault_models.dart';
import 'package:flux_vision/engine/scan_mode.dart';

void main() {
  late Directory tempDir;
  late LocalVaultStorage storage;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('flux_vision_vault_test_');
    storage = LocalVaultStorage(rootDirectoryProvider: () async => tempDir);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('LocalVaultStorage', () {
    test('saves, loads, and deletes room baselines atomically', () async {
      final baseline = RoomBaseline(
        id: 'b1',
        roomName: 'Lab Bench',
        mode: ScanMode.em,
        ambientValue: 46.2,
        notes: 'Clean baseline',
        createdAt: DateTime(2026, 11, 26, 12, 0),
      );

      await storage.saveBaseline(baseline);
      final loaded = await storage.loadBaselines();
      expect(loaded, hasLength(1));
      expect(loaded.first.roomName, equals('Lab Bench'));
      expect(loaded.first.ambientValue, closeTo(46.2, 1e-6));

      await storage.deleteBaseline('b1');
      expect(await storage.loadBaselines(), isEmpty);
    });

    test('saves, loads, and deletes scan sessions with Float32List binary grid', () async {
      final session = ScanSession(
        id: 's1',
        title: 'Conduit Sweep',
        mode: ScanMode.rf,
        peakValue: -41.5,
        peakDelta: 40.5,
        baselineValue: -82.0,
        gridSize: 32,
        anchorCount: 6,
        createdAt: DateTime(2026, 11, 26, 12, 5),
      );

      final grid = Float32List(1024);
      grid[512] = 0.92;
      grid[100] = 0.45;

      await storage.saveSession(session, grid);

      final sessions = await storage.loadSessions();
      expect(sessions, hasLength(1));
      expect(sessions.first.id, equals('s1'));

      final loadedGrid = await storage.loadSessionGrid('s1');
      expect(loadedGrid.length, equals(1024));
      expect(loadedGrid[512], closeTo(0.92, 1e-5));
      expect(loadedGrid[100], closeTo(0.45, 1e-5));

      await storage.deleteSession('s1');
      expect(await storage.loadSessions(), isEmpty);
      final afterDelete = await storage.loadSessionGrid('s1');
      expect(afterDelete.every((v) => v == 0.0), isTrue);
    });
  });
}
