import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';

/// 6-DOF complementary AHRS orientation tracker fusing gyroscope integration
/// with accelerometer gravity alignment.
///
/// Coordinate convention (portrait upright phone):
/// - `+X`: right edge of device
/// - `+Y`: top edge of device (world up when upright)
/// - `-Z`: camera look direction out the back of the device
///
/// Note on `package:vector_math` [Quaternion.rotated]:
/// `q.rotated(v)` computes `q^-1 * v * q` (world-to-body transform).
/// `q.conjugated().rotated(v)` computes `q * v * q^-1` (body-to-world transform).
class OrientationTracker {
  OrientationTracker({this.complementaryAlpha = 0.98});

  final double complementaryAlpha;
  Quaternion _orientation = Quaternion.identity();
  double? _lastGyroTimestampSec;

  Quaternion get currentOrientation => _orientation.clone();

  /// Active right-handed rotation from body frame to world frame (`q * v * q^-1`).
  static Vector3 rotateBodyToWorld(Quaternion q, Vector3 localVec) {
    return q.conjugated().rotated(localVec);
  }

  /// Active right-handed transform from world frame to body frame (`q^-1 * v * q`).
  static Vector3 rotateWorldToBody(Quaternion q, Vector3 worldVec) {
    return q.rotated(worldVec);
  }

  /// Forward camera look vector in world space (`-Z` in local phone frame).
  Vector3 get forwardWorld =>
      rotateBodyToWorld(_orientation, Vector3(0.0, 0.0, -1.0)).normalized();

  /// Pitch angle in degrees (`-90..+90`, positive when camera tilts upward).
  double get pitchDegrees {
    final fwd = forwardWorld;
    final horiz = math.sqrt(fwd.x * fwd.x + fwd.z * fwd.z).clamp(1e-9, 1.0);
    return math.atan2(fwd.y, horiz) * 180.0 / math.pi;
  }

  /// Yaw angle in degrees (`-180..+180`).
  double get yawDegrees {
    final fwd = forwardWorld;
    return math.atan2(fwd.x, -fwd.z) * 180.0 / math.pi;
  }

  /// Integrates angular rate `(gx, gy, gz)` in rad/s over clamped delta time.
  void applyGyroscope(
    double gx,
    double gy,
    double gz, {
    double? timestampSeconds,
    double? deltaSeconds,
  }) {
    final double dt;
    if (deltaSeconds != null) {
      dt = deltaSeconds;
    } else if (timestampSeconds != null) {
      if (_lastGyroTimestampSec == null) {
        _lastGyroTimestampSec = timestampSeconds;
        return;
      }
      dt = timestampSeconds - _lastGyroTimestampSec!;
      _lastGyroTimestampSec = timestampSeconds;
    } else {
      dt = 0.016;
    }

    final clampedDt = dt.clamp(0.001, 0.1);
    final omega = Vector3(gx, gy, gz);
    final angle = omega.length * clampedDt;
    if (angle < 1e-8) return;

    final axis = omega.normalized();
    final deltaQuat = Quaternion.axisAngle(axis, angle);
    _orientation = (_orientation * deltaQuat)..normalize();
  }

  /// Gently pulls pitch/roll toward gravity reaction vector using complementary weight `alpha`.
  void applyAccelerometer(double ax, double ay, double az) {
    final accel = Vector3(ax, ay, az);
    final norm = accel.length;
    if (norm < 1e-3) return;

    final measuredUpLocal = accel / norm;
    // Expected local up vector when world +Y is vertical up: q^-1 * (0, 1, 0) * q.
    final expectedUpLocal =
        rotateWorldToBody(_orientation, Vector3(0.0, 1.0, 0.0)).normalized();

    final dot = expectedUpLocal.dot(measuredUpLocal).clamp(-1.0, 1.0);
    final angle = math.acos(dot);
    if (angle < 1e-4) return;

    final axis = expectedUpLocal.cross(measuredUpLocal);
    if (axis.length2 < 1e-8) return;
    axis.normalize();

    // Rotate q so q^-1 * worldUp moves toward measuredUpLocal:
    // (q * R_corr^-1)^-1 * worldUp = R_corr * (q^-1 * worldUp).
    final correctionStep = (1.0 - complementaryAlpha) * angle;
    final correction = Quaternion.axisAngle(axis, correctionStep);
    _orientation = (_orientation * correction.conjugated())..normalize();
  }

  /// Directly sets orientation (used by virtual Demo simulator and deterministic tests).
  void setOrientation(Quaternion orientation) {
    if (orientation.length2 < 1e-9) {
      _orientation = Quaternion.identity();
    } else {
      _orientation = orientation.normalized();
    }
  }

  void reset() {
    _orientation = Quaternion.identity();
    _lastGyroTimestampSec = null;
  }
}
