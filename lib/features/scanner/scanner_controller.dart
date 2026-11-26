import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../core/permissions/permission_service.dart';
import '../../core/storage/vault_models.dart';
import '../../core/utils/frame_metrics.dart';
import '../../engine/orientation_tracker.dart';
import '../../engine/scan_mode.dart';
import '../../engine/signal_isolate_worker.dart';
import '../../engine/spatial_field_engine.dart';
import '../../sensors/field_sensor_source.dart';
import '../../sensors/live_sensor_source.dart';
import '../../sensors/simulated_sensor_source.dart';
import '../vault/vault_controller.dart';
import 'scanner_state.dart';

final permissionServiceProvider = Provider<PermissionService>(
  (ref) => PermissionService(),
);

final liveSensorSourceProvider = Provider<FieldSensorSource>(
  (ref) {
    final source = LiveSensorSource();
    ref.onDispose(() {
      unawaited(source.dispose());
    });
    return source;
  },
);

final simulatedSensorSourceProvider = Provider<FieldSensorSource>(
  (ref) {
    final source = SimulatedSensorSource();
    ref.onDispose(() {
      unawaited(source.dispose());
    });
    return source;
  },
);

final scannerControllerProvider = NotifierProvider<ScannerController, ScannerState>(
  ScannerController.new,
);

/// Orchestrates hardware/simulated sensors, background DSP isolate worker,
/// calibration, Privacy Diff baselines, and atomic vault session exports.
class ScannerController extends Notifier<ScannerState> {
  SignalIsolateWorker? _worker;
  SpatialFieldEngine? _syncEngine;
  FieldSensorSource? _activeSource;
  final OrientationTracker _hudOrientation = OrientationTracker();
  final FrameMetrics _frameMetrics = FrameMetrics();
  StreamSubscription<SensorPacket>? _sensorSub;
  StreamSubscription<ProcessedFieldFrame>? _workerSub;
  double _peakSessionValue = 0.0;
  double _peakSessionDelta = 0.0;
  bool _useIsolate = true;
  int _streamEpoch = 0;

  @override
  ScannerState build() {
    ref.onDispose(() {
      unawaited(_teardown());
    });
    return ScannerState.initial();
  }

  /// Allows unit tests to toggle synchronous engine execution without spawning an isolate.
  void configureTesting({bool useIsolate = true}) {
    _useIsolate = useIsolate;
  }

  Future<void> initialize({bool? forceDemoMode}) async {
    if (state.isScanning) return;
    final useDemo = forceDemoMode ?? state.demoMode;
    state = state.copyWith(
      demoMode: useDemo,
      clearSensorAlert: true,
      permissionPermanentlyDenied: false,
    );

    await _ensureEngineReady();
    if (!ref.mounted) return;
    await _startStreamForCurrentMode();
  }

  Future<void> _ensureEngineReady() async {
    if (_useIsolate) {
      if (_worker == null) {
        final worker = SignalIsolateWorker();
        await worker.start(
          initialMode: state.mode,
          initialBaseline: state.activeBaseline?.ambientValue ?? state.mode.defaultBaseline,
        );
        if (!ref.mounted) {
          await worker.dispose();
          return;
        }
        _workerSub = worker.frames.listen(_onProcessedFrame);
        _worker = worker;
      }
    } else {
      _syncEngine ??= SpatialFieldEngine(
        initialMode: state.mode,
        initialBaseline: state.activeBaseline?.ambientValue ?? state.mode.defaultBaseline,
      );
    }
  }

  Future<void> _startStreamForCurrentMode() async {
    final epoch = ++_streamEpoch;
    await _stopActiveSource();
    if (!ref.mounted || epoch != _streamEpoch) return;

    if (!state.demoMode) {
      final perms = await ref.read(permissionServiceProvider).requestForScanner(state.mode);
      if (!ref.mounted || epoch != _streamEpoch) return;
      if (perms.message != null) {
        state = state.copyWith(
          sensorAlert: perms.message,
          permissionPermanentlyDenied: perms.anyPermanentlyDenied,
        );
      }
      if (!perms.sensorAllowed) {
        state = state.copyWith(isScanning: false, isLifecyclePaused: false);
        return;
      }
    }

    final source = state.demoMode
        ? ref.read(simulatedSensorSourceProvider)
        : ref.read(liveSensorSourceProvider);
    _activeSource = source;

    _peakSessionValue = state.mode.defaultBaseline;
    _peakSessionDelta = 0.0;
    state = state.copyWith(
      isScanning: true,
      isLifecyclePaused: false,
      bleDeviceCount: 0,
    );

    _sensorSub = source.start(state.mode).listen(_handleSensorPacket);
  }

