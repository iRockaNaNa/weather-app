import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the app talks about the weather.
///
/// Snarky is the Carrot-style one — playful sarcasm, always clean and
/// family-friendly (no profanity, no mean-spirited jabs). Friendly is warm
/// and upbeat. Professional is plain and factual.
enum Personality {
  snarky,
  friendly,
  professional,
}

extension PersonalityLabel on Personality {
  /// Short name shown in the settings picker.
  String get label {
    switch (this) {
      case Personality.snarky:
        return 'Snarky';
      case Personality.friendly:
        return 'Friendly';
      case Personality.professional:
        return 'Professional';
    }
  }

  /// One-line description shown under the picker option.
  String get description {
    switch (this) {
      case Personality.snarky:
        return 'Playful, sarcastic weather with attitude — always clean.';
      case Personality.friendly:
        return 'Warm, upbeat weather that cheers you on.';
      case Personality.professional:
        return 'Plain, factual weather. Just the facts.';
    }
  }

  /// Reads a stored personality name; anything unknown falls back to
  /// Snarky, the default.
  static Personality fromStorage(String? value) {
    for (final p in Personality.values) {
      if (p.name == value) return p;
    }
    return Personality.snarky;
  }
}

/// Picks one short weather commentary line for the current conditions.
///
/// Lines are keyed by condition category (clear, rain, snow, storm, hot,
/// cold, windy, fog, and so on) and by personality. [variant] rotates
/// through the small pool for a category so the same weather doesn't
/// always get the same line — the app passes a different variant each
/// day. `{temp}` and `{wind}` in a line are replaced with the rounded
/// temperature (°F) and wind speed (mph).
class PersonalityDialogue {
  /// The line pools, keyed by condition category, then personality.
  ///
  /// Public so tests can check a returned line belongs to the right pool.
  static const Map<String, Map<Personality, List<String>>> lines = {
    'clear': {
      Personality.snarky: [
        'Clear skies. The sun is out and showing off again.',
        'Not a cloud in the sky. Suspiciously perfect — enjoy it before I change my mind.',
        'Sunny and clear. Your sunglasses called — they want to go outside.',
      ],
      Personality.friendly: [
        'A beautiful clear day — perfect for getting outside!',
        'Blue skies all day. Couldn’t ask for better weather!',
      ],
      Personality.professional: [
        'Clear skies with a temperature of {temp}°F.',
        'Sunny and clear. Temperature {temp}°F.',
      ],
    },
    'partly': {
      Personality.snarky: [
        'Partly cloudy. The sun is playing peekaboo with the clouds.',
        'Sun and clouds, taking turns. The sky can’t commit today.',
        'Partly cloudy — the sun is in, the sun is out, the sun is in…',
      ],
      Personality.friendly: [
        'A mix of sun and clouds — a lovely day either way.',
        'Partly cloudy with plenty of sunshine peeking through.',
      ],
      Personality.professional: [
        'Partly cloudy. Temperature {temp}°F.',
        'Intervals of sun and cloud. Temperature {temp}°F.',
      ],
    },
    'overcast': {
      Personality.snarky: [
        'Overcast. The sky is wearing grey today. Very 2026.',
        'Cloudy and grey. The sun is on break — no return time posted.',
        'Solid cloud cover. The sun has left the chat.',
      ],
      Personality.friendly: [
        'Cloudy skies today, but still a good day to be out.',
        'Overcast and calm — a cozy kind of day.',
      ],
      Personality.professional: [
        'Overcast. Temperature {temp}°F.',
        'Cloudy skies with a temperature of {temp}°F.',
      ],
    },
    'fog': {
      Personality.snarky: [
        'Foggy. The world is on low-visibility mode.',
        'So foggy, the horizon filed a missing persons report.',
        'Fog. Driving? Maybe wait until the world finishes rendering.',
      ],
      Personality.friendly: [
        'Foggy this morning — take it slow and enjoy the quiet.',
        'A soft, foggy day. The world looks a little dreamy.',
      ],
      Personality.professional: [
        'Fog with reduced visibility. Temperature {temp}°F.',
        'Foggy conditions. Drive with care. Temperature {temp}°F.',
      ],
    },
    'rain': {
      Personality.snarky: [
        'It’s raining. The sky is crying, probably because it saw your plans.',
        'Rain. Perfect weather for staying in and judging everyone who went out.',
        'Wet out there. The ducks are thrilled. You? Less so.',
      ],
      Personality.friendly: [
        'Rainy day — a great excuse for a cozy day in.',
        'Rain is falling, the plants are happy. Grab an umbrella!',
      ],
      Personality.professional: [
        'Rain expected. Temperature {temp}°F.',
        'Rainy conditions. Temperature {temp}°F.',
      ],
    },
    'snow': {
      Personality.snarky: [
        'Snow! The world is a snow globe and you live inside it.',
        'It’s snowing. Build a snowman. Name it after me.',
        'Snow is falling and so is your motivation to go outside.',
      ],
      Personality.friendly: [
        'Snow is falling — a beautiful winter day!',
        'Snowy and magical. Bundle up and enjoy it.',
      ],
      Personality.professional: [
        'Snow expected. Temperature {temp}°F.',
        'Snowy conditions. Temperature {temp}°F.',
      ],
    },
    'storm': {
      Personality.snarky: [
        'Thunderstorm. The sky is doing its dramatic monologue again.',
        'Lightning out there. Stay inside — the sky is in a mood.',
        'Storms rolling through. Mother Nature is not taking questions today.',
      ],
      Personality.friendly: [
        'Storms are passing through — stay safe and dry indoors.',
        'A stormy day. Best enjoyed from a window with something warm.',
      ],
      Personality.professional: [
        'Thunderstorms in the area. Temperature {temp}°F.',
        'Storm activity expected. Take shelter when thunder roars.',
      ],
    },
    'hot': {
      Personality.snarky: [
        'It’s {temp}°F. The sun has declared war on shade.',
        'Hot enough to fry an egg on the sidewalk. Please don’t — the egg did nothing wrong.',
        'Scorching out there. Your car steering wheel is now a weapon.',
      ],
      Personality.friendly: [
        'A hot day — stay cool, drink water, and find some shade.',
        'Warm and sunny! Don’t forget the sunscreen.',
      ],
      Personality.professional: [
        'Hot conditions. Temperature {temp}°F.',
        'High temperatures near {temp}°F. Stay hydrated.',
      ],
    },
    'cold': {
      Personality.snarky: [
        'It’s {temp}°F. Your nose hairs called — they’re on strike.',
        'Cold enough to see your breath. Breathe out dramatically.',
        'Bitter cold. Even the penguins are wearing jackets.',
      ],
      Personality.friendly: [
        'A chilly day — bundle up and stay warm.',
        'Cold out there, but the air is crisp and fresh.',
      ],
      Personality.professional: [
        'Cold conditions. Temperature {temp}°F.',
        'Low temperatures near {temp}°F. Dress warmly.',
      ],
    },
    'windy': {
      Personality.snarky: [
        'Windy. Hold onto your hat. And your dignity.',
        'The wind is auditioning for a hurricane. It’s not ready yet.',
        'Gusty out there at {wind} mph. Your hair has left the chat.',
      ],
      Personality.friendly: [
        'A breezy day — great for kites, less great for hats.',
        'Windy with gusts near {wind} mph. Hold on tight!',
      ],
      Personality.professional: [
        'Windy conditions. Winds near {wind} mph.',
        'Gusty winds near {wind} mph. Temperature {temp}°F.',
      ],
    },
    'cloudy': {
      Personality.snarky: [
        'Cloudy. The clouds are just hanging around, doing nothing.',
        'Grey skies overhead. The sun is working from home today.',
        'Cloudy. Somewhere above all this, the sun is having a great day.',
      ],
      Personality.friendly: [
        'Cloudy skies, but the day is still yours.',
        'A cloudy day — soft light, easy weather.',
      ],
      Personality.professional: [
        'Cloudy. Temperature {temp}°F.',
        'Mostly cloudy. Temperature {temp}°F.',
      ],
    },
  };

