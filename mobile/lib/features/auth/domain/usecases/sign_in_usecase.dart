// ============================================================
// sign_in_usecase.dart
// Kullanıcı girişi iş kuralı
// ============================================================

import '../../../../core/errors/failures.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class SignInUseCase {
  final AuthRepository repository;

  SignInUseCase(this.repository);

  /// Kullanıcı girişi yapar.
  /// Email ve şifre boş olamaz, email formatı doğru olmalıdır.
  Future<UserEntity> call({
    required String email,
    required String password,
  }) async {
    // 1. Doğrulama (validation)
    if (email.trim().isEmpty) {
      throw const ValidationFailure(message: 'E-posta boş bırakılamaz');
    }
    if (password.isEmpty) {
      throw const ValidationFailure(message: 'Şifre boş bırakılamaz');
    }
    if (!_isValidEmail(email)) {
      throw const ValidationFailure(message: 'Geçerli bir e-posta giriniz');
    }
    if (password.length < 6) {
      throw const ValidationFailure(message: 'Şifre en az 6 karakter olmalıdır');
    }

    // 2. Repository'e devret
    return await repository.signIn(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,}$');
    return regex.hasMatch(email.trim());
  }
}