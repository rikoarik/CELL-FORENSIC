import 'package:cell_forensic/core/supabase/supabase_config.dart';
import 'package:cell_forensic/domain/entities.dart';
import 'package:cell_forensic/domain/scoring/scoring_engine.dart';
import 'package:cell_forensic/features/dashboard/dashboard_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Snapshot for the teacher dashboard session overview (E6-01).
class DashboardSessionSnapshot {
  const DashboardSessionSnapshot({
    required this.session,
    required this.groups,
    this.pendingReviewCount = 0,
  });

  final LearningSession session;
  final List<Group> groups;

  /// Essay / provisional answers still awaiting teacher score across the session.
  final int pendingReviewCount;
}

/// Loads teacher sessions, group detail, reviews, and export rows (E6 / E9).
abstract class DashboardSessionRepository {
  /// Sessions owned by the signed-in teacher (draft / active / closed).
  Future<List<DashboardSessionSnapshot>> loadActiveSessions();

  Future<DashboardGroupDetail> loadGroupDetail({
    required String sessionId,
    required String groupId,
  });

  /// Persists teacher score + optional feedback with optimistic concurrency.
  Future<void> saveTeacherReview({
    required String answerId,
    required num teacherScore,
    String? feedback,
    required int baseVersion,
  });

  Future<List<DashboardExportRow>> loadExportRows(String sessionId);

  /// Creates a learning session owned by the authenticated teacher.
  Future<LearningSession> createSession({
    required String title,
    required String joinCode,
    required String contentVersionId,
    required int stationDurationSeconds,
    SessionStatus status = SessionStatus.draft,
  });

  /// Activates or closes a session (locks student writes when not active).
  Future<LearningSession> updateSessionStatus({
    required String sessionId,
    required SessionStatus status,
  });

  /// Published content versions available when creating a session.
  Future<List<ContentVersionOption>> loadContentVersions();
}

class ContentVersionOption {
  const ContentVersionOption({
    required this.id,
    required this.versionCode,
  });

  final String id;
  final String versionCode;
}

class SupabaseDashboardSessionRepository implements DashboardSessionRepository {
  const SupabaseDashboardSessionRepository({
    this.scoringEngine = const ScoringEngine(),
  });

  final ScoringEngine scoringEngine;

  static const _sessionColumns =
      'id, title, join_code, content_version_id, status, '
      'station_duration_seconds, teacher_id';

  /// E10: answer keys / rubrics require authenticated teacher JWT (anon
  /// cannot SELECT `questions.correct_answer` / `rubric`).
  SupabaseClient _requireTeacherClient() {
    final client = SupabaseConfig.clientOrNull;
    if (client == null) {
      throw StateError('Supabase belum dikonfigurasi');
    }
    if (client.auth.currentUser == null) {
      throw StateError(
        'Guru harus login untuk memuat kunci jawaban / penilaian '
        '(kolom correct_answer & rubric tidak tersedia untuk anon).',
      );
    }
    return client;
  }

  @override
  Future<List<DashboardSessionSnapshot>> loadActiveSessions() async {
    final client = SupabaseConfig.clientOrNull;
    if (client == null) return const [];

    final uid = client.auth.currentUser?.id;
    if (uid == null) return const [];

    final role = await _currentRole(client, uid);
    final isAdmin = role == 'admin';

    // RLS also exposes every *active* session (E7 residual). Dashboard scopes
    // to owned rows (+ unowned active demos as read-only) so teachers do not
    // operate on another teacher's classroom. Admins see all visible rows.
    final rows = await client
        .from('learning_sessions')
        .select(_sessionColumns)
        .order('created_at', ascending: false);

    final snapshots = <DashboardSessionSnapshot>[];
    for (final row in rows as List) {
      final map = Map<String, Object?>.from(row as Map);
      final session = LearningSession.fromJson(map);
      if (!_isDashboardVisible(session, uid: uid, isAdmin: isAdmin)) {
        continue;
      }
      final groupRows = await client
          .from('groups')
          .select(
            'id, session_id, name, group_members(id, display_name, is_leader)',
          )
          .eq('session_id', session.id);

      final groups = <Group>[];
      var pending = 0;
      for (final g in groupRows as List) {
        final gm = Map<String, Object?>.from(g as Map);
        final membersRaw = (gm['group_members'] as List?) ?? const [];
        final members = membersRaw
            .map(
              (m) => GroupMember.fromJson(
                Map<String, Object?>.from(m as Map),
              ),
            )
            .toList(growable: false);
        final group = Group(
          id: gm['id']! as String,
          sessionId: gm['session_id']! as String,
          name: gm['name']! as String,
          members: members,
        );
        groups.add(group);
        pending += await _countPendingReviews(group.id);
      }
      snapshots.add(
        DashboardSessionSnapshot(
          session: session,
          groups: groups,
          pendingReviewCount: pending,
        ),
      );
    }
    return snapshots;
  }

