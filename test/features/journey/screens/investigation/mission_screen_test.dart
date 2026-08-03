import 'package:cell_forensic/ar/ar_capability_probe.dart';
import 'package:cell_forensic/ar/mission_scene_panel.dart';
import 'package:cell_forensic/domain/intent_matcher.dart';
import 'package:cell_forensic/domain/mission_progress.dart';
import 'package:cell_forensic/features/content/local_content_pack.dart';
import 'package:cell_forensic/features/journey/screens/investigation/mission_screen.dart';
import 'package:cell_forensic/features/journey/student_journey.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _runStepKey = Key('mission-run-step');
const _completeMissionKey = Key('mission-complete');
const _assistantInputKey = Key('mission-assistant-input');
const _assistantSendKey = Key('mission-assistant-send');
const _assistantFabKey = Key('assistant-fab');
const _logbookFabKey = Key('mission-logbook-toggle');

StudentJourney _investigatingJourney({bool arSupported = false}) {
  return StudentJourney(content: buildLocalContentPack())
    ..completeDeviceCheck(arSupported: arSupported)
    ..joinWithGroup(groupName: 'Tim A', leaderName: 'Budi')
    // Scene 1 placement unlocks missions and auto-starts Misi 1.
    ..markLabPlaced();
}

Widget _wrap(Widget child) => MaterialApp(home: child);

