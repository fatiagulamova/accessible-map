// ============================================================
// user_model.dart
// Supabase'den gelen JSON verisini UserEntity'ye çevirir
// ============================================================

import '../../domain/entities/user_entity.dart';

/// Data katmanı modeli - JSON dönüşümlerinden sorumlu
class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
    required super.fullName,
    super.phone,
    super.role,
    super.isActive,
    super.createdAt,
  });

  /// Supabase'den gelen JSON'u UserModel'e çevirir
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? 'Anonim Kullanıcı',
      phone: json['phone'] as String?,
      role: UserRoleX.fromString(json['role'] as String? ?? 'user'),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  /// UserModel'i JSON'a çevirir (Supabase'e göndermek için)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'role': role.name,
      'is_active': isActive,
    };
  }

  /// UserEntity'den UserModel oluşturur
  factory UserModel.fromEntity(UserEntity entity) {
    return UserModel(
      id: entity.id,
      email: entity.email,
      fullName: entity.fullName,
      phone: entity.phone,
      role: entity.role,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
    );
  }
}