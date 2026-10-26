import 'package:accessible_map/core/errors/exceptions.dart';
import 'package:accessible_map/features/route/data/models/route_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RouteModel.fromEdgeFunctionJson', () {
    test('maps every candidate route returned by the Edge Function', () {
      final route = RouteModel.fromEdgeFunctionJson(
        {
          'routes': [
            {
              'geometry': [
                [32.3374, 41.6378],
                [32.3380, 41.6381],
              ],
              'distance': 150,
              'score': 72,
            },
            {
              'geometry': [
                [32.3374, 41.6378],
                [32.3377, 41.6380],
                [32.3380, 41.6381],
              ],
              'distance': 123.4,
              'score': 80,
            },
            {
              'geometry': [
                [32.3374, 41.6378],
                [32.3390, 41.6385],
                [32.3380, 41.6381],
              ],
              'distance': 210,
              'score': 55,
            },
          ],
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
      expect(route.algorithmUsed, 'osrm');
      expect(route.candidateRoutes, hasLength(3));
      expect(route.candidateRoutes[1].geometry, hasLength(3));
      expect(route.candidateRoutes[1].distance, 123.4);
      expect(route.candidateRoutes[1].score, 80.0);
      expect(route.bestRoute, same(route.candidateRoutes[1]));
      expect(route.riskyRoute, same(route.candidateRoutes[2]));
      expect(route.distanceInMeters, 123.4);
      expect(route.accessibilityScore, 80.0);
      expect(route.pathPoints, hasLength(3));
      expect(route.pathPoints.first.latitude, 41.6378);
      expect(route.pathPoints.first.longitude, 32.3374);
    });

    test('accepts numeric strings and clamps each score to 0-100', () {
      final route = RouteModel.fromEdgeFunctionJson(
        {
          'routes': [
            {
              'geometry': [
                ['32.3374', '41.6378'],
                ['32.3380', '41.6381'],
              ],
              'distance': '50',
              'score': '120',
            },
            {
              'geometry': [
                ['32.3374', '41.6378'],
                ['32.3382', '41.6382'],
              ],
              'distance': '80',
              'score': '-5',
            },
          ],
        },
        41.6378,
        32.3374,
        41.6381,
        32.3380,
      );

      expect(route.candidateRoutes.first.distance, 50.0);
      expect(route.candidateRoutes.first.score, 100.0);
      expect(route.candidateRoutes.last.distance, 80.0);
      expect(route.candidateRoutes.last.score, 0.0);
      expect(route.bestRoute, same(route.candidateRoutes.first));
      expect(route.riskyRoute, same(route.candidateRoutes.last));
    });

    test('throws a ServerException when the route list is empty', () {
      expect(
        () => RouteModel.fromEdgeFunctionJson(
          {'routes': <dynamic>[]},
          41.6378,
          32.3374,
          41.6381,
          32.3380,
        ),
        throwsA(isA<ServerException>()),
      );
    });

    test('throws a ServerException for an invalid geometry', () {
      expect(
        () => RouteModel.fromEdgeFunctionJson(
          {
            'routes': [
              {'geometry': <dynamic>[], 'distance': 10, 'score': 100},
            ],
          },
          41.6378,
          32.3374,
          41.6381,
          32.3380,
        ),
        throwsA(isA<ServerException>()),
      );
    });

    test('keeps parsing the legacy single-route response', () {
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

      expect(route.candidateRoutes, hasLength(1));
      expect(route.bestRoute, same(route.candidateRoutes.single));
      expect(route.riskyRoute, isNull);
      expect(route.distanceInMeters, 123.4);
      expect(route.accessibilityScore, 80.0);
    });
  });
}
