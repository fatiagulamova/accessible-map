// ============================================================
// reports_list_page.dart
// Bildirimler sekmesi - liste ekranı iskeleti
// ============================================================

import 'package:flutter/material.dart';

class ReportsListPage extends StatelessWidget {
  const ReportsListPage({super.key});

  static const Color _brandColor = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
        backgroundColor: _brandColor,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.list_alt_outlined,
                size: 72,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Henüz bildirim yok',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Bildirimler yakında burada listelenecek.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
