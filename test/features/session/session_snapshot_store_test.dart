import 'package:cell_forensic/core/database/local_store.dart';
import 'package:cell_forensic/domain/entities.dart';
import 'package:cell_forensic/features/content/local_content_pack.dart';
import 'package:cell_forensic/features/journey/student_journey.dart';
import 'package:cell_forensic/features/session/session_snapshot_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('snapshot save/load round-trips through LocalDatabase', () {
    final store = SessionSnapshotStore(LocalDatabase(InMemoryStorageBackend()));
    final group = Group(
      id: 'g1',
      sessionId: 's1',
      name: 'Kelompok Mawar',
      members: const [
        GroupMember(id: 'm1', displayName: 'Ani', isLeader: true),
        GroupMember(id: 'm2', displayName: 'Budi', isLeader: false),
      ],
    );

    store.save(
      SessionSnapshot(
        stageName: JourneyStage.groupSetup.name,
        arSupported: true,
        joinCode: 'CELL01',
        sessionId: 's1',
        sessionTitle: 'Demo',
        group: group,
      ),
    );

    final loaded = store.loadActive();
    expect(loaded, isNotNull);
    expect(loaded!.joinCode, 'CELL01');
    expect(loaded.group.name, 'Kelompok Mawar');
    expect(loaded.group.members, hasLength(2));
    expect(loaded.stageName, 'groupSetup');
  });

  test('StudentJourney restores group setup from snapshot', () {
    final journey = StudentJourney(content: buildLocalContentPack());
    final snap = SessionSnapshot(
      stageName: JourneyStage.onboarding.name,
      arSupported: false,
      joinCode: 'CELL01',
      sessionId: 'local-cell01',
      sessionTitle: 'Demo',
      group: const Group(
        id: 'g1',
        sessionId: 'local-cell01',
        name: 'Tim A',
        members: [
          GroupMember(id: 'm1', displayName: 'Budi', isLeader: true),
        ],
      ),
    );

    expect(journey.restoreFromSnapshot(snap), isTrue);
    // Onboarding snapshots still restore; live flow skips to Scene 1 after group.
    expect(journey.stage, JourneyStage.onboarding);
    expect(journey.groupName, 'Tim A');
    expect(journey.leaderName, 'Budi');
    expect(journey.arSupported, isFalse);
    expect(journey.missionProgress, isEmpty);
  });

  test('mission progress map round-trips through the snapshot store', () {
    final store = SessionSnapshotStore(LocalDatabase(InMemoryStorageBackend()));
    store.save(
      SessionSnapshot(
        stageName: JourneyStage.investigating.name,
        arSupported: true,
        joinCode: 'CELL01',
        sessionId: 's1',
        sessionTitle: 'Demo',
        group: const Group(
          id: 'g1',
          sessionId: 's1',
          name: 'Tim A',
          members: [GroupMember(id: 'm1', displayName: 'Ani', isLeader: true)],
        ),
        missionProgress: const {
          'mission1': MissionProgressSnapshot(
            status: MissionProgressSnapshot.statusCompleted,
            startedAtMs: 1000,
            completedAtMs: 2000,
          ),
          'mission2': MissionProgressSnapshot(
            status: MissionProgressSnapshot.statusRunning,
            startedAtMs: 3000,
          ),
          'mission3': MissionProgressSnapshot(
            status: MissionProgressSnapshot.statusLocked,
          ),
        },
      ),
    );

    final loaded = store.loadActive()!;
    expect(loaded.missionProgress, hasLength(3));
    expect(loaded.missionProgress['mission1']!.isCompleted, isTrue);
    expect(loaded.missionProgress['mission1']!.completedAtMs, 2000);
    expect(
      loaded.missionProgress['mission2']!.status,
      MissionProgressSnapshot.statusRunning,
    );
    expect(loaded.missionProgress['mission2']!.completedAtMs, isNull);
    expect(
      loaded.missionProgress['mission3']!.status,
      MissionProgressSnapshot.statusLocked,
    );
  });

  test('empty mission progress writes no orphan key (fresh session)', () {
    const snapshot = SessionSnapshot(
      stageName: 'groupSetup',
      arSupported: false,
      joinCode: 'CELL01',
      sessionId: 's1',
      sessionTitle: 'Demo',
      group: Group(
        id: 'g1',
        sessionId: 's1',
        name: 'Tim A',
        members: [GroupMember(id: 'm1', displayName: 'Ani', isLeader: true)],
      ),
    );

    expect(snapshot.missionProgress, isEmpty);
    expect(snapshot.toJson().containsKey('mission_progress'), isFalse);
  });

  test('completed mission stays completed across re-run (write-once)', () {
    final store = SessionSnapshotStore(LocalDatabase(InMemoryStorageBackend()));
    const completed = MissionProgressSnapshot(
      status: MissionProgressSnapshot.statusCompleted,
      startedAtMs: 1000,
      completedAtMs: 2000,
    );

    SessionSnapshot snapshotWith(MissionProgressSnapshot m1) => SessionSnapshot(
      stageName: JourneyStage.investigating.name,
      arSupported: false,
      joinCode: 'CELL01',
      sessionId: 's1',
      sessionTitle: 'Demo',
      group: const Group(
        id: 'g1',
        sessionId: 's1',
        name: 'Tim A',
        members: [GroupMember(id: 'm1', displayName: 'Ani', isLeader: true)],
      ),
      missionProgress: {'mission1': m1},
    );

    store.save(snapshotWith(completed));
    // A re-run of the same observation should not create a second completion:
    // completedAtMs is preserved (idempotent) rather than overwritten.
    final reloaded = store.loadActive()!;
    final existing = reloaded.missionProgress['mission1']!;
    final afterRerun = existing.isCompleted
        ? existing
        : existing.copyWith(
            status: MissionProgressSnapshot.statusCompleted,
            completedAtMs: 9999,
          );
    store.save(snapshotWith(afterRerun));

    final finalState = store.loadActive()!.missionProgress['mission1']!;
    expect(finalState.completedAtMs, 2000);
  });

  test('snapshot round-trips investigation progress + logbook', () {
    final store = SessionSnapshotStore(LocalDatabase(InMemoryStorageBackend()));
    final journey = StudentJourney(content: buildLocalContentPack())
      ..completeDeviceCheck(arSupported: false)
      ..joinWithGroup(groupName: 'Tim A', leaderName: 'Budi')
      ..finishOnboarding()
      ..saveLogbook({'Bentuk/gejala klinis yang terlihat pada Sampel A': 'ok'})
      ..saveSequenceProgress(stepIndex: 2, completed: false);

    final snap = journey.toSessionSnapshot();
    expect(snap, isNotNull);
    store.save(snap!);

    final restored = StudentJourney(content: buildLocalContentPack());
    expect(restored.restoreFromSnapshot(store.loadActive()!), isTrue);
    expect(restored.stage, JourneyStage.investigating);
    expect(restored.missionIndex, 0);
    expect(restored.sequenceStepIndex, 2);
    expect(
      restored.logbookByMission['MISI-1']!.values,
      contains('ok'),
    );
  });

  test('snapshot round-trips POS station answers and unlock state (E5-06)', () {
    final store = SessionSnapshotStore(LocalDatabase(InMemoryStorageBackend()));
    final journey = StudentJourney(content: buildLocalContentPack())
      ..completeDeviceCheck(arSupported: false)
      ..joinWithGroup(groupName: 'Tim A', leaderName: 'Budi')
      ..markLabPlaced()
      ..startMissionFromIntent(1)
      ..completeMissionObservation(1)
      ..startMissionFromIntent(2)
      ..completeMissionObservation(2)
      ..startMissionFromIntent(3)
      ..completeMissionObservation(3);
    journey.completeActiveMission(); // → conclusion when all completed
    journey
      ..submitInvestigation(
        sampleAIdentity: 'Sel tumbuhan',
        sampleAReasoning: 'Dinding sel',
        sampleBIdentity: 'Sel hewan',
        sampleBReasoning: 'Membran robek',
        hypothesis: 'Bukti mendukung.',
      )
      ..unlockStation('1111')
      ..answerQuestion('POS1-Q1', 'Sampel A')
      ..answerQuestion('POS1-Q2', 'Melindungi sel');

    store.save(journey.toSessionSnapshot()!);

    final restored = StudentJourney(content: buildLocalContentPack());
    expect(restored.restoreFromSnapshot(store.loadActive()!), isTrue);
    expect(restored.stage, JourneyStage.stations);
    expect(restored.stationIndex, 0);
    expect(restored.activeStationUnlocked, isTrue);
    expect(restored.answerFor('POS1-Q1'), 'Sampel A');
    expect(restored.stationExpiresAt, isNotNull);
  });
}
