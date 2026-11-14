import 'package:flutter_test/flutter_test.dart';

import 'package:weather_app/models/weather.dart';

/// Builds a fake Open-Meteo forecast payload with [days] daily entries
/// and 48 hourly entries, starting around now.
Map<String, dynamic> fakeForecastJson({int days = 10}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  String dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  final hourStart = DateTime(now.year, now.month, now.day, now.hour - 2);
  final hourlyTimes = <String>[];
  final hourlyTemps = <num>[];
  final hourlyCodes = <num>[];
  for (var i = 0; i < 48; i++) {
    final t = hourStart.add(Duration(hours: i));
    hourlyTimes.add(
      '${dateStr(t)}T${t.hour.toString().padLeft(2, '0')}:00',
    );
    hourlyTemps.add(60 + i % 10);
    hourlyCodes.add(0);
  }

  return {
    'current': {
      'temperature_2m': 72.0,
      'relative_humidity_2m': 40,
      'apparent_temperature': 73.0,
      'is_day': 1,
      'precipitation': 0.0,
      'weather_code': 0,
      'wind_speed_10m': 5.0,
      'pressure_msl': 1013.0,
    },
    'hourly': {
      'time': hourlyTimes,
      'temperature_2m': hourlyTemps,
      'weather_code': hourlyCodes,
    },
    'daily': {
      'time': List.generate(days, (i) => dateStr(today.add(Duration(days: i)))),
      'weather_code': List.generate(days, (i) => i % 3),
      'temperature_2m_max': List.generate(days, (i) => 80.0 - i),
      'temperature_2m_min': List.generate(days, (i) => 60.0 - i),
      'uv_index_max': List.generate(days, (i) => 5.0),
    },
  };
}

const _testCity = City(
  id: 'test',
  name: 'Testville',
  country: 'US',
  latitude: 33.41,
  longitude: -111.83,
);

void main() {
  group('WeatherData.fromJson — 10-day forecast', () {
    test('parses all 10 daily entries, starting today', () {
      final data = WeatherData.fromJson(_testCity, fakeForecastJson(days: 10));
      expect(data.daily.length, 10);

      final today = DateTime.now();
      final first = data.daily.first.date;
      expect(first.year, today.year);
      expect(first.month, today.month);
      expect(first.day, today.day);

      final last = data.daily.last.date;
      final day10 = today.add(const Duration(days: 9));
      expect(last.year, day10.year);
      expect(last.month, day10.month);
      expect(last.day, day10.day);
    });

    test('maps each day’s values in order', () {
      final data = WeatherData.fromJson(_testCity, fakeForecastJson(days: 10));
      expect(data.daily[0].tempMax, 80.0);
      expect(data.daily[0].tempMin, 60.0);
      expect(data.daily[0].weatherCode, 0);
      expect(data.daily[9].tempMax, 71.0);
      expect(data.daily[9].tempMin, 51.0);
      expect(data.daily[9].weatherCode, 0);
      expect(data.daily[4].uvIndexMax, 5.0);
    });

    test('daily list length follows the payload (fewer days still parses)', () {
      final data = WeatherData.fromJson(_testCity, fakeForecastJson(days: 7));
      expect(data.daily.length, 7);
    });

    test('hourly strip is still capped at 24 hours', () {
      final data = WeatherData.fromJson(_testCity, fakeForecastJson(days: 10));
      expect(data.hourly.length, 24);
    });
  });
}
