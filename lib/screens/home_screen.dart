import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import '../cubit/weather_cubit.dart';
import '../cubit/weather_state.dart';
import '../models/weather.dart';
import '../widgets/city_card.dart';
import 'city_detail_screen.dart';

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
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
                      IconButton(
                        onPressed: () =>
                            context.read<WeatherCubit>().retryLocation(),
                        icon: const Icon(Icons.my_location),
                        color: const Color(0xFF2B5FA8),
                        tooltip: 'Use my location',
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
                      itemCount: cities.length,
                      itemBuilder: (context, index) {
                        final data = cities[index];
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
    );
  }
}
