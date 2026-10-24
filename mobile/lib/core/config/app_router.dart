// ============================================================
// app_router.dart
// GoRouter ile auth-aware uygulama yönlendirmesi
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/map/presentation/pages/map_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/settings_page.dart';
import '../../features/reports/presentation/pages/reports_list_page.dart';
import '../../shared/widgets/main_navigation_shell.dart';

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
      final authState =
          refreshNotifier.value; // Read from notifier for accuracy

      // İlk yükleme sırasında splash ekranında kal
      if (authState is AuthInitial || authState is AuthLoading) {
        return state.matchedLocation == '/splash' ? null : '/splash';
      }

      final isAuthenticated = authState is AuthAuthenticated;
      final user = authState is AuthAuthenticated ? authState.user : null;
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      final isAdminRoute = state.matchedLocation == '/admin';

      // Kullanıcı giriş yapmamış ve korumalı sayfada ise → login'e yönlendir
      if (!isAuthenticated && !isAuthRoute) {
        return '/login';
      }

      // Kullanıcı giriş yapmış ve auth/splash sayfasında ise → map'e yönlendir
      if (isAuthenticated &&
          (isAuthRoute || state.matchedLocation == '/splash')) {
        return '/map';
      }

      // Admin sayfasına yalnızca yönetici rolündeki kullanıcılar erişebilir
      if (isAdminRoute && user?.isAdmin != true) {
        return '/map';
      }

      // Aksi halde normal akış
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder:
            (context, state) => const Scaffold(
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
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainNavigationShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/map',
                name: 'map',
                builder: (context, state) => const MapPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reports',
                name: 'reports',
                builder: (context, state) => const ReportsListPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                name: 'profile',
                builder: (context, state) => const ProfilePage(),
                routes: [
                  GoRoute(
                    path: 'settings',
                    name: 'profile-settings',
                    builder: (context, state) => const SettingsPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/admin',
        name: 'admin',
        builder: (context, state) => const AdminDashboardPage(),
      ),
    ],
  );
});
