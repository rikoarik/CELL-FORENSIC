import 'package:cell_forensic/ar/ar_lifecycle_controller.dart';
import 'package:cell_forensic/ar/ar_scene_engine.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ArLifecycleController', () {
    late FakeArSceneEngine engine;
    late ArLifecycleController controller;

    setUp(() {
      engine = FakeArSceneEngine();
      controller = ArLifecycleController(engine);
    });

    tearDown(() => engine.dispose());

    test('inactive/paused/hidden pause tracking via scene engine', () {
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
      ]) {
        engine.updateTracking(ArTrackingState.tracking);
        controller.pausedByLifecycle = false;
        controller.awaitingRelocalization = false;

        controller.handleAppLifecycle(state);

        expect(engine.isPaused, isTrue);
        expect(engine.trackingState, ArTrackingState.lost);
        expect(controller.pausedByLifecycle, isTrue);
      }
    });

    test('resumed stays lost until confirmRelocalized (no early unpause)', () {
      controller.handleAppLifecycle(AppLifecycleState.paused);
      expect(engine.isPaused, isTrue);

      controller.handleAppLifecycle(AppLifecycleState.resumed);

      expect(engine.isPaused, isTrue);
      expect(engine.trackingState, ArTrackingState.lost);
      expect(controller.pausedByLifecycle, isFalse);
      expect(controller.awaitingRelocalization, isTrue);

      controller.confirmRelocalized();

      expect(engine.isPaused, isFalse);
      expect(engine.trackingState, ArTrackingState.tracking);
      expect(controller.awaitingRelocalization, isFalse);
    });

    test('does not clear ARCore tracking-loss on resume', () {
      engine.updateTracking(ArTrackingState.lost);
      expect(controller.pausedByLifecycle, isFalse);

      controller.handleAppLifecycle(AppLifecycleState.resumed);

      expect(engine.trackingState, ArTrackingState.lost);
      expect(controller.awaitingRelocalization, isFalse);
    });

    test('lifecycle pause queues actions until relocalized', () async {
      controller.handleAppLifecycle(AppLifecycleState.inactive);
      final pending = engine.runAction('after-resume');
      await Future<void>.delayed(Duration.zero);
      expect(engine.isPaused, isTrue);

      controller.handleAppLifecycle(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(engine.isPaused, isTrue);

      controller.confirmRelocalized();
      await pending;
      expect(engine.isPaused, isFalse);
    });

    test('Fake engine stays testable via confirmRelocalized', () {
      controller.handleAppLifecycle(AppLifecycleState.paused);
      controller.handleAppLifecycle(AppLifecycleState.resumed);
      expect(engine.trackingState, ArTrackingState.lost);

      // Simulate Fake / fallback recovery signal.
      controller.confirmRelocalized();
      expect(engine.trackingState, ArTrackingState.tracking);
    });
  });
}
