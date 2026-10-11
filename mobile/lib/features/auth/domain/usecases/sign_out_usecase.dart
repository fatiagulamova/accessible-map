// ============================================================
// sign_out_usecase.dart
// Kullanıcı çıkışı iş kuralı
// ============================================================

import '../repositories/auth_repository.dart';

class SignOutUseCase {
  final AuthRepository repository;

  SignOutUseCase(this.repository);

  Future<void> call() async {
    await repository.signOut();
  }
}