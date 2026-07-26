import 'package:cell_forensic/ar/ar_asset_registry.dart';
import 'package:cell_forensic/ar/ar_scene_engine.dart';
import 'package:cell_forensic/ar/misi1_visuals.dart';
import 'package:cell_forensic/ar/misi2_visual_helpers.dart';
import 'package:cell_forensic/ar/misi3_visuals.dart';
import 'package:cell_forensic/domain/ai/ar_action_whitelist.dart';

/// Applies mission sequence steps and whitelisted AI AR actions onto an
/// [ArSceneEngine] without advancing [SequenceEngine] (E11 D–F / H–J).
///
/// Plugin limits: no native material glow / particle emitter — we combine GLB
/// swap + [ArOverlayEffect] Flutter overlays attached to the model frame.
///
/// Misi 1 beats are delegated to [Misi1Visuals] so SEQ-MISI-1 stays tabletop-
/// anchored and does not auto-chain into M2/M3. Misi 2 uses [Misi2VisualHelpers]
/// (membrane-anchored leak). Misi 3 uses [Misi3Visuals] so SEQ-MISI-3 stays A+B
/// side-by-side (force arrows never swap to mitokondria).
class ArVisualDirector {
  const ArVisualDirector();

  /// Applies visuals for a sequence step code (e.g. `glow_organelles`).
  Future<void> applySequenceStep(
    ArSceneEngine engine, {
    required String missionCode,
    required String stepCode,
  }) async {
    final model = ArAssetRegistry.modelForStep(missionCode, stepCode);
    if (model != null) {
      await engine.replaceModelAtActiveAnchor(model);
    }

    switch ((missionCode, stepCode)) {
      case ('MISI-1', 'focus_sample_a'):
        await Misi1Visuals.focusSampleA(engine);
      case ('MISI-1', 'zoom_internal'):
        // Stay on Sample A AllInOne — zoom toward kloroplas + vakuola (GAP-6).
        await Misi1Visuals.zoomInternal(engine);
      case ('MISI-1', 'glow_organelles'):
        await Misi1Visuals.glowOrganelles(engine);
      case ('MISI-1', 'play_shrink_animation'):
        await Misi1Visuals.playShrinkAnimation(engine);
      case ('MISI-2', 'focus_sample_b'):
        // PDF: focus lapisan terluar Sampel B — stay on lab tabletop.
        await Misi2VisualHelpers.focusSampleBOuter(engine);
      case ('MISI-2', 'zoom_membrane'):
        // PDF: zoom bilayer intact first (normal), damage comes next step.
        await Misi2VisualHelpers.zoomIntactBilayer(engine);
      case ('MISI-2', 'show_torn_bilayer'):
        // PDF: ekor fosfolipid terputus-putus (RantaiProtein proxy).
        await Misi2VisualHelpers.showTornBilayer(engine);
      case ('MISI-2', 'play_leak_particles'):
        // PDF: partikel air biru tua menyembur dari area membran (bukan fullscreen).
        await Misi2VisualHelpers.playMembraneLeakParticles(engine);
      case ('MISI-3', 'show_damaged_sample_a'):
        await Misi3Visuals.showDamagedSampleA(engine);
      case ('MISI-3', 'show_both_samples'):
        await Misi3Visuals.showBothSamples(engine);
      case ('MISI-3', 'highlight_cell_wall'):
        await Misi3Visuals.highlightCellWall(engine);
      case ('MISI-3', 'mark_sample_b'):
        await Misi3Visuals.markSampleB(engine);
      case ('MISI-3', 'show_force_arrows'):
        await Misi3Visuals.showForceArrows(engine);
      default:
        break;
    }
  }

  /// Applies a whitelisted AI [arAction] if valid for [missionNumber].
  ///
  /// Returns the resolved action that was applied (`none` if rejected).
  Future<String> applyAiAction(
    ArSceneEngine engine, {
    required String arAction,
    required int missionNumber,
    required double confidence,
  }) async {
    final resolved = ArActionWhitelist.resolve(
      arAction: arAction,
      missionNumber: missionNumber,
      confidence: confidence,
    );
    if (resolved == ArActionWhitelist.none) {
      return resolved;
    }

    final missionCode = 'MISI-$missionNumber';
    switch (resolved) {
      case 'focus_sample_a':
        await applySequenceStep(
          engine,
          missionCode: 'MISI-1',
          stepCode: 'focus_sample_a',
        );
      case 'focus_sample_b':
        await applySequenceStep(
          engine,
          missionCode: 'MISI-2',
          stepCode: 'focus_sample_b',
        );
      case 'highlight_chloroplast':
        await engine.replaceModelAtActiveAnchor(ArAssetRegistry.kloroplasSolo);
        await Misi1Visuals.glowOrganelles(engine);
      case 'show_damaged_chloroplast':
        await engine.replaceModelAtActiveAnchor(ArAssetRegistry.kloroplasSolo);
        await Misi1Visuals.glowOrganelles(engine);
      case 'show_vacuole_damage':
        await engine.replaceModelAtActiveAnchor(
          ArAssetRegistry.vakuolaMainSolo,
        );
        await Misi1Visuals.playShrinkAnimation(engine);
      case 'focus_membrane':
        await applySequenceStep(
          engine,
          missionCode: 'MISI-2',
          stepCode: 'zoom_membrane',
        );
      case 'show_membrane_damage':
        await applySequenceStep(
          engine,
          missionCode: 'MISI-2',
          stepCode: 'show_torn_bilayer',
        );
      case 'show_water_leak':
        await applySequenceStep(
          engine,
          missionCode: 'MISI-2',
          stepCode: 'play_leak_particles',
        );
      case 'compare_samples':
        await applySequenceStep(
          engine,
          missionCode: 'MISI-3',
          stepCode: 'show_both_samples',
        );
      case 'highlight_cell_wall':
        await applySequenceStep(
          engine,
          missionCode: 'MISI-3',
          stepCode: 'highlight_cell_wall',
        );
      case 'show_force_arrows':
        await applySequenceStep(
          engine,
          missionCode: 'MISI-3',
          stepCode: 'show_force_arrows',
        );
      case 'reset_scene':
        await engine.showAnchoredOverlayEffect(ArOverlayEffect.none);
        await engine.setSecondaryModel(null);
        await engine.setMaterialHighlight(ArNodeIds.primary, enabled: false);
        await engine.setOpacity(1);
        await engine.resetTransform();
        await engine.replaceModelAtActiveAnchor(
          ArAssetRegistry.primaryModelForMission(missionCode),
        );
      default:
        break;
    }
    return resolved;
  }
}
