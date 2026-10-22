// ============================================================
// report_categories.dart
// Bildirim kategorileri: form seçenekleri ve harita işaretleri
// ============================================================

import 'package:flutter/material.dart';

/// Bir bildirim kategorisinin form etiketini, ikonunu ve rengini taşır.
///
/// Aynı tanımlar hem bildirim formundaki kategori çiplerinde hem de harita
/// üzerindeki bildirim işaretlerinde kullanılır.
@immutable
class ReportCategory {
  const ReportCategory({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  /// Harita görsel kimliği için ASCII anahtar (ör. `ramp`).
  final String key;

  /// Kullanıcıya gösterilen kategori adı.
  final String label;

  final IconData icon;
  final Color color;

  String get markerIconId => 'report-marker-$key';

  static const ReportCategory ramp = ReportCategory(
    key: 'ramp',
    label: 'Rampa',
    icon: Icons.ramp_right,
    color: Color(0xFF4CAF50),
  );

  static const ReportCategory stairs = ReportCategory(
    key: 'stairs',
    label: 'Merdiven',
    icon: Icons.stairs,
    color: Color(0xFFFF9800),
  );

  static const ReportCategory sidewalk = ReportCategory(
    key: 'sidewalk',
    label: 'Kaldırım',
    icon: Icons.directions_walk,
    color: Color(0xFFF44336),
  );

  static const ReportCategory elevator = ReportCategory(
    key: 'elevator',
    label: 'Asansör',
    icon: Icons.elevator,
    color: Color(0xFF9C27B0),
  );

  static const ReportCategory other = ReportCategory(
    key: 'other',
    label: 'Diğer',
    icon: Icons.warning_amber_rounded,
    color: Color(0xFF9E9E9E),
  );

  /// Formdaki çiplerin ve harita ikonlarının sırası.
  static const List<ReportCategory> values = <ReportCategory>[
    ramp,
    stairs,
    sidewalk,
    elevator,
    other,
  ];

  /// Bildirim başlığına göre kategoriyi döndürür.
  ///
  /// Eşleşme büyük/küçük harf duyarsızdır; bilinen bir kategori geçmiyorsa
  /// [other] kullanılır.
  static ReportCategory forTitle(String title) {
    final normalizedTitle = title.toLowerCase();

    for (final category in values) {
      if (category == other) continue;
      if (normalizedTitle.contains(category.label.toLowerCase())) {
        return category;
      }
    }

    return other;
  }
}
