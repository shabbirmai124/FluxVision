import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import 'scanner_controller.dart';
import 'widgets/calibration_overlay.dart';
import 'widgets/flux_heatmap_painter.dart';
import 'widgets/grid_reticle_painter.dart';
import 'widgets/hud_telemetry_bar.dart';
import 'widgets/mode_selector_dock.dart';

/// Full-screen AR field scanner combining live camera feed (or calibrated dark
/// optical backdrop in Demo/desktop mode), Pure-Dart thermal overlay, optical
/// rangefinder reticle, measured contrast scrims, and lifecycle power safety.
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({
    super.key,
    this.enableHardwareCamera = true,
    this.autoInitialize = true,
  });

  final bool enableHardwareCamera;
  final bool autoInitialize;

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  CameraController? _cameraController;
  late final Ticker _ticker;
  double _elapsedSeconds = 0.0;
  Future<void> _cameraOpQueue = Future<void>.value();

  bool get _isMobilePlatform => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _ticker = createTicker((Duration elapsed) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds = (elapsed.inMicroseconds / 1e6) % 1000.0;
      });
    });

    if (widget.autoInitialize) {
      _ticker.start();
      Future<void>.microtask(_bootstrapScanner);
    }
  }

  Future<void> _bootstrapScanner() async {
    if (!mounted) return;
    final defaultDemo = !_isMobilePlatform;
    await ref.read(scannerControllerProvider.notifier).initialize(forceDemoMode: defaultDemo);
    if (widget.enableHardwareCamera && _isMobilePlatform) {
      _enqueueCameraOp(_initCameraImpl);
    }
  }

  void _enqueueCameraOp(Future<void> Function() op) {
    _cameraOpQueue = _cameraOpQueue.then((_) => op()).catchError((Object _) {});
  }

  Future<void> _initCameraImpl() async {
    if (!mounted || !_isMobilePlatform || _cameraController != null) return;
    try {
      final cameras = await availableCameras();
      if (!mounted || cameras.isEmpty) return;

      final rear = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        rear,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
      });
      ref.read(scannerControllerProvider.notifier).setCameraReady(true);
    } on MissingPluginException {
      // Test or desktop runner
    } on CameraException {
      // Camera permission denied or unavailable; matte optical backdrop stays visible
    }
  }

  Future<void> _disposeCameraImpl() async {
    final cam = _cameraController;
    _cameraController = null;
    if (mounted) {
      setState(() {});
      ref.read(scannerControllerProvider.notifier).setCameraReady(false);
    }
    await cam?.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(scannerControllerProvider.notifier);
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (_ticker.isActive) {
        _ticker.stop();
      }
      unawaited(controller.pauseForLifecycle());
      _enqueueCameraOp(_disposeCameraImpl);
    } else if (state == AppLifecycleState.resumed) {
      if (!_ticker.isActive && widget.autoInitialize) {
        _ticker.start();
      }
      unawaited(controller.resumeFromLifecycle());
      if (widget.enableHardwareCamera && _isMobilePlatform) {
        _enqueueCameraOp(_initCameraImpl);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    final cam = _cameraController;
    _cameraController = null;
    if (cam != null) {
      unawaited(cam.dispose());
    }
    super.dispose();
  }

  Future<void> _promptSaveBaseline() async {
    final currentState = ref.read(scannerControllerProvider);
    final textCtrl = TextEditingController(text: 'Living Room');
    final confirmed = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Save Room Baseline'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Stores ${currentState.frame.filteredValue.toStringAsFixed(1)} ${currentState.mode.unit} '
              'as the clean ambient floor for Privacy Diff sweeps.',
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: FluxTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: textCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Room Label',
                hintText: 'Server Closet, Bedroom, Studio',
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(textCtrl.text),
            child: const Text('Save Baseline'),
          ),
        ],
      ),
    );
    textCtrl.dispose();

    if (confirmed == null || !mounted) return;
    final saved = await ref
        .read(scannerControllerProvider.notifier)
        .saveCurrentAsBaseline(confirmed);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Saved "${saved.roomName}" (${saved.ambientValue.toStringAsFixed(1)} ${saved.mode.unit})',
        ),
      ),
    );
  }

  Future<void> _saveAndOpenBlueprint() async {
    final session = await ref
        .read(scannerControllerProvider.notifier)
        .saveBlueprintSnapshot();
    if (!mounted) return;
    unawaited(context.push('/blueprint/${session.id}'));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scannerControllerProvider);
    final controller = ref.read(scannerControllerProvider.notifier);
    final cam = _cameraController;
    final showLiveCamera = cam != null && cam.value.isInitialized && !state.demoMode;

    return Scaffold(
      backgroundColor: FluxTheme.background,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanUpdate: state.demoMode
            ? (DragUpdateDetails details) =>
                controller.nudgeDemoPan(details.delta.dx, details.delta.dy)
            : null,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Layer 0: Camera Preview or Calibrated Matte Optical Backdrop
            if (showLiveCamera)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: cam.value.previewSize?.height ?? 720,
                  height: cam.value.previewSize?.width ?? 1280,
                  child: CameraPreview(cam),
                ),
              )
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.05,
                    colors: <Color>[
                      Color(0xFF10151E),
                      FluxTheme.background,
                    ],
                  ),
                ),
              ),

            // Layer 1: Pure-Dart GPU-accelerated Radiometric Heatmap
            RepaintBoundary(
              child: CustomPaint(
                painter: FluxHeatmapPainter(
                  mode: state.mode,
                  hotspots: state.frame.hotspots,
                  elapsedSeconds: _elapsedSeconds,
                ),
                child: const SizedBox.expand(),
              ),
            ),

            // Layer 2: Precision Optical Rangefinder Reticle
            CustomPaint(
              painter: GridReticlePainter(
                mode: state.mode,
                elapsedSeconds: _elapsedSeconds,
                pitchDegrees: state.pitchDegrees,
                yawDegrees: state.yawDegrees,
                peakHotspot: state.frame.peakHotspot,
              ),
              child: const SizedBox.expand(),
            ),

            // Layer 2.5: Measured Top & Bottom Contrast Scrims for Camera Legibility
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: <double>[0.0, 0.20, 0.76, 1.0],
                    colors: <Color>[
                      Color(0x9906080B),
                      Color(0x0006080B),
                      Color(0x0006080B),
                      Color(0xB306080B),
                    ],
                  ),
                ),
              ),
            ),

            // Layer 3: Instrument HUD & Thumb-Zone Console
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  children: <Widget>[
                    HudTelemetryBar(
                      state: state,
                      onToggleDemo: () => unawaited(controller.toggleDemoMode()),
                      onOpenVault: () => unawaited(context.push('/vault')),
                      onClearBaseline: controller.clearActiveBaseline,
                    ),
                    const SizedBox(height: 10),
                    CalibrationOverlay(
                      isCalibrating: state.frame.isCalibrating,
                      progress: state.frame.calibrationProgress,
                      accentColor: state.mode.accentColor,
                      sensorAlert: state.sensorAlert,
                      demoMode: state.demoMode,
                      permissionPermanentlyDenied: state.permissionPermanentlyDenied,
                      onEnableDemoMode: () => unawaited(controller.toggleDemoMode()),
                      onOpenSettings: () => unawaited(controller.openPermissionSettings()),
                      onDismissAlert: controller.dismissAlert,
                    ),
                    const Spacer(),
                    ModeSelectorDock(
                      activeMode: state.mode,
                      trailLock: state.trailLock,
                      isCalibrating: state.frame.isCalibrating,
                      calibrationProgress: state.frame.calibrationProgress,
                      anchorCount: state.frame.anchorCount,
                      onSelectMode: (m) => unawaited(controller.setMode(m)),
                      onCalibrate: controller.startCalibration,
                      onToggleTrailLock: controller.toggleTrailLock,
                      onClearTrails: controller.clearTrails,
                      onSaveBaseline: () => unawaited(_promptSaveBaseline()),
                      onSaveBlueprint: () => unawaited(_saveAndOpenBlueprint()),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
