import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart';

import 'blueprint_mapper.dart';
import 'kalman_filter.dart';
import 'orientation_tracker.dart';
import 'scan_mode.dart';

@immutable
class ProjectedHotspot {
  const ProjectedHotspot({
    required this.screenX,
    required this.screenY,
    required this.intensity,
    required this.peakDelta,
  });

  final double screenX;
  final double screenY;
  final double intensity;
  final double peakDelta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectedHotspot &&
          runtimeType == other.runtimeType &&
          screenX == other.screenX &&
          screenY == other.screenY &&
          intensity == other.intensity &&
          peakDelta == other.peakDelta;

  @override
  int get hashCode => Object.hash(screenX, screenY, intensity, peakDelta);
}

@immutable
class ProcessedFieldFrame {
  const ProcessedFieldFrame({
    required this.mode,
    required this.rawValue,
    required this.filteredValue,
    required this.baselineValue,
    required this.anomalyDelta,
    required this.anomalyDetected,
    required this.hotspots,
    required this.anchorCount,
    required this.isCalibrating,
    required this.calibrationProgress,
    required this.timestampMs,
  });

  factory ProcessedFieldFrame.initial(ScanMode mode) {
    return ProcessedFieldFrame(
      mode: mode,
      rawValue: mode.defaultBaseline,
      filteredValue: mode.defaultBaseline,
      baselineValue: mode.defaultBaseline,
      anomalyDelta: 0.0,
      anomalyDetected: false,
      hotspots: const <ProjectedHotspot>[],
      anchorCount: 0,
      isCalibrating: false,
      calibrationProgress: 0.0,
      timestampMs: 0,
    );
  }

  final ScanMode mode;
  final double rawValue;
  final double filteredValue;
  final double baselineValue;
  final double anomalyDelta;
  final bool anomalyDetected;
  final List<ProjectedHotspot> hotspots;
  final int anchorCount;
  final bool isCalibrating;
  final double calibrationProgress;
  final int timestampMs;

  ProjectedHotspot? get peakHotspot {
    if (hotspots.isEmpty) return null;
    return hotspots.first;
  }

  ProcessedFieldFrame copyWith({
    bool? isCalibrating,
    double? calibrationProgress,
  }) {
    return ProcessedFieldFrame(
      mode: mode,
      rawValue: rawValue,
      filteredValue: filteredValue,
      baselineValue: baselineValue,
      anomalyDelta: anomalyDelta,
      anomalyDetected: anomalyDetected,
      hotspots: hotspots,
      anchorCount: anchorCount,
      isCalibrating: isCalibrating ?? this.isCalibrating,
      calibrationProgress: calibrationProgress ?? this.calibrationProgress,
      timestampMs: timestampMs,
    );
  }
}

class _SpatialAnchor {
  _SpatialAnchor({
    required this.worldDir,
    required this.intensity,
    required this.peakDelta,
  });

  Vector3 worldDir;
  double intensity;
  double peakDelta;
}

/// Core 3D spatial signal processing engine implementing Kalman filtering,
/// trimmed-mean baseline calibration, spherical anchor merging, temporal decay,
/// and perspective UV camera projection.
class SpatialFieldEngine {
  SpatialFieldEngine({
    ScanMode initialMode = ScanMode.em,
    double? initialBaseline,
    OrientationTracker? orientationTracker,
  })  : _mode = initialMode,
        _baseline = initialBaseline ?? initialMode.defaultBaseline,
        _kalman = KalmanFilter1D.forMode(
          initialMode,
          initialEstimate: initialBaseline ?? initialMode.defaultBaseline,
        ),
        _orientation = orientationTracker ?? OrientationTracker();

  static const int maxAnchorPool = 48;
  static const int maxProjectedHotspots = 12;
  static const int calibrationSampleCount = 50;
  static const double mergeAngularThresholdRad = 0.12;
  static const double decayLambdaPerSec = 0.28;
  static const double fovScale = 0.85;

