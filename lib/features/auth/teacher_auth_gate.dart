import 'package:cell_forensic/features/auth/teacher_auth_service.dart';
import 'package:cell_forensic/features/auth/teacher_login_screen.dart';
import 'package:cell_forensic/features/auth/teacher_profile.dart';
import 'package:flutter/material.dart';

/// Shows login until a teacher/admin JWT + profile is present.
class TeacherAuthGate extends StatefulWidget {
  const TeacherAuthGate({
    required this.child,
    this.authService,
    super.key,
  });

  final Widget child;
  final TeacherAuthService? authService;

  @override
  State<TeacherAuthGate> createState() => _TeacherAuthGateState();
}

class _TeacherAuthGateState extends State<TeacherAuthGate> {
  late final TeacherAuthService _auth =
      widget.authService ?? SupabaseTeacherAuthService();
  late Future<TeacherProfile?> _restoreFuture;

  @override
  void initState() {
    super.initState();
    _restoreFuture = _auth.restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TeacherProfile?>(
      future: _restoreFuture,
      builder: (context, restoreSnap) {
        if (restoreSnap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return StreamBuilder<TeacherProfile?>(
          stream: _auth.authStateChanges,
          initialData: _auth.currentProfile,
          builder: (context, snapshot) {
            final profile = snapshot.data;
            if (profile == null || !profile.isTeacherOrAdmin) {
              return TeacherLoginScreen(authService: _auth);
            }
            return TeacherAuthScope(
              authService: _auth,
              profile: profile,
              child: widget.child,
            );
          },
        );
      },
    );
  }
}

/// Inherited access to the signed-in teacher for dashboard screens.
class TeacherAuthScope extends InheritedWidget {
  const TeacherAuthScope({
    required this.authService,
    required this.profile,
    required super.child,
    super.key,
  });

  final TeacherAuthService authService;
  final TeacherProfile profile;

  static TeacherAuthScope of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<TeacherAuthScope>();
    assert(scope != null, 'TeacherAuthScope tidak ditemukan');
    return scope!;
  }

  static TeacherAuthScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TeacherAuthScope>();
  }

  @override
  bool updateShouldNotify(TeacherAuthScope oldWidget) {
    return oldWidget.profile.id != profile.id ||
        oldWidget.profile.role != profile.role ||
        oldWidget.profile.fullName != profile.fullName;
  }
}
