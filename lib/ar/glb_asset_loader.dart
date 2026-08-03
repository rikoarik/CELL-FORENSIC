import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:cell_forensic/ar/model_placement_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vector_math/vector_math_64.dart';

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
  static final Map<String, Future<ModelBounds>> _boundsCache = {};

  /// Disk-safe filename (no spaces / URL-unsafe chars) unique per asset path.
  static String diskFileNameFor(String assetPath) {
    final raw = assetPath.split('/').last;
    final sanitized = raw.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final hash = assetPath.hashCode.toUnsigned(32).toRadixString(16);
    return '${hash}_$sanitized';
  }

  /// URI string passed to [ARNode.uri] for a file already on disk.
  @visibleForTesting
  static String nodeUriForDiskPath(
    String absolutePath, {
    required bool android,
  }) {
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

  /// Reads accessor min/max values and applies every scene-node transform.
  /// Vertex buffers do not need to be decoded because valid glTF POSITION
  /// accessors already contain the local axis-aligned bounds.
  static Future<ModelBounds> loadBounds(String assetPath) =>
      _boundsCache.putIfAbsent(assetPath, () async {
        final data = await rootBundle.load(assetPath);
        return boundsFromGlbBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
      });

  @visibleForTesting
  static ModelBounds boundsFromGlbBytes(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    if (bytes.length < 20 || data.getUint32(0, Endian.little) != 0x46546C67) {
      throw const FormatException('Asset is not a GLB file.');
    }
    if (data.getUint32(4, Endian.little) != 2) {
      throw const FormatException('Only GLB version 2 is supported.');
    }

    final declaredLength = data.getUint32(8, Endian.little);
    if (declaredLength > bytes.length) {
      throw const FormatException('GLB is truncated.');
    }

    Map<String, dynamic>? document;
    var offset = 12;
    while (offset + 8 <= declaredLength) {
      final chunkLength = data.getUint32(offset, Endian.little);
      final chunkType = data.getUint32(offset + 4, Endian.little);
      offset += 8;
      if (offset + chunkLength > declaredLength) {
        throw const FormatException('GLB chunk exceeds declared length.');
      }
      if (chunkType == 0x4E4F534A) {
        final jsonBytes = bytes.sublist(offset, offset + chunkLength);
        final jsonText = utf8
            .decode(jsonBytes)
            .replaceFirst(RegExp(r'[\u0000\x20]+$'), '');
        document = Map<String, dynamic>.from(
          jsonDecode(jsonText) as Map<String, dynamic>,
        );
        break;
      }
      offset += chunkLength;
    }
    if (document == null) {
      throw const FormatException('GLB JSON chunk is missing.');
    }

    final nodes = _mapList(document['nodes']);
    final meshes = _mapList(document['meshes']);
    final accessors = _mapList(document['accessors']);
    final scenes = _mapList(document['scenes']);
    final sceneIndex = (document['scene'] as num?)?.toInt() ?? 0;

    final childNodeIndexes = <int>{};
    for (final node in nodes) {
      childNodeIndexes.addAll(_intList(node['children']));
    }
    final roots = scenes.isNotEmpty && sceneIndex < scenes.length
        ? _intList(scenes[sceneIndex]['nodes'])
        : [
            for (var index = 0; index < nodes.length; index++)
              if (!childNodeIndexes.contains(index)) index,
          ];

    var minX = double.infinity;
    var minY = double.infinity;
    var minZ = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    var maxZ = double.negativeInfinity;

    void include(Vector3 point) {
      minX = math.min(minX, point.x);
      minY = math.min(minY, point.y);
      minZ = math.min(minZ, point.z);
      maxX = math.max(maxX, point.x);
      maxY = math.max(maxY, point.y);
      maxZ = math.max(maxZ, point.z);
    }

    void visit(int nodeIndex, Matrix4 parentTransform) {
      if (nodeIndex < 0 || nodeIndex >= nodes.length) return;
      final node = nodes[nodeIndex];
      final worldTransform = parentTransform * _nodeTransform(node);
      final meshIndex = (node['mesh'] as num?)?.toInt();
      if (meshIndex != null && meshIndex >= 0 && meshIndex < meshes.length) {
        final primitives = _mapList(meshes[meshIndex]['primitives']);
        for (final primitive in primitives) {
          final attributes = primitive['attributes'];
          if (attributes is! Map) continue;
          final positionIndex = (attributes['POSITION'] as num?)?.toInt();
          if (positionIndex == null ||
              positionIndex < 0 ||
              positionIndex >= accessors.length) {
            continue;
          }
          final accessor = accessors[positionIndex];
          final localMin = _doubleList(accessor['min']);
          final localMax = _doubleList(accessor['max']);
          if (localMin.length < 3 || localMax.length < 3) continue;
          for (final x in [localMin[0], localMax[0]]) {
            for (final y in [localMin[1], localMax[1]]) {
              for (final z in [localMin[2], localMax[2]]) {
                include(worldTransform.transform3(Vector3(x, y, z)));
              }
            }
          }
        }
      }
      for (final childIndex in _intList(node['children'])) {
        visit(childIndex, worldTransform);
      }
    }

    for (final rootIndex in roots) {
      visit(rootIndex, Matrix4.identity());
    }
    if (![minX, minY, minZ, maxX, maxY, maxZ].every((v) => v.isFinite)) {
      throw const FormatException('GLB contains no bounded mesh positions.');
    }
    return ModelBounds(
      minX: minX,
      minY: minY,
      minZ: minZ,
      maxX: maxX,
      maxY: maxY,
      maxZ: maxZ,
    );
  }

  static Matrix4 _nodeTransform(Map<String, dynamic> node) {
    final matrix = _doubleList(node['matrix']);
    if (matrix.length == 16) return Matrix4.fromList(matrix);

    final translation = _doubleList(node['translation']);
    final rotation = _doubleList(node['rotation']);
    final scale = _doubleList(node['scale']);
    return Matrix4.compose(
      translation.length == 3
          ? Vector3(translation[0], translation[1], translation[2])
          : Vector3.zero(),
      rotation.length == 4
          ? Quaternion(rotation[0], rotation[1], rotation[2], rotation[3])
          : Quaternion.identity(),
      scale.length == 3
          ? Vector3(scale[0], scale[1], scale[2])
          : Vector3.all(1),
    );
  }

  static List<Map<String, dynamic>> _mapList(Object? value) => value is List
      ? value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
      : const [];

  static List<int> _intList(Object? value) => value is List
      ? value.whereType<num>().map((item) => item.toInt()).toList()
      : const [];

  static List<double> _doubleList(Object? value) => value is List
      ? value.whereType<num>().map((item) => item.toDouble()).toList()
      : const [];

  /// Test helper — clears the in-memory path cache.
  static void debugClearCache() {
    _cache.clear();
    _boundsCache.clear();
  }
}
