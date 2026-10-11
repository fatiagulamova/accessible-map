// ============================================================
// app_router.dart
// GoRouter ile auth-aware uygulama yönlendirmesi
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/map/presentation/pages/map_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    // Auth state değiştiğinde otomatik yönlendirme
    refreshListenable: _RouterRefreshNotifier(ref),
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final isAuthenticated = authState is AuthAuthenticated;
      final isAuthRoute =
          state.matchedLocation == '/login' || state.matchedLocation == '/register';

      // Kullanıcı giriş yapmamış ve korumalı sayfada ise → login'e yönlendir
      if (!isAuthenticated && !isAuthRoute) {
        return '/login';
      }

      // Kullanıcı giriş yapmış ve auth sayfasında ise → map'e yönlendir
      if (isAuthenticated && isAuthRoute) {
        return '/map';
      }

      // Aksi halde normal akış
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/map',
        name: 'map',
        builder: (context, state) => const MapPage(),
      ),
    ],
  );
});

// ============================================================
// Router yenileyici - auth state değişikliğinde router'ı yeniler
// ============================================================
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authControllerProvider, (previous, next) {
      notifyListeners();
    });
  }
}