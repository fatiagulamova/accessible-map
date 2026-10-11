// ============================================================
// auth_repository_impl.dart
// AuthRepository arayüzünün gerçek implementasyonu
// ============================================================

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Future<UserEntity> signIn({
    required String email,
    required String password,
  }) async {
    return _handleExceptions(() async {
      return await remoteDataSource.signIn(
        email: email,
        password: password,
      );
    });
  }

  @override
  Future<UserEntity> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    UserRole role = UserRole.user,
  }) async {
    return _handleExceptions(() async {
      return await remoteDataSource.signUp(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
        role: role.name,
      );
    });
  }

  @override
  Future<void> signOut() async {
    return _handleExceptions(() async {
      await remoteDataSource.signOut();
    });
  }

  @override
  Future<UserEntity?> getCurrentUser() async {
    return _handleExceptions(() async {
      return await remoteDataSource.getCurrentUser();
    });
  }

  @override
  Future<bool> isAuthenticated() async {
    return _handleExceptions(() async {
      return await remoteDataSource.isAuthenticated();
    });
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    return _handleExceptions(() async {
      await remoteDataSource.sendPasswordResetEmail(email);
    });
  }

  // ============================================================
  // YARDIMCI METOD
  // Exception'ları Failure'lara çevirir (UI'da gösterilecek)
  // ============================================================
  Future<T> _handleExceptions<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthException catch (e) {
      throw AuthFailure(message: e.message, code: e.code);
    } on NetworkException catch (e) {
      throw NetworkFailure(message: e.message, code: e.code);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message, code: e.code);
    } on CacheException catch (e) {
      throw CacheFailure(message: e.message, code: e.code);
    } on ValidationException catch (e) {
      throw ValidationFailure(message: e.message, code: e.code);
    } catch (e) {
      throw UnknownFailure(message: 'Beklenmeyen hata: $e');
    }
  }
}