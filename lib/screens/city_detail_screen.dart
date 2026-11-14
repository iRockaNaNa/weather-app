import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/weather_cubit.dart';
import '../cubit/weather_state.dart';
import '../models/weather.dart';
import '../models/weather_codes.dart';
import '../widgets/hourly_strip.dart';
import '../widgets/weather_art.dart';

/// Full-screen detail for one city, swipable between cities.
/// Gradient background follows the weather, like the design reference.
class CityDetailScreen extends StatefulWidget {
  const CityDetailScreen({super.key, required this.initialIndex});

  final int initialIndex;

  @override
  State<CityDetailScreen> createState() => _CityDetailScreenState();
}

class _CityDetailScreenState extends State<CityDetailScreen> {
  late final PageController _pageController;
  late int _pageIndex;

  @override
  void initState() {
    super.initState();
    _pageIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WeatherCubit, WeatherState>(
      builder: (context, state) {
        if (state is! WeatherLoaded) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final cities = state.cities;
        final safeIndex = cities.isEmpty
            ? 0
            : _pageIndex.clamp(0, cities.length - 1).toInt();
        return Scaffold(
          body: PageView.builder(
            controller: _pageController,
            itemCount: cities.length,
            onPageChanged: (i) => setState(() => _pageIndex = i),
            itemBuilder: (context, index) {
              return _CityDetailPage(
                data: cities[index],
                pageIndex: index,
                pageCount: cities.length,
                currentPage: safeIndex,
              );
            },
          ),
        );
      },
    );
  }
}

class _CityDetailPage extends StatelessWidget {
  const _CityDetailPage({
    required this.data,
    required this.pageIndex,
    required this.pageCount,
    required this.currentPage,
  });

  final WeatherData data;
  final int pageIndex;
  final int pageCount;
  final int currentPage;

  @override
  Widget build(BuildContext context) {
    final style = styleForCode(
      data.current.weatherCode,
      data.current.isDay,
    );
    final today = DateTime.now();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: style.gradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    color: Colors.white,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          data.city.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          DateFormats.mediumDate(today),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 8),
              WeatherArt(kind: style.art, size: 240),
              Text(
                '${data.current.temperature.round()}°',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 104,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
              Text(
                style.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Feels like ${data.current.feelsLike.round()}°',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    StatCell(
                      icon: Icons.wb_sunny_outlined,
                      value: data.daily.isNotEmpty
                          ? data.daily.first.uvIndexMax
                              .toStringAsFixed(0)
                          : '—',
                      label: 'UV index',
                    ),
                    StatCell(
                      icon: Icons.air,
                      value:
                          '${data.current.windSpeed.toStringAsFixed(1)} m/h',
                      label: 'Wind',
                    ),
                    StatCell(
                      icon: Icons.water_drop_outlined,
                      value: '${data.current.humidity}%',
                      label: 'Humidity',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              HourlyStrip(hourly: data.hourly),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: data.daily.map((d) {
                    final dayStyle = styleForCode(d.weatherCode, true);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 64,
                            child: Text(
                              DateFormats.dayLabel(d.date, today),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          WeatherArt(kind: dayStyle.art, size: 30),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              shortLabelForCode(d.weatherCode),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Text(
                            '${d.tempMin.round()}°',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${d.tempMax.round()}°',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              if (pageCount > 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(pageCount, (i) {
                    final active = i == currentPage;
                    return Container(
                      width: active ? 22 : 9,
                      height: 9,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white
                            : Colors.white.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    );
                  }),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
