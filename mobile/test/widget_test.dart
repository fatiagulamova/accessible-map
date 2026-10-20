// This is a basic Flutter widget test.
//
// Verifies that the application root widget builds successfully.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:accessible_map/app.dart';
import 'package:accessible_map/features/auth/presentation/providers/auth_provider.dart';

void main() {
  testWidgets('AccessibleMapApp builds', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Provide a Supabase client without initializing the global instance.
          supabaseClientProvider.overrideWithValue(
            SupabaseClient(
              'https://example.supabase.co',
              'test-key',
              authOptions: const AuthClientOptions(autoRefreshToken: false),
            ),
          ),
        ],
        child: const AccessibleMapApp(),
      ),
    );

    expect(find.byType(AccessibleMapApp), findsOneWidget);
  });
}
