import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:weather_app/models/weather.dart';
import 'package:weather_app/services/alerts_api.dart';
import 'package:weather_app/services/premium.dart';

/// A small real-shaped NWS active-alerts response (two features).
const _sampleAlertsJson = {
  'type': 'FeatureCollection',
  'features': [
    {
      'type': 'Feature',
      'properties': {
        'event': 'Flash Flood Watch',
        'severity': 'Moderate',
        'certainty': 'Possible',
        'urgency': 'Future',
        'headline': 'Flash Flood Watch issued November 14 at 10:00 AM MST',
        'description': 'Heavy rain may cause flash flooding.',
        'instruction': 'Avoid low-lying areas.',
        'areaDesc': 'Maricopa County',
        'effective': '2026-11-14T10:00:00-07:00',
        'expires': '2026-11-14T20:00:00-07:00',
      },
    },
    {
      'type': 'Feature',
      'properties': {
        'event': 'Excessive Heat Warning',
        'severity': 'Severe',
        'certainty': 'Likely',
        'urgency': 'Expected',
        'headline': 'Excessive Heat Warning issued November 14 at 9:00 AM MST',
        'description': 'Dangerously hot conditions.',
        'instruction': 'Drink plenty of fluids.',
        'areaDesc': 'Maricopa County',
        'effective': '2026-11-14T09:00:00-07:00',
        'expires': '2026-11-14T20:00:00-07:00',
      },
    },
  ],
};

WeatherData _sampleWeatherData() => WeatherData(
      city: const City(
        id: 'test',
        name: 'Mesa',
        country: 'United States',
        latitude: 33.42,
        longitude: -111.83,
      ),
      current: const CurrentWeather(
        temperature: 85,
        feelsLike: 86,
        humidity: 20,
        windSpeed: 5,
        pressure: 1012,
        precipitation: 0,
        weatherCode: 0,
        isDay: true,
      ),
      hourly: const [],
      daily: const [],
      fetchedAt: DateTime(2026, 11, 14),
    );

void main() {
  group('WeatherAlert — parsing', () {
    test('parses event, severity, headline, and times', () {
      final feature =
          (_sampleAlertsJson['features'] as List)[1] as Map<String, dynamic>;
      final alert = WeatherAlert.fromJson(feature);
      expect(alert.event, 'Excessive Heat Warning');
      expect(alert.severity, 'Severe');
      expect(alert.headline, contains('Excessive Heat Warning'));
      expect(alert.description, 'Dangerously hot conditions.');
      expect(alert.instruction, 'Drink plenty of fluids.');
      expect(alert.area, 'Maricopa County');
      // 8:00 PM at -07:00 is 3:00 AM UTC the next day, whatever the
      // test machine's own timezone is.
      expect(alert.expires?.toUtc(), DateTime.utc(2026, 11, 15, 3));
      expect(alert.isValid, true);
    });

    test('missing properties is not a valid alert', () {
      final alert = WeatherAlert.fromJson({});
      expect(alert.isValid, false);
    });

    test('severity ranks most severe first', () {
      const extreme =
          WeatherAlert(event: 'Tornado Warning', severity: 'Extreme', headline: '', description: '', instruction: '', area: '');
      const severe =
          WeatherAlert(event: 'Heat Warning', severity: 'Severe', headline: '', description: '', instruction: '', area: '');
      const moderate =
          WeatherAlert(event: 'Flood Watch', severity: 'Moderate', headline: '', description: '', instruction: '', area: '');
      const minor =
          WeatherAlert(event: 'Advisory', severity: 'Minor', headline: '', description: '', instruction: '', area: '');
      const unknown =
          WeatherAlert(event: 'Something', severity: 'Unknown', headline: '', description: '', instruction: '', area: '');
      final ranked = [minor, unknown, moderate, extreme, severe]
        ..sort((a, b) => a.severityRank.compareTo(b.severityRank));
      expect(
        ranked.map((a) => a.severity).toList(),
        ['Extreme', 'Severe', 'Moderate', 'Minor', 'Unknown'],
      );
    });
  });

  group('AlertsApi — fetching', () {
    test('returns alerts most severe first', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/alerts/active');
        expect(request.url.queryParameters['point'], '33.42,-111.83');
        return http.Response(jsonEncode(_sampleAlertsJson), 200);
      });
      final alerts = await AlertsApi(client: client)
          .fetchAlerts(latitude: 33.42, longitude: -111.83);
      expect(alerts.length, 2);
      expect(alerts.first.event, 'Excessive Heat Warning');
      expect(alerts.last.event, 'Flash Flood Watch');
    });

    test('empty features means no alerts, not an error', () async {
      final client = MockClient((request) async {
        return http.Response('{"type":"FeatureCollection","features":[]}', 200);
      });
      final alerts = await AlertsApi(client: client)
          .fetchAlerts(latitude: 33.42, longitude: -111.83);
      expect(alerts, isEmpty);
    });

    test('non-200, bad JSON, and network failure all mean no alerts', () async {
      final notFound = MockClient((request) async {
        return http.Response('Not found', 404);
      });
      expect(
        await AlertsApi(client: notFound)
            .fetchAlerts(latitude: 33.42, longitude: -111.83),
        isEmpty,
      );

      final badJson = MockClient((request) async {
        return http.Response('not json at all', 200);
      });
      expect(
        await AlertsApi(client: badJson)
            .fetchAlerts(latitude: 33.42, longitude: -111.83),
        isEmpty,
      );

      final throws = MockClient((request) async {
        throw Exception('no network');
      });
      expect(
        await AlertsApi(client: throws)
            .fetchAlerts(latitude: 33.42, longitude: -111.83),
        isEmpty,
      );
    });
  });

  group('Alerts — Premium gating and data', () {
    test('alerts are locked for free users', () {
      expect(PremiumRules.isAlertsLocked(isPremium: false), true);
      expect(PremiumRules.isAlertsLocked(isPremium: true), false);
    });

    test('WeatherData carries alerts via copyWith', () {
      final alert = WeatherAlert.fromJson(
          (_sampleAlertsJson['features'] as List)[1] as Map<String, dynamic>);
      final data = _sampleWeatherData();
      expect(data.alerts, isEmpty);
      final withAlerts = data.copyWith(alerts: [alert]);
      expect(withAlerts.alerts.length, 1);
      expect(withAlerts.alerts.first.event, 'Excessive Heat Warning');
      expect(withAlerts.city, data.city);
    });
  });
}
