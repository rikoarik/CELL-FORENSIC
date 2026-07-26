import 'package:cell_forensic/domain/entities.dart';
import 'package:cell_forensic/domain/scoring/scoring_engine.dart';
import 'package:cell_forensic/features/dashboard/dashboard_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LearningSession.canBeManagedBy', () {
    const owned = LearningSession(
      id: 's1',
      joinCode: 'CELL02',
      contentVersionId: 'c1',
      status: SessionStatus.active,
      stationDurationSeconds: 300,
      teacherId: 't1',
    );
    const orphan = LearningSession(
      id: 's2',
      joinCode: 'CELL01',
      contentVersionId: 'c1',
      status: SessionStatus.active,
      stationDurationSeconds: 300,
    );

    test('pemilik dan admin boleh mengelola', () {
      expect(
        owned.canBeManagedBy(actorId: 't1', actorRole: 'teacher'),
        isTrue,
      );
      expect(
        orphan.canBeManagedBy(actorId: 'admin', actorRole: 'admin'),
        isTrue,
      );
    });

    test('guru lain / orphan tidak boleh dikelola guru biasa', () {
      expect(
        owned.canBeManagedBy(actorId: 't2', actorRole: 'teacher'),
        isFalse,
      );
      expect(
        orphan.canBeManagedBy(actorId: 't1', actorRole: 'teacher'),
        isFalse,
      );
    });
  });

  group('DashboardQuestionMeta.mapDbType', () {
    test('memetakan tipe DB ke objektif/esai', () {
      expect(
        DashboardQuestionMeta.mapDbType('single_choice'),
        QuestionType.objective,
      );
      expect(
        DashboardQuestionMeta.mapDbType('multiple_choice'),
        QuestionType.objective,
      );
      expect(DashboardQuestionMeta.mapDbType('text'), QuestionType.essay);
      expect(DashboardQuestionMeta.mapDbType('essay'), QuestionType.essay);
    });
  });

  group('extractCorrectAnswer', () {
    test('membaca string dan jsonb sederhana', () {
      expect(DashboardQuestionMeta.extractCorrectAnswer('Sampel A'), 'Sampel A');
      expect(
        DashboardQuestionMeta.extractCorrectAnswer({'value': 'Membran'}),
        'Membran',
      );
      expect(DashboardQuestionMeta.extractCorrectAnswer(null), isNull);
    });
  });
}
