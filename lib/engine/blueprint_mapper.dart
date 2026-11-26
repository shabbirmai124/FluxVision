import 'dart:typed_data';
import 'package:vector_math/vector_math_64.dart';

/// Minimal anchor coordinate payload consumed by [BlueprintMapper].
class BlueprintAnchorInput {
  const BlueprintAnchorInput({
    required this.worldDir,
    required this.intensity,
  });

  final Vector3 worldDir;
  final double intensity;
}

/// Collapses 3D spherical spatial anchors into a smoothed 2D top-down intensity matrix.
class BlueprintMapper {
  static const int defaultGridSize = 32;

  /// Projects [anchors] onto horizontal `(x, z)` plane into a `gridSize x gridSize`
  /// [Float32List] normalized to `0.0..=1.0` after 2 passes of 3x3 Gaussian smoothing.
  static Float32List buildGrid(
    List<BlueprintAnchorInput> anchors, {
    int gridSize = defaultGridSize,
  }) {
    if (gridSize <= 0) {
      return Float32List(0);
    }

    var grid = Float32List(gridSize * gridSize);
    if (anchors.isEmpty) {
      return grid;
    }

    final half = (gridSize - 1) * 0.5;
    for (final anchor in anchors) {
      final dir = anchor.worldDir;
      // Map unit direction horizontal components (x, z) from [-1, 1] into [0, gridSize - 1].
      final gx = ((dir.x.clamp(-1.0, 1.0) * 0.85 + 1.0) * half)
          .round()
          .clamp(0, gridSize - 1);
      final gz = ((dir.z.clamp(-1.0, 1.0) * 0.85 + 1.0) * half)
          .round()
          .clamp(0, gridSize - 1);
      final idx = gz * gridSize + gx;
      if (anchor.intensity > grid[idx]) {
        grid[idx] = anchor.intensity.clamp(0.0, 1.0);
      }
    }

    // Two 3x3 Gaussian passes for smooth thermal contour continuity
    grid = _gaussianPass(grid, gridSize);
    grid = _gaussianPass(grid, gridSize);

    double maxVal = 0.0;
    for (final v in grid) {
      if (v > maxVal) maxVal = v;
    }
    if (maxVal > 1e-5) {
      final inv = 1.0 / maxVal;
      for (int i = 0; i < grid.length; i++) {
        grid[i] = (grid[i] * inv).clamp(0.0, 1.0);
      }
    }

    return grid;
  }

  static Float32List _gaussianPass(Float32List input, int size) {
    final output = Float32List(size * size);
    const kernel = <int>[
      1, 2, 1,
      2, 4, 2,
      1, 2, 1,
    ];

    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        double sum = 0.0;
        double weightSum = 0.0;
        int k = 0;
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            final nx = x + dx;
            final ny = y + dy;
            final w = kernel[k++].toDouble();
            if (nx >= 0 && nx < size && ny >= 0 && ny < size) {
              sum += input[ny * size + nx] * w;
              weightSum += w;
            }
          }
        }
        output[y * size + x] = weightSum > 0.0 ? sum / weightSum : 0.0;
      }
    }
    return output;
  }
}