  void _handleSensorPacket(SensorPacket packet) {
    if (!ref.mounted || state.isLifecyclePaused) return;

    switch (packet) {
      case EmPacket():
        if (_useIsolate) {
          _worker?.pushEm(packet.x, packet.y, packet.z, packet.timestampMs);
        } else {
          final frame = _syncEngine!.processEm(packet.x, packet.y, packet.z, packet.timestampMs);
          _onProcessedFrame(frame);
        }
      case RfPacket():
        if (state.bleDeviceCount != packet.deviceCount) {
          state = state.copyWith(bleDeviceCount: packet.deviceCount);
        }
        if (_useIsolate) {
          _worker?.pushRf(packet.strongestRssiDbm, packet.timestampMs);
        } else {
          final frame = _syncEngine!.processRf(packet.strongestRssiDbm, packet.timestampMs);
          _onProcessedFrame(frame);
        }
      case AcousticPacket():
        if (_useIsolate) {
          _worker?.pushAcoustic(packet.meanDecibel, packet.timestampMs);
        } else {
          final frame = _syncEngine!.processAcoustic(packet.meanDecibel, packet.timestampMs);
          _onProcessedFrame(frame);
        }
      case GyroPacket():
        _hudOrientation.applyGyroscope(
          packet.x,
          packet.y,
          packet.z,
          timestampSeconds: packet.timestampSeconds,
        );
        if (_useIsolate) {
          _worker?.pushGyro(packet.x, packet.y, packet.z, packet.timestampSeconds);
        } else {
          _syncEngine?.applyGyroscope(
            packet.x,
            packet.y,
            packet.z,
            timestampSeconds: packet.timestampSeconds,
          );
        }
      case AccelPacket():
        _hudOrientation.applyAccelerometer(packet.x, packet.y, packet.z);
        if (_useIsolate) {
          _worker?.pushAccel(packet.x, packet.y, packet.z);
        } else {
          _syncEngine?.applyAccelerometer(packet.x, packet.y, packet.z);
        }
      case OrientationPacket():
        _hudOrientation.setOrientation(packet.quaternion);
        if (_useIsolate) {
          _worker?.setOrientation(packet.quaternion);
        } else {
          _syncEngine?.setOrientation(packet.quaternion);
        }
      case SensorUnavailableEvent():
        state = state.copyWith(
          sensorAlert: packet.message,
          permissionPermanentlyDenied: packet.permanentlyDenied,
        );
    }
  }

  void _onProcessedFrame(ProcessedFieldFrame frame) {
    if (!ref.mounted) return;
    _frameMetrics.recordFrame();
    if (frame.filteredValue > _peakSessionValue || _peakSessionValue == 0.0) {
      _peakSessionValue = frame.filteredValue;
    }
    if (frame.anomalyDelta > _peakSessionDelta) {
      _peakSessionDelta = frame.anomalyDelta;
    }

    state = state.copyWith(
      frame: frame,
      fps: _frameMetrics.fps,
      frameLatencyMs: _frameMetrics.averageFrameMs,
      pitchDegrees: _hudOrientation.pitchDegrees,
      yawDegrees: _hudOrientation.yawDegrees,
    );
  }

  /// Nudges virtual camera pan when running in Demo Mode.
  void nudgeDemoPan(double dx, double dy) {
    if (!state.demoMode) return;
    final source = _activeSource;
    if (source is SimulatedSensorSource) {
      source.nudgePan(-dx * 0.005, dy * 0.005);
    }
  }

  Future<void> setMode(ScanMode mode) async {
    if (mode == state.mode) return;
    final currentBaseline = state.activeBaseline;
    final matchingBaseline = (currentBaseline != null && currentBaseline.mode == mode)
        ? currentBaseline
        : null;
    final baselineVal = matchingBaseline?.ambientValue ?? mode.defaultBaseline;

    await _ensureEngineReady();
    if (!ref.mounted) return;

    if (_useIsolate) {
      _worker?.setMode(mode, baseline: baselineVal);
    } else {
      _syncEngine?.setMode(mode, baseline: baselineVal);
    }

    final shouldRestart = state.isScanning || state.sensorAlert == null;
    state = state.copyWith(
      mode: mode,
      frame: ProcessedFieldFrame.initial(mode),
      bleDeviceCount: 0,
      activeBaseline: matchingBaseline,
      clearActiveBaseline: matchingBaseline == null,
      clearSensorAlert: true,
      permissionPermanentlyDenied: false,
    );

    if (shouldRestart) {
      await _startStreamForCurrentMode();
    }
  }

  Future<void> toggleDemoMode() async {
    final nextDemo = !state.demoMode;
    _streamEpoch++;
    await _stopActiveSource();
    if (!ref.mounted) return;

    _hudOrientation.setOrientation(Quaternion.identity());
    if (_useIsolate) {
      _worker?.setMode(
        state.mode,
        baseline: state.activeBaseline?.ambientValue ?? state.mode.defaultBaseline,
      );
    } else {
      _syncEngine?.setMode(
        state.mode,
        baseline: state.activeBaseline?.ambientValue ?? state.mode.defaultBaseline,
      );
    }
    state = state.copyWith(
      demoMode: nextDemo,
      bleDeviceCount: 0,
      clearSensorAlert: true,
      permissionPermanentlyDenied: false,
      frame: ProcessedFieldFrame.initial(state.mode),
    );
    await _ensureEngineReady();
    if (!ref.mounted) return;
    await _startStreamForCurrentMode();
  }

