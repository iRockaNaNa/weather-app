import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/weather.dart';

class NwsException implements Exception {
  NwsException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Maps a National Weather Service short forecast ("Partly Cloudy",
/// "Chance Showers And Thunderstorms") to the WMO weather code the
/// app's styles and labels already understand.
///
/// Checked most specific first: "Mostly Clear" contains "Clear",
/// "Partly Cloudy" contains "Cloudy", so the longer phrases win.
int nwsForecastToWmoCode(String shortForecast) {
  final text = shortForecast.toLowerCase();
  if (text.contains('thunder')) return 95;
  if (text.contains('snow') ||
      text.contains('flurr') ||
      text.contains('blizzard')) {
    return 71;
  }
  if (text.contains('sleet') ||
      text.contains('freezing rain') ||
      text.contains('ice')) {
    return 67;
  }
  if (text.contains('drizzle')) return 51;
  if (text.contains('rain') || text.contains('shower')) return 61;
  if (text.contains('fog') ||
      text.contains('haze') ||
      text.contains('smoke')) {
    return 45;
  }
  if (text.contains('partly')) return 2;
  if (text.contains('mostly clear') || text.contains('mostly sunny')) {
    return 1;
  }
  if (text.contains('cloudy') || text.contains('overcast')) return 3;
  if (text.contains('clear') || text.contains('sunny')) return 0;
  return 3;
}

/// Parses a National Weather Service wind speed ("5 mph",
/// "5 to 10 mph", "Calm") into mph. Non-numeric means calm.
double _parseWindMph(String? raw) {
  if (raw == null) return 0;
  final match = RegExp(r'[\d.]+').firstMatch(raw);
  if (match == null) return 0;
  return double.tryParse(match.group(0)!) ?? 0;
}

double? _asDouble(dynamic value) => (value as num?)?.toDouble();

int? _asInt(dynamic value) => (value as num?)?.toInt();

/// National Weather Service forecast — free, no key, US only.
/// https://api.weather.gov
///
/// The app's backup weather source: when Open-Meteo can't be reached
/// at all, this takes over for US cities. Two things it can't give
/// us: NWS has no UV index (daily UV reads 0 on fallback data) and
/// no pressure in the forecast (standard 1013.25 hPa is used —
/// pressure isn't shown anywhere in the app).
class NwsApi {
  NwsApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _pointsBase = 'https://api.weather.gov/points';

  /// Current + hourly + 7-day forecast for a US city.
  /// Throws [NwsException] for non-US points and on any failure.
  Future<WeatherData> fetchWeather(City city) async {
    final point = await _getJson(
      Uri.parse(
        '$_pointsBase/${city.latitude},${city.longitude}',
      ),
    );
    final props = point['properties'];
    if (props is! Map) throw NwsException('NWS point data looked wrong.');
    final forecastUrl = props['forecast'] as String?;
    final hourlyUrl = props['forecastHourly'] as String?;
    if (forecastUrl == null || hourlyUrl == null) {
      throw NwsException('NWS did not return a forecast for this place.');
    }

    final results = await Future.wait([
      _getJson(Uri.parse(hourlyUrl)),
      _getJson(Uri.parse(forecastUrl)),
    ]);
    final hourlyJson = results[0];
    final forecastJson = results[1];

    final hourly = _parseHourly(hourlyJson);
    if (hourly.isEmpty) {
      throw NwsException('NWS returned no hourly forecast.');
    }
    final daily = _parseDaily(forecastJson);
    if (daily.isEmpty) {
      throw NwsException('NWS returned no daily forecast.');
    }
    final first = hourly.first;
    final current = CurrentWeather(
      temperature: first.temperature,
      feelsLike: first.temperature,
      humidity: _firstHourlyHumidity(hourlyJson),
      windSpeed: _firstHourlyWind(hourlyJson),
      pressure: 1013.25,
      precipitation: 0,
      weatherCode: first.weatherCode,
      isDay: _firstHourlyIsDay(hourlyJson),
    );
    return WeatherData(
      city: city,
      current: current,
      hourly: hourly,
      daily: daily,
      fetchedAt: DateTime.now(),
    );
  }

  /// One NWS GET, decoded as a JSON map. Non-200 or bad JSON throws.
  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    http.Response res;
    try {
      res = await _client.get(
        uri,
        headers: {
          // NWS asks callers to identify themselves.
          'User-Agent': 'NanatechWeather/1.0 (ciao@nanatechcreativestudios.com)',
          'Accept': 'application/geo+json',
        },
      ).timeout(const Duration(seconds: 10));
    } catch (_) {
      throw NwsException(
        'Could not reach the National Weather Service.',
      );
    }
    if (res.statusCode != 200) {
      throw NwsException('NWS returned ${res.statusCode}.');
    }
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) {
        throw NwsException('NWS data looked wrong.');
      }
      return decoded;
    } catch (e) {
      if (e is NwsException) rethrow;
      throw NwsException('NWS data looked wrong.');
    }
  }

  /// Hourly periods from a forecast/hourly response, next 24 hours.
  List<HourlyPoint> _parseHourly(Map<String, dynamic> json) {
    final props = json['properties'];
    final periods = props is Map ? props['periods'] : null;
    if (periods is! List) return [];
    final now = DateTime.now();
    final points = <HourlyPoint>[];
    for (final entry in periods) {
      if (entry is! Map) continue;
      final period = Map<String, dynamic>.from(entry);
      final start = DateTime.tryParse(period['startTime'] as String? ?? '');
      final temp = _asDouble(period['temperature']);
      if (start == null || temp == null) continue;
      if (start.isBefore(now.subtract(const Duration(hours: 1)))) continue;
      points.add(HourlyPoint(
        time: start,
        temperature: temp,
        weatherCode: nwsForecastToWmoCode(
          period['shortForecast'] as String? ?? '',
        ),
      ));
      if (points.length >= 24) break;
    }
    return points;
  }

  /// Daily highs/lows from a 7-day forecast response: day periods give
  /// the high, night periods the low, grouped by date.
  List<DailyPoint> _parseDaily(Map<String, dynamic> json) {
    final props = json['properties'];
    final periods = props is Map ? props['periods'] : null;
    if (periods is! List) return [];
    final byDay = <String, _DayBucket>{};
    for (final entry in periods) {
      if (entry is! Map) continue;
      final period = Map<String, dynamic>.from(entry);
      final start = DateTime.tryParse(period['startTime'] as String? ?? '');
      final temp = _asDouble(period['temperature']);
      if (start == null || temp == null) continue;
      final key = '${start.year}-${start.month}-${start.day}';
      final bucket = byDay.putIfAbsent(
        key,
        () => _DayBucket(
          date: DateTime(start.year, start.month, start.day),
        ),
      );
      final code = nwsForecastToWmoCode(
        period['shortForecast'] as String? ?? '',
      );
      if (period['isDaytime'] == true) {
        if (temp > bucket.tempMax) bucket.tempMax = temp;
        bucket.dayCode ??= code;
      } else {
        if (temp < bucket.tempMin) bucket.tempMin = temp;
      }
    }
    final days = byDay.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return days
        .map((b) => DailyPoint(
              date: b.date,
              weatherCode: b.dayCode ?? 3,
              // A day with only day periods (or only night ones) uses
              // the one temperature it has for both high and low.
              tempMax: b.tempMax.isFinite ? b.tempMax : b.tempMin,
              tempMin: b.tempMin.isFinite ? b.tempMin : b.tempMax,
              uvIndexMax: 0,
            ))
        .take(7)
        .toList();
  }

  /// The first hourly period's fields, read straight off the raw
  /// response so the current conditions match the forecast's first
  /// hour.
  int _firstHourlyHumidity(Map<String, dynamic> json) {
    final period = _firstUsablePeriod(json);
    if (period == null) return 0;
    final humidity = period['relativeHumidity'];
    if (humidity is Map) return _asInt(humidity['value']) ?? 0;
    return 0;
  }

  double _firstHourlyWind(Map<String, dynamic> json) {
    final period = _firstUsablePeriod(json);
    if (period == null) return 0;
    return _parseWindMph(period['windSpeed'] as String?);
  }

  bool _firstHourlyIsDay(Map<String, dynamic> json) {
    final period = _firstUsablePeriod(json);
    if (period == null) return true;
    return period['isDaytime'] == true;
  }

  /// The first hourly period the forecast actually uses — same
  /// "from an hour ago onward" rule as [_parseHourly], so the current
  /// conditions always match the first hourly point.
  Map<String, dynamic>? _firstUsablePeriod(Map<String, dynamic> json) {
    final props = json['properties'];
    final periods = props is Map ? props['periods'] : null;
    if (periods is! List) return null;
    final now = DateTime.now();
    for (final entry in periods) {
      if (entry is! Map) continue;
      final period = Map<String, dynamic>.from(entry);
      final start = DateTime.tryParse(period['startTime'] as String? ?? '');
      if (start == null) continue;
      if (start.isBefore(now.subtract(const Duration(hours: 1)))) continue;
      return period;
    }
    return null;
  }
}

/// One day's high/low while pairing NWS day and night periods.
class _DayBucket {
  _DayBucket({required this.date});

  final DateTime date;
  double tempMax = double.negativeInfinity;
  double tempMin = double.infinity;
  int? dayCode;
}
