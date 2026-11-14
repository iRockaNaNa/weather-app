import 'dart:convert';

/// A place the user can get weather for.
class City {
  const City({
    required this.id,
    required this.name,
    required this.country,
    this.admin1,
    required this.latitude,
    required this.longitude,
    this.isCurrentLocation = false,
  });

  /// Stable id built from coordinates, e.g. "33.41_-111.83".
  final String id;
  final String name;
  final String country;
  final String? admin1;
  final double latitude;
  final double longitude;

  /// True for the GPS city (not saved by the user).
  final bool isCurrentLocation;

  String get displayName {
    if (admin1 != null && admin1!.isNotEmpty) {
      return '$name, $admin1';
    }
    return name;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'country': country,
        'admin1': admin1,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory City.fromJson(Map<String, dynamic> json) => City(
        id: json['id'] as String,
        name: json['name'] as String,
        country: json['country'] as String? ?? '',
        admin1: json['admin1'] as String?,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
      );

  static String idFor(double lat, double lon) =>
      '${lat.toStringAsFixed(2)}_${lon.toStringAsFixed(2)}';

  @override
  bool operator ==(Object other) => other is City && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Right-now conditions for a city.
class CurrentWeather {
  const CurrentWeather({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.pressure,
    required this.precipitation,
    required this.weatherCode,
    required this.isDay,
  });

  /// Temperature in °F.
  final double temperature;

  /// Feels-like temperature in °F.
  final double feelsLike;

  /// Relative humidity in %.
  final int humidity;

  /// Wind speed in mph.
  final double windSpeed;

  /// Surface pressure in hPa.
  final double pressure;

  /// Precipitation in inches.
  final double precipitation;

  /// WMO weather code.
  final int weatherCode;

  /// True when the sun is up at this location.
  final bool isDay;
}

/// One hour of the forecast.
class HourlyPoint {
  const HourlyPoint({
    required this.time,
    required this.temperature,
    required this.weatherCode,
  });

  final DateTime time;
  final double temperature;
  final int weatherCode;
}

/// One day of the forecast.
class DailyPoint {
  const DailyPoint({
    required this.date,
    required this.weatherCode,
    required this.tempMax,
    required this.tempMin,
    required this.uvIndexMax,
  });

  final DateTime date;
  final int weatherCode;
  final double tempMax;
  final double tempMin;
  final double uvIndexMax;
}

/// Everything the screens need for one city.
class WeatherData {
  const WeatherData({
    required this.city,
    required this.current,
    required this.hourly,
    required this.daily,
    required this.fetchedAt,
  });

  final City city;
  final CurrentWeather current;

  /// Next hours, starting at the current hour.
  final List<HourlyPoint> hourly;

  /// 10-day forecast, starting today.
  final List<DailyPoint> daily;

  final DateTime fetchedAt;

  factory WeatherData.fromJson(City city, Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>;
    final hourly = json['hourly'] as Map<String, dynamic>;
    final daily = json['daily'] as Map<String, dynamic>;

    final hourlyTimes = (hourly['time'] as List).cast<String>();
    final hourlyTemps = (hourly['temperature_2m'] as List).cast<num>();
    final hourlyCodes = (hourly['weather_code'] as List).cast<num>();

    final now = DateTime.now();
    final points = <HourlyPoint>[];
    for (var i = 0; i < hourlyTimes.length; i++) {
      final t = DateTime.parse(hourlyTimes[i]);
      // Keep from the current hour onward, next 24 hours max.
      if (t.isBefore(now.subtract(const Duration(hours: 1)))) continue;
      points.add(HourlyPoint(
        time: t,
        temperature: hourlyTemps[i].toDouble(),
        weatherCode: hourlyCodes[i].toInt(),
      ));
      if (points.length >= 24) break;
    }

    final dailyTimes = (daily['time'] as List).cast<String>();
    final dailyCodes = (daily['weather_code'] as List).cast<num>();
    final dailyMax = (daily['temperature_2m_max'] as List).cast<num>();
    final dailyMin = (daily['temperature_2m_min'] as List).cast<num>();
    final dailyUv = (daily['uv_index_max'] as List).cast<num>();

    final days = <DailyPoint>[];
    for (var i = 0; i < dailyTimes.length; i++) {
      days.add(DailyPoint(
        date: DateTime.parse(dailyTimes[i]),
        weatherCode: dailyCodes[i].toInt(),
        tempMax: dailyMax[i].toDouble(),
        tempMin: dailyMin[i].toDouble(),
        uvIndexMax: dailyUv[i].toDouble(),
      ));
    }

    return WeatherData(
      city: city,
      current: CurrentWeather(
        temperature: (current['temperature_2m'] as num).toDouble(),
        feelsLike: (current['apparent_temperature'] as num).toDouble(),
        humidity: (current['relative_humidity_2m'] as num).toInt(),
        windSpeed: (current['wind_speed_10m'] as num).toDouble(),
        pressure: (current['pressure_msl'] as num).toDouble(),
        precipitation: (current['precipitation'] as num).toDouble(),
        weatherCode: (current['weather_code'] as num).toInt(),
        isDay: (current['is_day'] as num).toInt() == 1,
      ),
      hourly: points,
      daily: days,
      fetchedAt: DateTime.now(),
    );
  }
}

/// Small date helpers so we don't need the intl package.
class DateFormats {
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _weekdays = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  /// "Mar 6, 2026"
  static String mediumDate(DateTime d) =>
      '${_months[d.month - 1]} ${d.day}, ${d.year}';

  /// "12:00 AM" / "3:00 PM"
  static String hourLabel(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour < 12 ? 'AM' : 'PM';
    return '$h:00 $ampm';
  }

  /// "Today", "Mon", "Tue" ...
  static String dayLabel(DateTime d, DateTime today) {
    if (d.year == today.year &&
        d.month == today.month &&
        d.day == today.day) {
      return 'Today';
    }
    return _weekdays[d.weekday - 1];
  }

  static String cityListJson(List<City> cities) =>
      jsonEncode(cities.map((c) => c.toJson()).toList());

  static List<City> cityListFromJson(String raw) {
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => City.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
