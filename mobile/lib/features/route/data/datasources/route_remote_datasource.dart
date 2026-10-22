// ============================================================
// route_remote_datasource.dart
// OSRM üzerinden rota, Supabase üzerinden erişilebilirlik verisi
// ============================================================

import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/route_entity.dart';
import '../models/route_model.dart';

/// Rota ve erişilebilirlik verilerini uzak kaynaklardan getirir.
abstract class RouteRemoteDataSource {
  Future<RouteModel> getAccessibleRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  });
}

/// OSRM ve Supabase implementasyonu.
class RouteRemoteDataSourceImpl implements RouteRemoteDataSource {
  static const String _osrmBaseUrl =
      'https://router.project-osrm.org/route/v1/foot';
  static const Duration _requestTimeout = Duration(seconds: 20);
  static const double _nearbyRadiusInMeters = 50;
  static const double _boundingBoxPaddingInDegrees = 0.001;
  static const List<String> _activeReportStatuses = ['pending', 'validated'];
  static const Map<String, double> _reportPenalties = {
    'bozuk kaldırım': 15,
    'rampa eksikliği': 20,
    'dar geçiş': 10,
    'asansör arızası': 15,
  };

  final http.Client _httpClient;
  final SupabaseClient _supabase;

  RouteRemoteDataSourceImpl({
    required http.Client httpClient,
    required SupabaseClient supabase,
  }) : _httpClient = httpClient,
       _supabase = supabase;

  @override
  Future<RouteModel> getAccessibleRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    final uri = Uri.parse(
      '$_osrmBaseUrl/${startLng.toString()},${startLat.toString()};'
      '${endLng.toString()},${endLat.toString()}'
      '?overview=full&geometries=geojson',
    );

    final response = await _httpClient
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(_requestTimeout);

    if (response.statusCode != 200) {
      throw ServerException(
        message: 'OSRM sunucusu ${response.statusCode} yanıtı döndürdü',
        code: 'OSRM_HTTP_${response.statusCode}',
      );
    }

    final json = _decodeResponse(response.body);
    final route = RouteModel.fromOsrmJson(
      json,
      startLat,
      startLng,
      endLat,
      endLng,
    );

    final accessibilityScore = await _calculateAccessibilityScore(
      route.pathPoints,
    );

