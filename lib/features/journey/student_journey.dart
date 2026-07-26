import 'package:cell_forensic/domain/entities.dart';
import 'package:cell_forensic/domain/mission_progress.dart';
import 'package:cell_forensic/domain/scoring/scoring_engine.dart';
import 'package:cell_forensic/features/content/local_content_pack.dart';
import 'package:cell_forensic/features/investigation/investigation_sync.dart';
import 'package:cell_forensic/features/journey/station_sync.dart';
import 'package:cell_forensic/features/session/session_snapshot_store.dart';
import 'package:flutter/foundation.dart';

/// Stages of the student journey, mirroring the group state machine in
/// `docs/04_USER_FLOW_GAMEPLAY.md` but scoped to the local student MVP.
enum JourneyStage {
  deviceCheck,
  joinSession,
  groupSetup,
  onboarding,
  investigating,
  conclusion,
  stations,
  results,
}

/// Drives the end-to-end student flow entirely from the local [ContentPack].
///
/// Session/group state can be persisted offline via [SessionSnapshotStore]
/// (E2-04). Mid-mission logbook + conclusion drafts persist in E4-05.
/// POS answers, timer expiry, and station rotation persist in E5-06.
/// UI screens listen via [ChangeNotifier] and call the command methods to
/// advance the state machine.
class StudentJourney extends ChangeNotifier {
  StudentJourney({
    required this.content,
    ScoringEngine? scoringEngine,
    InvestigationSync? investigationSync,
    StationSync? stationSync,
  }) : _scoring = scoringEngine ?? const ScoringEngine(),
       _sync = investigationSync ?? const InvestigationSync(),
       _stationSync = stationSync ?? const StationSync();

  final ContentPack content;
  final ScoringEngine _scoring;
  final InvestigationSync _sync;
  final StationSync _stationSync;

  JourneyStage _stage = JourneyStage.deviceCheck;
  bool _arSupported = false;
  String? _joinCode;
  String? _sessionId;
  String? _sessionTitle;
  String? _groupName;
  String? _leaderName;
  Group? _group;
  String? _remoteSessionId;
  String? _remoteGroupId;
  int _missionIndex = 0;
  bool _labPlaced = false;
  /// Intent-driven progress — empty until AR placement (no orphan seed).
  final Map<String, MissionProgress> _missionProgress = {};
  int _stationIndex = 0;
  bool _activeStationUnlocked = false;
  DateTime? _stationExpiresAt;
  final Set<String> _submittedStationCodes = {};
  String? _lastError;

  /// Sequence progress for the active mission (null = not started in UI).
  int? sequenceStepIndex;
  bool sequenceCompleted = false;

  /// Completed logbook entries keyed by mission code.
  final Map<String, Map<String, String>> logbookByMission = {};

  /// Sample A organelle observation ids (not mission completion).
  final Set<String> inspectedOrganelleHotspots = {};

  /// Autosaved conclusion draft (E4-06).
  ConclusionDraft? conclusionDraft;

  /// Autosaved / submitted answers keyed by question code.
  final Map<String, String> _answers = {};

  JourneyStage get stage => _stage;
  bool get arSupported => _arSupported;
  String? get joinCode => _joinCode;
  String? get sessionId => _sessionId;
  String? get sessionTitle => _sessionTitle ?? content.sessionTitle;
  String? get groupName => _groupName;
  String? get leaderName => _leaderName;
  Group? get group => _group;
  List<GroupMember> get members => _group?.members ?? const [];
  String? get lastError => _lastError;
  String? get remoteSessionId => _remoteSessionId;
  String? get remoteGroupId => _remoteGroupId;
  bool get isCloudSynced => _remoteGroupId != null;

  /// 0-based index of the focused mission (UI / logbook). Not a linear counter.
  int get missionIndex => _missionIndex;

  /// Total missions in the local content pack.
  int get missionCount => content.missions.length;

  /// Whether Scene 1 lab table + samples have been placed.
  bool get labPlaced => _labPlaced;

  /// Intent-driven progress map (`mission1`…`mission3`). Empty before placement.
  Map<String, MissionProgress> get missionProgress =>
      Map.unmodifiable(_missionProgress);

