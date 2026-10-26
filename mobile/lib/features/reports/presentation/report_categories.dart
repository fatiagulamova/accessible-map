// ============================================================
// report_categories.dart
// Bildirim kategorileri: form seçenekleri ve harita işaretleri
// ============================================================

import 'package:flutter/material.dart';

/// Bir bildirim kategorisinin form etiketini, ikonunu ve rengini taşır.
///
/// Aynı tanımlar hem bildirim formundaki kategori kartlarında hem de harita
/// üzerindeki bildirim işaretlerinde kullanılır.
@immutable
class ReportCategory {
  const ReportCategory({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
    this.formLabel,
    this.aliases = const <String>[],
  });

  /// Harita görsel kimliği için ASCII anahtar (ör. `ramp`).
  final String key;

  /// Kullanıcıya gösterilen kısa kategori adı.
  final String label;

  final IconData icon;
  final Color color;

  /// Mockup'a uygun uzun form etiketi; verilmezse [label] kullanılır.
  final String? formLabel;

  /// Başlığa göre kategori eşleşmesinde kontrol edilen alternatif metinler.
  final List<String> aliases;

  /// Formda gösterilen etiket.
  String get displayLabel => formLabel ?? label;

  String get markerIconId => 'report-marker-$key';

  static const ReportCategory ramp = ReportCategory(
    key: 'ramp',
    label: 'Rampa',
    formLabel: 'Rampa Eksikliği',
    icon: Icons.accessible_forward_rounded,
    color: Color(0xFF43A047),
  );

  static const ReportCategory stairs = ReportCategory(
    key: 'stairs',
    label: 'Merdiven',
    icon: Icons.stairs_rounded,
    color: Color(0xFFF57C00),
  );

  static const ReportCategory sidewalk = ReportCategory(
    key: 'sidewalk',
    label: 'Kaldırım',
    formLabel: 'Bozuk Kaldırım',
    icon: Icons.warning_rounded,
    color: Color(0xFFE53935),
  );

  static const ReportCategory elevator = ReportCategory(
    key: 'elevator',
    label: 'Asansör',
    formLabel: 'Erişilebilir Giriş',
    icon: Icons.door_front_door_rounded,
    color: Color(0xFF1565C0),
    aliases: <String>['erişilebilir giriş'],
  );

  static const ReportCategory other = ReportCategory(
    key: 'other',
    label: 'Diğer',
    icon: Icons.more_horiz_rounded,
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
      for (final alias in category.aliases) {
        if (normalizedTitle.contains(alias.toLowerCase())) {
          return category;
        }
      }
    }

    return other;
  }
}
