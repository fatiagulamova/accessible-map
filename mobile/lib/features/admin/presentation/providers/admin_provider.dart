// ============================================================
// admin_provider.dart
// Admin panelindeki bildirim yönetiminin durumunu yönetir
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/exceptions.dart' as core;
import '../../../../core/errors/failures.dart';
import '../../../reports/domain/entities/report_entity.dart';
import '../../../reports/domain/repositories/report_repository.dart';
import '../../../reports/presentation/providers/report_provider.dart';

// ============================================================
// ADMIN STATE
// ============================================================

sealed class AdminState {
  const AdminState();
}

class AdminInitial extends AdminState {
  const AdminInitial();
}

class AdminLoading extends AdminState {
  const AdminLoading();
}

class AdminLoaded extends AdminState {
  final List<ReportEntity> reports;

  const AdminLoaded(this.reports);
}

class AdminError extends AdminState {
  final String message;

  const AdminError(this.message);
}

// ============================================================
// ADMIN CONTROLLER
// ============================================================

class AdminController extends StateNotifier<AdminState> {
  final ReportRepository _repository;

  String? _lastDeleteError;

  AdminController(this._repository) : super(const AdminInitial());

  /// Son silme işlemindeki hata mesajı.
  String? get lastDeleteError => _lastDeleteError;

  /// Tüm bildirimleri yükler.
  Future<void> fetchAllReports() async {
    if (state is AdminLoading) return;

    state = const AdminLoading();
    try {
      final reports = await _repository.getAllReports();
      state = AdminLoaded(reports);
    } catch (e) {
      state = AdminError(_messageFrom(e));
    }
  }

  /// Bildirimi siler. Başarı durumunda `true` döner.
  /// Listenin yenilenmesi çağıran tarafın sorumluluğundadır.
  Future<bool> deleteReport(String id) async {
    _lastDeleteError = null;

    try {
      await _repository.deleteReport(id);
      return true;
    } catch (e) {
      _lastDeleteError = _messageFrom(e);
      return false;
    }
  }

  String _messageFrom(Object error) {
    if (error is Failure) return error.message;
    if (error is core.AppException) return error.message;
    return error.toString().replaceAll('Failure: ', '');
  }
}

final adminControllerProvider =
    StateNotifierProvider<AdminController, AdminState>((ref) {
      return AdminController(ref.watch(reportRepositoryProvider));
    });
