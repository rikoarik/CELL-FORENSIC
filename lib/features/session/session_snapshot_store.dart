import 'package:cell_forensic/core/database/local_store.dart';
import 'package:cell_forensic/domain/entities.dart';
import 'package:cell_forensic/features/investigation/investigation_sync.dart';
import 'package:flutter/foundation.dart';

/// Durable table + row id for the active student session/group snapshot.
const String kSessionSnapshotTable = 'session_snapshots';
const String kActiveSnapshotId = 'active';

/// Durable per-mission progress entry for the intent-driven journey map.
///
/// This is the persistence-side mirror of the mission-state-agent's progress
/// map. Until that agent lands its own strongly-typed value object, this is
/// the source-of-truth JSON contract. Expected mission-state type once it
/// exists:
///
/// ```dart
/// enum MissionStatus { locked, available, running, completed }
///
/// class MissionProgress {
///   final MissionStatus status;
///   final DateTime? startedAt;   // == missionStartedAt (first valid intent)
///   final DateTime? completedAt; // == missionCompletedAt (after success)
/// }
///
/// typedef MissionProgressMap = Map<String, MissionProgress>; // key: mission1..3
/// ```
///
/// The map is keyed by logical mission id (`mission1` | `mission2` | `mission3`)
/// so a relaunch after placement can restore the *logical* journey/mission
/// progress even though the AR anchor itself is not durable.
@immutable
class MissionProgressSnapshot {
  const MissionProgressSnapshot({
    required this.status,
    this.startedAtMs,
    this.completedAtMs,
  });

  /// Mission not yet reachable (prerequisite mission not completed).
  static const String statusLocked = 'locked';

  /// Mission reachable but no valid intent has run yet.
  static const String statusAvailable = 'available';

  /// A valid mission intent has run; [startedAtMs] is set. In-progress.
  static const String statusRunning = 'running';

  /// Mission observation succeeded; [completedAtMs] is set (write-once).
  static const String statusCompleted = 'completed';

  static const Set<String> validStatuses = {
    statusLocked,
    statusAvailable,
    statusRunning,
    statusCompleted,
  };

  factory MissionProgressSnapshot.fromJson(Map<String, Object?> json) {
    final rawStatus = json['status'] as String?;
    return MissionProgressSnapshot(
      status: validStatuses.contains(rawStatus) ? rawStatus! : statusLocked,
      startedAtMs: json['started_at_ms'] as int?,
      completedAtMs: json['completed_at_ms'] as int?,
    );
  }

  /// One of [validStatuses]: `locked|available|running|completed`.
  final String status;

  /// `missionStartedAt` in epoch ms — set when the first valid intent runs.
  final int? startedAtMs;

  /// `missionCompletedAt` in epoch ms — set once after a successful observation.
  final int? completedAtMs;

  bool get isCompleted => status == statusCompleted;

  DateTime? get startedAt => startedAtMs == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(startedAtMs!);

  DateTime? get completedAt => completedAtMs == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(completedAtMs!);

  MissionProgressSnapshot copyWith({
    String? status,
    int? startedAtMs,
    int? completedAtMs,
  }) => MissionProgressSnapshot(
    status: status ?? this.status,
    startedAtMs: startedAtMs ?? this.startedAtMs,
    completedAtMs: completedAtMs ?? this.completedAtMs,
  );

  Map<String, Object?> toJson() => {
    'status': status,
    'started_at_ms': startedAtMs,
    'completed_at_ms': completedAtMs,
  };
}

/// Offline snapshot of the student's joined session + investigation/POS
/// progress (E2-04, E4-05, E5-06).
@immutable
class SessionSnapshot {
  const SessionSnapshot({
    required this.stageName,
    required this.arSupported,
    required this.joinCode,
    required this.sessionId,
    required this.sessionTitle,
    required this.group,
    this.remoteSessionId,
    this.remoteGroupId,
    this.missionIndex = 0,
    this.missionProgress = const {},
    this.sequenceStepIndex,
    this.sequenceCompleted = false,
    this.logbookByMission = const {},
    this.conclusionDraft,
    this.stationIndex = 0,
    this.activeStationUnlocked = false,
    this.answers = const {},
    this.submittedStationCodes = const [],
    this.stationExpiresAtMs,
  });

