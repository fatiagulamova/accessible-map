// ============================================================
// submit_validation_usecase.dart
// Bir bildirime doğrulama/red oyu kaydetme iş kuralı
// ============================================================

import '../repositories/report_repository.dart';

class SubmitValidationUseCase {
  final ReportRepository repository;

  SubmitValidationUseCase(this.repository);

  /// Bildirime kullanıcının oyunu kaydeder.
  Future<void> call({required String reportId, required bool isValid}) {
    return repository.submitValidation(reportId: reportId, isValid: isValid);
  }
}
