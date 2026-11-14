import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/weather_cubit.dart';
import '../cubit/weather_state.dart';
import '../services/personality.dart';
import '../services/purchase_service.dart';
import 'paywall_screen.dart';

/// Settings: Premium state plus the weather personality (Premium only).
///
/// Free users see the personality section as a locked card with an
/// upgrade prompt, same pattern as the locked forecast and radar.
/// Premium users get the "Snarky weather dialogue" toggle and, when it
/// is on, the personality picker with a live preview.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final purchaseService = context.read<PurchaseService>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const _PremiumRow(),
            const SizedBox(height: 20),
            const Text(
              'Weather personality',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<bool>(
              valueListenable: purchaseService.isPremium,
              builder: (context, isPremium, _) {
                if (!isPremium) return const _LockedPersonalityCard();
                return const _PersonalityControls();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows "You're Premium" for Premium users, otherwise a button that
/// opens the paywall.
class _PremiumRow extends StatelessWidget {
  const _PremiumRow();

  @override
  Widget build(BuildContext context) {
    final service = context.read<PurchaseService>();
    return ValueListenableBuilder<bool>(
      valueListenable: service.isPremium,
      builder: (context, isPremium, _) {
        if (isPremium) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E6),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              children: [
                Icon(Icons.star, color: Color(0xFFF59E0B), size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "You're Premium",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      Text(
                        'All features unlocked.',
                        style:
                            TextStyle(fontSize: 14, color: Color(0xFF555555)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => PaywallScreen.open(context, service),
            icon: const Icon(Icons.star_outline, size: 18),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('Get Premium', style: TextStyle(fontSize: 16)),
            ),
          ),
        );
      },
    );
  }
}

/// The dialogue toggle + personality picker, for Premium users only.
class _PersonalityControls extends StatelessWidget {
  const _PersonalityControls();

  @override
  Widget build(BuildContext context) {
    final settings = context.read<PersonalitySettings>();
    return ValueListenableBuilder<PersonalityPrefs>(
      valueListenable: settings.prefs,
      builder: (context, prefs, _) {
        final enabled = prefs.dialogueEnabled ?? true;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text('Snarky weather dialogue'),
              subtitle: const Text('Weather with a little attitude.'),
              value: enabled,
              onChanged: (value) => settings.setDialogueEnabled(value),
              contentPadding: EdgeInsets.zero,
            ),
            if (enabled) ...[
              const SizedBox(height: 4),
              const Text(
                'Personality',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              RadioGroup<Personality>(
                groupValue: prefs.personality,
                onChanged: (value) {
                  if (value != null) settings.setPersonality(value);
                },
                child: Column(
                  children: [
                    for (final personality in Personality.values)
                      RadioListTile<Personality>(
                        title: Text(personality.label),
                        subtitle: Text(personality.description),
                        value: personality,
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _PreviewLine(personality: prefs.personality),
            ],
          ],
        );
      },
    );
  }
}

/// A live preview of the chosen personality, using the GPS city's
/// current conditions when there is one, otherwise the first city.
class _PreviewLine extends StatelessWidget {
  const _PreviewLine({required this.personality});

  final Personality personality;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WeatherCubit, WeatherState>(
      builder: (context, state) {
        if (state is! WeatherLoaded || state.cities.isEmpty) {
          return const SizedBox.shrink();
        }
        final data = state.cities.firstWhere(
          (w) => w.city.isCurrentLocation,
          orElse: () => state.cities.first,
        );
        final line = PersonalityDialogue.lineFor(
          weatherCode: data.current.weatherCode,
          temperatureF: data.current.temperature,
          windSpeedMph: data.current.windSpeed,
          personality: personality,
          variant: PersonalityDialogue.dailyVariant(),
        );
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Preview',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF888888),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                line,
                style: const TextStyle(
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Shown instead of the personality controls for free users: a locked
/// state with an upgrade prompt, never a blank area.
class _LockedPersonalityCard extends StatelessWidget {
  const _LockedPersonalityCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Icon(Icons.lock_outline,
              size: 32, color: Color(0xFF2B5FA8)),
          const SizedBox(height: 8),
          const Text(
            'Snarky weather dialogue',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Premium unlocks weather with personality — snarky, friendly, '
            'or professional.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF555555)),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => PaywallScreen.open(
              context,
              context.read<PurchaseService>(),
            ),
            child: const Text('See Premium'),
          ),
        ],
      ),
    );
  }
}
