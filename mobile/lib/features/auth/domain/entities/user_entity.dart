// ============================================================
// user_entity.dart
// Saf istifadəçi modeli (heç bir texnoloji asılılıq yoxdur)
// ============================================================

/// Uygulama rollerini temsil eden enum
enum UserRole {
  user,      // Bedensel engelli kullanıcı
  volunteer, // Gönüllü katılımcı
  admin,     // Sistem yöneticisi
}

extension UserRoleX on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.user:
        return 'Kullanıcı';
      case UserRole.volunteer:
        return 'Gönüllü';
      case UserRole.admin:
        return 'Yönetici';
    }
  }

  static UserRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'volunteer':
        return UserRole.volunteer;
      default:
        return UserRole.user;
    }
  }
}

/// Kullanıcı entity'si
class UserEntity {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final UserRole role;
  final bool isActive;
  final DateTime? createdAt;

  const UserEntity({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    this.role = UserRole.user,
    this.isActive = true,
    this.createdAt,
  });

  /// İsmin baş harflerini döndürür (avatar için)
  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  /// Yönetici mi?
  bool get isAdmin => role == UserRole.admin;

  /// Gönüllü mü?
  bool get isVolunteer => role == UserRole.volunteer;

  UserEntity copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phone,
    UserRole? role,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return UserEntity(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'UserEntity(id: $id, email: $email, fullName: $fullName, role: $role)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}