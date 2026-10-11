// ============================================================
// main.dart
// Uygulamanın giriş noktası
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';

Future<void> main() async {
  // Flutter binding'leri başlat
  WidgetsFlutterBinding.ensureInitialized();

  // .env dosyasını yükle
  await dotenv.load(fileName: '.env');

  // Supabase'i başlat
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // Uygulamayı Riverpod ile başlat
  runApp(
    const ProviderScope(
      child: AccessibleMapApp(),
    ),
  );
}