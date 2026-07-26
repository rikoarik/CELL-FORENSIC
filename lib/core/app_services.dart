import 'package:cell_forensic/core/config/app_flavor.dart';
import 'package:cell_forensic/core/database/local_store.dart';
import 'package:cell_forensic/core/database/shared_preferences_storage.dart';
import 'package:cell_forensic/core/supabase/supabase_config.dart';
import 'package:cell_forensic/core/sync/supabase_remote_sync_client.dart';
import 'package:cell_forensic/core/sync/sync_flush_controller.dart';
import 'package:cell_forensic/core/sync/sync_queue.dart';

/// Process-wide services wired at app start (E1 foundation).
class AppServices {
  AppServices._({
    required this.database,
    required this.syncQueue,
    required this.syncFlush,
    required this.flavor,
    this.persistentStorage,
  });

  final LocalDatabase database;
  final SyncQueue syncQueue;
  final SyncFlushController syncFlush;
  final AppFlavor flavor;
  final SharedPreferencesStorageBackend? persistentStorage;

  static AppServices? _instance;
  static AppServices get instance {
    final value = _instance;
    if (value == null) {
      throw StateError('AppServices.ensureInitialized() belum dipanggil');
    }
    return value;
  }

  static bool get isInitialized => _instance != null;

  /// Flavor + optional Supabase + durable local DB + sync queue.
  ///
  /// Starts [SyncFlushController] so both mobile and dashboard entrypoints
  /// drain the offline queue when a remote client is available.
  static Future<AppServices> ensureInitialized({
    bool usePersistentStore = true,
    bool startSyncFlush = true,
  }) async {
    if (_instance != null) return _instance!;

    final flavor = AppFlavor.current;
    assert(() {
      // ignore: avoid_print
      print('Cell Forensic flavor: ${flavor.label}');
      return true;
    }());

    await SupabaseConfig.ensureInitialized();

    SharedPreferencesStorageBackend? prefsBackend;
    final StorageBackend backend;
    if (usePersistentStore) {
      prefsBackend = await SharedPreferencesStorageBackend.open();
      backend = prefsBackend;
    } else {
      backend = InMemoryStorageBackend();
    }

    final database = LocalDatabase(backend);
    final syncQueue = SyncQueue(
      database: database,
      remote: const SupabaseRemoteSyncClient(),
    );
    final syncFlush = SyncFlushController(syncQueue: syncQueue);

    final services = AppServices._(
      database: database,
      syncQueue: syncQueue,
      syncFlush: syncFlush,
      flavor: flavor,
      persistentStorage: prefsBackend,
    );
    _instance = services;
    if (startSyncFlush) {
      syncFlush.start();
    }
    return services;
  }

  /// Opportunistic drain after local enqueue (no-op when offline / no client).
  void requestSyncFlush() => syncFlush.scheduleFlush();

  /// Test helper to replace/clear the singleton.
  static void debugReset() {
    _instance?.syncFlush.stop();
    _instance = null;
  }
}
