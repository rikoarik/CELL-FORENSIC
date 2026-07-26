import 'package:cell_forensic/core/database/local_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('committed rows survive a reopen over the same backend', () {
    final backend = InMemoryStorageBackend();

    LocalDatabase(backend).transaction((txn) {
      txn.put('groups', 'g1', {
        'id': 'g1',
        'version': 1,
        'payload': {'name': 'Kelompok Mawar'},
      });
      return null;
    });

    // Reopen: a brand new database instance over the same durable backend.
    final reopened = LocalDatabase(backend);
    final row = reopened.read('groups', 'g1');

    expect(row, isNotNull);
    expect(row!['version'], 1);
    expect((row['payload'] as Map)['name'], 'Kelompok Mawar');
  });

  test('a throwing transaction commits nothing (all-or-nothing)', () {
    final backend = InMemoryStorageBackend();
    final db = LocalDatabase(backend);

    expect(
      () => db.transaction<void>((txn) {
        txn.put('groups', 'g1', {'id': 'g1', 'version': 1});
        txn.put('queue', 'op1', {'id': 'op1'});
        throw StateError('boom');
      }),
      throwsStateError,
    );

    expect(db.read('groups', 'g1'), isNull);
    expect(db.read('queue', 'op1'), isNull);
  });

  test('a backend that fails to commit rolls back every table', () {
    final backend = _FaultyBackend()..failOnCommit = true;
    final db = LocalDatabase(backend);

    expect(
      () => db.transaction<void>((txn) {
        txn.put('groups', 'g1', {'id': 'g1'});
        txn.put('queue', 'op1', {'id': 'op1'});
      }),
      throwsA(isA<Exception>()),
    );

    backend.failOnCommit = false;
    final reopened = LocalDatabase(backend);
    expect(reopened.read('groups', 'g1'), isNull);
    expect(reopened.read('queue', 'op1'), isNull);
  });

  test('stored rows are deep-copied so external mutation cannot leak in', () {
    final backend = InMemoryStorageBackend();
    final db = LocalDatabase(backend);

    final payload = <String, Object?>{'name': 'awal'};
    db.transaction((txn) {
      txn.put('groups', 'g1', {'id': 'g1', 'payload': payload});
      return null;
    });

    payload['name'] = 'diubah-di-luar';

    final row = db.read('groups', 'g1')!;
    expect((row['payload'] as Map)['name'], 'awal');
  });
}

/// Backend wrapper whose commit can be forced to fail, to exercise rollback.
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
