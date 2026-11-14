import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/weather.dart';
import '../services/city_store.dart';
import '../services/location_service.dart';
import '../services/weather_api.dart';
import 'weather_state.dart';

/// Loads weather for the GPS city + saved cities, and keeps the list.
class WeatherCubit extends Cubit<WeatherState> {
  WeatherCubit({
    required WeatherApi api,
    required LocationService locationService,
    required CityStore store,
  })  : _api = api,
        _locationService = locationService,
        _store = store,
        super(const WeatherInitial());

  final WeatherApi _api;
  final LocationService _locationService;
  final CityStore _store;

  /// Saved (non-GPS) cities, kept so refreshes reuse the same list.
  List<City> _savedCities = [];

  /// Load everything: saved cities, then GPS city on top when available.
  Future<void> loadAll() async {
    emit(const WeatherLoading());
    _savedCities = await _store.loadCities();

    City? gpsCity;
    var locationAvailable = false;
    try {
      final pos = await _locationService.getCurrentPosition();
      final name = await _api.reverseGeocode(pos.latitude, pos.longitude);
      gpsCity = City(
        id: 'gps',
        name: name,
        country: '',
        latitude: pos.latitude,
        longitude: pos.longitude,
        isCurrentLocation: true,
      );
      locationAvailable = true;
    } catch (_) {
      // No GPS — saved cities still work.
      locationAvailable = false;
    }

    final cities = <City>[
      if (gpsCity != null) gpsCity,
      ..._savedCities,
    ];

    final loaded = await _fetchAll(cities);
    if (loaded.isEmpty) {
      emit(const WeatherError(
          'Could not load the weather. Check your connection and try again.'));
      return;
    }
    emit(WeatherLoaded(cities: loaded, locationAvailable: locationAvailable));
  }

  /// Refresh all weather, keeping the current city list.
  Future<void> refresh() async {
    final current = state;
    if (current is! WeatherLoaded) {
      await loadAll();
      return;
    }
    final cities = current.cities.map((w) => w.city).toList();
    final loaded = await _fetchAll(cities);
    if (loaded.isNotEmpty) {
      emit(WeatherLoaded(
        cities: loaded,
        locationAvailable: current.locationAvailable,
      ));
    }
  }

  /// Retry GPS only (used when the user enables location after the fact).
  Future<void> retryLocation() async {
    final current = state;
    if (current is! WeatherLoaded) {
      await loadAll();
      return;
    }
    try {
      final pos = await _locationService.getCurrentPosition();
      final name = await _api.reverseGeocode(pos.latitude, pos.longitude);
      final gpsCity = City(
        id: 'gps',
        name: name,
        country: '',
        latitude: pos.latitude,
        longitude: pos.longitude,
        isCurrentLocation: true,
      );
      final alreadyThere =
          current.cities.any((w) => w.city.isCurrentLocation);
      if (alreadyThere) return;
      final data = await _api.fetchWeather(gpsCity);
      emit(WeatherLoaded(
        cities: [data, ...current.cities],
        locationAvailable: true,
      ));
    } catch (_) {
      // Still no GPS — leave the list as it is.
    }
  }

  /// Search cities by name (Open-Meteo geocoding).
  Future<List<City>> searchCities(String query) =>
      _api.searchCities(query);

  /// Add a city from search results, fetch its weather, save the list.
  Future<void> addCity(City city) async {
    final current = state;
    if (current is! WeatherLoaded) return;
    if (current.cities.any((w) => w.city.id == city.id)) return;
    try {
      final data = await _api.fetchWeather(city);
      _savedCities = [..._savedCities, city];
      await _store.saveCities(_savedCities);
      emit(WeatherLoaded(
        cities: [...current.cities, data],
        locationAvailable: current.locationAvailable,
      ));
    } catch (_) {
      // Search result couldn't load — stay on the current list.
    }
  }

  /// Remove a saved city (the GPS city can't be removed).
  Future<void> removeCity(City city) async {
    final current = state;
    if (current is! WeatherLoaded) return;
    if (city.isCurrentLocation) return;
    _savedCities = _savedCities.where((c) => c.id != city.id).toList();
    await _store.saveCities(_savedCities);
    final remaining =
        current.cities.where((w) => w.city.id != city.id).toList();
    if (remaining.isEmpty) {
      emit(const WeatherError('No cities left. Add a city to see its weather.'));
      return;
    }
    emit(WeatherLoaded(
      cities: remaining,
      locationAvailable: current.locationAvailable,
    ));
  }

  Future<List<WeatherData>> _fetchAll(List<City> cities) async {
    final results = await Future.wait(
      cities.map((c) async {
        try {
          return await _api.fetchWeather(c);
        } catch (_) {
          return null;
        }
      }),
    );
    return results.whereType<WeatherData>().toList();
  }
}
