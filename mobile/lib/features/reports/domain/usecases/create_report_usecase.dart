// ============================================================
// create_report_usecase.dart
// Yeni engel bildirimi oluşturma iş kuralı
// ============================================================

import '../../../../core/errors/failures.dart';
import '../entities/report_entity.dart';
import '../repositories/report_repository.dart';

class CreateReportUseCase {
  final ReportRepository repository;

  CreateReportUseCase(this.repository);

  /// Bildirimi doğrular ve oluşturur.
  /// Başlık boş olamaz; enlem/boylam geçerli aralıkta olmalıdır.
  Future<void> call(ReportEntity report) async {
    if (report.title.trim().isEmpty) {
      throw const ValidationFailure(message: 'Başlık boş bırakılamaz');
    }

    if (!_isValidLatitude(report.latitude)) {
      throw const ValidationFailure(
        message: 'Geçerli bir enlem giriniz (-90 ile 90 arasında)',
      );
    }

    if (!_isValidLongitude(report.longitude)) {
      throw const ValidationFailure(
        message: 'Geçerli bir boylam giriniz (-180 ile 180 arasında)',
      );
    }

    return await repository.createReport(report);
  }

  bool _isValidLatitude(double latitude) =>
      latitude.isFinite && latitude >= -90 && latitude <= 90;

  bool _isValidLongitude(double longitude) =>
      longitude.isFinite && longitude >= -180 && longitude <= 180;
}
