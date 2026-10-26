// ============================================================
// settings_page.dart
// Erişilebilirlik ayarları ekranı
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';

const double _normalTextScale = 1.0;
const double _largeTextScale = 1.25;
const double _textScaleEpsilon = 0.01;

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const Color _navyText = Color(0xFF1A2B4C);
  static const Color _pageBackground = Color(0xFFF5F7FA);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsController = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);
    final isLargeText =
        settings.textScale >= _largeTextScale - _textScaleEpsilon;

    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        title: const Text('Erişilebilirlik Ayarları'),
        backgroundColor: Colors.white,
        foregroundColor: _navyText,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          color: _navyText,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: _navyText),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            const _SectionTitle('Görsel Ayarlar'),
            const SizedBox(height: 10),
            _SettingsCard(
              child: Column(
                children: [
                  _SettingsSwitchTile(
                    icon: Icons.text_fields_rounded,
                    title: 'Büyük Yazı',
                    subtitle: 'Metinleri daha büyük ve okunur gösterir.',
                    value: isLargeText,
                    onChanged: (value) {
                      settingsController.setTextScale(
                        value ? _largeTextScale : _normalTextScale,
                      );
                    },
                  ),
                  const _SettingsDivider(),
                  _SettingsSwitchTile(
                    icon: Icons.contrast_rounded,
                    title: 'Yüksek Kontrast',
                    subtitle:
                        'Arka planı koyulaştırarak okunabilirliği artırır.',
                    value: settings.isHighContrast,
                    onChanged: settingsController.setHighContrast,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _SectionTitle('Sesli Yönlendirme'),
            const SizedBox(height: 10),
            _SettingsCard(
              child: _SettingsSwitchTile(
                icon: Icons.volume_up_rounded,
                title: 'Sesli Yönlendirme',
                subtitle:
                    'Sesli yönlendirme özelliği yakında kullanıma sunulacaktır.',
                value: settings.isVoiceGuidanceEnabled,
                onChanged: settingsController.setVoiceGuidanceEnabled,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Bu ayarlar cihazınızda saklanır ve uygulamanın tamamına '
              'uygulanır.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF8A94A6),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mockup'taki gibi bölüm başlığı.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF1A2B4C),
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.1,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;

  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 1.5,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: Color(0xFFE8ECF1),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  static const Color _brandColor = Color(0xFF1565C0);
  static const Color _switchActiveColor = Color(0xFF43A047);
  static const Color _navyText = Color(0xFF1A2B4C);

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      secondary: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _brandColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: _brandColor),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: _navyText,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: Color(0xFF8A94A6),
          fontSize: 12.5,
          height: 1.35,
        ),
      ),
      activeThumbColor: Colors.white,
      activeTrackColor: _switchActiveColor,
      inactiveThumbColor: Colors.white,
      inactiveTrackColor: const Color(0xFFD0D5DD),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      value: value,
      onChanged: onChanged,
    );
  }
}
