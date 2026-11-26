import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:flux_vision/engine/kalman_filter.dart';
import 'package:flux_vision/engine/scan_mode.dart';

void main() {
  group('KalmanFilter1D', () {
    test('suppresses high-frequency sine jitter around 45 uT baseline', () {
      final filter = KalmanFilter1D.forMode(ScanMode.em, initialEstimate: 45.0);
      double maxDeviation = 0.0;

      for (int i = 0; i < 120; i++) {
        final noisy = 45.0 + math.sin(i * 0.9) * 4.5;
        final estimate = filter.update(noisy);
        maxDeviation = math.max(maxDeviation, (estimate - 45.0).abs());
      }

      expect(maxDeviation, lessThan(2.2));
    });

    test('converges rapidly on sustained 120 uT step spike', () {
      final filter = KalmanFilter1D.forMode(ScanMode.em, initialEstimate: 45.0);
      double estimate = 45.0;
      for (int i = 0; i < 30; i++) {
        estimate = filter.update(120.0);
      }
      expect(estimate, greaterThan(115.0));
    });

    test('resets cleanly with new baseline and tuning', () {
      final filter = KalmanFilter1D.forMode(ScanMode.rf);
      filter.update(-35.0);
      filter.reset(
        estimate: -80.0,
        processNoiseQ: ScanMode.acoustic.kalmanQ,
        measurementNoiseR: ScanMode.acoustic.kalmanR,
      );
      expect(filter.estimate, equals(-80.0));
      expect(filter.errorCovariance, equals(1.0));
    });
  });
}
