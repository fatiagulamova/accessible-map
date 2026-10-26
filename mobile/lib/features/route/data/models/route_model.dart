// ============================================================
// route_model.dart
// calculate-route-score Edge Function yanıtını RouteEntity'ye çevirir
// ============================================================

import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/route_entity.dart';

/// Data katmanı modeli - Edge Function rota yanıtını dönüştürür.
class RouteModel extends RouteEntity {
  const RouteModel({
    required super.id,
    required super.startLat,
    required super.startLng,
    required super.endLat,
    required super.endLng,
    required super.candidateRoutes,
    required super.algorithmUsed,
  });

  /// `calculate-route-score` Edge Function yanıtını [RouteModel]'e çevirir.
  ///
  /// Güncel yanıt biçimi:
  /// `{ routes: [{ geometry: [[lng, lat], ...], distance, score }, ...] }`.
  ///
  /// Eski tek rota yanıtı da (`{ geometry, distance, score }`) yeni Edge
  /// Function dağıtılana kadar desteklenir.
  factory RouteModel.fromEdgeFunctionJson(
    Map<String, dynamic> json,
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    final candidateRoutes = <RoutePath>[];

    if (json.containsKey('routes')) {
      final routes = json['routes'];

      if (routes is! List) {
        throw const ServerException(message: 'Rota listesi geçersiz');
      }

      if (routes.isEmpty) {
        throw const ServerException(message: 'Rota bulunamadı');
      }

      for (final route in routes) {
        if (route is! Map) {
          throw const ServerException(message: 'Rota kaydı geçersiz');
        }

        candidateRoutes.add(_parseRoutePath(Map<String, dynamic>.from(route)));
      }
    } else {
      // Geriye dönük uyumluluk: eski Edge Function tek rota döndürür.
      candidateRoutes.add(_parseRoutePath(json));
    }

    return RouteModel(
      id: _buildRouteId(startLat, startLng, endLat, endLng),
      startLat: startLat,
      startLng: startLng,
      endLat: endLat,
      endLng: endLng,
      candidateRoutes: List<RoutePath>.unmodifiable(candidateRoutes),
      algorithmUsed: 'osrm',
    );
  }

  /// Aday rotaları güncellenmiş bir kopya döndürür.
  RouteModel copyWith({List<RoutePath>? candidateRoutes}) {
    return RouteModel(
      id: id,
      startLat: startLat,
      startLng: startLng,
      endLat: endLat,
      endLng: endLng,
      candidateRoutes: candidateRoutes ?? this.candidateRoutes,
      algorithmUsed: algorithmUsed,
    );
  }

  static RoutePath _parseRoutePath(Map<String, dynamic> json) {
    final geometry = json['geometry'];

    if (geometry is! List || geometry.isEmpty) {
      throw const ServerException(message: 'Rota geometrisi bulunamadı');
    }

    final pathPoints = <LatLng>[];

    for (final coordinate in geometry) {
      if (coordinate is! List || coordinate.length < 2) {
        throw const ServerException(message: 'Rota koordinatı geçersiz');
      }

      // GeoJSON sırası: [longitude, latitude]
      pathPoints.add(
        LatLng(
          latitude: _asDouble(coordinate[1], 'enlem'),
          longitude: _asDouble(coordinate[0], 'boylam'),
        ),
      );
    }

    final distance = _asDouble(json['distance'], 'mesafe');
    final score = _asDouble(json['score'], 'erişilebilirlik puanı');

    if (!distance.isFinite || distance < 0) {
      throw const ServerException(message: 'Rota mesafesi geçersiz');
    }

    if (!score.isFinite) {
      throw const ServerException(message: 'Erişilebilirlik puanı geçersiz');
    }

    return RoutePath(
      geometry: List<LatLng>.unmodifiable(pathPoints),
      distance: distance,
      score: score.clamp(0.0, 100.0).toDouble(),
    );
  }

  // ============================================================
  // YARDIMCI METODLAR
  // ============================================================

  static double _asDouble(Object? value, String field) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
    }

    throw ServerException(message: 'Rota yanıtında geçersiz $field');
  }

  static String _buildRouteId(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return 'osrm-${startLat.toStringAsFixed(6)}_'
        '${startLng.toStringAsFixed(6)}_'
        '${endLat.toStringAsFixed(6)}_'
        '${endLng.toStringAsFixed(6)}';
  }
}
