import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/weather.dart';

/// One RainViewer radar frame: a snapshot time and its tile path.
class RadarFrame {
  const RadarFrame({required this.time, required this.path});

  /// Unix time (seconds) of the radar snapshot.
  final int time;

  /// Tile path from the API, e.g. "/v2/radar/006d57c1f85a".
  final String path;

  /// Local time of this frame.
  DateTime get dateTime =>
      DateTime.fromMillisecondsSinceEpoch(time * 1000);

  /// "3:00 PM" — plain hour label in local time.
  String get label => DateFormats.hourLabel(dateTime);

  factory RadarFrame.fromJson(Map<String, dynamic> json) => RadarFrame(
        time: (json['time'] as num?)?.toInt() ?? 0,
        path: json['path'] as String? ?? '',
      );

  /// True only for a frame with a real time and tile path.
  bool get isValid => time > 0 && path.isNotEmpty;
}

/// The radar frames RainViewer has right now.
class RadarFrames {
  const RadarFrames({required this.host, required this.frames});

  /// Tile host from the API, e.g. "https://tilecache.rainviewer.com".
  final String host;

  /// Past radar frames, oldest first.
  final List<RadarFrame> frames;

  /// The newest frame, or null when there are none.
  RadarFrame? get latest => frames.isEmpty ? null : frames.last;

  /// Next frame index for the animation, wrapping back to the start.
  static int nextIndex(int current, int count) {
    if (count <= 0) return 0;
    return (current + 1) % count;
  }

  factory RadarFrames.fromJson(Map<String, dynamic> json) {
    final host = json['host'] is String
        ? json['host'] as String
        : 'https://tilecache.rainviewer.com';
    // Lenient reads: decoded JSON maps are not always
    // Map<String, dynamic>, so never hard-cast them.
    final radar = json['radar'];
    final past = radar is Map ? radar['past'] : null;
    final frames = <RadarFrame>[];
    if (past is List) {
      for (final entry in past) {
        if (entry is Map) {
          final frame =
              RadarFrame.fromJson(Map<String, dynamic>.from(entry));
          if (frame.isValid) frames.add(frame);
        }
      }
    }
    frames.sort((a, b) => a.time.compareTo(b.time));
    return RadarFrames(host: host, frames: frames);
  }
}

/// Builds RainViewer tile URLs for one frame.
///
/// Tiles look like:
/// `https://tilecache.rainviewer.com/v2/radar/<hash>/256/{z}/{x}/{y}/2/1_1.png`
/// where `{z}/{x}/{y}` are the map tile coordinates. Color 2 is the
/// standard "Universal Blue" radar colors, `1_1` is smoothed tiles
/// with snow shown.
class RadarTileUrl {
  /// A URL template for flutter_map, with `{z}/{x}/{y}` placeholders.
  static String template({
    required String host,
    required RadarFrame frame,
    int color = 2,
    String options = '1_1',
  }) =>
      '$host${frame.path}/256/{z}/{x}/{y}/$color/$options.png';

  /// One concrete tile URL (used by tests and debugging).
  static String tile({
    required String host,
    required RadarFrame frame,
    required int z,
    required int x,
    required int y,
    int color = 2,
    String options = '1_1',
  }) =>
      '$host${frame.path}/256/$z/$x/$y/$color/$options.png';
}

/// Thrown when the radar list can't be loaded, with a plain-language reason.
class RadarException implements Exception {
  RadarException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// RainViewer free API — no key needed.
/// https://www.rainviewer.com/api.html
class RadarApi {
  RadarApi({http.Client? client}) : _client = client ?? http.Client();

  static const _mapsUrl =
      'https://api.rainviewer.com/public/weather-maps.json';

  final http.Client _client;

  /// Fetches the current radar frames (past snapshots, newest last).
  /// Throws [RadarException] with a plain-language message on any failure.
  Future<RadarFrames> fetchFrames() async {
    http.Response response;
    try {
      response = await _client
          .get(Uri.parse(_mapsUrl))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw RadarException(
        'Could not load the radar. Check your connection and try again.',
      );
    }
    if (response.statusCode != 200) {
      throw RadarException(
        'The radar service is having trouble. Try again in a bit.',
      );
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw RadarException(
          'The radar data looked wrong. Try again later.',
        );
      }
      final frames = RadarFrames.fromJson(decoded);
      if (frames.frames.isEmpty) {
        throw RadarException(
          'No radar images are available right now. Try again later.',
        );
      }
      return frames;
    } on RadarException {
      rethrow;
    } catch (_) {
      throw RadarException(
        'The radar data looked wrong. Try again later.',
      );
    }
  }
}
