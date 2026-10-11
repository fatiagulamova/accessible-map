// ============================================================
// exceptions.dart
// Data katmanında (Supabase, HTTP) fırlatılan istisnalar
// ============================================================

/// Tüm exception sınıflarının atası
abstract class AppException implements Exception {
  final String message;
  final String? code;

  const AppException({required this.message, this.code});

  @override
  String toString() => 'AppException(message: $message, code: $code)';
}

/// Sunucu kaynaklı istisnalar
class ServerException extends AppException {
  const ServerException({required super.message, super.code});
}

/// Supabase Auth kaynaklı istisnalar
class AuthException extends AppException {
  const AuthException({required super.message, super.code});
}

/// Ağ bağlantı istisnaları
class NetworkException extends AppException {
  const NetworkException({
    super.message = 'Ağ bağlantısı hatası',
    super.code = 'NETWORK_EXCEPTION',
  });
}

/// Önbellek istisnaları
class CacheException extends AppException {
  const CacheException({
    super.message = 'Önbellek hatası',
    super.code = 'CACHE_EXCEPTION',
  });
}

/// Doğrulama istisnaları
class ValidationException extends AppException {
  const ValidationException({
    required super.message,
    super.code = 'VALIDATION_EXCEPTION',
  });
}