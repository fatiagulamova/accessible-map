// ============================================================
// map_page.dart
// Ana harita ekranı (auth-aware + logout)
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/domain/entities/user_entity.dart';

class MapPage extends ConsumerWidget {
  const MapPage({super.key});

  // Bartın merkez koordinatları
  static const LatLng _bartinCenter = LatLng(41.6378, 32.3374);

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    // Onay diyaloğu
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Hesabınızdan çıkmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Erişilebilirlik Haritası'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          // Kullanıcı avatarı
          if (user != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: PopupMenuButton<String>(
                offset: const Offset(0, 50),
                icon: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(
                    user.initials,
                    style: const TextStyle(
                      color: Color(0xFF1565C0),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                onSelected: (value) {
                  if (value == 'logout') {
                    _handleLogout(context, ref);
                  } else if (value == 'profile') {
                    // TODO: Profil sayfası
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profil sayfası yakında')),
                    );
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: user.isAdmin
                                ? Colors.red[100]
                                : user.isVolunteer
                                    ? Colors.orange[100]
                                    : Colors.blue[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            user.role.displayName,
                            style: TextStyle(
                              fontSize: 11,
                              color: user.isAdmin
                                  ? Colors.red[900]
                                  : user.isVolunteer
                                      ? Colors.orange[900]
                                      : Colors.blue[900],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person_outline),
                        SizedBox(width: 12),
                        Text('Profilim'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: Colors.red),
                        SizedBox(width: 12),
                        Text('Çıkış Yap', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: FlutterMap(
        options: const MapOptions(
          initialCenter: _bartinCenter,
          initialZoom: 14.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.bartin.accessible_map',
          ),
          const MarkerLayer(
            markers: [
              Marker(
                point: _bartinCenter,
                width: 50,
                height: 50,
                child: Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Engel bildirme
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Engel bildirme yakında')),
          );
        },
        backgroundColor: const Color(0xFF26A69A),
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Engel Bildir'),
      ),
    );
  }
}