  void startCalibration() {
    if (_useIsolate) {
      _worker?.startCalibration();
    } else {
      _syncEngine?.startCalibration();
    }
  }

  void toggleTrailLock() {
    final next = !state.trailLock;
    if (_useIsolate) {
      _worker?.setTrailLock(next);
    } else {
      _syncEngine?.setTrailLock(next);
    }
    state = state.copyWith(trailLock: next);
  }

  void clearTrails() {
    if (_useIsolate) {
      _worker?.clearTrails();
    } else {
      _syncEngine?.clearTrails();
    }
  }

  void applyBaseline(RoomBaseline baseline) {
    final targetMode = baseline.mode;
    if (targetMode != state.mode) {
      unawaited(setMode(targetMode));
    }
    if (_useIsolate) {
      _worker?.setBaseline(baseline.ambientValue);
    } else {
      _syncEngine?.setBaseline(baseline.ambientValue);
    }
    state = state.copyWith(
      mode: targetMode,
      activeBaseline: baseline,
      statusBanner: 'Privacy Diff active: ${baseline.roomName}',
    );
  }

  void clearActiveBaseline() {
    final defVal = state.mode.defaultBaseline;
    if (_useIsolate) {
      _worker?.setBaseline(defVal);
    } else {
      _syncEngine?.setBaseline(defVal);
    }
    state = state.copyWith(clearActiveBaseline: true);
  }

  void dismissAlert() {
    state = state.copyWith(
      clearSensorAlert: true,
      permissionPermanentlyDenied: false,
    );
  }

  void setCameraReady(bool ready) {
    if (!ref.mounted) return;
    state = state.copyWith(cameraReady: ready);
  }

  Future<bool> openPermissionSettings() {
    return ref.read(permissionServiceProvider).openSettings();
  }

  Future<RoomBaseline> saveCurrentAsBaseline(String roomName, {String notes = ''}) async {
    final baseline = RoomBaseline(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      roomName: roomName.trim().isEmpty ? 'Scanned Room' : roomName.trim(),
      mode: state.mode,
      ambientValue: state.frame.filteredValue,
      notes: notes,
      createdAt: DateTime.now(),
    );
    await ref.read(vaultControllerProvider.notifier).saveBaseline(baseline);
    if (!ref.mounted) return baseline;
    applyBaseline(baseline);
    return baseline;
  }

  Future<ScanSession> saveBlueprintSnapshot({String? title}) async {
    await _ensureEngineReady();
    final Float32List grid = _useIsolate
        ? await _worker!.exportBlueprintGrid(gridSize: 32)
        : _syncEngine!.exportBlueprintGrid(gridSize: 32);

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final session = ScanSession(
      id: id,
      title: (title != null && title.trim().isNotEmpty)
          ? title.trim()
          : '${state.mode.label} Sweep',
      mode: state.mode,
      peakValue: _peakSessionValue == 0.0 ? state.frame.filteredValue : _peakSessionValue,
      peakDelta: _peakSessionDelta,
      baselineValue: state.frame.baselineValue,
      gridSize: 32,
      anchorCount: state.frame.anchorCount,
      baselineId: state.activeBaseline?.id,
      createdAt: DateTime.now(),
    );

    final storage = ref.read(localVaultStorageProvider);
    await storage.saveSession(session, grid);
    if (ref.mounted) {
      await ref.read(vaultControllerProvider.notifier).refresh();
    }
    return session;
  }

  Future<void> pauseForLifecycle() async {
    if (!ref.mounted || state.isLifecyclePaused) return;
    _streamEpoch++;
    state = state.copyWith(isLifecyclePaused: true, isScanning: false);
    await _stopActiveSource();
  }

  Future<void> resumeFromLifecycle() async {
    if (!ref.mounted || !state.isLifecyclePaused) return;
    state = state.copyWith(isLifecyclePaused: false);
    await _ensureEngineReady();
    if (!ref.mounted) return;
    await _startStreamForCurrentMode();
  }

  Future<void> _stopActiveSource() async {
    final subCancel = _sensorSub?.cancel();
    _sensorSub = null;
    final activeStop = _activeSource?.stop();
    _activeSource = null;

    await subCancel;
    await activeStop;
  }

  /// Safe teardown during `ref.onDispose`: never reads `ref` after disposal starts.
  Future<void> _teardown() async {
    _streamEpoch++;
    await _stopActiveSource();
    await _workerSub?.cancel();
    _workerSub = null;
    await _worker?.dispose();
    _worker = null;
  }
}
