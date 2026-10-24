// ============================================================
// profile_stats_provider.dart
// Profil ekranındaki kullanıcı istatistiklerini getirir
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

/// Kullanıcının bildirim ve doğrulama istatistiklerini taşır.
class ProfileStats {
  final int totalReports;
  final int totalValidations;

  const ProfileStats({
    required this.totalReports,
    required this.totalValidations,
  });

  static const empty = ProfileStats(totalReports: 0, totalValidations: 0);
}

/// Giriş yapan kullanıcının bildirimlerini ve bu bildirimlere yapılan
/// olumlu doğrulamaları Supabase üzerinden sayar.
final profileStatsProvider = FutureProvider<ProfileStats>((ref) async {
  final authState = ref.watch(authControllerProvider);
  if (authState is! AuthAuthenticated) {
    return ProfileStats.empty;
  }

  final client = ref.watch(supabaseClientProvider);
  final reportRows = await client
      .from('reports')
      .select('id')
      .eq('user_id', authState.user.id);

  final reportIds = reportRows
      .map((row) => row['id'] as String)
      .toList(growable: false);

  if (reportIds.isEmpty) {
    return ProfileStats.empty;
  }

  final validationRows = await client
      .from('validations')
      .select('id')
      .inFilter('report_id', reportIds)
      .eq('is_valid', true);

  return ProfileStats(
    totalReports: reportIds.length,
    totalValidations: validationRows.length,
  );
});
