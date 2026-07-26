import 'package:cell_forensic/ar/ar_scene_engine.dart';

/// Misi 1–only visual helpers (PDF Scene 2 / SEQ-MISI-1).
///
/// Keeps the existing tabletop [ARPlaneAnchor] — never re-places. Approximates
/// PDF beats with GLB swap + [ArOverlayEffect] because `ar_flutter_plugin_2`
/// has no AR camera dolly, material glow, or animation clips.
///
/// **Engine APIs desired (owned by ar-engine-agent, not called here yet):**
/// - `smoothZoomToTarget` / `focusOnTarget` — true dolly through cell wall
/// - native yellow material on chloroplast — today: Flutter yellow glow overlay
abstract final class Misi1Visuals {
  /// PDF yellow chloroplast glow (overlay painters should use this).
  static const yellowGlow = ColorValue(0xFFFACC15);

  /// Focus Sampel A on the lab table; clear comparison / secondary.
  static Future<void> focusSampleA(ArSceneEngine engine) async {
    await engine.setSecondaryModel(null);
    await engine.showNode(ArNodeIds.primary);
    await engine.showNode(ArNodeIds.labTable);
    await engine.hideNode(ArNodeIds.sampleB);
    await engine.setNodeScale(ArNodeIds.primary, ArVec3.one);
    await engine.setNodeScale(ArNodeIds.chloroplast, ArVec3.one);
    await engine.setNodeScale(ArNodeIds.vacuole, ArVec3.one);
    await engine.setNodePosition(ArNodeIds.primary, ArVec3.zero);
    await engine.setMaterialHighlight(ArNodeIds.sampleA, enabled: true);
    await engine.setOpacity(1);
    await engine.showAnchoredOverlayEffect(ArOverlayEffect.none);
    // Registry maps this step → sampleA. Lab table path is never cleared here.
  }

  /// Smooth zoom-through-wall approximation toward kloroplas + vakuola.
  ///
  /// Live AR: scale + slight lift on the **same** primary node (no re-anchor).
  /// Fallback ModelViewer: pair with [ArAssetRegistry.cameraOrbitForStep].
  /// True AR dolly needs engine `smoothZoomToTarget` (Wave 2 Engine API).
  static Future<void> zoomInternal(ArSceneEngine engine) async {
    await engine.setSecondaryModel(null);
    await engine.showNode(ArNodeIds.primary);
    // Stay on Sample A AllInOne so both organelles remain in-frame (GAP-6).
    await engine.setNodeScale(
      ArNodeIds.primary,
      const ArVec3(1.55, 1.55, 1.55),
    );
    // Slight rise = “through wall” framing without leaving the tabletop.
    await engine.setNodePosition(
      ArNodeIds.primary,
      const ArVec3(0, 0.04, 0),
    );
    await engine.setMaterialHighlight(ArNodeIds.chloroplast, enabled: true);
    await engine.setNodeScale(
      ArNodeIds.chloroplast,
      const ArVec3(0.92, 0.92, 0.92),
    );
    await engine.setNodeScale(
      ArNodeIds.vacuole,
      const ArVec3(0.88, 0.88, 0.88),
    );
    // Soft focus only — yellow glow reserved for [glowOrganelles].
    await engine.showAnchoredOverlayEffect(ArOverlayEffect.none);
    await engine.setOpacity(1);
  }

  /// Yellow glow + visibly shrunk / damaged chloroplast (KlooroPlas_Solo).
  ///
  /// Overlay [ArOverlayEffect.chloroplastHighlight] must paint
  /// [yellowGlow] (Wave 2 Overlays). Native material glow is unavailable.
  static Future<void> glowOrganelles(ArSceneEngine engine) async {
    await engine.setSecondaryModel(null);
    await engine.setMaterialHighlight(ArNodeIds.chloroplast, enabled: true);
    await engine.setNodeScale(
      ArNodeIds.chloroplast,
      const ArVec3(0.72, 0.72, 0.72),
    );
    await engine.setNodeScale(
      ArNodeIds.primary,
      const ArVec3(1.25, 1.25, 1.25),
    );
    await engine.setNodePosition(
      ArNodeIds.primary,
      const ArVec3(0, 0.02, 0),
    );
    await engine.setOpacity(1);
    await engine.showAnchoredOverlayEffect(
      ArOverlayEffect.chloroplastHighlight,
    );
  }

  /// Deflated giant vacuole (VakolaMain_Solo) — end of SEQ-MISI-1 (no M2).
  static Future<void> playShrinkAnimation(ArSceneEngine engine) async {
    await engine.setSecondaryModel(null);
    await engine.setMaterialHighlight(ArNodeIds.vacuole, enabled: true);
    await engine.setNodeScale(
      ArNodeIds.vacuole,
      const ArVec3(0.55, 0.55, 0.55),
    );
    await engine.setNodeScale(
      ArNodeIds.primary,
      const ArVec3(1.2, 1.2, 1.2),
    );
    await engine.setNodePosition(
      ArNodeIds.primary,
      const ArVec3(0, 0.02, 0),
    );
    await engine.setOpacity(0.82);
    await engine.showAnchoredOverlayEffect(ArOverlayEffect.vacuoleDamage);
  }
}

/// Tiny color holder so M1 helpers do not depend on Flutter `Color`.
class ColorValue {
  const ColorValue(this.argb);
  final int argb;
}
