import 'package:cell_forensic/core/database/local_store.dart';
import 'package:cell_forensic/core/sync/sync_operation.dart';
import 'package:cell_forensic/core/sync/sync_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime now;
  DateTime clock() => now;

  setUp(() => now = DateTime.utc(2026, 1, 1, 8));

  SyncQueue buildQueue(
    StorageBackend backend, {
    RemoteSyncClient? remote,
    int maxAttempts = 5,
    Duration baseBackoff = const Duration(seconds: 1),
    Duration maxBackoff = const Duration(minutes: 5),
  }) {
    var counter = 0;
    return SyncQueue(
      database: LocalDatabase(backend),
      remote: remote ?? _FakeRemote(),
      clock: clock,
      maxAttempts: maxAttempts,
      baseBackoff: baseBackoff,
      maxBackoff: maxBackoff,
      idGenerator: () => 'op-${++counter}',
    );
  }

  group('enqueue atomicity + local write', () {
    test('writes the entity and the operation in one logical transaction', () {
      final backend = InMemoryStorageBackend();
      final queue = buildQueue(backend);

      final op = queue.enqueue(
        idempotencyKey: 'k1',
        entityType: 'observation_records',
        entityId: 'o1',
        opType: SyncOpType.create,
        payload: {'detected_structure': 'kloroplas'},
        baseVersion: 0,
      );

      expect(op.status, SyncStatus.pending);
      expect(op.attemptCount, 0);

      final entity = queue.entity('observation_records', 'o1');
      expect(entity, isNotNull);
      expect(entity!['version'], 1);
      expect((entity['payload'] as Map)['detected_structure'], 'kloroplas');

      expect(queue.operations(), hasLength(1));
    });

    test('rolls back both entity and operation when the commit fails', () {
      final backend = _FaultyBackend();
      final queue = buildQueue(backend);

      backend.failOnCommit = true;
      expect(
        () => queue.enqueue(
          idempotencyKey: 'k1',
          entityType: 'answers',
          entityId: 'a1',
          opType: SyncOpType.create,
          payload: {'answer_text': 'sel tumbuhan'},
          baseVersion: 0,
        ),
        throwsA(isA<Exception>()),
      );

      backend.failOnCommit = false;
      expect(queue.entity('answers', 'a1'), isNull);
      expect(queue.operations(), isEmpty);
    });
  });

  group('idempotent enqueue', () {
    test('replaying the same idempotencyKey does not duplicate work', () {
      final backend = InMemoryStorageBackend();
      final queue = buildQueue(backend);

      final first = queue.enqueue(
        idempotencyKey: 'same-key',
        entityType: 'answers',
        entityId: 'a1',
        opType: SyncOpType.update,
        payload: {'answer_text': 'v1'},
        baseVersion: 0,
      );
      final second = queue.enqueue(
        idempotencyKey: 'same-key',
        entityType: 'answers',
        entityId: 'a1',
        opType: SyncOpType.update,
        payload: {'answer_text': 'v2-should-be-ignored'},
        baseVersion: 1,
      );

      expect(second.operationId, first.operationId);
      expect(queue.operations(), hasLength(1));
      // The entity keeps the first write; the replay had no side effect.
      final entity = queue.entity('answers', 'a1')!;
      expect(entity['version'], 1);
      expect((entity['payload'] as Map)['answer_text'], 'v1');
    });
  });

  group('conflict via versioned upsert', () {
    test('a stale baseVersion does not overwrite and is marked conflict', () {
      final backend = InMemoryStorageBackend();
      final queue = buildQueue(backend);

      // Current entity reaches version 2.
      queue.enqueue(
        idempotencyKey: 'k1',
        entityType: 'answers',
        entityId: 'a1',
        opType: SyncOpType.create,
        payload: {'answer_text': 'baru'},
        baseVersion: 0,
      );
      queue.enqueue(
        idempotencyKey: 'k2',
        entityType: 'answers',
        entityId: 'a1',
        opType: SyncOpType.update,
        payload: {'answer_text': 'update sah'},
        baseVersion: 1,
      );

      // A stale writer still believes it is editing version 0.
      final stale = queue.enqueue(
        idempotencyKey: 'k3-stale',
        entityType: 'answers',
        entityId: 'a1',
        opType: SyncOpType.update,
        payload: {'answer_text': 'tulisan basi'},
        baseVersion: 0,
      );

      expect(stale.status, SyncStatus.conflict);
      final entity = queue.entity('answers', 'a1')!;
      expect(entity['version'], 2);
      expect((entity['payload'] as Map)['answer_text'], 'update sah');
    });
  });

  group('remote success + idempotency', () {
    test('successful push marks the operation done', () async {
      final backend = InMemoryStorageBackend();
      final remote = _FakeRemote();
      final queue = buildQueue(backend, remote: remote);

      queue.enqueue(
        idempotencyKey: 'k1',
        entityType: 'answers',
        entityId: 'a1',
        opType: SyncOpType.create,
        payload: {'answer_text': 'x'},
        baseVersion: 0,
      );

      await queue.processDue();

      expect(queue.operations().single.status, SyncStatus.done);
      expect(remote.pushed, hasLength(1));
      expect(remote.sideEffects, 1);
    });

    test('a done operation is never re-sent on a later drain', () async {
      final backend = InMemoryStorageBackend();
      final remote = _FakeRemote();
      final queue = buildQueue(backend, remote: remote);

      queue.enqueue(
        idempotencyKey: 'k1',
        entityType: 'answers',
        entityId: 'a1',
        opType: SyncOpType.create,
        payload: {'answer_text': 'x'},
        baseVersion: 0,
      );

      await queue.processDue();
      await queue.processDue();

      expect(remote.pushed, hasLength(1));
      expect(remote.sideEffects, 1);
    });

    test('replaying the same idempotencyKey never pushes twice', () async {
      final backend = InMemoryStorageBackend();
      final remote = _FakeRemote();
      final queue = buildQueue(backend, remote: remote);

      queue.enqueue(
        idempotencyKey: 'dup',
        entityType: 'answers',
        entityId: 'a1',
        opType: SyncOpType.create,
        payload: {'answer_text': 'x'},
        baseVersion: 0,
      );
      queue.enqueue(
        idempotencyKey: 'dup',
        entityType: 'answers',
        entityId: 'a1',
        opType: SyncOpType.update,
        payload: {'answer_text': 'y'},
        baseVersion: 1,
      );

      await queue.processDue();
      await queue.processDue();

      expect(remote.pushed, hasLength(1));
      expect(remote.sideEffects, 1);
    });
  });

  group('retry with bounded exponential backoff', () {
    test(
      'a retryable failure reschedules with growing, capped delay',
      () async {
        final backend = InMemoryStorageBackend();
        final remote = _ScriptedRemote([
          _retryable, // attempt 1 fails
          _retryable, // attempt 2 fails
          _ok, // attempt 3 succeeds
        ]);
        final queue = buildQueue(
          backend,
          remote: remote,
          baseBackoff: const Duration(seconds: 1),
          maxBackoff: const Duration(seconds: 4),
          maxAttempts: 5,
        );

        queue.enqueue(
          idempotencyKey: 'k1',
          entityType: 'answers',
          entityId: 'a1',
          opType: SyncOpType.create,
          payload: {'answer_text': 'x'},
          baseVersion: 0,
        );

        // First drain: fails, stays pending, scheduled +1s.
        await queue.processDue();
        var op = queue.operations().single;
        expect(op.status, SyncStatus.pending);
        expect(op.attemptCount, 1);
        expect(op.nextRetryAt, now.add(const Duration(seconds: 1)));

        // Not due yet -> nothing happens.
        await queue.processDue();
        expect(queue.operations().single.attemptCount, 1);
        expect(remote.calls, 1);

        // Advance past the first backoff.
        now = now.add(const Duration(seconds: 1));
        await queue.processDue();
        op = queue.operations().single;
        expect(op.status, SyncStatus.pending);
        expect(op.attemptCount, 2);
        // Backoff doubles to 2s.
        expect(op.nextRetryAt, now.add(const Duration(seconds: 2)));

        // Advance and succeed.
        now = now.add(const Duration(seconds: 2));
        await queue.processDue();
        expect(queue.operations().single.status, SyncStatus.done);
        expect(remote.calls, 3);
      },
    );

    test('exhausting maxAttempts marks the operation failed', () async {
      final backend = InMemoryStorageBackend();
      final remote = _ScriptedRemote([_retryable, _retryable]);
      final queue = buildQueue(
        backend,
        remote: remote,
        baseBackoff: const Duration(seconds: 1),
        maxAttempts: 2,
      );

      queue.enqueue(
        idempotencyKey: 'k1',
        entityType: 'answers',
        entityId: 'a1',
        opType: SyncOpType.create,
        payload: {'answer_text': 'x'},
        baseVersion: 0,
      );

      await queue.processDue();
      now = now.add(const Duration(minutes: 10));
      await queue.processDue();

      final op = queue.operations().single;
      expect(op.status, SyncStatus.failed);
      expect(op.attemptCount, 2);
      expect(op.lastError, isNotNull);
    });
  });

  group('permanent failure', () {
    test('a non-retryable failure fails immediately without a retry', () async {
      final backend = InMemoryStorageBackend();
      final remote = _ScriptedRemote([_permanent]);
      final queue = buildQueue(backend, remote: remote);

      queue.enqueue(
        idempotencyKey: 'k1',
        entityType: 'answers',
        entityId: 'a1',
        opType: SyncOpType.create,
        payload: {'answer_text': 'x'},
        baseVersion: 0,
      );

      await queue.processDue();
      final op = queue.operations().single;
      expect(op.status, SyncStatus.failed);
      expect(op.attemptCount, 1);
      expect(op.nextRetryAt, isNull);

      // Even far in the future it is never retried.
      now = now.add(const Duration(days: 1));
      await queue.processDue();
      expect(remote.calls, 1);
    });
  });

  group('durability across reopen', () {
    test(
      'operations persist when the queue is reopened over the backend',
      () async {
        final backend = InMemoryStorageBackend();
        final first = buildQueue(backend);

        first.enqueue(
          idempotencyKey: 'k1',
          entityType: 'answers',
          entityId: 'a1',
          opType: SyncOpType.create,
          payload: {'answer_text': 'x'},
          baseVersion: 0,
        );

        // Reopen: a fresh queue over the same durable backend.
        final reopened = buildQueue(backend);
        expect(reopened.operations(), hasLength(1));
        expect(reopened.entity('answers', 'a1'), isNotNull);

        // The reopened queue still honours idempotency for the same key.
        reopened.enqueue(
          idempotencyKey: 'k1',
          entityType: 'answers',
          entityId: 'a1',
          opType: SyncOpType.update,
          payload: {'answer_text': 'again'},
          baseVersion: 1,
        );
        expect(reopened.operations(), hasLength(1));
      },
    );
  });
}

