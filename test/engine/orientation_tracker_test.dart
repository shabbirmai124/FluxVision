import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:flux_vision/engine/orientation_tracker.dart';

void main() {
  group('OrientationTracker', () {
    test('integrates gyroscope while maintaining unit quaternion normalization', () {
      final tracker = OrientationTracker();
      for (int i = 0; i < 50; i++) {
        tracker.applyGyroscope(0.2, 0.8, -0.1, deltaSeconds: 0.016);
      }

      final q = tracker.currentOrientation;
      expect(q.length, closeTo(1.0, 1e-6));
    });

    test('tracks 90-degree yaw rotation smoothly', () {
      final tracker = OrientationTracker();
      // Rotate around +Y axis at pi/2 rad/s for 1 second in 50ms chunks
      for (int i = 0; i < 20; i++) {
        tracker.applyGyroscope(0.0, math.pi / 2.0, 0.0, deltaSeconds: 0.05);
      }

      expect(tracker.yawDegrees.abs(), closeTo(90.0, 1.5));
    });

    test('applies complementary gravity correction and resets cleanly', () {
      final tracker = OrientationTracker(complementaryAlpha: 0.90);
      // Induce a pitched gyro error first
      tracker.applyGyroscope(0.8, 0.0, 0.0, deltaSeconds: 0.1);
      final pitchedBefore = tracker.pitchDegrees.abs();

      // Apply upright gravity reaction (0, +9.81, 0) repeatedly
      for (int i = 0; i < 60; i++) {
        tracker.applyAccelerometer(0.0, 9.81, 0.0);
      }

      expect(tracker.pitchDegrees.abs(), lessThan(pitchedBefore));

      tracker.reset();
      expect(tracker.yawDegrees, closeTo(0.0, 1e-6));
      expect(tracker.pitchDegrees, closeTo(0.0, 1e-6));
    });
  });
}
