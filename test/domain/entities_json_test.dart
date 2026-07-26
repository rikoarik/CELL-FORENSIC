import 'package:cell_forensic/domain/entities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LearningSession round-trips snake_case JSON', () {
    const json = {
      'id': 's1',
      'join_code': 'ABC123',
      'content_version_id': 'cv1',
      'status': 'active',
      'station_duration_seconds': 600,
    };

    final session = LearningSession.fromJson(json);

    expect(session.id, 's1');
    expect(session.joinCode, 'ABC123');
    expect(session.contentVersionId, 'cv1');
    expect(session.status, SessionStatus.active);
    expect(session.stationDurationSeconds, 600);
    expect(session.toJson(), json);
  });

  test('Group and members round-trip with leader flag', () {
    const json = {
      'id': 'g1',
      'session_id': 's1',
      'name': 'Kelompok Mawar',
      'members': [
        {'id': 'm1', 'display_name': 'Ani', 'is_leader': true},
        {'id': 'm2', 'display_name': 'Budi', 'is_leader': false},
      ],
    };

    final group = Group.fromJson(json);

    expect(group.name, 'Kelompok Mawar');
    expect(group.members, hasLength(2));
    expect(group.members.first.isLeader, isTrue);
    expect(group.toJson(), json);
  });

  test('ObservationRecord preserves version for optimistic concurrency', () {
    const json = {
      'id': 'o1',
      'group_id': 'g1',
      'mission_id': 'mi1',
      'sample_ref': 'SAMPLE_A',
      'detected_structure': 'kloroplas',
      'version': 3,
    };

    final record = ObservationRecord.fromJson(json);

    expect(record.version, 3);
    expect(record.detectedStructure, 'kloroplas');
    expect(record.toJson(), json);
  });

  test('Answer keeps scoring fields and version', () {
    const json = {
      'id': 'a1',
      'group_id': 'g1',
      'question_id': 'q1',
      'station_attempt_id': 'sa1',
      'answer_text': 'Sel tumbuhan',
      'auto_score': 10,
      'teacher_score': 12,
      'final_score': 12,
      'version': 2,
    };

    final answer = Answer.fromJson(json);

    expect(answer.autoScore, 10);
    expect(answer.finalScore, 12);
    expect(answer.version, 2);
    expect(answer.toJson(), json);
    expect(answer.toStudentWriteJson().containsKey('teacher_score'), isFalse);
    expect(answer.toStudentWriteJson().containsKey('final_score'), isFalse);
    expect(answer.toStudentWriteJson()['answer_text'], 'Sel tumbuhan');
  });

  test('unknown session status parses to unknown without throwing', () {
    final session = LearningSession.fromJson(const {
      'id': 's2',
      'join_code': 'ZZZ999',
      'content_version_id': 'cv1',
      'status': 'something_new',
      'station_duration_seconds': 300,
    });

    expect(session.status, SessionStatus.unknown);
  });
}
