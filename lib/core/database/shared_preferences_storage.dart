import 'dart:convert';

import 'package:cell_forensic/core/database/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Durable [StorageBackend] with an in-memory write-through cache (E1-05).
///
/// [commit] updates the cache synchronously (so [LocalDatabase]/[SyncQueue]
/// keep working), then flushes JSON to [SharedPreferences]. Call [flush] after
/// critical writes if you need to await durability.
class SharedPreferencesStorageBackend implements StorageBackend {
  SharedPreferencesStorageBackend._(this._prefs, this._cache);

  final SharedPreferences _prefs;
  final Map<String, String> _cache;
  static const _prefix = 'cf_db_';

  static Future<SharedPreferencesStorageBackend> open() async {
    final prefs = await SharedPreferences.getInstance();
    final cache = <String, String>{};
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_prefix)) continue;
      final value = prefs.getString(key);
      if (value != null) cache[key.substring(_prefix.length)] = value;
    }
    return SharedPreferencesStorageBackend._(prefs, cache);
  }

  String _key(String table) => '$_prefix$table';

  @override
  Map<String, Json> load(String table) {
    final raw = _cache[table];
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, Object?>;
    return decoded.map(
      (id, row) => MapEntry(id, (row as Map).cast<String, Object?>()),
    );
  }

  @override
  Set<String> get tables => _cache.keys.toSet();

  @override
  void commit(Map<String, Map<String, Json>> staged) {
    final encoded = <String, String>{};
    staged.forEach((table, rows) {
      encoded[table] = jsonEncode(rows);
    });
    encoded.forEach((table, rows) {
      _cache[table] = rows;
    });
    // Fire-and-forget flush; await [flush] when durability must be confirmed.
    // ignore: discarded_futures
    flush();
  }

  /// Awaits persistence of the current cache snapshot.
  Future<void> flush() async {
    for (final entry in _cache.entries) {
      await _prefs.setString(_key(entry.key), entry.value);
    }
  }
}
