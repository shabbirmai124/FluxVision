import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flux_vision/core/permissions/permission_service.dart';
import 'package:flux_vision/core/storage/local_vault_storage.dart';
import 'package:flux_vision/engine/scan_mode.dart';
import 'package:flux_vision/features/scanner/scanner_controller.dart';
import 'package:flux_vision/features/vault/vault_controller.dart';
import 'package:flux_vision/sensors/field_sensor_source.dart';

class _MockSensorSource implements FieldSensorSource {
  StreamController<SensorPacket>? _controller;

  @override
  bool get isSimulated => false;

  @override
  Stream<SensorPacket> start(ScanMode mode) {
    final prev = _controller;
    _controller = StreamController<SensorPacket>.broadcast();
    if (prev != null) {
      unawaited(prev.close());
    }
    return _controller!.stream;
  }

  void emit(SensorPacket packet) {
    if (!(_controller?.isClosed ?? true)) {
      _controller?.add(packet);
    }
  }

  @override
  Future<void> stop() async {
    await _controller?.close();
    _controller = null;
  }

  @override
  Future<void> dispose() => stop();
}

class _GrantedPermissionService extends PermissionService {
  @override
  Future<ScannerPermissionStatus> requestForScanner(ScanMode mode) async {
    return const ScannerPermissionStatus(
      camera: PermissionOutcome.granted,
      modeSensor: PermissionOutcome.granted,
      message: null,
    );
  }
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('flux_vision_ctrl_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('ScannerController handles live packets, sensor alerts, baselines, and snapshot export', () async {
    final mockSource = _MockSensorSource();
    final storage = LocalVaultStorage(rootDirectoryProvider: () async => tempDir);

    final container = ProviderContainer(
      overrides: [
        localVaultStorageProvider.overrideWithValue(storage),
        permissionServiceProvider.overrideWithValue(_GrantedPermissionService()),
        liveSensorSourceProvider.overrideWithValue(mockSource),
      ],
    );

    final controller = container.read(scannerControllerProvider.notifier)
      ..configureTesting(useIsolate: false);

    await controller.initialize(forceDemoMode: false);
    expect(container.read(scannerControllerProvider).isScanning, isTrue);

    // Emit magnetic spike
    for (int i = 0; i < 15; i++) {
      mockSource.emit(EmPacket(x: 120.0, y: 0.0, z: 0.0, timestampMs: i * 16.0));
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(container.read(scannerControllerProvider).frame.anomalyDetected, isTrue);

    // Emit permanent permission/hardware fallback event
    mockSource.emit(
      const SensorUnavailableEvent(
        code: 'PERMISSION_DENIED',
        message: 'Bluetooth denied',
        permanentlyDenied: true,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final alertState = container.read(scannerControllerProvider);
    expect(alertState.sensorAlert, equals('Bluetooth denied'));
    expect(alertState.permissionPermanentlyDenied, isTrue);

    // Save room baseline and activate Privacy Diff Mode
    final baseline = await controller.saveCurrentAsBaseline('Server Closet');
    expect(container.read(scannerControllerProvider).activeBaseline?.id, equals(baseline.id));

    // Save 2D blueprint snapshot and verify persisted binary grid
    final session = await controller.saveBlueprintSnapshot(title: 'Test Sweep');
    final savedGrid = await storage.loadSessionGrid(session.id);
    expect(savedGrid.length, equals(1024));

    // Dispose container cleanly without Riverpod ref-after-dispose errors
    container.dispose();
  });
}
