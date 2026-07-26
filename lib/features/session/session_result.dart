/// Controlled outcome types for the session feature.
///
/// Domain logic returns a [Result] instead of throwing so callers must handle
/// failures explicitly. Errors are modelled as a closed [SessionError] set that
/// never leaks internal session details (e.g. an invalid join code does not
/// reveal whether a session exists).
library;

/// Enumerates every controlled failure the session feature can surface.
enum SessionError {
  /// Provided join code did not match any active session.
  invalidJoinCode,

  /// Referenced session does not exist.
  sessionNotFound,

  /// Group name was empty after trimming.
  emptyGroupName,

  /// A group with the same (case-insensitive) name already exists in the
  /// session.
  duplicateGroupName,

  /// Referenced group does not exist.
  groupNotFound,

  /// Member display name was empty after trimming.
  emptyMemberName,

  /// Referenced member does not exist in the group.
  memberNotFound,

  /// The group leader cannot be removed while other members remain; promote a
  /// new leader first.
  cannotRemoveLeader;

  /// Human-readable, non-sensitive message for UI surfaces.
  String get message => switch (this) {
    SessionError.invalidJoinCode => 'Kode gabung tidak valid.',
    SessionError.sessionNotFound => 'Sesi tidak ditemukan.',
    SessionError.emptyGroupName => 'Nama kelompok wajib diisi.',
    SessionError.duplicateGroupName =>
      'Nama kelompok sudah digunakan di sesi ini.',
    SessionError.groupNotFound => 'Kelompok tidak ditemukan.',
    SessionError.emptyMemberName => 'Nama anggota wajib diisi.',
    SessionError.memberNotFound => 'Anggota tidak ditemukan.',
    SessionError.cannotRemoveLeader =>
      'Ketua tidak dapat dihapus. Tunjuk ketua baru terlebih dahulu.',
  };
}

/// A success-or-failure wrapper for session operations.
sealed class Result<T> {
  const Result();

  /// Whether this result represents a success.
  bool get isOk => this is Ok<T>;

  /// The success value, or `null` when this is an [Err].
  T? get valueOrNull => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>() => null,
  };

  /// The failure error, or `null` when this is an [Ok].
  SessionError? get errorOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(:final error) => error,
  };
}

/// A successful [Result] carrying a [value].
class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;
}

/// A failed [Result] carrying a controlled [error].
class Err<T> extends Result<T> {
  const Err(this.error);

  final SessionError error;
}
