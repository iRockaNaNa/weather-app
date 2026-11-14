import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/weather.dart';
import '../services/personality.dart';
import '../services/purchase_service.dart';

/// One playful weather line under the current conditions, when the user
/// is Premium and has dialogue turned on. Free users, and anyone with the
/// toggle off, see nothing at all — not even an empty box.
class PersonalityLine extends StatelessWidget {
  const PersonalityLine({
    super.key,
    required this.data,
    this.color = const Color(0xFF1A1A2E),
  });

  /// The city whose current conditions the line describes.
  final WeatherData data;

  /// Text color: dark on the white Home screen, white on the Details
  /// screen's gradient.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final settings = context.read<PersonalitySettings>();
    return ValueListenableBuilder<bool>(
      valueListenable: context.read<PurchaseService>().isPremium,
      builder: (context, isPremium, _) {
        if (!isPremium) return const SizedBox.shrink();
        return ValueListenableBuilder<PersonalityPrefs>(
          valueListenable: settings.prefs,
          builder: (context, prefs, _) {
            if (!(prefs.dialogueEnabled ?? true)) {
              return const SizedBox.shrink();
            }
            final line = PersonalityDialogue.lineFor(
              weatherCode: data.current.weatherCode,
              temperatureF: data.current.temperature,
              windSpeedMph: data.current.windSpeed,
              personality: prefs.personality,
              variant: PersonalityDialogue.dailyVariant(),
            );
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                line,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                  color: color,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
