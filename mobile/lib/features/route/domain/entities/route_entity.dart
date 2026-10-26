// ============================================================
// route_entity.dart
// Akıllı navigasyon için saf domain modeli
// ============================================================

/// Kullanıcının rota hesaplamasında uygulanacak erişilebilirlik tercihleri.
///
/// Tüm alanlar varsayılan olarak `false`'tur; böylece tercih belirtmeyen
/// mevcut çağrılar önceki davranışla aynı sonucu alır.
class RoutePreferences {
  final bool isWheelchair;
  final bool requireElevator;
  final bool preferRamp;
  final bool prioritizeDistance;

  const RoutePreferences({
    this.isWheelchair = false,
    this.requireElevator = false,
    this.preferRamp = false,
    this.prioritizeDistance = false,
  });

  /// Edge Function isteğinde kullanılacak JSON temsili.
  Map<String, bool> toJson() => {
    'isWheelchair': isWheelchair,
    'requireElevator': requireElevator,
    'preferRamp': preferRamp,
    'prioritizeDistance': prioritizeDistance,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutePreferences &&
          runtimeType == other.runtimeType &&
          isWheelchair == other.isWheelchair &&
          requireElevator == other.requireElevator &&
          preferRamp == other.preferRamp &&
          prioritizeDistance == other.prioritizeDistance;

  @override
  int get hashCode => Object.hash(
    isWheelchair,
    requireElevator,
    preferRamp,
    prioritizeDistance,
  );

  @override
  String toString() =>
      'RoutePreferences(isWheelchair: $isWheelchair, '
      'requireElevator: $requireElevator, preferRamp: $preferRamp, '
      'prioritizeDistance: $prioritizeDistance)';
}

/// Rota üzerindeki bir koordinatı temsil eden saf Dart değer nesnesi.
///
/// Flutter/MapLibre bağımlılığı yoktur; sunum katmanında MapLibre'nin
/// `LatLng` tipine dönüştürülebilir.
class LatLng {
  final double latitude;
  final double longitude;

  const LatLng({required this.latitude, required this.longitude});

  Map<String, double> toMap() => {'latitude': latitude, 'longitude': longitude};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LatLng &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'LatLng(latitude: $latitude, longitude: $longitude)';
}

/// OSRM'nin döndürdüğü tek bir aday rotayı temsil eden değer nesnesi.
///
/// [geometry] GeoJSON sırasından bağımsız olarak enlem/boylam noktalarıdır.
/// [distance] metre cinsindendir. [score] 0-100 aralığındaki erişilebilirlik
/// puanıdır.
class RoutePath {
  final List<LatLng> geometry;
  final double distance;
  final double score;

  const RoutePath({
    required this.geometry,
    required this.distance,
    required this.score,
  });

  /// Domain katmanındaki mevcut isimlendirmeyle uyumluluk için kısayollar.
  List<LatLng> get pathPoints => geometry;
  double get distanceInMeters => distance;
  double get accessibilityScore => score;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutePath &&
          runtimeType == other.runtimeType &&
          distance == other.distance &&
          score == other.score &&
          _latLngListsEqual(geometry, other.geometry);

  @override
  int get hashCode => Object.hash(distance, score, Object.hashAll(geometry));

  @override
  String toString() =>
      'RoutePath(distance: $distance, score: $score, '
      'points: ${geometry.length})';
}

/// Hesaplanan erişilebilir rotayı ve aday rotalarını temsil eden entity.
class RouteEntity {
  final String id;
  final double startLat;
  final double startLng;
  final double endLat;
  final double endLng;

  /// OSRM'nin döndürdüğü tüm geçerli aday rotalar (en fazla 3).
  final List<RoutePath> candidateRoutes;

  /// Rotayı üreten algoritma: 'astar', 'dijkstra' veya 'osrm'.
  final String algorithmUsed;

  const RouteEntity({
    required this.id,
    required this.startLat,
    required this.startLng,
    required this.endLat,
    required this.endLng,
    required this.candidateRoutes,
    required this.algorithmUsed,
  });

  /// En yüksek puanlı aday rota; eşit puanlarda en kısa olan tercih edilir.
  RoutePath? get bestRoute {
    if (candidateRoutes.isEmpty) return null;
    return candidateRoutes[_bestRouteIndex];
  }

  /// En düşük puanlı alternatif rota.
  ///
  /// Tek aday varsa `null` döner. Eşit puanlarda daha uzun rota "riskli"
  /// alternatif olarak kabul edilir.
  RoutePath? get riskyRoute {
    if (candidateRoutes.length < 2) return null;

    final bestIndex = _bestRouteIndex;
    RoutePath? risky;

    for (var index = 0; index < candidateRoutes.length; index++) {
      if (index == bestIndex) continue;

      final route = candidateRoutes[index];
      if (risky == null ||
          route.score < risky.score ||
          (route.score == risky.score && route.distance > risky.distance)) {
        risky = route;
      }
    }

    return risky;
  }

  int get _bestRouteIndex {
    var bestIndex = 0;
    var best = candidateRoutes[bestIndex];

    for (var index = 1; index < candidateRoutes.length; index++) {
      final route = candidateRoutes[index];

      if (route.score > best.score ||
          (route.score == best.score && route.distance < best.distance)) {
        best = route;
        bestIndex = index;
      }
    }

    return bestIndex;
  }

  // En iyi rota üzerinden eski tek-rota API'sini koruyan kısayollar.
  List<LatLng> get pathPoints => bestRoute?.geometry ?? const <LatLng>[];
  double get distanceInMeters => bestRoute?.distance ?? 0;
  double get accessibilityScore => bestRoute?.score ?? 0;

  @override
  String toString() =>
      'RouteEntity(id: $id, candidates: ${candidateRoutes.length}, '
      'distanceInMeters: $distanceInMeters, '
      'accessibilityScore: $accessibilityScore, '
      'algorithmUsed: $algorithmUsed)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RouteEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          startLat == other.startLat &&
          startLng == other.startLng &&
          endLat == other.endLat &&
          endLng == other.endLng &&
          algorithmUsed == other.algorithmUsed &&
          _routePathListsEqual(candidateRoutes, other.candidateRoutes);

  @override
  int get hashCode => Object.hash(
    id,
    startLat,
    startLng,
    endLat,
    endLng,
    algorithmUsed,
    Object.hashAll(candidateRoutes),
  );
}

bool _routePathListsEqual(List<RoutePath> a, List<RoutePath> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;

  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _latLngListsEqual(List<LatLng> a, List<LatLng> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;

  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
