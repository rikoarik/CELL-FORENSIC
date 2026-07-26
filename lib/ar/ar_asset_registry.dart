import 'package:cell_forensic/ar/ar_asset_manifest.dart';
import 'package:cell_forensic/ar/organelle_label_map.dart';

/// Maps mission / sequence codes to GLB asset paths under `assets/ar_models/`.
///
/// Paths match the audited files in `docs/10_ASSET_INVENTORY_AUDIT.md` and the
/// local folder layout. Prefer AllInOne / solo models without spaces in the
/// filename so AR copy-to-disk and Model Viewer URLs stay reliable.
///
/// Full inventory: [ArAssetManifest.allAssets]. Labels: [OrganelleLabelMap].
class ArAssetRegistry {
  const ArAssetRegistry._();

  /// Inventory size after E0-01 (not the aspirational “30”).
  static int get inventoriedCount => ArAssetManifest.allAssets.length;

  static bool get organelleLabelsSafe =>
      OrganelleLabelMap.assertProvisionalRules();

  static const mejaLab = 'assets/ar_models/Meja/MejaLab.glb';
  static const sampleA =
      'assets/ar_models/SelTumbuhan/SelTumbuhanRework_AllInOne.glb';
  static const sampleB = 'assets/ar_models/SelHewan/SelHewanBroken.glb';

  static const nukleusSolo =
      'assets/ar_models/SelTumbuhan/SelTumbuhhanSolo/Nukleus_Solo.glb';
  static const kloroplasSolo =
      'assets/ar_models/SelTumbuhan/SelTumbuhhanSolo/KlooroPlas_Solo.glb';
  static const dindingSelSolo =
      'assets/ar_models/SelTumbuhan/SelTumbuhhanSolo/DindingSel_Solo.glb';
  static const mitokondriaSolo =
      'assets/ar_models/SelTumbuhan/SelTumbuhhanSolo/Mitokondria_Solo.glb';
  static const vakuolaMainSolo =
      'assets/ar_models/SelTumbuhan/SelTumbuhhanSolo/VakolaMain_Solo.glb';
  static const rantaiProtein =
      'assets/ar_models/SelHewan/RantaiProtein/RantaiProtein.glb';

  /// Primary GLB for a mission scene (fallback 3D viewer + AR placement).
  static String primaryModelForMission(String missionCode) {
    return switch (missionCode) {
      'MISI-1' => sampleA,
      'MISI-2' => sampleB,
      'MISI-3' => sampleA,
      _ => sampleA,
    };
  }

  /// Model swap for a sequence step. Returns null to keep the mission primary.
  static String? modelForStep(String missionCode, String? stepCode) {
    if (stepCode == null) return null;
    return switch ((missionCode, stepCode)) {
      // Misi 1 — investigasi internal Sampel A (tumbuhan).
      // zoom_internal stays on the intact plant cell so kloroplas + vakuola
      // remain in-frame (do NOT swap to nukleusSolo — GAP-6).
      ('MISI-1', 'focus_sample_a') => sampleA,
      ('MISI-1', 'zoom_internal') => sampleA,
      ('MISI-1', 'glow_organelles') => kloroplasSolo,
      ('MISI-1', 'play_shrink_animation') => vakuolaMainSolo,

      // Misi 2 — membran Sampel B (hewan)
      ('MISI-2', 'focus_sample_b') => sampleB,
      ('MISI-2', 'zoom_membrane') => sampleB,
      ('MISI-2', 'show_torn_bilayer') => rantaiProtein,
      ('MISI-2', 'play_leak_particles') => rantaiProtein,

      // Misi 3 — bandingkan lapisan terluar (never mitokondriaSolo on arrows).
      ('MISI-3', 'show_both_samples') => sampleA,
      ('MISI-3', 'highlight_cell_wall') => dindingSelSolo,
      ('MISI-3', 'mark_sample_b') => sampleA,
      // Wave 1 bugfix: stay dinding/sampleA — not mitokondriaSolo.
      ('MISI-3', 'show_force_arrows') => dindingSelSolo,

      _ => null,
    };
  }

  /// Model Viewer camera orbit hint per step (drag/pinch still enabled).
  ///
  /// Misi 1 orbits pull closer for “through wall” framing (fallback only —
  /// live AR approximates zoom via [Misi1Visuals] node scale, not dolly).
  static String cameraOrbitForStep(String? stepCode) {
    return switch (stepCode) {
      // M1: through-wall → organelle focus → yellow glow → deflated vacuole
      'zoom_internal' => '0deg 58deg 1.05m',
      'glow_organelles' => '35deg 50deg 1.35m',
      'play_shrink_animation' => '25deg 65deg 1.25m',
      'focus_sample_a' => '0deg 72deg 2.0m',
      'zoom_membrane' => '0deg 65deg 1.4m',
      'highlight_cell_wall' => '40deg 55deg 1.8m',
      'show_torn_bilayer' || 'play_leak_particles' => '10deg 80deg 1.2m',
      'show_both_samples' || 'show_force_arrows' => '0deg 70deg 2.8m',
      _ => '0deg 75deg 2.2m',
    };
  }

  /// Human-readable Indonesian label for the active mode.
  static String modeLabel({required bool useAr}) =>
      useAr ? 'Mode AR (Kamera)' : 'Mode 3D Viewer';
}
