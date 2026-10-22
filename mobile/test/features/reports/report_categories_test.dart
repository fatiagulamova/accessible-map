import 'package:accessible_map/features/reports/presentation/report_categories.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReportCategory.forTitle', () {
    test('matches known categories case-insensitively', () {
      expect(ReportCategory.forTitle('Rampa'), ReportCategory.ramp);
      expect(ReportCategory.forTitle('rampa'), ReportCategory.ramp);
      expect(ReportCategory.forTitle('Merdivenler'), ReportCategory.stairs);
      expect(
        ReportCategory.forTitle('Kaldırım çukuru'),
        ReportCategory.sidewalk,
      );
      expect(
        ReportCategory.forTitle('ASANSÖR arızası'),
        ReportCategory.elevator,
      );
    });

    test('uses the default category for unknown titles', () {
      expect(ReportCategory.forTitle('Bilinmeyen engel'), ReportCategory.other);
      expect(ReportCategory.forTitle(''), ReportCategory.other);
    });

    test('provides the marker image id expected by the map', () {
      expect(ReportCategory.ramp.markerIconId, 'report-marker-ramp');
      expect(ReportCategory.stairs.markerIconId, 'report-marker-stairs');
      expect(ReportCategory.sidewalk.markerIconId, 'report-marker-sidewalk');
      expect(ReportCategory.elevator.markerIconId, 'report-marker-elevator');
      expect(ReportCategory.other.markerIconId, 'report-marker-other');
    });
  });
}
