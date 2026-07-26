import 'package:cell_forensic/core/config/app_flavor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default flavor is dev when APP_FLAVOR unset', () {
    expect(AppFlavor.current, AppFlavor.dev);
    expect(AppFlavor.current.label, 'Development');
    expect(AppFlavor.current.isProd, isFalse);
  });
}
