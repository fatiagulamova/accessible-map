// ============================================================
// get_accessible_route_usecase.dart
// Erişilebilir rota hesaplama iş kuralı
// ============================================================

import '../../../../core/errors/failures.dart';
import '../entities/route_entity.dart';
import '../repositories/route_repository.dart';

class GetAccessibleRouteUseCase {
  final RouteRepository repository;

  GetAccessibleRouteUseCase(this.repository);

  /// Koordinatları doğrular ve rota hesaplamayı repository'ye devreder.
  Future<RouteEntity> call({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    if (!_isValidLatitude(startLat)) {
      throw const ValidationFailure(
        message: 'Başlangıç enlemi -90 ile 90 arasında olmalıdır',
      );
    }

    if (!_isValidLongitude(startLng)) {
      throw const ValidationFailure(
        message: 'Başlangıç boylamı -180 ile 180 arasında olmalıdır',
      );
    }

    if (!_isValidLatitude(endLat)) {
      throw const ValidationFailure(
        message: 'Bitiş enlemi -90 ile 90 arasında olmalıdır',
      );
    }

    if (!_isValidLongitude(endLng)) {
      throw const ValidationFailure(
        message: 'Bitiş boylamı -180 ile 180 arasında olmalıdır',
      );
    }

    return repository.getAccessibleRoute(
      startLat: startLat,
      startLng: startLng,
      endLat: endLat,
      endLng: endLng,
    );
  }

  bool _isValidLatitude(double latitude) =>
      latitude.isFinite && latitude >= -90 && latitude <= 90;

  bool _isValidLongitude(double longitude) =>
      longitude.isFinite && longitude >= -180 && longitude <= 180;
}
