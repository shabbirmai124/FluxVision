import 'dart:async';
import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';

import '../engine/orientation_tracker.dart';
import '../engine/scan_mode.dart';
import 'field_sensor_source.dart';

class _VirtualEmitter {
  const _VirtualEmitter({
    required this.worldDir,
    required this.peakStrength,
    required this.angularSpreadRad,
  });

  final Vector3 worldDir;
  final double peakStrength;
  final double angularSpreadRad;
}

/// Deterministic 3D virtual room simulator for Demo Mode, emulators, and CI tests.
/// Places realistic hidden conduits, BLE transmitters, and acoustic sources in 3D space.
class SimulatedSensorSource implements FieldSensorSource {
  SimulatedSensorSource({
    this.tickInterval = const Duration(milliseconds: 20),
  });

  final Duration tickInterval;

  StreamController<SensorPacket>? _controller;
  Timer? _timer;
  ScanMode _mode = ScanMode.em;
  int _tickCount = 0;
  double _elapsedSec = 0.0;
  double _manualYawRad = 0.0;
  double _manualPitchRad = 0.0;
  bool _userDragged = false;

  static final List<_VirtualEmitter> _emEmitters = <_VirtualEmitter>[
    _VirtualEmitter(
      worldDir: Vector3(0.36, 0.08, -0.93).normalized(),
      peakStrength: 74.0,
      angularSpreadRad: 0.24,
    ),
    _VirtualEmitter(
      worldDir: Vector3(-0.44, -0.14, -0.89).normalized(),
      peakStrength: 52.0,
      angularSpreadRad: 0.28,
    ),
    _VirtualEmitter(
      worldDir: Vector3(0.05, 0.22, -0.97).normalized(),
      peakStrength: 38.0,
      angularSpreadRad: 0.22,
    ),
  ];

  static final List<_VirtualEmitter> _rfEmitters = <_VirtualEmitter>[
    _VirtualEmitter(
      worldDir: Vector3(-0.42, 0.06, -0.90).normalized(),
      peakStrength: 34.0,
      angularSpreadRad: 0.34,
    ),
    _VirtualEmitter(
      worldDir: Vector3(0.38, -0.09, -0.92).normalized(),
      peakStrength: 24.0,
      angularSpreadRad: 0.30,
    ),
  ];

  static final List<_VirtualEmitter> _acousticEmitters = <_VirtualEmitter>[
    _VirtualEmitter(
      worldDir: Vector3(0.14, 0.26, -0.95).normalized(),
      peakStrength: 34.0,
      angularSpreadRad: 0.30,
    ),
    _VirtualEmitter(
      worldDir: Vector3(-0.32, 0.04, -0.95).normalized(),
      peakStrength: 22.0,
      angularSpreadRad: 0.26,
    ),
  ];

  @override
  bool get isSimulated => true;

  @override
  Stream<SensorPacket> start(ScanMode mode) {
    _timer?.cancel();
    _timer = null;

    final prev = _controller;
    if (prev != null && !prev.isClosed) {
      unawaited(prev.close());
    }

    _mode = mode;
    _tickCount = 0;
    final controller = StreamController<SensorPacket>.broadcast();
    _controller = controller;

    // Emit an initial frame immediately, then tick deterministically
    _emitTick();
    _timer = Timer.periodic(tickInterval, (_) => _emitTick());
    return controller.stream;
  }

  /// Applies user drag panning in radians with bounded pitch.
  void nudgePan(double deltaYawRad, double deltaPitchRad) {
    _userDragged = true;
    _manualYawRad = ((_manualYawRad + deltaYawRad + math.pi) % (2.0 * math.pi)) - math.pi;
    _manualPitchRad = (_manualPitchRad + deltaPitchRad).clamp(-1.15, 1.15);
  }

  /// Resets manual pan offset and resumes autonomous room sweep.
  void resetPan() {
    _manualYawRad = 0.0;
    _manualPitchRad = 0.0;
    _userDragged = false;
  }

  void _emitTick() {
    final controller = _controller;
    if (controller == null || controller.isClosed) return;

    final dtSec = tickInterval.inMicroseconds / 1e6;
    _elapsedSec += dtSec;
    final timestampMs = _elapsedSec * 1000.0;

    final double yawRad;
    final double pitchRad;
    if (_userDragged) {
      yawRad = _manualYawRad;
      pitchRad = _manualPitchRad;
    } else {
      yawRad = math.sin(_elapsedSec * 0.55) * 0.52;
      pitchRad = math.sin(_elapsedSec * 0.37) * 0.18;
    }

    final yawQuat = Quaternion.axisAngle(Vector3(0.0, 1.0, 0.0), yawRad);
    final pitchQuat = Quaternion.axisAngle(Vector3(1.0, 0.0, 0.0), pitchRad);
    final orientation = (yawQuat * pitchQuat)..normalize();

    controller.add(OrientationPacket(quaternion: orientation));

    final forward = OrientationTracker.rotateBodyToWorld(
      orientation,
      Vector3(0.0, 0.0, -1.0),
    ).normalized();

    final jitter = math.sin(_elapsedSec * 19.3) * 0.9 + math.cos(_elapsedSec * 31.7) * 0.6;

    switch (_mode) {
      case ScanMode.em:
        final fieldBonus = _evaluateField(forward, _emEmitters);
        final magnitude = (ScanMode.em.defaultBaseline + fieldBonus + jitter).clamp(15.0, 220.0);
        // Project scalar magnitude onto 3-axis magnetometer components
        final mx = magnitude * 0.62;
        final my = magnitude * 0.48;
        final mz = math.sqrt(math.max(0.0, magnitude * magnitude - mx * mx - my * my));
        controller.add(EmPacket(x: mx, y: my, z: mz, timestampMs: timestampMs));

      case ScanMode.rf:
        if (_tickCount % 4 == 0) {
          final rfBonus = _evaluateField(forward, _rfEmitters);
          final rssi = (ScanMode.rf.defaultBaseline + rfBonus + jitter * 1.4).clamp(-98.0, -24.0);
          final devices = 4 + ((_tickCount ~/ 12) % 4);
          controller.add(
            RfPacket(
              strongestRssiDbm: rssi,
              deviceCount: devices,
              timestampMs: timestampMs,
            ),
          );
        }

      case ScanMode.acoustic:
        if (_tickCount % 2 == 0) {
          final acousticBonus = _evaluateField(forward, _acousticEmitters);
          final meanDb = (ScanMode.acoustic.defaultBaseline + acousticBonus + jitter * 1.1)
              .clamp(28.0, 105.0);
          controller.add(
            AcousticPacket(
              meanDecibel: meanDb,
              maxDecibel: meanDb + 3.2,
              timestampMs: timestampMs,
            ),
          );
        }
    }

    _tickCount++;
  }

  double _evaluateField(Vector3 forward, List<_VirtualEmitter> emitters) {
    double sum = 0.0;
    for (final emitter in emitters) {
      final dot = forward.dot(emitter.worldDir).clamp(-1.0, 1.0);
      final angle = math.acos(dot);
      final spreadSq = emitter.angularSpreadRad * emitter.angularSpreadRad;
      sum += emitter.peakStrength * math.exp(-(angle * angle) / (2.0 * spreadSq));
    }
    return sum;
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    final controller = _controller;
    _controller = null;
    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
  }

  @override
  Future<void> dispose() => stop();
}
