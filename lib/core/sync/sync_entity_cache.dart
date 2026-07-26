import 'package:cell_forensic/core/database/local_store.dart';

/// Reads the PostgREST payload nested under a [SyncQueue] local entity row.
///
/// [SyncQueue.enqueue] stores `{version, id: entityKey, payload: {...}}` — callers
/// must not treat the wrapper `id` as the Postgres row UUID.
Map<String, Object?>? syncCachedPayload(Json? entity) {
  final raw = entity?['payload'];
  if (raw is Map<String, Object?>) return Map<String, Object?>.from(raw);
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  return null;
}

/// Local conflict-detection version from the SyncQueue wrapper (not necessarily
/// a Postgres column).
int syncCachedVersion(Json? entity) {
  if (entity == null) return 0;
  final version = entity['version'];
  if (version is int) return version;
  if (version is num) return version.toInt();
  return 0;
}

String? syncCachedString(Json? entity, String key) {
  final value = syncCachedPayload(entity)?[key];
  return value is String && value.isNotEmpty ? value : null;
}
