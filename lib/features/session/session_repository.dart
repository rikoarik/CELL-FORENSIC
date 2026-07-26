import 'package:cell_forensic/domain/entities.dart';
import 'package:cell_forensic/features/session/session_result.dart';

export 'package:cell_forensic/features/session/session_result.dart';

/// Contract for joining learning sessions and managing groups/members.
///
/// Implementations own persistence. The default runtime implementation is
/// [InMemorySessionRepository] which simulates offline persistence by keeping
/// mutable state in memory so writes can be read back.
abstract class SessionRepository {
  /// Resolves a session from a [joinCode].
  ///
  /// The code is normalised (trimmed + upper-cased) before matching. An unknown
  /// code returns [SessionError.invalidJoinCode] without leaking whether any
  /// session exists.
  Future<Result<LearningSession>> joinSession(String joinCode);

  /// Returns all groups belonging to [sessionId] (empty when none).
  Future<List<Group>> groupsForSession(String sessionId);

  /// Looks up a single group by [groupId].
  Future<Result<Group>> group(String groupId);

  /// Creates a group with a single leader member.
  ///
  /// [name] must be non-empty within the session (case-insensitive uniqueness)
  /// and [leaderName] must be non-empty. The created leader is flagged
  /// automatically.
  Future<Result<Group>> createGroup({
    required String sessionId,
    required String name,
    required String leaderName,
  });

  /// Adds a non-leader member to [groupId].
  Future<Result<Group>> addMember({
    required String groupId,
    required String displayName,
  });

  /// Removes [memberId] from [groupId].
  ///
  /// Removing the current leader while other members remain fails with
  /// [SessionError.cannotRemoveLeader].
  Future<Result<Group>> removeMember({
    required String groupId,
    required String memberId,
  });

  /// Promotes [memberId] to leader, demoting the previous leader so exactly one
  /// leader remains.
  Future<Result<Group>> promoteMember({
    required String groupId,
    required String memberId,
  });
}
