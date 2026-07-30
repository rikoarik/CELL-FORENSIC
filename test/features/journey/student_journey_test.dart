import 'package:cell_forensic/domain/entities.dart';
import 'package:cell_forensic/domain/mission_progress.dart';
import 'package:cell_forensic/features/content/local_content_pack.dart';
import 'package:cell_forensic/features/journey/student_journey.dart';
import 'package:cell_forensic/features/session/session_snapshot_store.dart';
import 'package:flutter_test/flutter_test.dart';

ContentPack _pack() => buildLocalContentPack();

void main() {
  test('journey starts at device check', () {
    final journey = StudentJourney(content: _pack());
    expect(journey.stage, JourneyStage.deviceCheck);
    expect(journey.canGoBack, isFalse);
  });

  test('goBack steps one stage without clearing join data', () {
    final journey = StudentJourney(content: _pack())
      ..completeDeviceCheck(arSupported: false)
      ..joinWithGroup(groupName: 'Alpha', leaderName: 'Budi');
    expect(journey.stage, JourneyStage.investigating);
    expect(journey.canGoBack, isTrue);

    journey.goBack();
    expect(journey.stage, JourneyStage.groupSetup);
    expect(journey.groupName, 'Alpha');

    journey.goBack();
    expect(journey.stage, JourneyStage.joinSession);

    journey.goBack();
    expect(journey.stage, JourneyStage.deviceCheck);
    expect(journey.canGoBack, isFalse);
  });

  test('clearGroup allows creating a new group while keeping session', () {
    final journey = StudentJourney(content: _pack())
      ..completeDeviceCheck(arSupported: false)
      ..joinWithGroup(groupName: 'Alpha', leaderName: 'Budi');
    journey.goBack();
    expect(journey.stage, JourneyStage.groupSetup);
    expect(journey.groupName, 'Alpha');
    expect(journey.joinCode, isNotNull);

    journey.clearGroup();
    expect(journey.group, isNull);
    expect(journey.groupName, isNull);
    expect(journey.leaderName, isNull);
    expect(journey.joinCode, isNotNull);
    expect(journey.stage, JourneyStage.groupSetup);
  });

  test('enableLiveAr upgrades Mode 3D without leaving investigating stage', () {
    final journey = StudentJourney(content: _pack())
      ..completeDeviceCheck(arSupported: false)
      ..joinWithGroup(groupName: 'Alpha', leaderName: 'Budi');
    expect(journey.arSupported, isFalse);
    expect(journey.stage, JourneyStage.investigating);

    journey.markLabPlaced();
    expect(journey.labPlaced, isTrue);

    journey.enableLiveAr();
    expect(journey.arSupported, isTrue);
    expect(journey.labPlaced, isFalse);
    expect(journey.stage, JourneyStage.investigating);
  });

  test('progresses device check -> join -> group -> Scene 1 AR (no Misi 1)', () {
    final journey = StudentJourney(content: _pack());
    journey.completeDeviceCheck(arSupported: false);
    expect(journey.stage, JourneyStage.joinSession);
    expect(journey.arSupported, isFalse);

    journey.joinWithGroup(groupName: 'Kelompok Mawar', leaderName: 'Ani');
    expect(journey.stage, JourneyStage.investigating);
    expect(journey.groupName, 'Kelompok Mawar');
    expect(journey.missionProgress, isEmpty);
    expect(journey.hasRunningMission, isFalse);
  });

  test('acceptJoinedSession then setGroup then confirmGroupReady → Scene 1', () {
    final journey = StudentJourney(content: _pack())
      ..completeDeviceCheck(arSupported: true);

    journey.acceptJoinedSession(
      joinCode: 'CELL01',
      sessionId: 'local-cell01',
      sessionTitle: 'Demo',
    );
    expect(journey.stage, JourneyStage.groupSetup);
    expect(journey.joinCode, 'CELL01');
    expect(journey.missionProgress, isEmpty);

    journey.setGroup(
      const Group(
        id: 'g1',
        sessionId: 'local-cell01',
        name: 'Kelompok Mawar',
        members: [
          GroupMember(id: 'm1', displayName: 'Ani', isLeader: true),
        ],
      ),
    );
    expect(journey.groupName, 'Kelompok Mawar');
    expect(journey.leaderName, 'Ani');
    // Group create alone must not seed mission1:running.
    expect(journey.missionProgress, isEmpty);

    journey.confirmGroupReady();
    expect(journey.stage, JourneyStage.investigating);
    expect(journey.missionProgress, isEmpty);
    expect(journey.hasRunningMission, isFalse);
  });

  test('intent-driven missions + placement unlock; re-run keeps completedAt', () {
    final journey = StudentJourney(content: _pack())
      ..completeDeviceCheck(arSupported: true)
      ..joinWithGroup(groupName: 'Tim A', leaderName: 'Budi');

    expect(journey.missionProgress, isEmpty);
    journey.markLabPlaced();
    expect(journey.missionStatus(1).name, 'running');
    expect(journey.missionStatus(2).name, 'available');
    expect(journey.missionStatus(3).name, 'available');
    expect(journey.hasRunningMission, isTrue);
    expect(journey.activeMission.code, 'MISI-1');

    journey.startMissionFromIntent(1);
    expect(journey.missionStatus(1).name, 'running');
    expect(journey.activeMission.code, 'MISI-1');
    final started = journey.missionProgress['mission1']!.startedAt;
    expect(started, isNotNull);

    journey.completeMissionObservation(1);
    final completedAt = journey.missionProgress['mission1']!.completedAt;
    expect(completedAt, isNotNull);

    // Re-run must not duplicate completedAt.
    journey.startMissionFromIntent(1);
    journey.completeMissionObservation(1);
    expect(journey.missionProgress['mission1']!.completedAt, completedAt);

    journey.startMissionFromIntent(2);
    journey.completeMissionObservation(2);
    journey.startMissionFromIntent(3);
    journey.completeMissionObservation(3);
    expect(journey.allMissionsCompleted, isTrue);
    journey.completeActiveMission();
    expect(journey.stage, JourneyStage.conclusion);
  });

  test('completeActiveMission advances M1 → M2 → M3 → conclusion', () {
    final journey = StudentJourney(content: _pack())
      ..completeDeviceCheck(arSupported: false)
      ..joinWithGroup(groupName: 'Tim A', leaderName: 'Budi')
      ..markLabPlaced()
      ..startMissionFromIntent(1);

    journey.completeActiveMission();
    expect(journey.missionStatus(1), MissionStatus.completed);
    expect(journey.missionStatus(2), MissionStatus.running);
    expect(journey.activeMission.code, 'MISI-2');
    expect(journey.stage, JourneyStage.investigating);

    journey.completeActiveMission();
    expect(journey.missionStatus(2), MissionStatus.completed);
    expect(journey.missionStatus(3), MissionStatus.running);
    expect(journey.activeMission.code, 'MISI-3');

    journey.completeActiveMission();
    expect(journey.allMissionsCompleted, isTrue);
    expect(journey.stage, JourneyStage.conclusion);
  });

  test('snapshot round-trips missionProgress map', () {
    final journey = StudentJourney(content: _pack())
      ..completeDeviceCheck(arSupported: true)
      ..joinWithGroup(groupName: 'Tim A', leaderName: 'Budi')
      ..markLabPlaced()
      ..startMissionFromIntent(2)
      ..completeMissionObservation(2);

    final snap = journey.toSessionSnapshot()!;
    expect(snap.missionProgress['mission2']!.isCompleted, isTrue);
    expect(snap.missionProgress['mission1']!.status, 'available');

    final restored = StudentJourney(content: _pack());
    expect(restored.restoreFromSnapshot(snap), isTrue);
    expect(restored.missionStatus(2).name, 'completed');
    expect(restored.missionStatus(1).name, 'available');
    expect(restored.labPlaced, isTrue);
  });

  test('conclusion requires all fields before investigation submit', () {
    final journey = _atConclusion();

    journey.submitInvestigation(
      sampleAIdentity: '',
      sampleAReasoning: 'x',
      sampleBIdentity: 'y',
      sampleBReasoning: 'z',
      hypothesis: 'h',
    );
    expect(journey.stage, JourneyStage.conclusion);
    expect(journey.lastError, isNotNull);

    journey.submitInvestigation(
      sampleAIdentity: 'Sel tumbuhan',
      sampleAReasoning: 'Punya dinding sel',
      sampleBIdentity: 'Sel hewan',
      sampleBReasoning: 'Membran robek',
      hypothesis: 'Sampel A lebih tahan tekanan.',
    );
    expect(journey.stage, JourneyStage.stations);
    expect(journey.lastError, isNull);
    expect(journey.activeStation.code, 'POS-1');
  });

  test('stations unlock by PIN and submit in order to results', () {
    final journey = _atConclusion()
      ..submitInvestigation(
        sampleAIdentity: 'Sel tumbuhan',
        sampleAReasoning: 'Dinding sel',
        sampleBIdentity: 'Sel hewan',
        sampleBReasoning: 'Membran robek',
        hypothesis: 'Bukti mendukung.',
      );

    expect(journey.unlockStation('0000'), isFalse);
    expect(journey.activeStationUnlocked, isFalse);
    expect(journey.unlockStation('1111'), isTrue);
    expect(journey.activeStationUnlocked, isTrue);

    journey.answerQuestion('POS1-Q1', 'Sampel A');
    journey.answerQuestion('POS1-Q2', 'Melindungi sel');
    journey.submitActiveStation();
    expect(journey.activeStation.code, 'POS-2');
    expect(journey.activeStationUnlocked, isFalse);

    journey.unlockStation('2222');
    journey.answerQuestion('POS2-Q1', 'Membran');
    journey.answerQuestion('POS2-Q2', 'Isi sel bocor');
    journey.submitActiveStation();

    journey.unlockStation('3333');
    journey.answerQuestion('POS3-Q1', 'Tumbuhan');
    journey.answerQuestion('POS3-Q2', 'Hipotesis akhir');
    journey.submitActiveStation();

    expect(journey.stage, JourneyStage.results);
  });

  test('results expose an objective auto-score total', () {
    final journey = _completeStations();
    expect(journey.stage, JourneyStage.results);
    // Objective answers all correct: POS1-Q1(10)+POS2-Q1(10)+POS3-Q1(10)=30.
    expect(journey.objectiveScore, 30);
    // Essays await teacher review, so they are not auto-final.
    expect(journey.pendingTeacherReview, isTrue);
  });

  test('toSessionSnapshot keeps investigating progress and logbook', () {
    final journey = StudentJourney(content: _pack())
      ..completeDeviceCheck(arSupported: true)
      ..joinWithGroup(groupName: 'Tim A', leaderName: 'Budi')
      ..markLabPlaced()
      ..startMissionFromIntent(1)
      ..saveLogbook({'Bentuk/gejala klinis yang terlihat pada Sampel A': 'x'})
      ..saveSequenceProgress(stepIndex: 1, completed: false);

    final snap = journey.toSessionSnapshot();
    expect(snap, isNotNull);
    expect(snap!.stageName, JourneyStage.investigating.name);
    expect(snap.sequenceStepIndex, 1);
    expect(snap.logbookByMission['MISI-1'], isNotNull);
    expect(snap.missionProgress['mission1']!.status, 'running');

    final restored = StudentJourney(content: _pack());
    expect(restored.restoreFromSnapshot(snap), isTrue);
    expect(restored.stage, JourneyStage.investigating);
    expect(restored.sequenceStepIndex, 1);
    expect(restored.missionStatus(1).name, 'running');
  });

  test('marker unlock accepts resolved marker code (E5-01)', () {
    final journey = _atConclusion()
      ..submitInvestigation(
        sampleAIdentity: 'Sel tumbuhan',
        sampleAReasoning: 'Dinding sel',
        sampleBIdentity: 'Sel hewan',
        sampleBReasoning: 'Membran robek',
        hypothesis: 'Bukti mendukung.',
      );

    expect(journey.unlockStationByMarker('MARKER-POS-9'), isFalse);
    expect(journey.activeStationUnlocked, isFalse);
    expect(journey.simulateMarkerScan(), isTrue);
    expect(journey.activeStationUnlocked, isTrue);
    expect(journey.stationExpiresAt, isNotNull);
  });

  test('toSessionSnapshot restores POS answers, index and results (E5-06)', () {
    final journey = _atConclusion()
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

    final midSnap = journey.toSessionSnapshot();
    expect(midSnap, isNotNull);
    expect(midSnap!.stageName, JourneyStage.stations.name);
    expect(midSnap.stationIndex, 0);
    expect(midSnap.activeStationUnlocked, isTrue);
    expect(midSnap.answers['POS1-Q1'], 'Sampel A');
    expect(midSnap.stationExpiresAtMs, isNotNull);

    final midRestored = StudentJourney(content: _pack());
    expect(midRestored.restoreFromSnapshot(midSnap), isTrue);
    expect(midRestored.stage, JourneyStage.stations);
    expect(midRestored.activeStationUnlocked, isTrue);
    expect(midRestored.answerFor('POS1-Q1'), 'Sampel A');
    expect(midRestored.stationRemainingSeconds, greaterThan(0));

    journey
      ..submitActiveStation()
      ..unlockStation('2222')
      ..answerQuestion('POS2-Q1', 'Membran')
      ..submitActiveStation()
      ..unlockStation('3333')
      ..answerQuestion('POS3-Q1', 'Tumbuhan')
      ..submitActiveStation();

    final resultsSnap = journey.toSessionSnapshot();
    expect(resultsSnap!.stageName, JourneyStage.results.name);
    expect(resultsSnap.submittedStationCodes, containsAll(['POS-1', 'POS-2', 'POS-3']));

    final resultsRestored = StudentJourney(content: _pack());
    expect(resultsRestored.restoreFromSnapshot(resultsSnap), isTrue);
    expect(resultsRestored.stage, JourneyStage.results);
    expect(resultsRestored.objectiveScore, 30);
    expect(resultsRestored.isStationSubmitted('POS-2'), isTrue);
  });

  test('expired station timer on restore auto-submits (E5-05 / E5-06)', () {
    final journey = _atConclusion()
      ..submitInvestigation(
        sampleAIdentity: 'Sel tumbuhan',
        sampleAReasoning: 'Dinding sel',
        sampleBIdentity: 'Sel hewan',
        sampleBReasoning: 'Membran robek',
        hypothesis: 'Bukti mendukung.',
      )
      ..unlockStation('1111')
      ..answerQuestion('POS1-Q1', 'Sampel A');

    final snap = journey.toSessionSnapshot()!;
    final expired = SessionSnapshot(
      stageName: snap.stageName,
      arSupported: snap.arSupported,
      joinCode: snap.joinCode,
      sessionId: snap.sessionId,
      sessionTitle: snap.sessionTitle,
      group: snap.group,
      remoteSessionId: snap.remoteSessionId,
      remoteGroupId: snap.remoteGroupId,
      missionIndex: snap.missionIndex,
      stationIndex: snap.stationIndex,
      activeStationUnlocked: true,
      answers: snap.answers,
      submittedStationCodes: snap.submittedStationCodes,
      stationExpiresAtMs: DateTime.now()
          .subtract(const Duration(seconds: 5))
          .millisecondsSinceEpoch,
    );

    final restored = StudentJourney(content: _pack());
    expect(restored.restoreFromSnapshot(expired), isTrue);
    expect(restored.isStationSubmitted('POS-1'), isTrue);
    expect(restored.activeStation.code, 'POS-2');
    expect(restored.activeStationUnlocked, isFalse);
  });
}

