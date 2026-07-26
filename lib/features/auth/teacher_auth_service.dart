import 'dart:async';

import 'package:cell_forensic/core/supabase/supabase_config.dart';
import 'package:cell_forensic/features/auth/teacher_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Auth + profile gate for the teacher dashboard (E9).
///
/// Authorization always comes from `public.profiles.role`, never from
/// client-editable `user_metadata`.
abstract class TeacherAuthService {
  Stream<TeacherProfile?> get authStateChanges;

  TeacherProfile? get currentProfile;

  Future<TeacherProfile?> restoreSession();

  Future<TeacherProfile> signInWithPassword({
    required String email,
    required String password,
  });

  Future<void> signOut();
}

class SupabaseTeacherAuthService implements TeacherAuthService {
  SupabaseTeacherAuthService();

  final _controller = StreamController<TeacherProfile?>.broadcast();
  TeacherProfile? _profile;
  StreamSubscription<AuthState>? _authSub;
  bool _listening = false;

  SupabaseClient? get _client => SupabaseConfig.clientOrNull;

  @override
  Stream<TeacherProfile?> get authStateChanges {
    _ensureListening();
    return _controller.stream;
  }

  @override
  TeacherProfile? get currentProfile => _profile;

  void _ensureListening() {
    if (_listening) return;
    _listening = true;
    final client = _client;
    if (client == null) return;
    _authSub = client.auth.onAuthStateChange.listen((event) async {
      if (event.event == AuthChangeEvent.signedOut ||
          event.session == null) {
        _emit(null);
        return;
      }
      try {
        final profile = await _loadTeacherProfile(client);
        _emit(profile);
      } catch (_) {
        await client.auth.signOut();
        _emit(null);
      }
    });
  }

  void _emit(TeacherProfile? profile) {
    _profile = profile;
    if (!_controller.isClosed) {
      _controller.add(profile);
    }
  }

  @override
  Future<TeacherProfile?> restoreSession() async {
    _ensureListening();
    final client = _client;
    if (client == null) return null;
    final session = client.auth.currentSession;
    if (session == null) {
      _emit(null);
      return null;
    }
    try {
      final profile = await _loadTeacherProfile(client);
      _emit(profile);
      return profile;
    } catch (_) {
      await client.auth.signOut();
      _emit(null);
      return null;
    }
  }

  @override
  Future<TeacherProfile> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError(
        'Supabase belum dikonfigurasi. Atur SUPABASE_URL dan SUPABASE_ANON_KEY.',
      );
    }

    final trimmed = email.trim();
    if (trimmed.isEmpty || password.isEmpty) {
      throw StateError('Email dan kata sandi wajib diisi.');
    }

    try {
      final response = await client.auth.signInWithPassword(
        email: trimmed,
        password: password,
      );
      if (response.session == null || response.user == null) {
        throw StateError('Login gagal. Periksa email dan kata sandi.');
      }

      final profile = await _loadTeacherProfile(client);
      _emit(profile);
      return profile;
    } on AuthException catch (e) {
      await client.auth.signOut();
      _emit(null);
      throw StateError(_mapAuthException(e));
    } catch (e) {
      await client.auth.signOut();
      _emit(null);
      if (e is StateError) rethrow;
      throw StateError('Login gagal: $e');
    }
  }

  static String _mapAuthException(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login') ||
        msg.contains('invalid credentials') ||
        msg.contains('email not confirmed')) {
      return 'Email atau kata sandi salah, atau email belum dikonfirmasi.';
    }
    return 'Login gagal: ${e.message}';
  }

  @override
  Future<void> signOut() async {
    final client = _client;
    if (client != null) {
      await client.auth.signOut();
    }
    _emit(null);
  }

  Future<TeacherProfile> _loadTeacherProfile(SupabaseClient client) async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Sesi autentikasi tidak valid.');
    }

    final row = await client
        .from('profiles')
        .select('id, full_name, role')
        .eq('id', uid)
        .maybeSingle();

    if (row == null) {
      throw StateError(
        'Profil guru belum ada. Hubungi admin untuk membuat akun guru.',
      );
    }

    final profile = TeacherProfile.fromJson(
      Map<String, Object?>.from(row),
    );
    if (!profile.isTeacherOrAdmin) {
      throw StateError(
        'Akun ini bukan guru/admin. Role diambil dari tabel profiles, '
        'bukan metadata pengguna.',
      );
    }
    return profile;
  }

  Future<void> dispose() async {
    await _authSub?.cancel();
    await _controller.close();
  }
}

/// Deterministic fake for widget tests (no Supabase).
class FakeTeacherAuthService implements TeacherAuthService {
  FakeTeacherAuthService({
    TeacherProfile? initialProfile,
    this.failSignIn = false,
  }) : _profile = initialProfile {
    _controller.add(initialProfile);
  }

  final _controller = StreamController<TeacherProfile?>.broadcast();
  TeacherProfile? _profile;
  bool failSignIn;
  int signInCalls = 0;
  int signOutCalls = 0;

  @override
  Stream<TeacherProfile?> get authStateChanges => _controller.stream;

  @override
  TeacherProfile? get currentProfile => _profile;

  @override
  Future<TeacherProfile?> restoreSession() async => _profile;

  @override
  Future<TeacherProfile> signInWithPassword({
    required String email,
    required String password,
  }) async {
    signInCalls += 1;
    if (failSignIn) {
      throw StateError('Login gagal (fake).');
    }
    final profile = TeacherProfile(
      id: 't1',
      fullName: email.split('@').first,
      role: 'teacher',
    );
    _profile = profile;
    _controller.add(profile);
    return profile;
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
    _profile = null;
    _controller.add(null);
  }

  /// Test helper: inject a signed-in teacher without going through login UI.
  void emitSignedIn(TeacherProfile profile) {
    _profile = profile;
    _controller.add(profile);
  }
}
