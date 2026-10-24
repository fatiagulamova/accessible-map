// ============================================================
// report_remote_datasource.dart
// Supabase üzerinden report işlemlerini gerçekleştirir
// ============================================================

import 'package:image_picker/image_picker.dart' show XFile;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart' hide AuthException;
import '../../domain/entities/report_entity.dart';
import '../models/report_model.dart';

/// Reports işlemlerini Supabase üzerinden gerçekleştirir.
abstract class ReportRemoteDataSource {
  Future<List<ReportModel>> getNearbyReports({
    required double latitude,
    required double longitude,
    double radiusInMeters = 1000,
  });

  Future<void> createReport(ReportEntity report);

  Future<void> submitValidation({
    required String reportId,
    required bool isValid,
  });

  Future<List<ReportEntity>> getAllReports();

  /// Bildirim akışında gösterilecek en son 50 bildirimi getirir.
  Future<List<ReportEntity>> getAllRecentReports();

  Future<void> deleteReport(String reportId);

  Future<String> uploadReportPhoto(XFile photo);
}

/// Supabase implementasyonu
class ReportRemoteDataSourceImpl implements ReportRemoteDataSource {
  final SupabaseClient _supabase;

  ReportRemoteDataSourceImpl(this._supabase);

  @override
  Future<List<ReportModel>> getNearbyReports({
    required double latitude,
    required double longitude,
    double radiusInMeters = 1000,
  }) async {
    final response = await _supabase.rpc(
      'nearby_reports',
      params: {
        'p_lat': latitude,
        'p_lng': longitude,
        'p_radius_m': radiusInMeters,
      },
    );

    final rows = response as List<dynamic>;
    return rows
        .map(
          (row) => ReportModel.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  @override
  Future<void> createReport(ReportEntity report) async {
    // 1. Konumu kaydet
    final location =
        await _supabase
            .from('locations')
            .insert({
              'latitude': report.latitude,
              'longitude': report.longitude,
            })
            .select('id')
            .single();

    final locationId = location['id'] as String?;
    if (locationId == null) {
      throw const ServerException(message: 'Konum kaydedilemedi');
    }

    // 2. Bildirimi konum ile ilişkilendirerek kaydet
    final reportData = ReportModel.fromEntity(report).toJson();
    await _supabase.from('reports').insert({
      ...reportData,
      'location_id': locationId,
    });
  }

  @override
  Future<void> submitValidation({
    required String reportId,
    required bool isValid,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const AuthException('Oy kaydetmek için giriş yapmalısınız');
    }

    try {
      await _supabase.from('validations').insert({
        'report_id': reportId,
        'user_id': user.id,
        'is_valid': isValid,
      });
    } on PostgrestException catch (e) {
      final isDuplicateVote =
          e.code == '23505' ||
          e.message.toLowerCase().contains('duplicate key');

      if (isDuplicateVote) {
        throw ValidationException(
          message: 'Bu bildirimi zaten oyladınız.',
          code: e.code,
        );
      }

      throw ServerException(
        message: 'Oy kaydedilemedi: ${e.message}',
        code: e.code,
      );
    }
  }

  @override
  Future<List<ReportEntity>> getAllReports() async {
    // Konum bilgisi ayrı tabloda tutulduğu için ilişkiyi de seç.
    final response = await _supabase
        .from('reports')
        .select('*, locations(latitude, longitude)')
        .order('created_at', ascending: false);

    return response
        .map<ReportEntity>(
          (row) => ReportModel.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  @override
  Future<List<ReportEntity>> getAllRecentReports() async {
    final response = await _supabase
        .from('reports')
        .select(
          'id, user_id, title, description, photo_url, status, created_at, '
          'locations(latitude, longitude)',
        )
        .order('created_at', ascending: false)
        .limit(50);

    return response
        .map<ReportEntity>(
          (row) => ReportModel.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  @override
  Future<void> deleteReport(String reportId) async {
    await _supabase.from('reports').delete().eq('id', reportId);
  }

  @override
  Future<String> uploadReportPhoto(XFile photo) async {
    try {
      final bytes = await photo.readAsBytes();

      final extension = _fileExtension(photo.name);
      final fileName =
          'report_${DateTime.now().millisecondsSinceEpoch}.$extension';

      await _supabase.storage
          .from('report_photos')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(contentType: _contentType(extension)),
          );

      return _supabase.storage.from('report_photos').getPublicUrl(fileName);
    } on StorageException catch (e) {
      throw ServerException(message: 'Fotoğraf yüklenemedi: ${e.message}');
    } catch (e) {
      throw ServerException(message: 'Fotoğraf yüklenemedi: $e');
    }
  }

  // ============================================================
  // YARDIMCI METODLAR
  // ============================================================

  /// Dosya adından güvenli bir uzantı çıkarır.
  String _fileExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == fileName.length - 1) return 'jpg';

    final extension = fileName.substring(dotIndex + 1).toLowerCase();
    return const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)
        ? extension
        : 'jpg';
  }

  /// Uzantıya uygun MIME türünü döndürür.
  String _contentType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