  /// True when any mission is currently `running`.
  bool get hasRunningMission =>
      _missionProgress.values.any((p) => p.status == MissionStatus.running);

  /// Mission number (1–3) currently running, or null.
  int? get runningMissionNumber {
    for (final e in _missionProgress.entries) {
      if (e.value.status == MissionStatus.running) {
        return MissionProgress.numberForKey(e.key);
      }
    }
    return null;
  }

  /// True when all three missions are completed.
  bool get allMissionsCompleted => MissionProgress.logicalIds.every((key) {
    return _missionProgress[key]?.status == MissionStatus.completed;
  });

  /// 0-based index of the active POS station.
  int get stationIndex => _stationIndex;

  /// Total POS stations in the local content pack.
  int get stationCount => content.stations.length;

  MissionContent get activeMission => content.missions[_missionIndex];
  StationContent get activeStation => content.stations[_stationIndex];
  bool get activeStationUnlocked => _activeStationUnlocked;

  MissionStatus missionStatus(int missionNumber) {
    final key = MissionProgress.keyFor(missionNumber);
    return _missionProgress[key]?.status ?? MissionStatus.locked;
  }

  /// Wall-clock expiry for the active unlocked station (FR-093).
  DateTime? get stationExpiresAt => _stationExpiresAt;

  /// Remaining seconds on the active station timer; `null` when locked.
  ///
  /// Uses ceil-to-second so a just-started attempt still reports the full
  /// [ContentPack.stationDurationSeconds] for a short moment.
  int? get stationRemainingSeconds {
    if (!_activeStationUnlocked || _stationExpiresAt == null) return null;
    final ms = _stationExpiresAt!.difference(DateTime.now()).inMilliseconds;
    if (ms <= 0) return 0;
    return (ms + 999) ~/ 1000;
  }

  /// Test-only: move wall-clock expiry into the past without auto-submitting
  /// so UI resume / tick enforcement can be exercised (FR-093 / FR-096).
  @visibleForTesting
  void debugExpireStationWallClock() {
    if (!_activeStationUnlocked) return;
    _stationExpiresAt = DateTime.now().subtract(const Duration(seconds: 1));
  }

  /// Station codes already submitted/locked (FR-096).
  Set<String> get submittedStationCodes =>
      Set.unmodifiable(_submittedStationCodes);

  /// Next station in the rotation, or `null` when on the last POS (FR-095).
  StationContent? get nextStationInRotation {
    if (_stationIndex >= content.stations.length - 1) return null;
    return content.stations[_stationIndex + 1];
  }

  /// Whether answers for [stationCode] are locked after submit/timeout.
  bool isStationSubmitted(String stationCode) =>
      _submittedStationCodes.contains(stationCode);

  void completeDeviceCheck({required bool arSupported}) {
    _arSupported = arSupported;
    _transition(JourneyStage.joinSession);
  }

  /// Whether the progress-bar Back control should show.
  bool get canGoBack => _stage != JourneyStage.deviceCheck;

  /// Soft step back one journey stage (does not erase mission/logbook data).
  void goBack() {
    final prev = switch (_stage) {
      JourneyStage.deviceCheck => null,
      JourneyStage.joinSession => JourneyStage.deviceCheck,
      JourneyStage.groupSetup => JourneyStage.joinSession,
      // Live UI skips onboarding → investigating; step back to group setup.
      JourneyStage.onboarding => JourneyStage.groupSetup,
      JourneyStage.investigating => JourneyStage.groupSetup,
      JourneyStage.conclusion => JourneyStage.investigating,
      JourneyStage.stations => JourneyStage.conclusion,
      JourneyStage.results => JourneyStage.stations,
    };
    if (prev == null) return;
    _transition(prev);
  }

  /// Upgrades a Mode 3D session to live AR without resetting join/group state.
  ///
  /// Clears [labPlaced] so Scene 1 re-runs plane scan on the camera path.
  /// No-op when already on live AR.
  void enableLiveAr() {
    if (_arSupported) return;
    _arSupported = true;
    _labPlaced = false;
    notifyListeners();
  }

