// ============================================================
// app.dart
// Ana MaterialApp widget'i
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/profile/presentation/providers/settings_provider.dart';

class AccessibleMapApp extends ConsumerWidget {
  const AccessibleMapApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final highContrastTheme =
        settings.isHighContrast ? AppTheme.highContrastTheme : null;

    return MaterialApp.router(
      title: 'Erişilebilir Harita',
      debugShowCheckedModeBanner: false,
      theme: highContrastTheme ?? AppTheme.lightTheme,
      darkTheme: highContrastTheme ?? AppTheme.darkTheme,
      themeMode: settings.isHighContrast ? ThemeMode.dark : ThemeMode.system,
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);

        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(settings.textScale),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
