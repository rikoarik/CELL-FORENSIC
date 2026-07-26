import 'package:cell_forensic/core/database/local_store.dart';
import 'package:cell_forensic/domain/entities.dart';
import 'package:cell_forensic/features/session/persisted_session_repository.dart';
import 'package:cell_forensic/features/session/session_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const seed = LearningSession(
    id: 'session-1',
    joinCode: 'CELL01',
    contentVersionId: 'content-1',
    status: SessionStatus.active,
    stationDurationSeconds: 300,
    title: 'Demo',
  );

  PersistedSessionRepository open(LocalDatabase db) =>
      PersistedSessionRepository(database: db, seedSessions: const [seed]);

  test('join, create group, and members survive reopen', () async {
    final backend = InMemoryStorageBackend();
    final first = open(LocalDatabase(backend));

    final joined = await first.joinSession('cell01');
    expect(joined.isOk, isTrue);

    final created = await first.createGroup(
      sessionId: 'session-1',
      name: 'Kelompok A',
      leaderName: 'Ayu',
    );
    expect(created.isOk, isTrue);
    final groupId = created.valueOrNull!.id;

    await first.addMember(groupId: groupId, displayName: 'Budi');
    final withBudi = (await first.group(groupId)).valueOrNull!;
    final budi = withBudi.members.firstWhere((m) => m.displayName == 'Budi');
    await first.promoteMember(groupId: groupId, memberId: budi.id);

    final reopened = open(LocalDatabase(backend));
    final groups = await reopened.groupsForSession('session-1');
    expect(groups, hasLength(1));
    expect(groups.single.members, hasLength(2));
    expect(
      groups.single.members.where((m) => m.isLeader).single.displayName,
      'Budi',
    );

    final joinAgain = await reopened.joinSession('CELL01');
    expect(joinAgain.valueOrNull?.id, 'session-1');
  });

  test('invalid join code remains controlled after persistence', () async {
    final repo = open(LocalDatabase(InMemoryStorageBackend()));
    final result = await repo.joinSession('SALAH');
    expect(result.errorOrNull, SessionError.invalidJoinCode);
  });
}