  /// Records a successful join by code (local and/or remote). Advances to
  /// [JourneyStage.groupSetup].
  void acceptJoinedSession({
    required String joinCode,
    required String sessionId,
    String? sessionTitle,
  }) {
    final code = joinCode.trim().toUpperCase();
    if (code.isEmpty || sessionId.trim().isEmpty) {
      _fail('Kode gabung tidak valid.');
      return;
    }
    _joinCode = code;
    _sessionId = sessionId.trim();
    _sessionTitle = sessionTitle?.trim().isEmpty == true
        ? null
        : sessionTitle?.trim();
    _clearError();
    _transition(JourneyStage.groupSetup);
  }

  /// Applies a created/updated local [group] during group setup.
  void setGroup(Group group, {String? remoteSessionId, String? remoteGroupId}) {
    final leader = group.members.cast<GroupMember?>().firstWhere(
      (m) => m!.isLeader,
      orElse: () => null,
    );
    if (leader == null) {
      _fail('Kelompok harus memiliki tepat satu ketua.');
      return;
    }
    _group = group;
    _groupName = group.name;
    _leaderName = leader.displayName;
    if (remoteSessionId != null) _remoteSessionId = remoteSessionId;
    if (remoteGroupId != null) _remoteGroupId = remoteGroupId;
    _clearError();
    notifyListeners();
  }

  /// Leaves group setup and opens Scene 1 AR init (skips mandatory onboarding).
  ///
  /// Does **not** start Misi 1 or seed mission progress — placement + intent do.
  void confirmGroupReady() {
    if (_group == null || _groupName == null || _leaderName == null) {
      _fail('Buat kelompok terlebih dahulu.');
      return;
    }
    _clearError();
    sequenceStepIndex = null;
    sequenceCompleted = false;
    // Progress stays empty until AR placement (no mission1:running seed).
    _transition(JourneyStage.investigating);
  }

  /// Joins the local session and registers the group in one step.
  ///
  /// Convenience for tests and legacy callers; the live UI uses
  /// [acceptJoinedSession] + [setGroup] + [confirmGroupReady].
  /// Advances to Scene 1 AR init — does not auto-start Misi 1.
  void joinWithGroup({
    required String groupName,
    required String leaderName,
    String? remoteSessionId,
    String? remoteGroupId,
    String? joinCode,
    String? sessionId,
  }) {
    final name = groupName.trim();
    final leader = leaderName.trim();
    if (name.isEmpty || leader.isEmpty) {
      _fail('Nama kelompok dan ketua wajib diisi.');
      return;
    }
    _joinCode = (joinCode ?? content.joinCode).trim().toUpperCase();
    _sessionId = sessionId ?? 'local-${_joinCode!.toLowerCase()}';
    _sessionTitle = content.sessionTitle;
    _groupName = name;
    _leaderName = leader;
    _remoteSessionId = remoteSessionId;
    _remoteGroupId = remoteGroupId;
    _group = Group(
      id: 'local-group',
      sessionId: _sessionId!,
      name: name,
      members: [
        GroupMember(id: 'local-leader', displayName: leader, isLeader: true),
      ],
    );
    _clearError();
    sequenceStepIndex = null;
    sequenceCompleted = false;
    _transition(JourneyStage.investigating);
  }

