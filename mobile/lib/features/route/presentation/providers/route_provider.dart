// ============================================================
// route_provider.dart
// Route ile ilgili tüm Riverpod provider'ları
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/exceptions.dart' as core;
import '../../../../core/errors/failures.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/route_remote_datasource.dart';
import '../../data/repositories/route_repository_impl.dart';
import '../../domain/entities/route_entity.dart';
import '../../domain/repositories/route_repository.dart';
import '../../domain/usecases/get_accessible_route_usecase.dart';

// ============================================================
// DEPENDENCY PROVIDERS
// ============================================================

/// Remote data source
final routeRemoteDataSourceProvider = Provider<RouteRemoteDataSource>((ref) {
  return RouteRemoteDataSourceImpl(supabase: ref.watch(supabaseClientProvider));
});

/// Repository
final routeRepositoryProvider = Provider<RouteRepository>((ref) {
  return RouteRepositoryImpl(
    remoteDataSource: ref.watch(routeRemoteDataSourceProvider),
  );
});

/// Use case
final getAccessibleRouteUseCaseProvider = Provider<GetAccessibleRouteUseCase>((
  ref,
) {
  return GetAccessibleRouteUseCase(ref.watch(routeRepositoryProvider));
});

// ============================================================
// ROUTE STATE
// ============================================================

/// Rota işlemlerinin durumunu temsil eder.
sealed class RouteState {
  const RouteState();
}

class RouteInitial extends RouteState {
  const RouteInitial();
}

class RouteLoading extends RouteState {
  const RouteLoading();
}

class RouteLoaded extends RouteState {
  final RouteEntity route;

  const RouteLoaded(this.route);
}

class RouteError extends RouteState {
  final String message;

  const RouteError(this.message);
}

// ============================================================
// ROUTE CONTROLLER
// ============================================================

class RouteController extends StateNotifier<RouteState> {
  final GetAccessibleRouteUseCase _getAccessibleRouteUseCase;
  int _requestId = 0;

  RouteController({
    required GetAccessibleRouteUseCase getAccessibleRouteUseCase,
  }) : _getAccessibleRouteUseCase = getAccessibleRouteUseCase,
       super(const RouteInitial());

  /// Başlangıç ve bitiş koordinatları arasında erişilebilir rota hesaplar.
  Future<void> calculateRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    final requestId = ++_requestId;
    state = const RouteLoading();

    try {
      final route = await _getAccessibleRouteUseCase(
        startLat: startLat,
        startLng: startLng,
        endLat: endLat,
        endLng: endLng,
      );

      if (!mounted || requestId != _requestId) return;
      state = RouteLoaded(route);
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      state = RouteError(_messageFrom(error));
    }
  }

  /// Hesaplanan rotayı ve hata durumunu temizler.
  void clearRoute() {
    _requestId++;
    if (!mounted) return;
    state = const RouteInitial();
  }

  /// Hata mesajını kullanıcıya gösterilecek biçime çevirir.
  String _messageFrom(Object error) {
    if (error is Failure) return error.message;
    if (error is core.AppException) return error.message;
    return error.toString().replaceAll('Failure: ', '');
  }
}

final routeControllerProvider =
    StateNotifierProvider<RouteController, RouteState>((ref) {
      return RouteController(
        getAccessibleRouteUseCase: ref.watch(getAccessibleRouteUseCaseProvider),
      );
    });
