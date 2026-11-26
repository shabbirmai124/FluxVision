import 'package:flutter/foundation.dart';
import '../../core/storage/vault_models.dart';
import '../../engine/scan_mode.dart';
import '../../engine/spatial_field_engine.dart';

@immutable
class ScannerState {
  const ScannerState({
    required this.mode,
    required this.frame,
    required this.trailLock,
    required this.demoMode,
    required this.isScanning,
    required this.isLifecyclePaused,
    required this.fps,
    required this.frameLatencyMs,
    required this.pitchDegrees,
    required this.yawDegrees,
    required this.cameraReady,
    this.bleDeviceCount = 0,
    this.permissionPermanentlyDenied = false,
    this.activeBaseline,
    this.sensorAlert,
    this.statusBanner,
  });

  factory ScannerState.initial({bool demoMode = false}) {
    return ScannerState(
      mode: ScanMode.em,
      frame: ProcessedFieldFrame.initial(ScanMode.em),
      trailLock: false,
      demoMode: demoMode,
      isScanning: false,
      isLifecyclePaused: false,
      fps: 60,
      frameLatencyMs: 16.6,
      pitchDegrees: 0.0,
      yawDegrees: 0.0,
      cameraReady: false,
    );
  }

  final ScanMode mode;
  final ProcessedFieldFrame frame;
  final bool trailLock;
  final bool demoMode;
  final bool isScanning;
  final bool isLifecyclePaused;
  final int fps;
  final double frameLatencyMs;
  final double pitchDegrees;
  final double yawDegrees;
  final bool cameraReady;
  final int bleDeviceCount;
  final bool permissionPermanentlyDenied;
  final RoomBaseline? activeBaseline;
  final String? sensorAlert;
  final String? statusBanner;

  ScannerState copyWith({
    ScanMode? mode,
    ProcessedFieldFrame? frame,
    bool? trailLock,
    bool? demoMode,
    bool? isScanning,
    bool? isLifecyclePaused,
    int? fps,
    double? frameLatencyMs,
    double? pitchDegrees,
    double? yawDegrees,
    bool? cameraReady,
    int? bleDeviceCount,
    bool? permissionPermanentlyDenied,
    RoomBaseline? activeBaseline,
    bool clearActiveBaseline = false,
    String? sensorAlert,
    bool clearSensorAlert = false,
    String? statusBanner,
    bool clearStatusBanner = false,
  }) {
    return ScannerState(
      mode: mode ?? this.mode,
      frame: frame ?? this.frame,
      trailLock: trailLock ?? this.trailLock,
      demoMode: demoMode ?? this.demoMode,
      isScanning: isScanning ?? this.isScanning,
      isLifecyclePaused: isLifecyclePaused ?? this.isLifecyclePaused,
      fps: fps ?? this.fps,
      frameLatencyMs: frameLatencyMs ?? this.frameLatencyMs,
      pitchDegrees: pitchDegrees ?? this.pitchDegrees,
      yawDegrees: yawDegrees ?? this.yawDegrees,
      cameraReady: cameraReady ?? this.cameraReady,
      bleDeviceCount: bleDeviceCount ?? this.bleDeviceCount,
      permissionPermanentlyDenied:
          permissionPermanentlyDenied ?? this.permissionPermanentlyDenied,
      activeBaseline: clearActiveBaseline ? null : (activeBaseline ?? this.activeBaseline),
      sensorAlert: clearSensorAlert ? null : (sensorAlert ?? this.sensorAlert),
      statusBanner: clearStatusBanner ? null : (statusBanner ?? this.statusBanner),
    );
  }
}
