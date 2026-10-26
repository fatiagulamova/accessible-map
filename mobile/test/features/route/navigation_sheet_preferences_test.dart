import 'package:accessible_map/features/route/presentation/widgets/navigation_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows and toggles the accessibility preference chips', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: NavigationSheet(startLat: 41.6378, startLng: 32.3374),
          ),
        ),
      ),
    );

    expect(find.text('Erişilebilirlik Tercihleri'), findsOneWidget);
    expect(
      find.widgetWithText(FilterChip, 'Tekerlekli Sandalye'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(FilterChip, 'Asansör Kullanımı'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilterChip, 'Rampa Tercihi'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Yaya Önceliği'), findsOneWidget);

    final wheelchairChip = find.widgetWithText(
      FilterChip,
      'Tekerlekli Sandalye',
    );

    expect(tester.widget<FilterChip>(wheelchairChip).selected, isFalse);

    await tester.ensureVisible(wheelchairChip);
    await tester.tap(wheelchairChip);
    await tester.pump();

    expect(tester.widget<FilterChip>(wheelchairChip).selected, isTrue);
  });
}
