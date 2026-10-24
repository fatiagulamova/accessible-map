// ============================================================
// settings_page.dart
// Erişilebilirlik ayarları ekranı
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';

const double _normalTextScale = 1.0;
const double _largeTextScale = 1.25;
const double _extraLargeTextScale = 1.5;

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const Color _brandColor = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsController = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Erişilebilirlik Ayarları'),
        backgroundColor:
            settings.isHighContrast ? colorScheme.surface : _brandColor,
        foregroundColor:
            settings.isHighContrast ? colorScheme.onSurface : Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Text(
              'Görünüm',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            _SettingsCard(
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                secondary: Icon(Icons.contrast, color: colorScheme.primary),
                title: const Text(
                  'Yüksek Kontrast',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Arka planı siyah, metinleri beyaz yaparak okunabilirliği '
                  'artırır.',
                ),
                value: settings.isHighContrast,
                onChanged: (value) {
                  settingsController.setHighContrast(value);
                },
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Etkileşim',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            _SettingsCard(
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                secondary: Icon(Icons.volume_up, color: colorScheme.primary),
                title: const Text(
                  'Sesli Yönlendirme',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Sesli yönlendirme özelliği yakında kullanıma sunulacaktır.',
                ),
                value: settings.isVoiceGuidanceEnabled,
                onChanged: (value) {
                  settingsController.setVoiceGuidanceEnabled(value);
                },
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Büyük Yazı',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            _SettingsCard(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.text_fields, color: colorScheme.primary),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Yazı Boyutu',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          _textScaleLabel(settings.textScale),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Uygulama genelindeki metinlerin boyutunu ayarlayın.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value:
                          settings.textScale
                              .clamp(_normalTextScale, _extraLargeTextScale)
                              .toDouble(),
                      min: _normalTextScale,
                      max: _extraLargeTextScale,
                      divisions: 2,
                      label: _textScaleLabel(settings.textScale),
                      semanticFormatterCallback:
                          (value) => _textScaleLabel(value),
                      onChanged: (value) {
                        settingsController.setTextScale(value);
                      },
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Normal',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Büyük',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Çok Büyük',
                            textAlign: TextAlign.end,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Örnek Metin',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Erişilebilir bir şehir hepimizin hakkı.',
                            style: theme.textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Bu ayarlar cihazınızda saklanır ve uygulamanın tamamına '
              'uygulanır.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;

  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: child,
    );
  }
}

String _textScaleLabel(double textScale) {
  if (textScale >= _extraLargeTextScale) return 'Çok Büyük';
  if (textScale >= _largeTextScale) return 'Büyük';
  return 'Normal';
}
