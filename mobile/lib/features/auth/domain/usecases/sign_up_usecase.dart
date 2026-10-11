// ============================================================
// sign_up_usecase.dart
// Yeni kullanıcı kayıt iş kuralı
// ============================================================

import '../../../../core/errors/failures.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class SignUpUseCase {
  final AuthRepository repository;

  SignUpUseCase(this.repository);

  /// Yeni kullanıcı kaydı yapar.
  Future<UserEntity> call({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    UserRole role = UserRole.user,
  }) async {
    // 1. Doğrulama
    if (fullName.trim().isEmpty) {
      throw const ValidationFailure(message: 'Ad soyad boş bırakılamaz');
    }
    if (fullName.trim().length < 3) {
      throw const ValidationFailure(message: 'Ad soyad en az 3 karakter olmalıdır');
    }
    if (email.trim().isEmpty) {
      throw const ValidationFailure(message: 'E-posta boş bırakılamaz');
    }
    if (!_isValidEmail(email)) {
      throw const ValidationFailure(message: 'Geçerli bir e-posta giriniz');
    }
    if (password.length < 6) {
      throw const ValidationFailure(message: 'Şifre en az 6 karakter olmalıdır');
    }
    if (phone != null && phone.isNotEmpty && !_isValidPhone(phone)) {
      throw const ValidationFailure(message: 'Geçerli bir telefon numarası giriniz');
    }

    // 2. Repository'e devret
    return await repository.signUp(
      email: email.trim().toLowerCase(),
      password: password,
      fullName: fullName.trim(),
      phone: phone?.trim(),
      role: role,
    );
  }

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,}$');
    return regex.hasMatch(email.trim());
  }

  bool _isValidPhone(String phone) {
    final regex = RegExp(r'^\+?[0-9]{10,15}$');
    return regex.hasMatch(phone.replaceAll(RegExp(r'[\s\-\(\)]'), ''));
  }
}