  Future<String?> _currentRole(SupabaseClient client, String uid) async {
    final row = await client
        .from('profiles')
        .select('role')
        .eq('id', uid)
        .maybeSingle();
    if (row == null) return null;
    return Map<String, Object?>.from(row)['role'] as String?;
  }

  /// Owned sessions (any status), unowned active demos, or everything for admin.
  static bool _isDashboardVisible(
    LearningSession session, {
    required String uid,
    required bool isAdmin,
  }) {
    if (isAdmin) return true;
    if (session.teacherId == uid) return true;
    return session.teacherId == null &&
        session.status == SessionStatus.active;
  }

  Future<int> _countPendingReviews(String groupId) async {
    // E10: scoring uses questions.correct_answer — teacher JWT required.
    final client = _requireTeacherClient();

    final answerRows = await client
        .from('answers')
        .select(
          'answer_text, teacher_score, auto_score, '
          'questions(id, question_type, correct_answer, max_score)',
        )
        .eq('group_id', groupId);

    var count = 0;
    for (final row in answerRows as List) {
      final map = Map<String, Object?>.from(row as Map);
      final q = Map<String, Object?>.from(
        (map['questions'] as Map?) ?? const {},
      );
      final type = DashboardQuestionMeta.mapDbType(
        q['question_type'] as String?,
      );
      final score = scoringEngine.scoreAnswer(
        question: ScoringQuestion(
          id: (q['id'] as String?) ?? '',
          type: type,
          maxScore: (q['max_score'] as num?) ?? 0,
          correctAnswer: DashboardQuestionMeta.extractCorrectAnswer(
            q['correct_answer'],
          ),
        ),
        answerText: (map['answer_text'] as String?) ?? '',
        teacherScore: map['teacher_score'] as num?,
        aiSuggestedScore: map['auto_score'] as num?,
      );
      if (score.requiresTeacherReview && score.teacherScore == null) {
        count += 1;
      }
    }
    return count;
  }

