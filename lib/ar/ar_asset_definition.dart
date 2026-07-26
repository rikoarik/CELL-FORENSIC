/// Stable asset definition used by inventory + scene preload (E0-01 / docs §Integrasi).
class ArAssetDefinition {
  const ArAssetDefinition({
    required this.code,
    required this.flutterAssetPath,
    required this.format,
    required this.sizeBytes,
    required this.triangleCount,
    required this.materialCount,
    required this.textureImageCount,
    required this.keyNodes,
    required this.status,
    required this.preloadGroup,
    this.animationClips = const [],
    this.notes = '',
    this.supportedRenderer = const ['ar_plugin', 'fallback_3d'],
  });

  final String code;
  final String flutterAssetPath;
  final String format;
  final int sizeBytes;
  final int triangleCount;
  final int materialCount;
  final int textureImageCount;
  final List<String> keyNodes;
  final List<String> animationClips;

  /// `ready` | `fix` | `rebuild`
  final String status;
  final String preloadGroup;
  final String notes;
  final List<String> supportedRenderer;

  bool get isViewerSafeFilename =>
      !flutterAssetPath.contains(' ') && !flutterAssetPath.contains('+');
}
