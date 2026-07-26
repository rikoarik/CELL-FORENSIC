import 'package:cell_forensic/domain/entities.dart';
import 'package:cell_forensic/features/session/session_repository.dart';

/// In-memory [SessionRepository] used for offline-first behaviour and tests.
///
/// State lives in mutable maps/lists so writes can be read back within the same
/// instance, simulating persistence without a real backend. No external
/// dependencies are used; identifiers are generated with simple counters to keep
/// behaviour deterministic.
///
/// Optional [onChanged] lets a durable wrapper (e.g. [PersistedSessionRepository])
/// flush state after each successful mutation.
class InMemorySessionRepository implements SessionRepository {
  InMemorySessionRepository({
    Iterable<LearningSession> sessions = const [],
    Iterable<Group> groups = const [],
    this.onChanged,
  }) {
    for (final session in sessions) {
      _sessionsById[session.id] = session;
      _sessionsByCode[_normalizeJoinCode(session.joinCode)] = session;
    }
    _groups.addAll(groups);
    _groupCounter = _maxNumericSuffix(_groups.map((g) => g.id), 'group-');
    _memberCounter = _maxNumericSuffix(
      _groups.expand((g) => g.members.map((m) => m.id)),
      'member-',
    );
  }

  /// Invoked after a successful write so callers can persist.
  final void Function()? onChanged;

  final Map<String, LearningSession> _sessionsById = {};
  final Map<String, LearningSession> _sessionsByCode = {};
  final List<Group> _groups = [];

  int _groupCounter = 0;
  int _memberCounter = 0;

  /// All known sessions (for persistence).
  List<LearningSession> get sessions =>
      _sessionsById.values.toList(growable: false);

  /// All known groups (for persistence).
  List<Group> get allGroups => List.unmodifiable(_groups);

  /// Registers or replaces a session (used when a remote lookup succeeds).
  void upsertSession(LearningSession session) {
    _sessionsById[session.id] = session;
    _sessionsByCode[_normalizeJoinCode(session.joinCode)] = session;
    onChanged?.call();
  }

  static int _maxNumericSuffix(Iterable<String> ids, String prefix) {
    var max = 0;
    for (final id in ids) {
      if (!id.startsWith(prefix)) continue;
      final parsed = int.tryParse(id.substring(prefix.length));
      if (parsed != null && parsed > max) max = parsed;
    }
    return max;
  }

  static String _normalizeJoinCode(String raw) => raw.trim().toUpperCase();

  @override
  Future<Result<LearningSession>> joinSession(String joinCode) async {
    final normalized = _normalizeJoinCode(joinCode);
    final session = _sessionsByCode[normalized];
    if (normalized.isEmpty || session == null) {
      return const Err(SessionError.invalidJoinCode);
    }
    if (session.status != SessionStatus.active) {
      return const Err(SessionError.invalidJoinCode);
    }
    return Ok(session);
  }

  @override
  Future<List<Group>> groupsForSession(String sessionId) async {
    return _groups
        .where((group) => group.sessionId == sessionId)
        .toList(growable: false);
  }

  @override
  Future<Result<Group>> group(String groupId) async {
    final index = _indexOfGroup(groupId);
    if (index == -1) return const Err(SessionError.groupNotFound);
    return Ok(_groups[index]);
  }

  @override
  Future<Result<Group>> createGroup({
    required String sessionId,
    required String name,
    required String leaderName,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return const Err(SessionError.emptyGroupName);

    final trimmedLeader = leaderName.trim();
    if (trimmedLeader.isEmpty) return const Err(SessionError.emptyMemberName);

    final nameKey = trimmedName.toLowerCase();
    final duplicate = _groups.any(
      (group) =>
          group.sessionId == sessionId && group.name.toLowerCase() == nameKey,
    );
    if (duplicate) return const Err(SessionError.duplicateGroupName);

    final leader = GroupMember(
      id: 'member-${++_memberCounter}',
      displayName: trimmedLeader,
      isLeader: true,
    );
    final group = Group(
      id: 'group-${++_groupCounter}',
      sessionId: sessionId,
      name: trimmedName,
      members: [leader],
    );
    _groups.add(group);
    onChanged?.call();
    return Ok(group);
  }

  @override
  Future<Result<Group>> addMember({
    required String groupId,
    required String displayName,
  }) async {
    final index = _indexOfGroup(groupId);
    if (index == -1) return const Err(SessionError.groupNotFound);

    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return const Err(SessionError.emptyMemberName);

    final current = _groups[index];
    final member = GroupMember(
      id: 'member-${++_memberCounter}',
      displayName: trimmed,
      isLeader: false,
    );
    final updated = _withMembers(current, [...current.members, member]);
    _groups[index] = updated;
    onChanged?.call();
    return Ok(updated);
  }

  @override
  Future<Result<Group>> removeMember({
    required String groupId,
    required String memberId,
  }) async {
    final index = _indexOfGroup(groupId);
    if (index == -1) return const Err(SessionError.groupNotFound);

    final current = _groups[index];
    final member = current.members.cast<GroupMember?>().firstWhere(
      (m) => m!.id == memberId,
      orElse: () => null,
    );
    if (member == null) return const Err(SessionError.memberNotFound);

    if (member.isLeader && current.members.length > 1) {
      return const Err(SessionError.cannotRemoveLeader);
    }

    final remaining = current.members
        .where((m) => m.id != memberId)
        .toList(growable: false);
    final updated = _withMembers(current, remaining);
    _groups[index] = updated;
    onChanged?.call();
    return Ok(updated);
  }

  @override
  Future<Result<Group>> promoteMember({
    required String groupId,
    required String memberId,
  }) async {
    final index = _indexOfGroup(groupId);
    if (index == -1) return const Err(SessionError.groupNotFound);

    final current = _groups[index];
    final exists = current.members.any((m) => m.id == memberId);
    if (!exists) return const Err(SessionError.memberNotFound);

    final promoted = current.members
        .map(
          (m) => GroupMember(
            id: m.id,
            displayName: m.displayName,
            isLeader: m.id == memberId,
          ),
        )
        .toList(growable: false);
    final updated = _withMembers(current, promoted);
    _groups[index] = updated;
    onChanged?.call();
    return Ok(updated);
  }

  int _indexOfGroup(String groupId) =>
      _groups.indexWhere((group) => group.id == groupId);

  Group _withMembers(Group group, List<GroupMember> members) => Group(
    id: group.id,
    sessionId: group.sessionId,
    name: group.name,
    members: members,
  );
}
