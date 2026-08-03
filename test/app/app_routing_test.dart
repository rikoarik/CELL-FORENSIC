import 'package:cell_forensic/app/cell_forensic_app.dart';
import 'package:cell_forensic/features/auth/teacher_auth_service.dart';
import 'package:cell_forensic/features/dashboard/dashboard_session_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('/ membuka pengalaman siswa', (tester) async {
    await tester.pumpWidget(
      const CellForensicApp(initialRoute: CellForensicApp.studentRoute),
    );

    expect(find.text('Masuk Sesi'), findsOneWidget);
    expect(find.text('Masuk Dashboard Guru'), findsNothing);
  });

  for (final route in const [
    CellForensicApp.teacherRoute,
    CellForensicApp.teacherRouteAlias,
  ]) {
    testWidgets('$route membuka login guru dari build yang sama', (
      tester,
    ) async {
      await tester.pumpWidget(
        CellForensicApp(
          initialRoute: route,
          authService: _SignedOutTeacherAuthService(),
          dashboardRepository: _EmptyDashboardRepository(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Masuk Dashboard Guru'), findsOneWidget);
      expect(find.byKey(const Key('teacher-login-button')), findsOneWidget);
    });
  }
}

class _SignedOutTeacherAuthService extends FakeTeacherAuthService {}

class _EmptyDashboardRepository extends FakeDashboardSessionRepository {}