  /// Restores a previously persisted session/group snapshot (E2-04 / E4-05 /
  /// E5-06).
  ///
  /// Supports join/group/onboarding, mid-investigation, conclusion drafts,
  /// and POS station/results progress (answers, timer expiry, rotation).
  bool restoreFromSnapshot(SessionSnapshot snapshot) {
    _arSupported = snapshot.arSupported;
    _joinCode = snapshot.joinCode;
    _sessionId = snapshot.sessionId;
    _sessionTitle = snapshot.sessionTitle;
    _group = snapshot.group;
    _groupName = snapshot.group.name;
    final leader = snapshot.group.members.cast<GroupMember?>().firstWhere(
      (m) => m!.isLeader,
      orElse: () => null,
    );
    _leaderName = leader?.displayName;
    _remoteSessionId = snapshot.remoteSessionId;
    _remoteGroupId = snapshot.remoteGroupId;
    final maxMission =
        content.missions.isEmpty ? 0 : content.missions.length - 1;
    _missionIndex = snapshot.missionIndex.clamp(0, maxMission);
    sequenceStepIndex = snapshot.sequenceStepIndex;
    sequenceCompleted = snapshot.sequenceCompleted;
    _missionProgress
      ..clear()
      ..addAll({
        for (final e in snapshot.missionProgress.entries)
          e.key: MissionProgress(
            status: MissionStatus.values.firstWhere(
              (s) => s.name == e.value.status,
              orElse: () => MissionStatus.locked,
            ),
            startedAt: e.value.startedAt,
            completedAt: e.value.completedAt,
          ),
      });
    // Lab placement is session-local (AR anchor not durable). Logical progress
    // restores; UI may re-request plane placement. If any mission is past
    // locked, treat lab as previously placed for progress gating.
    _labPlaced = _missionProgress.values.any(
      (p) =>
          p.status == MissionStatus.available ||
          p.status == MissionStatus.running ||
          p.status == MissionStatus.completed,
    );
    logbookByMission
      ..clear()
      ..addAll({
        for (final e in snapshot.logbookByMission.entries) e.key: Map.of(e.value),
      });
    inspectedOrganelleHotspots
      ..clear()
      ..addAll(snapshot.inspectedOrganelleHotspots);
    conclusionDraft = snapshot.conclusionDraft;

    final maxStation =
        content.stations.isEmpty ? 0 : content.stations.length - 1;
    _stationIndex = snapshot.stationIndex.clamp(0, maxStation);
    _activeStationUnlocked = snapshot.activeStationUnlocked;
    _stationExpiresAt = snapshot.stationExpiresAtMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(snapshot.stationExpiresAtMs!);
    _answers
      ..clear()
      ..addAll(snapshot.answers);
    _submittedStationCodes
      ..clear()
      ..addAll(snapshot.submittedStationCodes);
    _clearError();

    final stage = JourneyStage.values.firstWhere(
      (s) => s.name == snapshot.stageName,
      orElse: () => JourneyStage.groupSetup,
    );

    if (stage == JourneyStage.joinSession) {
      _stage = JourneyStage.groupSetup;
      notifyListeners();
      return true;
    }

    if (stage == JourneyStage.groupSetup ||
        stage == JourneyStage.onboarding ||
        stage == JourneyStage.investigating ||
        stage == JourneyStage.conclusion ||
        stage == JourneyStage.stations ||
        stage == JourneyStage.results) {
      _stage = stage;
      // Rebuild submitted conclusion object from draft when resuming POS/results.
      final draft = conclusionDraft;
      if (draft != null &&
          !draft.isEmpty &&
          (stage == JourneyStage.stations || stage == JourneyStage.results)) {
        final fields = [
          draft.sampleAIdentity,
          draft.sampleAReasoning,
          draft.sampleBIdentity,
          draft.sampleBReasoning,
          draft.hypothesis,
        ];
        if (fields.every((f) => f.trim().isNotEmpty)) {
          conclusion = Conclusion(
            sampleAIdentity: draft.sampleAIdentity.trim(),
            sampleAReasoning: draft.sampleAReasoning.trim(),
            sampleBIdentity: draft.sampleBIdentity.trim(),
            sampleBReasoning: draft.sampleBReasoning.trim(),
            hypothesis: draft.hypothesis.trim(),
          );
        }
      }
      // If a station timer already expired while the app was closed, lock it.
      if (stage == JourneyStage.stations &&
          _activeStationUnlocked &&
          (stationRemainingSeconds ?? 0) <= 0) {
        submitActiveStation(expired: true);
        return true;
      }
      notifyListeners();
      return true;
    }

    if (_group != null && _leaderName != null) {
      _stage = JourneyStage.investigating;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Builds a durable snapshot of the current session/group, or null when the
  /// student has not joined yet.
  SessionSnapshot? toSessionSnapshot() {
    final code = _joinCode;
    final sid = _sessionId;
    final group = _group;
    if (code == null || sid == null || group == null) return null;

    final persistStage = switch (_stage) {
      JourneyStage.deviceCheck || JourneyStage.joinSession =>
        JourneyStage.groupSetup,
      _ => _stage,
    };

    return SessionSnapshot(
      stageName: persistStage.name,
      arSupported: _arSupported,
      joinCode: code,
      sessionId: sid,
      sessionTitle: sessionTitle ?? content.sessionTitle,
      group: group,
      remoteSessionId: _remoteSessionId,
      remoteGroupId: _remoteGroupId,
      missionIndex: _missionIndex,
      missionProgress: {
        for (final e in _missionProgress.entries)
          e.key: MissionProgressSnapshot(
            status: e.value.status.name,
            startedAtMs: e.value.startedAt?.millisecondsSinceEpoch,
            completedAtMs: e.value.completedAt?.millisecondsSinceEpoch,
          ),
      },
      sequenceStepIndex: sequenceStepIndex,
      sequenceCompleted: sequenceCompleted,
      logbookByMission: {
        for (final e in logbookByMission.entries) e.key: Map.of(e.value),
      },
      inspectedOrganelleHotspots: inspectedOrganelleHotspots.toList(
        growable: false,
      ),
      conclusionDraft: conclusionDraft,
      stationIndex: _stationIndex,
      activeStationUnlocked: _activeStationUnlocked,
      answers: Map.of(_answers),
      submittedStationCodes: _submittedStationCodes.toList(growable: false),
      stationExpiresAtMs: _stationExpiresAt?.millisecondsSinceEpoch,
    );
  }

  /// Optional onboarding exit — Scene 1 AR init without starting a mission.
  void finishOnboarding() {
    _clearError();
    sequenceStepIndex = null;
    sequenceCompleted = false;
    _transition(JourneyStage.investigating);
  }

  /// Marks Scene 1 lab placement complete → all three missions `available`.
  ///
  /// Does not start Misi 1. No-op before a group exists.
  void markLabPlaced() {
    if (_group == null) return;
    _labPlaced = true;
    final unlocked = MissionProgressMap.allAvailable(_missionProgress);
    _missionProgress
      ..clear()
      ..addAll(unlocked);
    _clearError();
    notifyListeners();
  }

  /// Starts a mission from a matched student intent (first valid → startedAt).
  ///
  /// Re-running a completed mission keeps [MissionProgress.completedAt] (write-once)
  /// and does not flip status away from completed.
  void startMissionFromIntent(int missionNumber) {
    if (missionNumber < 1 || missionNumber > content.missions.length) return;
    if (_group == null) return;

    final key = MissionProgress.keyFor(missionNumber);
    final existing = _missionProgress[key];

    // Already completed: allow observation re-run without duplicating completedAt.
    if (existing?.status == MissionStatus.completed) {
      _missionIndex = missionNumber - 1;
      sequenceStepIndex = null;
      sequenceCompleted = false;
      notifyListeners();
      return;
    }

    if (existing?.status == MissionStatus.running) {
      _missionIndex = missionNumber - 1;
      notifyListeners();
      return;
    }

    final now = DateTime.now();
    _missionProgress[key] = MissionProgress(
      status: MissionStatus.running,
      startedAt: existing?.startedAt ?? now,
      completedAt: existing?.completedAt,
    );
    _missionIndex = missionNumber - 1;
    sequenceStepIndex = null;
    sequenceCompleted = false;
    _clearError();
    notifyListeners();
  }

  /// Marks a mission completed after AR action + AI response succeed.
  ///
  /// Write-once [MissionProgress.completedAt] — re-runs keep the original.
  void completeMissionObservation(int missionNumber) {
    if (missionNumber < 1 || missionNumber > content.missions.length) return;
    final key = MissionProgress.keyFor(missionNumber);
    final existing = _missionProgress[key];
    if (existing?.status == MissionStatus.completed) {
      // Preserve completedAt; do not rewrite.
      notifyListeners();
      return;
    }

    final now = DateTime.now();
    _missionProgress[key] = MissionProgress(
      status: MissionStatus.completed,
      startedAt: existing?.startedAt ?? now,
      completedAt: existing?.completedAt ?? now,
    );
    _missionIndex = missionNumber - 1;
    sequenceCompleted = true;
    _clearError();
    notifyListeners();
  }

  /// Unknown / off-topic intents must not mutate the progress map.
  void ignoreIntentForProgress() {
    // Explicit no-op for call-site clarity in mission_screen.
  }

  /// Records sequence progress for the active mission (local autosave).
  void saveSequenceProgress({int? stepIndex, required bool completed}) {
    sequenceStepIndex = stepIndex;
    sequenceCompleted = completed;
    notifyListeners();
  }

  /// Records logbook entries for the active mission (autosaved locally + sync).
  void saveLogbook(Map<String, String> entries) {
    logbookByMission[activeMission.code] = Map.of(entries);
    _sync.enqueueLogbook(journey: this, entries: entries);
    notifyListeners();
  }

  /// Persists Sample A organelle inspection (observation only — not mission done).
  void saveInspectedOrganelleHotspots(Iterable<String> ids) {
    inspectedOrganelleHotspots
      ..clear()
      ..addAll(ids);
    notifyListeners();
  }

  /// Completes the focused mission observation (intent-driven, not linear).
  ///
  /// When all three missions are completed, advances to conclusion. Otherwise
  /// stays on Scene 1 so another intent can start a different mission.
  void completeActiveMission() {
    if (_stage != JourneyStage.investigating) return;
    final number = _missionIndex + 1;
    completeMissionObservation(number);
    if (allMissionsCompleted) {
      _transition(JourneyStage.conclusion);
    } else {
      sequenceStepIndex = null;
      sequenceCompleted = false;
      notifyListeners();
    }
  }

  /// Test helper: mark lab placed, complete M1–M3, enter conclusion.
  ///
  /// Prefer this over looping [completeActiveMission] — that no longer advances
  /// a linear counter and would hang if called in a `while (investigating)`.
  @visibleForTesting
  void debugCompleteAllMissionsToConclusion() {
    if (_group == null) return;
    markLabPlaced();
    for (var i = 1; i <= content.missions.length; i++) {
      startMissionFromIntent(i);
      completeMissionObservation(i);
    }
    if (_stage == JourneyStage.investigating && allMissionsCompleted) {
      _transition(JourneyStage.conclusion);
    }
  }

  /// Autosaves conclusion draft fields without submitting.
  void saveConclusionDraft(ConclusionDraft draft) {
    conclusionDraft = draft;
    _sync.enqueueConclusion(journey: this, draft: draft, submitted: false);
    notifyListeners();
  }

  /// Submits the group conclusion. All fields are required before moving on.
  void submitInvestigation({
    required String sampleAIdentity,
    required String sampleAReasoning,
    required String sampleBIdentity,
    required String sampleBReasoning,
    required String hypothesis,
  }) {
    final fields = [
      sampleAIdentity,
      sampleAReasoning,
      sampleBIdentity,
      sampleBReasoning,
      hypothesis,
    ];
    if (fields.any((field) => field.trim().isEmpty)) {
      _fail('Lengkapi semua field kesimpulan sebelum submit.');
      return;
    }
    conclusion = Conclusion(
      sampleAIdentity: sampleAIdentity.trim(),
      sampleAReasoning: sampleAReasoning.trim(),
      sampleBIdentity: sampleBIdentity.trim(),
      sampleBReasoning: sampleBReasoning.trim(),
      hypothesis: hypothesis.trim(),
    );
    final draft = ConclusionDraft.fromConclusion(conclusion!);
    conclusionDraft = draft;
    _sync.enqueueConclusion(journey: this, draft: draft, submitted: true);
    _clearError();
    _stationIndex = 0;
    _activeStationUnlocked = false;
    _stationExpiresAt = null;
    _submittedStationCodes.clear();
    _transition(JourneyStage.stations);
  }

  Conclusion? conclusion;

  /// Attempts to unlock the active station with [pin]. Returns whether it
  /// matched. Marker scanning falls back to this PIN entry (FR-092).
  bool unlockStation(String pin) {
    if (_stage != JourneyStage.stations) return false;
    if (isStationSubmitted(activeStation.code)) {
      _fail('Stasiun ini sudah dikumpulkan.');
      return false;
    }
    if (pin.trim() == activeStation.pin) {
      _beginStationAttempt();
      return true;
    }
    _fail('PIN stasiun salah.');
    return false;
  }

  /// Unlocks via scanned/simulated marker code (FR-091). On mismatch, the UI
  /// should fall back to [unlockStation] PIN entry (FR-092).
  bool unlockStationByMarker(String markerCode) {
    if (_stage != JourneyStage.stations) return false;
    if (isStationSubmitted(activeStation.code)) {
      _fail('Stasiun ini sudah dikumpulkan.');
      return false;
    }
    final expected = activeStation.resolvedMarkerCode;
    if (markerCode.trim().toUpperCase() == expected.toUpperCase()) {
      _beginStationAttempt();
      return true;
    }
    _fail(
      'Marker tidak cocok untuk ${activeStation.code}. '
      'Gunakan PIN sebagai cadangan.',
    );
    return false;
  }

  /// Simulates a successful marker scan for the active station (offline MVP).
  bool simulateMarkerScan() =>
      unlockStationByMarker(activeStation.resolvedMarkerCode);

  void _beginStationAttempt() {
    _activeStationUnlocked = true;
    _stationExpiresAt = DateTime.now().add(
      Duration(seconds: content.stationDurationSeconds),
    );
    _clearError();
    _stationSync.enqueueStationStart(journey: this);
    notifyListeners();
  }

  /// Autosaves an answer for a question in the active (unlocked) station.
  void answerQuestion(String questionCode, String answer) {
    if (!_activeStationUnlocked) {
      _fail('Buka stasiun dengan marker atau PIN terlebih dahulu.');
      return;
    }
    if (isStationSubmitted(activeStation.code)) {
      _fail('Jawaban stasiun ini sudah terkunci.');
      return;
    }
    _answers[questionCode] = answer;
    _stationSync.enqueueAnswer(
      journey: this,
      questionCode: questionCode,
      answerText: answer,
    );
    _clearError();
    notifyListeners();
  }

  /// Submits the active station and advances; after the last one, shows
  /// results. When [expired] is true the attempt is marked expired (FR-096).
  void submitActiveStation({bool expired = false}) {
    if (_stage != JourneyStage.stations || !_activeStationUnlocked) return;
    final station = activeStation;
    _submittedStationCodes.add(station.code);
    _stationSync.enqueueStationSubmit(
      journey: this,
      station: station,
      expired: expired,
    );
    _activeStationUnlocked = false;
    _stationExpiresAt = null;

    if (_stationIndex < content.stations.length - 1) {
      _stationIndex++;
      notifyListeners();
    } else {
      _transition(JourneyStage.results);
    }
  }

  /// Auto-scored total across objective questions only. Essays await teacher
  /// review and never contribute to this local total.
  int get objectiveScore {
    var total = 0;
    for (final station in content.stations) {
      for (final question in station.questions) {
        if (question.kind != QuestionKind.objective) continue;
        final score = _scoring.scoreAnswer(
          question: ScoringQuestion(
            id: question.code,
            type: QuestionType.objective,
            maxScore: question.maxScore,
            correctAnswer: question.correctAnswer,
          ),
          answerText: _answers[question.code] ?? '',
        );
        total += score.suggestedScore.round();
      }
    }
    return total;
  }

  /// Whether any essay answer still needs teacher review.
  bool get pendingTeacherReview => content.stations.any(
    (station) => station.questions.any((q) => q.kind == QuestionKind.essay),
  );

  String? answerFor(String questionCode) => _answers[questionCode];

  void _transition(JourneyStage next) {
    _stage = next;
    notifyListeners();
  }

  /// Surfaces a controlled UI error without changing stage.
  void reportError(String message) => _fail(message);

  void clearError() {
    if (_lastError == null) return;
    _clearError();
    notifyListeners();
  }

  void _fail(String message) {
    _lastError = message;
    notifyListeners();
  }

  void _clearError() => _lastError = null;
}

/// Immutable snapshot of a submitted group conclusion.
@immutable
class Conclusion {
  const Conclusion({
    required this.sampleAIdentity,
    required this.sampleAReasoning,
    required this.sampleBIdentity,
    required this.sampleBReasoning,
    required this.hypothesis,
  });

  final String sampleAIdentity;
  final String sampleAReasoning;
  final String sampleBIdentity;
  final String sampleBReasoning;
  final String hypothesis;
}
