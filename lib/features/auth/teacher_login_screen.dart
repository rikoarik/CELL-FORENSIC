import 'package:cell_forensic/features/auth/teacher_auth_service.dart';
import 'package:cell_forensic/shared/design_tokens.dart';
import 'package:flutter/material.dart';

/// Email/password login for the Flutter Web teacher dashboard (E9).
class TeacherLoginScreen extends StatefulWidget {
  const TeacherLoginScreen({
    required this.authService,
    super.key,
  });

  final TeacherAuthService authService;

  @override
  State<TeacherLoginScreen> createState() => _TeacherLoginScreenState();
}

class _TeacherLoginScreenState extends State<TeacherLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.authService.signInWithPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is StateError ? e.message : 'Login gagal: $e';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0B1C2C),
              DesignTokens.navy,
              Color(0xFF1A3A5C),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(DesignTokens.spaceXl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: DesignTokens.blue.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: DesignTokens.blue.withValues(alpha: 0.45),
                          ),
                        ),
                        child: const Icon(
                          Icons.biotech_outlined,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spaceLg),
                    const Text(
                      'Cell Forensic',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spaceSm),
                    Text(
                      'Masuk Dashboard Guru',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pantau sesi praktikum AR, nilai jawaban POS, dan ekspor hasil kelas.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spaceXl),
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              key: const Key('teacher-email-field'),
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                border: OutlineInputBorder(),
                              ),
                              enabled: !_busy,
                              onSubmitted: (_) => _submit(),
                            ),
                            const SizedBox(height: DesignTokens.spaceMd),
                            TextField(
                              key: const Key('teacher-password-field'),
                              controller: _passwordController,
                              obscureText: _obscure,
                              autofillHints: const [AutofillHints.password],
                              decoration: InputDecoration(
                                labelText: 'Kata sandi',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              enabled: !_busy,
                              onSubmitted: (_) => _submit(),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: DesignTokens.spaceMd),
                              Text(
                                _error!,
                                key: const Key('teacher-login-error'),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
                            const SizedBox(height: DesignTokens.spaceLg),
                            FilledButton(
                              key: const Key('teacher-login-button'),
                              onPressed: _busy ? null : _submit,
                              child: _busy
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Masuk'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spaceLg),
                    Text(
                      'Akun guru dibuat oleh admin (role di tabel profiles). '
                      'Otorisasi memakai JWT + profiles.role, bukan metadata klien.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
