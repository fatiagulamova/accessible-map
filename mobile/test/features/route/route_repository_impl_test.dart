import 'package:accessible_map/features/route/data/datasources/route_remote_datasource.dart';
import 'package:accessible_map/features/route/data/models/route_model.dart';
import 'package:accessible_map/features/route/data/repositories/route_repository_impl.dart';
import 'package:accessible_map/features/route/domain/entities/route_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RouteRepositoryImpl', () {
    test(
      'forwards accessibility preferences to the remote data source',
      () async {
        final dataSource = _RecordingRouteRemoteDataSource();
        final repository = RouteRepositoryImpl(remoteDataSource: dataSource);
        const preferences = RoutePreferences(
          isWheelchair: true,
          requireElevator: true,
          preferRamp: true,
          prioritizeDistance: true,
        );

        await repository.getAccessibleRoute(
          startLat: 41.6378,
          startLng: 32.3374,
          endLat: 41.6381,
          endLng: 32.3380,
          preferences: preferences,
        );

        expect(dataSource.lastPreferences, preferences);
      },
    );
  });
}

class _RecordingRouteRemoteDataSource implements RouteRemoteDataSource {
  RoutePreferences? lastPreferences;

  @override
  Future<RouteModel> getAccessibleRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    RoutePreferences preferences = const RoutePreferences(),
  }) async {
    lastPreferences = preferences;

    return const RouteModel(
      id: 'test-route',
      startLat: 41.6378,
      startLng: 32.3374,
      endLat: 41.6381,
      endLng: 32.3380,
      candidateRoutes: <RoutePath>[],
      algorithmUsed: 'osrm',
    );
  }
}
