import 'package:cell_forensic/domain/entities.dart';
import 'package:cell_forensic/features/session/session_repository.dart';
import 'package:flutter/foundation.dart';

/// Immutable snapshot of the session feature's UI state.
@immutable
class SessionState {
  const SessionState({
    this.session,
    this.groups = const [],
    this.isBusy = false,
    this.error,
  });

  /// The joined session, or `null` before a successful join.
  final LearningSession? session;

  /// Groups belonging to the joined session.
  final List<Group> groups;

  /// Whether a command is currently in flight.
  final bool isBusy;

  /// The most recent controlled error, cleared on the next successful command.
  final SessionError? error;

  /// Whether a session has been joined.
  bool get isJoined => session != null;

  SessionState copyWith({
    LearningSession? session,
    List<Group>? groups,
    bool? isBusy,
    SessionError? error,
    bool clearError = false,
  }) {
    return SessionState(
      session: session ?? this.session,
      groups: groups ?? this.groups,
      isBusy: isBusy ?? this.isBusy,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Coordinates session/group commands and exposes immutable [state].
///
/// The [SessionRepository] is injected via the constructor so tests can supply
/// an in-memory fake. State mutations flow through [_emit] which notifies
/// listeners.
class SessionViewModel extends ChangeNotifier {
  SessionViewModel({required SessionRepository repository})
    : _repository = repository;

  final SessionRepository _repository;

  SessionState _state = const SessionState();

  /// The current immutable state.
  SessionState get state => _state;

  /// Joins a session by [joinCode]. On success the joined session and its
  /// groups are loaded; on failure a controlled error is surfaced.
  Future<void> join(String joinCode) async {
    _emit(_state.copyWith(isBusy: true, clearError: true));
    final result = await _repository.joinSession(joinCode);
    switch (result) {
      case Ok(:final value):
        final groups = await _repository.groupsForSession(value.id);
        _emit(
          _state.copyWith(
            session: value,
            groups: groups,
            isBusy: false,
            clearError: true,
          ),
        );
      case Err(:final error):
        _emit(_state.copyWith(isBusy: false, error: error));
    }
  }

  /// Creates a group in the joined session, then refreshes group state.
  Future<void> createGroup({
    required String name,
    required String leaderName,
  }) async {
    await _mutateGroups(
      () => _repository.createGroup(
        sessionId: _requireSessionId(),
        name: name,
        leaderName: leaderName,
      ),
    );
  }

  /// Adds a non-leader member to [groupId].
  Future<void> addMember({
    required String groupId,
    required String displayName,
  }) async {
    await _mutateGroups(
      () => _repository.addMember(groupId: groupId, displayName: displayName),
    );
  }

  /// Removes [memberId] from [groupId].
  Future<void> removeMember({
    required String groupId,
    required String memberId,
  }) async {
    await _mutateGroups(
      () => _repository.removeMember(groupId: groupId, memberId: memberId),
    );
  }

  /// Promotes [memberId] to leader of [groupId].
  Future<void> promoteMember({
    required String groupId,
    required String memberId,
  }) async {
    await _mutateGroups(
      () => _repository.promoteMember(groupId: groupId, memberId: memberId),
    );
  }

  Future<void> _mutateGroups(Future<Result<Group>> Function() command) async {
    final session = _state.session;
    if (session == null) {
      _emit(_state.copyWith(error: SessionError.sessionNotFound));
      return;
    }

    _emit(_state.copyWith(isBusy: true, clearError: true));
    final result = await command();
    switch (result) {
      case Ok():
        final groups = await _repository.groupsForSession(session.id);
        _emit(_state.copyWith(groups: groups, isBusy: false, clearError: true));
      case Err(:final error):
        _emit(_state.copyWith(isBusy: false, error: error));
    }
  }

  String _requireSessionId() => _state.session!.id;

  void _emit(SessionState next) {
    _state = next;
    notifyListeners();
  }
}
