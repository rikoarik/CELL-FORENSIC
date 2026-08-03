import 'dart:math' as math;

/// Axis-aligned bounds in the glTF model's authored coordinate system.
class ModelBounds {
  const ModelBounds({
    required this.minX,
    required this.minY,
    required this.minZ,
    required this.maxX,
    required this.maxY,
    required this.maxZ,
  });

  final double minX;
  final double minY;
  final double minZ;
  final double maxX;
  final double maxY;
  final double maxZ;

  double get centerX => (minX + maxX) / 2;
  double get centerY => (minY + maxY) / 2;
  double get centerZ => (minZ + maxZ) / 2;
  double get width => maxX - minX;
  double get height => maxY - minY;
  double get depth => maxZ - minZ;

  @override
  String toString() =>
      'min=(${_f(minX)}, ${_f(minY)}, ${_f(minZ)}) '
      'max=(${_f(maxX)}, ${_f(maxY)}, ${_f(maxZ)}) '
      'center=(${_f(centerX)}, ${_f(centerY)}, ${_f(centerZ)}) '
      'size=(${_f(width)}, ${_f(height)}, ${_f(depth)})';

  static String _f(double value) => value.toStringAsFixed(6);
}

enum PlacementDistanceStatus { valid, tooNear, tooFar }

/// One source of truth for AR placement and ModelViewer normalization.
class ModelPlacementConfig {
  const ModelPlacementConfig({
    required this.targetHeightMeters,
    required this.minimumDistanceMeters,
    required this.preferredDistanceMeters,
    required this.maximumDistanceMeters,
    required this.minimumScale,
    required this.maximumScale,
    this.rotationCorrectionYRadians = 0,
  });

  /// A 45 cm-tall miniature keeps the complete lab desk legible on a phone
  /// while avoiding a near life-size desk that would dominate the AR view.
  final double targetHeightMeters;
  final double minimumDistanceMeters;
  final double preferredDistanceMeters;
  final double maximumDistanceMeters;
  final double minimumScale;
  final double maximumScale;
  final double rotationCorrectionYRadians;

  double uniformScaleFor(ModelBounds bounds, {double multiplier = 1}) {
    if (!bounds.height.isFinite || bounds.height <= 0) {
      throw ArgumentError.value(bounds.height, 'bounds.height');
    }
    final normalized = targetHeightMeters / bounds.height;
    return (normalized * multiplier).clamp(minimumScale, maximumScale);
  }

  /// Moves the authored model base to the anchor plane after uniform scaling.
  /// The supported correction is around Y, so rotation does not change minY.
  double baseCorrectionY(ModelBounds bounds, double uniformScale) =>
      -(bounds.minY * uniformScale);

  /// Camera target matching the grounded AR transform, expressed in the
  /// post-scale coordinate system used by `<model-viewer>`.
  ({double x, double y, double z}) modelViewerCameraTarget(
    ModelBounds bounds,
    double uniformScale, {
    double rotationYRadians = 0,
  }) {
    final cosine = math.cos(rotationYRadians);
    final sine = math.sin(rotationYRadians);
    final rotatedCenterX = bounds.centerX * cosine + bounds.centerZ * sine;
    final rotatedCenterZ = -bounds.centerX * sine + bounds.centerZ * cosine;
    return (
      x: rotatedCenterX * uniformScale,
      y: bounds.height * uniformScale / 2,
      z: rotatedCenterZ * uniformScale,
    );
  }

  PlacementDistanceStatus classifyDistance(double horizontalDistanceMeters) {
    if (horizontalDistanceMeters < minimumDistanceMeters) {
      return PlacementDistanceStatus.tooNear;
    }
    if (horizontalDistanceMeters > maximumDistanceMeters) {
      return PlacementDistanceStatus.tooFar;
    }
    return PlacementDistanceStatus.valid;
  }

  double horizontalDistance({
    required double cameraX,
    required double cameraZ,
    required double hitX,
    required double hitZ,
  }) => math.sqrt(math.pow(hitX - cameraX, 2) + math.pow(hitZ - cameraZ, 2));
}

abstract final class ArModelPlacementConfigs {
  static const labScene = ModelPlacementConfig(
    targetHeightMeters: 0.45,
    minimumDistanceMeters: 1.0,
    preferredDistanceMeters: 1.6,
    maximumDistanceMeters: 3.5,
    minimumScale: 0.20,
    maximumScale: 0.80,
  );

  /// Build-time audited bounds provide immediate web framing. AR reads the GLB
  /// again at runtime before creating an anchor and logs any actual difference.
  static ModelBounds auditedBoundsFor(String assetPath) {
    if (assetPath.endsWith('scene-misi3-dinding.glb')) {
      return const ModelBounds(
        minX: -1.0315405,
        minY: 0.0106598,
        minZ: -0.6090965,
        maxX: 1.0315405,
        maxY: 1.0215597,
        maxZ: 0.6564704,
      );
    }
    return const ModelBounds(
      minX: -1.0315405,
      minY: 0.0106598,
      minZ: -0.6090965,
      maxX: 1.0315405,
      maxY: 1.0090537,
      maxZ: 0.6564704,
    );
  }

  static ModelPlacementConfig forAsset(String assetPath) => labScene;
}
