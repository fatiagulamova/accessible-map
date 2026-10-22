// ============================================================
// route_repository.dart
// Route repository'nin soyut (abstract) arayüzü
// ============================================================

import '../entities/route_entity.dart';

/// Erişilebilir rota işlemlerini tanımlayan sözleşme.
/// Data katmanı bu arayüzü implement eder.
abstract class RouteRepository {
  /// Başlangıç ve bitiş koordinatları arasında erişilebilir bir rota hesaplar.
  Future<RouteEntity> getAccessibleRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  });
}
