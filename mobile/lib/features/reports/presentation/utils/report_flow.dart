// ============================================================
// report_flow.dart
// Engel bildirimi akışı için paylaşılan konum/sheet yardımcıları
// ============================================================

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../widgets/create_report_sheet.dart';

/// GPS alınamadığında kullanılan Bartın merkez koordinatları.
const ({double latitude, double longitude}) fallbackReportLocation = (
  latitude: 41.6378,
  longitude: 32.3374,
);

/// GPS üzerinden bildirim konumunu çözer; alınamazsa null döner.
Future<({double latitude, double longitude})?> resolveReportLocation() async {
  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 8),
    );

    // Bildirimde GPS'ten gelen koordinatları yuvarlamadan kullan.
    return (latitude: position.latitude, longitude: position.longitude);
  } catch (error) {
    debugPrint('Bildirim konumu alınamadı: $error');
    return null;
  }
}

/// Konumu çözer ve engel bildirim sayfasını açar.
///
/// GPS alınamazsa [fallbackReportLocation] kullanılır ve kullanıcıya
/// bilgilendirme gösterilir.
Future<void> openCreateReportSheet(BuildContext context) async {
  final location = await resolveReportLocation();

  if (!context.mounted) return;

  if (location == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('GPS konumu alınamadı, harita merkezi kullanılıyor.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  final reportLocation = location ?? fallbackReportLocation;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    clipBehavior: Clip.antiAlias,
    builder:
        (_) => CreateReportSheet(
          latitude: reportLocation.latitude,
          longitude: reportLocation.longitude,
          isUsingFallbackLocation: location == null,
        ),
  );
}
