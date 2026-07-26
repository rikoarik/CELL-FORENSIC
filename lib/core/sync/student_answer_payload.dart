/// E10-safe answer payloads for anon / student sync.
///
/// Column privileges allow student INSERT/UPDATE of text + auto_score only —
/// never [teacher_score], [final_score], or [feedback].
abstract final class StudentAnswerPayload {
  static const teacherOnlyKeys = {
    'teacher_score',
    'final_score',
    'feedback',
  };

  /// Non-column / teacher-only keys that must never reach PostgREST as anon.
  static const strippedKeys = {
    ...teacherOnlyKeys,
    'question_code',
    'rubric',
    'correct_answer',
  };

  static const insertKeys = {
    'id',
    'group_id',
    'question_id',
    'station_attempt_id',
    'answer_text',
    'auto_score',
    'version',
    'updated_at',
  };

  static const updateKeys = {
    'answer_text',
    'auto_score',
    'station_attempt_id',
    'version',
    'updated_at',
  };

  /// Removes privileged / unknown keys from a sync queue payload.
  static Map<String, Object?> sanitize(Map<String, Object?> raw) {
    final out = <String, Object?>{};
    for (final entry in raw.entries) {
      if (strippedKeys.contains(entry.key)) continue;
      out[entry.key] = entry.value;
    }
    return out;
  }

  static Map<String, Object?> forInsert(Map<String, Object?> raw) {
    final sanitized = sanitize(raw);
    return {
      for (final key in insertKeys)
        if (sanitized.containsKey(key)) key: sanitized[key],
    };
  }

  static Map<String, Object?> forUpdate(Map<String, Object?> raw) {
    final sanitized = sanitize(raw);
    return {
      for (final key in updateKeys)
        if (sanitized.containsKey(key)) key: sanitized[key],
    };
  }
}
