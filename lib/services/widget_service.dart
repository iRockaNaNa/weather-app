import 'dart:async';

import 'package:home_widget/home_widget.dart';

import '../cubit/weather_state.dart';
import '../models/weather.dart';
import '../models/weather_codes.dart';
import 'personality.dart';

/// Which content the home-screen widget shows.
///
/// The widget itself is never gated at the system level — anyone can add
/// it. What it *shows* is gated: free users see a locked upsell, Premium
/// users see live data, and a fresh install with no data yet asks the
/// user to open the app.
enum WidgetContentState {
  /// No weather has ever been loaded (the app was never opened).
  noData,

  /// Free user: locked upsell, never live data.
  locked,

  /// Premium user with GPS weather.
  live,
}

/// The widget's data: the GPS city's current conditions, plus the
/// snarky dialogue line when the user has it on.
///
/// Stored as one value per key in the widget's shared preferences, so
/// the native widget can read each field directly.
class WidgetPayload {
  const WidgetPayload({
    required this.state,
    this.cityName,
    this.temperatureF,
    this.feelsLikeF,
    this.conditionLabel,
    this.dialogueLine,
    this.updatedAt,
  });

  final WidgetContentState state;

  /// GPS city name, e.g. "Mesa, Arizona".
  final String? cityName;

  /// Temperature in °F.
  final double? temperatureF;

  /// Feels-like temperature in °F.
  final double? feelsLikeF;

  /// Short condition label, e.g. "Clear", "Rain".
  final String? conditionLabel;

  /// The personality line, when dialogue is on. Null otherwise.
  final String? dialogueLine;

  /// When this payload was built.
  final DateTime? updatedAt;

  static const WidgetPayload noData =
      WidgetPayload(state: WidgetContentState.noData);

  static const WidgetPayload locked =
      WidgetPayload(state: WidgetContentState.locked);

  /// Builds the payload for the current app state.
  ///
  /// Free users always get the locked payload, even when weather is
  /// loaded — the widget never leaks live data to the free tier.
  /// Premium users get live data when there is a GPS city, otherwise
  /// the empty state.
  factory WidgetPayload.forState({
    required WeatherData? gpsData,
    required bool isPremium,
    String? dialogueLine,
  }) {
    if (!isPremium) return locked;
    if (gpsData == null) return noData;
    return WidgetPayload(
      state: WidgetContentState.live,
      cityName: gpsData.city.displayName,
      temperatureF: gpsData.current.temperature,
      feelsLikeF: gpsData.current.feelsLike,
      conditionLabel: shortLabelForCode(gpsData.current.weatherCode),
      dialogueLine: dialogueLine,
      updatedAt: DateTime.now(),
    );
  }

  /// Storage keys, one per field.
  static const stateKey = 'widget_state';
  static const cityKey = 'widget_city';
  static const tempKey = 'widget_temp';
  static const feelsLikeKey = 'widget_feels_like';
  static const conditionKey = 'widget_condition';
  static const dialogueKey = 'widget_dialogue';
  static const updatedAtKey = 'widget_updated_at';

  /// The values to write, keyed by storage key. Null values clear the key.
  Map<String, Object?> toMap() => {
        stateKey: state.name,
        cityKey: cityName,
        tempKey: temperatureF,
        feelsLikeKey: feelsLikeF,
        conditionKey: conditionLabel,
        dialogueKey: dialogueLine,
        updatedAtKey: updatedAt?.millisecondsSinceEpoch,
      };

  factory WidgetPayload.fromMap(Map<String, Object?> map) {
    final stateRaw = map[stateKey] as String?;
    final state = WidgetContentState.values.firstWhere(
      (s) => s.name == stateRaw,
      orElse: () => WidgetContentState.noData,
    );
    return WidgetPayload(
      state: state,
      cityName: map[cityKey] as String?,
      temperatureF: (map[tempKey] as num?)?.toDouble(),
      feelsLikeF: (map[feelsLikeKey] as num?)?.toDouble(),
      conditionLabel: map[conditionKey] as String?,
      dialogueLine: map[dialogueKey] as String?,
      updatedAt: (map[updatedAtKey] as num?) != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map[updatedAtKey] as num).toInt(),
            )
          : null,
    );
  }
}

