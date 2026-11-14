import 'package:shared_preferences/shared_preferences.dart';

import '../models/weather.dart';

/// Saved cities + onboarding flag, kept on the device.
class CityStore {
  static const _citiesKey = 'saved_cities';
  static const _onboardingKey = 'onboarding_seen';

  /// Cities shown on first launch (same ones as the design reference).
  static const List<City> defaultCities = [
    City(
      id: '20.80_-156.33',
      name: 'Maui',
      country: 'United States',
      admin1: 'Hawaii',
      latitude: 20.7984,
      longitude: -156.3319,
    ),
    City(
      id: '32.72_-117.16',
      name: 'San Diego',
      country: 'United States',
      admin1: 'California',
      latitude: 32.7157,
      longitude: -117.1611,
    ),
    City(
      id: '24.09_32.90',
      name: 'Aswan',
      country: 'Egypt',
      admin1: 'Aswan',
      latitude: 24.0889,
      longitude: 32.8998,
    ),
  ];

  Future<List<City>> loadCities() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_citiesKey);
    if (raw == null || raw.isEmpty) return List.of(defaultCities);
    try {
      return DateFormats.cityListFromJson(raw);
    } catch (_) {
      return List.of(defaultCities);
    }
  }

  Future<void> saveCities(List<City> cities) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_citiesKey, DateFormats.cityListJson(cities));
  }

  Future<bool> onboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingKey) ?? false;
  }

  Future<void> markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
  }
}