    return route.copyWith(accessibilityScore: accessibilityScore);
  }

  // ============================================================
  // OSRM YANITI
  // ============================================================

  Map<String, dynamic> _decodeResponse(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;

      throw const ServerException(message: 'OSRM yanıtı geçersiz');
    } on ServerException {
      rethrow;
    } on FormatException {
      throw const ServerException(message: 'OSRM yanıtı çözümlenemedi');
    }
  }

  // ============================================================
  // ERİŞİLEBİLİRLİK PUANI
  // ============================================================

  /// Rota yakınındaki aktif bildirimleri ve olumlu özellikleri puanlar.
  ///
  /// MVP yaklaşımı: Supabase'de rota koordinatlarının sınır kutusundaki
  /// konumlar çekilir, ardından 50 m mesafe kontrolü Dart tarafında
  /// Haversine formülüyle yapılır.
  Future<double> _calculateAccessibilityScore(List<LatLng> pathPoints) async {
    if (pathPoints.isEmpty) return 100.0;

    final bounds = _RouteBounds.fromPath(
      pathPoints,
      paddingInDegrees: _boundingBoxPaddingInDegrees,
    );

    final locationRows = await _supabase
        .from('locations')
        .select('id, latitude, longitude')
        .gte('latitude', bounds.minLatitude)
        .lte('latitude', bounds.maxLatitude)
        .gte('longitude', bounds.minLongitude)
        .lte('longitude', bounds.maxLongitude);

    final locationsById = <String, LatLng>{};
    for (final row in locationRows) {
      final id = row['id'];
      if (id is! String) continue;

      final latitude = _asDouble(row['latitude']);
      final longitude = _asDouble(row['longitude']);
      if (latitude == null || longitude == null) continue;

      locationsById[id] = LatLng(latitude: latitude, longitude: longitude);
    }

    if (locationsById.isEmpty) return 100.0;

    final locationIds = locationsById.keys.toList(growable: false);

    final reportRows = await _supabase
        .from('reports')
        .select('title, location_id')
        .inFilter('location_id', locationIds)
        .inFilter('status', _activeReportStatuses);

    final featureRows = await _supabase
        .from('accessibility_features')
        .select('feature_type, has_ramp, has_elevator, location_id')
        .inFilter('location_id', locationIds);

    var score = 100.0;

    for (final row in reportRows) {
      final location = locationsById[row['location_id']];
      if (location == null || !_isNearPath(location, pathPoints)) continue;

      final title = row['title'];
      if (title is String) {
        score -= _penaltyForReport(title);
      }
    }

    for (final row in featureRows) {
      final location = locationsById[row['location_id']];
      if (location == null || !_isNearPath(location, pathPoints)) continue;

      final featureType = row['feature_type'];
      if (featureType == 'ramp' || _asBool(row['has_ramp'])) {
        score += 10;
      }
      if (featureType == 'elevator' || _asBool(row['has_elevator'])) {
        score += 5;
      }
    }

    return score.clamp(0.0, 100.0).toDouble();
  }

  double _penaltyForReport(String title) {
    final normalizedTitle = title.trim().toLowerCase();

    for (final entry in _reportPenalties.entries) {
      if (normalizedTitle.contains(entry.key)) return entry.value;
    }

    return 0;
  }

  bool _isNearPath(LatLng point, List<LatLng> pathPoints) {
    if (pathPoints.isEmpty) return false;

    if (pathPoints.length == 1) {
      return _haversineDistanceInMeters(point, pathPoints.first) <=
          _nearbyRadiusInMeters;
    }

    // Yalnızca köşe noktalarına bakmak uzun düz segmentlerde yakındaki
    // noktaları kaçırabilir; her segment için en yakın noktayı hesapla.
    for (var i = 0; i < pathPoints.length - 1; i++) {
      final nearestPoint = _nearestPointOnSegment(
        point,
        pathPoints[i],
        pathPoints[i + 1],
      );

      if (_haversineDistanceInMeters(point, nearestPoint) <=
          _nearbyRadiusInMeters) {
        return true;
      }
    }

    return false;
  }

  /// [point] noktasının [start]-[end] segmentine en yakın noktasını döndürür.
  ///
  /// 50 m'lik mesafelerde yeterince doğru olan yerel düzlem yaklaşımı kullanır;
  /// nihai mesafe hesabı Haversine formülüyle yapılır.
  LatLng _nearestPointOnSegment(LatLng point, LatLng start, LatLng end) {
    const metersPerDegreeLatitude = 111320.0;
    final metersPerDegreeLongitude =
        metersPerDegreeLatitude * math.cos(_toRadians(point.latitude)).abs();

    final startX =
        (start.longitude - point.longitude) * metersPerDegreeLongitude;
    final startY = (start.latitude - point.latitude) * metersPerDegreeLatitude;
    final endX = (end.longitude - point.longitude) * metersPerDegreeLongitude;
    final endY = (end.latitude - point.latitude) * metersPerDegreeLatitude;

    final segmentX = endX - startX;
    final segmentY = endY - startY;
    final segmentLengthSquared = segmentX * segmentX + segmentY * segmentY;

    if (segmentLengthSquared == 0) return start;

    final projection =
        (-(startX * segmentX + startY * segmentY) / segmentLengthSquared)
            .clamp(0.0, 1.0)
            .toDouble();

    final nearestX = startX + projection * segmentX;
    final nearestY = startY + projection * segmentY;

    return LatLng(
      latitude: point.latitude + nearestY / metersPerDegreeLatitude,
      longitude: point.longitude + nearestX / metersPerDegreeLongitude,
    );
  }

  double _haversineDistanceInMeters(LatLng from, LatLng to) {
    const earthRadiusInMeters = 6371000.0;

    final latitudeDelta = _toRadians(to.latitude - from.latitude);
    final longitudeDelta = _toRadians(to.longitude - from.longitude);
    final fromLatitude = _toRadians(from.latitude);
    final toLatitude = _toRadians(to.latitude);

    final sinLatitude = math.sin(latitudeDelta / 2);
    final sinLongitude = math.sin(longitudeDelta / 2);

    final a =
        sinLatitude * sinLatitude +
        math.cos(fromLatitude) *
            math.cos(toLatitude) *
            sinLongitude *
            sinLongitude;

    return 2 * earthRadiusInMeters * math.asin(math.sqrt(math.min(1.0, a)));
  }

  double _toRadians(double degrees) => degrees * math.pi / 180.0;

  double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  bool _asBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }
}

/// Rota koordinatlarının sınır kutusunu hesaplar.
class _RouteBounds {
  final double minLatitude;
  final double maxLatitude;
  final double minLongitude;
  final double maxLongitude;

  const _RouteBounds({
    required this.minLatitude,
    required this.maxLatitude,
    required this.minLongitude,
    required this.maxLongitude,
  });

  factory _RouteBounds.fromPath(
    List<LatLng> pathPoints, {
    required double paddingInDegrees,
  }) {
    var minLatitude = pathPoints.first.latitude;
    var maxLatitude = pathPoints.first.latitude;
    var minLongitude = pathPoints.first.longitude;
    var maxLongitude = pathPoints.first.longitude;

    for (final point in pathPoints.skip(1)) {
      if (point.latitude < minLatitude) minLatitude = point.latitude;
      if (point.latitude > maxLatitude) maxLatitude = point.latitude;
      if (point.longitude < minLongitude) minLongitude = point.longitude;
      if (point.longitude > maxLongitude) maxLongitude = point.longitude;
    }

    return _RouteBounds(
      minLatitude: minLatitude - paddingInDegrees,
      maxLatitude: maxLatitude + paddingInDegrees,
      minLongitude: minLongitude - paddingInDegrees,
      maxLongitude: maxLongitude + paddingInDegrees,
    );
  }
}
