import 'package:cell_forensic/ar/ar_asset_registry.dart';
import 'package:cell_forensic/ar/ar_scene_engine.dart';
import 'package:cell_forensic/core/database/local_store.dart';
import 'package:cell_forensic/domain/entities.dart';
import 'package:cell_forensic/domain/intent_matcher.dart';
import 'package:cell_forensic/domain/mission_progress.dart';
import 'package:cell_forensic/domain/sequence_engine.dart';
import 'package:cell_forensic/features/content/local_content_pack.dart';
import 'package:cell_forensic/features/journey/student_journey.dart';
import 'package:cell_forensic/features/session/session_snapshot_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// PDF `CELL FORENSIC (3).pdf` — 14 mandatory flow/progress contracts.
void main() {
  ContentPack pack() => buildLocalContentPack();

  Group demoGroup({String sessionId = 'local-cell01'}) => Group(
    id: 'g1',
    sessionId: sessionId,
    name: 'Kelompok Mawar',
    members: const [
      GroupMember(id: 'm1', displayName: 'Ani', isLeader: true),
    ],
  );

  StudentJourney fresh() => StudentJourney(content: pack());

  StudentJourney atGroupSetup() => fresh()
    ..completeDeviceCheck(arSupported: true)
    ..acceptJoinedSession(
      joinCode: 'CELL01',
      sessionId: 'local-cell01',
      sessionTitle: 'Demo',
    );

  /// Scene 1 after group submit — investigating, no placement, no running mission.
  StudentJourney atScene1() =>
      atGroupSetup()
        ..setGroup(demoGroup())
        ..confirmGroupReady();

  group('PDF flow contract (14 mandatory cases)', () {
    test('1. App launch does not start mission', () {
      final journey = fresh();

      expect(journey.stage, JourneyStage.deviceCheck);
      expect(journey.missionProgress, isEmpty);
      expect(journey.hasRunningMission, isFalse);
      expect(journey.labPlaced, isFalse);
      expect(journey.sequenceStepIndex, isNull);
      expect(journey.toSessionSnapshot(), isNull);
    });

    test('2. Join session does not start mission', () {
      final journey = fresh()..completeDeviceCheck(arSupported: true);
      journey.acceptJoinedSession(
        joinCode: 'CELL01',
        sessionId: 'local-cell01',
        sessionTitle: 'Demo',
      );

      expect(journey.stage, JourneyStage.groupSetup);
      expect(journey.missionProgress, isEmpty);
      expect(journey.hasRunningMission, isFalse);
      expect(journey.labPlaced, isFalse);
      expect(journey.toSessionSnapshot(), isNull);
    });

    test('3. Submit group name does not start Misi 1', () {
      final journey = atGroupSetup()..setGroup(demoGroup());

      expect(journey.stage, JourneyStage.groupSetup);
      expect(journey.missionProgress, isEmpty);
      expect(journey.hasRunningMission, isFalse);

      final beforeConfirm = journey.toSessionSnapshot()!;
      expect(beforeConfirm.missionProgress, isEmpty);
      expect(beforeConfirm.toJson().containsKey('mission_progress'), isFalse);

      journey.confirmGroupReady();

      expect(journey.stage, JourneyStage.investigating);
      expect(journey.missionProgress, isEmpty);
      expect(journey.hasRunningMission, isFalse);
      expect(journey.missionStatus(1), MissionStatus.locked);
      expect(journey.sequenceStepIndex, isNull);

      final after = journey.toSessionSnapshot()!;
      expect(after.missionProgress, isEmpty);
      expect(
        after.missionProgress['mission1']?.status,
        isNot(MissionProgressSnapshot.statusRunning),
      );
    });

    test('4. Submit group opens Scene 1 AR initialization', () async {
      final journey = atScene1();

      expect(journey.stage, JourneyStage.investigating);
      expect(journey.sequenceStepIndex, isNull);
      expect(journey.sequenceCompleted, isFalse);
      expect(journey.hasRunningMission, isFalse);
      expect(journey.labPlaced, isFalse);

      final engine = FakeArSceneEngine();
      await engine.initLabScene(
        labTableModelPath: ArAssetRegistry.mejaLab,
        sampleAModelPath: ArAssetRegistry.sampleA,
        sampleBModelPath: ArAssetRegistry.sampleB,
      );

      expect(engine.visualState.labTableModelPath, ArAssetRegistry.mejaLab);
      expect(engine.visualState.visibleNodes[ArNodeIds.labTable], isTrue);
      expect(engine.visualState.visibleNodes[ArNodeIds.sampleA], isTrue);
      expect(engine.visualState.visibleNodes[ArNodeIds.sampleB], isTrue);
      expect(engine.placement, isNull);

      await engine.dispose();
    });

    test('5. Before placement, no mission running', () {
      final journey = atScene1();

      expect(journey.stage, JourneyStage.investigating);
      expect(journey.labPlaced, isFalse);
      expect(journey.hasRunningMission, isFalse);
      expect(journey.missionProgress, isEmpty);
      expect(journey.runningMissionNumber, isNull);
      expect(journey.sequenceStepIndex, isNull);
      expect(journey.missionStatus(1), MissionStatus.locked);
      expect(journey.missionStatus(2), MissionStatus.locked);
      expect(journey.missionStatus(3), MissionStatus.locked);
    });

    test('6. After placement, both samples + all missions available', () async {
      final journey = atScene1();
      final engine = FakeArSceneEngine();
      await engine.place(const ArPlacement(x: 0, y: 0, z: -1));
      await engine.initLabScene(
        labTableModelPath: ArAssetRegistry.mejaLab,
        sampleAModelPath: ArAssetRegistry.sampleA,
        sampleBModelPath: ArAssetRegistry.sampleB,
      );

      expect(engine.placement, isNotNull);
      expect(engine.visualState.visibleNodes[ArNodeIds.sampleA], isTrue);
      expect(engine.visualState.visibleNodes[ArNodeIds.sampleB], isTrue);

      journey.markLabPlaced();

      expect(journey.labPlaced, isTrue);
      expect(journey.missionProgress, hasLength(3));
      expect(journey.missionStatus(1), MissionStatus.running);
      expect(journey.missionStatus(2), MissionStatus.available);
      expect(journey.missionStatus(3), MissionStatus.available);
      expect(journey.hasRunningMission, isTrue);
      expect(journey.activeMission.code, 'MISI-1');

      final snap = journey.toSessionSnapshot()!;
      expect(snap.missionProgress, hasLength(3));
      expect(snap.missionProgress['mission1']!.status, 'running');
      expect(snap.missionProgress['mission2']!.status, 'available');
      expect(snap.missionProgress['mission3']!.status, 'available');

      await engine.dispose();
    });

    test('7. Intent Sample A + rusak → Misi 1', () {
      final journey = atScene1()..markLabPlaced();
      const matcher = IntentMatcher([]);

      final match = matcher.match(
        'AI, tolong periksa organel apa saja yang rusak di Sampel A?',
      );
      expect(match.missionNumber, 1);
      // GAP-2: offline question → AR via sequenceCode (no Supabase required).
      expect(match.sequenceCode, 'SEQ-MISI-1');
      expect(
        const SequenceEngine().startForSequenceCode(match.sequenceCode!),
        isNotNull,
      );

      journey.startMissionFromIntent(match.missionNumber!);
      expect(journey.runningMissionNumber, 1);
      expect(journey.missionStatus(1), MissionStatus.running);
      expect(journey.activeMission.code, 'MISI-1');
      expect(journey.missionProgress['mission1']!.startedAt, isNotNull);
      expect(journey.missionStatus(2), MissionStatus.available);
    });

    test('8. Intent Sample B + bocor → Misi 2', () {
      final journey = atScene1()..markLabPlaced();
      const matcher = IntentMatcher([]);

      final match = matcher.match(
        'Mengapa cairan di dalam Sampel B bisa bocor keluar?',
      );
      expect(match.missionNumber, 2);
      expect(match.sequenceCode, 'SEQ-MISI-2');
      expect(
        const SequenceEngine().startForSequenceCode(match.sequenceCode!),
        isNotNull,
      );

      journey.startMissionFromIntent(match.missionNumber!);
      expect(journey.runningMissionNumber, 2);
      expect(journey.missionStatus(2), MissionStatus.running);
      expect(journey.activeMission.code, 'MISI-2');
    });

    test('9. Intent perbedaan A/B → Misi 3', () {
      final journey = atScene1()..markLabPlaced();
      const matcher = IntentMatcher([]);

      final match = matcher.match('apa perbedaan sampel a dan sampel b');
      expect(match.missionNumber, 3);
      expect(match.sequenceCode, 'SEQ-MISI-3');
      expect(
        IntentMatcher.classifyMission(
          'Kenapa Sampel A tidak hancur sekempes Sampel B '
          'padahal sama-sama diserang?',
        ),
        3,
      );
      expect(
        const SequenceEngine().startForSequenceCode(match.sequenceCode!),
        isNotNull,
      );

      journey.startMissionFromIntent(match.missionNumber!);
      expect(journey.runningMissionNumber, 3);
      expect(journey.missionStatus(3), MissionStatus.running);
      expect(journey.activeMission.code, 'MISI-3');
    });

    test('10. Unknown intent does not change progress', () {
      final journey = atScene1()..markLabPlaced();
      final before = Map.of(journey.missionProgress);

      const matcher = IntentMatcher([]);
      final unknown = matcher.match('apa warna langit hari ini');
      expect(unknown.missionNumber, isNull);
      expect(IntentMatcher.classifyMission('apa warna langit'), isNull);

      journey.ignoreIntentForProgress();
      if (unknown.missionNumber != null) {
        journey.startMissionFromIntent(unknown.missionNumber!);
      }

      expect(journey.hasRunningMission, isTrue);
      expect(journey.runningMissionNumber, 1);
      expect(journey.missionProgress.keys, before.keys);
      for (final key in before.keys) {
        expect(journey.missionProgress[key]!.status, before[key]!.status);
      }

      const engine = SequenceEngine();
      expect(engine.startSequence(0), isNull);
      expect(engine.startSequence(99), isNull);
    });

    test('11. Re-running mission does not duplicate completion', () {
      final journey = atScene1()..markLabPlaced();
      journey.startMissionFromIntent(1);
      journey.completeMissionObservation(1);

      final firstCompletedAt = journey.missionProgress['mission1']!.completedAt;
      expect(firstCompletedAt, isNotNull);
      expect(journey.missionStatus(1), MissionStatus.completed);

      // Re-run observation + complete again → completedAt write-once.
      journey.startMissionFromIntent(1);
      expect(journey.missionStatus(1), MissionStatus.completed);
      journey.completeMissionObservation(1);
      expect(journey.missionProgress['mission1']!.completedAt, firstCompletedAt);

      // SequenceEngine: re-complete returns same state (no second signal).
      const seq = SequenceEngine();
      var state = seq.startSequence(1)!;
      while (state.status == SequenceStatus.running) {
        state = seq.completeCurrentStep(state);
      }
      expect(state.completionEventCount, 1);
      final again = seq.completeCurrentStep(state);
      expect(identical(again, state), isTrue);
      expect(again.completionEventCount, 1);

      final store = SessionSnapshotStore(LocalDatabase(InMemoryStorageBackend()));
      store.save(journey.toSessionSnapshot()!);
      expect(
        store.loadActive()!.missionProgress['mission1']!.completedAtMs,
        firstCompletedAt!.millisecondsSinceEpoch,
      );
    });

    test(
      '12. Relaunch after placement restores journey; AR placement may be re-requested',
      () {
        final store = SessionSnapshotStore(
          LocalDatabase(InMemoryStorageBackend()),
        );
        final journey = atScene1()
          ..markLabPlaced()
          ..startMissionFromIntent(1)
          ..saveLogbook({
            'Bentuk/gejala klinis yang terlihat pada Sampel A': 'layu',
          })
          ..saveSequenceProgress(stepIndex: 0, completed: false);

        store.save(journey.toSessionSnapshot()!);

        final restored = StudentJourney(content: pack());
        expect(restored.restoreFromSnapshot(store.loadActive()!), isTrue);
        expect(restored.stage, JourneyStage.investigating);
        expect(restored.groupName, 'Kelompok Mawar');
        expect(restored.labPlaced, isTrue);
        expect(restored.missionProgress, hasLength(3));
        expect(restored.missionStatus(1), MissionStatus.running);
        expect(restored.logbookByMission['MISI-1']!.values, contains('layu'));

        // AR anchor/placement is not durable — new engine needs re-place.
        final engine = FakeArSceneEngine();
        expect(engine.placement, isNull);
        engine.dispose();
      },
    );

    test('13. Logbook tied to correct mission', () {
      final journey = atScene1()..markLabPlaced();

      journey.startMissionFromIntent(1);
      expect(journey.activeMission.code, 'MISI-1');
      journey.saveLogbook({
        'Bentuk/gejala klinis yang terlihat pada Sampel A': 'kloroplas rusak',
      });
      expect(journey.logbookByMission.keys, contains('MISI-1'));
      expect(journey.logbookByMission.containsKey('MISI-2'), isFalse);

      journey.completeMissionObservation(1);
      journey.startMissionFromIntent(2);
      expect(journey.activeMission.code, 'MISI-2');
      journey.saveLogbook({'Kondisi membran Sampel B': 'robek'});

      expect(
        journey.logbookByMission['MISI-1']!.values,
        contains('kloroplas rusak'),
      );
      expect(journey.logbookByMission['MISI-2']!.values, contains('robek'));
      expect(
        journey.logbookByMission['MISI-1']!.values,
        isNot(contains('robek')),
      );

      final snap = journey.toSessionSnapshot()!;
      expect(snap.logbookByMission['MISI-1'], isNotNull);
      expect(snap.logbookByMission['MISI-2'], isNotNull);
    });

    test('14. No orphan progress before group available', () {
      final journey = fresh();
      expect(journey.missionProgress, isEmpty);
      expect(journey.toSessionSnapshot(), isNull);

      journey.completeDeviceCheck(arSupported: false);
      expect(journey.toSessionSnapshot(), isNull);

      journey.acceptJoinedSession(
        joinCode: 'CELL01',
        sessionId: 'local-cell01',
      );
      expect(journey.group, isNull);
      expect(journey.toSessionSnapshot(), isNull);
      expect(journey.missionProgress, isEmpty);

      // markLabPlaced is a no-op without a group.
      journey.markLabPlaced();
      expect(journey.labPlaced, isFalse);
      expect(journey.missionProgress, isEmpty);

      journey.setGroup(demoGroup());
      final snap = journey.toSessionSnapshot()!;
      expect(snap.missionProgress, isEmpty);
      expect(snap.toJson().containsKey('mission_progress'), isFalse);
    });
  });
}
