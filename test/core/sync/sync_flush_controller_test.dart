import 'package:cell_forensic/core/database/local_store.dart';
import 'package:cell_forensic/core/sync/sync_flush_controller.dart';
import 'package:cell_forensic/core/sync/sync_operation.dart';
import 'package:cell_forensic/core/sync/sync_queue.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _CountingRemote implements RemoteSyncClient {
  int pushCount = 0;

  @override
  Future<void> push(SyncOperation operation) async {
    pushCount++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('flushNow drains due operations when canFlush is true', () async {
    final remote = _CountingRemote();
    final queue = SyncQueue(
      database: LocalDatabase(InMemoryStorageBackend()),
      remote: remote,
    );
    queue.enqueue(
      idempotencyKey: 'k1',
      entityType: 'observation_records',
      entityId: 'o1',
      opType: SyncOpType.update,
      payload: {'id': 'o1', 'version': 1},
      baseVersion: 0,
    );

    final flush = SyncFlushController(
      syncQueue: queue,
      canFlush: () => true,
      interval: const Duration(hours: 1),
    );

    await flush.flushNow();
    expect(remote.pushCount, 1);
    expect(queue.operations().single.status, SyncStatus.done);
  });

  test('flushNow is no-op when canFlush is false (offline)', () async {
    final remote = _CountingRemote();
    final queue = SyncQueue(
      database: LocalDatabase(InMemoryStorageBackend()),
      remote: remote,
    );
    queue.enqueue(
      idempotencyKey: 'k1',
      entityType: 'observation_records',
      entityId: 'o1',
      opType: SyncOpType.update,
      payload: {'id': 'o1', 'version': 1},
      baseVersion: 0,
    );

    final flush = SyncFlushController(
      syncQueue: queue,
      canFlush: () => false,
    );

    await flush.flushNow();
    expect(remote.pushCount, 0);
    expect(queue.operations().single.status, SyncStatus.pending);
  });

  test('app resume schedules a flush', () async {
    final remote = _CountingRemote();
    final queue = SyncQueue(
      database: LocalDatabase(InMemoryStorageBackend()),
      remote: remote,
    );
    queue.enqueue(
      idempotencyKey: 'k1',
      entityType: 'observation_records',
      entityId: 'o1',
      opType: SyncOpType.update,
      payload: {'id': 'o1', 'version': 1},
      baseVersion: 0,
    );

    final flush = SyncFlushController(
      syncQueue: queue,
      canFlush: () => true,
      interval: const Duration(hours: 1),
    )..start();

    flush.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);

    expect(remote.pushCount, greaterThanOrEqualTo(1));
    flush.stop();
  });
}
