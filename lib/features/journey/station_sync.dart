import 'package:cell_forensic/core/app_services.dart';
import 'package:cell_forensic/core/sync/stable_entity_uuid.dart';
import 'package:cell_forensic/core/sync/student_answer_payload.dart';
import 'package:cell_forensic/core/sync/sync_entity_cache.dart';
import 'package:cell_forensic/core/sync/sync_operation.dart';
import 'package:cell_forensic/core/sync/sync_queue.dart';
import 'package:cell_forensic/features/content/local_content_pack.dart';
import 'package:cell_forensic/features/journey/student_journey.dart';
import 'package:cell_forensic/features/session/remote_session_service.dart';

/// Offline-first autosave helper for POS station answers (E5-06 / E10).
///
/// Local snapshot persistence always wins. When
/// [StudentJourney.remoteGroupId] is set and [AppServices] is available,
/// enqueues Supabase upserts for `station_attempts` / `answers` without
/// blocking the UI.
///
/// Cloud rows use UUID PKs and `station_id` / `question_id` FKs (not content
/// codes). Lookups are best-effort; if the catalog is unreachable the local
/// journey still proceeds and the op is enqueued once IDs resolve.
class StationSync {
  const StationSync({
    SyncQueue? syncQueue,
    RemoteSessionService remoteSessionService = const RemoteSessionService(),
  }) : _syncQueue = syncQueue,
       _remote = remoteSessionService;

  final SyncQueue? _syncQueue;
  final RemoteSessionService _remote;

  SyncQueue? get _queue =>
      _syncQueue ??
      (AppServices.isInitialized ? AppServices.instance.syncQueue : null);

  String attemptEntityId(StudentJourney journey, StationContent station) =>
      '${journey.remoteGroupId}-${station.code}';

  /// Records that a station attempt has started (timer running).
  void enqueueStationStart({required StudentJourney journey}) {
    final groupId = journey.remoteGroupId;
    final queue = _queue;
    final expiresAt = journey.stationExpiresAt;
    if (groupId == null || queue == null || expiresAt == null) return;

    final station = journey.activeStation;
    final entityId = attemptEntityId(journey, station);
    final existing = queue.entity('station_attempts', entityId);
    final baseVersion = syncCachedVersion(existing);
    final recordId =
        syncCachedString(existing, 'id') ?? stableEntityUuid('sta:$entityId');
    final cachedStationId = syncCachedString(existing, 'station_id');

    void enqueueWithStationId(String stationId, int version) {
      queue.enqueue(
        idempotencyKey: 'sta-start-$entityId-v${version + 1}',
        entityType: 'station_attempts',
        entityId: entityId,
        opType: version == 0 ? SyncOpType.create : SyncOpType.update,
        baseVersion: version,
        payload: {
          'id': recordId,
          'group_id': groupId,
          'station_id': stationId,
          'status': 'active',
          'started_at': DateTime.now().toUtc().toIso8601String(),
          'expires_at': expiresAt.toUtc().toIso8601String(),
        },
      );
      _requestFlush();
    }

    if (cachedStationId != null) {
      enqueueWithStationId(cachedStationId, baseVersion);
      return;
    }

    _remote.findPublishedStationId(station.code).then((stationId) {
      if (stationId == null) return;
      final latest = queue.entity('station_attempts', entityId);
      enqueueWithStationId(stationId, syncCachedVersion(latest));
    });
  }

