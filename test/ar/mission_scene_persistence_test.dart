import 'package:cell_forensic/ar/ar_asset_registry.dart';
import 'package:cell_forensic/ar/ar_scene_engine.dart';
import 'package:cell_forensic/ar/ar_visual_director.dart';
import 'package:cell_forensic/ar/mission_scene_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    MissionScenePanel.debugUsePlaceholderScene = true;
  });
  tearDown(() {
    MissionScenePanel.debugUsePlaceholderScene = false;
  });

  testWidgets('live AR path does not activate fallback after successful place',
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

    expect(find.byKey(const Key('mission-mode-label')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('mission-mode-label'))).data,
      'Mode AR (Kamera)',
    );
    expect(find.byKey(const Key('mission-fallback-banner')), findsNothing);

    await tester.tap(find.byKey(const Key('mission-debug-place')));
    await tester.pump();
    await tester.pump();

    expect(engine.capabilities.isFallback, isFalse);
    expect(engine.placement, isNotNull);
    // GAP-1: placement shows lab table + both samples, no M1 step auto-start.
    expect(engine.visualState.labTableModelPath, ArAssetRegistry.mejaLab);
    expect(engine.visualState.activeModelPath, ArAssetRegistry.sampleA);
    expect(engine.visualState.secondaryModelPath, ArAssetRegistry.sampleB);
    expect(engine.visualState.overlay, ArOverlayEffect.comparisonLabels);
    expect(
      tester.widget<Text>(find.byKey(const Key('mission-mode-label'))).data,
      'Mode AR (Kamera)',
    );
    expect(find.byKey(const Key('mission-fallback-banner')), findsNothing);

    await engine.dispose();
  });

  testWidgets('fallback activates on forced init failure only', (tester) async {
    final engine = LiveArSceneEngine();
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
            sceneEngine: engine,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('mission-debug-force-fallback')));
    await tester.pump();

    expect(
      tester.widget<Text>(find.byKey(const Key('mission-mode-label'))).data,
      'Mode 3D Viewer',
    );
    expect(find.byKey(const Key('mission-fallback-banner')), findsOneWidget);
    // Engine capability stays Live — soft UI fallback only.
    expect(engine.capabilities.isFallback, isFalse);

    await engine.dispose();
  });

  test('same anchor/placement across M1 sequence steps via director', () async {
    final engine = LiveArSceneEngine();
    const director = ArVisualDirector();
    await engine.place(const ArPlacement(x: 2, y: 0, z: -1));
    final placement = engine.placement;

    await director.applySequenceStep(
      engine,
      missionCode: 'MISI-1',
      stepCode: 'focus_sample_a',
    );
    await director.applySequenceStep(
      engine,
      missionCode: 'MISI-1',
      stepCode: 'glow_organelles',
    );

    expect(engine.placement, placement);
    expect(engine.visualState.overlay, ArOverlayEffect.chloroplastHighlight);
    await engine.dispose();
  });

  testWidgets('lifecycle pause does not advance when run step disabled',
      (tester) async {
    final engine = LiveArSceneEngine();
    var runs = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MissionScenePanel(
            useAr: true,
            missionCode: 'MISI-1',
            statusLabel: 'Dijeda',
            stepLabel: 'paused',
            sequenceCompleted: false,
            sequencePaused: true,
            onRunStep: () => runs++,
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
    await engine.dispose();
  });

  testWidgets('tracking recovery re-enables run step', (tester) async {
    final engine = LiveArSceneEngine();
    late void Function(void Function()) setState;
    var paused = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, ss) {
              setState = ss;
              return MissionScenePanel(
                useAr: true,
                missionCode: 'MISI-1',
                statusLabel: paused ? 'Dijeda' : 'Berjalan',
                stepLabel: 'step',
                sequenceCompleted: false,
                sequencePaused: paused,
                onRunStep: () {},
                sceneEngine: engine,
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('mission-debug-place')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('mission-debug-tracking-lost')));
    await tester.pump();
    setState(() => paused = true);
    await tester.pump();
    expect(find.byKey(const Key('mission-tracking-lost')), findsOneWidget);

    await tester.tap(find.byKey(const Key('mission-debug-tracking-ok')));
    await tester.pump();
    setState(() => paused = false);
    await tester.pump();

    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('mission-run-step')))
          .onPressed,
      isNotNull,
    );
    await engine.dispose();
  });
}
