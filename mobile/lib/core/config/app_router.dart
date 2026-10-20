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
  final refreshNotifier = ValueNotifier<AuthState>(
    ref.read(authControllerProvider),
  );

  // Uygulama açıldığında mevcut kullanıcıyı yükle
  Future.microtask(
    () => ref.read(authControllerProvider.notifier).loadCurrentUser(),
  );

  ref.listen<AuthState>(authControllerProvider, (previous, next) {
    refreshNotifier.value = next;
  });

  ref.onDispose(() => refreshNotifier.dispose());

  return GoRouter(
    initialLocation: '/splash',
    // Auth state değiştiğinde otomatik yönlendirme
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = refreshNotifier.value; // Read from notifier for accuracy

      // İlk yükleme sırasında splash ekranında kal
      if (authState is AuthInitial || authState is AuthLoading) {
        return state.matchedLocation == '/splash' ? null : '/splash';
      }

      final isAuthenticated = authState is AuthAuthenticated;
      final isAuthRoute =
          state.matchedLocation == '/login' || state.matchedLocation == '/register';

      // Kullanıcı giriş yapmamış ve korumalı sayfada ise → login'e yönlendir
      if (!isAuthenticated && !isAuthRoute) {
        return '/login';
      }

      // Kullanıcı giriş yapmış ve auth/splash sayfasında ise → map'e yönlendir
      if (isAuthenticated &&
          (isAuthRoute || state.matchedLocation == '/splash')) {
        return '/map';
      }

      // Aksi halde normal akış
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
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