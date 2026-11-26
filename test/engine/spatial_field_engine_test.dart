import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:flux_vision/engine/scan_mode.dart';
import 'package:flux_vision/engine/spatial_field_engine.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('SpatialFieldEngine', () {
    test('trimmed-mean calibration discards outliers and updates baseline', () {
      final engine = SpatialFieldEngine(initialMode: ScanMode.em);
      engine.startCalibration();

      double? result;
      for (int i = 0; i < SpatialFieldEngine.calibrationSampleCount; i++) {
        // Inject 4 extreme outliers among 46 readings near 52.0 uT
        final sample = switch (i) {
          0 || 1 => 5.0,
          48 || 49 => 250.0,
          _ => 52.0,
        };
        result = engine.calibrateSample(sample);
      }

      expect(result, isNotNull);
      expect(result!, closeTo(52.0, 1e-6));
      expect(engine.baseline, closeTo(52.0, 1e-6));
      expect(engine.isCalibrating, isFalse);
    });

    test('projects spike within screen bounds and culls anchors behind camera', () {
      final engine = SpatialFieldEngine(initialMode: ScanMode.em, initialBaseline: 45.0);
      engine.setOrientation(Quaternion.identity());

      late ProcessedFieldFrame frame;
      for (int i = 0; i < 20; i++) {
        frame = engine.processEm(125.0, 0.0, 0.0, i * 16.0);
      }

      expect(frame.anomalyDetected, isTrue);
      expect(frame.hotspots, isNotEmpty);
      expect(frame.hotspots.first.screenX, closeTo(0.5, 1e-3));
      expect(frame.hotspots.first.screenY, closeTo(0.5, 1e-3));

      // Settle calm readings so Kalman returns to baseline while anchor stays live in front
      for (int i = 0; i < 25; i++) {
        engine.processEm(45.0, 0.0, 0.0, 320.0 + i * 16.0);
      }
      expect(engine.anchorCount, greaterThan(0));

      // Rotate 180 deg around Y -> existing anchor moves behind camera and is culled
      engine.setOrientation(Quaternion.axisAngle(Vector3(0.0, 1.0, 0.0), math.pi));
      final behindFrame = engine.processEm(45.0, 0.0, 0.0, 740.0);
      expect(behindFrame.anchorCount, greaterThan(0));
      expect(behindFrame.hotspots, isEmpty);
    });

    test('persists screen projection horizontally when panning away from anchor', () {
      final engine = SpatialFieldEngine(initialMode: ScanMode.em, initialBaseline: 45.0);
      engine.setOrientation(Quaternion.identity());
      for (int i = 0; i < 20; i++) {
        engine.processEm(125.0, 0.0, 0.0, i * 16.0);
      }
      for (int i = 0; i < 25; i++) {
        engine.processEm(45.0, 0.0, 0.0, 320.0 + i * 16.0);
      }

      // Pan phone slightly left (+15 deg yaw around +Y) -> anchor at -Z shifts right (screenX > 0.5)
      engine.setOrientation(Quaternion.axisAngle(Vector3(0.0, 1.0, 0.0), 15.0 * math.pi / 180.0));
      final pannedFrame = engine.processEm(45.0, 0.0, 0.0, 740.0);
      expect(pannedFrame.hotspots, isNotEmpty);
      expect(pannedFrame.hotspots.first.screenX, greaterThan(0.55));
    });

    test('temporal decay fades unlocked anchors while trailLock preserves them', () {
      final engine = SpatialFieldEngine(initialMode: ScanMode.em, initialBaseline: 45.0);
      for (int i = 0; i < 15; i++) {
        engine.processEm(115.0, 0.0, 0.0, i * 16.0);
      }
      expect(engine.anchorCount, greaterThan(0));

      // Lock trails and advance time across calm frames -> anchors stay preserved
      engine.setTrailLock(true);
      for (int i = 1; i <= 50; i++) {
        engine.processEm(45.0, 0.0, 0.0, 300.0 + i * 200.0);
      }
      expect(engine.anchorCount, greaterThan(0));

      // Unlock trails and advance ~12 seconds -> anchors decay away
      engine.setTrailLock(false);
      for (int i = 1; i <= 65; i++) {
        engine.processEm(45.0, 0.0, 0.0, 10500.0 + i * 200.0);
      }
      expect(engine.anchorCount, equals(0));
    });

    test('exports normalized 32x32 smoothed blueprint grid', () {
      final engine = SpatialFieldEngine(initialMode: ScanMode.rf, initialBaseline: -82.0);
      for (int i = 0; i < 10; i++) {
        engine.processRf(-38.0, i * 100.0);
      }

      final grid = engine.exportBlueprintGrid(gridSize: 32);
      expect(grid.length, equals(1024));
      final peak = grid.reduce(math.max);
      expect(peak, closeTo(1.0, 1e-4));
      expect(grid.every((v) => v >= 0.0 && v <= 1.0), isTrue);
    });
  });
}
