import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Copies a Flutter asset GLB into the app documents folder so
/// `ar_flutter_plugin_2` can load it via [NodeType.fileSystemAppFolderGLB]
/// (local Flutter assets only support `.gltf` through `localGLTF2`).
class GlbAssetLoader {
  GlbAssetLoader._();

  static final Map<String, String> _cache = {};

  /// Returns the filename relative to the app documents directory.
  static Future<String> ensureOnDisk(String assetPath) async {
    final cached = _cache[assetPath];
    if (cached != null) return cached;

    final fileName = assetPath.split('/').last;
    final dir = await getApplicationDocumentsDirectory();
    final out = File('${dir.path}/$fileName');
    if (!await out.exists()) {
      final data = await rootBundle.load(assetPath);
      await out.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }
    _cache[assetPath] = fileName;
    return fileName;
  }
}
