// ============================================================
// report_model.dart
// Supabase'den gelen JSON verisini ReportEntity'ye çevirir
// ============================================================

import '../../domain/entities/report_entity.dart';

/// Data katmanı modeli - JSON dönüşümlerinden sorumlu
class ReportModel extends ReportEntity {
  const ReportModel({
    required super.id,
    required super.userId,
    required super.title,
    super.description,
    super.photoUrl,
    required super.latitude,
    required super.longitude,
    super.status,
    super.createdAt,
  });

  /// Supabase'den gelen JSON'u ReportModel'e çevirir.
  /// Konum bilgisi join'den `locations` altında veya doğrudan
  /// üst seviyede gelebilir; iki durum da desteklenir.
  factory ReportModel.fromJson(Map<String, dynamic> json) {
    final location = _extractLocation(json);

    return ReportModel(
      id: (json['report_id'] ?? json['id']) as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      photoUrl: json['photo_url'] as String?,
      latitude: _asDouble(json['latitude'] ?? location['latitude']),
      longitude: _asDouble(json['longitude'] ?? location['longitude']),
      status: ReportStatus.fromString(json['status'] as String? ?? 'pending'),
      createdAt: _asDateTime(json['created_at']),
    );
  }

  /// Report tablosuna insert için JSON üretir.
  /// `location_id` datasource tarafından eklenir.
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'title': title,
      'description': description,
      'photo_url': photoUrl,
      'status': status.name,
    };
  }

  /// ReportEntity'den ReportModel oluşturur
  factory ReportModel.fromEntity(ReportEntity entity) {
    return ReportModel(
      id: entity.id,
      userId: entity.userId,
      title: entity.title,
      description: entity.description,
      photoUrl: entity.photoUrl,
      latitude: entity.latitude,
      longitude: entity.longitude,
      status: entity.status,
      createdAt: entity.createdAt,
    );
  }

  // ============================================================
  // YARDIMCI METODLAR
  // ============================================================

  /// Join'den gelen konum verisini güvenli şekilde çıkarır.
  static Map<String, dynamic> _extractLocation(Map<String, dynamic> json) {
    Object? raw = json['locations'] ?? json['location'];

    // İlişki liste olarak da dönebilir; ilk elemanı kullan.
    if (raw is List && raw.isNotEmpty) {
      raw = raw.first;
    }

    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return const <String, dynamic>{};
  }

  /// num veya String değerleri double'a çevirir.
  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// ISO 8601 tarih string'ini DateTime'a çevirir.
  static DateTime? _asDateTime(Object? value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
