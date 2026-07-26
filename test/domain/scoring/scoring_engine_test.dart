import 'package:cell_forensic/domain/scoring/scoring_engine.dart';
import 'package:cell_forensic/domain/scoring/scoring_weights.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = ScoringEngine();

  group('QuestionType.fromName', () {
    test('memetakan nama yang dikenal dan tidak dikenal', () {
      expect(QuestionType.fromName('objective'), QuestionType.objective);
      expect(QuestionType.fromName('essay'), QuestionType.essay);
      expect(QuestionType.fromName('rubric'), QuestionType.essay);
      expect(QuestionType.fromName(null), QuestionType.essay);
    });
  });

  group('auto-score objektif', () {
    const question = ScoringQuestion(
      id: 'q1',
      type: QuestionType.objective,
      maxScore: 15,
      correctAnswer: 'Sel Tumbuhan',
    );

    test('jawaban cocok (setelah trim+lowercase) mendapat skor maksimum', () {
      final result = engine.scoreAnswer(
        question: question,
        answerText: '  sel tumbuhan ',
      );

      expect(result.suggestedScore, 15);
      expect(result.finalScore, 15);
      expect(result.requiresTeacherReview, isFalse);
      expect(result.confidence, 1.0);
    });

    test('jawaban salah mendapat skor 0', () {
      final result = engine.scoreAnswer(
        question: question,
        answerText: 'sel hewan',
      );

      expect(result.suggestedScore, 0);
      expect(result.finalScore, 0);
      expect(result.requiresTeacherReview, isFalse);
    });

    test('skor guru menimpa auto-score objektif', () {
      final result = engine.scoreAnswer(
        question: question,
        answerText: 'sel tumbuhan',
        teacherScore: 10,
      );

      expect(result.suggestedScore, 15);
      expect(result.finalScore, 10);
    });
  });

  group('esai/rubrik tidak auto-final', () {
    const question = ScoringQuestion(
      id: 'q2',
      type: QuestionType.essay,
      maxScore: 20,
      rubric: 'Argumen berbasis bukti dinding sel dan organel.',
    );

    test('hanya mengembalikan skor saran dan tetap butuh review guru', () {
      final result = engine.scoreAnswer(
        question: question,
        answerText: 'Sampel A adalah sel tumbuhan karena memiliki dinding sel.',
        aiSuggestedScore: 12,
        aiConfidence: 0.6,
      );

      expect(result.suggestedScore, 12);
      expect(result.requiresTeacherReview, isTrue);
      expect(result.finalScore, isNull);
      expect(result.confidence, 0.6);
    });

    test('final_score berasal dari skor guru ketika tersedia', () {
      final result = engine.scoreAnswer(
        question: question,
        answerText: 'jawaban esai',
        aiSuggestedScore: 12,
        teacherScore: 18,
      );

      expect(result.suggestedScore, 12);
      expect(result.finalScore, 18);
    });
  });

  group('anti-halusinasi', () {
    test('objektif dengan kunci jawaban provisional (Organel X/Y) tidak '
        'ditetapkan sebagai fakta, hanya saran + review', () {
      const question = ScoringQuestion(
        id: 'q3',
        type: QuestionType.objective,
        maxScore: 10,
        correctAnswer: 'Organel X',
      );

      final result = engine.scoreAnswer(
        question: question,
        answerText: 'organel x',
      );

      expect(result.requiresTeacherReview, isTrue);
      expect(result.suggestedScore, 0);
      expect(result.finalScore, isNull);
    });

    test('objektif tanpa kunci jawaban terkonfirmasi butuh review guru', () {
      const question = ScoringQuestion(
        id: 'q4',
        type: QuestionType.objective,
        maxScore: 10,
        correctAnswer: '   ',
      );

      final result = engine.scoreAnswer(
        question: question,
        answerText: 'apa pun',
      );

      expect(result.requiresTeacherReview, isTrue);
      expect(result.suggestedScore, 0);
    });

    test('token membran nomor 1/2 diperlakukan sebagai provisional', () {
      const question = ScoringQuestion(
        id: 'q5',
        type: QuestionType.objective,
        maxScore: 10,
        correctAnswer: 'Membran 1',
      );

      final result = engine.scoreAnswer(
        question: question,
        answerText: 'membran 1',
      );

      expect(result.requiresTeacherReview, isTrue);
      expect(result.suggestedScore, 0);
    });
  });

  group('guard skor & confidence', () {
    const question = ScoringQuestion(
      id: 'q6',
      type: QuestionType.essay,
      maxScore: 20,
    );

    test('skor saran di-clamp ke rentang 0..maxScore', () {
      final tooHigh = engine.scoreAnswer(
        question: question,
        answerText: 'x',
        aiSuggestedScore: 999,
      );
      final tooLow = engine.scoreAnswer(
        question: question,
        answerText: 'x',
        aiSuggestedScore: -5,
      );

      expect(tooHigh.suggestedScore, 20);
      expect(tooLow.suggestedScore, 0);
    });

    test('final_score dari guru tidak boleh melebihi maxScore', () {
      final result = engine.scoreAnswer(
        question: question,
        answerText: 'x',
        teacherScore: 50,
      );

      expect(result.finalScore, 20);
    });

    test('confidence di-clamp ke rentang 0..1', () {
      final high = engine.scoreAnswer(
        question: question,
        answerText: 'x',
        aiSuggestedScore: 5,
        aiConfidence: 3.4,
      );
      final low = engine.scoreAnswer(
        question: question,
        answerText: 'x',
        aiSuggestedScore: 5,
        aiConfidence: -1,
      );

      expect(high.confidence, 1.0);
      expect(low.confidence, 0.0);
    });
  });

  group('agregasi tertimbang', () {
    test('menghitung total tertimbang dengan bobot resmi', () {
      final total = engine.aggregate([
        const ComponentResult(
          component: ScoreComponent.dataLaboratorium,
          rawScore: 20,
          maxScore: 25,
        ),
        const ComponentResult(
          component: ScoreComponent.identifikasiSampel,
          rawScore: 15,
          maxScore: 15,
        ),
        const ComponentResult(
          component: ScoreComponent.hipotesis,
          rawScore: 5,
          maxScore: 10,
        ),
        const ComponentResult(
          component: ScoreComponent.pos1,
          rawScore: 15,
          maxScore: 15,
        ),
        const ComponentResult(
          component: ScoreComponent.pos2,
          rawScore: 10,
          maxScore: 20,
        ),
        const ComponentResult(
          component: ScoreComponent.pos3,
          rawScore: 15,
          maxScore: 15,
        ),
      ]);

      // 0.8*25 + 1*15 + 0.5*10 + 1*15 + 0.5*20 + 1*15 = 20+15+5+15+10+15 = 80
      expect(total.value, closeTo(80, 1e-9));
      expect(total.maxValue, 100);
      expect(total.hasPendingReview, isFalse);
    });

    test('skor komponen di-clamp 0..maxScore sebelum ditimbang', () {
      final total = engine.aggregate([
        const ComponentResult(
          component: ScoreComponent.dataLaboratorium,
          rawScore: 999, // melebihi max 25
          maxScore: 25,
        ),
      ]);

      // hanya satu komponen: rasio 1.0 * 25 = 25
      expect(total.value, closeTo(25, 1e-9));
    });

    test('total tidak pernah melebihi 100', () {
      final total = engine.aggregate([
        for (final c in ScoreComponent.values)
          ComponentResult(component: c, rawScore: 999, maxScore: 10),
      ]);

      expect(total.value, lessThanOrEqualTo(100));
    });

    test('menandai review tertunda bila ada komponen pending', () {
      final total = engine.aggregate([
        const ComponentResult(
          component: ScoreComponent.hipotesis,
          rawScore: 5,
          maxScore: 10,
          pendingReview: true,
        ),
      ]);

      expect(total.hasPendingReview, isTrue);
    });
  });
}
