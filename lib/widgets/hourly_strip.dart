import 'package:material_ui/material_ui.dart';

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
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(24),
      ),
      // The strip sizes to its content (never shorter than the original
      // 96) instead of forcing a fixed height: with a larger system
      // font size the time/temp labels grow, and a fixed 96px box
      // overflowed with a RenderFlex "OVERFLOW" banner. A horizontal
      // SingleChildScrollView + Row sizes its height to the tallest
      // hour column, so the temps stay fully visible at any font scale.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 96),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (var i = 0; i < hours.length; i++) ...[
                if (i > 0) const SizedBox(width: 18),
                _HourItem(hour: hours[i], isNow: i == 0),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One hour in the strip: time label, mini art, temperature.
class _HourItem extends StatelessWidget {
  const _HourItem({required this.hour, required this.isNow});

  final HourlyPoint hour;
  final bool isNow;

  @override
  Widget build(BuildContext context) {
    final style = styleForCode(hour.weatherCode, true);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isNow ? 'Now' : DateFormats.hourLabel(hour.time),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        WeatherArt(kind: style.art, size: 40),
        const SizedBox(height: 6),
        Text(
          '${hour.temperature.round()}°',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
