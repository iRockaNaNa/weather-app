import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:weather_app/models/weather.dart';
import 'package:weather_app/widgets/hourly_strip.dart';

/// 12 hourly points, all clear (weather code 0) — the case from the
/// screenshot: Chicago, 44°, Clear.
List<HourlyPoint> clearHours() {
  final now = DateTime(2026, 11, 14, 13);
  return List.generate(
    12,
    (i) => HourlyPoint(
      time: now.add(Duration(hours: i)),
      temperature: 44.0 - i,
      weatherCode: 0,
    ),
  );
}

/// Pumps [HourlyStrip] at a phone-sized viewport with the given font
/// scale. RenderFlex overflows are reported through FlutterError, which
/// the test binding captures — [WidgetTester.takeException] retrieves
/// them, so no custom onError handler is needed.
Future<void> pumpStrip(
  WidgetTester tester, {
  required double textScale,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 844),
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: HourlyStrip(hourly: clearHours()),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('HourlyStrip overflow', () {
    testWidgets('no overflow at default font scale', (tester) async {
      await pumpStrip(tester, textScale: 1.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no overflow at a large system font scale', (tester) async {
      // Android "Larger" font size is ~1.3x; the test font has a smaller
      // line-height factor than Roboto, so 1.6x here stands in for the
      // on-device overflow seen in the screenshot.
      await pumpStrip(tester, textScale: 1.6);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no overflow at an extra-large system font scale',
        (tester) async {
      await pumpStrip(tester, textScale: 2.0);
      expect(tester.takeException(), isNull);
    });
  });
}
