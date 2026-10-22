// ============================================================
// main_navigation_shell.dart
// Alt gezinme çubuğu ve sekme bazlı navigasyon iskeleti
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Uygulamanın ana sekmelerini barındıran alt gezinme kabuğu.
///
/// Her sekme kendi navigasyon geçmişini korur. Aynı sekmeye tekrar
/// dokunulduğunda o sekmenin başlangıç sayfasına dönülür.
class MainNavigationShell extends StatelessWidget {
  const MainNavigationShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map), label: 'Harita'),
          NavigationDestination(
            icon: Icon(Icons.list_alt),
            label: 'Bildirimler',
          ),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}
