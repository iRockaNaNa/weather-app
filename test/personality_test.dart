import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_app/services/personality.dart';
import 'package:weather_app/services/premium.dart';

void main() {
  group('PersonalityDialogue — condition categories', () {
    test('storm codes win over everything', () {
      expect(
        PersonalityDialogue.categoryFor(
          weatherCode: 95,
          temperatureF: 95,
          windSpeedMph: 30,
        ),
        'storm',
      );
    });

    test('snow codes map to snow', () {
      expect(
        PersonalityDialogue.categoryFor(
          weatherCode: 71,
          temperatureF: 28,
          windSpeedMph: 5,
        ),
        'snow',
      );
    });

    test('rain and drizzle codes map to rain', () {
      for (final code in [51, 61, 63, 80, 82]) {
        expect(
          PersonalityDialogue.categoryFor(
            weatherCode: code,
            temperatureF: 60,
            windSpeedMph: 5,
          ),
          'rain',
        );
      }
    });

    test('fog codes map to fog', () {
      expect(
        PersonalityDialogue.categoryFor(
          weatherCode: 45,
          temperatureF: 55,
          windSpeedMph: 3,
        ),
        'fog',
      );
    });

    test('hot, cold, and windy come from temperature and wind', () {
      expect(
        PersonalityDialogue.categoryFor(
          weatherCode: 0,
          temperatureF: 95,
          windSpeedMph: 5,
        ),
        'hot',
      );
      expect(
        PersonalityDialogue.categoryFor(
          weatherCode: 0,
          temperatureF: 20,
          windSpeedMph: 5,
        ),
        'cold',
      );
      expect(
        PersonalityDialogue.categoryFor(
          weatherCode: 0,
          temperatureF: 60,
          windSpeedMph: 25,
        ),
        'windy',
      );
    });

    test('clear, partly, and overcast come from the sky code', () {
      expect(
        PersonalityDialogue.categoryFor(
          weatherCode: 0,
          temperatureF: 70,
          windSpeedMph: 5,
        ),
        'clear',
      );
      expect(
        PersonalityDialogue.categoryFor(
          weatherCode: 2,
          temperatureF: 70,
          windSpeedMph: 5,
        ),
        'partly',
      );
      expect(
        PersonalityDialogue.categoryFor(
          weatherCode: 3,
          temperatureF: 70,
          windSpeedMph: 5,
        ),
        'overcast',
      );
    });

    test('unknown codes fall back to cloudy', () {
      expect(
        PersonalityDialogue.categoryFor(
          weatherCode: 999,
          temperatureF: 70,
          windSpeedMph: 5,
        ),
        'cloudy',
      );
    });
  });

  group('PersonalityDialogue — lines', () {
    test('the line comes from the right pool for condition + personality',
        () {
      for (final personality in Personality.values) {
        final line = PersonalityDialogue.lineFor(
          weatherCode: 95,
          temperatureF: 70,
          windSpeedMph: 5,
          personality: personality,
        );
        // Pool lines carry {temp}/{wind} tokens, so compare against the
        // pool with the same values filled in.
        final filled =
            PersonalityDialogue.lines['storm']![personality]!.map((pool) => pool
                .replaceAll('{temp}', '70')
                .replaceAll('{wind}', '5'));
        expect(filled, contains(line));
      }
    });

    test('variants rotate through the pool instead of repeating', () {
      final seen = <String>{};
      for (var v = 0; v < 3; v++) {
        seen.add(PersonalityDialogue.lineFor(
          weatherCode: 0,
          temperatureF: 70,
          windSpeedMph: 5,
          personality: Personality.snarky,
          variant: v,
        ));
      }
      expect(seen.length, 3);
    });

    test('the variant wraps around past the end of the pool', () {
      final first = PersonalityDialogue.lineFor(
        weatherCode: 0,
        temperatureF: 70,
        windSpeedMph: 5,
        personality: Personality.snarky,
        variant: 0,
      );
      final wrapped = PersonalityDialogue.lineFor(
        weatherCode: 0,
        temperatureF: 70,
        windSpeedMph: 5,
        personality: Personality.snarky,
        variant: 3,
      );
      expect(wrapped, first);
    });

    test('professional lines include the real temperature', () {
      final line = PersonalityDialogue.lineFor(
        weatherCode: 0,
        temperatureF: 78,
        windSpeedMph: 5,
        personality: Personality.professional,
      );
      expect(line, contains('78'));
      expect(line, isNot(contains('{temp}')));
    });

    test('windy lines include the real wind speed', () {
      final line = PersonalityDialogue.lineFor(
        weatherCode: 0,
        temperatureF: 60,
        windSpeedMph: 25,
        personality: Personality.professional,
      );
      expect(line, contains('25'));
      expect(line, isNot(contains('{wind}')));
    });

    test('snarky lines stay clean — no profanity', () {
      const banned = ['damn', 'hell', 'crap', 'stupid', 'idiot', 'hate you'];
      for (final category in PersonalityDialogue.lines.keys) {
        for (final line in PersonalityDialogue.lines[category]![
            Personality.snarky]!) {
          for (final word in banned) {
            expect(line.toLowerCase(), isNot(contains(word)));
          }
        }
      }
    });

    test('every category has a line for every personality', () {
      for (final category in PersonalityDialogue.lines.keys) {
        for (final personality in Personality.values) {
          final pool =
              PersonalityDialogue.lines[category]![personality]!;
          expect(pool, isNotEmpty);
          for (final line in pool) {
            expect(line, isNotEmpty);
          }
        }
      }
    });

    test('dailyVariant changes day to day', () {
      expect(
        PersonalityDialogue.dailyVariant(DateTime(2026, 11, 14)),
        isNot(PersonalityDialogue.dailyVariant(DateTime(2026, 11, 15))),
      );
      expect(
        PersonalityDialogue.dailyVariant(DateTime(2026, 11, 14)),
        PersonalityDialogue.dailyVariant(DateTime(2026, 11, 14, 23, 59)),
      );
    });
  });

  group('PremiumRules — personality', () {
    test('dialogue is locked for free users', () {
      expect(
        PremiumRules.isPersonalityLocked(isPremium: false),
        isTrue,
      );
    });

    test('dialogue is open for Premium users', () {
      expect(
        PremiumRules.isPersonalityLocked(isPremium: true),
        isFalse,
      );
    });
  });

  group('PersonalitySettings — persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('dialogue defaults to ON for Premium, OFF for free', () async {
      final settings = PersonalitySettings();
      await settings.load();
      expect(settings.isEnabledFor(isPremium: true), isTrue);
      expect(settings.isEnabledFor(isPremium: false), isFalse);
    });

    test('personality defaults to Snarky', () async {
      final settings = PersonalitySettings();
      await settings.load();
      expect(settings.prefs.value.personality, Personality.snarky);
    });

    test('the toggle persists and overrides the default', () async {
      final settings = PersonalitySettings();
      await settings.load();
      await settings.setDialogueEnabled(false);
      expect(settings.isEnabledFor(isPremium: true), isFalse);
      // A fresh instance reads the saved value back.
      final reloaded = PersonalitySettings();
      await reloaded.load();
      expect(reloaded.isEnabledFor(isPremium: true), isFalse);
    });

    test('the personality persists and round-trips', () async {
      final settings = PersonalitySettings();
      await settings.load();
      await settings.setPersonality(Personality.friendly);
      expect(settings.prefs.value.personality, Personality.friendly);
      final reloaded = PersonalitySettings();
      await reloaded.load();
      expect(reloaded.prefs.value.personality, Personality.friendly);
    });

    test('an unknown stored personality falls back to Snarky', () {
      SharedPreferences.setMockInitialValues({
        'personality_style': 'mysterious',
      });
      final settings = PersonalitySettings();
      // load() reads the mock values synchronously enough for the
      // notifier to carry the fallback after the future completes.
      return settings.load().then((_) {
        expect(settings.prefs.value.personality, Personality.snarky);
      });
    });
  });
}
