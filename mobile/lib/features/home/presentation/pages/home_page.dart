// ============================================================
// home_page.dart
// Anasayfa: arama çubuğu, harita önizlemesi ve hızlı işlemler
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../reports/presentation/report_categories.dart';
import '../../../reports/presentation/utils/report_flow.dart';

/// Mockup'a uygun ana sayfa: üstte arama çubuğu, harita önizlemesi ve
/// renkli hızlı işlem kartları.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const Color _brandColor = AppColors.primaryBlue;
  static const Color _navyText = AppColors.textPrimary;
  static const Color _pageBackground = AppColors.background;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: _pageBackground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _brandColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.accessible_rounded,
                    color: _brandColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Erişilebilir Harita',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: _brandColor,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Erişilebilirlik Ayarları',
                  onPressed: () => context.push('/profile/settings'),
                  style: IconButton.styleFrom(
                    foregroundColor: _brandColor,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.settings_outlined, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Nereye gitmek istiyorsunuz?',
              style: theme.textTheme.titleLarge?.copyWith(
                color: _navyText,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 14),
            _buildSearchBar(context),
            const SizedBox(height: 18),
            _buildMapPreview(context),
            const SizedBox(height: 12),
            _buildLocationCard(context),
            const SizedBox(height: 22),
            Text(
              'Hızlı İşlemler',
              style: theme.textTheme.titleMedium?.copyWith(
                color: _navyText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.map_rounded,
                    label: 'Harita',
                    subtitle: 'Engelleri görün',
                    onTap: () => context.go('/map'),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.route_rounded,
                    label: 'Rota Oluştur',
                    subtitle: 'Güvenli güzergâh',
                    onTap: () => context.go('/map'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.add_location_alt_outlined,
                    label: 'Bildirim Yap',
                    subtitle: 'Engel raporlayın',
                    onTap: () => unawaited(openCreateReportSheet(context)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.person_rounded,
                    label: 'Profilim',
                    subtitle: 'Hesap ve ayarlar',
                    onTap: () => context.go('/profile'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(28),
      child: TextField(
        readOnly: true,
        onTap: () => context.go('/map'),
        style: const TextStyle(
          color: _navyText,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: 'Bir yer arayın...',
          hintStyle: TextStyle(
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
          prefixIcon: const Icon(Icons.search_rounded, color: _brandColor),
          suffixIcon: const Icon(
            Icons.arrow_forward_rounded,
            color: AppColors.textSecondary,
            size: 22,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: _brandColor, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationCard(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/map'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _brandColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: _brandColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Konumunuz',
                      style: TextStyle(
                        color: Color(0xFF8A94A6),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Bartın',
                      style: TextStyle(
                        color: _navyText,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapPreview(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/map'),
        child: SizedBox(
          height: 200,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const CustomPaint(painter: _HomeMapPainter()),
              Positioned(
                left: 26,
                top: 28,
                child: _MapPin(
                  icon: ReportCategory.ramp.icon,
                  color: ReportCategory.ramp.color,
                ),
              ),
              Positioned(
                right: 46,
                top: 20,
                child: _MapPin(
                  icon: ReportCategory.stairs.icon,
                  color: ReportCategory.stairs.color,
                ),
              ),
              Positioned(
                left: 62,
                bottom: 34,
                child: _MapPin(
                  icon: ReportCategory.sidewalk.icon,
                  color: ReportCategory.sidewalk.color,
                ),
              ),
              Positioned(
                right: 24,
                bottom: 46,
                child: _MapPin(
                  icon: Icons.elevator,
                  color: ReportCategory.elevator.color,
                ),
              ),
              Align(
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _brandColor.withValues(alpha: 0.16),
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _brandColor,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Material(
                  color: Colors.white,
                  elevation: 2,
                  shadowColor: Colors.black26,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => context.go('/map'),
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.my_location_rounded,
                        color: _brandColor,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 108),
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primaryBlue, size: 24),
              ),
              const SizedBox(height: 14),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 16),
    );
  }
}

/// Harita önizlemesi için dekoratif sokak/park/ağ dokusu çizer.
///
/// Gerçek bir MapLibre örneği başlatmak yerine hafif bir dekorasyon
/// kullanılır; böylece ana sekme ile harita sekmesi aynı anda iki platform
/// görünümü oluşturmaz.
class _HomeMapPainter extends CustomPainter {
  const _HomeMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Zemin
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF1EFE9),
    );

    // Parklar
    final parkPaint = Paint()..color = const Color(0xFFCDE6C8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.04, h * 0.52, w * 0.30, h * 0.34),
        const Radius.circular(14),
      ),
      parkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.62, h * 0.06, w * 0.30, h * 0.26),
        const Radius.circular(14),
      ),
      parkPaint,
    );
    canvas.drawCircle(Offset(w * 0.72, h * 0.66), w * 0.07, parkPaint);

    // Nehir
    final waterPaint =
        Paint()
          ..color = const Color(0xFFB8D8F0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round;
    final river =
        Path()
          ..moveTo(w * 0.80, h * 0.28)
          ..quadraticBezierTo(w * 0.58, h * 0.48, w * 0.86, h * 0.72);
    canvas.drawPath(river, waterPaint);

    // Ana sokaklar
    final streetPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round;
    for (final x in [0.18, 0.44, 0.70]) {
      canvas.drawLine(
        Offset(w * x - 20, 0),
        Offset(w * x + 18, h),
        streetPaint,
      );
    }
    for (final y in [0.26, 0.58, 0.86]) {
      canvas.drawLine(Offset(0, h * y), Offset(w, h * y - 14), streetPaint);
    }

    // Yan sokaklar
    final lanePaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
    for (final x in [0.31, 0.57, 0.84]) {
      canvas.drawLine(Offset(w * x - 10, 0), Offset(w * x + 10, h), lanePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HomeMapPainter oldDelegate) => false;
}
