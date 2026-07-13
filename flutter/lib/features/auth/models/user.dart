/// User role enumeration.
enum UserRole {
  student,
  teacher,
  partner,
  admin;

  static UserRole fromString(String? value) {
    switch (value) {
      case 'student':
        return UserRole.student;
      case 'teacher':
        return UserRole.teacher;
      case 'partner':
        return UserRole.partner;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.student;
    }
  }

  String get label {
    switch (this) {
      case UserRole.student:
        return 'Student';
      case UserRole.teacher:
        return 'Teacher';
      case UserRole.partner:
        return 'Partner (Institution)';
      case UserRole.admin:
        return 'Admin';
    }
  }
}

/// User model — matches unified_profiles table in Supabase.
class User {
  const User({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    this.avatarUrl,
    this.telegramId,
    this.targetExam,
    this.currentLevel,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String email;
  final String displayName;
  final UserRole role;
  final String? avatarUrl;
  final String? telegramId;
  final String? targetExam;
  final String? currentLevel;
  final String createdAt;
  final String updatedAt;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String,
      role: UserRole.fromString(json['role'] as String?),
      avatarUrl: json['avatar_url'] as String?,
      telegramId: json['telegram_id'] as String?,
      targetExam: json['target_exam'] as String?,
      currentLevel: json['current_level'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'display_name': displayName,
    'role': role.name,
    'avatar_url': avatarUrl,
    'telegram_id': telegramId,
    'target_exam': targetExam,
    'current_level': currentLevel,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };
}
