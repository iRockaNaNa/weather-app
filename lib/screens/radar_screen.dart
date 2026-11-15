import 'dart:async';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../models/weather_codes.dart';
import '../services/purchase_service.dart';
import '../services/radar_api.dart';
import '../widgets/weather_art.dart';
import 'paywall_screen.dart';

/// Live radar map (RainViewer, free — no key needed).
///
/// Premium only: free users see a locked state with an upgrade prompt.
/// Shows recent radar frames over an OpenStreetMap base map, animating
/// through them with play/pause.
class RadarScreen extends StatefulWidget {
  const RadarScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.cityName,
    this.api,
  });

  final double latitude;
  final double longitude;
  final String cityName;

  /// Radar API to use — only the tests pass one (a mock client).
  /// The app always uses the real RainViewer API.
  final RadarApi? api;

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> {
  late final RadarApi _api;
  RadarFrames? _frames;
  // Starts false on purpose: the first load is triggered from build()
  // only when NOT already loading, so starting at true meant the load
  // never started — the spinner stayed up forever and the refresh
  // button was disabled too, so there was no way out.
  bool _loading = false;
  String? _error;
  int _frameIndex = 0;
  bool _playing = false;
  Timer? _timer;

  /// True once any radar tile has failed to load.
  bool _tilesFailed = false;

  /// True while a post-frame load/restart is already scheduled.
  bool _runScheduled = false;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? RadarApi();
    // Frames load lazily from build(): only Premium users get the radar,
    // so free users never trigger a network fetch.
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Makes sure the radar is loaded and animating — called from build()
  /// while the user is Premium. Schedules the work after the frame so
  /// build itself never triggers a setState. Only schedules when there
  /// is actually work to do.
  void _ensureRunning() {
    if (_runScheduled) return;
    final needsLoad = _frames == null && !_loading && _error == null;
    final needsRestart = _frames != null &&
        _frames!.frames.length > 1 &&
        _timer == null &&
        !_playing;
    if (!needsLoad && !needsRestart) return;
    _runScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runScheduled = false;
      if (!mounted) return;
      if (needsLoad) {
        _load();
      } else {
        _startAnimation();
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _tilesFailed = false;
    });
    _stopAnimation();
    try {
      final frames = await _api.fetchFrames();
      if (!mounted) return;
      setState(() {
        _frames = frames;
        _frameIndex = frames.frames.length - 1;
        _loading = false;
      });
      _startAnimation();
    } on RadarException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _startAnimation() {
    final frames = _frames;
    if (frames == null || frames.frames.length <= 1) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (!mounted) return;
      setState(() {
        _frameIndex = RadarFrames.nextIndex(
          _frameIndex,
          frames.frames.length,
        );
      });
    });
    setState(() => _playing = true);
  }

  void _stopAnimation() {
    // Only rebuild when something actually changed — the locked view
    // calls this after every frame, so an unconditional setState would
    // loop forever.
    final wasRunning = _timer != null || _playing;
    _timer?.cancel();
    _timer = null;
    if (wasRunning && mounted) setState(() => _playing = false);
  }

  void _togglePlay() {
    if (_playing) {
      _stopAnimation();
    } else {
      _startAnimation();
    }
  }

  void _onTileError() {
    if (!_tilesFailed && mounted) {
      setState(() => _tilesFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final frames = _frames;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        title: Text(
          'Radar — ${widget.cityName}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            color: const Color(0xFF2B5FA8),
            tooltip: 'Reload radar',
          ),
        ],
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: context.read<PurchaseService>().isPremium,
        builder: (context, isPremium, _) {
          if (!isPremium) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _stopAnimation());
            return _lockedRadarView(context);
          }
          _ensureRunning();
          if (_loading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading radar…'),
                ],
              ),
            );
          }
          if (_error != null) {
            return _RadarError(message: _error!, onRetry: _load);
          }
          if (frames == null || frames.frames.isEmpty) {
            return _RadarError(
              message:
                  'No radar images are available right now. Try again later.',
              onRetry: _load,
            );
          }
          return _buildMap(frames);
        },
      ),
    );
  }

  /// Shown instead of the map for free users: a locked state with an
  /// upgrade prompt, same pattern as the locked 10-day forecast.
  Widget _lockedRadarView(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              color: Color(0xFF2B5FA8),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outline,
              color: Colors.white,
              size: 44,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Live radar',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Premium unlocks the live radar map — watch rain move in real time.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Color(0xFF555555)),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => PaywallScreen.open(
                context,
                context.read<PurchaseService>(),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text('See Premium', style: TextStyle(fontSize: 17)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(RadarFrames frames) {
    final frame = frames.frames[_frameIndex];
    final radarTemplate = RadarTileUrl.template(
      host: frames.host,
      frame: frame,
    );
    return Column(
      children: [
        Expanded(
          child: FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(widget.latitude, widget.longitude),
              initialZoom: 7,
              minZoom: 3,
              maxZoom: 12,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:
                    'com.nanatechcreativestudios.weather',
              ),
              TileLayer(
                urlTemplate: radarTemplate,
                userAgentPackageName:
                    'com.nanatechcreativestudios.weather',
                errorTileCallback: (_, __, ___) => _onTileError(),
              ),
              RichAttributionWidget(
                attributions: const [
                  TextSourceAttribution(
                    '© OpenStreetMap contributors',
                  ),
                  TextSourceAttribution(
                    'Radar: RainViewer',
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_tilesFailed)
          Container(
            width: double.infinity,
            color: const Color(0xFFFFF7E6),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.cloud_off,
                  size: 18,
                  color: Color(0xFFB45309),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Some radar images aren\'t loading — check your connection.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                IconButton(
                  onPressed:
                      frames.frames.length > 1 ? _togglePlay : null,
                  icon: Icon(
                    _playing ? Icons.pause : Icons.play_arrow,
                  ),
                  color: const Color(0xFF2B5FA8),
                  tooltip: _playing ? 'Pause' : 'Play',
                ),
                Expanded(
                  child: Slider(
                    value: _frameIndex.toDouble(),
                    min: 0,
                    max: (frames.frames.length - 1).toDouble(),
                    divisions: frames.frames.length > 1
                        ? frames.frames.length - 1
                        : null,
                    onChanged: frames.frames.length > 1
                        ? (value) {
                            _stopAnimation();
                            setState(() {
                              _frameIndex = value.round();
                            });
                          }
                        : null,
                  ),
                ),
                Text(
                  frame.label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Friendly "Opps!" error view, matching the app's error screen.
class _RadarError extends StatelessWidget {
  const _RadarError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF6B8A), Color(0xFFE91E63)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Opps!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24),
              Stack(
                alignment: Alignment.center,
                children: [
                  WeatherArt(
                    kind: WeatherArtKind.cloudy,
                    size: 220,
                  ),
                  const Icon(
                    Icons.close,
                    color: Color(0xFFE91E63),
                    size: 64,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFE91E63),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Try again',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
