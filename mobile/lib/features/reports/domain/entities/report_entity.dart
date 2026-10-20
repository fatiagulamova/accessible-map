// ============================================================
// report_entity.dart
// Engel bildirimi için saf domain modeli
// ============================================================

/// Bildirim durumlarını temsil eden enum
enum ReportStatus {
  pending,   // Onay bekliyor
  validated, // Doğrulandı
  rejected,  // Reddedildi
  resolved;  // Çözüldü

  /// String değerden enum'a dönüştürür.
  /// Bilinmeyen değerler için [ReportStatus.pending] döner.
  static ReportStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'validated':
        return ReportStatus.validated;
      case 'rejected':
        return ReportStatus.rejected;
      case 'resolved':
        return ReportStatus.resolved;
      default:
        return ReportStatus.pending;
    }
  }
}

/// Engel bildirimi entity'si
class ReportEntity {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final String? photoUrl;
  final double latitude;
  final double longitude;
  final ReportStatus status;
  final DateTime? createdAt;

  const ReportEntity({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.photoUrl,
    required this.latitude,
    required this.longitude,
    this.status = ReportStatus.pending,
    this.createdAt,
  });

  ReportEntity copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    String? photoUrl,
    double? latitude,
    double? longitude,
    ReportStatus? status,
    DateTime? createdAt,
  }) {
    return ReportEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      photoUrl: photoUrl ?? this.photoUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'ReportEntity(id: $id, title: $title, status: $status, '
      'latitude: $latitude, longitude: $longitude)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          title == other.title &&
          description == other.description &&
          photoUrl == other.photoUrl &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          status == other.status &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(
        id,
        userId,
        title,
        description,
        photoUrl,
        latitude,
        longitude,
        status,
        createdAt,
      );
}
