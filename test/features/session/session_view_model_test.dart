import 'package:cell_forensic/domain/entities.dart';
import 'package:cell_forensic/features/session/in_memory_session_repository.dart';
import 'package:cell_forensic/features/session/session_repository.dart';
import 'package:cell_forensic/features/session/session_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const seededSession = LearningSession(
    id: 'session-1',
    joinCode: 'ABC123',
    contentVersionId: 'content-1',
    status: SessionStatus.active,
    stationDurationSeconds: 300,
  );

  SessionViewModel buildViewModel() => SessionViewModel(
    repository: InMemorySessionRepository(sessions: const [seededSession]),
  );

  test('state awal belum tergabung dan tanpa error', () {
    final vm = buildViewModel();

    expect(vm.state.isJoined, isFalse);
    expect(vm.state.session, isNull);
    expect(vm.state.error, isNull);
    expect(vm.state.groups, isEmpty);
  });

  test('join berhasil memperbarui state dan memberi notifikasi', () async {
    final vm = buildViewModel();
    var notifications = 0;
    vm.addListener(() => notifications++);

    await vm.join('  abc123 ');

    expect(vm.state.isJoined, isTrue);
    expect(vm.state.session?.id, 'session-1');
    expect(vm.state.error, isNull);
    expect(notifications, greaterThan(0));
  });

  test('join gagal menyetel error terkontrol tanpa sesi', () async {
    final vm = buildViewModel();

    await vm.join('salah');

    expect(vm.state.isJoined, isFalse);
    expect(vm.state.session, isNull);
    expect(vm.state.error, SessionError.invalidJoinCode);
  });

  test('createGroup menambah grup ke state setelah join', () async {
    final vm = buildViewModel();
    await vm.join('ABC123');

    await vm.createGroup(name: 'Kelompok A', leaderName: 'Ayu');

    expect(vm.state.groups, hasLength(1));
    expect(vm.state.groups.single.members.single.isLeader, isTrue);
    expect(vm.state.error, isNull);
  });

  test('createGroup dengan nama kosong menyetel error', () async {
    final vm = buildViewModel();
    await vm.join('ABC123');

    await vm.createGroup(name: '  ', leaderName: 'Ayu');

    expect(vm.state.groups, isEmpty);
    expect(vm.state.error, SessionError.emptyGroupName);
  });

  test('addMember dan promoteMember menjaga tepat satu leader', () async {
    final vm = buildViewModel();
    await vm.join('ABC123');
    await vm.createGroup(name: 'Kelompok A', leaderName: 'Ayu');
    final groupId = vm.state.groups.single.id;

    await vm.addMember(groupId: groupId, displayName: 'Budi');
    final budi = vm.state.groups.single.members.firstWhere(
      (m) => m.displayName == 'Budi',
    );
    await vm.promoteMember(groupId: groupId, memberId: budi.id);

    final leaders = vm.state.groups.single.members.where((m) => m.isLeader);
    expect(leaders, hasLength(1));
    expect(leaders.single.displayName, 'Budi');
  });

  test('command sukses membersihkan error sebelumnya', () async {
    final vm = buildViewModel();
    await vm.join('salah');
    expect(vm.state.error, SessionError.invalidJoinCode);

    await vm.join('ABC123');

    expect(vm.state.error, isNull);
    expect(vm.state.isJoined, isTrue);
  });
}
