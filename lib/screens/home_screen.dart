import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

import '../cubit/weather_cubit.dart';
import '../cubit/weather_state.dart';
import '../models/weather.dart';
import '../services/personality.dart';
import '../services/premium.dart';
import '../services/purchase_service.dart';
import '../services/widget_service.dart';
import '../widgets/city_card.dart';
import '../widgets/personality_line.dart';
import 'city_detail_screen.dart';
import 'paywall_screen.dart';
import 'radar_screen.dart';
import 'settings_screen.dart';

/// Home: "Weather" title, search bar, colorful city cards.
/// Long-press a card to remove that city.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  List<City> _searchResults = [];
  bool _searching = false;
  StreamSubscription<Uri?>? _widgetClickSub;
  late final ValueNotifier<bool> _isPremium;

  @override
  void initState() {
    super.initState();
    _isPremium = context.read<PurchaseService>().isPremium;
    _isPremium.addListener(_syncWidgetFromState);
    _widgetClickSub = WidgetService.widgetClicked.listen(_onWidgetTap);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncWidgetFromState();
      _checkWidgetLaunch();
    });
  }

  @override
  void dispose() {
    _widgetClickSub?.cancel();
    _isPremium.removeListener(_syncWidgetFromState);
    _searchController.dispose();
    super.dispose();
  }

  /// Pushes the current weather to the home-screen widget. Runs on every
  /// weather load/refresh and whenever Premium flips.
  Future<void> _syncWidget(WeatherLoaded state) async {
    final purchaseService = context.read<PurchaseService>();
    final settings = context.read<PersonalitySettings>();
    final gps = WidgetService.gpsDataOf(state);
    final isPremium = purchaseService.isPremium.value;
    await WidgetService().sync(
      gpsData: gps,
      isPremium: isPremium,
      dialogueLine: WidgetService.dialogueLineFor(
        gpsData: gps,
        settings: settings,
        isPremium: isPremium,
      ),
    );
  }

  void _syncWidgetFromState() {
    final state = context.read<WeatherCubit>().state;
    if (state is WeatherLoaded) {
      unawaited(_syncWidget(state));
    }
  }

  /// Did the app just launch from a widget tap?
  Future<void> _checkWidgetLaunch() async {
    final uri = await WidgetService.launchedFromWidget();
    if (mounted) _onWidgetTap(uri);
  }

  /// A tap on the locked widget opens the app straight to the paywall.
  /// Any other widget tap just opens the app.
  void _onWidgetTap(Uri? uri) {
    if (uri == null || !WidgetService.isPaywallTap(uri)) return;
    if (!mounted) return;
    final service = context.read<PurchaseService>();
    if (!service.isPremium.value) {
      PaywallScreen.open(context, service);
    }
  }

  Future<void> _runSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    final results =
        await context.read<WeatherCubit>().searchCities(query);
    if (!mounted) return;
    setState(() {
      _searching = false;
      _searchResults = results;
    });
  }

  Future<void> _openSearchedCity(City city) async {
    setState(() => _searchResults = []);
    _searchController.clear();
    final cubit = context.read<WeatherCubit>();
    final purchaseService = context.read<PurchaseService>();
    // Free tier: one location total. The GPS city counts as that one
    // location when it is showing, so a free user with GPS can't add a
    // saved city. A city that is already saved can always be opened.
    final stateBefore = cubit.state;
    if (stateBefore is WeatherLoaded) {
      final savedCount = stateBefore.cities
          .where((w) => !w.city.isCurrentLocation)
          .length;
      final hasGpsCity =
          stateBefore.cities.any((w) => w.city.isCurrentLocation);
      final alreadySaved =
          stateBefore.cities.any((w) => w.city.id == city.id);
      if (!alreadySaved &&
          !PremiumRules.canAddCity(
            savedCityCount: savedCount,
            hasGpsCity: hasGpsCity,
            isPremium: purchaseService.isPremium.value,
          )) {
        if (mounted) PaywallScreen.open(context, purchaseService);
        return;
      }
    }
    await cubit.addCity(city);
    if (!mounted) return;
    final state = cubit.state;
    if (state is WeatherLoaded) {
      final index =
          state.cities.indexWhere((w) => w.city.id == city.id);
      if (index >= 0) _openDetail(index);
    }
  }

  void _openDetail(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CityDetailScreen(initialIndex: index),
      ),
    );
  }

  /// Live radar, centered on the GPS city when there is one,
  /// otherwise on the first saved city. Free for everyone.
  void _openRadar(List<WeatherData> cities) {
    final gps = cities
        .where((w) => w.city.isCurrentLocation)
        .firstOrNull;
    final target = gps?.city ?? cities.first.city;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RadarScreen(
          latitude: target.latitude,
          longitude: target.longitude,
          cityName: target.displayName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: BlocListener<WeatherCubit, WeatherState>(
          // Every weather load/refresh pushes fresh data to the widget.
          listener: (context, state) {
            if (state is WeatherLoaded) unawaited(_syncWidget(state));
          },
          child: BlocBuilder<WeatherCubit, WeatherState>(
          builder: (context, state) {
            if (state is! WeatherLoaded) {
              return const Center(child: CircularProgressIndicator());
            }
            final cities = state.cities;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: [
                      const Text(
                        'Weather',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const Spacer(),
                      _PremiumButton(),
                      IconButton(
                        onPressed: () => _openRadar(cities),
                        icon: const Icon(Icons.radar),
                        color: const Color(0xFF2B5FA8),
                        tooltip: 'Live radar',
                      ),
                      IconButton(
                        onPressed: () =>
                            context.read<WeatherCubit>().retryLocation(),
                        icon: const Icon(Icons.my_location),
                        color: const Color(0xFF2B5FA8),
                        tooltip: 'Use my location',
                      ),
                      IconButton(
                        onPressed: () => SettingsScreen.open(context),
                        icon: const Icon(Icons.settings),
                        color: const Color(0xFF2B5FA8),
                        tooltip: 'Settings',
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _runSearch,
                    decoration: InputDecoration(
                      hintText: 'Search for a city...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final c = _searchResults[i];
                        return ListTile(
                          leading: const Icon(
                            Icons.location_on_outlined,
                            color: Color(0xFF2B5FA8),
                          ),
                          title: Text(c.name),
                          subtitle: Text(
                            [c.admin1, c.country]
                                .where((e) => e != null && e.isNotEmpty)
                                .join(', '),
                          ),
                          onTap: () => _openSearchedCity(c),
                        );
                      },
                    ),
                  ),
                if (!state.locationAvailable)
                  Container(
                    margin: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7E6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_off,
                          size: 18,
                          color: Color(0xFFB45309),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Location is off — showing saved cities.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            await Geolocator.openAppSettings();
                          },
                          child: const Text('Enable'),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () =>
                        context.read<WeatherCubit>().refresh(),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      // One extra slot for the dialogue line, shown right
                      // under the GPS city card (or the first card when
                      // there is no GPS city). The line itself renders
                      // nothing for free users or when the toggle is off.
                      itemCount: cities.length + 1,
                      itemBuilder: (context, index) {
                        final gpsIndex = cities.indexWhere(
                            (w) => w.city.isCurrentLocation);
                        final dialogueIndex = (gpsIndex >= 0 ? gpsIndex : 0) + 1;
                        if (index == dialogueIndex) {
                          return PersonalityLine(
                            data: cities[dialogueIndex - 1],
                          );
                        }
                        final data = cities[
                            index > dialogueIndex ? index - 1 : index];
                        return CityCard(
                          data: data,
                          onTap: () => _openDetail(index),
                          onLongPress: data.city.isCurrentLocation
                              ? null
                              : () async {
                                  await context
                                      .read<WeatherCubit>()
                                      .removeCity(data.city);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Removed ${data.city.name}'),
                                      ),
                                    );
                                  }
                                },
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
          ),
        ),
      ),
    );
  }
}

/// Header button: a gold star when Premium, otherwise an "Upgrade" button
/// that opens the paywall.
class _PremiumButton extends StatelessWidget {
  const _PremiumButton();

  @override
  Widget build(BuildContext context) {
    final service = context.read<PurchaseService>();
    return ValueListenableBuilder<bool>(
      valueListenable: service.isPremium,
      builder: (context, isPremium, _) {
        if (isPremium) {
          return const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(Icons.star, color: Color(0xFFF59E0B)),
          );
        }
        return FilledButton.tonalIcon(
          onPressed: () => PaywallScreen.open(context, service),
          icon: const Icon(Icons.star_outline, size: 18),
          label: const Text('Premium'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            minimumSize: const Size(0, 36),
          ),
        );
      },
    );
  }
}
