import 'package:flutter_test/flutter_test.dart';
import 'package:weather_app/cubit/weather_state.dart';
import 'package:weather_app/models/weather.dart';
import 'package:weather_app/services/personality.dart';
import 'package:weather_app/services/widget_service.dart';

/// Records what the service tried to save, instead of touching the
/// platform widget storage.
class FakeWidgetStorage implements WidgetStorage {
  final saved = <String, Object?>{};
  int updateCalls = 0;
  bool throwOnSave = false;

  @override
  Future<bool?> save(String key, Object? value) async {
    if (throwOnSave) throw StateError('no storage');
    saved[key] = value;
    return true;
  }

  @override
  Future<void> updateWidget() async {
    updateCalls++;
  }
}

WeatherData gpsData() => WeatherData(
      city: const City(
        id: 'gps',
        name: 'Mesa',
        country: 'US',
        admin1: 'Arizona',
        latitude: 33.41,
        longitude: -111.83,
        isCurrentLocation: true,
      ),
      current: const CurrentWeather(
        temperature: 72,
        feelsLike: 74,
        humidity: 20,
        windSpeed: 5,
        pressure: 1013,
        precipitation: 0,
        weatherCode: 0,
        isDay: true,
      ),
      hourly: const [],
      daily: const [],
      fetchedAt: DateTime(2026, 11, 14),
    );

