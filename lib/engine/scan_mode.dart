import 'package:flutter/material.dart';

/// Physical signal domains scanned by FluxVision with calibrated radiometric palettes.
enum ScanMode {
  em(
    id: 'em',
    label: 'EM Field',
    shortLabel: 'EM',
    unit: 'µT',
    defaultBaseline: 45.0,
    kalmanQ: 0.08,
    kalmanR: 1.5,
    deadband: 8.0,
    span: 80.0,
    accentColor: Color(0xFFE8922D),
    paletteColors: <Color>[
      Color(0xFF1D103D),
      Color(0xFFA22372),
      Color(0xFFE8721E),
      Color(0xFFFFF2C6),
    ],
    description: 'Magnetometer flux for hidden wiring, conduits & electronics',
  ),
  rf(
    id: 'rf',
    label: 'RF Spectrum',
    shortLabel: 'RF',
    unit: 'dBm',
    defaultBaseline: -82.0,
    kalmanQ: 0.25,
    kalmanR: 4.0,
    deadband: 4.0,
    span: 35.0,
    accentColor: Color(0xFF38BDF8),
    paletteColors: <Color>[
      Color(0xFF0B1C33),
      Color(0xFF0E5A8A),
      Color(0xFF22A9D8),
      Color(0xFFE3F7FD),
    ],
    description: 'Bluetooth LE RSSI transmitter & dead-zone spatial mapper',
  ),
  acoustic(
    id: 'acoustic',
    label: 'Acoustic',
    shortLabel: 'SND',
    unit: 'dB',
    defaultBaseline: 42.0,
    kalmanQ: 0.15,
    kalmanR: 2.0,
    deadband: 6.0,
    span: 40.0,
    accentColor: Color(0xFF6BCB77),
    paletteColors: <Color>[
      Color(0xFF10212E),
      Color(0xFF1B8A7A),
      Color(0xFF8FD14F),
      Color(0xFFF9F4B0),
    ],
    description: 'Directional microphone decibel hotspot visualizer',
  );

  const ScanMode({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.unit,
    required this.defaultBaseline,
    required this.kalmanQ,
    required this.kalmanR,
    required this.deadband,
    required this.span,
    required this.accentColor,
    required this.paletteColors,
    required this.description,
  });

  final String id;
  final String label;
  final String shortLabel;
  final String unit;
  final double defaultBaseline;
  final double kalmanQ;
  final double kalmanR;
  final double deadband;
  final double span;
  final Color accentColor;
  final List<Color> paletteColors;
  final String description;

  static ScanMode fromId(String id) {
    return ScanMode.values.firstWhere(
      (mode) => mode.id == id,
      orElse: () => ScanMode.em,
    );
  }
}
