import 'package:flutter_test/flutter_test.dart';
import 'package:weather_app/services/premium.dart';

void main() {
  group('PremiumRules — one free location', () {
    test('free user with no GPS city can save one city', () {
      expect(
        PremiumRules.canAddCity(
          savedCityCount: 0,
          hasGpsCity: false,
          isPremium: false,
        ),
        isTrue,
      );
    });

    test('free user with one saved city cannot add a second', () {
      expect(
        PremiumRules.canAddCity(
          savedCityCount: 1,
          hasGpsCity: false,
          isPremium: false,
        ),
        isFalse,
      );
    });

    test('free user with the GPS city showing cannot add a saved city', () {
      expect(
        PremiumRules.canAddCity(
          savedCityCount: 0,
          hasGpsCity: true,
          isPremium: false,
        ),
        isFalse,
      );
    });

    test('Premium user can save unlimited cities', () {
      expect(
        PremiumRules.canAddCity(
          savedCityCount: 1,
          hasGpsCity: true,
          isPremium: true,
        ),
        isTrue,
      );
      expect(
        PremiumRules.canAddCity(
          savedCityCount: 50,
          hasGpsCity: false,
          isPremium: true,
        ),
        isTrue,
      );
    });

    test('the free limit is 1 location total', () {
      expect(PremiumRules.freeCityLimit, 1);
    });
  });

  group('PremiumRules — 10-day forecast', () {
    test('forecast is locked for free users', () {
      expect(
        PremiumRules.isForecastLocked(isPremium: false),
        isTrue,
      );
    });

    test('forecast is open for Premium users', () {
      expect(
        PremiumRules.isForecastLocked(isPremium: true),
        isFalse,
      );
    });
  });

  group('PremiumRules — live radar', () {
    test('radar is locked for free users', () {
      expect(
        PremiumRules.isRadarLocked(isPremium: false),
        isTrue,
      );
    });

    test('radar is open for Premium users', () {
      expect(
        PremiumRules.isRadarLocked(isPremium: true),
        isFalse,
      );
    });
  });

  group('PremiumRules — product ids', () {
    test('monthly and lifetime ids are the ones Play Console will use', () {
      expect(PremiumRules.monthlyProductId, 'weather_premium_monthly');
      expect(PremiumRules.lifetimeProductId, 'weather_premium_lifetime');
      expect(PremiumRules.productIds, {
        'weather_premium_monthly',
        'weather_premium_lifetime',
      });
    });
  });

  group('PremiumEntitlement', () {
    test('round-trips through JSON', () {
      final grantedAt = DateTime(2026, 11, 14, 12, 0);
      final entitlement = PremiumEntitlement(
        productId: 'weather_premium_lifetime',
        grantedAt: grantedAt,
      );
      final restored =
          PremiumEntitlement.fromJson(entitlement.toJson());
      expect(restored.productId, 'weather_premium_lifetime');
      expect(restored.grantedAt, grantedAt);
      expect(restored.isValid, isTrue);
    });

    test('an unknown product id is not valid', () {
      final entitlement = PremiumEntitlement(
        productId: 'something_else',
        grantedAt: DateTime.now(),
      );
      expect(entitlement.isValid, isFalse);
    });

    test('bad saved data does not crash and is not valid', () {
      final entitlement = PremiumEntitlement.fromJson({});
      expect(entitlement.isValid, isFalse);
    });
  });
}
