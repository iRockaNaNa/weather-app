import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/weather_cubit.dart';
import '../cubit/weather_state.dart';
import '../models/weather.dart';
import '../models/weather_codes.dart';
import '../services/alerts_api.dart';
import '../services/premium.dart';
import '../services/purchase_service.dart';
import '../widgets/hourly_strip.dart';
import '../widgets/personality_line.dart';
import '../widgets/weather_art.dart';
import 'paywall_screen.dart';

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
                            color: Colors.white.withValues(alpha: 0.8),
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
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 20),
              PersonalityLine(data: data, color: Colors.white),
              _AlertsSection(data: data),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
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
              ValueListenableBuilder<bool>(
                valueListenable:
                    context.read<PurchaseService>().isPremium,
                builder: (context, isPremium, _) {
                  if (!isPremium) return _lockedForecastCard(context);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
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
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Text(
                            '${d.tempMin.round()}°',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
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
                  );
                },
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
                            : Colors.white.withValues(alpha: 0.45),
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

  /// Shown instead of the 10-day forecast for free users: a locked state
  /// with an upgrade prompt, never a blank area.
  Widget _lockedForecastCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(Icons.lock_outline, color: Colors.white, size: 32),
          const SizedBox(height: 8),
          const Text(
            '10-day forecast',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Premium unlocks the full 10-day forecast.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => PaywallScreen.open(
              context,
              context.read<PurchaseService>(),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1A1A2E),
            ),
            child: const Text('See Premium'),
          ),
        ],
      ),
    );
  }
}

/// Severe-weather alerts for this city (National Weather Service).
///
/// Free users see a locked card. Premium users with no active alerts
/// see nothing at all — alerts only appear when there is something
/// to warn about.
class _AlertsSection extends StatelessWidget {
  const _AlertsSection({required this.data});

  final WeatherData data;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: context.read<PurchaseService>().isPremium,
      builder: (context, isPremium, _) {
        if (PremiumRules.isAlertsLocked(isPremium: isPremium)) {
          return Column(
            children: [
              const SizedBox(height: 16),
              _lockedAlertsCard(context),
            ],
          );
        }
        if (data.alerts.isEmpty) return const SizedBox.shrink();
        return Column(
          children: [
            const SizedBox(height: 16),
            for (final alert in data.alerts) ...[
              _AlertCard(alert: alert),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }

  Widget _lockedAlertsCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.white, size: 32),
          const SizedBox(height: 8),
          const Text(
            'Severe weather alerts',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Premium unlocks official severe-weather alerts for this city.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => PaywallScreen.open(
              context,
              context.read<PurchaseService>(),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1A1A2E),
            ),
            child: const Text('See Premium'),
          ),
        ],
      ),
    );
  }
}

/// One alert: event name + expiry on top, tap to read the full text
/// and what to do.
class _AlertCard extends StatefulWidget {
  const _AlertCard({required this.alert});

  final WeatherAlert alert;

  @override
  State<_AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends State<_AlertCard> {
  bool _expanded = false;

  Color get _severityColor {
    switch (widget.alert.severity.toLowerCase()) {
      case 'extreme':
        return const Color(0xFFFF5252);
      case 'severe':
        return const Color(0xFFFF9800);
      case 'moderate':
        return const Color(0xFFFFC107);
      case 'minor':
        return const Color(0xFFFFEB3B);
      default:
        return Colors.white;
    }
  }

  String get _endsLabel {
    final expires = widget.alert.expires;
    if (expires == null) return '';
    final now = DateTime.now();
    final sameDay = expires.year == now.year &&
        expires.month == now.month &&
        expires.day == now.day;
    if (sameDay) return 'Ends ${DateFormats.hourLabel(expires)}';
    return 'Ends ${DateFormats.mediumDate(expires)} '
        '${DateFormats.hourLabel(expires)}';
  }

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _severityColor.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: _severityColor, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alert.event,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ],
            ),
            if (_endsLabel.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                _endsLabel,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                ),
              ),
            ],
            if (alert.headline.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                alert.headline,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                ),
              ),
            ],
            if (_expanded) ...[
              if (alert.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  alert.description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                  ),
                ),
              ],
              if (alert.instruction.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text(
                  'What to do:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  alert.instruction,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                  ),
                ),
              ],
              if (alert.area.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Areas: ${alert.area}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
