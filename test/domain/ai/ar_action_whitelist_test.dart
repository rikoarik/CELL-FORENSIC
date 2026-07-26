import 'package:cell_forensic/domain/ai/ar_action_whitelist.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ArActionWhitelist', () {
    test('sanitizes unknown action to none', () {
      expect(ArActionWhitelist.sanitize('explode_cell'), ArActionWhitelist.none);
      expect(ArActionWhitelist.sanitize(null), ArActionWhitelist.none);
      expect(
        ArActionWhitelist.sanitize('highlight_chloroplast'),
        'highlight_chloroplast',
      );
    });

    test('rejects low confidence', () {
      expect(
        ArActionWhitelist.resolve(
          arAction: 'highlight_chloroplast',
          missionNumber: 1,
          confidence: 0.4,
        ),
        ArActionWhitelist.none,
      );
    });

    test('rejects mission mismatch', () {
      expect(
        ArActionWhitelist.resolve(
          arAction: 'highlight_chloroplast',
          missionNumber: 2,
          confidence: 0.95,
        ),
        ArActionWhitelist.none,
      );
      expect(
        ArActionWhitelist.resolve(
          arAction: 'compare_samples',
          missionNumber: 1,
          confidence: 0.95,
        ),
        ArActionWhitelist.none,
      );
    });

    test('allows valid action for matching mission', () {
      expect(
        ArActionWhitelist.resolve(
          arAction: 'highlight_chloroplast',
          missionNumber: 1,
          confidence: 0.95,
        ),
        'highlight_chloroplast',
      );
      expect(
        ArActionWhitelist.resolve(
          arAction: 'show_water_leak',
          missionNumber: 2,
          confidence: 0.7,
        ),
        'show_water_leak',
      );
      expect(
        ArActionWhitelist.resolve(
          arAction: 'reset_scene',
          missionNumber: 3,
          confidence: 0.9,
        ),
        'reset_scene',
      );
    });
  });
}
