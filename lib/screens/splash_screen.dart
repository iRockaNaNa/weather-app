import 'package:material_ui/material_ui.dart';

import '../models/weather_codes.dart';
import '../widgets/weather_art.dart';

/// First screen: blue → teal → yellow gradient, sun + cloud art, spinner.
/// Matches the design reference splash.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF4A90E2),
              Color(0xFF5BC8A8),
              Color(0xFFFFC93C),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              SizedBox(
                height: 320,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Positioned(
                      top: 0,
                      left: 40,
                      child: WeatherArt(
                        kind: WeatherArtKind.clearDay,
                        size: 190,
                      ),
                    ),
                    Positioned(
                      top: 90,
                      child: WeatherArt(
                        kind: WeatherArtKind.rain,
                        size: 280,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 3),
              const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