  @override
  Future<DashboardGroupDetail> loadGroupDetail({
    required String sessionId,
    required String groupId,
  }) async {
    final client = _requireTeacherClient();

    final sessionRow = await client
        .from('learning_sessions')
        .select(_sessionColumns)
        .eq('id', sessionId)
        .maybeSingle();
    if (sessionRow == null) {
      throw StateError('Sesi tidak ditemukan');
    }
    final session = LearningSession.fromJson(
      Map<String, Object?>.from(sessionRow),
    );

    final groupRow = await client
        .from('groups')
        .select(
          'id, session_id, name, group_members(id, display_name, is_leader)',
        )
        .eq('id', groupId)
        .eq('session_id', sessionId)
        .maybeSingle();
    if (groupRow == null) {
      throw StateError('Kelompok tidak ditemukan');
    }
    final gm = Map<String, Object?>.from(groupRow);
    final membersRaw = (gm['group_members'] as List?) ?? const [];
    final group = Group(
      id: gm['id']! as String,
      sessionId: gm['session_id']! as String,
      name: gm['name']! as String,
      members: membersRaw
          .map(
            (m) => GroupMember.fromJson(Map<String, Object?>.from(m as Map)),
          )
          .toList(growable: false),
    );

    final progressRows = await client
        .from('mission_progress')
        .select('status, ar_mode, missions(code, title)')
        .eq('group_id', groupId);

    final missionProgress = <DashboardMissionProgress>[];
    for (final row in progressRows as List) {
      final map = Map<String, Object?>.from(row as Map);
      final mission = Map<String, Object?>.from(
        (map['missions'] as Map?) ?? const {},
      );
      missionProgress.add(
        DashboardMissionProgress(
          missionCode: (mission['code'] as String?) ?? '—',
          missionTitle: (mission['title'] as String?) ?? 'Misi',
          status: (map['status'] as String?) ?? 'not_started',
          arMode: (map['ar_mode'] as String?) ?? 'arcore',
        ),
      );
    }

    final conclusionRow = await client
        .from('investigation_conclusions')
        .select(
          'status, sample_a_identity, sample_a_reasoning, '
          'sample_b_identity, sample_b_reasoning, group_hypothesis',
        )
        .eq('group_id', groupId)
        .maybeSingle();

    DashboardConclusion? conclusion;
    if (conclusionRow != null) {
      final c = Map<String, Object?>.from(conclusionRow);
      conclusion = DashboardConclusion(
        status: (c['status'] as String?) ?? 'draft',
        sampleAIdentity: (c['sample_a_identity'] as String?) ?? '',
        sampleAReasoning: (c['sample_a_reasoning'] as String?) ?? '',
        sampleBIdentity: (c['sample_b_identity'] as String?) ?? '',
        sampleBReasoning: (c['sample_b_reasoning'] as String?) ?? '',
        groupHypothesis: (c['group_hypothesis'] as String?) ?? '',
      );
    }

    final answerRows = await client
        .from('answers')
        .select(
          'id, group_id, answer_text, auto_score, teacher_score, final_score, '
          'feedback, version, '
          'questions(id, code, question_text, question_type, correct_answer, '
          'rubric, max_score, evaluation_stations(code, title))',
        )
        .eq('group_id', groupId)
        .order('updated_at', ascending: true);

    final answers = <DashboardAnswerReview>[];
    for (final row in answerRows as List) {
      answers.add(_mapAnswerReview(Map<String, Object?>.from(row as Map)));
    }

    return DashboardGroupDetail(
      session: session,
      group: group,
      missionProgress: missionProgress,
      answers: answers,
      conclusion: conclusion,
    );
  }

  DashboardAnswerReview _mapAnswerReview(Map<String, Object?> map) {
    final qRaw = Map<String, Object?>.from(
      (map['questions'] as Map?) ?? const {},
    );
    final stationRaw = Map<String, Object?>.from(
      (qRaw['evaluation_stations'] as Map?) ?? const {},
    );
    final type = DashboardQuestionMeta.mapDbType(
      qRaw['question_type'] as String?,
    );
    final maxScore = (qRaw['max_score'] as num?) ?? 0;
    final question = DashboardQuestionMeta(
      id: (qRaw['id'] as String?) ?? (map['question_id'] as String?) ?? '',
      code: (qRaw['code'] as String?) ?? '',
      text: (qRaw['question_text'] as String?) ?? '',
      type: type,
      maxScore: maxScore,
      correctAnswer: DashboardQuestionMeta.extractCorrectAnswer(
        qRaw['correct_answer'],
      ),
      rubric: DashboardQuestionMeta.extractRubric(qRaw['rubric']),
      stationCode: (stationRaw['code'] as String?) ?? '',
      stationTitle: (stationRaw['title'] as String?) ?? '',
    );

    final answerText = (map['answer_text'] as String?) ?? '';
    final teacherScore = map['teacher_score'] as num?;
    final storedAuto = map['auto_score'] as num?;
    final score = scoringEngine.scoreAnswer(
      question: question.toScoringQuestion(),
      answerText: answerText,
      teacherScore: teacherScore,
      aiSuggestedScore: storedAuto,
    );

    return DashboardAnswerReview(
      answerId: map['id']! as String,
      groupId: map['group_id']! as String,
      question: question,
      answerText: answerText,
      storedAutoScore: storedAuto,
      storedTeacherScore: teacherScore,
      storedFinalScore: map['final_score'] as num?,
      feedback: map['feedback'] as String?,
      version: (map['version'] as num?)?.toInt() ?? 1,
      score: score,
    );
  }

