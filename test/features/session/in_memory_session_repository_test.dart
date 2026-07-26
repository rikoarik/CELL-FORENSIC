import 'package:cell_forensic/domain/entities.dart';
import 'package:cell_forensic/features/session/in_memory_session_repository.dart';
import 'package:cell_forensic/features/session/session_repository.dart';
import 'package:cell_forensic/features/session/session_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const seededSession = LearningSession(
    id: 'session-1',
    joinCode: 'ABC123',
    contentVersionId: 'content-1',
    status: SessionStatus.active,
    stationDurationSeconds: 300,
  );

  InMemorySessionRepository buildRepository() =>
      InMemorySessionRepository(sessions: const [seededSession]);

  group('joinSession', () {
    test('menormalkan join code menjadi uppercase dan trim', () async {
      final repository = buildRepository();

      final result = await repository.joinSession('  abc123 ');

      expect(result.isOk, isTrue);
      expect(result.valueOrNull?.id, 'session-1');
      expect(result.valueOrNull?.joinCode, 'ABC123');
    });

    test(
      'kode tidak valid mengembalikan error terkontrol tanpa sesi',
      () async {
        final repository = buildRepository();

        final result = await repository.joinSession('nope');

        expect(result.isOk, isFalse);
        expect(result.errorOrNull, SessionError.invalidJoinCode);
        expect(result.valueOrNull, isNull);
      },
    );

    test('kode kosong mengembalikan error terkontrol', () async {
      final repository = buildRepository();

      final result = await repository.joinSession('   ');

      expect(result.errorOrNull, SessionError.invalidJoinCode);
    });
  });

  group('createGroup', () {
    test('membuat grup dengan leader otomatis ditandai', () async {
      final repository = buildRepository();

      final result = await repository.createGroup(
        sessionId: 'session-1',
        name: 'Kelompok Mitokondria',
        leaderName: 'Ayu',
      );

      expect(result.isOk, isTrue);
      final grup = result.valueOrNull!;
      expect(grup.name, 'Kelompok Mitokondria');
      expect(grup.sessionId, 'session-1');
      expect(grup.members, hasLength(1));
      expect(grup.members.single.displayName, 'Ayu');
      expect(grup.members.single.isLeader, isTrue);
    });

    test('nama kosong ditolak dengan error terkontrol', () async {
      final repository = buildRepository();

      final result = await repository.createGroup(
        sessionId: 'session-1',
        name: '   ',
        leaderName: 'Ayu',
      );

      expect(result.errorOrNull, SessionError.emptyGroupName);
    });

    test('nama leader kosong ditolak', () async {
      final repository = buildRepository();

      final result = await repository.createGroup(
        sessionId: 'session-1',
        name: 'Kelompok A',
        leaderName: '  ',
      );

      expect(result.errorOrNull, SessionError.emptyMemberName);
    });

    test('nama grup harus unik dalam sesi (case-insensitive)', () async {
      final repository = buildRepository();
      await repository.createGroup(
        sessionId: 'session-1',
        name: 'Kelompok A',
        leaderName: 'Ayu',
      );

      final duplicate = await repository.createGroup(
        sessionId: 'session-1',
        name: 'kelompok a',
        leaderName: 'Budi',
      );

      expect(duplicate.errorOrNull, SessionError.duplicateGroupName);
    });
  });

  group('members', () {
    Future<Group> seedGroup(InMemorySessionRepository repository) async {
      final result = await repository.createGroup(
        sessionId: 'session-1',
        name: 'Kelompok A',
        leaderName: 'Ayu',
      );
      return result.valueOrNull!;
    }

    test('menambah anggota sebagai non-leader', () async {
      final repository = buildRepository();
      final grup = await seedGroup(repository);

      final result = await repository.addMember(
        groupId: grup.id,
        displayName: 'Budi',
      );

      final updated = result.valueOrNull!;
      expect(updated.members, hasLength(2));
      final budi = updated.members.firstWhere((m) => m.displayName == 'Budi');
      expect(budi.isLeader, isFalse);
      expect(updated.members.where((m) => m.isLeader), hasLength(1));
    });

    test('nama anggota kosong ditolak', () async {
      final repository = buildRepository();
      final grup = await seedGroup(repository);

      final result = await repository.addMember(
        groupId: grup.id,
        displayName: '',
      );

      expect(result.errorOrNull, SessionError.emptyMemberName);
    });

    test('promote memindahkan leader dan menjaga tepat satu leader', () async {
      final repository = buildRepository();
      final grup = await seedGroup(repository);
      final added = (await repository.addMember(
        groupId: grup.id,
        displayName: 'Budi',
      )).valueOrNull!;
      final budi = added.members.firstWhere((m) => m.displayName == 'Budi');

      final promoted = await repository.promoteMember(
        groupId: grup.id,
        memberId: budi.id,
      );

      final updated = promoted.valueOrNull!;
      expect(updated.members.where((m) => m.isLeader), hasLength(1));
      expect(
        updated.members.firstWhere((m) => m.id == budi.id).isLeader,
        isTrue,
      );
      expect(
        updated.members.firstWhere((m) => m.displayName == 'Ayu').isLeader,
        isFalse,
      );
    });

    test('menghapus leader saat ada anggota lain ditolak', () async {
      final repository = buildRepository();
      final grup = await seedGroup(repository);
      await repository.addMember(groupId: grup.id, displayName: 'Budi');
      final leader = grup.members.single;

      final result = await repository.removeMember(
        groupId: grup.id,
        memberId: leader.id,
      );

      expect(result.errorOrNull, SessionError.cannotRemoveLeader);
    });

    test('menghapus anggota non-leader berhasil', () async {
      final repository = buildRepository();
      final grup = await seedGroup(repository);
      final added = (await repository.addMember(
        groupId: grup.id,
        displayName: 'Budi',
      )).valueOrNull!;
      final budi = added.members.firstWhere((m) => m.displayName == 'Budi');

      final result = await repository.removeMember(
        groupId: grup.id,
        memberId: budi.id,
      );

      final updated = result.valueOrNull!;
      expect(updated.members, hasLength(1));
      expect(updated.members.single.displayName, 'Ayu');
    });

    test('member tidak ditemukan mengembalikan error terkontrol', () async {
      final repository = buildRepository();
      final grup = await seedGroup(repository);

      final result = await repository.promoteMember(
        groupId: grup.id,
        memberId: 'tidak-ada',
      );

      expect(result.errorOrNull, SessionError.memberNotFound);
    });
  });

  group('persistensi offline (in-memory)', () {
    test('state grup dapat dibaca ulang setelah ditulis', () async {
      final repository = buildRepository();
      await repository.createGroup(
        sessionId: 'session-1',
        name: 'Kelompok A',
        leaderName: 'Ayu',
      );
      await repository.createGroup(
        sessionId: 'session-1',
        name: 'Kelompok B',
        leaderName: 'Budi',
      );

      final groups = await repository.groupsForSession('session-1');

      expect(groups, hasLength(2));
      expect(
        groups.map((g) => g.name),
        containsAll(<String>['Kelompok A', 'Kelompok B']),
      );
    });

    test('grup tidak ditemukan mengembalikan error terkontrol', () async {
      final repository = buildRepository();

      final result = await repository.addMember(
        groupId: 'tidak-ada',
        displayName: 'Budi',
      );

      expect(result.errorOrNull, SessionError.groupNotFound);
    });
  });
}
