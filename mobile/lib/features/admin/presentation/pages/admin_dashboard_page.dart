// ============================================================
// admin_dashboard_page.dart
// Yöneticilerin tüm bildirimleri görüntüleyip silebildiği panel
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../reports/domain/entities/report_entity.dart';
import '../providers/admin_provider.dart';

const Color _brandColor = Color(0xFF1565C0);

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(adminControllerProvider.notifier).fetchAllReports();
    });
  }

  Future<void> _refresh() {
    return ref.read(adminControllerProvider.notifier).fetchAllReports();
  }

  Future<void> _confirmDelete(ReportEntity report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Bildirimi Sil'),
            content: Text(
              '"${report.title}" başlıklı bildirimi kalıcı olarak '
              'silmek istiyor musunuz?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Vazgeç'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Sil'),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) return;

    final controller = ref.read(adminControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    final success = await controller.deleteReport(report.id);
    if (!mounted) return;

    if (success) {
      await controller.fetchAllReports();
      if (!mounted) return;
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Bildirim silindi.'
                : controller.lastDeleteError ?? 'Bildirim silinemedi.',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Paneli'),
        backgroundColor: _brandColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _refresh,
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.go('/map'),
                style: FilledButton.styleFrom(
                  backgroundColor: _brandColor,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.local_fire_department),
                label: const Text('Show Heatmap on Map'),
              ),
            ),
          ),
          Expanded(
            child: switch (state) {
              AdminInitial() || AdminLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
              AdminError(:final message) => _AdminErrorView(
                message: message,
                onRetry: _refresh,
              ),
              AdminLoaded(:final reports) =>
                reports.isEmpty
                    ? const _AdminEmptyView()
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: reports.length,
                      itemBuilder: (context, index) {
                        final report = reports[index];
                        return _AdminReportCard(
                          report: report,
                          onDelete: () => _confirmDelete(report),
                        );
                      },
                    ),
            },
          ),
        ],
      ),
    );
  }
}

class _AdminReportCard extends StatelessWidget {
  final ReportEntity report;
  final VoidCallback onDelete;

  const _AdminReportCard({required this.report, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurfaceVariant;
    final coordinates =
        '${report.latitude.toStringAsFixed(5)}, '
        '${report.longitude.toStringAsFixed(5)}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _AdminStatusChip(status: report.status),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 16,
                            color: mutedColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            coordinates,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: mutedColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onDelete,
              tooltip: 'Sil',
              icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminStatusChip extends StatelessWidget {
  final ReportStatus status;

  const _AdminStatusChip({required this.status});

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

class _AdminEmptyView extends StatelessWidget {
  const _AdminEmptyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Henüz bildirim bulunmuyor.',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Yeni bildirimler geldiğinde burada görünecek.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _AdminErrorView({required this.message, required this.onRetry});

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
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
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
