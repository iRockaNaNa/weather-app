import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../models/weather_codes.dart';

/// Chunky 3D-style weather illustration, drawn from widgets to match the
/// design reference (glossy cloud, big sun, rain drops, snow).
class WeatherArt extends StatelessWidget {
  const WeatherArt({
    super.key,
    required this.kind,
    required this.size,
  });

  final WeatherArtKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = size;
    switch (kind) {
      case WeatherArtKind.clearDay:
        return SizedBox(width: s, height: s, child: _Sun(size: s));
      case WeatherArtKind.clearNight:
        return SizedBox(width: s, height: s, child: _Moon(size: s));
      case WeatherArtKind.partlyDay:
        return SizedBox(
          width: s,
          height: s,
          child: Stack(
            children: [
              Positioned(
                left: s * 0.08,
                top: s * 0.02,
                child: _Sun(size: s * 0.55),
              ),
              Positioned(
                left: s * 0.22,
                top: s * 0.34,
                child: _Cloud(size: s * 0.72),
              ),
            ],
          ),
        );
      case WeatherArtKind.partlyNight:
        return SizedBox(
          width: s,
          height: s,
          child: Stack(
            children: [
              Positioned(
                left: s * 0.08,
                top: s * 0.02,
                child: _Moon(size: s * 0.5),
              ),
              Positioned(
                left: s * 0.22,
                top: s * 0.34,
                child: _Cloud(size: s * 0.72),
              ),
            ],
          ),
        );
      case WeatherArtKind.cloudy:
      case WeatherArtKind.fog:
        return SizedBox(
          width: s,
          height: s * 0.85,
          child: Center(child: _Cloud(size: s * 0.9)),
        );
      case WeatherArtKind.rain:
        return SizedBox(
          width: s,
          height: s,
          child: Stack(
            children: [
              Positioned(
                left: s * 0.05,
                top: s * 0.02,
                child: _Cloud(size: s * 0.85),
              ),
              Positioned(
                left: s * 0.22,
                top: s * 0.68,
                child: _Drops(size: s * 0.6),
              ),
            ],
          ),
        );
      case WeatherArtKind.snow:
        return SizedBox(
          width: s,
          height: s,
          child: Stack(
            children: [
              Positioned(
                left: s * 0.05,
                top: s * 0.02,
                child: _Cloud(size: s * 0.85),
              ),
              Positioned(
                left: s * 0.22,
                top: s * 0.68,
                child: _Snow(size: s * 0.6),
              ),
            ],
          ),
        );
      case WeatherArtKind.thunder:
        return SizedBox(
          width: s,
          height: s,
          child: Stack(
            children: [
              Positioned(
                left: s * 0.05,
                top: s * 0.0,
                child: _Cloud(size: s * 0.85),
              ),
              Positioned(
                left: s * 0.38,
                top: s * 0.62,
                child: _Bolt(size: s * 0.32),
              ),
            ],
          ),
        );
    }
  }
}

