import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Copies a Flutter asset GLB into the app documents folder so
/// `ar_flutter_plugin_2` can load it via [NodeType.fileSystemAppFolderGLB]
/// (local Flutter assets only support `.gltf` through `localGLTF2`).
///
/// Path rules:
/// - **Android / SceneView**: needs a `file://` URI. Bare absolute paths are
///   treated as Android *asset* paths and fail to open.
/// - **iOS**: the plugin prepends the documents directory, so pass the
///   relative filename only.
class GlbAssetLoader {
  GlbAssetLoader._();

  static final Map<String, String> _cache = {};

  /// Disk-safe filename (no spaces / URL-unsafe chars) unique per asset path.
  static String diskFileNameFor(String assetPath) {
    final raw = assetPath.split('/').last;
    final sanitized = raw.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final hash = assetPath.hashCode.toUnsigned(32).toRadixString(16);
    return '${hash}_$sanitized';
  }

  /// URI string passed to [ARNode.uri] for a file already on disk.
  @visibleForTesting
  static String nodeUriForDiskPath(String absolutePath, {required bool android}) {
    if (android) return Uri.file(absolutePath).toString();
    return absolutePath.split(Platform.pathSeparator).last;
  }

  /// Returns the URI string passed to [ARNode.uri].
  static Future<String> ensureOnDisk(String assetPath) async {
    final cached = _cache[assetPath];
    if (cached != null) return cached;

    final fileName = diskFileNameFor(assetPath);
    final dir = await getApplicationDocumentsDirectory();
    final out = File('${dir.path}/$fileName');
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final needsWrite =
        !await out.exists() || await out.length() != bytes.length;
    if (needsWrite) {
      await out.writeAsBytes(bytes, flush: true);
    }

    final uri = nodeUriForDiskPath(
      out.path,
      android: !kIsWeb && Platform.isAndroid,
    );
    _cache[assetPath] = uri;
    return uri;
  }

  /// Test helper — clears the in-memory path cache.
  static void debugClearCache() => _cache.clear();
}
