// ============================================================
// report_repository.dart
// Reports repository'nin soyut (abstract) arayüzü
// ============================================================

import '../entities/report_entity.dart';

/// Reports işlemlerini tanımlayan sözleşme.
/// Data katmanı bu arayüzü implement eder.
abstract class ReportRepository {
  /// Belirtilen konumun yakınındaki bildirimleri getirir.
  Future<List<ReportEntity>> getNearbyReports({
    required double latitude,
    required double longitude,
    double radiusInMeters = 1000,
  });

  /// Yeni bir engel bildirimi oluşturur.
  Future<void> createReport(ReportEntity report);
}
