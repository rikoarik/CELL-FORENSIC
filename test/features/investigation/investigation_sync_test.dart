import 'package:cell_forensic/core/database/local_store.dart';
import 'package:cell_forensic/core/sync/sync_operation.dart';
import 'package:cell_forensic/core/sync/sync_queue.dart';
import 'package:cell_forensic/features/content/local_content_pack.dart';
import 'package:cell_forensic/features/investigation/investigation_sync.dart';
import 'package:cell_forensic/features/journey/student_journey.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoopRemote implements RemoteSyncClient {
  @override
  Future<void> push(SyncOperation operation) async {}
}

void main() {
  test('enqueueLogbook writes observation_records when remoteGroupId set', () {
    final db = LocalDatabase(InMemoryStorageBackend());
    final queue = SyncQueue(database: db, remote: _NoopRemote());
    final sync = InvestigationSync(syncQueue: queue);
    final journey = StudentJourney(
      content: buildLocalContentPack(),
      investigationSync: sync,
    )
      ..completeDeviceCheck(arSupported: false)
      ..joinWithGroup(
        groupName: 'Tim A',
        leaderName: 'Budi',
        remoteGroupId: 'group-1',
      )
      ..finishOnboarding();

    journey.saveLogbook({
      journey.activeMission.logbookPrompts[0]: 'Sel mengkerut',
      journey.activeMission.logbookPrompts[1]: 'Vakuola',
    });

    final ops = queue.operations();
    expect(ops, isNotEmpty);
    expect(ops.first.entityType, 'observation_records');
    expect(ops.first.payload['group_id'], 'group-1');
    expect(ops.first.payload['structure_state'], 'Sel mengkerut');
    // Postgres uuid columns reject free-form composite ids.
    expect(
      ops.first.payload['id'],
      stableEntityUuid('obs:group-1-${journey.activeMission.code}'),
    );
  });

  test('logbook re-enqueue keeps stable UUID from payload cache', () {
    final db = LocalDatabase(InMemoryStorageBackend());
    final queue = SyncQueue(database: db, remote: _NoopRemote());
    final sync = InvestigationSync(syncQueue: queue);
    final journey = StudentJourney(
      content: buildLocalContentPack(),
      investigationSync: sync,
    )
      ..completeDeviceCheck(arSupported: false)
      ..joinWithGroup(
        groupName: 'Tim A',
        leaderName: 'Budi',
        remoteGroupId: 'group-1',
      )
      ..finishOnboarding();

    final prompt = journey.activeMission.logbookPrompts[0];
    journey.saveLogbook({prompt: 'Satu'});
    journey.saveLogbook({prompt: 'Dua'});

    final ops = queue
        .operations()
        .where((op) => op.entityType == 'observation_records')
        .toList();
    expect(ops.length, greaterThanOrEqualTo(2));
    final ids = ops.map((op) => op.payload['id']).toSet();
    expect(ids, {
      stableEntityUuid('obs:group-1-${journey.activeMission.code}'),
    });
  });

  test('enqueueConclusion drafts investigation_conclusions', () {
    final db = LocalDatabase(InMemoryStorageBackend());
    final queue = SyncQueue(database: db, remote: _NoopRemote());
    final sync = InvestigationSync(syncQueue: queue);
    final journey = StudentJourney(
      content: buildLocalContentPack(),
      investigationSync: sync,
    )
      ..completeDeviceCheck(arSupported: false)
      ..joinWithGroup(
        groupName: 'Tim A',
        leaderName: 'Budi',
        remoteGroupId: 'group-1',
      )
      ..debugCompleteAllMissionsToConclusion();

    journey.saveConclusionDraft(
      const ConclusionDraft(
        sampleAIdentity: 'Tumbuhan',
        hypothesis: 'Draft hipotesis',
      ),
    );

    final ops = queue.operations();
    expect(ops.single.entityType, 'investigation_conclusions');
    expect(ops.single.payload['status'], 'draft');
    expect(ops.single.payload['sample_a_identity'], 'Tumbuhan');
    expect(ops.single.payload['id'], 'group-1');
    expect(ops.single.payload.containsKey('version'), isFalse);
  });

  test('skips enqueue when remoteGroupId absent', () {
    final db = LocalDatabase(InMemoryStorageBackend());
    final queue = SyncQueue(database: db, remote: _NoopRemote());
    final sync = InvestigationSync(syncQueue: queue);
    final journey = StudentJourney(
      content: buildLocalContentPack(),
      investigationSync: sync,
    )
      ..completeDeviceCheck(arSupported: false)
      ..joinWithGroup(groupName: 'Tim A', leaderName: 'Budi')
      ..finishOnboarding();

    journey.saveLogbook({journey.activeMission.logbookPrompts[0]: 'x'});
    expect(queue.operations(), isEmpty);
  });
}