  @override
  Future<void> saveTeacherReview({
    required String answerId,
    required num teacherScore,
    String? feedback,
    required int baseVersion,
  }) async {
    final client = _requireTeacherClient();

    // Prefer a versioned update; empty result means stale version OR RLS deny
    // (E9: only session owner/admin may review). Distinguish via a plain read.
    final updated = await client
        .from('answers')
        .update({
          'teacher_score': teacherScore,
          'final_score': teacherScore,
          'feedback': feedback,
          'version': baseVersion + 1,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', answerId)
        .eq('version', baseVersion)
        .select('id');

    if ((updated as List).isNotEmpty) return;

    final existing = await client
        .from('answers')
        .select('id, version')
        .eq('id', answerId)
        .maybeSingle();
    if (existing == null) {
      throw StateError(
        'Gagal menyimpan penilaian — jawaban tidak ditemukan atau '
        'Anda bukan pemilik sesi (kebijakan RLS guru).',
      );
    }
    final currentVersion =
        (Map<String, Object?>.from(existing)['version'] as num?)?.toInt();
    if (currentVersion != null && currentVersion != baseVersion) {
      throw StateError(
        'Gagal menyimpan penilaian — data sudah diubah (konflik versi). '
        'Muat ulang lalu coba lagi.',
      );
    }
    throw StateError(
      'Gagal menyimpan penilaian — tidak diizinkan mengubah jawaban sesi ini. '
      'Pastikan Anda pemilik sesi atau admin.',
    );
  }

  @override
  Future<LearningSession> createSession({
    required String title,
    required String joinCode,
    required String contentVersionId,
    required int stationDurationSeconds,
    SessionStatus status = SessionStatus.draft,
  }) async {
    final client = SupabaseConfig.clientOrNull;
    if (client == null) {
      throw StateError('Supabase belum dikonfigurasi');
    }
    final uid = client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Guru harus login untuk membuat sesi.');
    }

    final code = joinCode.trim().toUpperCase();
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty || code.isEmpty) {
      throw StateError('Judul dan kode gabung wajib diisi.');
    }
    if (stationDurationSeconds < 30 || stationDurationSeconds > 7200) {
      throw StateError('Durasi stasiun harus antara 30–7200 detik.');
    }

    final statusName = status == SessionStatus.unknown
        ? SessionStatus.draft.name
        : status.name;

    final row = await client
        .from('learning_sessions')
        .insert({
          'teacher_id': uid,
          'content_version_id': contentVersionId,
          'title': trimmedTitle,
          'join_code': code,
          'status': statusName,
          'station_duration_seconds': stationDurationSeconds,
        })
        .select(_sessionColumns)
        .single();

    return LearningSession.fromJson(Map<String, Object?>.from(row));
  }

  @override
  Future<LearningSession> updateSessionStatus({
    required String sessionId,
    required SessionStatus status,
  }) async {
    final client = SupabaseConfig.clientOrNull;
    if (client == null) {
      throw StateError('Supabase belum dikonfigurasi');
    }
    if (status != SessionStatus.active && status != SessionStatus.closed) {
      throw StateError('Status hanya boleh active atau closed.');
    }

    final row = await client
        .from('learning_sessions')
        .update({'status': status.name})
        .eq('id', sessionId)
        .select(_sessionColumns)
        .maybeSingle();

    if (row == null) {
      throw StateError(
        'Gagal mengubah status sesi. Pastikan Anda pemilik sesi '
        '(teacher_id) atau admin — sesi demo tanpa pemilik tidak bisa diubah.',
      );
    }
    return LearningSession.fromJson(Map<String, Object?>.from(row));
  }

  @override
  Future<List<ContentVersionOption>> loadContentVersions() async {
    final client = SupabaseConfig.clientOrNull;
    if (client == null) return const [];

    final rows = await client
        .from('content_versions')
        .select('id, version_code')
        .eq('status', 'published')
        .order('created_at', ascending: false);

    return (rows as List)
        .map((row) {
          final map = Map<String, Object?>.from(row as Map);
          return ContentVersionOption(
            id: map['id']! as String,
            versionCode: (map['version_code'] as String?) ?? '—',
          );
        })
        .toList(growable: false);
  }

