/// Offline-first sync queue built on the pure-Dart [LocalDatabase].
///
/// The queue guarantees:
///  * atomic local-write + enqueue (one logical transaction),
///  * idempotent enqueue and idempotent remote success (replays are no-ops),
///  * bounded exponential backoff that separates retryable from permanent
///    failures, and
///  * versioned upsert so a stale [SyncOperation.baseVersion] never clobbers a
///    newer local value (it is marked [SyncStatus.conflict] instead).
///
/// Durability is delegated to the injected [StorageBackend]; "reopening" the
/// queue means constructing a new [SyncQueue] over the same backend.
library;

import 'dart:math';

import 'package:cell_forensic/core/database/local_store.dart';
import 'package:cell_forensic/core/sync/sync_operation.dart';

/// A failure returned by the remote when pushing an operation.
///
/// [retryable] failures (e.g. network blips, 5xx) are rescheduled with backoff;
/// non-retryable failures (e.g. validation, 4xx) fail the operation permanently.
class RemoteFailure implements Exception {
  const RemoteFailure(this.message, {required this.retryable});

  final String message;
  final bool retryable;

  @override
  String toString() =>
      'RemoteFailure(${retryable ? 'retryable' : 'permanent'}): $message';
}

/// The remote transport the queue pushes operations to.
///
/// Implementations should be idempotent on [SyncOperation.idempotencyKey] so a
/// replay never produces a second server-side side effect.
abstract class RemoteSyncClient {
  Future<void> push(SyncOperation operation);
}

/// Supplies the current time; injected so retry scheduling is deterministic.
typedef Clock = DateTime Function();

/// Table name under which queued operations are persisted.
const String kSyncQueueTable = 'sync_queue';

class SyncQueue {
  SyncQueue({
    required LocalDatabase database,
    required RemoteSyncClient remote,
    Clock? clock,
    int maxAttempts = 5,
    Duration baseBackoff = const Duration(seconds: 1),
    Duration maxBackoff = const Duration(minutes: 5),
    String Function()? idGenerator,
  }) : _db = database,
       _remote = remote,
       _clock = clock ?? DateTime.now,
       _maxAttempts = maxAttempts,
       _baseBackoff = baseBackoff,
       _maxBackoff = maxBackoff,
       _newId = idGenerator ?? _defaultUuidV4;

  final LocalDatabase _db;
  final RemoteSyncClient _remote;
  final Clock _clock;
  final int _maxAttempts;
  final Duration _baseBackoff;
  final Duration _maxBackoff;
  final String Function() _newId;

  /// Enqueues a change and applies its versioned local write atomically.
  ///
  /// Replaying an already-seen [idempotencyKey] returns the existing operation
  /// without touching storage. A stale [baseVersion] is recorded as a
  /// [SyncStatus.conflict] and does not overwrite the newer local value.
  SyncOperation enqueue({
    required String idempotencyKey,
    required String entityType,
    required String entityId,
    required SyncOpType opType,
    required Map<String, Object?> payload,
    required int baseVersion,
  }) {
    final existing = _findByIdempotencyKey(idempotencyKey);
    if (existing != null) return existing;

    return _db.transaction((txn) {
      final current = txn.get(entityType, entityId);
      final currentVersion = current == null ? 0 : current['version']! as int;
      final isConflict = current != null && baseVersion < currentVersion;

      final operation = SyncOperation(
        operationId: _newId(),
        idempotencyKey: idempotencyKey,
        entityType: entityType,
        entityId: entityId,
        opType: opType,
        payload: payload,
        baseVersion: baseVersion,
        status: isConflict ? SyncStatus.conflict : SyncStatus.pending,
        lastError: isConflict
            ? 'version conflict: base $baseVersion < current $currentVersion'
            : null,
      );

      if (!isConflict) {
        txn.put(entityType, entityId, {
          'id': entityId,
          'version': baseVersion + 1,
          'payload': payload,
        });
      }
      txn.put(kSyncQueueTable, operation.operationId, operation.toJson());
      return operation;
    });
  }

  /// All queued operations, in insertion order.
  List<SyncOperation> operations() => _db
      .readTable(kSyncQueueTable)
      .values
      .map(SyncOperation.fromJson)
      .toList(growable: false);

  /// Operations that are pending and whose retry time (if any) has arrived.
  List<SyncOperation> dueOperations() {
    final now = _clock();
    return operations()
        .where((op) => op.status == SyncStatus.pending && _isDue(op, now))
        .toList(growable: false);
  }

  /// The locally stored, versioned record for an entity, or `null`.
  Json? entity(String entityType, String entityId) =>
      _db.read(entityType, entityId);

  /// Pushes every currently-due operation once, applying success/backoff rules.
  Future<void> processDue() async {
    for (final op in dueOperations()) {
      await _process(op);
    }
  }

  Future<void> _process(SyncOperation op) async {
    _save(op.copyWith(status: SyncStatus.inFlight));
    try {
      await _remote.push(op);
      _save(
        op.copyWith(
          status: SyncStatus.done,
          attemptCount: op.attemptCount,
          nextRetryAt: null,
          lastError: null,
        ),
      );
    } on RemoteFailure catch (failure) {
      final attempt = op.attemptCount + 1;
      if (!failure.retryable || attempt >= _maxAttempts) {
        _save(
          op.copyWith(
            status: SyncStatus.failed,
            attemptCount: attempt,
            nextRetryAt: null,
            lastError: failure.message,
          ),
        );
      } else {
        _save(
          op.copyWith(
            status: SyncStatus.pending,
            attemptCount: attempt,
            nextRetryAt: _clock().add(_backoffFor(attempt)),
            lastError: failure.message,
          ),
        );
      }
    }
  }

  bool _isDue(SyncOperation op, DateTime now) {
    final at = op.nextRetryAt;
    return at == null || !at.isAfter(now);
  }

  Duration _backoffFor(int attempt) {
    // Exponential (base * 2^(attempt-1)) capped at [_maxBackoff].
    final shift = (attempt - 1).clamp(0, 30);
    final scaled = _baseBackoff.inMilliseconds * (1 << shift);
    final capped = min(scaled, _maxBackoff.inMilliseconds);
    return Duration(milliseconds: capped);
  }

  SyncOperation? _findByIdempotencyKey(String key) {
    for (final op in operations()) {
      if (op.idempotencyKey == key) return op;
    }
    return null;
  }

  void _save(SyncOperation op) {
    _db.transaction((txn) {
      txn.put(kSyncQueueTable, op.operationId, op.toJson());
      return null;
    });
  }
}

/// Minimal, dependency-free RFC-4122 v4 UUID generator.
String _defaultUuidV4() {
  final rng = Random();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int start, int end) {
    final buffer = StringBuffer();
    for (var i = start; i < end; i++) {
      buffer.write(bytes[i].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
