// ============================================================
// auth_provider.dart
// Auth ile ilgili tüm Riverpod provider'ları
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/get_current_user_usecase.dart';
import '../../domain/usecases/sign_in_usecase.dart';
import '../../domain/usecases/sign_out_usecase.dart';
import '../../domain/usecases/sign_up_usecase.dart';

// ============================================================
// DEPENDENCY PROVIDERS
// ============================================================

/// Supabase client'a erişim
final supabaseClientProvider = Provider<sb.SupabaseClient>((ref) {
  return sb.Supabase.instance.client;
});

/// Remote data source
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSourceImpl(ref.watch(supabaseClientProvider));
});

/// Repository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
  );
});

/// Use case providers
final signInUseCaseProvider = Provider<SignInUseCase>((ref) {
  return SignInUseCase(ref.watch(authRepositoryProvider));
});

final signUpUseCaseProvider = Provider<SignUpUseCase>((ref) {
  return SignUpUseCase(ref.watch(authRepositoryProvider));
});

final signOutUseCaseProvider = Provider<SignOutUseCase>((ref) {
  return SignOutUseCase(ref.watch(authRepositoryProvider));
});

final getCurrentUserUseCaseProvider = Provider<GetCurrentUserUseCase>((ref) {
  return GetCurrentUserUseCase(ref.watch(authRepositoryProvider));
});

// ============================================================
// AUTH STATE
// ============================================================

/// Auth işlemlerinin durumunu temsil eder
sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final UserEntity user;
  const AuthAuthenticated(this.user);
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
}

// ============================================================
// AUTH CONTROLLER
// ============================================================

class AuthController extends StateNotifier<AuthState> {
  final SignInUseCase _signInUseCase;
  final SignUpUseCase _signUpUseCase;
  final SignOutUseCase _signOutUseCase;
  final GetCurrentUserUseCase _getCurrentUserUseCase;

  AuthController({
    required SignInUseCase signInUseCase,
    required SignUpUseCase signUpUseCase,
    required SignOutUseCase signOutUseCase,
    required GetCurrentUserUseCase getCurrentUserUseCase,
  })  : _signInUseCase = signInUseCase,
        _signUpUseCase = signUpUseCase,
        _signOutUseCase = signOutUseCase,
        _getCurrentUserUseCase = getCurrentUserUseCase,
        super(const AuthInitial());

  /// Kullanıcı girişi
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    state = const AuthLoading();
    try {
      final user = await _signInUseCase(email: email, password: password);
      state = AuthAuthenticated(user);
      return true;
    } catch (e) {
      state = AuthError(e.toString().replaceAll('Failure: ', ''));
      return false;
    }
  }

  /// Yeni kullanıcı kaydı
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    UserRole role = UserRole.user,
  }) async {
    state = const AuthLoading();
    try {
      final user = await _signUpUseCase(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
        role: role,
      );
      state = AuthAuthenticated(user);
      return true;
    } catch (e) {
      state = AuthError(e.toString().replaceAll('Failure: ', ''));
      return false;
    }
  }

  /// Çıkış yap
  Future<void> signOut() async {
    state = const AuthLoading();
    try {
      await _signOutUseCase();
      state = const AuthUnauthenticated();
    } catch (e) {
      state = AuthError(e.toString().replaceAll('Failure: ', ''));
    }
  }

  /// Aktif kullanıcıyı yükle
  Future<void> loadCurrentUser() async {
    state = const AuthLoading();
    try {
      final user = await _getCurrentUserUseCase();
      if (user != null) {
        state = AuthAuthenticated(user);
      } else {
        state = const AuthUnauthenticated();
      }
    } catch (e) {
      state = const AuthUnauthenticated();
    }
  }

  /// Hata mesajını temizle
  void clearError() {
    if (state is AuthError) {
      state = const AuthInitial();
    }
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    signInUseCase: ref.watch(signInUseCaseProvider),
    signUpUseCase: ref.watch(signUpUseCaseProvider),
    signOutUseCase: ref.watch(signOutUseCaseProvider),
    getCurrentUserUseCase: ref.watch(getCurrentUserUseCaseProvider),
  );
});

// ============================================================
// AUTH STATE STREAM
// Supabase auth değişikliklerini dinler
// ============================================================

final authStateStreamProvider = StreamProvider<sb.AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});