  /// Which condition category these readings belong to.
  ///
  /// Severe weather wins first (storm, snow, rain, fog), then temperature
  /// and wind extremes, then the plain sky condition.
  static String categoryFor({
    required int weatherCode,
    required double temperatureF,
    required double windSpeedMph,
  }) {
    switch (weatherCode) {
      case 95:
      case 96:
      case 99:
        return 'storm';
      case 71:
      case 73:
      case 75:
      case 77:
      case 85:
      case 86:
        return 'snow';
      case 51:
      case 53:
      case 55:
      case 56:
      case 57:
      case 61:
      case 63:
      case 65:
      case 66:
      case 67:
      case 80:
      case 81:
      case 82:
        return 'rain';
      case 45:
      case 48:
        return 'fog';
      default:
        break;
    }
    if (temperatureF >= 90) return 'hot';
    if (temperatureF <= 32) return 'cold';
    if (windSpeedMph >= 20) return 'windy';
    switch (weatherCode) {
      case 0:
        return 'clear';
      case 1:
      case 2:
        return 'partly';
      case 3:
        return 'overcast';
      default:
        return 'cloudy';
    }
  }

  /// One line for these conditions, in this personality.
  ///
  /// [variant] rotates through the pool for the category; pass
  /// [dailyVariant] so the line changes day to day.
  static String lineFor({
    required int weatherCode,
    required double temperatureF,
    required double windSpeedMph,
    required Personality personality,
    int variant = 0,
  }) {
    final category = categoryFor(
      weatherCode: weatherCode,
      temperatureF: temperatureF,
      windSpeedMph: windSpeedMph,
    );
    final pool = lines[category]?[personality] ??
        lines['cloudy']![personality]!;
    final line = pool[variant % pool.length];
    return line
        .replaceAll('{temp}', temperatureF.round().toString())
        .replaceAll('{wind}', windSpeedMph.round().toString());
  }

