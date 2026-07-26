/// Weighted evaluation components for the LKPD score.
///
/// Official weights come from `docs/09_LKPD_EVALUATION_SCORING.md` and must sum
/// to 100. Weights are expressed as whole-percentage contributions to the total.
library;

/// A weighted component of the overall evaluation score.
enum ScoreComponent {
  dataLaboratorium,
  identifikasiSampel,
  hipotesis,
  pos1,
  pos2,
  pos3,
}

/// Immutable, validated set of component weights.
///
/// The constructor enforces the two invariants required by the scoring spec:
/// every weight is non-negative and the components sum to exactly 100.
class ScoringWeights {
  ScoringWeights(Map<ScoreComponent, int> weights)
    : _weights = Map.unmodifiable(weights) {
    var total = 0;
    for (final entry in _weights.entries) {
      if (entry.value < 0) {
        throw ArgumentError.value(
          entry.value,
          entry.key.name,
          'Bobot komponen tidak boleh negatif',
        );
      }
      total += entry.value;
    }
    if (total != 100) {
      throw ArgumentError.value(
        total,
        'weights',
        'Total bobot komponen harus 100',
      );
    }
  }

  /// Recommended weights from the LKPD scoring document.
  static final ScoringWeights official = ScoringWeights({
    ScoreComponent.dataLaboratorium: 25,
    ScoreComponent.identifikasiSampel: 15,
    ScoreComponent.hipotesis: 10,
    ScoreComponent.pos1: 15,
    ScoreComponent.pos2: 20,
    ScoreComponent.pos3: 15,
  });

  final Map<ScoreComponent, int> _weights;

  /// Weight assigned to [component], or 0 when it is not configured.
  int weightFor(ScoreComponent component) => _weights[component] ?? 0;

  /// Sum of all configured weights (always 100 for a valid instance).
  int get total => _weights.values.fold(0, (sum, value) => sum + value);
}
