/// Pure-Dart scoring engine for Cell Forensic evaluations (E5/E9).
///
/// Responsibilities:
/// - Auto-score objective questions by exact/normalized answer match.
/// - Produce only *suggested* scores for essay/rubric questions; those always
///   require teacher review and never become final automatically.
/// - Aggregate component scores into a weighted total (see [ScoringWeights]).
///
/// Anti-hallucination policy (`docs/09_LKPD_EVALUATION_SCORING.md`): the engine
/// never asserts the identity of the provisional organelles (Organel X/Y) or
/// the numbered membrane parts as facts. Objective questions keyed on those
/// provisional tokens — or lacking a confirmed key — are deferred to teacher
/// review instead of being auto-scored.
library;

import 'package:cell_forensic/domain/scoring/scoring_weights.dart';

/// The kind of question being scored.
enum QuestionType {
  /// Closed question auto-scored against a confirmed [ScoringQuestion.correctAnswer].
  objective,

  /// Open/rubric question. AI may suggest a score but a teacher must review it.
  essay;

  /// Maps a stored `question_type` value. Unknown values default to [essay]
  /// so ambiguous items are conservatively routed through teacher review.
  static QuestionType fromName(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'objective':
      case 'objektif':
        return QuestionType.objective;
      case 'essay':
      case 'esai':
      case 'rubric':
      case 'rubrik':
        return QuestionType.essay;
      default:
        return QuestionType.essay;
    }
  }
}

/// A question definition used for scoring.
class ScoringQuestion {
  const ScoringQuestion({
    required this.id,
    required this.type,
    required this.maxScore,
    this.correctAnswer,
    this.rubric,
  });

  final String id;
  final QuestionType type;

  /// Maximum attainable raw score for this question.
  final num maxScore;

  /// Confirmed correct answer for objective questions. When null/empty or a
  /// provisional token, objective auto-scoring is disabled.
  final String? correctAnswer;

  /// Human-readable rubric text for essay questions (not auto-interpreted).
  final String? rubric;
}

/// Result of scoring a single answer.
class AnswerScore {
  const AnswerScore({
    required this.questionId,
    required this.suggestedScore,
    required this.maxScore,
    required this.requiresTeacherReview,
    this.teacherScore,
    this.confidence,
  });

  final String questionId;

  /// AI/auto suggested score, always clamped to `0..maxScore`.
  final num suggestedScore;
  final num maxScore;

  /// When true, [finalScore] stays null until a teacher provides a score.
  final bool requiresTeacherReview;

  /// Teacher-provided score, if any (clamped when used for [finalScore]).
  final num? teacherScore;

  /// Optional model confidence, clamped to `0..1`.
  final double? confidence;

  /// The authoritative score for aggregation.
  ///
  /// - Teacher score wins whenever present (clamped to `0..maxScore`).
  /// - Otherwise null when the item still needs review (essays / provisional).
  /// - Otherwise the auto-scored suggestion for objective items.
  num? get finalScore {
    final teacher = teacherScore;
    if (teacher != null) return teacher.clamp(0, maxScore);
    if (requiresTeacherReview) return null;
    return suggestedScore.clamp(0, maxScore);
  }
}

/// A per-component score contributing to the weighted total.
class ComponentResult {
  const ComponentResult({
    required this.component,
    required this.rawScore,
    required this.maxScore,
    this.pendingReview = false,
  });

  final ScoreComponent component;
  final num rawScore;
  final num maxScore;

  /// True when the component still contains answers awaiting teacher review.
  final bool pendingReview;

  /// [rawScore] clamped to `0..maxScore`.
  num get clampedScore => rawScore.clamp(0, maxScore);

  /// Fraction of the component earned, in `0..1` (0 when [maxScore] <= 0).
  double get ratio => maxScore <= 0 ? 0 : clampedScore / maxScore;
}

/// The aggregated, weighted total for a group.
class TotalScore {
  const TotalScore({
    required this.value,
    required this.maxValue,
    required this.hasPendingReview,
  });

