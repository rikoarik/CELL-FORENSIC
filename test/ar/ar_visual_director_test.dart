import 'package:cell_forensic/ar/ar_asset_registry.dart';
import 'package:cell_forensic/ar/ar_scene_engine.dart';
import 'package:cell_forensic/ar/ar_visual_director.dart';
import 'package:cell_forensic/ar/misi2_visual_helpers.dart';
import 'package:cell_forensic/domain/ai/ar_action_whitelist.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late LiveArSceneEngine engine;
  const director = ArVisualDirector();

  setUp(() {
    engine = LiveArSceneEngine();
  });

  tearDown(() => engine.dispose());

  test('same live engine keeps placement while sequence steps swap models',
      () async {
    await engine.place(const ArPlacement(x: 1, y: 0, z: -1));
    final placement = engine.placement;

    await director.applySequenceStep(
      engine,
      missionCode: 'MISI-1',
      stepCode: 'focus_sample_a',
    );
    await director.applySequenceStep(
      engine,
      missionCode: 'MISI-1',
      stepCode: 'glow_organelles',
    );
    await director.applySequenceStep(
      engine,
      missionCode: 'MISI-1',
      stepCode: 'play_shrink_animation',
    );

    expect(engine.placement, placement);
    expect(engine.capabilities.isFallback, isFalse);
    expect(
      engine.visualState.activeModelPath,
      ArAssetRegistry.vakuolaMainSolo,
    );
    expect(engine.visualState.overlay, ArOverlayEffect.vacuoleDamage);
  });

  test('M3 compare keeps secondary model on same scene', () async {
    await engine.place(const ArPlacement(x: 0, y: 0, z: -1));
    await director.applySequenceStep(
      engine,
      missionCode: 'MISI-3',
      stepCode: 'show_both_samples',
    );
    expect(engine.visualState.activeModelPath, ArAssetRegistry.sampleA);
    expect(engine.visualState.secondaryModelPath, ArAssetRegistry.sampleB);
    expect(engine.visualState.overlay, ArOverlayEffect.comparisonLabels);
  });

  test('M3 SEQ full beat: A+B → green wall → red X → force arrows on dinding',
      () async {
    await engine.place(const ArPlacement(x: 0, y: 0, z: -1));
    final placement = engine.placement;

    await director.applySequenceStep(
      engine,
      missionCode: 'MISI-3',
      stepCode: 'show_both_samples',
    );
    expect(engine.visualState.activeModelPath, ArAssetRegistry.sampleA);
    expect(engine.visualState.secondaryModelPath, ArAssetRegistry.sampleB);
    expect(engine.visualState.overlay, ArOverlayEffect.comparisonLabels);
    expect(
      engine.visualState.nodeScale[ArNodeIds.primary],
      ArVec3.one,
    );

    await director.applySequenceStep(
      engine,
      missionCode: 'MISI-3',
      stepCode: 'highlight_cell_wall',
    );
    expect(engine.visualState.activeModelPath, ArAssetRegistry.dindingSelSolo);
    expect(engine.visualState.secondaryModelPath, ArAssetRegistry.sampleB);
    expect(engine.visualState.highlightTarget, ArNodeIds.cellWall);
    expect(engine.visualState.overlay, ArOverlayEffect.cellWallHighlight);

    await director.applySequenceStep(
      engine,
      missionCode: 'MISI-3',
      stepCode: 'mark_sample_b',
    );
    expect(engine.visualState.activeModelPath, ArAssetRegistry.sampleA);
    expect(engine.visualState.secondaryModelPath, ArAssetRegistry.sampleB);
    expect(engine.visualState.overlay, ArOverlayEffect.missingStructureCross);

    await director.applySequenceStep(
      engine,
      missionCode: 'MISI-3',
      stepCode: 'show_force_arrows',
    );
    // Wave 1 bug: must NOT swap to mitokondriaSolo.
    expect(
      engine.visualState.activeModelPath,
      ArAssetRegistry.dindingSelSolo,
    );
    expect(
      engine.visualState.activeModelPath,
      isNot(ArAssetRegistry.mitokondriaSolo),
    );
    expect(engine.visualState.secondaryModelPath, ArAssetRegistry.sampleB);
    expect(engine.visualState.overlay, ArOverlayEffect.forceArrows);
    expect(engine.visualState.highlightTarget, ArNodeIds.cellWall);
    expect(
      ArAssetRegistry.modelForStep('MISI-3', 'show_force_arrows'),
      ArAssetRegistry.dindingSelSolo,
    );
    expect(engine.placement, placement);
  });

  test('M1 zoom_internal stays on Sample A — not nukleusSolo (GAP-6)', () async {
    await engine.place(const ArPlacement(x: 0, y: 0, z: -1));
    await engine.initLabScene(
      labTableModelPath: ArAssetRegistry.mejaLab,
      sampleAModelPath: ArAssetRegistry.sampleA,
      sampleBModelPath: ArAssetRegistry.sampleB,
    );
    await director.applySequenceStep(
      engine,
      missionCode: 'MISI-1',
      stepCode: 'zoom_internal',
    );

    expect(engine.visualState.activeModelPath, ArAssetRegistry.sampleA);
    expect(
      engine.visualState.activeModelPath,
      isNot(ArAssetRegistry.nukleusSolo),
    );
    expect(ArAssetRegistry.modelForStep('MISI-1', 'zoom_internal'),
        ArAssetRegistry.sampleA);
    expect(engine.visualState.highlightTarget, ArNodeIds.chloroplast);
    expect(
      engine.visualState.nodeScale[ArNodeIds.primary],
      const ArVec3(1.55, 1.55, 1.55),
    );
    expect(
      engine.visualState.nodeScale[ArNodeIds.vacuole],
      const ArVec3(0.88, 0.88, 0.88),
    );
    // Yellow glow reserved for glow_organelles — zoom is framing only.
    expect(engine.visualState.overlay, ArOverlayEffect.none);
    expect(engine.visualState.secondaryModelPath, isNull);
    // Lab table anchor asset persists across the zoom step.
    expect(engine.visualState.labTableModelPath, ArAssetRegistry.mejaLab);
  });

  test('M1 SEQ-MISI-1 full path keeps placement and ends on vacuole', () async {
    await engine.place(const ArPlacement(x: 0.2, y: 0, z: -0.8));
    await engine.initLabScene(
      labTableModelPath: ArAssetRegistry.mejaLab,
      sampleAModelPath: ArAssetRegistry.sampleA,
      sampleBModelPath: ArAssetRegistry.sampleB,
    );
    final placement = engine.placement;

    await director.applySequenceStep(
      engine,
      missionCode: 'MISI-1',
      stepCode: 'focus_sample_a',
    );
    await director.applySequenceStep(
      engine,
      missionCode: 'MISI-1',
      stepCode: 'zoom_internal',
    );
    await director.applySequenceStep(
      engine,
      missionCode: 'MISI-1',
      stepCode: 'glow_organelles',
    );
    expect(engine.visualState.activeModelPath, ArAssetRegistry.kloroplasSolo);
    expect(engine.visualState.overlay, ArOverlayEffect.chloroplastHighlight);
    expect(
      engine.visualState.nodeScale[ArNodeIds.chloroplast],
      const ArVec3(0.72, 0.72, 0.72),
    );

    await director.applySequenceStep(
      engine,
      missionCode: 'MISI-1',
      stepCode: 'play_shrink_animation',
    );

    expect(engine.placement, placement);
    expect(engine.visualState.labTableModelPath, ArAssetRegistry.mejaLab);
    expect(engine.visualState.activeModelPath, ArAssetRegistry.vakuolaMainSolo);
    expect(engine.visualState.overlay, ArOverlayEffect.vacuoleDamage);
    expect(
      engine.visualState.nodeScale[ArNodeIds.vacuole],
      const ArVec3(0.55, 0.55, 0.55),
    );
    // M1 complete — still no secondary / no auto M2 sample.
    expect(engine.visualState.secondaryModelPath, isNull);
  });

  test('valid AI action executes; unknown / mismatch / low conf rejected',
      () async {
    await engine.place(const ArPlacement(x: 0, y: 0, z: 0));

    final ok = await director.applyAiAction(
      engine,
      arAction: 'highlight_chloroplast',
      missionNumber: 1,
      confidence: 0.95,
    );
    expect(ok, 'highlight_chloroplast');
    expect(
      engine.visualState.highlightTarget,
      ArNodeIds.chloroplast,
    );

    final unknown = await director.applyAiAction(
      engine,
      arAction: 'invent_facts',
      missionNumber: 1,
      confidence: 0.99,
    );
    expect(unknown, ArActionWhitelist.none);

    final mismatch = await director.applyAiAction(
      engine,
      arAction: 'compare_samples',
      missionNumber: 1,
      confidence: 0.99,
    );
    expect(mismatch, ArActionWhitelist.none);

    final low = await director.applyAiAction(
      engine,
      arAction: 'highlight_chloroplast',
      missionNumber: 1,
      confidence: 0.1,
    );
    expect(low, ArActionWhitelist.none);
  });

  test('Fake engine also implements E11 visual APIs', () async {
    final fake = FakeArSceneEngine();
    await fake.showNode(ArNodeIds.primary);
    await fake.setNodeScale(ArNodeIds.primary, const ArVec3(1.2, 1.2, 1.2));
    await fake.setOpacity(0.5);
    await fake.showAnchoredOverlayEffect(ArOverlayEffect.waterLeak);
    await fake.resetTransform();
    expect(fake.capabilities.isFallback, isTrue);
    expect(fake.visualState.overlay, ArOverlayEffect.waterLeak);
    expect(fake.visualState.userScale, 1);
    await fake.dispose();
  });

  test('M2 SEQ-MISI-2: normal bilayer then torn + membrane-anchored leak',
      () async {
    await engine.place(const ArPlacement(x: 0.2, y: 0, z: -1.1));
    await engine.initLabScene(
      labTableModelPath: ArAssetRegistry.mejaLab,
      sampleAModelPath: ArAssetRegistry.sampleA,
      sampleBModelPath: ArAssetRegistry.sampleB,
    );
    final placement = engine.placement;

    await director.applySequenceStep(
      engine,
      missionCode: 'MISI-2',
      stepCode: 'focus_sample_b',
    );
    expect(engine.placement, placement);
    expect(engine.visualState.activeModelPath, ArAssetRegistry.sampleB);
    expect(engine.visualState.secondaryModelPath, isNull);
    expect(engine.visualState.highlightTarget, ArNodeIds.membrane);
    expect(engine.visualState.overlay, ArOverlayEffect.none);
    expect(engine.visualState.labTableModelPath, ArAssetRegistry.mejaLab);

    await director.applySequenceStep(
      engine,
      missionCode: 'MISI-2',
      stepCode: 'zoom_membrane',
    );
    // Intact zoom — no damage ring yet (normal before torn).
    expect(engine.placement, placement);
    expect(engine.visualState.activeModelPath, ArAssetRegistry.sampleB);
    expect(engine.visualState.overlay, ArOverlayEffect.none);
    expect(
      engine.visualState.nodeScale[ArNodeIds.primary],
      Misi2VisualHelpers.bilayerZoomScale,
    );
    expect(engine.visualState.highlightTarget, ArNodeIds.membrane);

    await director.applySequenceStep(
      engine,
      missionCode: 'MISI-2',
      stepCode: 'show_torn_bilayer',
    );
    expect(engine.placement, placement);
    expect(engine.visualState.activeModelPath, ArAssetRegistry.rantaiProtein);
    expect(engine.visualState.overlay, ArOverlayEffect.membraneDamage);

    await director.applySequenceStep(
      engine,
      missionCode: 'MISI-2',
      stepCode: 'play_leak_particles',
    );
    expect(engine.placement, placement);
    expect(engine.visualState.activeModelPath, ArAssetRegistry.rantaiProtein);
    expect(engine.visualState.overlay, ArOverlayEffect.waterLeak);
    // Membrane highlight anchors the dark-blue spray (not fullscreen).
    expect(engine.visualState.highlightTarget, ArNodeIds.membrane);
    expect(engine.visualState.labTableModelPath, ArAssetRegistry.mejaLab);
  });
}
