import 'package:cell_forensic/core/sync/student_answer_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StudentAnswerPayload', () {
    test('sanitize strips teacher score columns and question_code', () {
      final safe = StudentAnswerPayload.sanitize({
        'id': 'a1',
        'group_id': 'g1',
        'question_id': 'q1',
        'answer_text': 'dinding sel',
        'auto_score': 10,
        'teacher_score': 12,
        'final_score': 12,
        'feedback': 'bagus',
        'question_code': 'POS1-Q1',
        'version': 2,
      });

      expect(safe.keys, isNot(contains('teacher_score')));
      expect(safe.keys, isNot(contains('final_score')));
      expect(safe.keys, isNot(contains('feedback')));
      expect(safe.keys, isNot(contains('question_code')));
      expect(safe['answer_text'], 'dinding sel');
      expect(safe['auto_score'], 10);
      expect(safe['question_id'], 'q1');
    });

    test('forUpdate omits question_id (anon cannot UPDATE that column)', () {
      final update = StudentAnswerPayload.forUpdate({
        'id': 'a1',
        'group_id': 'g1',
        'question_id': 'q1',
        'answer_text': 'v2',
        'teacher_score': 99,
        'version': 3,
        'updated_at': '2026-07-26T00:00:00Z',
      });

      expect(update.keys, isNot(contains('question_id')));
      expect(update.keys, isNot(contains('teacher_score')));
      expect(update['answer_text'], 'v2');
      expect(update['version'], 3);
    });

    test('forInsert keeps question_id and drops teacher columns', () {
      final insert = StudentAnswerPayload.forInsert({
        'id': 'a1',
        'group_id': 'g1',
        'question_id': 'q1',
        'station_attempt_id': 'sa1',
        'answer_text': 'Sel A',
        'teacher_score': 5,
        'version': 1,
        'updated_at': '2026-07-26T00:00:00Z',
      });

      expect(insert['question_id'], 'q1');
      expect(insert.keys, isNot(contains('teacher_score')));
    });
  });
}
