import 'scan_mode.dart';

/// Standard 1D Kalman filter tuned per signal domain to suppress high-frequency jitter.
class KalmanFilter1D {
  KalmanFilter1D({
    required double initialEstimate,
    required this.processNoiseQ,
    required this.measurementNoiseR,
    double initialCovariance = 1.0,
  })  : _estimate = initialEstimate,
        _errorCovariance = initialCovariance;

  factory KalmanFilter1D.forMode(ScanMode mode, {double? initialEstimate}) {
    return KalmanFilter1D(
      initialEstimate: initialEstimate ?? mode.defaultBaseline,
      processNoiseQ: mode.kalmanQ,
      measurementNoiseR: mode.kalmanR,
    );
  }

  double _estimate;
  double _errorCovariance;
  double processNoiseQ;
  double measurementNoiseR;

  double get estimate => _estimate;
  double get errorCovariance => _errorCovariance;

  /// Advances one predict-update step and returns the filtered scalar estimate.
  double update(double measurement) {
    final predictedCov = _errorCovariance + processNoiseQ;
    final gain = predictedCov / (predictedCov + measurementNoiseR);
    _estimate = _estimate + gain * (measurement - _estimate);
    _errorCovariance = (1.0 - gain) * predictedCov;
    return _estimate;
  }

  /// Resets filter state for mode switches or manual recalibration.
  void reset({
    required double estimate,
    double? processNoiseQ,
    double? measurementNoiseR,
  }) {
    _estimate = estimate;
    _errorCovariance = 1.0;
    if (processNoiseQ != null) this.processNoiseQ = processNoiseQ;
    if (measurementNoiseR != null) this.measurementNoiseR = measurementNoiseR;
  }
}
