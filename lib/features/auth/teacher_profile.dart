/// Teacher/admin profile row from `public.profiles` (authorization source).
class TeacherProfile {
  const TeacherProfile({
    required this.id,
    required this.fullName,
    required this.role,
  });

  factory TeacherProfile.fromJson(Map<String, Object?> json) {
    return TeacherProfile(
      id: json['id']! as String,
      fullName: (json['full_name'] as String?) ?? 'Guru',
      role: (json['role'] as String?) ?? 'student',
    );
  }

  final String id;
  final String fullName;
  final String role;

  bool get isTeacherOrAdmin => role == 'teacher' || role == 'admin';
}
