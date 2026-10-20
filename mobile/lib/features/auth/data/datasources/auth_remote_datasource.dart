// ============================================================
// auth_remote_datasource.dart
// Supabase Auth ile doğrudan iletişim kuran katman
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/user_entity.dart';
import '../models/user_model.dart';

/// Auth işlemlerini Supabase üzerinden gerçekleştirir.
abstract class AuthRemoteDataSource {
  Future<UserModel> signIn({
    required String email,
    required String password,
  });

  Future<UserModel> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    String role,
  });

  Future<void> signOut();

  Future<UserModel?> getCurrentUser();

  Future<bool> isAuthenticated();

  Future<void> sendPasswordResetEmail(String email);
}

/// Supabase implementasyonu
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final sb.SupabaseClient _supabase;

  AuthRemoteDataSourceImpl(this._supabase);

  @override
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw const AuthException(message: 'Giriş başarısız oldu');
      }

      // Profiles tablosundan kullanıcı profilini çek
      return await _fetchProfile(user.id, fallbackEmail: email);
    } on sb.AuthException catch (e) {
      throw AuthException(message: _translateAuthError(e.message), code: e.statusCode);
    } catch (e) {
      throw ServerException(message: 'Sunucu hatası: $e');
    }
  }

  @override
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    String role = 'user',
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'phone': phone,
          'role': role,
        },
      );

      final user = response.user;
      if (user == null) {
        throw const AuthException(message: 'Kayıt başarısız oldu');
      }

      // Profil trigger ile otomatik oluşur, ama emin olmak için bir süre bekle
      await Future.delayed(const Duration(milliseconds: 500));

      return await _fetchProfile(user.id, fallbackEmail: email, fallbackName: fullName);
    } on sb.AuthException catch (e) {
      throw AuthException(message: _translateAuthError(e.message), code: e.statusCode);
    } catch (e) {
      throw ServerException(message: 'Sunucu hatası: $e');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw ServerException(message: 'Çıkış yapılamadı: $e');
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      return await _fetchProfile(user.id, fallbackEmail: user.email ?? '');
    } catch (e) {
      throw ServerException(message: 'Kullanıcı bilgisi alınamadı: $e');
    }
  }

  @override
  Future<bool> isAuthenticated() async {
    return _supabase.auth.currentSession != null;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } on sb.AuthException catch (e) {
      throw AuthException(message: _translateAuthError(e.message));
    } catch (e) {
      throw const ServerException(
        message: 'Şifre sıfırlama e-postası gönderilemedi',
      );
    }
  }

  // ============================================================
  // YARDIMCI METODLAR
  // ============================================================

  /// Profiles tablosundan kullanıcı profilini getirir
  Future<UserModel> _fetchProfile(
    String userId, {
    required String fallbackEmail,
    String? fallbackName,
  }) async {
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data == null) {
        // Profil henüz oluşmadıysa fallback veri döndür
        return UserModel(
          id: userId,
          email: fallbackEmail,
          fullName: fallbackName ?? 'Kullanıcı',
          role: UserRole.user,
        );
      }

      return UserModel.fromJson(data);
    } catch (e) {
      throw ServerException(message: 'Profil bilgisi alınamadı: $e');
    }
  }

  /// Supabase hata mesajlarını Türkçe'ye çevirir
  String _translateAuthError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      return 'E-posta veya şifre yanlış';
    }
    if (lower.contains('email not confirmed')) {
      return 'E-posta adresiniz henüz onaylanmadı';
    }
    if (lower.contains('user already registered')) {
      return 'Bu e-posta adresi zaten kayıtlı';
    }
    if (lower.contains('password should be at least')) {
      return 'Şifre en az 6 karakter olmalıdır';
    }
    if (lower.contains('unable to validate email')) {
      return 'Geçerli bir e-posta adresi giriniz';
    }
    if (lower.contains('rate limit')) {
      return 'Çok fazla deneme yaptınız. Lütfen bekleyin';
    }
    return message;
  }
}