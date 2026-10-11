// ============================================================
// get_current_user_usecase.dart
// Aktif kullanıcıyı getirme iş kuralı
// ============================================================

import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class GetCurrentUserUseCase {
  final AuthRepository repository;

  GetCurrentUserUseCase(this.repository);

  /// Aktif kullanıcıyı döndürür (yoksa null)
  Future<UserEntity?> call() async {
    return await repository.getCurrentUser();
  }
}