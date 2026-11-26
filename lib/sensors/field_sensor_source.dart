import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart';

import '../engine/scan_mode.dart';

/// Unified telemetry packet stream emitted by live hardware or simulated sensors.
@immutable
sealed class SensorPacket {
  const SensorPacket();
}

final class EmPacket extends SensorPacket {
  const EmPacket({
    required this.x,
    required this.y,
    required this.z,
    required this.timestampMs,
  });

  final double x;
  final double y;
  final double z;
  final double timestampMs;
}

final class RfPacket extends SensorPacket {
  const RfPacket({
    required this.strongestRssiDbm,
    required this.deviceCount,
    required this.timestampMs,
  });

  final double strongestRssiDbm;
  final int deviceCount;
  final double timestampMs;
}

final class AcousticPacket extends SensorPacket {
  const AcousticPacket({
    required this.meanDecibel,
    required this.timestampMs,
    this.maxDecibel,
  });

  final double meanDecibel;
  final double? maxDecibel;
  final double timestampMs;
}

final class GyroPacket extends SensorPacket {
  const GyroPacket({
    required this.x,
    required this.y,
    required this.z,
    required this.timestampSeconds,
  });

  final double x;
  final double y;
  final double z;
  final double timestampSeconds;
}

final class AccelPacket extends SensorPacket {
  const AccelPacket({
    required this.x,
    required this.y,
    required this.z,
  });

  final double x;
  final double y;
  final double z;
}

final class OrientationPacket extends SensorPacket {
  const OrientationPacket({required this.quaternion});

  final Quaternion quaternion;
}

final class SensorUnavailableEvent extends SensorPacket {
  const SensorUnavailableEvent({
    required this.code,
    required this.message,
    this.permanentlyDenied = false,
  });

  final String code;
  final String message;
  final bool permanentlyDenied;
}

/// Hardware-independent sensor source interface enabling Demo Mode and unit tests.
abstract interface class FieldSensorSource {
  bool get isSimulated;

  Stream<SensorPacket> start(ScanMode mode);

  Future<void> stop();

  Future<void> dispose();
}
