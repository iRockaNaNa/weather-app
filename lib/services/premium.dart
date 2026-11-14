/// Premium rules for the Weather App — pure Dart, no store access.
///
/// Free tier: ONE location total — the GPS city when available, otherwise
/// one saved city — plus current conditions and the hourly forecast.
/// Premium covers ALL features: unlimited saved cities, the 10-day forecast,
/// the live radar, snarky weather dialogue, severe-weather alerts, widgets,
/// and anything added later.
///
/// Premium can be bought two ways, same unlock either way:
/// - `weather_premium_monthly`: $0.99/month subscription. The 7-day free
///   trial is configured on the subscription in Google Play Console —
///   there is no trial logic in this code.
/// - `weather_premium_lifetime`: $10 one-time purchase, yours forever.
///
/// There are NO ads in this app, ever.
class PremiumRules {
  /// Product id for the $0.99/month subscription.
  static const monthlyProductId = 'weather_premium_monthly';

  /// Product id for the $10 one-time lifetime license.
  static const lifetimeProductId = 'weather_premium_lifetime';

  /// Both product ids the store is asked about.
  static const productIds = {monthlyProductId, lifetimeProductId};

  /// How many locations a free user can have in total.
  /// The GPS city counts as the one location when it is available.
  static const freeCityLimit = 1;

  /// Can this user save one more city?
  /// [savedCityCount] counts saved cities only. [hasGpsCity] is true when
  /// the GPS city is showing — it counts as the one free location, so a
  /// free user with GPS already up can't add a saved city.
  static bool canAddCity({
    required int savedCityCount,
    required bool hasGpsCity,
    required bool isPremium,
  }) {
    if (isPremium) return true;
    final totalLocations = savedCityCount + (hasGpsCity ? 1 : 0);
    return totalLocations < freeCityLimit;
  }

  /// Is the 10-day forecast locked for this user?
  static bool isForecastLocked({required bool isPremium}) => !isPremium;

  /// Is the live radar locked for this user?
  static bool isRadarLocked({required bool isPremium}) => !isPremium;

  /// Is the snarky weather dialogue locked for this user?
  static bool isPersonalityLocked({required bool isPremium}) => !isPremium;

  /// Is the home-screen widget locked for this user?
  static bool isWidgetLocked({required bool isPremium}) => !isPremium;
}

/// A saved record that this device owns Premium.
///
/// Kept in SharedPreferences so a paying user stays Premium even when the
/// store can't be reached (offline, or the app isn't on the store yet).
/// A record only ever exists because a real purchase (or restore) created
/// it — with no record and no store confirmation, the user is free tier.
class PremiumEntitlement {
  const PremiumEntitlement({
    required this.productId,
    required this.grantedAt,
  });

  /// The product that granted Premium: one of [PremiumRules.productIds].
  final String productId;

  /// When the purchase (or restore) happened.
  final DateTime grantedAt;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'grantedAt': grantedAt.toIso8601String(),
      };

  factory PremiumEntitlement.fromJson(Map<String, dynamic> json) {
    final productId = json['productId'] as String? ?? '';
    final grantedAtRaw = json['grantedAt'] as String? ?? '';
    return PremiumEntitlement(
      productId: productId,
      grantedAt:
          DateTime.tryParse(grantedAtRaw) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  /// True only for a record that names one of our two products.
  bool get isValid => PremiumRules.productIds.contains(productId);
}