  ScanMode _mode;
  double _baseline;
  bool _trailLock = false;
  final KalmanFilter1D _kalman;
  final OrientationTracker _orientation;
  final List<_SpatialAnchor> _anchors = <_SpatialAnchor>[];

  final List<double> _calibrationBuffer = <double>[];
  bool _isCalibrating = false;
  double _lastTimestampMs = 0.0;

  ScanMode get mode => _mode;
  double get baseline => _baseline;
  bool get trailLock => _trailLock;
  bool get isCalibrating => _isCalibrating;
  int get anchorCount => _anchors.length;
  OrientationTracker get orientation => _orientation;

  void setMode(ScanMode mode, {double? baseline}) {
    _mode = mode;
    _baseline = baseline ?? mode.defaultBaseline;
    _kalman.reset(
      estimate: _baseline,
      processNoiseQ: mode.kalmanQ,
      measurementNoiseR: mode.kalmanR,
    );
    _anchors.clear();
    _calibrationBuffer.clear();
    _isCalibrating = false;
    _lastTimestampMs = 0.0;
  }

  void setBaseline(double baseline) {
    _baseline = baseline;
  }

  void setTrailLock(bool locked) {
    _trailLock = locked;
  }

  void clearTrails() {
    _anchors.clear();
  }

  void startCalibration() {
    _calibrationBuffer.clear();
    _isCalibrating = true;
  }

  /// Feeds a single calibration sample; returns finalized trimmed mean once
  /// [calibrationSampleCount] samples are collected, or `null` while collecting.
  double? calibrateSample(double rawValue) {
    if (!_isCalibrating) {
      _isCalibrating = true;
      _calibrationBuffer.clear();
    }
    _calibrationBuffer.add(rawValue);
    if (_calibrationBuffer.length < calibrationSampleCount) {
      return null;
    }

    final sorted = List<double>.from(_calibrationBuffer)..sort();
    final trim = (sorted.length * 0.1).floor();
    final slice = sorted.sublist(trim, sorted.length - trim);
    final sum = slice.fold<double>(0.0, (acc, v) => acc + v);
    final trimmedMean = sum / slice.length;

    _baseline = trimmedMean;
    _kalman.reset(estimate: trimmedMean);
    _isCalibrating = false;
    _calibrationBuffer.clear();
    return trimmedMean;
  }

  void applyGyroscope(double gx, double gy, double gz, {double? timestampSeconds, double? deltaSeconds}) {
    _orientation.applyGyroscope(
      gx,
      gy,
      gz,
      timestampSeconds: timestampSeconds,
      deltaSeconds: deltaSeconds,
    );
  }

  void applyAccelerometer(double ax, double ay, double az) {
    _orientation.applyAccelerometer(ax, ay, az);
  }

  void setOrientation(Quaternion quaternion) {
    _orientation.setOrientation(quaternion);
  }

  ProcessedFieldFrame processEm(double mx, double my, double mz, double timestampMs) {
    final rawMagnitude = math.sqrt(mx * mx + my * my + mz * mz);
    return _processScalar(rawMagnitude, timestampMs);
  }

  ProcessedFieldFrame processRf(double rssiDbm, double timestampMs) {
    return _processScalar(rssiDbm, timestampMs);
  }

  ProcessedFieldFrame processAcoustic(double dbValue, double timestampMs) {
    return _processScalar(dbValue, timestampMs);
  }

