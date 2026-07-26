/// Whitelist + validation for AI-driven AR actions (E11 H–J).
///
/// Unknown actions become [none]. Mission mismatch and low confidence also
/// force [none] so the mission never jumps to unrelated visuals.
abstract final class ArActionWhitelist {
  static const none = 'none';
  static const minConfidence = 0.6;

  static const allowed = <String>{
    none,
    'focus_sample_a',
    'focus_sample_b',
    'highlight_chloroplast',
    'show_damaged_chloroplast',
    'show_vacuole_damage',
    'focus_membrane',
    'show_membrane_damage',
    'show_water_leak',
    'compare_samples',
    'highlight_cell_wall',
    'show_force_arrows',
    'reset_scene',
  };

  /// Mission numbers (1–3) each action may target. [reset_scene] is universal.
  static const missionForAction = <String, Set<int>>{
    'focus_sample_a': {1},
    'highlight_chloroplast': {1},
    'show_damaged_chloroplast': {1},
    'show_vacuole_damage': {1},
    'focus_sample_b': {2},
    'focus_membrane': {2},
    'show_membrane_damage': {2},
    'show_water_leak': {2},
    'compare_samples': {3},
    'highlight_cell_wall': {3},
    'show_force_arrows': {3},
    'reset_scene': {1, 2, 3},
  };

  static bool isAllowed(String action) => allowed.contains(action);

  /// Normalizes [arAction]; unknown → [none].
  static String sanitize(String? arAction) {
    final value = (arAction ?? none).trim().toLowerCase();
    if (!isAllowed(value)) return none;
    return value;
  }

  /// Returns [none] when confidence is low, mission mismatches, or action
  /// unknown. Otherwise returns the sanitized action.
  static String resolve({
    required String? arAction,
    required int missionNumber,
    required double confidence,
  }) {
    final action = sanitize(arAction);
    if (action == none) return none;
    if (confidence < minConfidence) return none;
    final allowedMissions = missionForAction[action];
    if (allowedMissions == null || !allowedMissions.contains(missionNumber)) {
      return none;
    }
    return action;
  }
}
