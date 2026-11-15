import 'dart:convert';

import 'package:http/http.dart' as http;

/// One active severe-weather alert from the National Weather Service.
class WeatherAlert {
  const WeatherAlert({
    required this.event,
    required this.severity,
    required this.headline,
    required this.description,
    required this.instruction,
    required this.area,
    this.effective,
    this.expires,
  });

  /// e.g. "Excessive Heat Warning", "Severe Thunderstorm Watch".
  final String event;

  /// NWS severity: Extreme, Severe, Moderate, Minor, Unknown.
  final String severity;

  /// Short headline from the alert.
  final String headline;

  /// Full alert text.
  final String description;

  /// What to do (may be empty when the alert gives none).
  final String instruction;

  /// Area the alert covers, e.g. "Maricopa County".
  final String area;

  final DateTime? effective;
  final DateTime? expires;

  /// Sort order, most severe first: Extreme, Severe, Moderate, Minor,
  /// then anything else.
  static const _severityOrder = {
    'extreme': 0,
    'severe': 1,
    'moderate': 2,
    'minor': 3,
  };

  int get severityRank => _severityOrder[severity.toLowerCase()] ?? 4;

  /// True only for an alert with a real event name.
  bool get isValid => event.isNotEmpty;

  factory WeatherAlert.fromJson(Map<String, dynamic> json) {
    final props = json['properties'];
    final p = props is Map ? Map<String, dynamic>.from(props) : <String, dynamic>{};
    return WeatherAlert(
      event: p['event'] as String? ?? '',
      severity: p['severity'] as String? ?? 'Unknown',
      headline: p['headline'] as String? ?? '',
      description: p['description'] as String? ?? '',
      instruction: p['instruction'] as String? ?? '',
      area: p['areaDesc'] as String? ?? '',
      effective: DateTime.tryParse(p['effective'] as String? ?? ''),
      expires: DateTime.tryParse(p['expires'] as String? ?? ''),
    );
  }
}

/// National Weather Service active alerts — free, no key, US only.
/// https://api.weather.gov/alerts
///
/// The app never breaks on alerts: a non-US point, no active alerts,
/// or any failure all come back as an empty list.
class AlertsApi {
  AlertsApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _activeBase = 'https://api.weather.gov/alerts/active';

  /// Active alerts at a point, most severe first.
  Future<List<WeatherAlert>> fetchAlerts({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse('$_activeBase?point=$latitude,$longitude');
    try {
      final res = await _client.get(
        uri,
        headers: {
          // NWS asks callers to identify themselves.
          'User-Agent': 'NanatechWeather/1.0 (ciao@nanatechcreativestudios.com)',
          'Accept': 'application/geo+json',
        },
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return [];
      final features = decoded['features'];
      if (features is! List) return [];
      final alerts = <WeatherAlert>[];
      for (final feature in features) {
        if (feature is Map) {
          final alert =
              WeatherAlert.fromJson(Map<String, dynamic>.from(feature));
          if (alert.isValid) alerts.add(alert);
        }
      }
      alerts.sort((a, b) => a.severityRank.compareTo(b.severityRank));
      return alerts;
    } catch (_) {
      return [];
    }
  }
}
