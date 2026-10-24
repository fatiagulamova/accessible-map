import 'package:accessible_map/core/errors/exceptions.dart';
import 'package:accessible_map/features/route/data/models/route_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RouteModel.fromEdgeFunctionJson', () {
    test(
      'maps geometry, distance and score from the Edge Function response',
      () {
        final route = RouteModel.fromEdgeFunctionJson(
          {
            'geometry': [
              [32.3374, 41.6378],
              [32.3380, 41.6381],
            ],
            'distance': 123.4,
            'score': 80,
          },
          41.6378,
          32.3374,
          41.6381,
          32.3380,
        );

        expect(route.startLat, 41.6378);
        expect(route.startLng, 32.3374);
        expect(route.endLat, 41.6381);
        expect(route.endLng, 32.3380);
        expect(route.distanceInMeters, 123.4);
        expect(route.accessibilityScore, 80.0);
        expect(route.algorithmUsed, 'osrm');
        expect(route.pathPoints, hasLength(2));
        expect(route.pathPoints.first.latitude, 41.6378);
        expect(route.pathPoints.first.longitude, 32.3374);
      },
    );

    test('accepts numeric strings and clamps the score to 0-100', () {
      final route = RouteModel.fromEdgeFunctionJson(
        {
          'geometry': [
            ['32.3374', '41.6378'],
            ['32.3380', '41.6381'],
          ],
          'distance': '50',
          'score': '120',
        },
        41.6378,
        32.3374,
        41.6381,
        32.3380,
      );

      expect(route.distanceInMeters, 50.0);
      expect(route.accessibilityScore, 100.0);
    });

    test('throws a ServerException for an invalid geometry', () {
      expect(
        () => RouteModel.fromEdgeFunctionJson(
          {'geometry': <dynamic>[], 'distance': 10, 'score': 100},
          41.6378,
          32.3374,
          41.6381,
          32.3380,
        ),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
