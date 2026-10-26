// ============================================================
// report_detail_sheet.dart
// Haritadaki bir engel bildiriminin detaylarını gösteren modal sheet
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../domain/entities/report_entity.dart';
import '../providers/report_provider.dart';

const Color _brandColor = AppColors.primaryBlue;

class ReportDetailSheet extends ConsumerStatefulWidget {
  final ReportEntity report;

  const ReportDetailSheet({super.key, required this.report});

  @override
  ConsumerState<ReportDetailSheet> createState() => _ReportDetailSheetState();
}

class _ReportDetailSheetState extends ConsumerState<ReportDetailSheet> {
  bool? _pendingVote;
  String? _validationError;

  bool get _isSubmitting => _pendingVote != null;

  Future<void> _submitValidation(bool isValid) async {
    if (_isSubmitting) return;

    final report = widget.report;
    final controller = ref.read(reportControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final route = ModalRoute.of(context);

    setState(() {
      _pendingVote = isValid;
      _validationError = null;
    });

    final success = await controller.validateReport(report.id, isValid);

    if (!mounted) return;

    if (success) {
      if (route == null || route.isCurrent) {
        navigator.pop();
      }

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Oyunuz kaydedildi. Teşekkürler!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

      unawaited(
        controller.loadNearbyReports(report.latitude, report.longitude),
      );
      return;
    }

    final message = controller.lastValidationError ?? 'Oy kaydedilemedi.';
    setState(() {
      _pendingVote = null;
      _validationError = message;
    });

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final photoUrl = report.photoUrl?.trim() ?? '';
    final description = report.description?.trim() ?? '';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _brandColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.report_problem_outlined,
                    color: _brandColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      StatusBadge(status: report.status),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Kapat',
                  icon: const Icon(Icons.close, color: _brandColor),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description.isEmpty ? 'Açıklama eklenmemiş.' : description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color:
                    description.isEmpty
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : null,
                fontStyle: description.isEmpty ? FontStyle.italic : null,
              ),
            ),
            if (photoUrl.isNotEmpty) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  photoUrl,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  semanticLabel: '${report.title} fotoğrafı',
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;

                    final totalBytes = loadingProgress.expectedTotalBytes;
                    final progress =
                        totalBytes != null && totalBytes > 0
                            ? loadingProgress.cumulativeBytesLoaded / totalBytes
                            : null;

                    return Container(
                      height: 200,
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: CircularProgressIndicator(value: progress),
                    );
                  },
                  errorBuilder:
                      (context, error, stackTrace) => Container(
                        height: 200,
                        color:
                            Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.broken_image_outlined,
                              size: 36,
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 8),
                            const Text('Fotoğraf yüklenemedi'),
                          ],
                        ),
                      ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.place_outlined,
              text:
                  '${report.latitude.toStringAsFixed(5)}, '
                  '${report.longitude.toStringAsFixed(5)}',
            ),
            if (_validationError != null) ...[
              const SizedBox(height: 16),
              _ValidationErrorBanner(message: _validationError!),
            ],
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isSubmitting ? null : () => _submitValidation(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandColor,
                foregroundColor: Colors.white,
              ),
              icon:
                  _pendingVote == true
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.verified_outlined),
              label: Text(_pendingVote == true ? 'Kaydediliyor...' : 'Doğrula'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isSubmitting ? null : () => _submitValidation(false),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade300),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              icon:
                  _pendingVote == false
                      ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.red.shade700,
                        ),
                      )
                      : const Icon(Icons.thumb_down_alt_outlined),
              label: Text(
                _pendingVote == false ? 'Kaydediliyor...' : 'Yalan / Reddet',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValidationErrorBanner extends StatelessWidget {
  final String message;

  const _ValidationErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 20, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.red.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportStatusChip extends StatelessWidget {
  final ReportStatus status;

  const _ReportStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ReportStatus.pending => ('Onay Bekliyor', Colors.orange),
      ReportStatus.validated => ('Doğrulandı', Colors.green),
      ReportStatus.rejected => ('Reddedildi', Colors.red),
      ReportStatus.resolved => ('Çözüldü', Colors.blue),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color.shade800,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
