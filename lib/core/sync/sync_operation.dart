/// The unit of work in the offline sync queue.
library;

import 'package:cell_forensic/core/database/local_store.dart';

/// The kind of mutation an operation represents against a remote entity.
enum SyncOpType {
  create,
  update,
  delete;

  static SyncOpType fromName(String value) =>
      SyncOpType.values.firstWhere((type) => type.name == value);
}

/// Lifecycle of a queued operation.
///
/// [pending] awaits a (re)send, [inFlight] is being pushed, [done] is confirmed
/// by the remote, [failed] is terminal (permanent error or exhausted retries),
/// and [conflict] means a stale [SyncOperation.baseVersion] lost a versioned
/// upsert and was intentionally not applied.
enum SyncStatus {
  pending,
  inFlight,
  done,
  failed,
  conflict;

  static SyncStatus fromName(String value) =>
      SyncStatus.values.firstWhere((status) => status.name == value);
}

/// An immutable record describing one queued change plus its sync bookkeeping.
class SyncOperation {
  const SyncOperation({
    required this.operationId,
    required this.idempotencyKey,
    required this.entityType,
    required this.entityId,
    required this.opType,
    required this.payload,
    required this.baseVersion,
    this.attemptCount = 0,
    this.nextRetryAt,
    this.status = SyncStatus.pending,
    this.lastError,
  });

  factory SyncOperation.fromJson(Json json) {
    final retryMillis = json['next_retry_at'] as int?;
    return SyncOperation(
      operationId: json['operation_id']! as String,
      idempotencyKey: json['idempotency_key']! as String,
      entityType: json['entity_type']! as String,
      entityId: json['entity_id']! as String,
      opType: SyncOpType.fromName(json['op_type']! as String),
      payload: (json['payload'] as Map? ?? const {}).cast<String, Object?>(),
      baseVersion: json['base_version']! as int,
      attemptCount: json['attempt_count']! as int,
      nextRetryAt: retryMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(retryMillis, isUtc: true),
      status: SyncStatus.fromName(json['status']! as String),
      lastError: json['last_error'] as String?,
    );
  }

  /// UUID string uniquely identifying this operation.
  final String operationId;

  /// Client-supplied key that makes the operation idempotent across replays.
  final String idempotencyKey;

  final String entityType;
  final String entityId;
  final SyncOpType opType;
  final Map<String, Object?> payload;

  /// The entity version the change was based on (optimistic concurrency).
  final int baseVersion;

  final int attemptCount;
  final DateTime? nextRetryAt;
  final SyncStatus status;
  final String? lastError;

  SyncOperation copyWith({
    int? attemptCount,
    Object? nextRetryAt = _unset,
    SyncStatus? status,
    Object? lastError = _unset,
  }) {
    return SyncOperation(
      operationId: operationId,
      idempotencyKey: idempotencyKey,
      entityType: entityType,
      entityId: entityId,
      opType: opType,
      payload: payload,
      baseVersion: baseVersion,
      attemptCount: attemptCount ?? this.attemptCount,
      nextRetryAt: nextRetryAt == _unset
          ? this.nextRetryAt
          : nextRetryAt as DateTime?,
      status: status ?? this.status,
      lastError: lastError == _unset ? this.lastError : lastError as String?,
    );
  }

  Json toJson() => {
    'operation_id': operationId,
    'idempotency_key': idempotencyKey,
    'entity_type': entityType,
    'entity_id': entityId,
    'op_type': opType.name,
    'payload': payload,
    'base_version': baseVersion,
    'attempt_count': attemptCount,
    'next_retry_at': nextRetryAt?.toUtc().millisecondsSinceEpoch,
    'status': status.name,
    'last_error': lastError,
  };
}

const Object _unset = Object();