StudentJourney _atConclusion() {
  final journey = StudentJourney(content: _pack())
    ..completeDeviceCheck(arSupported: true)
    ..joinWithGroup(groupName: 'Tim A', leaderName: 'Budi')
    ..markLabPlaced()
    ..startMissionFromIntent(1)
    ..completeMissionObservation(1)
    ..startMissionFromIntent(2)
    ..completeMissionObservation(2)
    ..startMissionFromIntent(3)
    ..completeMissionObservation(3);
  journey.completeActiveMission();
  return journey;
}

StudentJourney _completeStations() {
  final journey = _atConclusion()
    ..submitInvestigation(
      sampleAIdentity: 'Sel tumbuhan',
      sampleAReasoning: 'Dinding sel',
      sampleBIdentity: 'Sel hewan',
      sampleBReasoning: 'Membran robek',
      hypothesis: 'Bukti mendukung.',
    );
  journey
    ..unlockStation('1111')
    ..answerQuestion('POS1-Q1', 'Sampel A')
    ..answerQuestion('POS1-Q2', 'Melindungi sel')
    ..submitActiveStation()
    ..unlockStation('2222')
    ..answerQuestion('POS2-Q1', 'Membran')
    ..answerQuestion('POS2-Q2', 'Isi sel bocor')
    ..submitActiveStation()
    ..unlockStation('3333')
    ..answerQuestion('POS3-Q1', 'Tumbuhan')
    ..answerQuestion('POS3-Q2', 'Hipotesis akhir')
    ..submitActiveStation();
  return journey;
}
