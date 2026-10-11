// ============================================================
// failures.dart
// Domain katmanında kullanıcıya gösterilecek hata sınıfları
// ============================================================

/// Tüm failure sınıflarının atası (abstract base class)
abstract class Failure {
  final String message;
  final String? code;

  const Failure({required this.message, this.code});

  @override
  String toString() => 'Failure(message: $message, code: $code)';
}

// ============================================================
// AUTH FAILURES
// ============================================================

/// Sunucu (Supabase) kaynaklı hatalar
class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.code});
}

/// Kimlik doğrulama hataları (yanlış şifre, kayıtlı olmayan email vb.)
class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.code});
}

/// Ağ / internet bağlantı hataları
class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'İnternet bağlantınızı kontrol edin',
    super.code = 'NETWORK_ERROR',
  });
}

/// Önbellek hataları
class CacheFailure extends Failure {
  const CacheFailure({
    super.message = 'Yerel veri okunamadı',
    super.code = 'CACHE_ERROR',
  });
}

/// Doğrulama (validation) hataları
class ValidationFailure extends Failure {
  const ValidationFailure({required super.message, super.code = 'VALIDATION_ERROR'});
}

/// Bilinmeyen hatalar
class UnknownFailure extends Failure {
  const UnknownFailure({
    super.message = 'Beklenmeyen bir hata oluştu',
    super.code = 'UNKNOWN_ERROR',
  });
}