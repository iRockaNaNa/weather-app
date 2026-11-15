import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:weather_app/models/weather.dart';
import 'package:weather_app/services/nws_api.dart';
import 'package:weather_app/services/weather_api.dart';

/// A small real-shaped NWS /points response for Mesa.
const _samplePointsJson = {
  'properties': {
    'forecast': 'https://api.weather.gov/gridpoints/PSR/168,55/forecast',
    'forecastHourly':
        'https://api.weather.gov/gridpoints/PSR/168,55/forecast/hourly',
    'timeZone': 'America/Phoenix',
  },
};

/// Hourly + daily periods built around "now" so the hourly filter
/// (from an hour ago onward) keeps them.
Map<String, dynamic> _sampleHourlyJson() {
  final now = DateTime.now();
  String iso(DateTime d) => d.toIso8601String();
  return {
    'properties': {
      'units': 'us',
      'periods': [
        {
          'number': 1,
          'startTime': iso(now),
          'endTime': iso(now.add(const Duration(hours: 1))),
          'isDaytime': false,
          'temperature': 68,
          'temperatureUnit': 'F',
          'relativeHumidity': {'value': 58},
          'windSpeed': '5 mph',
          'shortForecast': 'Partly Cloudy',
        },
        {
          'number': 2,
          'startTime': iso(now.add(const Duration(hours: 1))),
          'endTime': iso(now.add(const Duration(hours: 2))),
          'isDaytime': false,
          'temperature': 66,
          'temperatureUnit': 'F',
          'relativeHumidity': {'value': 63},
          'windSpeed': '0 mph',
          'shortForecast': 'Mostly Clear',
        },
        {
          'number': 3,
          'startTime': iso(now.add(const Duration(hours: 2))),
          'endTime': iso(now.add(const Duration(hours: 3))),
          'isDaytime': false,
          'temperature': 64,
          'temperatureUnit': 'F',
          'relativeHumidity': {'value': 70},
          'windSpeed': '5 to 10 mph',
          'shortForecast': 'Clear',
        },
      ],
    },
  };
}

Map<String, dynamic> _sampleDailyJson() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  String iso(DateTime d) => d.toIso8601String();
  return {
    'properties': {
      'periods': [
        {
          'number': 1,
          'name': 'Today',
          'startTime': iso(today.add(const Duration(hours: 6))),
          'isDaytime': true,
          'temperature': 85,
          'shortForecast': 'Sunny',
        },
        {
          'number': 2,
          'name': 'Tonight',
          'startTime': iso(today.add(const Duration(hours: 18))),
          'isDaytime': false,
          'temperature': 60,
          'shortForecast': 'Mostly Clear',
        },
        {
          'number': 3,
          'name': 'Tuesday',
          'startTime': iso(tomorrow.add(const Duration(hours: 6))),
          'isDaytime': true,
          'temperature': 88,
          'shortForecast': 'Sunny',
        },
        {
          'number': 4,
          'name': 'Tuesday Night',
          'startTime': iso(tomorrow.add(const Duration(hours: 18))),
          'isDaytime': false,
          'temperature': 62,
          'shortForecast': 'Clear',
        },
      ],
    },
  };
}

const _mesa = City(
  id: 'test',
  name: 'Mesa',
  country: 'United States',
  latitude: 33.42,
  longitude: -111.83,
);

/// Routes requests: weather.gov answers from the samples above,
/// Open-Meteo fails when [openMeteoFails] is true.
MockClient _mockClient({required bool openMeteoFails}) {
  return MockClient((request) async {
    final url = request.url.toString();
    if (url.contains('api.weather.gov/points/')) {
      return http.Response(jsonEncode(_samplePointsJson), 200);
    }
    if (url.contains('/forecast/hourly')) {
      return http.Response(jsonEncode(_sampleHourlyJson()), 200);
    }
    if (url.contains('/forecast')) {
      return http.Response(jsonEncode(_sampleDailyJson()), 200);
    }
    if (url.contains('api.open-meteo.com')) {
      if (openMeteoFails) return http.Response('error', 500);
      return http.Response('{"current":{}}', 200);
    }
    return http.Response('not found', 404);
  });
}

