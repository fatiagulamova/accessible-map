// ============================================================
// status_badge.dart
// Bildirim durumu için tutarlı etiket
// ============================================================

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../features/reports/domain/entities/report_entity.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      ReportStatus.pending => (
        'Onay bekliyor',
        AppColors.warning,
        Icons.hourglass_top_rounded,
      ),
      ReportStatus.validated => (
        'Doğrulandı',
        AppColors.success,
        Icons.verified_rounded,
      ),
      ReportStatus.rejected => (
        'Reddedildi',
        AppColors.error,
        Icons.cancel_rounded,
      ),
      ReportStatus.resolved => (
        'Çözüldü',
        AppColors.primaryBlue,
        Icons.check_circle_rounded,
      ),
    };

    return Semantics(
      label: 'Bildirim durumu: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