void main() {
  group('WidgetPayload — states', () {
    test('free user gets the locked payload even with weather loaded', () {
      final payload = WidgetPayload.forState(
        gpsData: gpsData(),
        isPremium: false,
        dialogueLine: 'Some line',
      );
      expect(payload.state, WidgetContentState.locked);
      expect(payload.cityName, isNull);
      expect(payload.temperatureF, isNull);
    });

    test('premium user without GPS data gets the empty payload', () {
      final payload = WidgetPayload.forState(
        gpsData: null,
        isPremium: true,
      );
      expect(payload.state, WidgetContentState.noData);
    });

    test('premium user with GPS data gets live data', () {
      final payload = WidgetPayload.forState(
        gpsData: gpsData(),
        isPremium: true,
        dialogueLine: 'Sunny and clear.',
      );
      expect(payload.state, WidgetContentState.live);
      expect(payload.cityName, 'Mesa, Arizona');
      expect(payload.temperatureF, 72);
      expect(payload.feelsLikeF, 74);
      expect(payload.conditionLabel, 'Clear');
      expect(payload.dialogueLine, 'Sunny and clear.');
      expect(payload.updatedAt, isNotNull);
    });

    test('live payload without a dialogue line has a null line', () {
      final payload = WidgetPayload.forState(
        gpsData: gpsData(),
        isPremium: true,
      );
      expect(payload.state, WidgetContentState.live);
      expect(payload.dialogueLine, isNull);
    });
  });

  group('WidgetPayload — map round-trip', () {
    test('live payload survives toMap/fromMap', () {
      final original = WidgetPayload.forState(
        gpsData: gpsData(),
        isPremium: true,
        dialogueLine: 'Sunny and clear.',
      );
      final restored = WidgetPayload.fromMap(original.toMap());
      expect(restored.state, WidgetContentState.live);
      expect(restored.cityName, original.cityName);
      expect(restored.temperatureF, original.temperatureF);
      expect(restored.feelsLikeF, original.feelsLikeF);
      expect(restored.conditionLabel, original.conditionLabel);
      expect(restored.dialogueLine, original.dialogueLine);
      // Stored as epoch milliseconds, so microseconds are dropped.
      expect(
        restored.updatedAt?.millisecondsSinceEpoch,
        original.updatedAt?.millisecondsSinceEpoch,
      );
    });

    test('locked payload round-trips with null fields', () {
      final restored = WidgetPayload.fromMap(WidgetPayload.locked.toMap());
      expect(restored.state, WidgetContentState.locked);
      expect(restored.cityName, isNull);
      expect(restored.temperatureF, isNull);
    });

    test('unknown state falls back to noData', () {
      final restored = WidgetPayload.fromMap({'widget_state': 'weird'});
      expect(restored.state, WidgetContentState.noData);
    });
  });

  group('WidgetService.sync', () {
    test('writes every key and asks for one widget update', () async {
      final storage = FakeWidgetStorage();
      final service = WidgetService(storage: storage);
      await service.sync(
        gpsData: gpsData(),
        isPremium: true,
        dialogueLine: 'Sunny and clear.',
      );
      expect(storage.saved[WidgetPayload.stateKey], 'live');
      expect(storage.saved[WidgetPayload.cityKey], 'Mesa, Arizona');
      expect(storage.saved[WidgetPayload.tempKey], 72);
      expect(storage.saved[WidgetPayload.feelsLikeKey], 74);
      expect(storage.saved[WidgetPayload.conditionKey], 'Clear');
      expect(storage.saved[WidgetPayload.dialogueKey], 'Sunny and clear.');
      expect(storage.saved[WidgetPayload.updatedAtKey], isA<int>());
      expect(storage.updateCalls, 1);
    });

    test('free sync writes the locked state and clears live fields', () async {
      final storage = FakeWidgetStorage();
      final service = WidgetService(storage: storage);
      await service.sync(gpsData: gpsData(), isPremium: false);
      expect(storage.saved[WidgetPayload.stateKey], 'locked');
      expect(storage.saved[WidgetPayload.cityKey], isNull);
      expect(storage.saved[WidgetPayload.tempKey], isNull);
      expect(storage.updateCalls, 1);
    });

    test('sync never throws when storage fails', () async {
      final storage = FakeWidgetStorage()..throwOnSave = true;
      final service = WidgetService(storage: storage);
      await service.sync(gpsData: gpsData(), isPremium: true);
    });
  });

  group('WidgetService helpers', () {
    test('gpsDataOf picks the GPS city, null without one', () {
      final loaded = WeatherLoaded(cities: [gpsData()], locationAvailable: true);
      expect(WidgetService.gpsDataOf(loaded)?.city.name, 'Mesa');
      final noGps = WeatherLoaded(cities: const [], locationAvailable: false);
      expect(WidgetService.gpsDataOf(noGps), isNull);
    });

    test('dialogueLineFor returns null for free users', () {
      final settings = PersonalitySettings();
      expect(
        WidgetService.dialogueLineFor(
          gpsData: gpsData(),
          settings: settings,
          isPremium: false,
        ),
        isNull,
      );
    });

    test('dialogueLineFor returns null when the toggle is off', () {
      final settings = PersonalitySettings();
      settings.prefs.value =
          const PersonalityPrefs(dialogueEnabled: false);
      expect(
        WidgetService.dialogueLineFor(
          gpsData: gpsData(),
          settings: settings,
          isPremium: true,
        ),
        isNull,
      );
    });

    test('dialogueLineFor returns a line from the right pool', () {
      final settings = PersonalitySettings();
      settings.prefs.value = const PersonalityPrefs(
        dialogueEnabled: true,
        personality: Personality.friendly,
      );
      final line = WidgetService.dialogueLineFor(
        gpsData: gpsData(),
        settings: settings,
        isPremium: true,
      );
      expect(line, isNotNull);
      expect(
        PersonalityDialogue.lines['clear']![Personality.friendly]!,
        contains(line),
      );
    });

    test('tap URIs carry the right target', () {
      final paywallUri = WidgetService.tapUri(toPaywall: true);
      expect(paywallUri.queryParameters['target'], 'paywall');
      expect(WidgetService.isPaywallTap(paywallUri), isTrue);
      final homeUri = WidgetService.tapUri(toPaywall: false);
      expect(homeUri.queryParameters['target'], 'home');
      expect(WidgetService.isPaywallTap(homeUri), isFalse);
      expect(WidgetService.isPaywallTap(null), isFalse);
    });
  });
}
