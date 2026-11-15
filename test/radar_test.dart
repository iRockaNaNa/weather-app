import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:weather_app/models/weather.dart';
import 'package:weather_app/screens/radar_screen.dart';
import 'package:weather_app/services/purchase_service.dart';
import 'package:weather_app/services/radar_api.dart';

/// A small real-shaped RainViewer response (frames trimmed to two).
const _sampleMapsJson = {
  'version': '2.0',
  'generated': 1794686420,
  'host': 'https://tilecache.rainviewer.com',
  'radar': {
    'past': [
      {'time': 1794685800, 'path': '/v2/radar/a396d3025964'},
      {'time': 1794686400, 'path': '/v2/radar/006d57c1f85a'},
    ],
    'nowcast': [],
  },
  'satellite': {'infrared': []},
};

void main() {
  group('RadarFrames — parsing', () {
    test('parses host and past frames oldest first', () {
      final frames = RadarFrames.fromJson(_sampleMapsJson);
      expect(frames.host, 'https://tilecache.rainviewer.com');
      expect(frames.frames.length, 2);
      expect(frames.frames.first.time, 1794685800);
      expect(frames.frames.first.path, '/v2/radar/a396d3025964');
      expect(frames.latest?.time, 1794686400);
    });

    test('missing radar data gives no frames, not a crash', () {
      expect(RadarFrames.fromJson({}).frames, isEmpty);
      expect(RadarFrames.fromJson({'radar': {}}).frames, isEmpty);
      expect(
        RadarFrames.fromJson({'radar': {'past': []}}).frames,
        isEmpty,
      );
    });

    test('frames with no time or path are skipped', () {
      final frames = RadarFrames.fromJson({
        'host': 'https://tilecache.rainviewer.com',
        'radar': {
          'past': [
            {'time': 1794686400, 'path': '/v2/radar/006d57c1f85a'},
            {'time': 0, 'path': '/v2/radar/bad'},
            {'time': 1794685800, 'path': ''},
          ],
        },
      });
      expect(frames.frames.length, 1);
      expect(frames.frames.first.path, '/v2/radar/006d57c1f85a');
    });

    test('frames are sorted oldest first even if the API is not', () {
      final frames = RadarFrames.fromJson({
        'host': 'https://tilecache.rainviewer.com',
        'radar': {
          'past': [
            {'time': 1794686400, 'path': '/v2/radar/newer'},
            {'time': 1794685800, 'path': '/v2/radar/older'},
          ],
        },
      });
      expect(frames.frames.first.path, '/v2/radar/older');
      expect(frames.latest?.path, '/v2/radar/newer');
    });
  });

  group('RadarFrame — time label', () {
    test('label matches the local hour label for its time', () {
      const frame = RadarFrame(
        time: 1794686400,
        path: '/v2/radar/006d57c1f85a',
      );
      expect(frame.label, DateFormats.hourLabel(frame.dateTime));
      expect(
        frame.dateTime,
        DateTime.fromMillisecondsSinceEpoch(1794686400 * 1000),
      );
    });
  });

  group('RadarTileUrl — tile URLs', () {
    test('builds the exact RainViewer tile URL', () {
      const frame = RadarFrame(
        time: 1794686400,
        path: '/v2/radar/006d57c1f85a',
      );
      expect(
        RadarTileUrl.tile(
          host: 'https://tilecache.rainviewer.com',
          frame: frame,
          z: 5,
          x: 9,
          y: 12,
        ),
        'https://tilecache.rainviewer.com/v2/radar/006d57c1f85a/256/5/9/12/2/1_1.png',
      );
    });

    test('template keeps {z}/{x}/{y} placeholders for the map', () {
      const frame = RadarFrame(
        time: 1794686400,
        path: '/v2/radar/006d57c1f85a',
      );
      expect(
        RadarTileUrl.template(
          host: 'https://tilecache.rainviewer.com',
          frame: frame,
        ),
        'https://tilecache.rainviewer.com/v2/radar/006d57c1f85a/256/{z}/{x}/{y}/2/1_1.png',
      );
    });
  });

  group('RadarFrames — animation stepping', () {
    test('nextIndex steps forward and wraps to the start', () {
      expect(RadarFrames.nextIndex(0, 3), 1);
      expect(RadarFrames.nextIndex(1, 3), 2);
      expect(RadarFrames.nextIndex(2, 3), 0);
    });

    test('nextIndex with no frames stays at 0', () {
      expect(RadarFrames.nextIndex(0, 0), 0);
    });
  });

  group('RadarScreen — the radar actually loads', () {
    // Regression test (Nov 14): the radar screen was stuck on
    // "Loading radar…" forever. _loading started at true, and the
    // load is only triggered from build() when NOT already loading —
    // so the first load never started, and the refresh button was
    // disabled too, so there was no way out. Pumping the screen
    // with a mock API must end with the map on screen, not the
    // spinner.
    testWidgets('Premium user sees the map, not a stuck spinner',
        (tester) async {
      final api = RadarApi(
        client: MockClient((_) async => http.Response(
              '{"version":"2.0","generated":1794686420,'
              '"host":"https://tilecache.rainviewer.com",'
              '"radar":{"past":['
              '{"time":1794685800,"path":"/v2/radar/a396d3025964"},'
              '{"time":1794686400,"path":"/v2/radar/006d57c1f85a"}]}}',
              200,
            )),
      );
      final service = PurchaseService();
      service.isPremium.value = true;

      await tester.pumpWidget(
        MaterialApp(
          home: RepositoryProvider<PurchaseService>.value(
            value: service,
            child: RadarScreen(
              latitude: 33.42,
              longitude: -111.83,
              cityName: 'Phoenix',
              api: api,
            ),
          ),
        ),
      );
      // First frame schedules the load, the next ones run it.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      await tester.pump();

      expect(find.text('Loading radar…'), findsNothing);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