void main() {
  group('NWS short forecast → WMO code', () {
    test('maps the common phrases', () {
      expect(nwsForecastToWmoCode('Sunny'), 0);
      expect(nwsForecastToWmoCode('Clear'), 0);
      expect(nwsForecastToWmoCode('Mostly Clear'), 1);
      expect(nwsForecastToWmoCode('Mostly Sunny'), 1);
      expect(nwsForecastToWmoCode('Partly Cloudy'), 2);
      expect(nwsForecastToWmoCode('Partly Sunny'), 2);
      expect(nwsForecastToWmoCode('Cloudy'), 3);
      expect(nwsForecastToWmoCode('Overcast'), 3);
      expect(nwsForecastToWmoCode('Patchy Fog'), 45);
      expect(nwsForecastToWmoCode('Drizzle'), 51);
      expect(nwsForecastToWmoCode('Light Rain'), 61);
      expect(nwsForecastToWmoCode('Showers'), 61);
      expect(nwsForecastToWmoCode('Freezing Rain'), 67);
      expect(nwsForecastToWmoCode('Light Snow'), 71);
      expect(nwsForecastToWmoCode('Snow Showers'), 71);
      expect(
        nwsForecastToWmoCode('Chance Showers And Thunderstorms'),
        95,
      );
      expect(nwsForecastToWmoCode(''), 3);
    });
  });

  group('NwsApi — fetching', () {
    test('builds current, hourly, and daily from NWS responses', () async {
      final client = _mockClient(openMeteoFails: false);
      final data =
          await NwsApi(client: client).fetchWeather(_mesa);
      expect(data.city, _mesa);
      expect(data.current.temperature, 68);
      expect(data.current.weatherCode, 2);
      expect(data.current.humidity, 58);
      expect(data.current.windSpeed, 5);
      expect(data.current.isDay, false);
      expect(data.hourly.length, 3);
      expect(data.hourly[1].temperature, 66);
      expect(data.hourly[2].weatherCode, 0);
      expect(data.daily.length, 2);
      expect(data.daily[0].tempMax, 85);
      expect(data.daily[0].tempMin, 60);
      expect(data.daily[0].weatherCode, 0);
      expect(data.daily[1].tempMax, 88);
      expect(data.daily[1].tempMin, 62);
    });

    test('non-US point throws (NWS has no forecast there)', () async {
      final client = MockClient((request) async {
        return http.Response('not found', 404);
      });
      expect(
        () => NwsApi(client: client).fetchWeather(_mesa),
        throwsA(isA<NwsException>()),
      );
    });

    test('bad forecast JSON throws instead of returning half a forecast',
        () async {
      final client = MockClient((request) async {
        if (request.url.toString().contains('/points/')) {
          return http.Response(jsonEncode(_samplePointsJson), 200);
        }
        return http.Response('nope', 200);
      });
      expect(
        () => NwsApi(client: client).fetchWeather(_mesa),
        throwsA(isA<NwsException>()),
      );
    });
  });

  group('WeatherApi — Open-Meteo with NWS fallback', () {
    test('falls back to NWS when Open-Meteo fails', () async {
      final client = _mockClient(openMeteoFails: true);
      final api = WeatherApi(
        client: client,
        nwsApi: NwsApi(client: client),
      );
      final data = await api.fetchWeather(_mesa);
      expect(data.current.temperature, 68);
      expect(data.daily.length, 2);
    });

    test('throws the Open-Meteo error when the fallback fails too',
        () async {
      final client = MockClient((request) async {
        return http.Response('error', 500);
      });
      final api = WeatherApi(
        client: client,
        nwsApi: NwsApi(client: client),
      );
      expect(
        () => api.fetchWeather(_mesa),
        throwsA(isA<WeatherException>()),
      );
    });
  });
}
