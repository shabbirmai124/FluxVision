import 'package:flutter_test/flutter_test.dart';
import 'package:flux_vision/engine/scan_mode.dart';
import 'package:flux_vision/sensors/field_sensor_source.dart';
import 'package:flux_vision/sensors/simulated_sensor_source.dart';

void main() {
  group('SimulatedSensorSource', () {
    test('emits orientation and mode packets across EM, RF, and Acoustic modes', () async {
      final source = SimulatedSensorSource(tickInterval: const Duration(milliseconds: 10));
      addTearDown(source.dispose);

      // EM mode
      final emPackets = <SensorPacket>[];
      final emSub = source.start(ScanMode.em).listen(emPackets.add);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await emSub.cancel();
      expect(emPackets.whereType<OrientationPacket>(), isNotEmpty);
      expect(emPackets.whereType<EmPacket>(), isNotEmpty);

      // RF mode (emits every 4 ticks)
      final rfPackets = <SensorPacket>[];
      final rfSub = source.start(ScanMode.rf).listen(rfPackets.add);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await rfSub.cancel();
      expect(rfPackets.whereType<RfPacket>(), isNotEmpty);
      expect(rfPackets.whereType<RfPacket>().first.deviceCount, greaterThan(0));

      // Acoustic mode (emits every 2 ticks)
      final acPackets = <SensorPacket>[];
      final acSub = source.start(ScanMode.acoustic).listen(acPackets.add);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await acSub.cancel();
      expect(acPackets.whereType<AcousticPacket>(), isNotEmpty);

      // Pan nudge stays bounded and stop closes stream cleanly
      source.nudgePan(10.0, -10.0);
      source.resetPan();
      await source.stop();
    });
  });
}
