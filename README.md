# Chance of Bananas

Discover the weather in your city and plan your day correctly — a Flutter
weather app built to match the design from
[Flutter Awesome](https://flutterawesome.com/a-flutter-weather-app-that-discover-the-weather-in-your-city/amp/).

## Screens

| Screen | What it does |
| --- | --- |
| **Splash** | Blue → teal → yellow gradient, sun + cloud art, spinner while the first weather loads |
| **Onboarding** | "Weather App — Discover the weather in your city and plan your day correctly", blue arrow button (first launch only) |
| **Home** | "Weather" title, city search bar, colorful city cards (gradient follows the weather) — tap a card to open it, long-press to remove it, pull down to refresh |
| **City detail** | Full-screen gradient that changes with the weather, big 3D-style cloud art, huge temperature, feels-like, UV / wind / humidity stats, hourly strip, 7-day forecast — swipe sideways between cities |
| **Error** | Friendly "Opps!" screen with retry when nothing can load |

## How it works

- **Weather data: Open-Meteo** — free, no API key, no account:
  `api.open-meteo.com` (current + hourly + 7-day forecast, °F / mph).
- **City search: Open-Meteo geocoding** — free, no key.
- **GPS city name: BigDataCloud reverse geocode** — free, no key; falls back
  to "Current Location" if it can't resolve a name.
- **State:** `flutter_bloc` Cubit (like the original app's Bloc/cubit setup).
- **Saved cities** persist on the device (`shared_preferences`).
  First launch seeds Maui, San Diego, and Aswan (the cities from the design),
  plus your GPS city on top when location is available.

## Run it (WSL — same as the Nanatech app)

Flutter is **not** installed in the Muse VM, so this project has not been
compiled yet. Run these in WSL where Flutter is already set up:

```bash
cd ~/weather-app            # or wherever you copied the project
flutter pub get
flutter analyze             # static checks
flutter test                # unit tests (weather codes + date formats)
flutter run                 # run on a connected phone / emulator
flutter build apk --debug   # debug APK
```

## First run

- The app asks for **location permission** the first time it opens, so it can
  show your city's weather. If you deny it, the app still works with the
  saved cities — tap the pin button on the home screen to retry location.
- Location services (GPS) need to be on for the GPS city to appear.

## Notes

- Release builds are signed with the **debug key** for now
  (`android/app/build.gradle.kts`). Before publishing to the Play Store,
  add a real keystore (`key.properties`) and point the release signing config
  at it — same setup as the Nanatech app.
- App icon is a sun + cloud drawn for this app (Android mipmaps + iOS
  AppIcon + launch image are included).
- `Color.withOpacity` is used in a few places; newer Flutter versions may
  flag it as deprecated in `flutter analyze` — it's a warning only, the app
  still builds fine.