  @override
  Future<List<DashboardExportRow>> loadExportRows(String sessionId) async {
    // E10: export joins questions.correct_answer / rubric — teacher JWT required.
    final client = _requireTeacherClient();

    final sessionRow = await client
        .from('learning_sessions')
        .select(_sessionColumns)
        .eq('id', sessionId)
        .maybeSingle();
    if (sessionRow == null) return const [];

    final session = LearningSession.fromJson(
      Map<String, Object?>.from(sessionRow),
    );

    final groupRows = await client
        .from('groups')
        .select(
          'id, session_id, name, group_members(id, display_name, is_leader)',
        )
        .eq('session_id', sessionId);

    final rows = <DashboardExportRow>[];
    for (final g in groupRows as List) {
      final gm = Map<String, Object?>.from(g as Map);
      final membersRaw = (gm['group_members'] as List?) ?? const [];
      final members = membersRaw
          .map(
            (m) => GroupMember.fromJson(Map<String, Object?>.from(m as Map)),
          )
          .toList(growable: false);
      final group = Group(
        id: gm['id']! as String,
        sessionId: gm['session_id']! as String,
        name: gm['name']! as String,
        members: members,
      );
      final memberNames =
          members.map((m) => m.displayName).join('; ');

      final answerRows = await client
          .from('answers')
          .select(
            'id, group_id, answer_text, auto_score, teacher_score, final_score, '
            'feedback, version, '
            'questions(id, code, question_text, question_type, correct_answer, '
            'rubric, max_score, evaluation_stations(code, title))',
          )
          .eq('group_id', group.id);

      if ((answerRows as List).isEmpty) {
        rows.add(
          DashboardExportRow(
            sessionJoinCode: session.joinCode,
            sessionTitle: session.title,
            groupName: group.name,
            memberNames: memberNames,
            questionCode: '',
            questionType: '',
            stationCode: '',
            answerText: '',
            autoScore: null,
            teacherScore: null,
            finalScore: null,
            requiresReview: false,
            feedback: '',
          ),
        );
        continue;
      }

      for (final row in answerRows) {
        final review = _mapAnswerReview(Map<String, Object?>.from(row as Map));
        rows.add(
          DashboardExportRow(
            sessionJoinCode: session.joinCode,
            sessionTitle: session.title,
            groupName: group.name,
            memberNames: memberNames,
            questionCode: review.question.code,
            questionType: review.question.type.name,
            stationCode: review.question.stationCode,
            answerText: review.answerText,
            autoScore: review.score.suggestedScore,
            teacherScore: review.score.teacherScore,
            finalScore: review.score.finalScore,
            requiresReview: review.needsReview,
            feedback: review.feedback ?? '',
          ),
        );
      }
    }
    return rows;
  }
}

/// Deterministic fake for widget/unit tests.
class FakeDashboardSessionRepository implements DashboardSessionRepository {
  FakeDashboardSessionRepository([
    this.snapshots = const [],
    Map<String, DashboardGroupDetail>? groupDetails,
    List<DashboardExportRow>? exportRows,
    List<ContentVersionOption>? contentVersions,
  ])  : groupDetails = groupDetails ?? {},
        exportRows = exportRows ?? const [],
        contentVersions = contentVersions ??
            const [
              ContentVersionOption(
                id: 'c1',
                versionCode: 'v1-demo',
              ),
            ];

  List<DashboardSessionSnapshot> snapshots;
  final Map<String, DashboardGroupDetail> groupDetails;
  List<DashboardExportRow> exportRows;
  List<ContentVersionOption> contentVersions;

  /// Owner id stamped on [createSession] (matches fake auth teacher id).
  String actingTeacherId = 't1';

  /// When set, [saveTeacherReview] throws (simulates RLS / conflict).
  StateError? reviewError;

  final List<TeacherReviewCall> reviewCalls = [];
  final List<LearningSession> createdSessions = [];
  final List<({String sessionId, SessionStatus status})> statusUpdates = [];

  @override
  Future<List<DashboardSessionSnapshot>> loadActiveSessions() async =>
      snapshots;

