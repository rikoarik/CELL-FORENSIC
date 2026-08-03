import 'package:cell_forensic/ar/ar_asset_registry.dart';
import 'package:cell_forensic/ar/glb_asset_loader.dart';
import 'package:cell_forensic/ar/model_placement_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const config = ArModelPlacementConfigs.labScene;

  test('normalizes the audited lab scene to a 45 cm uniform height', () {
    final bounds = ArModelPlacementConfigs.auditedBoundsFor(
      ArAssetRegistry.scene1,
    );
    final scale = config.uniformScaleFor(bounds);

    expect(bounds.height * scale, closeTo(0.45, 1e-9));
    expect(bounds.width * scale, closeTo(0.9298, 0.001));
    expect(config.baseCorrectionY(bounds, scale), closeTo(-0.004805, 1e-6));

    final cameraTarget = config.modelViewerCameraTarget(bounds, scale);
    expect(cameraTarget.x, closeTo(0, 1e-9));
    expect(cameraTarget.y, closeTo(0.225, 1e-9));
    expect(cameraTarget.z, closeTo(0.01068, 1e-5));
  });

  test('rotates the ModelViewer camera target with the visible model', () {
    const bounds = ModelBounds(
      minX: 0,
      minY: 1,
      minZ: 1,
      maxX: 2,
      maxY: 3,
      maxZ: 3,
    );

    final cameraTarget = config.modelViewerCameraTarget(
      bounds,
      0.5,
      rotationYRadians: 3.141592653589793 / 2,
    );

    expect(cameraTarget.x, closeTo(1, 1e-9));
    expect(cameraTarget.y, closeTo(0.5, 1e-9));
    expect(cameraTarget.z, closeTo(-0.5, 1e-9));
  });

  test('classifies horizontal placement distance without using camera Y', () {
    expect(config.classifyDistance(0.99), PlacementDistanceStatus.tooNear);
    expect(config.classifyDistance(1.0), PlacementDistanceStatus.valid);
    expect(config.classifyDistance(3.5), PlacementDistanceStatus.valid);
    expect(config.classifyDistance(3.51), PlacementDistanceStatus.tooFar);
    expect(
      config.horizontalDistance(cameraX: 1, cameraZ: 2, hitX: 4, hitZ: 6),
      closeTo(5, 1e-9),
    );
  });

  testWidgets('runtime GLB bounds match every audited scene', (tester) async {
    const scenePaths = <String>[
      ArAssetRegistry.scene1,
      ArAssetRegistry.sceneMisi1Kloroplas,
      ArAssetRegistry.sceneMisi1Vakuola,
      ArAssetRegistry.sceneMisi2Membran,
      ArAssetRegistry.sceneMisi3Dinding,
    ];

    GlbAssetLoader.debugClearCache();
    for (final path in scenePaths) {
      final actual = await GlbAssetLoader.loadBounds(path);
      final audited = ArModelPlacementConfigs.auditedBoundsFor(path);

      expect(actual.minX, closeTo(audited.minX, 1e-5), reason: path);
      expect(actual.minY, closeTo(audited.minY, 1e-5), reason: path);
      expect(actual.minZ, closeTo(audited.minZ, 1e-5), reason: path);
      expect(actual.maxX, closeTo(audited.maxX, 1e-5), reason: path);
      expect(actual.maxY, closeTo(audited.maxY, 1e-5), reason: path);
      expect(actual.maxZ, closeTo(audited.maxZ, 1e-5), reason: path);
    }
  });
}
