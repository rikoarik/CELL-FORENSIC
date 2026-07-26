/// Pure-Dart local persistence abstraction for Cell Forensic.
///
/// This is deliberately package-free: no `sqflite`/`isar`/`drift`. It models a
/// tiny document store with all-or-nothing transactions on top of an injectable
/// [StorageBackend], which stands in for durable disk storage. Because the
/// durable state lives in the backend, "reopening" the database is simply
/// constructing a new [LocalDatabase] over the same backend — the same contract
/// a SQLite file would give us, but testable without any native plugin.
library;

import 'dart:convert';

/// A single stored row as a JSON-compatible map.
typedef Json = Map<String, Object?>;

/// Durable storage seam. Implementations decide *where* bytes live; the
/// database layer decides *how* rows are transacted on top of them.
///
/// [commit] MUST be atomic across all supplied tables: either every staged
/// table is applied or none is (so a mid-write failure never leaves a partial
/// transaction on disk).
abstract class StorageBackend {
  /// Returns a fresh, owned copy of every row in [table] keyed by row id.
  Map<String, Json> load(String table);

  /// All table names that currently hold data.
  Set<String> get tables;

  /// Atomically replaces the contents of each table in [staged] with the given
  /// rows. Tables not present in [staged] are left untouched.
  void commit(Map<String, Map<String, Json>> staged);
}

/// In-memory [StorageBackend] that simulates durability by serializing rows.
///
/// Serialization gives us two things a real file-backed store would provide:
/// deep isolation (callers cannot mutate stored rows by keeping a reference)
/// and an all-or-nothing [commit] (encoding happens before any table is
/// swapped in, so an encoding error aborts the whole commit).
class InMemoryStorageBackend implements StorageBackend {
  final Map<String, String> _tables = {};

  @override
  Map<String, Json> load(String table) {
    final raw = _tables[table];
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, Object?>;
    return decoded.map(
      (id, row) => MapEntry(id, (row as Map).cast<String, Object?>()),
    );
  }

  @override
  Set<String> get tables => _tables.keys.toSet();

  @override
  void commit(Map<String, Map<String, Json>> staged) {
    // Phase 1: encode everything (may throw) without mutating live state.
    final encoded = <String, String>{};
    staged.forEach((table, rows) {
      encoded[table] = jsonEncode(rows);
    });
    // Phase 2: apply — pure assignment, cannot fail partway.
    encoded.forEach((table, rows) {
      _tables[table] = rows;
    });
  }
}

/// A document database offering snapshot-isolated, all-or-nothing transactions.
class LocalDatabase {
  LocalDatabase(this._backend);

  final StorageBackend _backend;

  /// Reads a single committed row, or `null` when absent.
  Json? read(String table, String id) => _backend.load(table)[id];

  /// Reads every committed row in [table] keyed by id.
  Map<String, Json> readTable(String table) => _backend.load(table);

  /// Runs [action] inside a single logical transaction.
  ///
  /// All writes staged by [action] are committed together when it returns. If
  /// [action] throws, nothing is committed and the store is left untouched.
  T transaction<T>(T Function(Transaction txn) action) {
    final txn = Transaction._(_backend);
    final result = action(txn);
    txn._commit();
    return result;
  }
}

/// The mutation surface handed to a [LocalDatabase.transaction] callback.
///
/// Reads observe a snapshot taken lazily at first touch of each table plus this
/// transaction's own pending writes; nothing is visible to the database until
/// the transaction commits successfully.
class Transaction {
  Transaction._(this._backend);

  final StorageBackend _backend;
  final Map<String, Map<String, Json>> _staged = {};

  Map<String, Json> _tableBuffer(String table) =>
      _staged.putIfAbsent(table, () => _backend.load(table));

  /// Reads a row within the transaction, honouring uncommitted writes.
  Json? get(String table, String id) => _tableBuffer(table)[id];

  /// Reads all rows of [table] within the transaction.
  Map<String, Json> readTable(String table) => Map.of(_tableBuffer(table));

  /// Stages an insert/update of [value] under [id]. A defensive deep copy is
  /// stored so later external mutation of [value] cannot leak into the store.
  void put(String table, String id, Json value) {
    _tableBuffer(table)[id] = _deepCopy(value);
  }

  /// Stages a delete of [id].
  void delete(String table, String id) {
    _tableBuffer(table).remove(id);
  }

  void _commit() {
    if (_staged.isEmpty) return;
    _backend.commit(_staged);
  }
}

Json _deepCopy(Json value) =>
    (jsonDecode(jsonEncode(value)) as Map).cast<String, Object?>();
