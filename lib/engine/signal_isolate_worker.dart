import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:vector_math/vector_math_64.dart';

import 'scan_mode.dart';
import 'spatial_field_engine.dart';

/// Background Dart Isolate worker keeping Kalman filtering, AHRS fusion,
/// voxel management, and projection math off the UI frame thread.
class SignalIsolateWorker {
  Isolate? _isolate;
  SendPort? _workerPort;
  ReceivePort? _receivePort;
  StreamSubscription<dynamic>? _rxSub;
  final StreamController<ProcessedFieldFrame> _frameController =
      StreamController<ProcessedFieldFrame>.broadcast();

  int _nextReqId = 1;
  final Map<int, Completer<Float32List>> _gridRequests = <int, Completer<Float32List>>{};
  bool _disposed = false;

  Stream<ProcessedFieldFrame> get frames => _frameController.stream;
  bool get isRunning => _workerPort != null && !_disposed;

  Future<void> start({
    ScanMode initialMode = ScanMode.em,
    double? initialBaseline,
  }) async {
    if (_isolate != null || _disposed) return;

    final readyCompleter = Completer<SendPort>();
    _receivePort = ReceivePort();

    _rxSub = _receivePort!.listen((dynamic message) {
      if (message is SendPort) {
        if (!readyCompleter.isCompleted) {
          readyCompleter.complete(message);
        }
      } else if (message is ProcessedFieldFrame) {
        if (!_frameController.isClosed) {
          _frameController.add(message);
        }
      } else if (message is _GridResponse) {
        final completer = _gridRequests.remove(message.requestId);
        completer?.complete(message.grid);
      }
    });

    _isolate = await Isolate.spawn<_IsolateInitConfig>(
      _isolateEntry,
      _IsolateInitConfig(
        replyPort: _receivePort!.sendPort,
        initialModeIndex: initialMode.index,
        initialBaseline: initialBaseline,
      ),
      debugName: 'FluxVisionSignalWorker',
    );

    _workerPort = await readyCompleter.future;
  }

  void pushEm(double mx, double my, double mz, double timestampMs) {
    _sendCmd(Float64List.fromList(<double>[_cmdEm, mx, my, mz, timestampMs]));
  }

  void pushRf(double rssiDbm, double timestampMs) {
    _sendCmd(Float64List.fromList(<double>[_cmdRf, rssiDbm, timestampMs]));
  }

  void pushAcoustic(double dbValue, double timestampMs) {
    _sendCmd(Float64List.fromList(<double>[_cmdAcoustic, dbValue, timestampMs]));
  }

  void pushGyro(double gx, double gy, double gz, double timestampSeconds) {
    _sendCmd(Float64List.fromList(<double>[_cmdGyro, gx, gy, gz, timestampSeconds]));
  }

  void pushAccel(double ax, double ay, double az) {
    _sendCmd(Float64List.fromList(<double>[_cmdAccel, ax, ay, az]));
  }

  void setOrientation(Quaternion q) {
    _sendCmd(Float64List.fromList(<double>[_cmdSetQuat, q.x, q.y, q.z, q.w]));
  }

  void setMode(ScanMode mode, {double? baseline}) {
    _sendCmd(
      Float64List.fromList(<double>[
        _cmdSetMode,
        mode.index.toDouble(),
        baseline ?? mode.defaultBaseline,
      ]),
    );
  }

  void setBaseline(double baseline) {
    _sendCmd(Float64List.fromList(<double>[_cmdSetBaseline, baseline]));
  }

  void setTrailLock(bool locked) {
    _sendCmd(Float64List.fromList(<double>[_cmdSetTrailLock, locked ? 1.0 : 0.0]));
  }

  void clearTrails() {
    _sendCmd(Float64List.fromList(<double>[_cmdClearTrails]));
  }

  void startCalibration() {
    _sendCmd(Float64List.fromList(<double>[_cmdStartCalibration]));
  }