/// Yellow sun with rays.
class _Sun extends StatelessWidget {
  const _Sun({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final s = size;
    final center = s / 2;
    final rayLen = s * 0.13;
    final rayW = s * 0.055;
    final sunR = s * 0.30;
    final rays = <Widget>[];
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final dist = sunR + rayLen * 0.7;
      final x = center + math.cos(a) * dist - rayW / 2;
      final y = center + math.sin(a) * dist - rayLen / 2;
      rays.add(Positioned(
        left: x,
        top: y,
        child: Transform.rotate(
          angle: a + math.pi / 2,
          child: Container(
            width: rayW,
            height: rayLen,
            decoration: BoxDecoration(
              color: const Color(0xFFFFC93C),
              borderRadius: BorderRadius.circular(rayW / 2),
            ),
          ),
        ),
      ));
    }
    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        children: [
          ...rays,
          Center(
            child: Container(
              width: sunR * 2,
              height: sunR * 2,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0xFFFFE082), Color(0xFFFFC93C)],
                  stops: [0.4, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x55FFC93C),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pale moon with craters and a few stars.
class _Moon extends StatelessWidget {
  const _Moon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final s = size;
    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        children: [
          Positioned(
            left: s * 0.10,
            top: s * 0.08,
            child: _dot(s * 0.05, Colors.white70),
          ),
          Positioned(
            left: s * 0.82,
            top: s * 0.22,
            child: _dot(s * 0.04, Colors.white70),
          ),
          Positioned(
            left: s * 0.68,
            top: s * 0.04,
            child: _dot(s * 0.03, Colors.white54),
          ),
          Center(
            child: Container(
              width: s * 0.62,
              height: s * 0.62,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0xFFF3E8FF), Color(0xFFC9B8F5)],
                  stops: [0.5, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x44C9B8F5),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: s * 0.12,
                    top: s * 0.14,
                    child: _dot(s * 0.09, const Color(0xFFB9A6E8)),
                  ),
                  Positioned(
                    left: s * 0.28,
                    top: s * 0.32,
                    child: _dot(s * 0.06, const Color(0xFFB9A6E8)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(double d, Color c) => Container(
        width: d,
        height: d,
        decoration: BoxDecoration(shape: BoxShape.circle, color: c),
      );
}

/// Glossy white cloud made of overlapping circles.
class _Cloud extends StatelessWidget {
  const _Cloud({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final s = size;
    return SizedBox(
      width: s,
      height: s * 0.72,
      child: Stack(
        children: [
          // Soft shadow under the cloud.
          Positioned(
            left: s * 0.08,
            top: s * 0.58,
            child: Container(
              width: s * 0.84,
              height: s * 0.10,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(s * 0.05),
              ),
            ),
          ),
          // Base.
          Positioned(
            left: s * 0.04,
            top: s * 0.30,
            child: Container(
              width: s * 0.92,
              height: s * 0.30,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(s * 0.15),
              ),
            ),
          ),
          // Left bump.
          Positioned(
            left: s * 0.10,
            top: s * 0.12,
            child: _ball(s * 0.42),
          ),
          // Right bump.
          Positioned(
            left: s * 0.50,
            top: s * 0.06,
            child: _ball(s * 0.48),
          ),
          // Glossy highlight.
          Positioned(
            left: s * 0.16,
            top: s * 0.16,
            child: Container(
              width: s * 0.22,
              height: s * 0.12,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(s * 0.06),
              ),
            ),
          ),
          // Cool tint at the bottom edge.
          Positioned(
            left: s * 0.14,
            top: s * 0.50,
            child: Container(
              width: s * 0.72,
              height: s * 0.10,
              decoration: BoxDecoration(
                color: const Color(0xFFDCE9FF).withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(s * 0.05),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ball(double d) => Container(
        width: d,
        height: d,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
      );
}

/// Three blue raindrops.
class _Drops extends StatelessWidget {
  const _Drops({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final s = size;
    return SizedBox(
      width: s,
      height: s * 0.4,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _drop(s * 0.13, 0),
          _drop(s * 0.13, s * 0.06),
          _drop(s * 0.13, 0),
        ],
      ),
    );
  }

  Widget _drop(double d, double topPad) => Padding(
        padding: EdgeInsets.only(top: topPad),
        child: Container(
          width: d,
          height: d * 1.5,
          decoration: const BoxDecoration(
            color: Color(0xFF35A1FF),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(50),
              topRight: Radius.circular(50),
              bottomLeft: Radius.circular(50),
              bottomRight: Radius.circular(50),
            ),
          ),
        ),
      );
}

/// Three white snow dots.
class _Snow extends StatelessWidget {
  const _Snow({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final s = size;
    return SizedBox(
      width: s,
      height: s * 0.4,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _flake(s * 0.14, 0),
          _flake(s * 0.14, s * 0.07),
          _flake(s * 0.14, 0),
        ],
      ),
    );
  }

  Widget _flake(double d, double topPad) => Padding(
        padding: EdgeInsets.only(top: topPad),
        child: Container(
          width: d,
          height: d,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
        ),
      );
}

/// Yellow lightning bolt.
class _Bolt extends StatelessWidget {
  const _Bolt({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.4,
      child: CustomPaint(painter: _BoltPainter()),
    );
  }
}

class _BoltPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFD93C)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width * 0.62, 0)
      ..lineTo(size.width * 0.10, size.height * 0.58)
      ..lineTo(size.width * 0.45, size.height * 0.58)
      ..lineTo(size.width * 0.32, size.height)
      ..lineTo(size.width * 0.88, size.height * 0.42)
      ..lineTo(size.width * 0.52, size.height * 0.42)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
