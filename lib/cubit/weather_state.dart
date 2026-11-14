import 'package:equatable/equatable.dart';

import '../models/weather.dart';

sealed class WeatherState extends Equatable {
  const WeatherState();

  @override
  List<Object?> get props => [];
}

/// Nothing loaded yet.
class WeatherInitial extends WeatherState {
  const WeatherInitial();
}

/// Loading the first batch of weather.
class WeatherLoading extends WeatherState {
  const WeatherLoading();
}

/// Weather ready for every city.
class WeatherLoaded extends WeatherState {
  const WeatherLoaded({
    required this.cities,
    required this.locationAvailable,
  });

  /// One entry per city, GPS city first when available.
  final List<WeatherData> cities;

  /// False when GPS was unavailable — only saved cities are shown.
  final bool locationAvailable;

  @override
  List<Object?> get props => [cities, locationAvailable];
}

/// Nothing could be loaded at all.
class WeatherError extends WeatherState {
  const WeatherError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
