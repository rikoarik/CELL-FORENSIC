import 'package:cell_forensic/ar/ar_scene_engine.dart';
import 'package:flutter/widgets.dart';

/// Maps Flutter [AppLifecycleState] to AR tracking pause/resume (E7-02).
///
/// When the app becomes inactive/paused/hidden, sequence actions pause via
/// [ArSceneEngine.updateTracking] (`lost`). On [AppLifecycleState.resumed],
/// this controller clears its lifecycle pause flag but does **not** force
/// tracking healthy — callers must signal relocalization via
/// [confirmRelocalized] (or the engine's own tracking update) so Fake/Live
/// paths stay testable and ARCore can finish recovering.
class ArLifecycleController {
  ArLifecycleController(this.engine);

  final ArSceneEngine engine;

  /// True when the last pause was caused by app lifecycle (not ARCore).
  bool pausedByLifecycle = false;

  /// True after a lifecycle resume until tracking is confirmed healthy again.
  bool awaitingRelocalization = false;

  void handleAppLifecycle(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _pauseForLifecycle();
      case AppLifecycleState.resumed:
        _resumeFromLifecycle();
      case AppLifecycleState.detached:
        break;
    }
  }

  void _pauseForLifecycle() {
    if (engine.trackingState == ArTrackingState.lost) return;
    pausedByLifecycle = true;
    awaitingRelocalization = false;
    engine.updateTracking(ArTrackingState.lost);
  }

  void _resumeFromLifecycle() {
    if (!pausedByLifecycle) return;
    pausedByLifecycle = false;
    awaitingRelocalization = true;
    // Keep [ArTrackingState.lost] until [confirmRelocalized] / engine signal.
  }

  /// Marks tracking healthy after ARCore/Fake relocalization.
  ///
  /// Safe to call when not awaiting — no-ops if tracking is already healthy
  /// and no lifecycle resume is pending.
  void confirmRelocalized() {
    if (!awaitingRelocalization &&
        engine.trackingState == ArTrackingState.tracking) {
      return;
    }
    awaitingRelocalization = false;
    engine.updateTracking(ArTrackingState.tracking);
  }
}
