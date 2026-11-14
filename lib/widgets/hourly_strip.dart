import 'package:flutter/material.dart';

import '../models/weather.dart';
import '../models/weather_codes.dart';
import 'weather_art.dart';

/// Translucent card with the next hours: time, mini art, temperature.
class HourlyStrip extends StatelessWidget {
  const HourlyStrip({
    super.key,
    required this.hourly,
  });

  final List<HourlyPoint> hourly;

  @override
  Widget build(BuildContext context) {
    final hours = hourly.take(12).toList();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(24),
      ),
      child: SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: hours.length,
          separatorBuilder: (_, __) => const SizedBox(width: 18),
          itemBuilder: (context, index) {
            final h = hours[index];
            final style = styleForCode(h.weatherCode, true);
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  index == 0 ? 'Now' : DateFormats.hourLabel(h.time),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                WeatherArt(kind: style.art, size: 40),
                const SizedBox(height: 6),
                Text(
                  '${h.temperature.round()}°',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One stat in the detail stats card: icon + value + label.
class StatCell extends StatelessWidget {
  const StatCell({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 5),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.75),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
