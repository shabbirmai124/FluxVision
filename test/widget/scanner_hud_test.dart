import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flux_vision/app/theme.dart';
import 'package:flux_vision/core/storage/local_vault_storage.dart';
import 'package:flux_vision/features/scanner/scanner_controller.dart';
import 'package:flux_vision/features/scanner/scanner_screen.dart';
import 'package:flux_vision/features/vault/vault_controller.dart';
import 'package:flux_vision/sensors/simulated_sensor_source.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('flux_vision_widget_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('ScannerScreen renders HUD in Demo Mode, switches modes, and locks trails', (tester) async {
    final simSource = SimulatedSensorSource(tickInterval: const Duration(milliseconds: 25));
    final container = ProviderContainer(
      overrides: [
        localVaultStorageProvider.overrideWithValue(
          LocalVaultStorage(rootDirectoryProvider: () async => tempDir),
        ),
        simulatedSensorSourceProvider.overrideWithValue(simSource),
      ],
    );
    addTearDown(() {
      unawaited(simSource.dispose());
      container.dispose();
    });

    container.read(scannerControllerProvider.notifier).configureTesting(useIsolate: false);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: FluxTheme.dark(),
          home: const ScannerScreen(
            enableHardwareCamera: false,
            autoInitialize: false,
          ),
        ),
      ),
    );

    unawaited(container.read(scannerControllerProvider.notifier).initialize(forceDemoMode: true));
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('DEMO ON'), findsOneWidget);
    expect(find.text('EM µT'), findsOneWidget);

    // Switch to RF mode
    await tester.tap(find.text('RF'));
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('RF dBm'), findsOneWidget);
    expect(find.textContaining('BLE'), findsOneWidget);

    // Switch to Acoustic mode
    await tester.tap(find.text('SND'));
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('SND dB'), findsOneWidget);

    // Toggle Trail Lock
    await tester.tap(find.text('Trail Lock'));
    await tester.pump();
    expect(find.text('Locked'), findsOneWidget);

    // Start 1-second Calibration
    await tester.tap(find.text('Calibrate'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Calibrating'), findsOneWidget);

    unawaited(container.read(scannerControllerProvider.notifier).pauseForLifecycle());
    await tester.pump();
  });
}
