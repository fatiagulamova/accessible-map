// ============================================================
// main_navigation_shell.dart
// Eğrisel alt gezinme çubuğu ve sekme bazlı navigasyon iskeleti
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/reports/presentation/utils/report_flow.dart';

/// Marka mavisi — mockup'taki merkez "+" ve aktif sekme rengi.
const Color _brandBlue = Color(0xFF1565C0);

/// Eğrisel navigasyon çubuğunun merkez buton indeksi.
const _centerActionIndex = 2;

/// Uygulamanın ana sekmelerini barındıran alt gezinme kabuğu.
///
/// Her sekme kendi navigasyon geçmişini korur. Aynı sekmeye tekrar
/// dokunulduğunda o sekmenin başlangıç sayfasına dönülür.
class MainNavigationShell extends StatelessWidget {
  const MainNavigationShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  int get _barIndex {
    final branch = navigationShell.currentIndex;
    // FAB için ayrı rota dalı yok; merkez indeks ile rota indeksleri
    // arasında bir adım kayma vardır.
    return branch < _centerActionIndex ? branch : branch + 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: _MockupCurvedNavBar(
        currentIndex: _barIndex,
        onTap: (index) async {
          if (index == _centerActionIndex) {
            await openCreateReportSheet(context);
            return;
          }

          final branchIndex =
              index < _centerActionIndex ? index : index - 1;

          navigationShell.goBranch(
            branchIndex,
            initialLocation: branchIndex == navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}

/// Mockup'a uygun sabit merkez "+" düğmeli eğrisel alt çubuk.
class _MockupCurvedNavBar extends StatelessWidget {
  const _MockupCurvedNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const double _barHeight = 64;
  static const double _fabSize = 58;
  static const double _fabOverlap = 26;
  static const double _notchRadius = 34;
  static const double _cornerRadius = 22;

  static const _items = <({IconData icon, IconData activeIcon, String label})>[
    (
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Anasayfa',
    ),
    (
      icon: Icons.map_outlined,
      activeIcon: Icons.map_rounded,
      label: 'Harita',
    ),
    (
      icon: Icons.add,
      activeIcon: Icons.add,
      label: '',
    ),
    (
      icon: Icons.notifications_outlined,
      activeIcon: Icons.notifications_rounded,
      label: 'Bildirimler',
    ),
    (
      icon: Icons.person_outline,
      activeIcon: Icons.person_rounded,
      label: 'Profil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SizedBox(
      height: _barHeight + _fabOverlap + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CustomPaint(
              painter: const _NavBarPainter(
                color: Colors.white,
                notchRadius: _notchRadius,
                cornerRadius: _cornerRadius,
                barHeight: _barHeight,
              ),
              child: SizedBox(
                height: _barHeight + bottomInset,
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: Row(
                    children: [
                      for (var i = 0; i < _items.length; i++)
                        Expanded(
                          child:
                              i == _centerActionIndex
                                  ? const SizedBox.shrink()
                                  : _NavItem(
                                    icon: _items[i].icon,
                                    activeIcon: _items[i].activeIcon,
                                    label: _items[i].label,
                                    selected: currentIndex == i,
                                    onTap: () => onTap(i),
                                  ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: _barHeight + bottomInset - (_fabSize - _fabOverlap),
            child: _CenterFab(size: _fabSize, onTap: () => onTap(_centerActionIndex)),
          ),
        ],
      ),
    );
  }
}

class _CenterFab extends StatelessWidget {
  const _CenterFab({required this.size, required this.onTap});

  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _brandBlue,
            boxShadow: [
              BoxShadow(
                color: _brandBlue.withValues(alpha: 0.38),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? _brandBlue : const Color(0xFF8A94A6);

    return InkWell(
      onTap: onTap,
      splashColor: _brandBlue.withValues(alpha: 0.08),
      highlightColor: _brandBlue.withValues(alpha: 0.04),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(selected ? activeIcon : icon, color: color, size: 24),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Üst kenarı yuvarlatılmış, ortasında FAB için çentik bulunan beyaz çubuk.
class _NavBarPainter extends CustomPainter {
  const _NavBarPainter({
    required this.color,
    required this.notchRadius,
    required this.cornerRadius,
    required this.barHeight,
  });

  final Color color;
  final double notchRadius;
  final double cornerRadius;
  final double barHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    const shoulder = 10.0;

    final path =
        Path()
          ..moveTo(0, cornerRadius)
          ..quadraticBezierTo(0, 0, cornerRadius, 0)
          ..lineTo(cx - notchRadius - shoulder, 0)
          ..cubicTo(
            cx - notchRadius + 4,
            0,
            cx - notchRadius + 2,
            notchRadius,
            cx,
            notchRadius,
          )
          ..cubicTo(
            cx + notchRadius - 2,
            notchRadius,
            cx + notchRadius - 4,
            0,
            cx + notchRadius + shoulder,
            0,
          )
          ..lineTo(w - cornerRadius, 0)
          ..quadraticBezierTo(w, 0, w, cornerRadius)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close();

    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.22), 12, true);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _NavBarPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.notchRadius != notchRadius ||
      oldDelegate.cornerRadius != cornerRadius ||
      oldDelegate.barHeight != barHeight;
}
