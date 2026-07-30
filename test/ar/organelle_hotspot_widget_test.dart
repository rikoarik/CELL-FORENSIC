import 'package:cell_forensic/ar/ar_scene_engine.dart';
import 'package:cell_forensic/ar/mission_scene_panel.dart';
import 'package:cell_forensic/ar/organelle_hotspot.dart';
import 'package:cell_forensic/ar/organelle_hotspot_layer.dart';
import 'package:cell_forensic/domain/mission_progress.dart';
import 'package:cell_forensic/features/content/local_content_pack.dart';
import 'package:cell_forensic/features/journey/screens/investigation/mission_screen.dart';
import 'package:cell_forensic/features/journey/student_journey.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

StudentJourney _journey() {
  return StudentJourney(content: buildLocalContentPack())
    ..completeDeviceCheck(arSupported: false)
    ..joinWithGroup(groupName: 'Tim A', leaderName: 'Budi')
    ..markLabPlaced();
}

void main() {
  setUp(() {
    MissionScenePanel.debugUsePlaceholderScene = true;
    MissionScreen.intentStepDwell = const Duration(milliseconds: 1);
  });
  tearDown(() {
    MissionScenePanel.debugUsePlaceholderScene = false;
    MissionScreen.intentStepDwell = const Duration(milliseconds: 1000);
  });

  testWidgets('hotspots disabled until placement', (tester) async {
    final engine = FakeArSceneEngine();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MissionScenePanel(
            useAr: true,
            missionCode: 'MISI-1',
            statusLabel: 'Menyiapkan',
            stepLabel: '—',
            sequenceCompleted: false,
            onRunStep: () {},
            sceneEngine: engine,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('organelle-hotspots-disabled')), findsOneWidget);
  });

  testWidgets('select → popup; close → inspected; Tanya AI drafts', (
    tester,
  ) async {
    final controller = OrganelleHotspotController()..setEnabled(true);
    OrganelleHotspotContent? asked;
    OrganelleHotspotContent? logged;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: SizedBox(
                  width: 400,
                  height: 280,
                  child: OrganelleHotspotLayer(
                    controller: controller,
                    dualSamples: false,
                  ),
                ),
              ),
              OrganelleObservationSheet(
                controller: controller,
                onAskAi: (c) => asked = c,
                onLogbook: (c) => logged = c,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('organelle-intro-hint')), findsOneWidget);
    expect(find.byKey(const Key('hotspot-plant-cell')), findsOneWidget);
    expect(find.byKey(const Key('hotspot-chloroplast')), findsOneWidget);
    expect(find.textContaining('krisis turgor'), findsOneWidget);

    controller.select(OrganelleHotspotId.chloroplast);
    await tester.pump();

    expect(
      controller.phaseOf(OrganelleHotspotId.chloroplast),
      OrganelleHotspotPhase.selected,
    );
    expect(find.byKey(const Key('organelle-popup-chloroplast')), findsOneWidget);

    await tester.tap(find.byKey(const Key('organelle-popup-close')));
    await tester.pump();

    expect(controller.openPopupId, isNull);
    expect(
      controller.phaseOf(OrganelleHotspotId.chloroplast),
      OrganelleHotspotPhase.inspected,
    );

    controller.select(OrganelleHotspotId.vacuole);
    await tester.pump();
    await tester.tap(find.byKey(const Key('organelle-popup-ask-ai')));
    await tester.pump();
    expect(asked?.id, OrganelleHotspotId.vacuole);
    expect(asked?.draftAiQuestion, contains('turgor'));

    controller.select(OrganelleHotspotId.chloroplast);
    await tester.pump();
    await tester.tap(find.byKey(const Key('organelle-popup-logbook')));
    await tester.pump();
    expect(logged?.id, OrganelleHotspotId.chloroplast);

    controller.select(OrganelleHotspotId.plantCell);
    await tester.pump();
    expect(
      find.byKey(const Key('organelle-popup-plantCell')),
      findsOneWidget,
    );
    expect(find.textContaining('Kloroplas dan Vakuola Raksasa'), findsOneWidget);
  });

  testWidgets('overlay hit selects vakuola', (tester) async {
    final controller = OrganelleHotspotController()..setEnabled(true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(
                width: 400,
                height: 400,
                child: OrganelleHotspotLayer(
                  controller: controller,
                  dualSamples: false,
                ),
              ),
              OrganelleObservationSheet(controller: controller),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    // Tap the vacuole target; secondary kloroplas is offset away from center.
    await tester.tap(
      find.byKey(const Key('hotspot-vacuole')),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(controller.openPopupId, isNotNull);
    expect(
      {OrganelleHotspotId.vacuole, OrganelleHotspotId.chloroplast},
      contains(controller.openPopupId),
    );
    expect(find.byKey(const Key('organelle-popup-closed')), findsNothing);
  });

  testWidgets('Tanya AI drafts only — no sequence overlay', (tester) async {
    final draft = TextEditingController();
    addTearDown(draft.dispose);
    final engine = FakeArSceneEngine();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: MissionScenePanel(
                  useAr: false,
                  missionCode: 'MISI-1',
                  statusLabel: 'Laboratorium siap',
                  stepLabel: '—',
                  sequenceCompleted: false,
                  onRunStep: () {},
                  sceneEngine: engine,
                  onHotspotAskAi: (content) {
                    draft.text = content.draftAiQuestion;
                  },
                ),
              ),
              TextField(
                key: const Key('mission-assistant-input'),
                controller: draft,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final btn = find.byKey(const Key('mission-tap-vacuole'));
    await tester.ensureVisible(btn);
    await tester.tap(btn);
    await tester.pump();
    await tester.tap(find.byKey(const Key('organelle-popup-ask-ai')));
    await tester.pump();

    expect(draft.text, contains('turgor'));
    expect(
      engine.visualState.overlay,
      isNot(ArOverlayEffect.chloroplastHighlight),
    );
  });

  testWidgets('hotspot select does not complete mission or run sequence', (
    tester,
  ) async {
    MissionScenePanel.debugUsePlaceholderScene = true;
    addTearDown(() {
      MissionScenePanel.debugUsePlaceholderScene = false;
    });

    final journey = _journey()..startMissionFromIntent(1);
    final beforeStep = journey.sequenceStepIndex;
    final engine = FakeArSceneEngine();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MissionScenePanel(
            useAr: false,
            missionCode: 'MISI-1',
            statusLabel: 'Berjalan',
            stepLabel: '—',
            sequenceCompleted: false,
            onRunStep: () {},
            sceneEngine: engine,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final btn = find.byKey(const Key('mission-tap-chloroplast'));
    await tester.ensureVisible(btn);
    await tester.tap(btn);
    await tester.pump();

    expect(journey.sequenceStepIndex, beforeStep);
    expect(journey.missionStatus(1), MissionStatus.running);
    expect(journey.sequenceCompleted, isFalse);
    expect(
      engine.visualState.overlay,
      isNot(ArOverlayEffect.chloroplastHighlight),
    );
  });
}