  /// Weighted total, clamped to `0..maxValue`.
  final double value;

  /// Maximum attainable total (100 for the official weights).
  final int maxValue;

  /// True when any aggregated component is still awaiting teacher review.
  final bool hasPendingReview;
}

/// Deterministic, dependency-free scoring engine.
class ScoringEngine {
  const ScoringEngine();

  /// Answer keys that must never be auto-asserted as facts until the final
  /// assets/diagrams are confirmed (see doc "Catatan kunci").
  static const Set<String> provisionalAnswerTokens = {
    'organel x',
    'organel y',
    'membran 1',
    'membran 2',
    'membran nomor 1',
    'membran nomor 2',
    'bagian 1',
    'bagian 2',
  };

  /// Normalizes free text for comparison: trim + lowercase.
  static String normalize(String value) => value.trim().toLowerCase();

  /// Scores a single [answerText] against [question].
  AnswerScore scoreAnswer({
    required ScoringQuestion question,
    required String answerText,
    num? teacherScore,
    num? aiSuggestedScore,
    double? aiConfidence,
  }) {
    switch (question.type) {
      case QuestionType.objective:
        return _scoreObjective(
          question: question,
          answerText: answerText,
          teacherScore: teacherScore,
        );
      case QuestionType.essay:
        return _scoreEssay(
          question: question,
          teacherScore: teacherScore,
          aiSuggestedScore: aiSuggestedScore,
          aiConfidence: aiConfidence,
        );
    }
  }

  AnswerScore _scoreObjective({
    required ScoringQuestion question,
    required String answerText,
    num? teacherScore,
  }) {
    final key = question.correctAnswer;

    // Anti-hallucination: no confirmed key, or a provisional identity token →
    // do not assert correctness. Defer to teacher review with a 0 suggestion.
    if (key == null || !_isConfirmedKey(key)) {
      return AnswerScore(
        questionId: question.id,
        suggestedScore: 0,
        maxScore: question.maxScore,
        requiresTeacherReview: true,
        teacherScore: teacherScore,
      );
    }

    final correct = normalize(answerText) == normalize(key);
    return AnswerScore(
      questionId: question.id,
      suggestedScore: correct ? question.maxScore : 0,
      maxScore: question.maxScore,
      requiresTeacherReview: false,
      teacherScore: teacherScore,
      confidence: 1.0,
    );
  }

  AnswerScore _scoreEssay({
    required ScoringQuestion question,
    num? teacherScore,
    num? aiSuggestedScore,
    double? aiConfidence,
  }) {
    final suggested = (aiSuggestedScore ?? 0).clamp(0, question.maxScore);
    return AnswerScore(
      questionId: question.id,
      suggestedScore: suggested,
      maxScore: question.maxScore,
      requiresTeacherReview: true,
      teacherScore: teacherScore,
      confidence: aiConfidence?.clamp(0.0, 1.0).toDouble(),
    );
  }

  bool _isConfirmedKey(String key) {
    final normalized = normalize(key);
    if (normalized.isEmpty) return false;
    for (final token in provisionalAnswerTokens) {
      if (normalized.contains(token)) return false;
    }
    return true;
  }

  /// Aggregates [components] into a weighted [TotalScore].
  ///
  /// Uses [ScoringWeights.official] unless [weights] is provided. Each
  /// component contributes `ratio * weight`, and the result is clamped so the
  /// total never exceeds [ScoringWeights.total].
  TotalScore aggregate(
    List<ComponentResult> components, {
    ScoringWeights? weights,
  }) {
    final resolved = weights ?? ScoringWeights.official;
    var total = 0.0;
    var pending = false;
    for (final component in components) {
      total += component.ratio * resolved.weightFor(component.component);
      pending = pending || component.pendingReview;
    }
    final max = resolved.total;
    return TotalScore(
      value: total.clamp(0.0, max.toDouble()),
      maxValue: max,
      hasPendingReview: pending,
    );
  }
}
