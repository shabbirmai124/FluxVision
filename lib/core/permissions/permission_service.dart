import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../engine/scan_mode.dart';

enum PermissionOutcome {
  granted,
  denied,
  permanentlyDenied,
  unsupportedPlatform,
}

@immutable
class ScannerPermissionStatus {
  const ScannerPermissionStatus({
    required this.camera,
    required this.modeSensor,
    required this.message,
  });

  final PermissionOutcome camera;
  final PermissionOutcome modeSensor;
  final String? message;

  bool get cameraAllowed =>
      camera == PermissionOutcome.granted ||
      camera == PermissionOutcome.unsupportedPlatform;

  bool get sensorAllowed =>
      modeSensor == PermissionOutcome.granted ||
      modeSensor == PermissionOutcome.unsupportedPlatform;

  bool get anyPermanentlyDenied =>
      camera == PermissionOutcome.permanentlyDenied ||
      modeSensor == PermissionOutcome.permanentlyDenied;
}

/// UI-isolate runtime permission orchestrator with platform-specific BLE,
/// microphone, and camera handling plus graceful desktop/emulator fallbacks.
class PermissionService {
  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<ScannerPermissionStatus> requestForScanner(ScanMode mode) async {
    if (!_isMobile) {
      return const ScannerPermissionStatus(
        camera: PermissionOutcome.unsupportedPlatform,
        modeSensor: PermissionOutcome.unsupportedPlatform,
        message: 'Running on non-mobile target; Demo Mode is recommended.',
      );
    }

    try {
      final camStatus = await Permission.camera.request();
      final camResult = _mapStatus(camStatus);
      PermissionOutcome sensorResult = PermissionOutcome.granted;
      String? msg;

      if (mode == ScanMode.rf) {
        final bleOutcome = await _requestBluetoothPermissions();
        sensorResult = bleOutcome.$1;
        msg = bleOutcome.$2;
      } else if (mode == ScanMode.acoustic) {
        final micStatus = await Permission.microphone.request();
        sensorResult = _mapStatus(micStatus);
        if (sensorResult != PermissionOutcome.granted) {
          msg = sensorResult == PermissionOutcome.permanentlyDenied
              ? 'Microphone permission permanently denied. Open Settings or use Demo Mode.'
              : 'Microphone permission is required for live Acoustic decibel mapping.';
        }
      }

      if (camResult != PermissionOutcome.granted && msg == null) {
        msg = camResult == PermissionOutcome.permanentlyDenied
            ? 'Camera permission permanently denied; using calibrated dark HUD.'
            : 'Camera permission declined; showing calibrated dark HUD backdrop.';
      }

      return ScannerPermissionStatus(
        camera: camResult,
        modeSensor: sensorResult,
        message: msg,
      );
    } on MissingPluginException {
      return const ScannerPermissionStatus(
        camera: PermissionOutcome.unsupportedPlatform,
        modeSensor: PermissionOutcome.unsupportedPlatform,
        message: 'Permission plugin unavailable in test/desktop runner.',
      );
    } on PlatformException catch (e) {
      return ScannerPermissionStatus(
        camera: PermissionOutcome.denied,
        modeSensor: PermissionOutcome.denied,
        message: e.message ?? 'Hardware permission error.',
      );
    }
  }

  Future<(PermissionOutcome, String?)> _requestBluetoothPermissions() async {
    if (Platform.isIOS) {
      // iOS maps CoreBluetooth permission solely to Permission.bluetooth (NSBluetoothAlwaysUsageDescription).
      final btStatus = await Permission.bluetooth.request();
      final outcome = _mapStatus(btStatus);
      if (outcome == PermissionOutcome.granted) {
        return (PermissionOutcome.granted, null);
      }
      final msg = outcome == PermissionOutcome.permanentlyDenied
          ? 'Bluetooth permission permanently denied in iOS Settings.'
          : 'Bluetooth access is required for live BLE RF scanning.';
      return (outcome, msg);
    }

    // Android 12+ uses BLUETOOTH_SCAN (neverForLocation) + BLUETOOTH_CONNECT.
    final statuses = await <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    final scanStatus = statuses[Permission.bluetoothScan] ?? PermissionStatus.denied;
    final connectStatus = statuses[Permission.bluetoothConnect] ?? PermissionStatus.denied;

    if (scanStatus.isGranted && connectStatus.isGranted) {
      return (PermissionOutcome.granted, null);
    }

    final permDenied = scanStatus.isPermanentlyDenied || connectStatus.isPermanentlyDenied;
    final outcome = permDenied ? PermissionOutcome.permanentlyDenied : PermissionOutcome.denied;
    final msg = permDenied
        ? 'Nearby Devices permission permanently denied. Open Settings or switch to Demo Mode.'
        : 'Bluetooth scan permission is needed for live RF telemetry.';
    return (outcome, msg);
  }

  /// Requests legacy location permission required for BLE scanning on Android 11 (API 30) and lower.
  Future<bool> requestLegacyAndroidLocationIfNeeded() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final status = await Permission.locationWhenInUse.request();
      return status.isGranted;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> openSettings() async {
    if (!_isMobile) return false;
    try {
      return await openAppSettings();
    } on MissingPluginException {
      return false;
    }
  }

  PermissionOutcome _mapStatus(PermissionStatus status) {
    if (status.isGranted || status.isLimited) {
      return PermissionOutcome.granted;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return PermissionOutcome.permanentlyDenied;
    }
    return PermissionOutcome.denied;
  }
}
