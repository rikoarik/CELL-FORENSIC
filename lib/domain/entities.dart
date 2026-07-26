/// Shared domain models for mobile and dashboard.
///
/// Dart fields use camelCase; JSON maps to the snake_case shapes defined in
/// `docs/07_DATABASE_SCHEMA.md`. Mutable, syncable entities carry a [version]
/// to support optimistic-concurrency conflict detection.
library;

enum SessionStatus {
  draft,
  active,
  paused,
  closed,
  unknown;

  static SessionStatus fromName(String? value) {
    return SessionStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => SessionStatus.unknown,
    );
  }
}

class LearningSession {
  const LearningSession({
    required this.id,
    required this.joinCode,
    required this.contentVersionId,
    required this.status,
    required this.stationDurationSeconds,
    this.title = '',
    this.teacherId,
  });

  factory LearningSession.fromJson(Map<String, Object?> json) {
    return LearningSession(
      id: json['id']! as String,
      joinCode: json['join_code']! as String,
      contentVersionId: json['content_version_id']! as String,
      status: SessionStatus.fromName(json['status'] as String?),
      stationDurationSeconds: (json['station_duration_seconds'] as num).toInt(),
      title: (json['title'] as String?) ?? '',
      teacherId: json['teacher_id'] as String?,
    );
  }

  final String id;
  final String joinCode;
  final String contentVersionId;
  final SessionStatus status;
  final int stationDurationSeconds;
  final String title;

  /// Owning teacher profile id; null for demo seeds (e.g. CELL01).
  final String? teacherId;

  /// Whether [actorId] may mutate this session under E9 RLS
  /// (`teacher_id = auth.uid()` or admin).
  bool canBeManagedBy({required String actorId, required String actorRole}) {
    if (actorRole == 'admin') return true;
    final owner = teacherId;
    return owner != null && owner == actorId;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'join_code': joinCode,
    'content_version_id': contentVersionId,
    'status': status.name,
    'station_duration_seconds': stationDurationSeconds,
    if (title.isNotEmpty) 'title': title,
    if (teacherId != null) 'teacher_id': teacherId,
  };
}

class GroupMember {
  const GroupMember({
    required this.id,
    required this.displayName,
    required this.isLeader,
  });

  factory GroupMember.fromJson(Map<String, Object?> json) {
    return GroupMember(
      id: json['id']! as String,
      displayName: json['display_name']! as String,
      isLeader: json['is_leader']! as bool,
    );
  }

  final String id;
  final String displayName;
  final bool isLeader;

  Map<String, Object?> toJson() => {
    'id': id,
    'display_name': displayName,
    'is_leader': isLeader,
  };
}

class Group {
  const Group({
    required this.id,
    required this.sessionId,
    required this.name,
    required this.members,
  });

  factory Group.fromJson(Map<String, Object?> json) {
    final rawMembers = json['members'] as List<dynamic>? ?? const [];
    return Group(
      id: json['id']! as String,
      sessionId: json['session_id']! as String,
      name: json['name']! as String,
      members: rawMembers
          .map(
            (m) => GroupMember.fromJson(
              Map<String, Object?>.from(m as Map),
            ),
          )
          .toList(growable: false),
    );
  }

  final String id;
  final String sessionId;
  final String name;
  final List<GroupMember> members;

  Map<String, Object?> toJson() => {
    'id': id,
    'session_id': sessionId,
    'name': name,
    'members': members.map((member) => member.toJson()).toList(growable: false),
  };
}

class ObservationRecord {
  const ObservationRecord({
    required this.id,
    required this.groupId,
    required this.missionId,
    required this.sampleRef,
    required this.detectedStructure,
    required this.version,
  });

  factory ObservationRecord.fromJson(Map<String, Object?> json) {
    return ObservationRecord(
      id: json['id']! as String,
      groupId: json['group_id']! as String,
      missionId: json['mission_id']! as String,
      sampleRef: json['sample_ref']! as String,
      detectedStructure: json['detected_structure']! as String,
      version: json['version']! as int,
    );
  }

  final String id;
  final String groupId;
  final String missionId;
  final String sampleRef;
  final String detectedStructure;
  final int version;

  Map<String, Object?> toJson() => {
    'id': id,
    'group_id': groupId,
    'mission_id': missionId,
    'sample_ref': sampleRef,
    'detected_structure': detectedStructure,
    'version': version,
  };
}

class Answer {
  const Answer({
    required this.id,
    required this.groupId,
    required this.questionId,
    required this.stationAttemptId,
    required this.answerText,
    required this.autoScore,
    required this.teacherScore,
    required this.finalScore,
    required this.version,
  });

  factory Answer.fromJson(Map<String, Object?> json) {
    return Answer(
      id: json['id']! as String,
      groupId: json['group_id']! as String,
      questionId: json['question_id']! as String,
      stationAttemptId: json['station_attempt_id']! as String,
      answerText: json['answer_text']! as String,
      autoScore: json['auto_score'] as int?,
      teacherScore: json['teacher_score'] as int?,
      finalScore: json['final_score'] as int?,
      version: json['version']! as int,
    );
  }

  final String id;
  final String groupId;
  final String questionId;
  final String stationAttemptId;
  final String answerText;
  final int? autoScore;
  final int? teacherScore;
  final int? finalScore;
  final int version;

  Map<String, Object?> toJson() => {
    'id': id,
    'group_id': groupId,
    'question_id': questionId,
    'station_attempt_id': stationAttemptId,
    'answer_text': answerText,
    'auto_score': autoScore,
    'teacher_score': teacherScore,
    'final_score': finalScore,
    'version': version,
  };

  /// Columns students may write under E10 (no teacher score / feedback).
  Map<String, Object?> toStudentWriteJson() => {
    'id': id,
    'group_id': groupId,
    'question_id': questionId,
    'station_attempt_id': stationAttemptId,
    'answer_text': answerText,
    'auto_score': autoScore,
    'version': version,
  };
}