/// The platform calls the widget needs: save one value, then ask the
/// launcher to redraw. Kept behind an interface so tests can use a fake.
abstract class WidgetStorage {
  Future<bool?> save(String key, Object? value);

  Future<void> updateWidget();
}

/// Real storage: the home_widget plugin's shared preferences.
class HomeWidgetStorage implements WidgetStorage {
  @override
  Future<bool?> save(String key, Object? value) {
    if (value == null) return HomeWidget.saveWidgetData<String>(key, null);
    if (value is String) return HomeWidget.saveWidgetData<String>(key, value);
    if (value is double) return HomeWidget.saveWidgetData<double>(key, value);
    if (value is int) return HomeWidget.saveWidgetData<int>(key, value);
    if (value is bool) return HomeWidget.saveWidgetData<bool>(key, value);
    throw ArgumentError(
      'Unsupported widget value type: ${value.runtimeType}',
    );
  }

  @override
  Future<void> updateWidget() => HomeWidget.updateWidget(
        qualifiedAndroidName: WidgetService.receiverClassName,
      );
}

/// Writes the widget's data and asks the launcher to redraw it.
///
/// Syncing never throws: widget failures must never break the app.
/// Call [sync] whenever weather loads or refreshes, when Premium flips,
/// and when the personality toggle changes.
class WidgetService {
  WidgetService({WidgetStorage? storage})
      : _storage = storage ?? HomeWidgetStorage();

  final WidgetStorage _storage;

  /// Fully qualified receiver class, used to target the widget update.
  static const receiverClassName =
      'com.nanatechcreativestudios.weather.WeatherWidgetReceiver';

  /// Deep-link targets the widget taps use. The app reads the `target`
  /// query parameter when launched from the widget.
  static const paywallTarget = 'paywall';
  static const homeTarget = 'home';

  /// The URI a widget tap opens the app with.
  static Uri tapUri({required bool toPaywall}) => Uri.parse(
        'weatherapp://widget?target=${toPaywall ? paywallTarget : homeTarget}',
      );

  /// The GPS city's data in a loaded state, or null without GPS.
  static WeatherData? gpsDataOf(WeatherLoaded state) =>
      state.cities.where((w) => w.city.isCurrentLocation).firstOrNull;

  /// The dialogue line for the widget, or null when lines are off.
  /// Free users never get a line.
  static String? dialogueLineFor({
    required WeatherData? gpsData,
    required PersonalitySettings settings,
    required bool isPremium,
  }) {
    if (gpsData == null) return null;
    if (!settings.isEnabledFor(isPremium: isPremium)) return null;
    return PersonalityDialogue.lineFor(
      weatherCode: gpsData.current.weatherCode,
      temperatureF: gpsData.current.temperature,
      windSpeedMph: gpsData.current.windSpeed,
      personality: settings.prefs.value.personality,
      variant: PersonalityDialogue.dailyVariant(),
    );
  }

  /// Builds the payload for the current state and pushes it to the widget.
  Future<void> sync({
    required WeatherData? gpsData,
    required bool isPremium,
    String? dialogueLine,
  }) async {
    try {
      final payload = WidgetPayload.forState(
        gpsData: gpsData,
        isPremium: isPremium,
        dialogueLine: dialogueLine,
      );
      for (final entry in payload.toMap().entries) {
        await _storage.save(entry.key, entry.value);
      }
      await _storage.updateWidget();
    } catch (_) {
      // Widget updates never break the app.
    }
  }

  /// The URI the app was launched with from a widget tap, if any.
  static Future<Uri?> launchedFromWidget() =>
      HomeWidget.initiallyLaunchedFromHomeWidget();

  /// Taps on the widget while the app is already running.
  static Stream<Uri?> get widgetClicked => HomeWidget.widgetClicked;

  /// True when this launch URI means "open the paywall".
  static bool isPaywallTap(Uri? uri) =>
      uri?.queryParameters['target'] == paywallTarget;
}
