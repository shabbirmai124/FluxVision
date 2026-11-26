import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../engine/scan_mode.dart';
import 'field_sensor_source.dart';

/// Live smartphone hardware sensor pipeline wiring sensors_plus, flutter_blue_plus,
/// and noise_meter with defensive onError fallbacks so missing hardware never crashes.
class LiveSensorSource implements FieldSensorSource {
  StreamController<SensorPacket>? _controller;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<MagnetometerEvent>? _magSub;
  StreamSubscription<List<ScanResult>>? _bleResultsSub;
  StreamSubscription<BluetoothAdapterState>? _bleAdapterSub;
  StreamSubscription<NoiseReading>? _noiseSub;
  bool _bleScanning = false;
  bool _bleQueueConfigured = false;
  int _sessionToken = 0;

  @override
  bool get isSimulated => false;

  @override
  Stream<SensorPacket> start(ScanMode mode) {
    final token = ++_sessionToken;
    unawaited(_cancelSubscriptions());

    final controller = StreamController<SensorPacket>.broadcast();
    _controller = controller;

    _startMotionSensors(controller);
    switch (mode) {
      case ScanMode.em:
        _startMagnetometer(controller);
      case ScanMode.rf:
        unawaited(_startBleScanner(controller, token));
      case ScanMode.acoustic:
        _startNoiseMeter(controller);
    }

    return controller.stream;
  }

  void _startMotionSensors(StreamController<SensorPacket> controller) {
    try {
      _gyroSub = gyroscopeEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(
        (GyroscopeEvent e) {
          if (controller.isClosed) return;
          controller.add(
            GyroPacket(
              x: e.x,
              y: e.y,
              z: e.z,
              timestampSeconds: e.timestamp.microsecondsSinceEpoch / 1e6,
            ),
          );
        },
        onError: (Object _) {
          // Devices without a gyroscope degrade gracefully using identity orientation
        },
        cancelOnError: false,
      );
    } on MissingPluginException {
      // Non-mobile target
    } on PlatformException {
      // Unsupported gyroscope
    }

    try {
      _accelSub = accelerometerEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(
        (AccelerometerEvent e) {
          if (controller.isClosed) return;
          controller.add(AccelPacket(x: e.x, y: e.y, z: e.z));
        },
        onError: (Object _) {},
        cancelOnError: false,
      );
    } on MissingPluginException {
      // Non-mobile target
    } on PlatformException {
      // Unsupported accelerometer
    }
  }

  void _startMagnetometer(StreamController<SensorPacket> controller) {
    try {
      _magSub = magnetometerEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(
        (MagnetometerEvent e) {
          if (controller.isClosed) return;
          controller.add(
            EmPacket(
              x: e.x,
              y: e.y,
              z: e.z,
              timestampMs: e.timestamp.microsecondsSinceEpoch / 1000.0,
            ),
          );
        },
        onError: (Object _) {
          _emitUnavailable(
            controller,
            code: 'MAGNETOMETER_UNAVAILABLE',
            message: 'Magnetometer unavailable on this device. Switch to Demo Mode.',
          );
        },
        cancelOnError: false,
      );
    } on MissingPluginException {
      _emitUnavailable(
        controller,
        code: 'MAGNETOMETER_UNAVAILABLE',
        message: 'Hardware sensors unavailable on this platform. Enable Demo Mode.',
      );
    } on PlatformException catch (e) {
      _emitUnavailable(
        controller,
        code: 'MAGNETOMETER_ERROR',
        message: e.message ?? 'Magnetometer stream error. Switch to Demo Mode.',
      );
    }
  }

  Future<void> _startBleScanner(
    StreamController<SensorPacket> controller,
    int token,
  ) async {
    try {
      if (!_bleQueueConfigured) {
        FlutterBluePlus.setOperationQueueMode(OperationQueueMode.perDevice);
        _bleQueueConfigured = true;
      }

      final supported = await FlutterBluePlus.isSupported;
      if (!supported) {
        _emitUnavailable(
          controller,
          code: 'BLE_UNSUPPORTED',
          message: 'Bluetooth LE radio unavailable on this device. Enable Demo Mode.',
        );
        return;
      }

      if (token != _sessionToken || controller.isClosed) return;

      final adapterState = await FlutterBluePlus.adapterState.first.timeout(
        const Duration(seconds: 2),
        onTimeout: () => BluetoothAdapterState.unknown,
      );
      if (token != _sessionToken || controller.isClosed) return;

      if (adapterState != BluetoothAdapterState.on) {
        _emitUnavailable(
          controller,
          code: 'BLE_OFF',
          message: 'Turn on Bluetooth for live RF scanning, or enable Demo Mode.',
        );
        _bleAdapterSub = FlutterBluePlus.adapterState.listen((BluetoothAdapterState s) {
          if (s == BluetoothAdapterState.on && token == _sessionToken && !controller.isClosed) {
            unawaited(_beginBleScanStream(controller, token));
          }
        });
        return;
      }

      await _beginBleScanStream(controller, token);
    } on MissingPluginException {
      _emitUnavailable(
        controller,
        code: 'BLE_UNSUPPORTED',
        message: 'Bluetooth LE plugin unavailable on this target. Enable Demo Mode.',
      );
    } on PlatformException catch (e) {
      _emitUnavailable(
        controller,
        code: 'BLE_ERROR',
        message: e.message ?? 'Bluetooth scan error. Enable Demo Mode.',
      );
    } catch (_) {
      _emitUnavailable(
        controller,
        code: 'BLE_ERROR',
        message: 'Unable to start Bluetooth LE scan. Enable Demo Mode.',
      );
    }
  }

