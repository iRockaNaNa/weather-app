import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:weather_app/models/weather.dart';
import 'package:weather_app/services/alerts_api.dart';
import 'package:weather_app/services/purchase_service.dart';
import 'package:weather_app/widgets/city_card.dart';

WeatherData _sampleData({List<WeatherAlert> alerts = const []}) =>
    WeatherData(
      city: const City(
        id: 'test',
        name: 'Mesa',
        country: 'United States',
        latitude: 33.42,
        longitude: -111.83,
      ),
      current: const CurrentWeather(
        temperature: 62,
        feelsLike: 63,
        humidity: 30,
        windSpeed: 5,
        pressure: 1012,
        precipitation: 0,
        weatherCode: 0,
        isDay: false,
      ),
      hourly: const [],
      daily: const [],
      fetchedAt: DateTime(2026, 11, 14),
      alerts: alerts,
    );

const _sampleAlert = WeatherAlert(
  event: 'Excessive Heat Warning',
  severity: 'Severe',
  headline: 'Excessive Heat Warning issued',
  description: 'Dangerously hot conditions.',
  instruction: 'Drink plenty of fluids.',
  area: 'Maricopa County',
);

/// Pumps [CityCard] at a phone-sized viewport with the given font
/// scale. RenderFlex overflows are reported through FlutterError,
/// which the test binding captures — [WidgetTester.takeException]
/// retrieves them, so no custom onError handler is needed.
Future<void> pumpCard(
  WidgetTester tester, {
  required double textScale,
  bool isPremium = false,
  List<WeatherAlert> alerts = const [],
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final service = PurchaseService();
  service.isPremium.value = isPremium;

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 844),
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp(
        home: RepositoryProvider<PurchaseService>.value(
          value: service,
          child: Scaffold(
            body: SingleChildScrollView(
              child: CityCard(
                data: _sampleData(alerts: alerts),
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('CityCard overflow', () {
    testWidgets('no overflow at default font scale', (tester) async {
      await pumpCard(tester, textScale: 1.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no overflow at a large system font scale', (tester) async {
      // Android "Larger" font size is ~1.3x — the scale that showed
      // "BOTTOM OVERFLOWED BY 17 PIXELS" on the phone.
      await pumpCard(tester, textScale: 1.3);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no overflow at an extra-large system font scale',
        (tester) async {
      await pumpCard(tester, textScale: 2.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no overflow with the alert badge at a large font scale',
        (tester) async {
      await pumpCard(
        tester,
        textScale: 1.3,
        isPremium: true,
        alerts: [_sampleAlert],
      );
      expect(tester.takeException(), isNull);
    });
  });
}
