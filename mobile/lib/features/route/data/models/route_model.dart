// ============================================================
// route_model.dart
// OSRM GeoJSON yanıtını RouteEntity'ye çevirir
// ============================================================

import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/route_entity.dart';

/// Data katmanı modeli - OSRM JSON dönüşümlerinden sorumlu.
class RouteModel extends RouteEntity {
  const RouteModel({
    required super.id,
    required super.startLat,
    required super.startLng,
    required super.endLat,
    required super.endLng,
    required super.distanceInMeters,
    required super.accessibilityScore,
    required super.pathPoints,
    required super.algorithmUsed,
  });

  /// OSRM `/route/v1/foot/...` yanıtını [RouteModel]'e çevirir.
  ///
  /// OSRM GeoJSON koordinatları `[longitude, latitude]` sırasındadır.
  /// Erişilebilirlik puanı başlangıçta 100'dür; datasource, yakındaki
  /// bildirim ve özelliklere göre [copyWith] ile günceller.
  factory RouteModel.fromOsrmJson(
    Map<String, dynamic> json,
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    final code = json['code'];
    final routes = json['routes'];

    if (code is! String ||
        code.toLowerCase() != 'ok' ||
        routes is! List ||
        routes.isEmpty) {
      throw ServerException(
        message:
            code == null
                ? 'OSRM rotası bulunamadı'
                : 'OSRM rotası bulunamadı (kod: $code)',
      );
    }

    final route = _asMap(routes.first, 'rota');
    final geometry = _asMap(route['geometry'], 'geometri');
    final coordinates = geometry['coordinates'];

    if (coordinates is! List || coordinates.isEmpty) {
      throw const ServerException(message: 'OSRM rota geometrisi boş');
    }

    final pathPoints = <LatLng>[];
    for (final coordinate in coordinates) {
      if (coordinate is! List || coordinate.length < 2) {
        throw const ServerException(message: 'OSRM koordinatı geçersiz');
      }

      // GeoJSON sırası: [longitude, latitude]
      pathPoints.add(
        LatLng(
          latitude: _asDouble(coordinate[1], 'enlem'),
          longitude: _asDouble(coordinate[0], 'boylam'),
        ),
      );
    }

    return RouteModel(
      id: _buildRouteId(startLat, startLng, endLat, endLng),
      startLat: startLat,
      startLng: startLng,
      endLat: endLat,
      endLng: endLng,
      distanceInMeters: _asDouble(route['distance'], 'mesafe'),
      accessibilityScore: 100,
      pathPoints: pathPoints,
      algorithmUsed: 'osrm',
    );
  }

  /// Erişilebilirlik puanı güncellenmiş bir kopya döndürür.
  RouteModel copyWith({double? accessibilityScore}) {
    return RouteModel(
      id: id,
      startLat: startLat,
      startLng: startLng,
      endLat: endLat,
      endLng: endLng,
      distanceInMeters: distanceInMeters,
      accessibilityScore: accessibilityScore ?? this.accessibilityScore,
      pathPoints: pathPoints,
      algorithmUsed: algorithmUsed,
    );
  }

  // ============================================================
  // YARDIMCI METODLAR
  // ============================================================

  static Map<String, dynamic> _asMap(Object? value, String field) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);

    throw ServerException(message: 'OSRM yanıtında geçersiz $field');
  }

  static double _asDouble(Object? value, String field) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
    }

    throw ServerException(message: 'OSRM yanıtında geçersiz $field');
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
