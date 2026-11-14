import 'package:flutter/material.dart';

/// Which kind of sky art to draw.
enum WeatherArtKind {
  clearDay,
  clearNight,
  partlyDay,
  partlyNight,
  cloudy,
  rain,
  snow,
  thunder,
  fog,
}

/// Look for one weather condition: label, background gradient, art.
class WeatherStyle {
  const WeatherStyle({
    required this.label,
    required this.gradient,
    required this.art,
  });

  final String label;
  final List<Color> gradient;
  final WeatherArtKind art;

  /// Card gradients on the city list use the same colors.
  List<Color> get cardGradient => gradient;
}

/// Maps a WMO weather code (+ day/night) to the design's look.
WeatherStyle styleForCode(int code, bool isDay) {
  switch (code) {
    case 0:
      // Clear sky.
      return WeatherStyle(
        label: isDay ? 'Clear' : 'Clear night',
        gradient: isDay
            ? const [Color(0xFFFFC93C), Color(0xFFFF9A3D)]
            : const [Color(0xFF3B2D8F), Color(0xFF1E1B4B)],
        art: isDay ? WeatherArtKind.clearDay : WeatherArtKind.clearNight,
      );
    case 1:
      // Mainly clear.
      return WeatherStyle(
        label: isDay ? 'Mainly clear' : 'Mainly clear',
        gradient: isDay
            ? const [Color(0xFF7ED0FF), Color(0xFFFFB347)]
            : const [Color(0xFF4B3A8F), Color(0xFF241D52)],
        art: isDay ? WeatherArtKind.partlyDay : WeatherArtKind.partlyNight,
      );
    case 2:
      // Partly cloudy.
      return WeatherStyle(
        label: 'Partly cloudy',
        gradient: isDay
            ? const [Color(0xFF5B8DEF), Color(0xFF8E6BEF)]
            : const [Color(0xFF4B3A8F), Color(0xFF241D52)],
        art: isDay ? WeatherArtKind.partlyDay : WeatherArtKind.partlyNight,
      );
    case 3:
      // Overcast.
      return const WeatherStyle(
        label: 'Overcast',
        gradient: [Color(0xFF6B7C93), Color(0xFF4A5A73)],
        art: WeatherArtKind.cloudy,
      );
    case 45:
    case 48:
      // Fog / depositing rime fog.
      return const WeatherStyle(
        label: 'Foggy',
        gradient: [Color(0xFF8A97A8), Color(0xFF5C6B7A)],
        art: WeatherArtKind.fog,
      );
    case 51:
    case 53:
    case 55:
    case 56:
    case 57:
      // Drizzle.
      return const WeatherStyle(
        label: 'Drizzle',
        gradient: [Color(0xFF5B7A99), Color(0xFF3E5A78)],
        art: WeatherArtKind.rain,
      );
    case 61:
    case 63:
    case 65:
    case 66:
    case 67:
    case 80:
    case 81:
    case 82:
      // Rain / rain showers.
      return const WeatherStyle(
        label: 'Rainy',
        gradient: [Color(0xFF4A90E2), Color(0xFF2B5FA8)],
        art: WeatherArtKind.rain,
      );
    case 71:
    case 73:
    case 75:
    case 77:
    case 85:
    case 86:
      // Snow.
      return const WeatherStyle(
        label: 'Snowy',
        gradient: [Color(0xFF38BDF8), Color(0xFF2563EB)],
        art: WeatherArtKind.snow,
      );
    case 95:
    case 96:
    case 99:
      // Thunderstorm.
      return const WeatherStyle(
        label: 'Thunderstorm',
        gradient: [Color(0xFF5B5B8A), Color(0xFF2E2E4D)],
        art: WeatherArtKind.thunder,
      );
    default:
      return const WeatherStyle(
        label: 'Cloudy',
        gradient: [Color(0xFF6B7C93), Color(0xFF4A5A73)],
        art: WeatherArtKind.cloudy,
      );
  }
}

/// Short label for a WMO code, used in the hourly strip.
String shortLabelForCode(int code) {
  switch (code) {
    case 0:
      return 'Clear';
    case 1:
    case 2:
      return 'Partly cloudy';
    case 3:
      return 'Overcast';
    case 45:
    case 48:
      return 'Fog';
    case 51:
    case 53:
    case 55:
    case 56:
    case 57:
      return 'Drizzle';
    case 61:
    case 63:
    case 65:
    case 66:
    case 67:
    case 80:
    case 81:
    case 82:
      return 'Rain';
    case 71:
    case 73:
    case 75:
    case 77:
    case 85:
    case 86:
      return 'Snow';
    case 95:
    case 96:
    case 99:
      return 'Storm';
    default:
      return 'Cloudy';
  }
}
