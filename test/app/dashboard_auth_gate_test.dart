import 'package:cell_forensic/app/cell_forensic_app.dart';
import 'package:cell_forensic/domain/entities.dart';
import 'package:cell_forensic/features/auth/teacher_auth_service.dart';
import 'package:cell_forensic/features/auth/teacher_profile.dart';
import 'package:cell_forensic/features/dashboard/dashboard_session_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dashboard menampilkan login saat belum autentikasi', (
    tester,
  ) async {
    final auth = FakeTeacherAuthService();
    final repo = FakeDashboardSessionRepository();

    await tester.pumpWidget(
      CellForensicApp.dashboard(
        authService: auth,
        dashboardRepository: repo,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Masuk Dashboard Guru'), findsOneWidget);
    expect(find.byKey(const Key('teacher-login-button')), findsOneWidget);
    expect(find.text('Ringkasan Sesi'), findsNothing);
  });

  testWidgets('login sukses membuka ringkasan sesi', (tester) async {
    final auth = FakeTeacherAuthService();
    final repo = FakeDashboardSessionRepository([
      DashboardSessionSnapshot(
        session: const LearningSession(
          id: 's1',
          joinCode: 'CELL99',
          contentVersionId: 'c1',
          status: SessionStatus.active,
          stationDurationSeconds: 300,
          title: 'Sesi Uji',
        ),
        groups: const [],
      ),
    ]);

    await tester.pumpWidget(
      CellForensicApp.dashboard(
        authService: auth,
        dashboardRepository: repo,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('teacher-email-field')),
      'guru@sekolah.id',
    );
    await tester.enterText(
      find.byKey(const Key('teacher-password-field')),
      'rahasia',
    );
    await tester.tap(find.byKey(const Key('teacher-login-button')));
    await tester.pumpAndSettle();

    expect(auth.signInCalls, 1);
    expect(find.text('Ringkasan Sesi'), findsOneWidget);
    expect(find.text('Sesi Uji'), findsOneWidget);
    expect(find.byKey(const Key('create-session-fab')), findsOneWidget);
  });

  testWidgets('logout kembali ke layar login', (tester) async {
    final auth = FakeTeacherAuthService(
      initialProfile: const TeacherProfile(
        id: 't1',
        fullName: 'Bu Sari',
        role: 'teacher',
      ),
    );
    final repo = FakeDashboardSessionRepository();

    await tester.pumpWidget(
      CellForensicApp.dashboard(
        authService: auth,
        dashboardRepository: repo,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ringkasan Sesi'), findsOneWidget);

    await tester.tap(find.byKey(const Key('teacher-logout-button')).first);
    await tester.pumpAndSettle();

    expect(auth.signOutCalls, 1);
    expect(find.text('Masuk Dashboard Guru'), findsOneWidget);
  });

  testWidgets('buat sesi dari dialog menambah kartu sesi', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final auth = FakeTeacherAuthService(
      initialProfile: const TeacherProfile(
        id: 't1',
        fullName: 'Bu Sari',
        role: 'teacher',
      ),
    );
    final repo = FakeDashboardSessionRepository();

    await tester.pumpWidget(
      CellForensicApp.dashboard(
        authService: auth,
        dashboardRepository: repo,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('create-session-fab')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('create-session-title')),
      'Praktikum Baru',
    );
    await tester.enterText(
      find.byKey(const Key('create-session-join-code')),
      'CELL42',
    );
    await tester.tap(find.byKey(const Key('create-session-submit')));
    await tester.pumpAndSettle();

    expect(repo.createdSessions, hasLength(1));
    expect(repo.createdSessions.first.joinCode, 'CELL42');
    expect(repo.createdSessions.first.teacherId, 't1');
    expect(find.text('Praktikum Baru'), findsOneWidget);
    expect(find.byKey(const Key('activate-session-created-1')), findsNothing);
    expect(find.byKey(const Key('close-session-created-1')), findsOneWidget);
  });

  testWidgets('sesi tanpa pemilik tampil baca saja (tanpa Aktifkan/Tutup)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final auth = FakeTeacherAuthService(
      initialProfile: const TeacherProfile(
        id: 't1',
        fullName: 'Bu Sari',
        role: 'teacher',
      ),
    );
    final repo = FakeDashboardSessionRepository([
      DashboardSessionSnapshot(
        session: const LearningSession(
          id: 'demo',
          joinCode: 'CELL01',
          contentVersionId: 'c1',
          status: SessionStatus.active,
          stationDurationSeconds: 300,
          title: 'Demo Tanpa Pemilik',
          teacherId: null,
        ),
        groups: const [],
      ),
    ]);

    await tester.pumpWidget(
      CellForensicApp.dashboard(
        authService: auth,
        dashboardRepository: repo,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Demo Tanpa Pemilik'), findsOneWidget);
    expect(find.byKey(const Key('session-readonly-demo')), findsOneWidget);
    expect(find.byKey(const Key('activate-session-demo')), findsNothing);
    expect(find.byKey(const Key('close-session-demo')), findsNothing);
  });

  testWidgets('aktifkan dan tutup sesi milik guru', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final auth = FakeTeacherAuthService(
      initialProfile: const TeacherProfile(
        id: 't1',
        fullName: 'Bu Sari',
        role: 'teacher',
      ),
    );
    final repo = FakeDashboardSessionRepository([
      DashboardSessionSnapshot(
        session: const LearningSession(
          id: 'owned',
          joinCode: 'CELL77',
          contentVersionId: 'c1',
          status: SessionStatus.draft,
          stationDurationSeconds: 300,
          title: 'Sesi Milik Saya',
          teacherId: 't1',
        ),
        groups: const [],
      ),
    ]);

    await tester.pumpWidget(
      CellForensicApp.dashboard(
        authService: auth,
        dashboardRepository: repo,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('activate-session-owned')));
    await tester.pumpAndSettle();
    expect(repo.statusUpdates, hasLength(1));
    expect(repo.statusUpdates.single.status, SessionStatus.active);

    await tester.tap(find.byKey(const Key('close-session-owned')));
    await tester.pumpAndSettle();
    expect(repo.statusUpdates, hasLength(2));
    expect(repo.statusUpdates.last.status, SessionStatus.closed);
  });
}
