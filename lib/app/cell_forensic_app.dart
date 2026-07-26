import 'package:cell_forensic/features/auth/teacher_auth_gate.dart';
import 'package:cell_forensic/features/auth/teacher_auth_service.dart';
import 'package:cell_forensic/features/dashboard/dashboard_session_repository.dart';
import 'package:flutter/material.dart';

import '../ui/app_theme.dart';
import 'dashboard_home.dart';
import 'mobile_home.dart';

enum AppExperience { mobile, dashboard }

class CellForensicApp extends StatelessWidget {
  const CellForensicApp({super.key})
      : experience = AppExperience.mobile,
        authService = null,
        dashboardRepository = null;

  const CellForensicApp.dashboard({
    super.key,
    this.authService,
    this.dashboardRepository,
  }) : experience = AppExperience.dashboard;

  final AppExperience experience;

  /// Injected in tests; production uses [SupabaseTeacherAuthService].
  final TeacherAuthService? authService;

  /// Injected in tests; production uses Supabase-backed repository.
  final DashboardSessionRepository? dashboardRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cell Forensic',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: experience == AppExperience.mobile
          ? const MobileHome()
          : TeacherAuthGate(
              authService: authService,
              child: DashboardHome(repository: dashboardRepository),
            ),
    );
  }
}
