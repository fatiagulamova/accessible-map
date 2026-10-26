import 'package:accessible_map/features/route/domain/entities/route_entity.dart';
import 'package:accessible_map/features/route/domain/repositories/route_repository.dart';
import 'package:accessible_map/features/route/domain/usecases/get_accessible_route_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GetAccessibleRouteUseCase', () {
    test('forwards accessibility preferences to the repository', () async {
      final repository = _RecordingRouteRepository();
      final useCase = GetAccessibleRouteUseCase(repository);
      const preferences = RoutePreferences(
        isWheelchair: true,
        requireElevator: true,
        preferRamp: true,
        prioritizeDistance: true,
      );

      await useCase(
        startLat: 41.6378,
        startLng: 32.3374,
        endLat: 41.6381,
        endLng: 32.3380,
        preferences: preferences,
      );

      expect(repository.lastPreferences, preferences);
    });

    test('uses default preferences when they are omitted', () async {
      final repository = _RecordingRouteRepository();
      final useCase = GetAccessibleRouteUseCase(repository);

      await useCase(
        startLat: 41.6378,
        startLng: 32.3374,
        endLat: 41.6381,
        endLng: 32.3380,
      );

      expect(repository.lastPreferences, const RoutePreferences());
    });
  });
}

class _RecordingRouteRepository implements RouteRepository {
  RoutePreferences? lastPreferences;

  @override
  Future<RouteEntity> getAccessibleRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    RoutePreferences preferences = const RoutePreferences(),
  }) async {
    lastPreferences = preferences;

    return const RouteEntity(
      id: 'test-route',
      startLat: 41.6378,
      startLng: 32.3374,
      endLat: 41.6381,
      endLng: 32.3380,
      candidateRoutes: <RoutePath>[],
      algorithmUsed: 'test',
    );
  }
}
