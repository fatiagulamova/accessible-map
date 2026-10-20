// ============================================================
// auth_repository.dart
// Auth repository'nin soyut (abstract) arayüzü
// ============================================================

import '../entities/user_entity.dart';

/// Auth işlemlerini tanımlayan sözleşme.
/// Data katmanı bu arayüzü implement eder.
abstract class AuthRepository {
  /// Kullanıcı girişi
  /// [email] ve [password] zorunludur.
  Future<UserEntity> signIn({
    required String email,
    required String password,
  });

  /// Yeni kullanıcı kaydı
  Future<UserEntity> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    UserRole role,
  });

  /// Çıkış yap
  Future<void> signOut();

  /// Şu an aktif olan kullanıcıyı getir (yoksa null)
  Future<UserEntity?> getCurrentUser();

  /// Kullanıcının oturum açıp açmadığını kontrol et
  Future<bool> isAuthenticated();

  /// Şifre sıfırlama e-postası gönder
  Future<void> sendPasswordResetEmail(String email);
}