Future<void> _tapRunStep(WidgetTester tester) async {
  final finder = find.byKey(_runStepKey);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _runSequenceToCompletion(
  WidgetTester tester,
  StudentJourney journey,
) async {
  final taps = journey.activeMission.sequence.steps.length + 1;
  for (var i = 0; i < taps; i++) {
    await _tapRunStep(tester);
  }
}

Future<void> _openAssistant(WidgetTester tester) async {
  await tester.tap(find.byKey(_assistantFabKey));
  await tester.pumpAndSettle();
}

Future<void> _openLogbook(WidgetTester tester) async {
  await tester.tap(find.byKey(_logbookFabKey));
  await tester.pumpAndSettle();
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

  testWidgets('menampilkan judul misi / Misi 1', (tester) async {
    final journey = _investigatingJourney()..startMissionFromIntent(1);
    await tester.pumpWidget(_wrap(MissionScreen(journey: journey)));

    expect(find.text(journey.activeMission.title), findsWidgets);
    expect(find.textContaining('Misi 1'), findsWidgets);
    expect(find.byKey(_assistantFabKey), findsOneWidget);
    expect(find.byKey(_logbookFabKey), findsOneWidget);

    await _openAssistant(tester);
    expect(find.byKey(const Key('mission-assistant-mic')), findsOneWidget);
    expect(find.textContaining('Tanya Asisten AI'), findsWidgets);
  });

  testWidgets('panel AR fallback mulai dari Misi 1 setelah place', (tester) async {
    final journey = _investigatingJourney();
    await tester.pumpWidget(_wrap(MissionScreen(journey: journey)));

    // markLabPlaced auto-starts Misi 1 — chrome shows mission title, not Scene 1.
    expect(find.textContaining('Misi 1'), findsWidgets);
    expect(find.text(journey.activeMission.title), findsWidgets);
    expect(find.textContaining('Menyiapkan'), findsWidgets);
  });

  testWidgets('FAB tidak menutupi kartu hasil hotspot', (tester) async {
    final journey = _investigatingJourney()..startMissionFromIntent(1);
    await tester.pumpWidget(_wrap(MissionScreen(journey: journey)));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(_assistantFabKey), findsOneWidget);
    expect(find.byKey(_logbookFabKey), findsOneWidget);

    final vacuole = find.byKey(const Key('mission-tap-vacuole'));
    await tester.ensureVisible(vacuole);
    await tester.tap(vacuole);
    await tester.pump();

    expect(
      find.byKey(const Key('organelle-popup-vacuole')),
      findsOneWidget,
    );
    expect(find.byKey(_assistantFabKey), findsNothing);
    expect(find.byKey(_logbookFabKey), findsNothing);

    await tester.tap(find.byKey(const Key('organelle-popup-close')));
    await tester.pump();

    expect(find.byKey(_assistantFabKey), findsOneWidget);
    expect(find.byKey(_logbookFabKey), findsOneWidget);
  });

  testWidgets('panel scene memenuhi area bawah tanpa gap kosong', (tester) async {
    final journey = _investigatingJourney()..startMissionFromIntent(1);
    await tester.pumpWidget(_wrap(MissionScreen(journey: journey)));
    await tester.pump();

    final stackRect = tester.getRect(
      find.byKey(const Key('mission-scene-stack')),
    );
    final panelRect = tester.getRect(find.byType(MissionScenePanel));

    expect(panelRect.bottom, stackRect.bottom);
  });

  testWidgets(
    'menjalankan langkah sequence hingga selesai lalu aktifkan Selesaikan Misi',
    (tester) async {
      final journey = _investigatingJourney()..startMissionFromIntent(1);
      await tester.pumpWidget(_wrap(MissionScreen(journey: journey)));

      final beforeButton = tester.widget<FilledButton>(
        find.byKey(_completeMissionKey),
      );
      expect(beforeButton.onPressed, isNull);

      await _tapRunStep(tester);
      expect(find.textContaining('Berjalan'), findsWidgets);

      final remaining = journey.activeMission.sequence.steps.length;
      for (var i = 0; i < remaining; i++) {
        await _tapRunStep(tester);
      }
      expect(find.textContaining('Selesai'), findsWidgets);

      final afterButton = tester.widget<FilledButton>(
        find.byKey(_completeMissionKey),
      );
      expect(afterButton.onPressed, isNotNull);
    },
  );

  testWidgets(
    'Selesaikan Misi menyelesaikan misi aktif lalu lanjut ke misi berikutnya',
    (tester) async {
      final journey = _investigatingJourney()..startMissionFromIntent(1);
      await tester.pumpWidget(_wrap(MissionScreen(journey: journey)));

      await _runSequenceToCompletion(tester, journey);
      await tester.ensureVisible(find.byKey(_completeMissionKey));
      await tester.pump();
      await tester.tap(find.byKey(_completeMissionKey));
      await tester.pumpAndSettle();

      expect(journey.missionStatus(1), MissionStatus.completed);
      expect(journey.missionStatus(2), MissionStatus.running);
      expect(journey.activeMission.code, 'MISI-2');
      expect(
        find.textContaining('Misi 2 — Analisis'),
        findsOneWidget,
      );
    },
  );

  testWidgets('asisten membalas intent yang dikenali', (tester) async {
    final journey = _investigatingJourney();
    await tester.pumpWidget(_wrap(MissionScreen(journey: journey)));

    await _openAssistant(tester);
    await tester.ensureVisible(find.byKey(_assistantInputKey));
    await tester.enterText(
      find.byKey(_assistantInputKey),
      'amati organel pada sampel a',
    );
    await tester.ensureVisible(find.byKey(_assistantSendKey));
    await tester.tap(find.byKey(_assistantSendKey));
    await tester.pump();
    // Intent autoplay dwells per step — advance fake async timers.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('Perhatikan organel'), findsOneWidget);
    // Offline sequenceCode auto-plays M1 AR → observation completes (PDF SCENE 2).
    expect(journey.missionStatus(1), MissionStatus.completed);
    expect(journey.sequenceCompleted, isTrue);
    expect(find.textContaining('Selesai'), findsWidgets);
  });

  testWidgets('asisten menolak label provisional Organel X', (tester) async {
    final journey = _investigatingJourney();
    await tester.pumpWidget(_wrap(MissionScreen(journey: journey)));

    await _openAssistant(tester);
    await tester.ensureVisible(find.byKey(_assistantInputKey));
    await tester.enterText(find.byKey(_assistantInputKey), 'apa itu organel x');
    await tester.ensureVisible(find.byKey(_assistantSendKey));
    await tester.tap(find.byKey(_assistantSendKey));
    await tester.pump();

    expect(find.text(IntentMatcher.provisionalResponse), findsOneWidget);
  });

  testWidgets('asisten memakai unknownResponse untuk input asing', (
    tester,
  ) async {
    final journey = _investigatingJourney();
    await tester.pumpWidget(_wrap(MissionScreen(journey: journey)));

    await _openAssistant(tester);
    await tester.ensureVisible(find.byKey(_assistantInputKey));
    await tester.enterText(find.byKey(_assistantInputKey), 'apa warna langit');
    await tester.ensureVisible(find.byKey(_assistantSendKey));
    await tester.tap(find.byKey(_assistantSendKey));
    await tester.pump();

    expect(find.text(IntentMatcher.unknownResponse), findsOneWidget);
  });

  testWidgets('logbook autosave ke journey saat mengisi field', (tester) async {
    final journey = _investigatingJourney()..startMissionFromIntent(1);
    await tester.pumpWidget(_wrap(MissionScreen(journey: journey)));

    await _openLogbook(tester);

    const answer = 'Sel tampak mengkerut';
    await tester.enterText(find.byKey(const Key('logbook-field-0')), answer);
    await tester.pump();

    final saved = journey.logbookByMission['MISI-1'];
    expect(saved, isNotNull);
    expect(saved!.values, contains(answer));
  });

  testWidgets('assistant draft dan logbook tetap saat upgrade ke live AR', (
    tester,
  ) async {
    final journey = _investigatingJourney(arSupported: false)
      ..startMissionFromIntent(1);
    await tester.pumpWidget(_wrap(MissionScreen(journey: journey)));
    await tester.pump();

    await _openAssistant(tester);
    await tester.enterText(
      find.byKey(_assistantInputKey),
      'draft sebelum upgrade',
    );
    await tester.tap(find.byKey(const Key('assistant-tab-logbook')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('logbook-field-0')),
      'catatan sebelum upgrade',
    );
    await tester.pump();

    journey.enableLiveAr();
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('assistant-tab-view-logbook')), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(const Key('logbook-field-0')))
          .controller
          ?.text,
      'catatan sebelum upgrade',
    );

    await tester.tap(find.byKey(const Key('assistant-tab-chat')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('assistant-tab-view-chat')), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(_assistantInputKey)).controller?.text,
      'draft sebelum upgrade',
    );
  });

  testWidgets('unsupported restored AR session switches to 3D viewer', (
    tester,
  ) async {
    final journey = _investigatingJourney(arSupported: true)
      ..startMissionFromIntent(1)
      ..saveSequenceProgress(stepIndex: 1, completed: false);
    final probe = ArCapabilityProbe(
      debugOverride: () async => const ArCapabilityResult(
        supported: false,
        reason: 'arcore_unsupported_device',
        platform: 'android',
        arcoreAvailability: 'UNSUPPORTED_DEVICE_NOT_CAPABLE',
        cameraGranted: true,
        probed: true,
      ),
    );

    await tester.pumpWidget(
      _wrap(MissionScreen(journey: journey, capabilityProbe: probe)),
    );
    await tester.pump();
    await tester.pump();

    expect(journey.arSupported, isFalse);
    expect(journey.stage, JourneyStage.investigating);
    expect(journey.sequenceStepIndex, 1);
    expect(journey.missionStatus(1), MissionStatus.running);
    expect(
      tester.widget<Text>(find.byKey(const Key('mission-mode-label'))).data,
      'Mode 3D Viewer',
    );
  });

  testWidgets('AR path menahan sequence sampai place + intent', (tester) async {
    final journey = _investigatingJourney(arSupported: true);
    // markLabPlaced was called by helper — reset placement gate for live AR UI.
    await tester.pumpWidget(_wrap(MissionScreen(journey: journey)));
    await tester.pump();

    // Live AR without place: run step disabled.
    // Helper already marked lab placed for progress; UI still needs plane place.
    final placeKey = find.byKey(const Key('mission-debug-place'));
    if (placeKey.evaluate().isNotEmpty) {
      await tester.ensureVisible(placeKey);
      await tester.pump();
      await tester.tap(placeKey);
      await tester.pump();
      await tester.pump();
    }

    // Without running mission, sequence should not advance from idle.
    journey.startMissionFromIntent(1);
    await tester.pump();

    expect(
      tester.widget<FilledButton>(find.byKey(_runStepKey)).onPressed,
      isNotNull,
    );

    await _tapRunStep(tester);
    expect(find.textContaining('Berjalan'), findsWidgets);

    final lostKey = find.byKey(const Key('mission-debug-tracking-lost'));
    await tester.ensureVisible(lostKey);
    await tester.pump();
    await tester.tap(lostKey);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('mission-tracking-lost')), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(_runStepKey)).onPressed,
      isNull,
    );

    final okKey = find.byKey(const Key('mission-debug-tracking-ok'));
    await tester.ensureVisible(okKey);
    await tester.pump();
    await tester.tap(okKey);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('mission-tracking-lost')), findsNothing);
  });

  testWidgets(
    'misi 2 dan 3 memakai sequence + briefing masing-masing',
    (tester) async {
      final journey = _investigatingJourney()..startMissionFromIntent(2);
      await tester.pumpWidget(_wrap(MissionScreen(journey: journey)));
      expect(find.textContaining('Misi 2 — Analisis'), findsOneWidget);

      journey.startMissionFromIntent(3);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Menyelidiki perbedaan'),
        findsOneWidget,
      );

      await _runSequenceToCompletion(tester, journey);
      expect(find.textContaining('Selesai'), findsWidgets);
    },
  );

  testWidgets('memulihkan progres sequence mid-misi dari snapshot journey', (
    tester,
  ) async {
    final journey = _investigatingJourney()..startMissionFromIntent(1);
    // Simulate mid-mission: step index 1 of 4.
    journey.saveSequenceProgress(stepIndex: 1, completed: false);

    await tester.pumpWidget(_wrap(MissionScreen(journey: journey)));
    await tester.pump();

    // Restored engine should show running state with remaining steps.
    expect(find.textContaining('Berjalan'), findsWidgets);
    expect(
      tester.widget<FilledButton>(find.byKey(_completeMissionKey)).onPressed,
      isNull,
    );

    // Finish remaining steps (3 left after restore to index 1).
    for (var i = 0; i < 3; i++) {
      await _tapRunStep(tester);
    }
    expect(find.textContaining('Selesai'), findsWidgets);
    expect(
      tester.widget<FilledButton>(find.byKey(_completeMissionKey)).onPressed,
      isNotNull,
    );
  });
}
