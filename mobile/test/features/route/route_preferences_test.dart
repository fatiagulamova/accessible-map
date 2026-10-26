import 'package:accessible_map/features/route/domain/entities/route_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RoutePreferences', () {
    test('defaults to false for every preference', () {
      const preferences = RoutePreferences();

      expect(preferences.toJson(), {
        'isWheelchair': false,
        'requireElevator': false,
        'preferRamp': false,
        'prioritizeDistance': false,
      });
    });

    test('serializes selected preferences for the Edge Function', () {
      const preferences = RoutePreferences(
        isWheelchair: true,
        requireElevator: true,
        preferRamp: true,
        prioritizeDistance: true,
      );

      expect(preferences.toJson(), {
        'isWheelchair': true,
        'requireElevator': true,
        'preferRamp': true,
        'prioritizeDistance': true,
      });
    });

    test('supports value equality', () {
      const first = RoutePreferences(
        isWheelchair: true,
        prioritizeDistance: true,
      );
      const second = RoutePreferences(
        isWheelchair: true,
        prioritizeDistance: true,
      );
      const different = RoutePreferences(isWheelchair: true);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(different));
    });
  });
}
