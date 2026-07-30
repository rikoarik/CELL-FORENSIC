import 'package:cell_forensic/ar/ar_asset_manifest.dart';
import 'package:cell_forensic/ar/ar_asset_registry.dart';
import 'package:cell_forensic/ar/organelle_label_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('E0-01 inventory has 25 GLB definitions', () {
    expect(ArAssetManifest.allAssets, hasLength(25));
    expect(ArAssetRegistry.inventoriedCount, 25);
  });

  test('E0-02 every asset is GLB with non-negative triangle count', () {
    for (final asset in ArAssetManifest.allAssets) {
      expect(asset.format, 'GLB');
      expect(asset.triangleCount, greaterThanOrEqualTo(0));
      expect(asset.sizeBytes, greaterThan(0));
    }
  });

  test('E0-08 organelle X/Y and membrane parts stay provisional', () {
    expect(OrganelleLabelMap.assertProvisionalRules(), isTrue);
    expect(ArAssetRegistry.organelleLabelsSafe, isTrue);
    final open = OrganelleLabelMap.provisional.map((l) => l.code).toSet();
    expect(
      open,
      containsAll({
        'ORGANELLE_X',
        'ORGANELLE_Y',
        'B_MEMBRANE_PART_1',
        'B_MEMBRANE_PART_2',
      }),
    );
  });

  test('mission primary paths exist in manifest', () {
    for (final code in ['MISI-1', 'MISI-2', 'MISI-3']) {
      final path = ArAssetRegistry.primaryModelForMission(code);
      expect(ArAssetManifest.byPath(path), isNotNull, reason: path);
    }
  });
}
