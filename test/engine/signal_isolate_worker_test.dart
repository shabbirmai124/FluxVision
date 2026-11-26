import 'package:flutter_test/flutter_test.dart';
import 'package:flux_vision/engine/scan_mode.dart';
import 'package:flux_vision/engine/signal_isolate_worker.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('SignalIsolateWorker', () {
    test('processes telemetry packets across background Isolate and exports 32x32 grid', () async {
      final worker = SignalIsolateWorker();
      await worker.start(initialMode: ScanMode.em, initialBaseline: 45.0);
      addTearDown(worker.dispose);

      expect(worker.isRunning, isTrue);

      final framesFuture = worker.frames.take(12).toList();
      worker.setOrientation(Quaternion.identity());
      for (int i = 0; i < 12; i++) {
        worker.pushEm(120.0, 0.0, 0.0, i * 16.0);
      }

      final frames = await framesFuture;
      expect(frames, hasLength(12));
      expect(frames.last.anomalyDetected, isTrue);
      expect(frames.last.hotspots, isNotEmpty);

      final grid = await worker.exportBlueprintGrid(gridSize: 32);
      expect(grid.length, equals(1024));
      expect(grid.any((v) => v > 0.5), isTrue);

      await worker.dispose();
      expect(worker.isRunning, isFalse);
    });
  });
}
