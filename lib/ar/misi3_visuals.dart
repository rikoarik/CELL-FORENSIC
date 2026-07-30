import 'package:cell_forensic/ar/ar_asset_registry.dart';
import 'package:cell_forensic/ar/ar_scene_engine.dart';
import 'package:cell_forensic/ar/misi1_visuals.dart';

/// Misi 3–only tabletop choreography helpers (PDF Scene 2 / SEQ-MISI-3).
///
/// Beats: damaged Sample A glow → A+B side-by-side → green cell-wall contour
/// on A → red X on B → force arrows. Always on the same lab-table anchor;
/// never re-places. Dedicated force-arrow GLB is unavailable — arrows are an
/// [ArOverlayEffect.forceArrows] Flutter overlay. Native material glow is
/// unavailable — yellow chloroplast glow is a Flutter overlay approximation.
abstract final class Misi3Visuals {
  /// Shared A↔B separation so both samples keep comparable proportions.
  static const sideBySideOffsetX = 0.14;

  /// Matched 1:1 scale for comparison beats (no accidental zoom bleed).
  static const comparisonScale = ArVec3.one;

  /// PDF green contour on Sample A's cell wall.
  static const greenContourArgb = 0xFF22C55E;

  static Future<void> _stayOnTabletop(ArSceneEngine engine) async {
    await engine.showNode(ArNodeIds.primary);
    await engine.showNode(ArNodeIds.labTable);
    await engine.showNode(ArNodeIds.tempatUjiA);
    await engine.showNode(ArNodeIds.tempatUjiB);
  }

  static Future<void> _pairSamples(
    ArSceneEngine engine, {
    required String primaryModel,
  }) async {
    await _stayOnTabletop(engine);
    await engine.replaceModelAtActiveAnchor(primaryModel);
    await engine.setSecondaryModel(
      ArAssetRegistry.sampleB,
      offsetX: sideBySideOffsetX,
    );
    await engine.setNodeScale(ArNodeIds.primary, comparisonScale);
    await engine.setNodeScale(ArNodeIds.sampleA, comparisonScale);
    await engine.setNodeScale(ArNodeIds.sampleB, comparisonScale);
    await engine.setOpacity(1);
  }

  /// Step `show_damaged_sample_a` — plant cell with Flutter glow (no B yet).
  static Future<void> showDamagedSampleA(ArSceneEngine engine) async {
    await _stayOnTabletop(engine);
    await engine.setSecondaryModel(null);
    await engine.replaceModelAtActiveAnchor(ArAssetRegistry.sampleADamaged);
    await engine.setNodeScale(ArNodeIds.primary, comparisonScale);
    await engine.setNodeScale(ArNodeIds.sampleA, comparisonScale);
    await Misi1Visuals.glowOrganelles(engine);
  }

  /// Step `show_both_samples` — Sampel A + Sampel B side-by-side.
  static Future<void> showBothSamples(ArSceneEngine engine) async {
    await _pairSamples(engine, primaryModel: ArAssetRegistry.sampleA);
    await engine.setMaterialHighlight(ArNodeIds.primary, enabled: false);
    await engine.showAnchoredOverlayEffect(ArOverlayEffect.comparisonLabels);
  }

  /// Step `highlight_cell_wall` — green contour on dinding sel (A), B stays.
  static Future<void> highlightCellWall(ArSceneEngine engine) async {
    await _pairSamples(engine, primaryModel: ArAssetRegistry.dindingSelSolo);
    await engine.setMaterialHighlight(ArNodeIds.cellWall, enabled: true);
    await engine.showAnchoredOverlayEffect(ArOverlayEffect.cellWallHighlight);
  }

  /// Step `mark_sample_b` — restore A+B pair + red X on B (no cell wall).
  static Future<void> markSampleB(ArSceneEngine engine) async {
    await _pairSamples(engine, primaryModel: ArAssetRegistry.sampleA);
    await engine.setMaterialHighlight(ArNodeIds.primary, enabled: false);
    await engine.showAnchoredOverlayEffect(
      ArOverlayEffect.missingStructureCross,
    );
  }

  /// Step `show_force_arrows` — stay on dinding/sampleA + force-arrows overlay.
  ///
  /// Wave 1 bug: registry mapped this step → [ArAssetRegistry.mitokondriaSolo].
  /// Must remain dinding sel (wall resisting pressure) with Sample B secondary.
  static Future<void> showForceArrows(ArSceneEngine engine) async {
    await _pairSamples(engine, primaryModel: ArAssetRegistry.dindingSelSolo);
    await engine.setMaterialHighlight(ArNodeIds.cellWall, enabled: true);
    await engine.showAnchoredOverlayEffect(ArOverlayEffect.forceArrows);
  }
}
