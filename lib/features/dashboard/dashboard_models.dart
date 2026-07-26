import 'package:cell_forensic/domain/entities.dart';
import 'package:cell_forensic/domain/scoring/scoring_engine.dart';

/// Mission progress row for a group (dashboard detail).
class DashboardMissionProgress {
  const DashboardMissionProgress({
    required this.missionCode,
    required this.missionTitle,
    required this.status,
    required this.arMode,
  });

  final String missionCode;
  final String missionTitle;
  final String status;
  final String arMode;
}

/// Investigation conclusion summary for a group.
class DashboardConclusion {
  const DashboardConclusion({
    required this.status,
    required this.sampleAIdentity,
    required this.sampleAReasoning,
    required this.sampleBIdentity,
    required this.sampleBReasoning,
    required this.groupHypothesis,
  });

  final String status;
  final String sampleAIdentity;
  final String sampleAReasoning;
  final String sampleBIdentity;
  final String sampleBReasoning;
  final String groupHypothesis;

  bool get isSubmitted => status == 'submitted';
}

/// Question metadata joined onto an answer for teacher review.
class DashboardQuestionMeta {
  const DashboardQuestionMeta({
    required this.id,
    required this.code,
    required this.text,
    required this.type,
    required this.maxScore,
    this.correctAnswer,
    this.rubric,
    this.stationCode = '',
    this.stationTitle = '',
  });

  final String id;
  final String code;
  final String text;
  final QuestionType type;
  final num maxScore;
  final String? correctAnswer;
  final String? rubric;
  final String stationCode;
  final String stationTitle;

  ScoringQuestion toScoringQuestion() => ScoringQuestion(
        id: id,
        type: type,
        maxScore: maxScore,
        correctAnswer: correctAnswer,
        rubric: rubric,
      );

  /// Maps DB `question_type` (+ optional objective/essay aliases) to [QuestionType].
  static QuestionType mapDbType(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'single_choice':
      case 'multiple_choice':
      case 'objective':
      case 'objektif':
        return QuestionType.objective;
      case 'text':
      case 'essay':
      case 'esai':
      case 'rubric':
      case 'rubrik':
      default:
        return QuestionType.essay;
    }
  }

  /// Extracts a comparable answer key from jsonb / string `correct_answer`.
  static String? extractCorrectAnswer(Object? raw) {
    if (raw == null) return null;
    if (raw is String) {
      final trimmed = raw.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (raw is num || raw is bool) return raw.toString();
    if (raw is List) {
      if (raw.isEmpty) return null;
      return extractCorrectAnswer(raw.first);
    }
    if (raw is Map) {
      for (final key in const ['value', 'answer', 'text', 'correct']) {
        if (raw.containsKey(key)) {
          return extractCorrectAnswer(raw[key]);
        }
      }
    }
    return raw.toString();
  }

  static String? extractRubric(Object? raw) {
    if (raw == null) return null;
    if (raw is String) return raw;
    if (raw is Map) {
      final text = raw['text'] ?? raw['rubric'] ?? raw['guidance'];
      return text?.toString();
    }
    return raw.toString();
  }
}

/// One answer + question + live [ScoringEngine] result for the dashboard.
class DashboardAnswerReview {
  const DashboardAnswerReview({
    required this.answerId,
    required this.groupId,
    required this.question,
    required this.answerText,
    required this.storedAutoScore,
    required this.storedTeacherScore,
    required this.storedFinalScore,
    required this.feedback,
    required this.version,
    required this.score,
  });

  final String answerId;
  final String groupId;
  final DashboardQuestionMeta question;
  final String answerText;
  final num? storedAutoScore;
  final num? storedTeacherScore;
  final num? storedFinalScore;
  final String? feedback;
  final int version;
  final AnswerScore score;

  bool get needsReview => score.requiresTeacherReview && score.teacherScore == null;
}

/// Full drill-down payload for one group in a session.
class DashboardGroupDetail {
  const DashboardGroupDetail({
    required this.session,
    required this.group,
    required this.missionProgress,
    required this.answers,
    this.conclusion,
  });

  final LearningSession session;
  final Group group;
  final List<DashboardMissionProgress> missionProgress;
  final List<DashboardAnswerReview> answers;
  final DashboardConclusion? conclusion;

  int get pendingReviewCount =>
      answers.where((a) => a.needsReview).length;

  int get objectiveAnswerCount =>
      answers.where((a) => a.question.type == QuestionType.objective).length;
}

/// Flat row used for CSV export of a session.
class DashboardExportRow {
  const DashboardExportRow({
    required this.sessionJoinCode,
    required this.sessionTitle,
    required this.groupName,
    required this.memberNames,
    required this.questionCode,
    required this.questionType,
    required this.stationCode,
    required this.answerText,
    required this.autoScore,
    required this.teacherScore,
    required this.finalScore,
    required this.requiresReview,
    required this.feedback,
  });

  final String sessionJoinCode;
  final String sessionTitle;
  final String groupName;
  final String memberNames;
  final String questionCode;
  final String questionType;
  final String stationCode;
  final String answerText;
  final num? autoScore;
  final num? teacherScore;
  final num? finalScore;
  final bool requiresReview;
  final String feedback;
}
