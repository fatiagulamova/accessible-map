// ============================================================
// get_nearby_reports_usecase.dart
// Yakındaki engel bildirimlerini getirme iş kuralı
// ============================================================

import '../entities/report_entity.dart';
import '../repositories/report_repository.dart';

class GetNearbyReportsUseCase {
  final ReportRepository repository;

  GetNearbyReportsUseCase(this.repository);

  /// Parametreleri repository'ye devreder.
  Future<List<ReportEntity>> call({
    required double latitude,
    required double longitude,
    double radiusInMeters = 1000,
  }) {
    return repository.getNearbyReports(
      latitude: latitude,
      longitude: longitude,
      radiusInMeters: radiusInMeters,
    );
  }
}