  /// Autosaves one answer while the station timer is running (FR-094).
  ///
  /// Writes only E10-allowed columns (`answer_text` / `auto_score` / …).
  void enqueueAnswer({
    required StudentJourney journey,
    required String questionCode,
    required String answerText,
  }) {
    final groupId = journey.remoteGroupId;
    final queue = _queue;
    if (groupId == null || queue == null) return;

    final station = journey.activeStation;
    final attemptEntity = attemptEntityId(journey, station);
    final entityId = '$attemptEntity-$questionCode';
    final existing = queue.entity('answers', entityId);
    final baseVersion = syncCachedVersion(existing);
    final recordId =
        syncCachedString(existing, 'id') ?? stableEntityUuid('ans:$entityId');
    final attemptRow = queue.entity('station_attempts', attemptEntity);
    final attemptRecordId =
        syncCachedString(attemptRow, 'id') ??
        stableEntityUuid('sta:$attemptEntity');
    final cachedQuestionId = syncCachedString(existing, 'question_id');

    void enqueueWithQuestionId(String questionId, int version) {
      _enqueueAnswerPayload(
        queue: queue,
        entityId: entityId,
        baseVersion: version,
        isCreate: version == 0,
        payload: {
          'id': recordId,
          'group_id': groupId,
          'question_id': questionId,
          'station_attempt_id': attemptRecordId,
          'answer_text': answerText,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'version': version + 1,
        },
      );
    }

    if (cachedQuestionId != null) {
      enqueueWithQuestionId(cachedQuestionId, baseVersion);
      return;
    }

    _remote.findPublishedQuestionId(questionCode).then((questionId) {
      if (questionId == null) return;
      final latest = queue.entity('answers', entityId);
      final version = syncCachedVersion(latest);
      final latestText =
          syncCachedString(latest, 'answer_text') ?? answerText;
      _enqueueAnswerPayload(
        queue: queue,
        entityId: entityId,
        baseVersion: version,
        isCreate: version == 0,
        payload: {
          'id': recordId,
          'group_id': groupId,
          'question_id': questionId,
          'station_attempt_id': attemptRecordId,
          'answer_text': latestText,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'version': version + 1,
        },
      );
    });
  }

  void _enqueueAnswerPayload({
    required SyncQueue queue,
    required String entityId,
    required int baseVersion,
    required bool isCreate,
    required Map<String, Object?> payload,
  }) {
    final safe = StudentAnswerPayload.sanitize(payload);
    if (safe['question_id'] == null) {
      // Wait for async question id resolution — do not enqueue a doomed insert.
      return;
    }

    queue.enqueue(
      idempotencyKey: 'ans-$entityId-v${safe['version']}',
      entityType: 'answers',
      entityId: entityId,
      opType: isCreate ? SyncOpType.create : SyncOpType.update,
      baseVersion: baseVersion,
      payload: safe,
    );
    _requestFlush();
  }

  /// Locks a station attempt as submitted or expired (FR-096).
  void enqueueStationSubmit({
    required StudentJourney journey,
    required StationContent station,
    required bool expired,
  }) {
    final groupId = journey.remoteGroupId;
    final queue = _queue;
    if (groupId == null || queue == null) return;

    final entityId = attemptEntityId(journey, station);
    final existing = queue.entity('station_attempts', entityId);
    final baseVersion = syncCachedVersion(existing);
    final recordId =
        syncCachedString(existing, 'id') ?? stableEntityUuid('sta:$entityId');
    final cachedStationId = syncCachedString(existing, 'station_id');

    void enqueueWithStationId(String stationId, int version) {
      queue.enqueue(
        idempotencyKey: 'sta-submit-$entityId-v${version + 1}',
        entityType: 'station_attempts',
        entityId: entityId,
        opType: version == 0 ? SyncOpType.create : SyncOpType.update,
        baseVersion: version,
        payload: {
          'id': recordId,
          'group_id': groupId,
          'station_id': stationId,
          'status': expired ? 'expired' : 'submitted',
          'submitted_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
      _requestFlush();
    }

    if (cachedStationId != null) {
      enqueueWithStationId(cachedStationId, baseVersion);
      return;
    }

    _remote.findPublishedStationId(station.code).then((stationId) {
      if (stationId == null) return;
      final latest = queue.entity('station_attempts', entityId);
      enqueueWithStationId(stationId, syncCachedVersion(latest));
    });
  }

  void _requestFlush() {
    if (AppServices.isInitialized) {
      AppServices.instance.requestSyncFlush();
    }
  }
}
