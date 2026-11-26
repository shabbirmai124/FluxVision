/// Rolling FPS and frame interval calculator with zero heap churn per frame.
class FrameMetrics {
  DateTime? _lastFrameTime;
  double _emaFrameMs = 16.67;

  double get averageFrameMs => _emaFrameMs;
  int get fps => _emaFrameMs > 0.1 ? (1000.0 / _emaFrameMs).round().clamp(1, 240) : 60;

  void recordFrame([DateTime? now]) {
    final current = now ?? DateTime.now();
    final prev = _lastFrameTime;
    _lastFrameTime = current;
    if (prev == null) return;

    final deltaMs = current.difference(prev).inMicroseconds / 1000.0;
    if (deltaMs > 0.5 && deltaMs < 1000.0) {
      _emaFrameMs = _emaFrameMs * 0.85 + deltaMs * 0.15;
    }
  }

  void reset() {
    _lastFrameTime = null;
    _emaFrameMs = 16.67;
  }
}
