import 'package:flutter/material.dart';

/// Physical signal domains scanned by FluxVision.
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
    accentColor: Color(0xFFFF8A2B),
    paletteColors: <Color>[
      Color(0xFF1E0B4B),
      Color(0xFFB0148C),
      Color(0xFFFA730D),
      Color(0xFFFFF5C7),
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
    accentColor: Color(0xFF00E5FF),
    paletteColors: <Color>[
      Color(0xFF051937),
      Color(0xFF004D7A),
      Color(0xFF00B4D8),
      Color(0xFFE0FBFC),
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
    accentColor: Color(0xFFA7E82D),
    paletteColors: <Color>[
      Color(0xFF0D1B2A),
      Color(0xFF1B998B),
      Color(0xFFA7E82D),
      Color(0xFFFFF9A6),
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
