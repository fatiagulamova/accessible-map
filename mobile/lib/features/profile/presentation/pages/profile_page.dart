// ============================================================
// profile_page.dart
// Profil sekmesi - kullanıcı bilgileri ve çıkış işlemleri
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  static const Color _brandColor = Color(0xFF1565C0);

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final authController = ref.read(authControllerProvider.notifier);

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Çıkış Yap'),
            content: const Text(
              'Hesabınızdan çıkış yapmak istediğinize emin misiniz?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Vazgeç'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text(
                  'Çıkış Yap',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (shouldLogout == true) {
      await authController.signOut();
    }
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Colors.red;
      case UserRole.volunteer:
        return Colors.orange;
      case UserRole.user:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: _brandColor,
        foregroundColor: Colors.white,
      ),
      body:
          user == null
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: _brandColor.withValues(alpha: 0.12),
                        child: Text(
                          user.initials,
                          style: const TextStyle(
                            color: _brandColor,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user.fullName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Chip(
                        avatar: Icon(
                          Icons.badge_outlined,
                          size: 18,
                          color: _roleColor(user.role),
                        ),
                        label: Text(user.role.displayName),
                        backgroundColor: _roleColor(
                          user.role,
                        ).withValues(alpha: 0.10),
                        side: BorderSide(
                          color: _roleColor(user.role).withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Hesap Bilgileri',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Column(
                          children: [
                            _InfoRow(
                              icon: Icons.person_outline,
                              label: 'Ad Soyad',
                              value: user.fullName,
                            ),
                            const Divider(height: 1),
                            _InfoRow(
                              icon: Icons.email_outlined,
                              label: 'E-posta',
                              value: user.email,
                            ),
                            const Divider(height: 1),
                            _InfoRow(
                              icon: Icons.admin_panel_settings_outlined,
                              label: 'Rol',
                              value: user.role.displayName,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _handleLogout(context, ref),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.logout),
                        label: const Text('Çıkış Yap'),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF1565C0)),
          const SizedBox(width: 12),
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
