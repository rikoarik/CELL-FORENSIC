import 'package:cell_forensic/core/database/local_store.dart';
import 'package:cell_forensic/features/content/local_content_pack.dart';
import 'package:cell_forensic/features/journey/journey_host.dart';
import 'package:cell_forensic/features/journey/student_journey.dart';
import 'package:cell_forensic/features/session/session_snapshot_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('host renders the screen for the current journey stage', (
    tester,
  ) async {
    final journey = StudentJourney(content: buildLocalContentPack());
    await tester.pumpWidget(MaterialApp(home: JourneyHost(journey: journey)));

    // Device check is the first stage.
    expect(find.textContaining('AR'), findsWidgets);

    journey.completeDeviceCheck(arSupported: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // Join stage shows the seeded local join code field.
    expect(find.byKey(const Key('joinCodeField')), findsOneWidget);
    expect(find.textContaining('CELL01'), findsWidgets);
  });

  testWidgets('submit investigation shows success and reset clears snapshot', (
    tester,
  ) async {
    final db = LocalDatabase(InMemoryStorageBackend());
    final store = SessionSnapshotStore(db);
    final journey = StudentJourney(content: buildLocalContentPack())
      ..completeDeviceCheck(arSupported: false)
      ..joinWithGroup(groupName: 'Tim A', leaderName: 'Budi')
      ..debugCompleteAllMissionsToConclusion();

    await tester.pumpWidget(
      MaterialApp(
        home: JourneyHost(
          journey: journey,
          snapshotStore: store,
          restoreSnapshot: false,
        ),
      ),
    );

    journey.submitInvestigation(
      sampleAIdentity: 'Sel tumbuhan',
      sampleAReasoning: 'Dinding sel',
      sampleBIdentity: 'Sel hewan',
      sampleBReasoning: 'Membran robek',
      hypothesis: 'Bukti mendukung.',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Investigasi berhasil dikirim!'), findsOneWidget);
    expect(store.loadActive(), isNotNull);

    await tester.tap(find.byKey(const Key('results-start-over')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(journey.stage, JourneyStage.deviceCheck);
    expect(store.loadActive(), isNull);
  });

  testWidgets(
    'expired POS timer during restore is persisted to snapshot store',
    (tester) async {
      final db = LocalDatabase(InMemoryStorageBackend());
      final store = SessionSnapshotStore(db);
      final pack = buildLocalContentPack();

      final seedJourney = StudentJourney(content: pack)
        ..completeDeviceCheck(arSupported: false)
        ..joinWithGroup(groupName: 'Tim A', leaderName: 'Budi')
        ..debugCompleteAllMissionsToConclusion()
        ..submitInvestigation(
          sampleAIdentity: 'Sel tumbuhan',
          sampleAReasoning: 'Dinding sel',
          sampleBIdentity: 'Sel hewan',
          sampleBReasoning: 'Membran robek',
          hypothesis: 'Bukti mendukung.',
        )
        ..unlockStation('1111')
        ..answerQuestion('POS1-Q1', 'Sampel A');

      final live = seedJourney.toSessionSnapshot()!;
      store.save(
        SessionSnapshot(
          stageName: live.stageName,
          arSupported: live.arSupported,
          joinCode: live.joinCode,
          sessionId: live.sessionId,
          sessionTitle: live.sessionTitle,
          group: live.group,
          remoteSessionId: live.remoteSessionId,
          remoteGroupId: live.remoteGroupId,
          missionIndex: live.missionIndex,
          stationIndex: live.stationIndex,
          activeStationUnlocked: true,
          answers: live.answers,
          submittedStationCodes: live.submittedStationCodes,
          stationExpiresAtMs: DateTime.now()
              .subtract(const Duration(seconds: 5))
              .millisecondsSinceEpoch,
          conclusionDraft: live.conclusionDraft,
        ),
      );

      final journey = StudentJourney(content: pack);
      await tester.pumpWidget(
        MaterialApp(
          home: JourneyHost(
            journey: journey,
            snapshotStore: store,
            restoreSnapshot: true,
          ),
        ),
      );
      await tester.pump();

      expect(journey.activeStation.code, 'POS-2');
      expect(journey.isStationSubmitted('POS-1'), isTrue);

      final persisted = store.loadActive();
      expect(persisted, isNotNull);
      expect(persisted!.stationIndex, 1);
      expect(persisted.submittedStationCodes, contains('POS-1'));
      expect(persisted.activeStationUnlocked, isFalse);
    },
  );
}
