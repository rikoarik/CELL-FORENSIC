import 'package:cell_forensic/domain/scoring/scoring_weights.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bobot resmi sesuai dokumen dan totalnya 100', () {
    final weights = ScoringWeights.official;

    expect(weights.weightFor(ScoreComponent.dataLaboratorium), 25);
    expect(weights.weightFor(ScoreComponent.identifikasiSampel), 15);
    expect(weights.weightFor(ScoreComponent.hipotesis), 10);
    expect(weights.weightFor(ScoreComponent.pos1), 15);
    expect(weights.weightFor(ScoreComponent.pos2), 20);
    expect(weights.weightFor(ScoreComponent.pos3), 15);
    expect(weights.total, 100);
  });

  test('semua komponen resmi memiliki bobot', () {
    final weights = ScoringWeights.official;

    for (final component in ScoreComponent.values) {
      expect(weights.weightFor(component), greaterThan(0));
    }
  });

  test('menolak konfigurasi bobot yang tidak berjumlah 100', () {
    expect(
      () => ScoringWeights({
        ScoreComponent.dataLaboratorium: 25,
        ScoreComponent.identifikasiSampel: 15,
        ScoreComponent.hipotesis: 10,
        ScoreComponent.pos1: 15,
        ScoreComponent.pos2: 20,
        ScoreComponent.pos3: 10, // total 95
      }),
      throwsArgumentError,
    );
  });

  test('menolak bobot negatif', () {
    expect(
      () => ScoringWeights({
        ScoreComponent.dataLaboratorium: 120,
        ScoreComponent.identifikasiSampel: -20,
        ScoreComponent.hipotesis: 0,
        ScoreComponent.pos1: 0,
        ScoreComponent.pos2: 0,
        ScoreComponent.pos3: 0,
      }),
      throwsArgumentError,
    );
  });
}
