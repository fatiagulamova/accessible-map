// ============================================================
// app.dart
// Ana MaterialApp widget'i - auth yoklaması ile
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/config/app_router.dart';
import 'features/auth/presentation/providers/auth_provider.dart';

class AccessibleMapApp extends ConsumerStatefulWidget {
  const AccessibleMapApp({super.key});

  @override
  ConsumerState<AccessibleMapApp> createState() => _AccessibleMapAppState();
}

class _AccessibleMapAppState extends ConsumerState<AccessibleMapApp> {
  @override
  void initState() {
    super.initState();
    // Uygulama açıldığında mevcut kullanıcıyı yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).loadCurrentUser();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final authState = ref.watch(authControllerProvider);

    // İlk yüklemede splash ekranı göster
    if (authState is AuthLoading || authState is AuthInitial) {
      return MaterialApp(
        title: 'Accessible Map',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const _SplashScreen(),
      );
    }

    return MaterialApp.router(
      title: 'Accessible Map',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}

// ============================================================
// Splash Screen - auth yüklenirken gösterilir
// ============================================================
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.accessible,
              size: 100,
              color: Color(0xFF1565C0),
            ),
            SizedBox(height: 24),
            Text(
              'Accessible Map',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}