import 'package:cell_forensic/ar/ar_asset_manifest.dart';
import 'package:cell_forensic/ar/organelle_label_map.dart';

/// Maps mission / sequence codes to GLB asset paths under `assets/ar_models/`.
///
/// Web + AR use the same scene files in `assets/ar_models/scenes/`.
/// Idle/default uses [scene1] (`scene-1.glb`).
class ArAssetRegistry {
  const ArAssetRegistry._();

  static int get inventoriedCount => ArAssetManifest.allAssets.length;

  static bool get organelleLabelsSafe =>
      OrganelleLabelMap.assertProvisionalRules();

  /// Idle scene (meja + 2 sel).
  static const scene1 = 'assets/ar_models/scene-1.glb';

  /// Lab table / tray — same as idle scene (merged GLB).
  static const mejaLab = scene1;
  static const tempatUji = scene1;

  /// Per-mission / per-step scene swaps (full scene, same as web).
  static const sceneMisi1Kloroplas =
      'assets/ar_models/scenes/scene-misi1-kloroplas.glb';
  static const sceneMisi1Vakuola =
      'assets/ar_models/scenes/scene-misi1-vakuola.glb';
  static const sceneMisi2Membran =
      'assets/ar_models/scenes/scene-misi2-membran.glb';
  static const sceneMisi3Dinding =
      'assets/ar_models/scenes/scene-misi3-dinding.glb';

  /// Primary GLB for a mission (before a specific sequence step fires).
  static String primaryModelForMission(String missionCode) {
    return switch (missionCode) {
      'MISI-1' => scene1,
      'MISI-2' => sceneMisi2Membran,
      'MISI-3' => sceneMisi3Dinding,
      _ => scene1,
    };
  }

  /// Model swap for a sequence step. Returns null to keep the mission primary.
  static String? modelForStep(String missionCode, String? stepCode) {
    if (stepCode == null) return null;
    return switch ((missionCode, stepCode)) {
      ('MISI-1', 'glow_organelles') => sceneMisi1Kloroplas,
      ('MISI-1', 'play_shrink_animation') => sceneMisi1Vakuola,
      ('MISI-1', _) => scene1,
      ('MISI-2', _) => sceneMisi2Membran,
      ('MISI-3', _) => sceneMisi3Dinding,
      _ => null,
    };
  }

  // Aliases — old call sites still reference these names.
  static const sampleA = scene1;
  static const sampleAViewer = scene1;
  static const sampleADamaged = sceneMisi1Kloroplas;
  static const sampleB = sceneMisi2Membran;
  static const kloroplasSolo = sceneMisi1Kloroplas;
  static const vakuolaMainSolo = sceneMisi1Vakuola;
  static const dindingSelSolo = sceneMisi3Dinding;
  static const rantaiProtein = sceneMisi2Membran;
  static const nukleusSolo = scene1;
  static const mitokondriaSolo = scene1;

  /// Used by [mission_screen] when picking Sample A path for lab init.
  static String sampleAFor({required bool liveAr}) => scene1;

  /// Model Viewer camera orbit hint per step.
  static String cameraOrbitForStep(String? stepCode) {
    return switch (stepCode) {
      'zoom_internal' => '0deg 58deg 75%',
      'glow_organelles' => '35deg 50deg 90%',
      'play_shrink_animation' => '25deg 65deg 85%',
      'focus_sample_a' => '0deg 72deg 105%',
      'zoom_membrane' => '0deg 65deg 80%',
      'highlight_cell_wall' => '40deg 55deg 100%',
      'show_torn_bilayer' || 'play_leak_particles' => '10deg 80deg 80%',
      'show_damaged_sample_a' => '20deg 55deg 95%',
      'show_both_samples' || 'show_force_arrows' => '0deg 70deg 120%',
      _ => '0deg 75deg 105%',
    };
  }

  static String modeLabel({required bool useAr}) =>
      useAr ? 'Mode AR (Kamera)' : 'Mode 3D Viewer';
}
