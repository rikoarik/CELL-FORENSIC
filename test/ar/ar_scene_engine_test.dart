import 'package:cell_forensic/ar/ar_asset_registry.dart';
import 'package:cell_forensic/ar/ar_scene_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FakeArSceneEngine', () {
    late FakeArSceneEngine engine;
    late List<ArSceneEvent> events;

    setUp(() {
      engine = FakeArSceneEngine();
      events = [];
      engine.events.listen(events.add);
    });

    tearDown(() => engine.dispose());

    test('exposes fallback capabilities', () {
      expect(engine.capabilities.supportsPlaneDetection, isFalse);
      expect(engine.capabilities.supportsAnchors, isTrue);
      expect(engine.capabilities.isFallback, isTrue);
    });

    test(
      'places a scene and correlates ordered events to command sequence',
      () async {
        await engine.place(const ArPlacement(x: 1, y: 2, z: 3));

        expect(events, [
          const ArSceneEvent(
            sequence: 1,
            type: ArSceneEventType.commandAccepted,
            command: ArSceneCommandType.place,
          ),
          const ArSceneEvent(
            sequence: 1,
            type: ArSceneEventType.placementCompleted,
            command: ArSceneCommandType.place,
          ),
        ]);
        expect(engine.placement, const ArPlacement(x: 1, y: 2, z: 3));
      },
    );

    test('uses increasing sequence numbers in command order', () async {
      await engine.place(const ArPlacement(x: 0, y: 0, z: 0));
      await engine.runAction('highlight-nucleus');

      expect(events.map((event) => event.sequence), [1, 1, 2, 2]);
      expect(events.map((event) => event.command), [
        ArSceneCommandType.place,
        ArSceneCommandType.place,
        ArSceneCommandType.action,
        ArSceneCommandType.action,
      ]);
    });

    test(
      'pauses actions while tracking is lost and resumes them in order',
      () async {
        engine.updateTracking(ArTrackingState.lost);
        final first = engine.runAction('one');
        final second = engine.runAction('two');

        await Future<void>.delayed(Duration.zero);
        expect(engine.isPaused, isTrue);
        expect(
          events.where(
            (event) => event.type == ArSceneEventType.actionCompleted,
          ),
          isEmpty,
        );

        engine.updateTracking(ArTrackingState.tracking);
        await Future.wait([first, second]);

        expect(engine.isPaused, isFalse);
        expect(
          events
              .where((event) => event.type == ArSceneEventType.actionCompleted)
              .map((event) => event.actionId),
          ['one', 'two'],
        );
      },
    );

    test('deduplicates completion for the same action id', () async {
      await engine.runAction('inspect-membrane');
      await engine.runAction('inspect-membrane');

      expect(
        events
            .where((event) => event.type == ArSceneEventType.actionCompleted)
            .map((event) => event.actionId),
        ['inspect-membrane'],
      );
    });

    test('reset clears placement and completed actions', () async {
      await engine.place(const ArPlacement(x: 1, y: 0, z: 0));
      await engine.runAction('step-a');
      await engine.reset();

      expect(engine.placement, isNull);
      await engine.runAction('step-a');
      expect(
        events
            .where((e) => e.type == ArSceneEventType.actionCompleted)
            .map((e) => e.actionId)
            .where((id) => id == 'step-a')
            .length,
        2,
      );
    });

    test('initLabScene places one merged scene GLB (no stacked meja)',
        () async {
      await engine.place(const ArPlacement(x: 0, y: 0, z: 0));
      await engine.initLabScene(
        labTableModelPath: ArAssetRegistry.mejaLab,
        tempatUjiModelPath: ArAssetRegistry.tempatUji,
        sampleAModelPath: ArAssetRegistry.sampleA,
        sampleBModelPath: ArAssetRegistry.sampleB,
      );

      final visual = engine.visualState;
      expect(visual.labTableModelPath, isNull);
      expect(visual.activeModelPath, ArAssetRegistry.sampleA);
      expect(visual.secondaryModelPath, isNull);
      expect(visual.visibleNodes[ArNodeIds.labTable], isFalse);
      expect(visual.visibleNodes[ArNodeIds.tempatUjiA], isFalse);
      expect(visual.visibleNodes[ArNodeIds.tempatUjiB], isFalse);
      expect(visual.visibleNodes[ArNodeIds.sampleA], isTrue);
      expect(visual.visibleNodes[ArNodeIds.sampleB], isFalse);
      expect(visual.nodeModels[ArNodeIds.primary], ArAssetRegistry.sampleA);
      expect(visual.overlay, ArOverlayEffect.none);
      // Placement must not complete a mission action (GAP-1).
      expect(
        events.where((e) => e.type == ArSceneEventType.actionCompleted),
        isEmpty,
      );
    });
  });

  group('LiveArSceneEngine', () {
    test('exposes plane-detection capabilities for real AR path', () {
      final engine = LiveArSceneEngine();
      expect(engine.capabilities.supportsPlaneDetection, isTrue);
      expect(engine.capabilities.isFallback, isFalse);
      engine.dispose();
    });

    test('E11 visual APIs update visualState without clearing placement',
        () async {
      final engine = LiveArSceneEngine();
      await engine.place(const ArPlacement(x: 0, y: 1, z: 0));
      await engine.replaceModelAtActiveAnchor('assets/ar_models/x.glb');
      await engine.setMaterialHighlight('chloroplast', enabled: true);
      await engine.showAnchoredOverlayEffect(ArOverlayEffect.waterLeak);
      await engine.setUserTransform(scale: 1.5, rotationY: 0.5);
      expect(engine.placement, const ArPlacement(x: 0, y: 1, z: 0));
      expect(engine.visualState.activeModelPath, 'assets/ar_models/x.glb');
      expect(engine.visualState.highlightTarget, 'chloroplast');
      expect(engine.visualState.overlay, ArOverlayEffect.waterLeak);
      expect(engine.visualState.userScale, 1.5);
      await engine.resetTransform();
      expect(engine.visualState.userScale, 1);
      expect(engine.placement, isNotNull);
      await engine.dispose();
    });

    test('Wave2 focus/zoom/outline APIs keep placement and restore zoom',
        () async {
      final engine = LiveArSceneEngine();
      await engine.place(const ArPlacement(x: 0, y: 0, z: 0));
      await engine.setNodeScale(ArNodeIds.primary, ArVec3.one);
      await engine.focusOnTarget(ArNodeIds.sampleA);
      await engine.smoothZoomToTarget(
        ArNodeIds.primary,
        factor: 1.5,
        cameraOrbit: '0deg 65deg 1.4m',
      );
      await engine.setOutline(ArNodeIds.cellWall, enabled: true);
      await engine.replaceNodeModel(
        ArNodeIds.chloroplast,
        'assets/ar_models/kloroplas.glb',
      );
      await engine.showAnchoredOverlay(ArOverlayEffect.chloroplastHighlight);
      await engine.showParticleOverlay(ArOverlayEffect.waterLeak);

      expect(engine.placement, isNotNull);
      expect(engine.visualState.focusTarget, ArNodeIds.sampleA);
      expect(engine.visualState.zoomTarget, ArNodeIds.primary);
      expect(engine.visualState.zoomFactor, 1.5);
      expect(engine.visualState.cameraOrbit, '0deg 65deg 1.4m');
      expect(engine.visualState.outlineTarget, ArNodeIds.cellWall);
      expect(
        engine.visualState.nodeModels[ArNodeIds.chloroplast],
        'assets/ar_models/kloroplas.glb',
      );
      expect(engine.visualState.overlay, ArOverlayEffect.waterLeak);
      expect(
        engine.visualState.nodeScale[ArNodeIds.primary],
        const ArVec3(1.5, 1.5, 1.5),
      );

      await engine.resetSceneFocus();
      expect(engine.placement, isNotNull);
      expect(engine.visualState.focusTarget, isNull);
      expect(engine.visualState.zoomTarget, isNull);
      expect(engine.visualState.zoomFactor, 1);
      expect(engine.visualState.highlightTarget, isNull);
      expect(engine.visualState.outlineTarget, isNull);
      expect(engine.visualState.cameraOrbit, isNull);
      // Pre-zoom sequence scale restored.
      expect(engine.visualState.nodeScale[ArNodeIds.primary], ArVec3.one);

      await engine.dispose();
    });

    test('resetTransform preserves sequence nodeScale/nodePosition', () async {
      final engine = FakeArSceneEngine();
      await engine.place(const ArPlacement(x: 1, y: 0, z: 0));
      await engine.setNodeScale(
        ArNodeIds.primary,
        const ArVec3(1.2, 1.2, 1.2),
      );
      await engine.setNodePosition(
        ArNodeIds.primary,
        const ArVec3(0.1, 0.03, 0),
      );
      await engine.setUserTransform(scale: 1.8, rotationY: 0.4);

      await engine.resetTransform();

      expect(engine.visualState.userScale, 1);
      expect(engine.visualState.userRotationY, 0);
      expect(
        engine.visualState.nodeScale[ArNodeIds.primary],
        const ArVec3(1.2, 1.2, 1.2),
      );
      expect(
        engine.visualState.nodePosition[ArNodeIds.primary],
        const ArVec3(0.1, 0.03, 0),
      );
      expect(engine.placement, isNotNull);
      await engine.dispose();
    });
  });
}
