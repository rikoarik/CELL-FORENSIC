import 'package:cell_forensic/ar/ar_asset_registry.dart';
import 'package:cell_forensic/ar/ar_lifecycle_controller.dart';
import 'package:cell_forensic/ar/ar_overlay_frame.dart';
import 'package:cell_forensic/ar/ar_scene_engine.dart';
import 'package:cell_forensic/ar/ar_visual_director.dart';
import 'package:cell_forensic/ar/misi2_visual_helpers.dart';
import 'package:cell_forensic/ar/misi3_visuals.dart';
import 'package:cell_forensic/ar/mission_scene_panel.dart';
import 'package:cell_forensic/domain/sequence_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart' hide ArPlacement;

/// Wave 4 — mandatory AR visual fidelity cases (E10).
///
/// Prefer [FakeArSceneEngine] + director/sequence unit seams; widget cases use
/// [MissionScenePanel.debugUsePlaceholderScene] so ARView/ModelViewer stay out
/// of the widget tree when asserting live vs fallback UI mode.
void main() {
  const director = ArVisualDirector();
  const sequenceEngine = SequenceEngine();

  setUp(() {
    MissionScenePanel.debugUsePlaceholderScene = true;
  });
  tearDown(() {
    MissionScenePanel.debugUsePlaceholderScene = false;
  });

  Future<void> initLab(FakeArSceneEngine engine) async {
    await engine.place(const ArPlacement(x: 0.1, y: 0, z: -1));
    await engine.initLabScene(
      labTableModelPath: ArAssetRegistry.mejaLab,
      sampleAModelPath: ArAssetRegistry.sampleA,
      sampleBModelPath: ArAssetRegistry.sampleB,
    );
  }

  ArSceneVisualState snapshot(ArSceneEngine engine) => engine.visualState;

  // --- Case 1 ---
  testWidgets(
    'W4-01 live AR success does not enter fallback',
    (tester) async {
      final engine = LiveArSceneEngine();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MissionScenePanel(
              useAr: true,
              missionCode: 'MISI-1',
              statusLabel: 'Berjalan',
              stepLabel: 'Langkah 1',
              sequenceCompleted: false,
              onRunStep: () {},
              sceneEngine: engine,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(engine.capabilities.isFallback, isFalse);
      expect(find.byKey(const Key('mission-fallback-banner')), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const Key('mission-mode-label'))).data,
        'Mode AR (Kamera)',
      );

      await tester.tap(find.byKey(const Key('mission-debug-place')));
      await tester.pump();
      await tester.pump();

      expect(engine.placement, isNotNull);
      expect(engine.capabilities.isFallback, isFalse);
      expect(find.byKey(const Key('mission-fallback-banner')), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const Key('mission-mode-label'))).data,
        'Mode AR (Kamera)',
      );
      // Placeholder path for tests — ModelViewer must still not mount.
      expect(find.byType(ModelViewer), findsNothing);

      await engine.dispose();
    },
  );

  // --- Case 2 ---
  testWidgets(
    'W4-02 fallback on unsupported / init failure',
    (tester) async {
      final live = LiveArSceneEngine();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MissionScenePanel(
              useAr: true,
              missionCode: 'MISI-1',
              statusLabel: 'Menyiapkan',
              stepLabel: 'Tempatkan model',
              sequenceCompleted: false,
              onRunStep: () {},
              sceneEngine: live,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('mission-debug-force-fallback')));
      await tester.pump();
      await tester.pump();

      expect(
        tester.widget<Text>(find.byKey(const Key('mission-mode-label'))).data,
        'Mode 3D Viewer',
      );
      expect(find.byKey(const Key('mission-fallback-banner')), findsOneWidget);

      await live.dispose();

      // Unsupported device path uses Fake engine capability flag.
      final fake = FakeArSceneEngine();
      expect(fake.capabilities.isFallback, isTrue);
      expect(fake.capabilities.supportsPlaneDetection, isFalse);
      await fake.dispose();
    },
  );

  // --- Case 3 ---
  test('W4-03 same anchor across M1/M2/M3 steps', () async {
    final engine = FakeArSceneEngine();
    await initLab(engine);
    final placement = engine.placement;

    for (final step in MissionSequences.misi1.steps) {
      await director.applySequenceStep(
        engine,
        missionCode: 'MISI-1',
        stepCode: step.code,
      );
      expect(engine.placement, placement);
      expect(engine.visualState.labTableModelPath, ArAssetRegistry.mejaLab);
    }
    for (final step in MissionSequences.misi2.steps) {
      await director.applySequenceStep(
        engine,
        missionCode: 'MISI-2',
        stepCode: step.code,
      );
      expect(engine.placement, placement);
      expect(engine.visualState.labTableModelPath, ArAssetRegistry.mejaLab);
    }
    for (final step in MissionSequences.misi3.steps) {
      await director.applySequenceStep(
        engine,
        missionCode: 'MISI-3',
        stepCode: step.code,
      );
      expect(engine.placement, placement);
      expect(engine.visualState.labTableModelPath, ArAssetRegistry.mejaLab);
    }

    await engine.dispose();
  });

  // --- Case 4 ---
  test('W4-04 Misi 1 sequence only runs M1 visuals', () async {
    final engine = FakeArSceneEngine();
    await initLab(engine);

    final m1Steps = MissionSequences.misi1.steps.map((s) => s.code).toList();
    expect(
      m1Steps,
      [
        SequenceStepCodes.focusSampleA,
        SequenceStepCodes.zoomInternal,
        SequenceStepCodes.glowOrganelles,
        SequenceStepCodes.playShrinkAnimation,
      ],
    );
    expect(m1Steps, isNot(contains(SequenceStepCodes.focusSampleB)));
    expect(m1Steps, isNot(contains(SequenceStepCodes.showBothSamples)));

    final m1Overlays = <ArOverlayEffect>{};
    for (final step in MissionSequences.misi1.steps) {
      await director.applySequenceStep(
        engine,
        missionCode: 'MISI-1',
        stepCode: step.code,
      );
      m1Overlays.add(engine.visualState.overlay);
    }

    expect(
      m1Overlays,
      everyElement(
        isIn({
          ArOverlayEffect.none,
          ArOverlayEffect.chloroplastHighlight,
          ArOverlayEffect.vacuoleDamage,
        }),
      ),
    );
    expect(m1Overlays, isNot(contains(ArOverlayEffect.waterLeak)));
    expect(m1Overlays, isNot(contains(ArOverlayEffect.membraneDamage)));
    expect(m1Overlays, isNot(contains(ArOverlayEffect.forceArrows)));
    expect(m1Overlays, isNot(contains(ArOverlayEffect.comparisonLabels)));
    expect(engine.visualState.activeModelPath, ArAssetRegistry.vakuolaMainSolo);
    expect(engine.visualState.secondaryModelPath, isNull);
    expect(
      engine.visualState.activeModelPath,
      isNot(ArAssetRegistry.sampleB),
    );
    expect(
      engine.visualState.activeModelPath,
      isNot(ArAssetRegistry.rantaiProtein),
    );
    expect(
      engine.visualState.activeModelPath,
      isNot(ArAssetRegistry.dindingSelSolo),
    );

    await engine.dispose();
  });

  // --- Case 5 ---
  test('W4-05 Misi 2 sequence only runs M2 visuals', () async {
    final engine = FakeArSceneEngine();
    await initLab(engine);

    final m2Steps = MissionSequences.misi2.steps.map((s) => s.code).toList();
    expect(
      m2Steps,
      [
        SequenceStepCodes.focusSampleB,
        SequenceStepCodes.zoomMembrane,
        SequenceStepCodes.showTornBilayer,
        SequenceStepCodes.playLeakParticles,
      ],
    );
    expect(m2Steps, isNot(contains(SequenceStepCodes.glowOrganelles)));
    expect(m2Steps, isNot(contains(SequenceStepCodes.showForceArrows)));

    final m2Overlays = <ArOverlayEffect>{};
    for (final step in MissionSequences.misi2.steps) {
      await director.applySequenceStep(
        engine,
        missionCode: 'MISI-2',
        stepCode: step.code,
      );
      m2Overlays.add(engine.visualState.overlay);
      expect(engine.visualState.highlightTarget, ArNodeIds.membrane);
      expect(engine.visualState.secondaryModelPath, isNull);
    }

    expect(
      m2Overlays,
      everyElement(
        isIn({
          ArOverlayEffect.none,
          ArOverlayEffect.membraneDamage,
          ArOverlayEffect.waterLeak,
        }),
      ),
    );
    expect(m2Overlays, isNot(contains(ArOverlayEffect.chloroplastHighlight)));
    expect(m2Overlays, isNot(contains(ArOverlayEffect.vacuoleDamage)));
    expect(m2Overlays, isNot(contains(ArOverlayEffect.forceArrows)));
    expect(m2Overlays, isNot(contains(ArOverlayEffect.cellWallHighlight)));
    expect(engine.visualState.activeModelPath, ArAssetRegistry.rantaiProtein);
    expect(
      engine.visualState.activeModelPath,
      isNot(ArAssetRegistry.kloroplasSolo),
    );
    expect(
      engine.visualState.nodeScale[ArNodeIds.primary],
      Misi2VisualHelpers.tornBilayerScale,
    );

    await engine.dispose();
  });

  // --- Case 6 ---
  test('W4-06 Misi 3 sequence only runs M3 visuals', () async {
    final engine = FakeArSceneEngine();
    await initLab(engine);

    final m3Steps = MissionSequences.misi3.steps.map((s) => s.code).toList();
    expect(
      m3Steps,
      [
        SequenceStepCodes.showDamagedSampleA,
        SequenceStepCodes.showBothSamples,
        SequenceStepCodes.highlightCellWall,
        SequenceStepCodes.markSampleB,
        SequenceStepCodes.showForceArrows,
      ],
    );
    expect(m3Steps, isNot(contains(SequenceStepCodes.playLeakParticles)));
    expect(m3Steps, isNot(contains(SequenceStepCodes.playShrinkAnimation)));

    final m3Overlays = <ArOverlayEffect>{};
    for (final step in MissionSequences.misi3.steps) {
      await director.applySequenceStep(
        engine,
        missionCode: 'MISI-3',
        stepCode: step.code,
      );
      m3Overlays.add(engine.visualState.overlay);
      if (step.code == SequenceStepCodes.showDamagedSampleA) {
        expect(engine.visualState.secondaryModelPath, isNull);
      } else {
        expect(engine.visualState.secondaryModelPath, ArAssetRegistry.sampleB);
      }
    }

    expect(
      m3Overlays,
      everyElement(
        isIn({
          ArOverlayEffect.chloroplastHighlight,
          ArOverlayEffect.comparisonLabels,
          ArOverlayEffect.cellWallHighlight,
          ArOverlayEffect.missingStructureCross,
          ArOverlayEffect.forceArrows,
        }),
      ),
    );
    expect(m3Overlays, contains(ArOverlayEffect.chloroplastHighlight));
    expect(m3Overlays, isNot(contains(ArOverlayEffect.waterLeak)));
    expect(m3Overlays, isNot(contains(ArOverlayEffect.vacuoleDamage)));
    expect(m3Overlays, isNot(contains(ArOverlayEffect.membraneDamage)));
    expect(
      engine.visualState.activeModelPath,
      ArAssetRegistry.dindingSelSolo,
    );
    expect(
      engine.visualState.activeModelPath,
      isNot(ArAssetRegistry.mitokondriaSolo),
    );
    expect(
      engine.visualState.activeModelPath,
      isNot(ArAssetRegistry.rantaiProtein),
    );

    await engine.dispose();
  });

  // --- Case 7 ---
  test('W4-07 re-trigger does not duplicate completion', () async {
    var state = sequenceEngine.start(MissionSequences.misi1);
    while (state.status == SequenceStatus.running) {
      state = sequenceEngine.completeCurrentStep(state);
    }
    expect(state.status, SequenceStatus.completed);
    expect(state.completionEventCount, 1);
    expect(state.signalsCompletion, isTrue);

    final again = sequenceEngine.completeCurrentStep(state);
    expect(identical(again, state), isTrue);
    expect(again.completionEventCount, 1);

    final engine = FakeArSceneEngine();
    final events = <ArSceneEvent>[];
    engine.events.listen(events.add);
    await engine.runAction(SequenceStepCodes.playShrinkAnimation);
    await engine.runAction(SequenceStepCodes.playShrinkAnimation);
    expect(
      events
          .where((e) => e.type == ArSceneEventType.actionCompleted)
          .map((e) => e.actionId),
      [SequenceStepCodes.playShrinkAnimation],
    );
    await engine.dispose();
  });

  // --- Case 8 ---
  test('W4-08 unknown sequenceCode does not change scene', () async {
    final engine = FakeArSceneEngine();
    await initLab(engine);
    await director.applySequenceStep(
      engine,
      missionCode: 'MISI-1',
      stepCode: 'focus_sample_a',
    );
    final before = snapshot(engine);
    final placement = engine.placement;

    expect(sequenceEngine.startForSequenceCode('SEQ-UNKNOWN'), isNull);
    expect(sequenceEngine.startForSequenceCode('SEQ-MISI-99'), isNull);
    expect(MissionSequences.forSequenceCode('bogus'), isNull);

    await director.applySequenceStep(
      engine,
      missionCode: 'MISI-9',
      stepCode: 'invented_step',
    );

    expect(engine.placement, placement);
    expect(engine.visualState.activeModelPath, before.activeModelPath);
    expect(engine.visualState.secondaryModelPath, before.secondaryModelPath);
    expect(engine.visualState.overlay, before.overlay);
    expect(engine.visualState.labTableModelPath, before.labTableModelPath);
    expect(engine.visualState.highlightTarget, before.highlightTarget);

    await engine.dispose();
  });

  // --- Case 9 ---
  test('W4-09 tracking lost pauses sequence', () async {
    final engine = FakeArSceneEngine();
    await initLab(engine);

    var seq = sequenceEngine.start(MissionSequences.misi1);
    expect(seq.stepIndex, 0);
    expect(seq.currentStep?.code, SequenceStepCodes.focusSampleA);

    engine.updateTracking(ArTrackingState.lost);
    expect(engine.isPaused, isTrue);

    final events = <ArSceneEvent>[];
    final sub = engine.events.listen(events.add);

    final pending = engine.runAction(seq.currentStep!.code);
    await Future<void>.delayed(Duration.zero);
    // Step index unchanged while paused — sequence must not invent a new step.
    expect(seq.stepIndex, 0);
    expect(seq.currentStep?.code, SequenceStepCodes.focusSampleA);
    expect(
      events.where((e) => e.type == ArSceneEventType.actionCompleted),
      isEmpty,
    );
    expect(engine.isPaused, isTrue);

    engine.updateTracking(ArTrackingState.tracking);
    await pending;
    expect(engine.isPaused, isFalse);
    expect(seq.stepIndex, 0);
    expect(
      events.where((e) => e.type == ArSceneEventType.actionCompleted).length,
      1,
    );

    await sub.cancel();
    await engine.dispose();
  });

  // --- Case 10 ---
  testWidgets(
    'W4-10 lifecycle pause does not advance sequence',
    (tester) async {
      final engine = FakeArSceneEngine();
      final lifecycle = ArLifecycleController(engine);
      var seq = sequenceEngine.start(MissionSequences.misi2);
      final stepAtPause = seq.stepIndex;
      final codeAtPause = seq.currentStep?.code;

      lifecycle.handleAppLifecycle(AppLifecycleState.paused);
      expect(engine.isPaused, isTrue);

      var runs = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MissionScenePanel(
              useAr: true,
              missionCode: 'MISI-2',
              statusLabel: 'Dijeda',
              stepLabel: codeAtPause ?? '',
              sequenceCompleted: false,
              sequencePaused: true,
              onRunStep: () {
                runs++;
                seq = sequenceEngine.completeCurrentStep(seq);
              },
              sceneEngine: engine,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('mission-debug-place')));
      await tester.pump();

      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('mission-run-step')))
            .onPressed,
        isNull,
      );
      expect(runs, 0);
      expect(seq.stepIndex, stepAtPause);
      expect(seq.currentStep?.code, codeAtPause);

      await engine.dispose();
    },
  );

  // --- Case 11 ---
  test('W4-11 resume continues same step', () async {
    final engine = FakeArSceneEngine();
    final lifecycle = ArLifecycleController(engine);
    await initLab(engine);

    var seq = sequenceEngine.start(MissionSequences.misi1);
    // Advance to zoom_internal (index 1) before pause.
    await director.applySequenceStep(
      engine,
      missionCode: 'MISI-1',
      stepCode: SequenceStepCodes.focusSampleA,
    );
    seq = sequenceEngine.completeCurrentStep(seq);
    expect(seq.stepIndex, 1);
    expect(seq.currentStep?.code, SequenceStepCodes.zoomInternal);

    lifecycle.handleAppLifecycle(AppLifecycleState.inactive);
    expect(engine.isPaused, isTrue);
    expect(seq.stepIndex, 1);

    final queued = engine.runAction(SequenceStepCodes.zoomInternal);
    await Future<void>.delayed(Duration.zero);

    lifecycle.handleAppLifecycle(AppLifecycleState.resumed);
    expect(engine.isPaused, isTrue);
    expect(seq.stepIndex, 1);
    expect(seq.currentStep?.code, SequenceStepCodes.zoomInternal);

    lifecycle.confirmRelocalized();
    await queued;
    expect(engine.isPaused, isFalse);
    expect(seq.stepIndex, 1);

    await director.applySequenceStep(
      engine,
      missionCode: 'MISI-1',
      stepCode: SequenceStepCodes.zoomInternal,
    );
    expect(engine.visualState.activeModelPath, ArAssetRegistry.sampleA);
    expect(
      engine.visualState.nodeScale[ArNodeIds.primary],
      const ArVec3(1.55, 1.55, 1.55),
    );

    await engine.dispose();
  });

  // --- Case 12 ---
  test('W4-12 M3 side-by-side stays tabletop', () async {
    final engine = FakeArSceneEngine();
    await initLab(engine);
    final placement = engine.placement;

    for (final step in MissionSequences.misi3.steps) {
      await director.applySequenceStep(
        engine,
        missionCode: 'MISI-3',
        stepCode: step.code,
      );
      expect(engine.placement, placement);
      expect(engine.visualState.labTableModelPath, ArAssetRegistry.mejaLab);
      if (step.code == SequenceStepCodes.showDamagedSampleA) {
        expect(engine.visualState.secondaryModelPath, isNull);
        continue;
      }
      expect(engine.visualState.secondaryModelPath, ArAssetRegistry.sampleB);
      expect(
        engine.visualState.secondaryOffsetX,
        Misi3Visuals.sideBySideOffsetX,
      );
      expect(
        engine.visualState.nodeScale[ArNodeIds.primary],
        Misi3Visuals.comparisonScale,
      );
      expect(engine.visualState.visibleNodes[ArNodeIds.labTable], isTrue);
    }

    await engine.dispose();
  });

  // --- Case 13 ---
  test('W4-13 M2 particles bound to membrane target', () async {
    final engine = FakeArSceneEngine();
    await initLab(engine);

    await director.applySequenceStep(
      engine,
      missionCode: 'MISI-2',
      stepCode: SequenceStepCodes.playLeakParticles,
    );

    expect(engine.visualState.overlay, ArOverlayEffect.waterLeak);
    expect(engine.visualState.highlightTarget, ArNodeIds.membrane);
    expect(
      engine.visualState.nodeScale[ArNodeIds.membrane],
      const ArVec3(1.3, 1.3, 1.3),
    );

    // Frame anchors spray to membrane rim (not fullscreen).
    const frame = ArOverlayFrame(size: Size(400, 600));
    expect(frame.membraneRadius, lessThan(frame.size.shortestSide * 0.5));
    expect(frame.sampleACenter.dx, closeTo(200, 0.01));

    await engine.dispose();
  });

  // --- Case 14 ---
  testWidgets(
    'W4-14 model_viewer_plus not used on healthy ARCore (unit/fake)',
    (tester) async {
      final engine = LiveArSceneEngine();
      expect(engine.capabilities.isFallback, isFalse);
      expect(engine.capabilities.supportsPlaneDetection, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MissionScenePanel(
              useAr: true,
              missionCode: 'MISI-1',
              statusLabel: 'Berjalan',
              stepLabel: 'focus_sample_a',
              stepCode: 'focus_sample_a',
              sequenceCompleted: false,
              onRunStep: () {},
              sceneEngine: engine,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('mission-debug-place')));
      await tester.pump();
      await tester.pump();

      // Healthy live path: Mode AR, no fallback banner, no ModelViewer.
      expect(
        tester.widget<Text>(find.byKey(const Key('mission-mode-label'))).data,
        'Mode AR (Kamera)',
      );
      expect(find.byKey(const Key('mission-fallback-banner')), findsNothing);
      expect(find.byType(ModelViewer), findsNothing);
      expect(engine.capabilities.isFallback, isFalse);
      expect(engine.placement, isNotNull);

      await engine.dispose();
    },
  );
}
