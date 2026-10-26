// ============================================================
// route_repository_impl.dart
// RouteRepository arayüzünün gerçek implementasyonu
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/errors/exceptions.dart' as core;
import '../../../../core/errors/failures.dart';
import '../../domain/entities/route_entity.dart';
import '../../domain/repositories/route_repository.dart';
import '../datasources/route_remote_datasource.dart';

class RouteRepositoryImpl implements RouteRepository {
  final RouteRemoteDataSource remoteDataSource;

  RouteRepositoryImpl({required this.remoteDataSource});

  @override
  Future<RouteEntity> getAccessibleRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    RoutePreferences preferences = const RoutePreferences(),
  }) {
    return _handleExceptions(
      () => remoteDataSource.getAccessibleRoute(
        startLat: startLat,
        startLng: startLng,
        endLat: endLat,
        endLng: endLng,
        preferences: preferences,
      ),
    );
  }

  // ============================================================
  // YARDIMCI METOD
  // Exception'ları Failure'lara çevirir (UI'da gösterilecek)
  // ============================================================
  Future<T> _handleExceptions<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on sb.AuthException catch (e) {
      throw AuthFailure(message: e.message, code: e.statusCode);
    } on sb.PostgrestException catch (e) {
      throw ServerFailure(message: e.message, code: e.code);
    } on core.AuthException catch (e) {
      throw AuthFailure(message: e.message, code: e.code);
    } on core.NetworkException catch (e) {
      throw NetworkFailure(message: e.message, code: e.code);
    } on core.ServerException catch (e) {
      throw ServerFailure(message: e.message, code: e.code);
    } on core.CacheException catch (e) {
      throw CacheFailure(message: e.message, code: e.code);
    } on core.ValidationException catch (e) {
      throw ValidationFailure(message: e.message, code: e.code);
    } catch (e) {
      throw UnknownFailure(message: 'Beklenmeyen hata: $e');
    }
  }
}
