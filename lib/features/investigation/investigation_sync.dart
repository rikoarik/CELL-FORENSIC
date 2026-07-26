import 'package:cell_forensic/core/app_services.dart';
import 'package:cell_forensic/core/sync/stable_entity_uuid.dart';
import 'package:cell_forensic/core/sync/sync_entity_cache.dart';
import 'package:cell_forensic/core/sync/sync_operation.dart';
import 'package:cell_forensic/core/sync/sync_queue.dart';
import 'package:cell_forensic/features/content/local_content_pack.dart';
import 'package:cell_forensic/features/journey/student_journey.dart';
import 'package:cell_forensic/features/session/remote_session_service.dart';

export 'package:cell_forensic/core/sync/stable_entity_uuid.dart'
    show stableEntityUuid;

/// Offline-first autosave helper for logbook + conclusion (E4-05 / E4-06).
///
/// Always writes through the caller's local persistence first. When
/// [StudentJourney.remoteGroupId] is set and [AppServices] is available,
/// enqueues Supabase upserts without blocking the UI.
class InvestigationSync {
  const InvestigationSync({
    SyncQueue? syncQueue,
    RemoteSessionService remoteSessionService = const RemoteSessionService(),
  }) : _syncQueue = syncQueue,
       _remote = remoteSessionService;

  final SyncQueue? _syncQueue;
  final RemoteSessionService _remote;

  SyncQueue? get _queue =>
      _syncQueue ??
      (AppServices.isInitialized ? AppServices.instance.syncQueue : null);

  /// Enqueues an observation_records upsert for the active mission logbook.
  void enqueueLogbook({
    required StudentJourney journey,
    required Map<String, String> entries,
  }) {
    final groupId = journey.remoteGroupId;
    final queue = _queue;
    if (groupId == null || queue == null) return;

    final mission = journey.activeMission;
    final entityKey = '$groupId-${mission.code}';
    final prompts = mission.logbookPrompts;
    String at(int i) =>
        i < prompts.length ? (entries[prompts[i]] ?? '').trim() : '';

    final existing = queue.entity('observation_records', entityKey);
    final baseVersion = syncCachedVersion(existing);
    final recordId =
        syncCachedString(existing, 'id') ??
        stableEntityUuid('obs:$entityKey');

    // Resolve mission_id in the background when possible; payload stays valid
    // without it (column is nullable) so offline enqueue never blocks.
    final cachedMissionId = syncCachedString(existing, 'mission_id');
    final payload = <String, Object?>{
      'id': recordId,
      'group_id': groupId,
      'sample_ref': mission.sampleRef,
      'structure_state': at(0),
      'detected_structure': at(1),
      'glow_color': at(2),
      'function_analysis': at(3),
      'damage_impact': at(3),
      'outer_layer_material': mission.orderNumber == 2 || mission.orderNumber == 3
          ? at(1)
          : '',
      'outer_layer_condition': mission.orderNumber >= 2 ? at(0) : '',
      'visual_effects': <String>[],
      'version': baseVersion + 1,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'mission_id': ?cachedMissionId,
    };

    queue.enqueue(
      idempotencyKey: 'obs-$entityKey-v${baseVersion + 1}',
      entityType: 'observation_records',
      entityId: entityKey,
      opType: SyncOpType.update,
      baseVersion: baseVersion,
      payload: payload,
    );
    _requestFlush();

    if (cachedMissionId == null) {
      _remote.findPublishedMissionId(mission.code).then((missionId) {
        if (missionId == null) return;
        final latest = queue.entity('observation_records', entityKey);
        if (latest == null) return;
        final version = syncCachedVersion(latest);
        final latestPayload = syncCachedPayload(latest);
        if (latestPayload == null) return;
        queue.enqueue(
          idempotencyKey: 'obs-$entityKey-mission-$missionId-v$version',
          entityType: 'observation_records',
          entityId: entityKey,
          opType: SyncOpType.update,
          baseVersion: version,
          payload: {
            ...latestPayload,
            'mission_id': missionId,
            'version': version + 1,
          },
        );
        _requestFlush();
      });
    }
  }

  /// Enqueues investigation_conclusions upsert (draft or submitted).
  void enqueueConclusion({
    required StudentJourney journey,
    required ConclusionDraft draft,
    required bool submitted,
  }) {
    final groupId = journey.remoteGroupId;
    final queue = _queue;
    if (groupId == null || queue == null) return;

    final entityId = groupId;
    final existing = queue.entity('investigation_conclusions', entityId);
    final baseVersion = syncCachedVersion(existing);
    // Prefer stable id = group_id so upsert matches the unique(group_id) row.
    final recordId = syncCachedString(existing, 'id') ?? groupId;

    queue.enqueue(
      idempotencyKey: 'concl-$entityId-v${baseVersion + 1}',
      entityType: 'investigation_conclusions',
      entityId: entityId,
      opType: SyncOpType.update,
      baseVersion: baseVersion,
      payload: {
        'id': recordId,
        'group_id': groupId,
        'sample_a_identity': draft.sampleAIdentity,
        'sample_a_reasoning': draft.sampleAReasoning,
        'sample_b_identity': draft.sampleBIdentity,
        'sample_b_reasoning': draft.sampleBReasoning,
        'group_hypothesis': draft.hypothesis,
        'status': submitted ? 'submitted' : 'draft',
        if (submitted) 'submitted_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
    _requestFlush();
  }

  void _requestFlush() {
    if (AppServices.isInitialized) {
      AppServices.instance.requestSyncFlush();
    }
  }
}

/// Draft conclusion fields kept for autosave / restore.
class ConclusionDraft {
  const ConclusionDraft({
    this.sampleAIdentity = '',
    this.sampleAReasoning = '',
    this.sampleBIdentity = '',
    this.sampleBReasoning = '',
    this.hypothesis = '',
  });

  factory ConclusionDraft.fromJson(Map<String, Object?> json) {
    return ConclusionDraft(
      sampleAIdentity: (json['sample_a_identity'] as String?) ?? '',
      sampleAReasoning: (json['sample_a_reasoning'] as String?) ?? '',
      sampleBIdentity: (json['sample_b_identity'] as String?) ?? '',
      sampleBReasoning: (json['sample_b_reasoning'] as String?) ?? '',
      hypothesis: (json['hypothesis'] as String?) ?? '',
    );
  }

  factory ConclusionDraft.fromConclusion(Conclusion conclusion) {
    return ConclusionDraft(
      sampleAIdentity: conclusion.sampleAIdentity,
      sampleAReasoning: conclusion.sampleAReasoning,
      sampleBIdentity: conclusion.sampleBIdentity,
      sampleBReasoning: conclusion.sampleBReasoning,
      hypothesis: conclusion.hypothesis,
    );
  }

  final String sampleAIdentity;
  final String sampleAReasoning;
  final String sampleBIdentity;
  final String sampleBReasoning;
  final String hypothesis;

  bool get isEmpty =>
      sampleAIdentity.isEmpty &&
      sampleAReasoning.isEmpty &&
      sampleBIdentity.isEmpty &&
      sampleBReasoning.isEmpty &&
      hypothesis.isEmpty;

  Map<String, Object?> toJson() => {
    'sample_a_identity': sampleAIdentity,
    'sample_a_reasoning': sampleAReasoning,
    'sample_b_identity': sampleBIdentity,
    'sample_b_reasoning': sampleBReasoning,
    'hypothesis': hypothesis,
  };
}

/// Maps mission logbook prompts for sync helpers (kept for tests).
List<String> logbookPromptKeys(MissionContent mission) => mission.logbookPrompts;