const _ok = null;
final _retryable = RemoteFailure('sementara', retryable: true);
final _permanent = RemoteFailure('permanen', retryable: false);

class _FakeRemote implements RemoteSyncClient {
  final List<SyncOperation> pushed = [];
  final Set<String> _seenKeys = {};
  int sideEffects = 0;

  @override
  Future<void> push(SyncOperation operation) async {
    pushed.add(operation);
    if (_seenKeys.add(operation.idempotencyKey)) {
      sideEffects++;
    }
  }
}

class _ScriptedRemote implements RemoteSyncClient {
  _ScriptedRemote(this._script);

  final List<Object?> _script;
  int calls = 0;
  final List<SyncOperation> pushed = [];

  @override
  Future<void> push(SyncOperation operation) async {
    pushed.add(operation);
    final behavior = calls < _script.length ? _script[calls] : _ok;
    calls++;
    if (behavior is RemoteFailure) {
      throw behavior;
    }
  }
}

class _FaultyBackend implements StorageBackend {
  final InMemoryStorageBackend _delegate = InMemoryStorageBackend();
  bool failOnCommit = false;

  @override
  Map<String, Map<String, Object?>> load(String table) => _delegate.load(table);

  @override
  Set<String> get tables => _delegate.tables;

  @override
  void commit(Map<String, Map<String, Map<String, Object?>>> staged) {
    if (failOnCommit) {
      throw Exception('disk failure');
    }
    _delegate.commit(staged);
  }
}
