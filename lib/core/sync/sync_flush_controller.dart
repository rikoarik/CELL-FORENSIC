import 'dart:async';

import 'package:cell_forensic/core/supabase/supabase_config.dart';
import 'package:cell_forensic/core/sync/sync_queue.dart';
import 'package:flutter/widgets.dart';

/// Drains [SyncQueue] periodically and on app resume when Supabase is available.
///
/// Offline-first: enqueue still works without a client; [flushNow] is a no-op
/// until [canFlush] is true.
class SyncFlushController with WidgetsBindingObserver {
  SyncFlushController({
    required this.syncQueue,
    this.interval = const Duration(seconds: 15),
    bool Function()? canFlush,
  }) : _canFlush = canFlush ?? _defaultCanFlush;

  final SyncQueue syncQueue;
  final Duration interval;
  final bool Function() _canFlush;

  Timer? _timer;
  Future<void>? _inFlight;
  bool _started = false;

  static bool _defaultCanFlush() => SupabaseConfig.clientOrNull != null;

  bool get isStarted => _started;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(interval, (_) => scheduleFlush());
    scheduleFlush();
  }

  void stop() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
  }

  /// Opportunistic flush after enqueue / resume (non-blocking).
  void scheduleFlush() {
    unawaited(flushNow());
  }

  /// Pushes every currently-due operation once.
  Future<void> flushNow() async {
    if (_inFlight != null) return _inFlight!;
    if (!_canFlush()) return;
    if (syncQueue.dueOperations().isEmpty) return;

    final future = syncQueue.processDue();
    _inFlight = future;
    try {
      await future;
    } finally {
      if (identical(_inFlight, future)) _inFlight = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      scheduleFlush();
    }
  }
}