  ProcessedFieldFrame _processScalar(double rawValue, double timestampMs) {
    if (_isCalibrating) {
      calibrateSample(rawValue);
    }

    final filtered = _kalman.update(rawValue);
    final delta = switch (_mode) {
      ScanMode.em => (filtered - _baseline).abs(),
      ScanMode.rf || ScanMode.acoustic => filtered - _baseline,
    };

    final intensity = ((delta - _mode.deadband) / _mode.span).clamp(0.0, 1.0);
    final dtSec = _computeDeltaSeconds(timestampMs);

    _updateAnchors(intensity, delta, dtSec);
    final projected = _projectVisibleHotspots();

    final progress = _isCalibrating
        ? (_calibrationBuffer.length / calibrationSampleCount).clamp(0.0, 1.0)
        : 0.0;

    return ProcessedFieldFrame(
      mode: _mode,
      rawValue: rawValue,
      filteredValue: filtered,
      baselineValue: _baseline,
      anomalyDelta: math.max(0.0, delta),
      anomalyDetected: intensity > 0.12,
      hotspots: projected,
      anchorCount: _anchors.length,
      isCalibrating: _isCalibrating,
      calibrationProgress: progress,
      timestampMs: timestampMs.round(),
    );
  }

  double _computeDeltaSeconds(double timestampMs) {
    if (_lastTimestampMs <= 0.0) {
      _lastTimestampMs = timestampMs;
      return 0.016;
    }
    final dt = (timestampMs - _lastTimestampMs) / 1000.0;
    _lastTimestampMs = timestampMs;
    return dt.clamp(0.001, 0.25);
  }

  void _updateAnchors(double intensity, double delta, double dtSec) {
    if (!_trailLock && _anchors.isNotEmpty) {
      final decayFactor = math.exp(-decayLambdaPerSec * dtSec);
      for (final anchor in _anchors) {
        anchor.intensity *= decayFactor;
      }
      _anchors.removeWhere((a) => a.intensity < 0.04);
    }

    if (intensity <= 0.12) return;

    final forward = _orientation.forwardWorld;
    final cosThreshold = math.cos(mergeAngularThresholdRad);

    for (final anchor in _anchors) {
      if (anchor.worldDir.dot(forward) >= cosThreshold) {
        anchor.worldDir = (anchor.worldDir * 0.75 + forward * 0.25).normalized();
        if (intensity > anchor.intensity) {
          anchor.intensity = intensity;
        }
        if (delta > anchor.peakDelta) {
          anchor.peakDelta = delta;
        }
        return;
      }
    }

    if (_anchors.length >= maxAnchorPool) {
      _anchors.removeAt(0);
    }
    _anchors.add(
      _SpatialAnchor(
        worldDir: forward,
        intensity: intensity,
        peakDelta: math.max(0.0, delta),
      ),
    );
  }

  List<ProjectedHotspot> _projectVisibleHotspots() {
    if (_anchors.isEmpty) return const <ProjectedHotspot>[];

    final currentQuat = _orientation.currentOrientation;
    final visible = <ProjectedHotspot>[];

    for (final anchor in _anchors) {
      final local = OrientationTracker.rotateWorldToBody(currentQuat, anchor.worldDir);
      if (local.z >= -0.15) continue;

      final u = 0.5 + 0.5 * ((local.x / -local.z) * fovScale);
      final v = 0.5 + 0.5 * ((-local.y / -local.z) * fovScale);

      if (u >= -0.15 && u <= 1.15 && v >= -0.15 && v <= 1.15) {
        visible.add(
          ProjectedHotspot(
            screenX: u,
            screenY: v,
            intensity: anchor.intensity,
            peakDelta: anchor.peakDelta,
          ),
        );
      }
    }

    visible.sort((a, b) => b.intensity.compareTo(a.intensity));
    if (visible.length > maxProjectedHotspots) {
      return visible.sublist(0, maxProjectedHotspots);
    }
    return visible;
  }

  /// Projects active 3D anchors onto a smoothed 2D top-down intensity matrix.
  Float32List exportBlueprintGrid({int gridSize = BlueprintMapper.defaultGridSize}) {
    final inputs = _anchors
        .map((a) => BlueprintAnchorInput(worldDir: a.worldDir, intensity: a.intensity))
        .toList(growable: false);
    return BlueprintMapper.buildGrid(inputs, gridSize: gridSize);
  }
}
