import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'cubit/weather_cubit.dart';
import 'cubit/weather_state.dart';
import 'screens/error_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'services/city_store.dart';
import 'services/location_service.dart';
import 'services/personality.dart';
import 'services/purchase_service.dart';
import 'services/weather_api.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final purchaseService = PurchaseService();
  final personalitySettings = PersonalitySettings();
  // Never blocks startup: any store failure just leaves the app free tier.
  unawaited(purchaseService.initialize());
  unawaited(personalitySettings.load());
  runApp(WeatherApp(
    purchaseService: purchaseService,
    personalitySettings: personalitySettings,
  ));
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({
    super.key,
    required this.purchaseService,
    required this.personalitySettings,
  });

  final PurchaseService purchaseService;
  final PersonalitySettings personalitySettings;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<PurchaseService>.value(value: purchaseService),
        RepositoryProvider<PersonalitySettings>.value(
            value: personalitySettings),
      ],
      child: BlocProvider(
        create: (_) => WeatherCubit(
          api: WeatherApi(),
          locationService: LocationService(),
          store: CityStore(),
        ),
        child: MaterialApp(
          title: 'Weather App',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2B5FA8),
            ),
          ),
          home: const AppRoot(),
        ),
      ),
    );
  }
}

/// Picks the right screen: splash while loading, error when nothing loaded,
/// onboarding on first launch, then the city list.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  final _store = CityStore();
  bool _onboardingSeen = false;
  bool _checkedOnboarding = false;

  @override
  void initState() {
    super.initState();
    _init();
    context.read<WeatherCubit>().loadAll();
  }

  Future<void> _init() async {
    final seen = await _store.onboardingSeen();
    if (mounted) {
      setState(() {
        _onboardingSeen = seen;
        _checkedOnboarding = true;
      });
    }
  }

  Future<void> _finishOnboarding() async {
    await _store.markOnboardingSeen();
    if (mounted) {
      setState(() => _onboardingSeen = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WeatherCubit, WeatherState>(
      builder: (context, state) {
        if (state is WeatherLoading ||
            state is WeatherInitial ||
            !_checkedOnboarding) {
          return const SplashScreen();
        }
        if (state is WeatherError) {
          return ErrorScreen(
            message: state.message,
            onRetry: () => context.read<WeatherCubit>().loadAll(),
          );
        }
        if (state is WeatherLoaded) {
          if (!_onboardingSeen) {
            return OnboardingScreen(onDone: _finishOnboarding);
          }
          return const HomeScreen();
        }
        return const SplashScreen();
      },
    );
  }
}
