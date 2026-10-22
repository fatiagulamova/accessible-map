// ============================================================
// report_repository_impl.dart
// ReportRepository arayüzünün gerçek implementasyonu
// ============================================================

import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/errors/exceptions.dart' as core;
import '../../../../core/errors/failures.dart';
import '../../domain/entities/report_entity.dart';
import '../../domain/repositories/report_repository.dart';
import '../datasources/report_remote_datasource.dart';

class ReportRepositoryImpl implements ReportRepository {
  final ReportRemoteDataSource remoteDataSource;

  ReportRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<ReportEntity>> getNearbyReports({
    required double latitude,
    required double longitude,
    double radiusInMeters = 1000,
  }) {
    return _handleExceptions(() async {
      return await remoteDataSource.getNearbyReports(
        latitude: latitude,
        longitude: longitude,
        radiusInMeters: radiusInMeters,
      );
    });
  }

  @override
  Future<void> createReport(ReportEntity report) {
    return _handleExceptions(() async {
      await remoteDataSource.createReport(report);
    });
  }

  @override
  Future<void> submitValidation({
    required String reportId,
    required bool isValid,
  }) {
    return _handleExceptions(() async {
      await remoteDataSource.submitValidation(
        reportId: reportId,
        isValid: isValid,
      );
    });
  }

  @override
  Future<List<ReportEntity>> getAllReports() {
    return _handleExceptions(() async {
      return await remoteDataSource.getAllReports();
    });
  }

  @override
  Future<void> deleteReport(String reportId) {
    return _handleExceptions(() async {
      await remoteDataSource.deleteReport(reportId);
    });
  }

  // ============================================================
  // YARDIMCI METOD
  // Exception'ları Failure'lara çevirir (UI'da gösterilecek)
  // ============================================================
  Future<T> _handleExceptions<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on sb.AuthException catch (e) {
      throw AuthFailure(message: e.message, code: e.statusCode);
    } on sb.PostgrestException catch (e) {
      throw ServerFailure(message: e.message, code: e.code);
    } on http.ClientException catch (e) {
      throw NetworkFailure(message: 'Ağ bağlantısı hatası: ${e.message}');
    } on TimeoutException {
      throw const NetworkFailure();
    } on core.AuthException catch (e) {
      throw AuthFailure(message: e.message, code: e.code);
    } on core.NetworkException catch (e) {
      throw NetworkFailure(message: e.message, code: e.code);
    } on core.ServerException catch (e) {
      throw ServerFailure(message: e.message, code: e.code);
    } on core.CacheException catch (e) {
      throw CacheFailure(message: e.message, code: e.code);
    } on core.ValidationException catch (e) {
      throw ValidationFailure(message: e.message, code: e.code);
    } catch (e) {
      throw UnknownFailure(message: 'Beklenmeyen hata: $e');
    }
  }
}
