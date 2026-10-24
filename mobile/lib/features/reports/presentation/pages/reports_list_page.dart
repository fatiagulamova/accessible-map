// ============================================================
// reports_list_page.dart
// Bildirimler sekmesi - kullanıcı bildirimlerinin akışı
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/report_entity.dart';
import '../providers/report_provider.dart';
import '../widgets/report_detail_sheet.dart';

class ReportsListPage extends ConsumerWidget {
  const ReportsListPage({super.key});

  static const Color _brandColor = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentReports = ref.watch(getRecentReportsProvider);
    final filter = ref.watch(reportFilterProvider);
    final hasActiveFilters = filter.isActive;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
        backgroundColor: _brandColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => _showReportFilters(context),
            tooltip: 'Filtrele',
            style:
                hasActiveFilters
                    ? IconButton.styleFrom(backgroundColor: Colors.white)
                    : null,
            icon: Icon(
              Icons.filter_list,
              color: hasActiveFilters ? _brandColor : Colors.white,
            ),
          ),
          IconButton(
            onPressed: () => ref.invalidate(getRecentReportsProvider),
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/map'),
        backgroundColor: _brandColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Haritadan Bildir'),
      ),
      body: recentReports.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => _ReportsErrorView(
              message: _errorMessage(error),
              onRetry: () => ref.invalidate(getRecentReportsProvider),
            ),
        data: (reports) {
          if (reports.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => _refresh(ref),
              child: const CustomScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyReportsView(),
                  ),
                ],
              ),
            );
          }

          final filteredReports = reports
              .where(filter.matches)
              .toList(growable: false);

          if (filteredReports.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => _refresh(ref),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _FilteredEmptyView(
                      onClearFilters: () => _clearFilters(ref),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => _refresh(ref),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
              itemCount: filteredReports.length,
              itemBuilder: (context, index) {
                final report = filteredReports[index];

                return _ReportFeedCard(
                  report: report,
                  onTap: () => _openReportDetail(context, ref, report),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _showReportFilters(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (_) => const _ReportFilterSheet(),
    );
  }

  void _clearFilters(WidgetRef ref) {
    ref.read(reportFilterProvider.notifier).state = const ReportFilter();
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(getRecentReportsProvider);

    try {
      await ref.read(getRecentReportsProvider.future);
    } catch (_) {
      // Hata durumu provider üzerinden hata görünümünde gösterilir.
    }
  }

  Future<void> _openReportDetail(
    BuildContext context,
    WidgetRef ref,
    ReportEntity report,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (_) => ReportDetailSheet(report: report),
    );

    if (!context.mounted) return;
    ref.invalidate(getRecentReportsProvider);
  }

  String _errorMessage(Object error) {
    if (error is Failure) return error.message;
    return 'Bildirimler yüklenemedi. Lütfen tekrar deneyin.';
  }
}

class _ReportFilterSheet extends ConsumerWidget {
  const _ReportFilterSheet();

  static const List<String> _categories = [
    'Rampa',
    'Merdiven',
    'Kaldırım',
    'Asansör',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(reportFilterProvider);
    final filterNotifier = ref.read(reportFilterProvider.notifier);
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bildirimleri Filtrele',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Durum',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Tümü'),
                  selected: filter.status == null,
                  onSelected: (_) {
                    filterNotifier.state = ReportFilter(
                      category: filter.category,
                    );
                  },
                ),
                ChoiceChip(
                  label: const Text('Bekliyor'),
                  selected: filter.status == ReportStatus.pending,
                  onSelected: (_) {
                    filterNotifier.state = ReportFilter(
                      status: ReportStatus.pending,
                      category: filter.category,
                    );
                  },
                ),
                ChoiceChip(
                  label: const Text('Onaylandı'),
                  selected: filter.status == ReportStatus.validated,
                  onSelected: (_) {
                    filterNotifier.state = ReportFilter(
                      status: ReportStatus.validated,
                      category: filter.category,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Kategori',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Tümü'),
                  selected: filter.category == null,
                  onSelected: (_) {
                    filterNotifier.state = ReportFilter(status: filter.status);
                  },
                ),
                for (final category in _categories)
                  ChoiceChip(
                    label: Text(category),
                    selected: filter.category == category,
                    onSelected: (_) {
                      filterNotifier.state = ReportFilter(
                        status: filter.status,
                        category: category,
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  filterNotifier.state = const ReportFilter();
                },
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Filtreleri Temizle'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportFeedCard extends StatelessWidget {
  final ReportEntity report;
  final VoidCallback onTap;

  const _ReportFeedCard({required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoUrl = report.photoUrl?.trim() ?? '';
    final description = report.description?.trim() ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ReportPhoto(photoUrl: photoUrl, title: report.title),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description.isEmpty ? 'Açıklama eklenmemiş.' : description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          description.isEmpty
                              ? theme.colorScheme.onSurfaceVariant
                              : null,
                      fontStyle: description.isEmpty ? FontStyle.italic : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _ReportStatusChip(status: report.status),
                      _ReportDateLabel(createdAt: report.createdAt),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportPhoto extends StatelessWidget {
  final String photoUrl;
  final String title;

  const _ReportPhoto({required this.photoUrl, required this.title});

  @override
  Widget build(BuildContext context) {
    if (photoUrl.isEmpty) {
      return const _PhotoPlaceholder(icon: Icons.image_outlined);
    }

    return Image.network(
      photoUrl,
      width: double.infinity,
      height: 190,
      fit: BoxFit.cover,
      semanticLabel: '$title fotoğrafı',
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;

        final totalBytes = loadingProgress.expectedTotalBytes;
        final progress =
            totalBytes != null && totalBytes > 0
                ? loadingProgress.cumulativeBytesLoaded / totalBytes
                : null;

        return Container(
          height: 190,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: CircularProgressIndicator(value: progress),
        );
      },
      errorBuilder:
          (context, error, stackTrace) =>
              const _PhotoPlaceholder(icon: Icons.broken_image_outlined),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  final IconData icon;

  const _PhotoPlaceholder({required this.icon});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 150,
      color: colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: 44,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
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

    return Semantics(
      label: 'Bildirim durumu: $label',
      child: Container(
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
      ),
    );
  }
}

class _ReportDateLabel extends StatelessWidget {
  final DateTime? createdAt;

  const _ReportDateLabel({required this.createdAt});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule_outlined, size: 15, color: color),
        const SizedBox(width: 4),
        Text(
          _formatReportDate(createdAt),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _EmptyReportsView extends StatelessWidget {
  const _EmptyReportsView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 96),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 72,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz bildirim yok',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Haritadan ilk bildirimi ekleyerek topluluğa yardımcı olun.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilteredEmptyView extends StatelessWidget {
  final VoidCallback onClearFilters;

  const _FilteredEmptyView({required this.onClearFilters});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 96),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_alt_off_outlined,
              size: 72,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 16),
            Text(
              'Bu filtrelerle eşleşen bildirim yok',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Filtreleri temizleyerek tüm bildirimleri görebilirsiniz.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onClearFilters,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Filtreleri Temizle'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportsErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ReportsErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: Colors.red.shade400),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatReportDate(DateTime? createdAt) {
  if (createdAt == null) return 'Tarih bilinmiyor';

  final localDate = createdAt.toLocal();
  final difference = DateTime.now().difference(localDate);

  if (difference.isNegative) return _formatAbsoluteDate(localDate);
  if (difference.inMinutes < 1) return 'Az önce';
  if (difference.inHours < 1) return '${difference.inMinutes} dakika önce';
  if (difference.inDays < 1) return '${difference.inHours} saat önce';
  if (difference.inDays < 7) return '${difference.inDays} gün önce';

  return _formatAbsoluteDate(localDate);
}

String _formatAbsoluteDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');

  return '$day.$month.${date.year}';
}
