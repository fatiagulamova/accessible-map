// ============================================================
// route_entity.dart
// Akıllı navigasyon için saf domain modeli
// ============================================================

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

/// Hesaplanan erişilebilir rotayı temsil eden entity.
class RouteEntity {
  final String id;
  final double startLat;
  final double startLng;
  final double endLat;
  final double endLng;
  final double distanceInMeters;

  /// 0-100 arasında erişilebilirlik puanı.
  final double accessibilityScore;

  /// Rota geometrisini oluşturan koordinatlar.
  final List<LatLng> pathPoints;

  /// Rotayı üreten algoritma: 'astar' veya 'dijkstra'.
  final String algorithmUsed;

  const RouteEntity({
    required this.id,
    required this.startLat,
    required this.startLng,
    required this.endLat,
    required this.endLng,
    required this.distanceInMeters,
    required this.accessibilityScore,
    required this.pathPoints,
    required this.algorithmUsed,
  });

  @override
  String toString() =>
      'RouteEntity(id: $id, distanceInMeters: $distanceInMeters, '
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
          distanceInMeters == other.distanceInMeters &&
          accessibilityScore == other.accessibilityScore &&
          algorithmUsed == other.algorithmUsed &&
          _latLngListsEqual(pathPoints, other.pathPoints);

  @override
  int get hashCode => Object.hash(
    id,
    startLat,
    startLng,
    endLat,
    endLng,
    distanceInMeters,
    accessibilityScore,
    algorithmUsed,
    Object.hashAll(pathPoints),
  );
}

bool _latLngListsEqual(List<LatLng> a, List<LatLng> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;

  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
