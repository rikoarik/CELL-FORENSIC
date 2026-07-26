import 'package:cell_forensic/ar/ar_asset_registry.dart';
import 'package:cell_forensic/ar/ar_scene_engine.dart';
import 'package:cell_forensic/ar/ar_visual_director.dart';
import 'package:cell_forensic/ar/misi1_visuals.dart';
import 'package:cell_forensic/ar/misi2_visual_helpers.dart';
import 'package:cell_forensic/ar/mission_scene_panel.dart';
import 'package:cell_forensic/domain/mission_progress.dart';
import 'package:cell_forensic/domain/sequence_engine.dart';
import 'package:cell_forensic/features/content/local_content_pack.dart';
import 'package:cell_forensic/features/journey/screens/investigation/mission_screen.dart';
import 'package:cell_forensic/features/journey/student_journey.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wave 5 Critical regressions — these would FAIL before the live nodeScale
/// sync + intent dwell fixes and PASS after.
void main() {
  const director = ArVisualDirector();

  setUp(() {
    MissionScenePanel.debugUsePlaceholderScene = true;
    MissionScreen.intentStepDwell = const Duration(milliseconds: 200);
  });

  tearDown(() {
    MissionScenePanel.debugUsePlaceholderScene = false;
    MissionScreen.intentStepDwell = const Duration(milliseconds: 1000);
  });

  group('live scale sync', () {
    test('W5-01 combineLiveNodeScale multiplies base × gesture × nodeScale', () {
      // Before fix: live path used only base * gesture (ignored 1.55).
      final combined = combineLiveNodeScale(
        baseScale: 0.08,
        gestureScale: 1.0,
        sequenceScale: const ArVec3(1.55, 1.55, 1.55),
      );
      expect(combined, closeTo(0.08 * 1.55, 1e-9));
      expect(combined, isNot(closeTo(0.08, 1e-9)));

      final withGesture = combineLiveNodeScale(
        baseScale: 0.08,
        gestureScale: 1.5,
        sequenceScale: const ArVec3(1.55, 1.55, 1.55),
      );
      expect(withGesture, closeTo(0.08 * 1.5 * 1.55, 1e-9));

      final noSequence = combineLiveNodeScale(
        baseScale: 0.08,
        gestureScale: 1.2,
        sequenceScale: null,
      );
      expect(noSequence, closeTo(0.08 * 1.2, 1e-9));
    });

    test('W5-02 M1 zoom_internal nodeScale reaches combined live scale', () async {
      final engine = FakeArSceneEngine();
      await engine.place(const ArPlacement(x: 0, y: 0, z: -1));
      await engine.initLabScene(
        labTableModelPath: ArAssetRegistry.mejaLab,
        sampleAModelPath: ArAssetRegistry.sampleA,
        sampleBModelPath: ArAssetRegistry.sampleB,
      );

      await director.applySequenceStep(
        engine,
        missionCode: 'MISI-1',
        stepCode: 'zoom_internal',
      );

      final seq = engine.visualState.nodeScale[ArNodeIds.primary];
      expect(seq, const ArVec3(1.55, 1.55, 1.55));
      expect(engine.visualState.zoomTarget, ArNodeIds.primary);
      expect(engine.visualState.focusTarget, ArNodeIds.chloroplast);
      expect(
        engine.visualState.cameraOrbit,
        ArAssetRegistry.cameraOrbitForStep('zoom_internal'),
      );

      final live = combineLiveNodeScale(
        baseScale: 0.08,
        gestureScale: engine.visualState.userScale,
        sequenceScale: seq,
      );
      expect(live, closeTo(0.08 * 1.55, 1e-9));

      await engine.dispose();
    });

    test('W5-03 M2 zoom_membrane uses smoothZoomToTarget scale', () async {
      final engine = FakeArSceneEngine();
      await engine.place(const ArPlacement(x: 0, y: 0, z: -1));
      await engine.initLabScene(
        labTableModelPath: ArAssetRegistry.mejaLab,
        sampleAModelPath: ArAssetRegistry.sampleA,
        sampleBModelPath: ArAssetRegistry.sampleB,
      );

      await Misi2VisualHelpers.zoomIntactBilayer(engine);

      expect(
        engine.visualState.nodeScale[ArNodeIds.primary],
        Misi2VisualHelpers.bilayerZoomScale,
      );
      expect(engine.visualState.zoomTarget, ArNodeIds.primary);
      expect(engine.visualState.focusTarget, ArNodeIds.membrane);
      expect(
        combineLiveNodeScale(
          baseScale: 0.08,
          gestureScale: 1,
          sequenceScale: engine.visualState.nodeScale[ArNodeIds.primary],
        ),
        closeTo(0.08 * Misi2VisualHelpers.bilayerZoomScale.x, 1e-9),
      );

      await engine.dispose();
    });
  });

  group('intent dwell playback', () {
    StudentJourney journey() => StudentJourney(content: buildLocalContentPack())
      ..completeDeviceCheck(arSupported: false)
      ..joinWithGroup(groupName: 'Tim A', leaderName: 'Budi')
      ..markLabPlaced();

    testWidgets(
      'W5-04 intent playSequence does not complete all steps in 0ms',
      (tester) async {
        final j = journey();
        await tester.pumpWidget(MaterialApp(home: MissionScreen(journey: j)));
        await tester.pump();

        await tester.enterText(
          find.byKey(const Key('mission-assistant-input')),
          'amati organel pada sampel a',
        );
        await tester.tap(find.byKey(const Key('mission-assistant-send')));
        await tester.pump(); // start playback

        // Immediately after send: must NOT have collapsed the whole sequence.
        expect(j.missionStatus(1), isNot(MissionStatus.completed));
        expect(j.sequenceCompleted, isFalse);

        // Mid-dwell: an intermediate step / overlay should be visible.
        await tester.pump(const Duration(milliseconds: 100));
        expect(j.sequenceCompleted, isFalse);
        expect(
          find.textContaining('Langkah'),
          findsWidgets,
        );

        // Advance through remaining dwells (4 steps × 200ms + slack).
        await tester.pump(const Duration(milliseconds: 1200));
        expect(j.missionStatus(1), MissionStatus.completed);
        expect(j.sequenceCompleted, isTrue);
      },
    );

    testWidgets(
      'W5-05 pause mid-intent does not skip steps',
      (tester) async {
        // Live AR path exposes debug tracking controls (fallback hides them).
        final j = StudentJourney(content: buildLocalContentPack())
          ..completeDeviceCheck(arSupported: true)
          ..joinWithGroup(groupName: 'Tim A', leaderName: 'Budi')
          ..markLabPlaced();
        await tester.pumpWidget(MaterialApp(home: MissionScreen(journey: j)));
        await tester.pump();

        final placeKey = find.byKey(const Key('mission-debug-place'));
        await tester.ensureVisible(placeKey);
        await tester.tap(placeKey);
        await tester.pump();
        await tester.pump();

        await tester.enterText(
          find.byKey(const Key('mission-assistant-input')),
          'amati organel pada sampel a',
        );
        await tester.tap(find.byKey(const Key('mission-assistant-send')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final beforePause = j.sequenceStepIndex;

        final lostKey = find.byKey(const Key('mission-debug-tracking-lost'));
        await tester.ensureVisible(lostKey);
        await tester.tap(lostKey);
        // Parent listens via post-frame setState on trackingChanged.
        await tester.pump();
        await tester.pump();
        expect(find.textContaining('Dijeda'), findsWidgets);
        expect(find.byKey(const Key('mission-tracking-lost')), findsOneWidget);

        // While paused, time passes but sequence must not jump to completion.
        await tester.pump(const Duration(milliseconds: 800));
        expect(j.sequenceCompleted, isFalse);
        expect(j.missionStatus(1), isNot(MissionStatus.completed));
        expect(
          j.sequenceStepIndex,
          lessThan(MissionSequences.misi1.steps.length),
        );
        if (beforePause != null) {
          expect(j.sequenceStepIndex, lessThanOrEqualTo(beforePause + 1));
        }

        final okKey = find.byKey(const Key('mission-debug-tracking-ok'));
        await tester.ensureVisible(okKey);
        await tester.tap(okKey);
        await tester.pump();
        await tester.pump();
        // Finish remaining dwells after resume.
        await tester.pump(const Duration(milliseconds: 1500));
        expect(j.missionStatus(1), MissionStatus.completed);
        expect(j.sequenceCompleted, isTrue);
      },
    );

    test('W5-06 Misi1Visuals.zoomInternal sets focus + zoom engine fields',
        () async {
      final engine = FakeArSceneEngine();
      await engine.place(const ArPlacement(x: 0, y: 0, z: -1));
      await Misi1Visuals.zoomInternal(engine);

      expect(engine.visualState.focusTarget, ArNodeIds.chloroplast);
      expect(engine.visualState.zoomTarget, ArNodeIds.primary);
      expect(engine.visualState.zoomFactor, 1.55);
      expect(
        engine.visualState.nodeScale[ArNodeIds.primary],
        const ArVec3(1.55, 1.55, 1.55),
      );
      await engine.dispose();
    });
  });
}
