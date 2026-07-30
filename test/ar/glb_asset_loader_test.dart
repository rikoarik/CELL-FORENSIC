import 'package:cell_forensic/ar/glb_asset_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('diskFileNameFor strips spaces and unsafe characters', () {
    final name = GlbAssetLoader.diskFileNameFor(
      'assets/ar_models/SelTumbuhan/SelTumbuhanRework_Export 2 normal color.glb',
    );
    expect(name, isNot(contains(' ')));
    expect(name, endsWith('.glb'));
    expect(name, contains('SelTumbuhanRework_Export_2_normal_color.glb'));
  });

  test('diskFileNameFor is stable and unique per path', () {
    const a =
        'assets/ar_models/SelTumbuhan/SelTumbuhanRework_Export_1_normal_color.glb';
    const b =
        'assets/ar_models/SelTumbuhan/SelTumbuhanRework_Export_2_normal_color.glb';
    expect(GlbAssetLoader.diskFileNameFor(a), GlbAssetLoader.diskFileNameFor(a));
    expect(
      GlbAssetLoader.diskFileNameFor(a),
      isNot(GlbAssetLoader.diskFileNameFor(b)),
    );
  });

  test('nodeUriForDiskPath uses file:// on Android, basename elsewhere', () {
    const path = '/data/user/0/app/app_flutter/model.glb';
    expect(
      GlbAssetLoader.nodeUriForDiskPath(path, android: true),
      'file:///data/user/0/app/app_flutter/model.glb',
    );
    expect(
      GlbAssetLoader.nodeUriForDiskPath(path, android: false),
      'model.glb',
    );
  });
}