  /// A variant that changes once a day, so the same weather gets a
  /// different line tomorrow.
  static int dailyVariant([DateTime? now]) {
    final date = now ?? DateTime.now();
    return date.difference(DateTime(date.year)).inDays;
  }
}

/// The user's personality choices, kept on the device.
///
/// The dialogue toggle has no stored value until the user flips it: then
/// it defaults to ON for Premium users and OFF for everyone else (free
/// users never see dialogue lines at all). Personality defaults to Snarky.
class PersonalityPrefs {
  const PersonalityPrefs({
    this.dialogueEnabled,
    this.personality = Personality.snarky,
  });

  /// Null until the user has flipped the toggle.
  final bool? dialogueEnabled;

  final Personality personality;

  PersonalityPrefs copyWith({
    bool? dialogueEnabled,
    Personality? personality,
  }) =>
      PersonalityPrefs(
        dialogueEnabled: dialogueEnabled ?? this.dialogueEnabled,
        personality: personality ?? this.personality,
      );
}

class PersonalitySettings {
  static const _enabledKey = 'personality_dialogue_enabled';
  static const _personalityKey = 'personality_style';

  /// The current choices; widgets listen to this and rebuild on change.
  final ValueNotifier<PersonalityPrefs> prefs =
      ValueNotifier(const PersonalityPrefs());

  bool _loaded = false;

  /// Reads the saved choices once. Safe to call repeatedly; later calls
  /// are no-ops. Never throws — defaults stand on any failure.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final sp = await SharedPreferences.getInstance();
      prefs.value = PersonalityPrefs(
        dialogueEnabled: sp.getBool(_enabledKey),
        personality:
            PersonalityLabel.fromStorage(sp.getString(_personalityKey)),
      );
    } catch (_) {
      // Defaults stand: dialogue on for Premium, off for free.
    }
  }

  /// Saves the toggle and updates listeners right away.
  Future<void> setDialogueEnabled(bool value) async {
    prefs.value = prefs.value.copyWith(dialogueEnabled: value);
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(_enabledKey, value);
    } catch (_) {
      // In-memory value still stands for this session.
    }
  }

  /// Saves the personality and updates listeners right away.
  Future<void> setPersonality(Personality value) async {
    prefs.value = prefs.value.copyWith(personality: value);
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_personalityKey, value.name);
    } catch (_) {
      // In-memory value still stands for this session.
    }
  }

  /// Should dialogue lines show for this user? Free users never get them.
  bool isEnabledFor({required bool isPremium}) {
    if (!isPremium) return false;
    return prefs.value.dialogueEnabled ?? true;
  }

  void dispose() => prefs.dispose();
}
