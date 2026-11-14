import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/weather.dart';

class WeatherException implements Exception {
  WeatherException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Open-Meteo — free weather data, no API key needed.
class WeatherApi {
  WeatherApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _forecastBase = 'https://api.open-meteo.com/v1/forecast';
  static const _geoBase = 'https://geocoding-api.open-meteo.com/v1/search';

  /// Current weather + hourly + 10-day forecast for one city.
  Future<WeatherData> fetchWeather(City city) async {
    final uri = Uri.parse(
      '$_forecastBase?latitude=${city.latitude}&longitude=${city.longitude}'
      '&current=temperature_2m,relative_humidity_2m,apparent_temperature,'
      'is_day,precipitation,weather_code,wind_speed_10m,pressure_msl'
      '&hourly=temperature_2m,weather_code'
      '&daily=weather_code,temperature_2m_max,temperature_2m_min,uv_index_max'
      '&temperature_unit=fahrenheit&wind_speed_unit=mph'
      '&precipitation_unit=inch&timezone=auto&forecast_days=10',
    );
    try {
      final res = await _client
          .get(uri)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw WeatherException(
            'Weather service returned ${res.statusCode}.');
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return WeatherData.fromJson(city, json);
    } on WeatherException {
      rethrow;
    } catch (_) {
      throw WeatherException(
          'Could not reach the weather service. Check your connection.');
    }
  }

  /// Search for cities by name (Open-Meteo geocoding, free, no key).
  Future<List<City>> searchCities(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final uri = Uri.parse(
      '$_geoBase?name=${Uri.encodeQueryComponent(q)}&count=5&language=en&format=json',
    );
    try {
      final res = await _client
          .get(uri)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final results = json['results'] as List?;
      if (results == null) return [];
      return results.map((e) {
        final m = e as Map<String, dynamic>;
        final lat = (m['latitude'] as num).toDouble();
        final lon = (m['longitude'] as num).toDouble();
        return City(
          id: City.idFor(lat, lon),
          name: m['name'] as String,
          country: m['country'] as String? ?? '',
          admin1: m['admin1'] as String?,
          latitude: lat,
          longitude: lon,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Best-effort city name for GPS coordinates (BigDataCloud, free, no key).
  /// Falls back to "Current Location" when it can't be resolved.
  Future<String> reverseGeocode(double lat, double lon) async {
    final uri = Uri.parse(
      'https://api.bigdatacloud.net/data/reverse-geocode-client'
      '?latitude=$lat&longitude=$lon&localityLanguage=en',
    );
    try {
      final res = await _client
          .get(uri)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return 'Current Location';
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final city = json['city'] as String?;
      final locality = json['locality'] as String?;
      final name = (city != null && city.isNotEmpty) ? city : locality;
      if (name == null || name.isEmpty) return 'Current Location';
      return name;
    } catch (_) {
      return 'Current Location';
    }
  }
}