  factory SessionSnapshot.fromJson(Map<String, Object?> json) {
    final groupJson = (json['group'] as Map).cast<String, Object?>();
    final logbookRaw = json['logbook_by_mission'];
    final logbook = <String, Map<String, String>>{};
    if (logbookRaw is Map) {
      for (final entry in logbookRaw.entries) {
        final inner = entry.value;
        if (inner is Map) {
          logbook[entry.key.toString()] = {
            for (final e in inner.entries)
              e.key.toString(): e.value?.toString() ?? '',
          };
        }
      }
    }

    ConclusionDraft? draft;
    final draftRaw = json['conclusion_draft'];
    if (draftRaw is Map) {
      draft = ConclusionDraft.fromJson(draftRaw.cast<String, Object?>());
    }

    final answersRaw = json['answers'];
    final answers = <String, String>{};
    if (answersRaw is Map) {
      for (final e in answersRaw.entries) {
        answers[e.key.toString()] = e.value?.toString() ?? '';
      }
    }

    final submittedRaw = json['submitted_station_codes'];
    final submitted = <String>[];
    if (submittedRaw is List) {
      for (final item in submittedRaw) {
        submitted.add(item.toString());
      }
    }

    final missionProgressRaw = json['mission_progress'];
    final missionProgress = <String, MissionProgressSnapshot>{};
    if (missionProgressRaw is Map) {
      for (final entry in missionProgressRaw.entries) {
        final value = entry.value;
        if (value is Map) {
          missionProgress[entry.key.toString()] =
              MissionProgressSnapshot.fromJson(value.cast<String, Object?>());
        }
      }
    }

    return SessionSnapshot(
      stageName: (json['stage'] as String?) ?? 'groupSetup',
      arSupported: json['ar_supported'] as bool? ?? false,
      joinCode: json['join_code']! as String,
      sessionId: json['session_id']! as String,
      sessionTitle: (json['session_title'] as String?) ?? '',
      group: Group.fromJson(groupJson),
      remoteSessionId: json['remote_session_id'] as String?,
      remoteGroupId: json['remote_group_id'] as String?,
      missionIndex: json['mission_index'] as int? ?? 0,
      missionProgress: missionProgress,
      sequenceStepIndex: json['sequence_step_index'] as int?,
      sequenceCompleted: json['sequence_completed'] as bool? ?? false,
      logbookByMission: logbook,
      conclusionDraft: draft,
      stationIndex: json['station_index'] as int? ?? 0,
      activeStationUnlocked: json['active_station_unlocked'] as bool? ?? false,
      answers: answers,
      submittedStationCodes: submitted,
      stationExpiresAtMs: json['station_expires_at_ms'] as int?,
    );
  }

  final String stageName;
  final bool arSupported;
  final String joinCode;
  final String sessionId;
  final String sessionTitle;
  final Group group;
  final String? remoteSessionId;
  final String? remoteGroupId;
  final int missionIndex;

  /// Intent-driven per-mission progress map, keyed by logical mission id
  /// (`mission1` | `mission2` | `mission3`). Empty until the first valid
  /// mission intent runs, so app launch / join / create-group never seed
  /// mission counters (no orphan progress before real journey activity).
  final Map<String, MissionProgressSnapshot> missionProgress;

  final int? sequenceStepIndex;
  final bool sequenceCompleted;
  final Map<String, Map<String, String>> logbookByMission;
  final ConclusionDraft? conclusionDraft;

  /// 0-based POS station index (E5-06).
  final int stationIndex;

  /// Whether the active POS station is unlocked (E5-01 / E5-06).
  final bool activeStationUnlocked;

  /// Autosaved answers keyed by question code (E5-06 / FR-094).
  final Map<String, String> answers;

  /// Station codes already submitted/locked (FR-096).
  final List<String> submittedStationCodes;

  /// Wall-clock expiry for the active unlocked station timer, epoch ms.
  final int? stationExpiresAtMs;

  Map<String, Object?> toJson() => {
    'stage': stageName,
    'ar_supported': arSupported,
    'join_code': joinCode,
    'session_id': sessionId,
    'session_title': sessionTitle,
    'group': group.toJson(),
    'remote_session_id': remoteSessionId,
    'remote_group_id': remoteGroupId,
    'mission_index': missionIndex,
    // Only persist the mission map once it has real entries so a fresh
    // session (post join/create-group, pre first intent) writes no orphan
    // mission progress.
    if (missionProgress.isNotEmpty)
      'mission_progress': {
        for (final e in missionProgress.entries) e.key: e.value.toJson(),
      },
    'sequence_step_index': sequenceStepIndex,
    'sequence_completed': sequenceCompleted,
    'logbook_by_mission': {
      for (final e in logbookByMission.entries) e.key: e.value,
    },
    if (conclusionDraft != null) 'conclusion_draft': conclusionDraft!.toJson(),
    'station_index': stationIndex,
    'active_station_unlocked': activeStationUnlocked,
    'answers': answers,
    'submitted_station_codes': submittedStationCodes,
    'station_expires_at_ms': stationExpiresAtMs,
  };
}

/// Reads/writes the active [SessionSnapshot] via [LocalDatabase].
class SessionSnapshotStore {
  const SessionSnapshotStore(this._db);

  final LocalDatabase _db;

  SessionSnapshot? loadActive() {
    final row = _db.read(kSessionSnapshotTable, kActiveSnapshotId);
    if (row == null) return null;
    try {
      return SessionSnapshot.fromJson(row);
    } catch (_) {
      return null;
    }
  }

  void save(SessionSnapshot snapshot) {
    _db.transaction((txn) {
      txn.put(kSessionSnapshotTable, kActiveSnapshotId, snapshot.toJson());
      return null;
    });
  }

  void clear() {
    _db.transaction((txn) {
      txn.delete(kSessionSnapshotTable, kActiveSnapshotId);
      return null;
    });
  }
}
