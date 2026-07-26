import 'package:flutter/painting.dart';

/// Shared 2D frame anchors for Flutter AR overlays (model-frame relative).
///
/// Live AR and ModelViewer fallback both paint into the same scene rect, so
/// overlays stay visually bound to Sample A / Sample B rather than the full
/// screen.
class ArOverlayFrame {
  const ArOverlayFrame({
    required this.size,
    this.dualSamples = false,
  });

  final Size size;
  final bool dualSamples;

  /// Vertical bias matching the typical tabletop model resting point.
  double get midY => size.height * 0.55;

  double get modelRadius => size.shortestSide * (dualSamples ? 0.16 : 0.22);

  /// Sample A (tumbuhan) — left when dual, otherwise centered.
  Offset get sampleACenter {
    if (!dualSamples) {
      return Offset(size.width * 0.5, midY);
    }
    return Offset(size.width * 0.28, midY);
  }

  /// Sample B (hewan) — right when dual; coincides with A when single.
  Offset get sampleBCenter {
    if (!dualSamples) {
      return Offset(size.width * 0.5, midY);
    }
    return Offset(size.width * 0.72, midY);
  }

  /// Chloroplast sits slightly left inside Sample A.
  Offset get chloroplastCenter =>
      sampleACenter.translate(-modelRadius * 0.28, -modelRadius * 0.05);

  /// Vacuole sits slightly right/lower inside Sample A.
  Offset get vacuoleCenter =>
      sampleACenter.translate(modelRadius * 0.22, modelRadius * 0.12);

  /// Outer membrane / cell-wall contour radius around the active cell.
  double get membraneRadius => modelRadius * 1.02;
}
