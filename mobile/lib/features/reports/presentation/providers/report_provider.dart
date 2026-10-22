// ============================================================
// report_provider.dart
// Reports ile ilgili tüm Riverpod provider'ları
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../../../../core/errors/exceptions.dart' as core;
import '../../../../core/errors/failures.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/report_remote_datasource.dart';
import '../../data/repositories/report_repository_impl.dart';
import '../../domain/entities/report_entity.dart';
import '../../domain/repositories/report_repository.dart';
import '../../domain/usecases/create_report_usecase.dart';
import '../../domain/usecases/get_nearby_reports_usecase.dart';
import '../../domain/usecases/submit_validation_usecase.dart';

// ============================================================
// DEPENDENCY PROVIDERS
// ============================================================

/// Remote data source
final reportRemoteDataSourceProvider = Provider<ReportRemoteDataSource>((ref) {
  return ReportRemoteDataSourceImpl(ref.watch(supabaseClientProvider));
});

/// Repository
final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepositoryImpl(
    remoteDataSource: ref.watch(reportRemoteDataSourceProvider),
  );
});

/// Use case providers
final createReportUseCaseProvider = Provider<CreateReportUseCase>((ref) {
  return CreateReportUseCase(ref.watch(reportRepositoryProvider));
});

final getNearbyReportsUseCaseProvider = Provider<GetNearbyReportsUseCase>((
  ref,
) {
  return GetNearbyReportsUseCase(ref.watch(reportRepositoryProvider));
});

final submitValidationUseCaseProvider = Provider<SubmitValidationUseCase>((
  ref,
) {
  return SubmitValidationUseCase(ref.watch(reportRepositoryProvider));
});

// ============================================================
// REPORT STATE
// ============================================================

/// Report işlemlerinin durumunu temsil eder
sealed class ReportState {
  const ReportState();
}

class ReportInitial extends ReportState {
  const ReportInitial();
}

class ReportLoading extends ReportState {
  const ReportLoading();
}

class ReportLoaded extends ReportState {
  final List<ReportEntity> reports;

  const ReportLoaded(this.reports);
}

class ReportError extends ReportState {
  final String message;

  const ReportError(this.message);
}

// ============================================================
// REPORT CONTROLLER
// ============================================================

class ReportController extends StateNotifier<ReportState> {
  final GetNearbyReportsUseCase _getNearbyReportsUseCase;
  final CreateReportUseCase _createReportUseCase;
  final SubmitValidationUseCase _submitValidationUseCase;
  final ReportRemoteDataSource _remoteDataSource;
  final String? Function() _currentUserId;

  String? _lastValidationError;

  ReportController({
    required GetNearbyReportsUseCase getNearbyReportsUseCase,
    required CreateReportUseCase createReportUseCase,
    required SubmitValidationUseCase submitValidationUseCase,
    required ReportRemoteDataSource remoteDataSource,
    required String? Function() currentUserId,
  }) : _getNearbyReportsUseCase = getNearbyReportsUseCase,
       _createReportUseCase = createReportUseCase,
       _submitValidationUseCase = submitValidationUseCase,
       _remoteDataSource = remoteDataSource,
       _currentUserId = currentUserId,
       super(const ReportInitial());

  /// Son doğrulama işlemindeki hata mesajı.
  String? get lastValidationError => _lastValidationError;

  /// Belirtilen konumun yakınındaki bildirimleri yükler.
  Future<void> loadNearbyReports(double lat, double lng) async {
    state = const ReportLoading();
    try {
      final reports = await _getNearbyReportsUseCase(
        latitude: lat,
        longitude: lng,
      );
      state = ReportLoaded(reports);
    } catch (e) {
      state = ReportError(_messageFrom(e));
    }
  }

  /// Yeni bildirim oluşturur ve ardından listeyi yeniler.
  Future<bool> submitReport({
    required String title,
    required String description,
    required double lat,
    required double lng,
    XFile? photo,
  }) async {
    final userId = _currentUserId();
    if (userId == null || userId.isEmpty) {
      state = const ReportError('Bildirim göndermek için giriş yapmalısınız');
      return false;
    }

    try {
      String? photoUrl;
      if (photo != null) {
        photoUrl = await _remoteDataSource.uploadReportPhoto(photo);
      }

      final trimmedDescription = description.trim();
      final report = ReportEntity(
        id: '',
        userId: userId,
        title: title.trim(),
        description: trimmedDescription.isEmpty ? null : trimmedDescription,
        photoUrl: photoUrl,
        latitude: lat,
        longitude: lng,
      );

      await _createReportUseCase(report);
      await loadNearbyReports(lat, lng);
      return true;
    } catch (e) {
      state = ReportError(_messageFrom(e));
      return false;
    }
  }

  /// Bildirime doğrulama/red oyu kaydeder.
  /// Başarısız olsa bile mevcut harita işaretlerini korumak için
  /// genel [ReportState] değiştirilmez.
  Future<bool> validateReport(String reportId, bool isValid) async {
    _lastValidationError = null;

    try {
      await _submitValidationUseCase(reportId: reportId, isValid: isValid);
      return true;
    } catch (e) {
      _lastValidationError = _messageFrom(e);
      return false;
    }
  }

  /// Hata mesajını kullanıcıya gösterilecek biçime çevirir.
  String _messageFrom(Object error) {
    if (error is Failure) return error.message;
    if (error is core.AppException) return error.message;
    return error.toString().replaceAll('Failure: ', '');
  }
}

final reportControllerProvider =
    StateNotifierProvider<ReportController, ReportState>((ref) {
      return ReportController(
        getNearbyReportsUseCase: ref.watch(getNearbyReportsUseCaseProvider),
        createReportUseCase: ref.watch(createReportUseCaseProvider),
        submitValidationUseCase: ref.watch(submitValidationUseCaseProvider),
        remoteDataSource: ref.watch(reportRemoteDataSourceProvider),
        currentUserId: () {
          final authState = ref.read(authControllerProvider);
          return authState is AuthAuthenticated ? authState.user.id : null;
        },
      );
    });