  @override
  Future<DashboardGroupDetail> loadGroupDetail({
    required String sessionId,
    required String groupId,
  }) async {
    final detail = groupDetails[groupId];
    if (detail == null) {
      throw StateError('Kelompok $groupId tidak ada di fake repo');
    }
    return detail;
  }

  @override
  Future<void> saveTeacherReview({
    required String answerId,
    required num teacherScore,
    String? feedback,
    required int baseVersion,
  }) async {
    if (reviewError != null) throw reviewError!;
    reviewCalls.add(
      TeacherReviewCall(
        answerId: answerId,
        teacherScore: teacherScore,
        feedback: feedback,
        baseVersion: baseVersion,
      ),
    );

    for (final entry in groupDetails.entries) {
      final detail = entry.value;
      final updated = detail.answers.map((a) {
        if (a.answerId != answerId) return a;
        final score = const ScoringEngine().scoreAnswer(
          question: a.question.toScoringQuestion(),
          answerText: a.answerText,
          teacherScore: teacherScore,
          aiSuggestedScore: a.storedAutoScore,
        );
        return DashboardAnswerReview(
          answerId: a.answerId,
          groupId: a.groupId,
          question: a.question,
          answerText: a.answerText,
          storedAutoScore: a.storedAutoScore,
          storedTeacherScore: teacherScore,
          storedFinalScore: teacherScore,
          feedback: feedback,
          version: baseVersion + 1,
          score: score,
        );
      }).toList(growable: false);

      groupDetails[entry.key] = DashboardGroupDetail(
        session: detail.session,
        group: detail.group,
        missionProgress: detail.missionProgress,
        answers: updated,
        conclusion: detail.conclusion,
      );
    }
  }

  @override
  Future<List<DashboardExportRow>> loadExportRows(String sessionId) async {
    final match = snapshots.where((s) => s.session.id == sessionId);
    if (match.isEmpty) return List<DashboardExportRow>.from(exportRows);
    final joinCode = match.first.session.joinCode;
    return exportRows
        .where((r) => r.sessionJoinCode == joinCode)
        .toList(growable: false);
  }

  @override
  Future<LearningSession> createSession({
    required String title,
    required String joinCode,
    required String contentVersionId,
    required int stationDurationSeconds,
    SessionStatus status = SessionStatus.draft,
  }) async {
    final session = LearningSession(
      id: 'created-${createdSessions.length + 1}',
      joinCode: joinCode.trim().toUpperCase(),
      contentVersionId: contentVersionId,
      status: status,
      stationDurationSeconds: stationDurationSeconds,
      title: title.trim(),
      teacherId: actingTeacherId,
    );
    createdSessions.add(session);
    snapshots = [
      ...snapshots,
      DashboardSessionSnapshot(session: session, groups: const []),
    ];
    return session;
  }

  @override
  Future<LearningSession> updateSessionStatus({
    required String sessionId,
    required SessionStatus status,
  }) async {
    statusUpdates.add((sessionId: sessionId, status: status));
    final updated = <DashboardSessionSnapshot>[];
    LearningSession? found;
    for (final snap in snapshots) {
      if (snap.session.id != sessionId) {
        updated.add(snap);
        continue;
      }
      final session = LearningSession(
        id: snap.session.id,
        joinCode: snap.session.joinCode,
        contentVersionId: snap.session.contentVersionId,
        status: status,
        stationDurationSeconds: snap.session.stationDurationSeconds,
        title: snap.session.title,
        teacherId: snap.session.teacherId,
      );
      found = session;
      updated.add(
        DashboardSessionSnapshot(
          session: session,
          groups: snap.groups,
          pendingReviewCount: snap.pendingReviewCount,
        ),
      );
    }
    snapshots = updated;
    if (found == null) {
      throw StateError('Sesi $sessionId tidak ada di fake repo');
    }
    return found;
  }

  @override
  Future<List<ContentVersionOption>> loadContentVersions() async =>
      contentVersions;
}

class TeacherReviewCall {
  const TeacherReviewCall({
    required this.answerId,
    required this.teacherScore,
    required this.feedback,
    required this.baseVersion,
  });

  final String answerId;
  final num teacherScore;
  final String? feedback;
  final int baseVersion;
}
