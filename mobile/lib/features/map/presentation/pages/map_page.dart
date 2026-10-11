// ============================================================
// map_page.dart
// Ana harita ekranı (OpenStreetMap)
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  // Bartın merkez koordinatları
  static const LatLng _bartinCenter = LatLng(41.6378, 32.3374);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Erişilebilirlik Haritası'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
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
        },
        backgroundColor: const Color(0xFF26A69A),
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Engel Bildir'),
      ),
    );
  }
}