  Future<Float32List> exportBlueprintGrid({int gridSize = 32}) async {
    final port = _workerPort;
    if (port == null || _disposed) {
      return Float32List(gridSize * gridSize);
    }
    final reqId = _nextReqId++;
    final completer = Completer<Float32List>();
    _gridRequests[reqId] = completer;
    port.send(Float64List.fromList(<double>[_cmdExportGrid, reqId.toDouble(), gridSize.toDouble()]));
    return completer.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () {
        _gridRequests.remove(reqId);
        return Float32List(gridSize * gridSize);
      },
    );
  }

  void _sendCmd(Float64List payload) {
    if (_disposed) return;
    _workerPort?.send(payload);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _workerPort?.send(null);
    await _rxSub?.cancel();
    _receivePort?.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _workerPort = null;
    for (final c in _gridRequests.values) {
      if (!c.isCompleted) c.complete(Float32List(0));
    }
    _gridRequests.clear();
    await _frameController.close();
  }
}

const double _cmdEm = 1.0;
const double _cmdRf = 2.0;
const double _cmdAcoustic = 3.0;
const double _cmdGyro = 4.0;
const double _cmdAccel = 5.0;
const double _cmdSetQuat = 6.0;
const double _cmdSetMode = 7.0;
const double _cmdSetBaseline = 8.0;
const double _cmdSetTrailLock = 9.0;
const double _cmdClearTrails = 10.0;
const double _cmdStartCalibration = 11.0;
const double _cmdExportGrid = 12.0;

class _IsolateInitConfig {
  const _IsolateInitConfig({
    required this.replyPort,
    required this.initialModeIndex,
    required this.initialBaseline,
  });

  final SendPort replyPort;
  final int initialModeIndex;
  final double? initialBaseline;
}

class _GridResponse {
  const _GridResponse({required this.requestId, required this.grid});

  final int requestId;
  final Float32List grid;
}

void _isolateEntry(_IsolateInitConfig config) {
  final inbox = ReceivePort();
  config.replyPort.send(inbox.sendPort);

  final engine = SpatialFieldEngine(
    initialMode: ScanMode.values[config.initialModeIndex],
    initialBaseline: config.initialBaseline,
  );

  inbox.listen((dynamic message) {
    if (message == null) {
      inbox.close();
      return;
    }
    if (message is! Float64List || message.isEmpty) return;

    final cmd = message[0];
    if (cmd == _cmdEm && message.length >= 5) {
      final frame = engine.processEm(message[1], message[2], message[3], message[4]);
      config.replyPort.send(frame);
    } else if (cmd == _cmdRf && message.length >= 3) {
      final frame = engine.processRf(message[1], message[2]);
      config.replyPort.send(frame);
    } else if (cmd == _cmdAcoustic && message.length >= 3) {
      final frame = engine.processAcoustic(message[1], message[2]);
      config.replyPort.send(frame);
    } else if (cmd == _cmdGyro && message.length >= 5) {
      engine.applyGyroscope(
        message[1],
        message[2],
        message[3],
        timestampSeconds: message[4],
      );
    } else if (cmd == _cmdAccel && message.length >= 4) {
      engine.applyAccelerometer(message[1], message[2], message[3]);
    } else if (cmd == _cmdSetQuat && message.length >= 5) {
      engine.setOrientation(Quaternion(message[1], message[2], message[3], message[4]));
    } else if (cmd == _cmdSetMode && message.length >= 3) {
      final idx = message[1].round().clamp(0, ScanMode.values.length - 1);
      engine.setMode(ScanMode.values[idx], baseline: message[2]);
    } else if (cmd == _cmdSetBaseline && message.length >= 2) {
      engine.setBaseline(message[1]);
    } else if (cmd == _cmdSetTrailLock && message.length >= 2) {
      engine.setTrailLock(message[1] >= 0.5);
    } else if (cmd == _cmdClearTrails) {
      engine.clearTrails();
    } else if (cmd == _cmdStartCalibration) {
      engine.startCalibration();
    } else if (cmd == _cmdExportGrid && message.length >= 3) {
      final reqId = message[1].round();
      final size = message[2].round();
      final grid = engine.exportBlueprintGrid(gridSize: size);
      config.replyPort.send(_GridResponse(requestId: reqId, grid: grid));
    }
  });
}
