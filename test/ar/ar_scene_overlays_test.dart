import 'package:cell_forensic/ar/ar_overlay_frame.dart';
import 'package:cell_forensic/ar/ar_scene_engine.dart';
import 'package:cell_forensic/ar/ar_scene_overlays.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('overlay layer paints for each mission effect', (tester) async {
    for (final effect in ArOverlayEffect.values) {
      if (effect == ArOverlayEffect.none) continue;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: ArSceneOverlayLayer(
                effect: effect,
                highlightTarget: null,
                dualSamples: effect == ArOverlayEffect.missingStructureCross ||
                    effect == ArOverlayEffect.forceArrows ||
                    effect == ArOverlayEffect.comparisonLabels,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(ArSceneOverlayLayer), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
    }
  });

  test('dual sample frame separates A and B anchors', () {
    const size = Size(400, 600);
    final dual = ArOverlayFrame(size: size, dualSamples: true);
    final single = ArOverlayFrame(size: size, dualSamples: false);

    expect(dual.sampleACenter.dx, lessThan(size.width * 0.5));
    expect(dual.sampleBCenter.dx, greaterThan(size.width * 0.5));
    expect(single.sampleACenter.dx, closeTo(size.width * 0.5, 0.01));
    expect(single.sampleBCenter.dx, closeTo(size.width * 0.5, 0.01));
    expect(dual.chloroplastCenter.dx, lessThan(dual.sampleACenter.dx));
  });

  testWidgets('none + no highlight shrinks to empty', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ArSceneOverlayLayer(
            effect: ArOverlayEffect.none,
            highlightTarget: null,
          ),
        ),
      ),
    );
    expect(find.byType(ArSceneOverlayLayer), findsOneWidget);
    expect(find.byKey(const Key('ar-overlay-empty')), findsOneWidget);
  });
}
