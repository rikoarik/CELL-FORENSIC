import 'package:cell_forensic/core/supabase/supabase_config.dart';
import 'package:cell_forensic/domain/entities.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of registering a student group against a remote learning session.
class RemoteJoinResult {
  const RemoteJoinResult({
    required this.sessionId,
    required this.groupId,
    required this.sessionTitle,
    required this.joinCode,
  });

  final String sessionId;
  final String groupId;
  final String sessionTitle;
  final String joinCode;
}

/// Thin Supabase adapter for join-session (E2-01 / E1-04 / E9).
///
/// Returns null when Supabase is not configured or the network/query fails so
/// the journey can continue offline with the local content pack.
///
/// Group creation prefers `rpc('join_active_session')` (E7/E9). Direct table
/// inserts are no longer allowed for anon under tightened RLS.
class RemoteSessionService {
  const RemoteSessionService();

  SupabaseClient? get _client => SupabaseConfig.clientOrNull;

  /// Looks up an active remote session by [joinCode] without creating a group.
  Future<LearningSession?> findActiveSession(String joinCode) async {
    final client = _client;
    if (client == null) return null;

    final code = joinCode.trim().toUpperCase();
    if (code.isEmpty) return null;

    try {
      final session = await client
          .from('learning_sessions')
          .select(
            'id, title, join_code, status, content_version_id, '
            'station_duration_seconds',
          )
          .eq('join_code', code)
          .eq('status', 'active')
          .maybeSingle();

      if (session == null) return null;
      return LearningSession(
        id: session['id'] as String,
        joinCode: session['join_code'] as String? ?? code,
        contentVersionId:
            session['content_version_id'] as String? ?? 'local-content',
        status: SessionStatus.active,
        stationDurationSeconds:
            (session['station_duration_seconds'] as num?)?.toInt() ?? 300,
        title: session['title'] as String? ?? '',
      );
    } on PostgrestException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Looks up an active session by [joinCode] and creates group + leader via RPC.
  Future<RemoteJoinResult?> joinActiveSession({
    required String joinCode,
    required String groupName,
    required String leaderName,
  }) async {
    final client = _client;
    if (client == null) return null;

    final code = joinCode.trim().toUpperCase();
    final group = groupName.trim();
    final leader = leaderName.trim();
    if (code.isEmpty || group.isEmpty || leader.isEmpty) return null;

    try {
      final raw = await client.rpc(
        'join_active_session',
        params: {
          'p_join_code': code,
          'p_group_name': group,
          'p_leader_name': leader,
        },
      );

      final map = _asStringKeyedMap(raw);
      if (map == null) return null;

      final sessionId = _asUuidString(map['session_id']);
      final groupId = _asUuidString(map['group_id']);
      if (sessionId == null || groupId == null) return null;

      return RemoteJoinResult(
        sessionId: sessionId,
        groupId: groupId,
        sessionTitle: (map['session_title'] as String?) ?? 'Sesi',
        joinCode: (map['join_code'] as String?) ?? code,
      );
    } on PostgrestException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Resolves a published mission row id by content [code] (e.g. `MISI-1`).
  Future<String?> findPublishedMissionId(String code) =>
      _firstIdWhere(table: 'missions', code: code);

  /// Resolves a published evaluation station id by [code] (e.g. `POS-1`).
  Future<String?> findPublishedStationId(String code) =>
      _firstIdWhere(table: 'evaluation_stations', code: code);

  /// Resolves a published question id by [code] (e.g. `POS1-Q1`).
  Future<String?> findPublishedQuestionId(String code) =>
      _firstIdWhere(table: 'questions', code: code);

  Future<String?> _firstIdWhere({
    required String table,
    required String code,
  }) async {
    final client = _client;
    if (client == null) return null;
    final normalized = code.trim();
    if (normalized.isEmpty) return null;
    try {
      final rows = await client
          .from(table)
          .select('id')
          .eq('code', normalized)
          .limit(1);
      if (rows.isEmpty) return null;
      return _asUuidString(rows.first['id']);
    } on PostgrestException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Map<String, Object?>? _asStringKeyedMap(Object? raw) {
    if (raw is Map<String, Object?>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    // Some PostgREST encodings wrap jsonb as a single-element list.
    if (raw is List && raw.isNotEmpty) {
      return _asStringKeyedMap(raw.first);
    }
    return null;
  }

  String? _asUuidString(Object? value) {
    if (value is String && value.isNotEmpty) return value;
    if (value == null) return null;
    final text = value.toString();
    return text.isEmpty ? null : text;
  }
}
