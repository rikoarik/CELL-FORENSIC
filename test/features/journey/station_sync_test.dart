import 'package:cell_forensic/core/database/local_store.dart';
import 'package:cell_forensic/core/sync/stable_entity_uuid.dart';
import 'package:cell_forensic/core/sync/sync_operation.dart';
import 'package:cell_forensic/core/sync/sync_queue.dart';
import 'package:cell_forensic/domain/entities.dart';
import 'package:cell_forensic/features/content/local_content_pack.dart';
import 'package:cell_forensic/features/journey/station_sync.dart';
import 'package:cell_forensic/features/journey/student_journey.dart';
import 'package:cell_forensic/features/session/remote_session_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoopRemote implements RemoteSyncClient {
  @override
  Future<void> push(SyncOperation operation) async {}
}

class _FakeRemoteCatalog extends RemoteSessionService {
  _FakeRemoteCatalog({
    this.stationIds = const {},
    this.questionIds = const {},
  });

  final Map<String, String> stationIds;
  final Map<String, String> questionIds;

  @override
  Future<LearningSession?> findActiveSession(String joinCode) async => null;

  @override
  Future<RemoteJoinResult?> joinActiveSession({
    required String joinCode,
    required String groupName,
    required String leaderName,
  }) async =>
      null;

  @override
  Future<String?> findPublishedMissionId(String code) async => null;

  @override
  Future<String?> findPublishedStationId(String code) async =>
      stationIds[code];

  @override
  Future<String?> findPublishedQuestionId(String code) async =>
      questionIds[code];
}

StudentJourney _stationsJourney({
  required StationSync sync,
  String? remoteGroupId,
}) {
  final journey = StudentJourney(
    content: buildLocalContentPack(),
    stationSync: sync,
  )
    ..completeDeviceCheck(arSupported: false)
    ..joinWithGroup(
      groupName: 'Tim A',
      leaderName: 'Budi',
      remoteGroupId: remoteGroupId,
    )
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

void main() {
  test('station start enqueues UUID id + station_id FK (not station_code)',
      () async {
    final db = LocalDatabase(InMemoryStorageBackend());
    final queue = SyncQueue(database: db, remote: _NoopRemote());
    const stationUuid = '11111111-1111-5111-8111-111111111111';
    final sync = StationSync(
      syncQueue: queue,
      remoteSessionService: _FakeRemoteCatalog(
        stationIds: {'POS-1': stationUuid},
      ),
    );
    final journey = _stationsJourney(sync: sync, remoteGroupId: 'group-1')
      ..unlockStation('1111');

    await Future<void>.delayed(Duration.zero);

    final ops = queue.operations();
    expect(ops, isNotEmpty);
    final start = ops.firstWhere((op) => op.entityType == 'station_attempts');
    expect(start.payload['station_code'], isNull);
    expect(start.payload['station_id'], stationUuid);
    expect(start.payload['id'], stableEntityUuid('sta:group-1-POS-1'));
    expect(start.payload['group_id'], 'group-1');
    expect(start.payload.containsKey('version'), isFalse);
    expect(journey.stationExpiresAt, isNotNull);
  });

  test('answer enqueue uses question_id UUID and station_attempt_id UUID',
      () async {
    final db = LocalDatabase(InMemoryStorageBackend());
    final queue = SyncQueue(database: db, remote: _NoopRemote());
    const stationUuid = '11111111-1111-5111-8111-111111111111';
    const questionUuid = '22222222-2222-5222-8222-222222222222';
    final sync = StationSync(
      syncQueue: queue,
      remoteSessionService: _FakeRemoteCatalog(
        stationIds: {'POS-1': stationUuid},
        questionIds: {'POS1-Q1': questionUuid},
      ),
    );
    final journey = _stationsJourney(sync: sync, remoteGroupId: 'group-1')
      ..unlockStation('1111');
    await Future<void>.delayed(Duration.zero);

    journey.answerQuestion('POS1-Q1', 'Sampel A');
    await Future<void>.delayed(Duration.zero);

    final answerOps = queue
        .operations()
        .where((op) => op.entityType == 'answers')
        .toList();
    expect(answerOps, isNotEmpty);
    final payload = answerOps.last.payload;
    expect(payload['question_code'], isNull);
    expect(payload['question_id'], questionUuid);
    expect(payload['station_attempt_id'], stableEntityUuid('sta:group-1-POS-1'));
    expect(payload['id'], isNot(contains('POS1-Q1')));
    expect(payload['id'], matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(payload['answer_text'], 'Sampel A');
  });

  test('skips remote enqueue when remoteGroupId absent', () async {
    final db = LocalDatabase(InMemoryStorageBackend());
    final queue = SyncQueue(database: db, remote: _NoopRemote());
    final sync = StationSync(
      syncQueue: queue,
      remoteSessionService: _FakeRemoteCatalog(
        stationIds: {'POS-1': '11111111-1111-5111-8111-111111111111'},
      ),
    );
    final journey = _stationsJourney(sync: sync)..unlockStation('1111');
    journey.answerQuestion('POS1-Q1', 'x');
    await Future<void>.delayed(Duration.zero);
    expect(queue.operations(), isEmpty);
  });

  test('re-enqueue keeps stable UUID from cached payload', () async {
    final db = LocalDatabase(InMemoryStorageBackend());
    final queue = SyncQueue(database: db, remote: _NoopRemote());
    const stationUuid = '11111111-1111-5111-8111-111111111111';
    final sync = StationSync(
      syncQueue: queue,
      remoteSessionService: _FakeRemoteCatalog(
        stationIds: {'POS-1': stationUuid},
      ),
    );
    final journey = _stationsJourney(sync: sync, remoteGroupId: 'group-1')
      ..unlockStation('1111');
    await Future<void>.delayed(Duration.zero);

    journey.submitActiveStation();
    await Future<void>.delayed(Duration.zero);

    final attempts = queue
        .operations()
        .where((op) => op.entityType == 'station_attempts')
        .toList();
    expect(attempts.length, greaterThanOrEqualTo(2));
    final ids = attempts.map((op) => op.payload['id']).toSet();
    expect(ids, {stableEntityUuid('sta:group-1-POS-1')});
    expect(attempts.last.payload['station_id'], stationUuid);
    expect(attempts.last.payload['status'], 'submitted');
  });
}
