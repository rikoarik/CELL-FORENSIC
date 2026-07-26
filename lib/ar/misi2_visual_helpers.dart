import 'package:cell_forensic/ar/ar_asset_registry.dart';
import 'package:cell_forensic/ar/ar_scene_engine.dart';

/// Misi 2–only tabletop choreography helpers (PDF Scene 2 / SEQ-MISI-2).
///
/// PDF beats: focus Sampel B outer → zoom bilayer (intact) → torn bilayer →
/// dark-blue water particles exit from the membrane area — always on the same
/// lab-table anchor (never re-place / fullscreen takeover).
///
/// Native particle emitters are unavailable (`ar_flutter_plugin_2`); leak uses
/// [ArOverlayEffect.waterLeak] anchored via [ArNodeIds.membrane] highlight.
abstract final class Misi2VisualHelpers {
  /// Mild focus scale — Sample B outer membrane in frame.
  static const outerFocusScale = ArVec3(1.05, 1.05, 1.05);

  /// Zoom into the outer membrane / bilayer region.
  static const bilayerZoomScale = ArVec3(1.35, 1.35, 1.35);

  /// Close-up scale while the torn bilayer proxy is on stage.
  static const tornBilayerScale = ArVec3(1.5, 1.5, 1.5);

  /// Keeps the scene on the existing tabletop placement (no re-anchor).
  static Future<void> stayOnTabletop(ArSceneEngine engine) async {
    await engine.showNode(ArNodeIds.primary);
    await engine.showNode(ArNodeIds.labTable);
  }

  /// Step `focus_sample_b` — Sampel B outer layer, membrane highlighted.
  static Future<void> focusSampleBOuter(ArSceneEngine engine) async {
    await stayOnTabletop(engine);
    await engine.setSecondaryModel(null);
    await engine.replaceModelAtActiveAnchor(ArAssetRegistry.sampleB);
    await engine.setNodeScale(ArNodeIds.primary, outerFocusScale);
    await engine.setNodeScale(ArNodeIds.membrane, const ArVec3(1.1, 1.1, 1.1));
    await engine.focusOnTarget(ArNodeIds.membrane);
    await engine.setOpacity(1);
    await engine.showAnchoredOverlayEffect(ArOverlayEffect.none);
  }

  /// Step `zoom_membrane` — zoom bilayer while still **intact** (normal).
  ///
  /// Damage overlay is deferred to [showTornBilayer] so students see normal
  /// then torn, matching the PDF “diperbesar … lalu … robek” beat order.
  /// Uses [smoothZoomToTarget] so live AR receives real [nodeScale] updates.
  static Future<void> zoomIntactBilayer(ArSceneEngine engine) async {
    await stayOnTabletop(engine);
    await engine.setSecondaryModel(null);
    await engine.replaceModelAtActiveAnchor(ArAssetRegistry.sampleB);
    // Reset zoom baseline so factor maps to [bilayerZoomScale] exactly.
    await engine.setNodeScale(ArNodeIds.primary, ArVec3.one);
    await engine.focusOnTarget(ArNodeIds.membrane);
    await engine.smoothZoomToTarget(
      ArNodeIds.primary,
      factor: bilayerZoomScale.x,
      cameraOrbit: ArAssetRegistry.cameraOrbitForStep('zoom_membrane'),
    );
    await engine.setNodeScale(ArNodeIds.membrane, const ArVec3(1.25, 1.25, 1.25));
    await engine.setOpacity(1);
    await engine.showAnchoredOverlayEffect(ArOverlayEffect.none);
  }

  /// Step `show_torn_bilayer` — RantaiProtein proxy + membrane damage ring.
  static Future<void> showTornBilayer(ArSceneEngine engine) async {
    await stayOnTabletop(engine);
    await engine.setSecondaryModel(null);
    await engine.replaceModelAtActiveAnchor(ArAssetRegistry.rantaiProtein);
    await engine.setNodeScale(ArNodeIds.primary, tornBilayerScale);
    await engine.setNodeScale(ArNodeIds.membrane, const ArVec3(1.3, 1.3, 1.3));
    await engine.setMaterialHighlight(ArNodeIds.membrane, enabled: true);
    await engine.setOpacity(1);
    await engine.showAnchoredOverlayEffect(ArOverlayEffect.membraneDamage);
  }

  /// Step `play_leak_particles` — dark-blue water spray from membrane area.
  ///
  /// Keeps the torn bilayer model on stage; particles are a Flutter overlay
  /// painted at the membrane highlight target (not fullscreen).
  static Future<void> playMembraneLeakParticles(ArSceneEngine engine) async {
    await stayOnTabletop(engine);
    await engine.setSecondaryModel(null);
    await engine.replaceModelAtActiveAnchor(ArAssetRegistry.rantaiProtein);
    await engine.setNodeScale(ArNodeIds.primary, tornBilayerScale);
    await engine.setNodeScale(ArNodeIds.membrane, const ArVec3(1.3, 1.3, 1.3));
    // Highlight must be membrane so [ArSceneOverlayLayer] anchors the spray.
    await engine.setMaterialHighlight(ArNodeIds.membrane, enabled: true);
    await engine.setOpacity(1);
    await engine.showAnchoredOverlayEffect(ArOverlayEffect.waterLeak);
  }
}
