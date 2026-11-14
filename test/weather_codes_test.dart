import 'package:flutter_test/flutter_test.dart';
import 'package:weather_app/models/weather.dart';
import 'package:weather_app/models/weather_codes.dart';

void main() {
  group('WMO weather codes', () {
    test('clear sky is sunny in the day, clear at night', () {
      expect(styleForCode(0, true).label, 'Clear');
      expect(styleForCode(0, true).art, WeatherArtKind.clearDay);
      expect(styleForCode(0, false).art, WeatherArtKind.clearNight);
    });

    test('rain codes map to rain art', () {
      for (final code in [61, 63, 65, 80, 81, 82]) {
        expect(styleForCode(code, true).art, WeatherArtKind.rain);
      }
    });

    test('snow codes map to snow art', () {
      for (final code in [71, 73, 75, 85, 86]) {
        expect(styleForCode(code, true).art, WeatherArtKind.snow);
      }
    });

    test('thunderstorm maps to thunder art', () {
      expect(styleForCode(95, true).art, WeatherArtKind.thunder);
    });

    test('unknown codes fall back to cloudy', () {
      expect(styleForCode(999, true).art, WeatherArtKind.cloudy);
    });
  });

  group('DateFormats', () {
    test('medium date', () {
      expect(
        DateFormats.mediumDate(DateTime(2026, 11, 14)),
        'Nov 14, 2026',
      );
    });

    test('hour labels', () {
      expect(DateFormats.hourLabel(DateTime(2026, 1, 1, 0)), '12:00 AM');
      expect(DateFormats.hourLabel(DateTime(2026, 1, 1, 15)), '3:00 PM');
    });

    test('day labels', () {
      final today = DateTime(2026, 11, 14); // a Saturday
      expect(DateFormats.dayLabel(today, today), 'Today');
      expect(
        DateFormats.dayLabel(DateTime(2026, 11, 15), today),
        'Sun',
      );
    });
  });
}