  Future<void> _beginBleScanStream(
    StreamController<SensorPacket> controller,
    int token,
  ) async {
    if (token != _sessionToken || controller.isClosed) return;
    await _bleResultsSub?.cancel();
    _bleResultsSub = FlutterBluePlus.scanResults.listen((List<ScanResult> results) {
      if (controller.isClosed || results.isEmpty) return;
      double strongest = -100.0;
      for (final result in results) {
        final rssi = result.rssi.toDouble();
        if (rssi < 0.0 && rssi > strongest) {
          strongest = rssi;
        }
      }
      controller.add(
        RfPacket(
          strongestRssiDbm: strongest,
          deviceCount: results.length,
          timestampMs: DateTime.now().microsecondsSinceEpoch / 1000.0,
        ),
      );
    });

    await FlutterBluePlus.startScan(
      continuousUpdates: true,
      androidUsesFineLocation: false,
    );
    _bleScanning = true;
  }

  void _startNoiseMeter(StreamController<SensorPacket> controller) {
    try {
      final meter = NoiseMeter();
      _noiseSub = meter.noise.listen(
        (NoiseReading reading) {
          if (controller.isClosed) return;
          final mean = reading.meanDecibel.isFinite
              ? reading.meanDecibel.clamp(0.0, 140.0)
              : ScanMode.acoustic.defaultBaseline;
          final maxDb = reading.maxDecibel.isFinite
              ? reading.maxDecibel.clamp(0.0, 140.0)
              : mean;
          controller.add(
            AcousticPacket(
              meanDecibel: math.max(0.0, mean),
              maxDecibel: math.max(mean, maxDb),
              timestampMs: DateTime.now().microsecondsSinceEpoch / 1000.0,
            ),
          );
        },
        onError: (Object _) {
          _emitUnavailable(
            controller,
            code: 'MICROPHONE_UNAVAILABLE',
            message: 'Microphone stream unavailable. Check permissions or enable Demo Mode.',
          );
        },
        cancelOnError: true,
      );
    } on MissingPluginException {
      _emitUnavailable(
        controller,
        code: 'MICROPHONE_UNAVAILABLE',
        message: 'Acoustic sensor unavailable on this platform. Enable Demo Mode.',
      );
    } on PlatformException catch (e) {
      _emitUnavailable(
        controller,
        code: 'MICROPHONE_ERROR',
        message: e.message ?? 'Microphone error. Enable Demo Mode.',
      );
    }
  }

  void _emitUnavailable(
    StreamController<SensorPacket> controller, {
    required String code,
    required String message,
    bool permanentlyDenied = false,
  }) {
    if (controller.isClosed) return;
    controller.add(
      SensorUnavailableEvent(
        code: code,
        message: message,
        permanentlyDenied: permanentlyDenied,
      ),
    );
  }

  Future<void> _cancelSubscriptions() async {
    final futures = <Future<void>>[
      if (_gyroSub != null) _gyroSub!.cancel(),
      if (_accelSub != null) _accelSub!.cancel(),
      if (_magSub != null) _magSub!.cancel(),
      if (_bleResultsSub != null) _bleResultsSub!.cancel(),
      if (_bleAdapterSub != null) _bleAdapterSub!.cancel(),
      if (_noiseSub != null) _noiseSub!.cancel(),
    ];
    _gyroSub = null;
    _accelSub = null;
    _magSub = null;
    _bleResultsSub = null;
    _bleAdapterSub = null;
    _noiseSub = null;

    if (futures.isNotEmpty) {
      await Future.wait<void>(futures);
    }

    if (_bleScanning) {
      _bleScanning = false;
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {
        // Ignore stop errors if Bluetooth was turned off externally
      }
    }
  }

  @override
  Future<void> stop() async {
    _sessionToken++;
    await _cancelSubscriptions();
    final controller = _controller;
    _controller = null;
    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
  }

  @override
  Future<void> dispose() => stop();
}
