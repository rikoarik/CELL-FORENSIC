import 'package:cell_forensic/features/auth/teacher_auth_gate.dart';
import 'package:cell_forensic/features/auth/teacher_auth_service.dart';
import 'package:cell_forensic/features/dashboard/dashboard_session_repository.dart';
import 'package:flutter/material.dart';

import '../ui/app_theme.dart';
import 'dashboard_home.dart';
import 'mobile_home.dart';

enum AppExperience { mobile, dashboard }

class CellForensicApp extends StatelessWidget {
  const CellForensicApp({
    super.key,
    this.initialRoute,
    this.authService,
    this.dashboardRepository,
  }) : experience = AppExperience.mobile,
       _legacyDashboardEntry = false;

  const CellForensicApp.dashboard({
    super.key,
    this.authService,
    this.dashboardRepository,
  }) : experience = AppExperience.dashboard,
       initialRoute = teacherRoute,
       _legacyDashboardEntry = true;

  static const studentRoute = '/';
  static const teacherRoute = '/guru';
  static const teacherRouteAlias = '/dashboard';

  final AppExperience experience;
  final String? initialRoute;
  final bool _legacyDashboardEntry;

  /// Injected in tests; production uses [SupabaseTeacherAuthService].
  final TeacherAuthService? authService;

  /// Injected in tests; production uses Supabase-backed repository.
  final DashboardSessionRepository? dashboardRepository;

  Widget _teacherExperience(BuildContext context) {
    return TeacherAuthGate(
      authService: authService,
      child: DashboardHome(repository: dashboardRepository),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _legacyDashboardEntry
          ? 'Cell Forensic — Dashboard Guru'
          : 'Cell Forensic',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: initialRoute,
      routes: {
        studentRoute: (_) => const MobileHome(),
        teacherRoute: _teacherExperience,
        teacherRouteAlias: _teacherExperience,
      },
      onUnknownRoute: (_) => MaterialPageRoute<void>(
        settings: const RouteSettings(name: studentRoute),
        builder: (_) => const MobileHome(),
      ),
    );
  }
}
