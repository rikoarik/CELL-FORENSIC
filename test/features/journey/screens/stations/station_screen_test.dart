import 'package:cell_forensic/features/content/local_content_pack.dart';
import 'package:cell_forensic/features/journey/screens/stations/station_screen.dart';
import 'package:cell_forensic/features/journey/student_journey.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drives a fresh [StudentJourney] all the way to the stations stage so the
/// widget under test starts on the first (locked) POS station.
StudentJourney _stationsJourney(ContentPack pack) {
  final journey = StudentJourney(content: pack)
    ..completeDeviceCheck(arSupported: false)
    ..joinWithGroup(groupName: 'Tim A', leaderName: 'Budi')
    ..debugCompleteAllMissionsToConclusion();
  journey.submitInvestigation(
    sampleAIdentity: 'Sel tumbuhan',
    sampleAReasoning: 'Dinding sel',
    sampleBIdentity: 'Sel hewan',
    sampleBReasoning: 'Membran robek',
    hypothesis: 'Bukti mendukung.',
  );
  return journey;
}

/// A tiny content pack with a short station timer so timeout behaviour can be
/// exercised by pumping a short duration.
ContentPack _shortPack() => const ContentPack(
  sessionTitle: 'Uji',
  joinCode: 'UJI01',
  stationDurationSeconds: 3,
  missions: [],
  stations: [
    StationContent(
      code: 'S1',
      title: 'Stasiun 1',
      pin: '1111',
      markerCode: 'MARKER-S1',
      questions: [
        QuestionContent(
          code: 'S1Q1',
          text: 'Soal objektif',
          kind: QuestionKind.objective,
          maxScore: 10,
          correctAnswer: 'a',
        ),
      ],
    ),
    StationContent(
      code: 'S2',
      title: 'Stasiun 2',
      pin: '2222',
      markerCode: 'MARKER-S2',
      questions: [
        QuestionContent(
          code: 'S2Q1',
          text: 'Soal esai',
          kind: QuestionKind.essay,
          maxScore: 5,
        ),
      ],
    ),
  ],
);

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('locked station shows marker scan, PIN entry and fallback '
      'guidance (FR-091, FR-092)', (tester) async {
    final journey = _stationsJourney(buildLocalContentPack());
    await tester.pumpWidget(_wrap(StationScreen(journey: journey)));

    expect(find.byKey(const ValueKey('station-marker-scan')), findsOneWidget);
    expect(find.text('Pindai Marker'), findsOneWidget);
    expect(find.byKey(const ValueKey('station-pin')), findsOneWidget);
    expect(find.text('Buka Stasiun'), findsOneWidget);
    expect(find.textContaining('marker'), findsWidgets);
  });

  testWidgets('simulated marker scan unlocks the active station (E5-01)', (
    tester,
  ) async {
    final journey = _stationsJourney(buildLocalContentPack());
    await tester.pumpWidget(_wrap(StationScreen(journey: journey)));

    await tester.tap(find.byKey(const ValueKey('station-marker-scan')));
    await tester.pump();

    expect(journey.activeStationUnlocked, isTrue);
    expect(find.text('Kumpulkan'), findsOneWidget);
    expect(find.byKey(const ValueKey('answer-POS1-Q1')), findsOneWidget);

    await tester.tap(find.text('Kumpulkan'));
    await tester.pump();
  });

  testWidgets('wrong PIN surfaces the journey lastError', (tester) async {
    final journey = _stationsJourney(buildLocalContentPack());
    await tester.pumpWidget(_wrap(StationScreen(journey: journey)));

    await tester.enterText(find.byKey(const ValueKey('station-pin')), '0000');
    await tester.tap(find.text('Buka Stasiun'));
    await tester.pump();

    expect(journey.activeStationUnlocked, isFalse);
    expect(find.textContaining('salah'), findsWidgets);
  });

  testWidgets('correct PIN unlocks and reveals questions, timer and submit', (
    tester,
  ) async {
    final journey = _stationsJourney(buildLocalContentPack());
    await tester.pumpWidget(_wrap(StationScreen(journey: journey)));

    await tester.enterText(find.byKey(const ValueKey('station-pin')), '1111');
    await tester.tap(find.text('Buka Stasiun'));
    await tester.pump();

    expect(journey.activeStationUnlocked, isTrue);
    expect(find.text('Kumpulkan'), findsOneWidget);
    expect(find.byKey(const ValueKey('answer-POS1-Q1')), findsOneWidget);
    expect(find.textContaining('Sisa waktu'), findsOneWidget);

    // Countdown must be cleaned up so no timers leak past the test.
    await tester.tap(find.text('Kumpulkan'));
    await tester.pump();
  });

  testWidgets('POS 1 shows identification questions (E5-02)', (tester) async {
    final journey = _stationsJourney(buildLocalContentPack());
    await tester.pumpWidget(_wrap(StationScreen(journey: journey)));
    await tester.enterText(find.byKey(const ValueKey('station-pin')), '1111');
    await tester.tap(find.text('Buka Stasiun'));
    await tester.pump();

    expect(find.textContaining('dinding sel'), findsWidgets);
    expect(find.byKey(const ValueKey('answer-POS1-Q1')), findsOneWidget);
    expect(find.byKey(const ValueKey('answer-POS1-Q2')), findsOneWidget);

    await tester.tap(find.text('Kumpulkan'));
    await tester.pump();
  });

  testWidgets('POS 2 shows damage-analysis questions after rotation (E5-03)', (
    tester,
  ) async {
    final journey = _stationsJourney(buildLocalContentPack())
      ..unlockStation('1111')
      ..submitActiveStation();
    await tester.pumpWidget(_wrap(StationScreen(journey: journey)));

    expect(journey.activeStation.code, 'POS-2');
    await tester.enterText(find.byKey(const ValueKey('station-pin')), '2222');
    await tester.tap(find.text('Buka Stasiun'));
    await tester.pump();

    expect(find.textContaining('kerusakan'), findsWidgets);
    expect(find.byKey(const ValueKey('answer-POS2-Q1')), findsOneWidget);
    expect(find.byKey(const ValueKey('answer-POS2-Q2')), findsOneWidget);

    await tester.tap(find.text('Kumpulkan'));
    await tester.pump();
  });

  testWidgets('POS 3 shows forensic-conclusion questions (E5-04)', (
    tester,
  ) async {
    final journey = _stationsJourney(buildLocalContentPack())
      ..unlockStation('1111')
      ..submitActiveStation()
      ..unlockStation('2222')
      ..submitActiveStation();
    await tester.pumpWidget(_wrap(StationScreen(journey: journey)));

    expect(journey.activeStation.code, 'POS-3');
    await tester.enterText(find.byKey(const ValueKey('station-pin')), '3333');
    await tester.tap(find.text('Buka Stasiun'));
    await tester.pump();

    expect(find.textContaining('hipotesis'), findsWidgets);
    expect(find.byKey(const ValueKey('answer-POS3-Q1')), findsOneWidget);
    expect(find.byKey(const ValueKey('answer-POS3-Q2')), findsOneWidget);

    await tester.tap(find.text('Kumpulkan'));
    await tester.pump();
  });

  testWidgets('typing an answer autosaves via answerQuestion', (tester) async {
    final journey = _stationsJourney(buildLocalContentPack());
    await tester.pumpWidget(_wrap(StationScreen(journey: journey)));

    await tester.enterText(find.byKey(const ValueKey('station-pin')), '1111');
    await tester.tap(find.text('Buka Stasiun'));
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('answer-POS1-Q1')),
      'Sampel A',
    );
    await tester.pump();

    expect(journey.answerFor('POS1-Q1'), 'Sampel A');

    await tester.tap(find.text('Kumpulkan'));
    await tester.pump();
  });

  testWidgets('Kumpulkan submits the active station and advances', (
    tester,
  ) async {
    final journey = _stationsJourney(buildLocalContentPack());
    await tester.pumpWidget(_wrap(StationScreen(journey: journey)));

    await tester.enterText(find.byKey(const ValueKey('station-pin')), '1111');
    await tester.tap(find.text('Buka Stasiun'));
    await tester.pump();

    await tester.tap(find.text('Kumpulkan'));
    await tester.pump();

    expect(journey.activeStation.code, 'POS-2');
    expect(journey.activeStationUnlocked, isFalse);
    expect(journey.isStationSubmitted('POS-1'), isTrue);
  });

  testWidgets('timer locks answers and submits when time runs out (FR-093, '
      'FR-096)', (tester) async {
    final journey = _stationsJourney(_shortPack());
    await tester.pumpWidget(_wrap(StationScreen(journey: journey)));

    await tester.enterText(find.byKey(const ValueKey('station-pin')), '1111');
    await tester.tap(find.text('Buka Stasiun'));
    await tester.pump();

    expect(find.text('00:03'), findsOneWidget);

    // Advance the countdown to zero.
    await tester.pump(const Duration(seconds: 3));

    expect(journey.activeStation.code, 'S2');
    expect(journey.activeStationUnlocked, isFalse);
    expect(journey.isStationSubmitted('S1'), isTrue);
  });

  testWidgets('app resume recomputes wall-clock expiry (FR-093, FR-096)', (
    tester,
  ) async {
    final journey = _stationsJourney(_shortPack())..unlockStation('1111');
    expect(journey.activeStationUnlocked, isTrue);

    await tester.pumpWidget(_wrap(StationScreen(journey: journey)));
    await tester.pump();
    expect(find.textContaining('Sisa waktu'), findsOneWidget);

    // Wall clock is already past expiry while the local UI counter still has
    // leftover seconds (backgrounding suspended Timer ticks).
    journey.debugExpireStationWallClock();
    expect(journey.stationRemainingSeconds, 0);

    // Invoke the screen observer directly — binding lifecycle transitions are
    // asserted by AppLifecycleListener and are awkward to fake in tests.
    final element = tester.element(find.byType(StationScreen));
    final state = (element as StatefulElement).state as WidgetsBindingObserver;
    state.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();

    expect(journey.isStationSubmitted('S1'), isTrue);
    expect(journey.activeStationUnlocked, isFalse);
  });

  testWidgets('rotation hint mentions the next POS station (E5-05)', (
    tester,
  ) async {
    final journey = _stationsJourney(buildLocalContentPack());
    await tester.pumpWidget(_wrap(StationScreen(journey: journey)));

    expect(find.textContaining('rotasi'), findsWidgets);
  });
}
