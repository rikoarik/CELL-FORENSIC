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

StudentJourney _investigatingJourney({bool arSupported = false}) {
  return StudentJourney(content: buildLocalContentPack())
    ..completeDeviceCheck(arSupported: arSupported)
    ..joinWithGroup(groupName: 'Tim A', leaderName: 'Budi')
    // Scene 1 placement unlocks missions; does not auto-start Misi 1.
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

void main() {
  setUp(() {
    MissionScenePanel.debugUsePlaceholderScene = true;
  });
  tearDown(() {
    MissionScenePanel.debugUsePlaceholderScene = false;
  });

  testWidgets('menampilkan judul misi / Scene 1', (tester) async {
    final journey = _investigatingJourney()..startMissionFromIntent(1);
    await tester.pumpWidget(_wrap(MissionScreen(journey: journey)));

    expect(find.text(journey.activeMission.title), findsOneWidget);
    expect(find.textContaining('Fokus ke Sampel A'), findsOneWidget);
    expect(find.byKey(const Key('mission-assistant-mic')), findsOneWidget);
    expect(find.textContaining('Tanya Asisten AI'), findsWidgets);
  });

  testWidgets('panel AR fallback mulai dari laboratorium siap', (tester) async {
    final journey = _investigatingJourney();
    await tester.pumpWidget(_wrap(MissionScreen(journey: journey)));

    expect(find.textContaining('Laboratorium siap'), findsWidgets);
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
    'Selesaikan Misi menandai observasi selesai tanpa lompat linear',
    (tester) async {
      final journey = _investigatingJourney()..startMissionFromIntent(1);
      await tester.pumpWidget(_wrap(MissionScreen(journey: journey)));

      await _runSequenceToCompletion(tester, journey);
      await tester.ensureVisible(find.byKey(_completeMissionKey));
      await tester.pump();
      await tester.tap(find.byKey(_completeMissionKey));
      await tester.pumpAndSettle();

      expect(journey.activeMission.code, 'MISI-1');
      expect(journey.missionStatus(1), MissionStatus.completed);
      expect(
        find.textContaining('Investigasi Internal Sampel A'),
        findsOneWidget,
      );
    },
  );

  testWidgets('asisten membalas intent yang dikenali', (tester) async {
    final journey = _investigatingJourney();
    await tester.pumpWidget(_wrap(MissionScreen(journey: journey)));

    await tester.ensureVisible(find.byKey(_assistantInputKey));
    await tester.enterText(
      find.byKey(_assistantInputKey),
      'amati organel pada sampel a',
    );
    await tester.ensureVisible(find.byKey(_assistantSendKey));
    await tester.tap(find.byKey(_assistantSendKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('Perhatikan organel'), findsOneWidget);
    // Offline sequenceCode auto-plays M1 AR → observation completes (PDF SCENE 2).
    expect(journey.missionStatus(1), MissionStatus.completed);
    expect(journey.sequenceCompleted, isTrue);
    expect(find.textContaining('Selesai'), findsWidgets);
  });

  testWidgets('asisten menolak label provisional Organel X', (tester) async {
    final journey = _investigatingJourney();
    await tester.pumpWidget(_wrap(MissionScreen(journey: journey)));

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

    await tester.tap(find.byKey(const Key('mission-logbook-toggle')));
    await tester.pump();

    const answer = 'Sel tampak mengkerut';
    await tester.enterText(find.byKey(const Key('logbook-field-0')), answer);
    await tester.pump();

    final saved = journey.logbookByMission['MISI-1'];
    expect(saved, isNotNull);
    expect(saved!.values, contains(answer));
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
    expect(
      tester.widget<FilledButton>(find.byKey(_runStepKey)).onPressed,
      isNotNull,
    );
  });

  testWidgets('misi 2 dan 3 memakai sequence + briefing masing-masing', (
    tester,
  ) async {
    final journey = _investigatingJourney()..startMissionFromIntent(2);
    await tester.pumpWidget(_wrap(MissionScreen(journey: journey)));
    expect(find.textContaining('Membran Sampel B'), findsOneWidget);

    journey.startMissionFromIntent(3);
    await tester.pumpAndSettle();
    expect(find.textContaining('Perbandingan Lapisan'), findsOneWidget);

    await _runSequenceToCompletion(tester, journey);
    expect(find.textContaining('Selesai'), findsWidgets);
  });

  testWidgets('memulihkan progres sequence mid-misi dari snapshot journey', (
    tester,
  ) async {
    final journey = _investigatingJourney()
      ..startMissionFromIntent(1)
      ..saveSequenceProgress(stepIndex: 2, completed: false);
    await tester.pumpWidget(_wrap(MissionScreen(journey: journey)));
    await tester.pump();

    expect(find.textContaining('Berjalan'), findsWidgets);
    expect(find.textContaining('Langkah'), findsWidgets);

    final remaining = journey.activeMission.sequence.steps.length - 1;
    for (var i = 0; i < remaining; i++) {
      await _tapRunStep(tester);
    }
    expect(find.textContaining('Selesai'), findsWidgets);
    expect(
      tester.widget<FilledButton>(find.byKey(_completeMissionKey)).onPressed,
      isNotNull,
    );
  });
}
