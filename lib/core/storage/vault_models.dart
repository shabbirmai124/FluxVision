import 'package:flutter/foundation.dart';
import '../../engine/scan_mode.dart';

/// Saved ambient room baseline used for Privacy Diff sweeps.
@immutable
class RoomBaseline {
  const RoomBaseline({
    required this.id,
    required this.roomName,
    required this.mode,
    required this.ambientValue,
    required this.createdAt,
    this.notes = '',
  });

  factory RoomBaseline.fromJson(Map<String, dynamic> json) {
    return RoomBaseline(
      id: json['id'] as String,
      roomName: json['roomName'] as String,
      mode: ScanMode.fromId(json['mode'] as String),
      ambientValue: (json['ambientValue'] as num).toDouble(),
      notes: (json['notes'] as String?) ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String roomName;
  final ScanMode mode;
  final double ambientValue;
  final String notes;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'roomName': roomName,
      'mode': mode.id,
      'ambientValue': ambientValue,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

/// Persisted scan session referencing a binary 32x32 Float32List heatmap file.
@immutable
class ScanSession {
  const ScanSession({
    required this.id,
    required this.title,
    required this.mode,
    required this.peakValue,
    required this.peakDelta,
    required this.baselineValue,
    required this.gridSize,
    required this.anchorCount,
    required this.createdAt,
    this.baselineId,
  });

  factory ScanSession.fromJson(Map<String, dynamic> json) {
    return ScanSession(
      id: json['id'] as String,
      title: json['title'] as String,
      mode: ScanMode.fromId(json['mode'] as String),
      peakValue: (json['peakValue'] as num).toDouble(),
      peakDelta: (json['peakDelta'] as num).toDouble(),
      baselineValue: (json['baselineValue'] as num).toDouble(),
      gridSize: (json['gridSize'] as num).toInt(),
      anchorCount: (json['anchorCount'] as num).toInt(),
      baselineId: json['baselineId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String title;
  final ScanMode mode;
  final double peakValue;
  final double peakDelta;
  final double baselineValue;
  final int gridSize;
  final int anchorCount;
  final String? baselineId;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'mode': mode.id,
      'peakValue': peakValue,
      'peakDelta': peakDelta,
      'baselineValue': baselineValue,
      'gridSize': gridSize,
      'anchorCount': anchorCount,
      'baselineId': baselineId,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
