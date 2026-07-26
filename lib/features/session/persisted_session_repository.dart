import 'package:cell_forensic/core/database/local_store.dart';
import 'package:cell_forensic/domain/entities.dart';
import 'package:cell_forensic/features/session/in_memory_session_repository.dart';
import 'package:cell_forensic/features/session/session_repository.dart';

/// Table keys used by [PersistedSessionRepository].
const String kSessionsTable = 'learning_sessions';
const String kGroupsTable = 'groups';

/// [SessionRepository] that mirrors every mutation into [LocalDatabase].
///
/// On construction it hydrates from the durable backend (so a process relaunch
/// restores prior session/group rows) and seeds any missing [seedSessions]
/// (typically the local CELL01 content-pack session).
class PersistedSessionRepository implements SessionRepository {
  PersistedSessionRepository({
    required LocalDatabase database,
    Iterable<LearningSession> seedSessions = const [],
  }) : _db = database {
    final loadedSessions = <LearningSession>[];
    final loadedGroups = <Group>[];

    for (final row in _db.readTable(kSessionsTable).values) {
      loadedSessions.add(LearningSession.fromJson(row));
    }
    for (final row in _db.readTable(kGroupsTable).values) {
      loadedGroups.add(Group.fromJson(row));
    }

    final knownCodes = {
      for (final s in loadedSessions) s.joinCode.trim().toUpperCase(),
    };
    final seedsToAdd = seedSessions.where(
      (s) => !knownCodes.contains(s.joinCode.trim().toUpperCase()),
    );

    _inner = InMemorySessionRepository(
      sessions: [...loadedSessions, ...seedsToAdd],
      groups: loadedGroups,
      onChanged: _persist,
    );
    // Ensure seeds land on disk even when the store was empty.
    _persist();
  }

  final LocalDatabase _db;
  late final InMemorySessionRepository _inner;

  /// Underlying mutable store (tests / remote upsert helpers).
  InMemorySessionRepository get inner => _inner;

  void _persist() {
    _db.transaction((txn) {
      for (final session in _inner.sessions) {
        txn.put(kSessionsTable, session.id, session.toJson());
      }
      // Replace groups table contents so deletes stay consistent.
      final existing = txn.readTable(kGroupsTable);
      for (final id in existing.keys.toList()) {
        txn.delete(kGroupsTable, id);
      }
      for (final group in _inner.allGroups) {
        txn.put(kGroupsTable, group.id, group.toJson());
      }
      return null;
    });
  }

  /// Registers a session discovered remotely so later offline joins succeed.
  void upsertSession(LearningSession session) => _inner.upsertSession(session);

  @override
  Future<Result<LearningSession>> joinSession(String joinCode) =>
      _inner.joinSession(joinCode);

  @override
  Future<List<Group>> groupsForSession(String sessionId) =>
      _inner.groupsForSession(sessionId);

  @override
  Future<Result<Group>> group(String groupId) => _inner.group(groupId);

  @override
  Future<Result<Group>> createGroup({
    required String sessionId,
    required String name,
    required String leaderName,
  }) => _inner.createGroup(
    sessionId: sessionId,
    name: name,
    leaderName: leaderName,
  );

  @override
  Future<Result<Group>> addMember({
    required String groupId,
    required String displayName,
  }) => _inner.addMember(groupId: groupId, displayName: displayName);

  @override
  Future<Result<Group>> removeMember({
    required String groupId,
    required String memberId,
  }) => _inner.removeMember(groupId: groupId, memberId: memberId);

  @override
  Future<Result<Group>> promoteMember({
    required String groupId,
    required String memberId,
  }) => _inner.promoteMember(groupId: groupId, memberId: memberId);
}
