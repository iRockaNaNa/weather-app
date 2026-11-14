import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'premium.dart';

/// Talks to the Play Store about Premium and remembers the answer.
///
/// Two products, same unlock either way:
/// - [PremiumRules.monthlyProductId]: $0.99/month subscription. The 7-day
///   free trial lives on the subscription in Google Play Console; when the
///   store returns several offers for it, buying uses the free-trial offer
///   so the user actually gets the trial.
/// - [PremiumRules.lifetimeProductId]: $10 one-time purchase.
///
/// Until those products exist in Play Console (no Play account yet, app not
/// on the store), [productsReady] stays false and the paywall shows
/// "Premium is coming soon" instead of broken buy buttons. The free app
/// keeps working fully either way.
///
/// Entitlement is saved on the device, so a paying user stays Premium when
/// the store can't be reached. With no saved purchase and no store
/// confirmation, the user is on the free tier.
class PurchaseService {
  PurchaseService({InAppPurchase? store})
      : _store = store ?? InAppPurchase.instance;

  final InAppPurchase _store;

  static const _entitlementKey = 'premium_entitlement';

  /// True when this device owns Premium (from a purchase, a restore, or a
  /// saved entitlement from an earlier purchase).
  final ValueNotifier<bool> isPremium = ValueNotifier<bool>(false);

  /// True when the store answered and both products were found. False
  /// while loading, when the store is unavailable, or when the products
  /// don't exist in Play Console yet.
  final ValueNotifier<bool> productsReady = ValueNotifier<bool>(false);

  /// True while a purchase is going through the store sheet.
  final ValueNotifier<bool> purchaseInProgress = ValueNotifier<bool>(false);

  /// Plain-words description of the last purchase problem, if any.
  final ValueNotifier<String?> lastError = ValueNotifier<String?>(null);

  /// Store price text for the monthly plan, e.g. "$0.99". Null until the
  /// products have loaded.
  String? monthlyPrice;

  /// Store price text for the lifetime license, e.g. "$10.00". Null until
  /// the products have loaded.
  String? lifetimePrice;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  Completer<bool>? _restoreCompleter;
  bool _initialized = false;

  /// Store product details, keyed by product id, once they have loaded.
  final Map<String, ProductDetails> _details = {};

  /// Sets up the store connection. Never throws — any failure just leaves
  /// the app on the free tier with [productsReady] false.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _loadSavedEntitlement();

      _purchaseSubscription =
          _store.purchaseStream.listen(_onPurchases, onError: (_) {
        purchaseInProgress.value = false;
      });

      final available = await _store.isAvailable();
      if (!available) return;

      final response =
          await _store.queryProductDetails(PremiumRules.productIds);
      if (response.error != null) return;
      final found = {for (final p in response.productDetails) p.id};
      if (!PremiumRules.productIds.every(found.contains)) {
        // Products not in Play Console yet — Premium is coming soon.
        return;
      }
      _pickProducts(response.productDetails);
      productsReady.value = true;

      // Quietly refresh entitlement from the store (no prompt on Android).
      await _store.restorePurchases();
    } catch (_) {
      // Store problems never break the free app.
      purchaseInProgress.value = false;
    }
  }

  /// Starts the $0.99/month subscription (7-day free trial is on the
  /// subscription in Play Console). Returns false if the store couldn't
  /// start the purchase.
  Future<bool> buyMonthly() => _buy(PremiumRules.monthlyProductId);

  /// Starts the $10 one-time lifetime license. Returns false if the store
  /// couldn't start the purchase.
  Future<bool> buyLifetime() => _buy(PremiumRules.lifetimeProductId);

  Future<bool> _buy(String productId) async {
    lastError.value = null;
    if (!productsReady.value) return false;
    final details = _details[productId];
    if (details == null) return false;
    try {
      purchaseInProgress.value = true;
      final ok = await _store.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: details),
      );
      if (!ok) purchaseInProgress.value = false;
      return ok;
    } catch (_) {
      purchaseInProgress.value = false;
      lastError.value =
          'The store is not available right now. Please try again later.';
      return false;
    }
  }

  /// Re-asks the store what this device owns. Returns true when a Premium
  /// purchase was found, false when nothing was found (or the store didn't
  /// answer in time). Never throws.
  Future<bool> restorePurchases() async {
    lastError.value = null;
    if (isPremium.value) return true;
    if (_restoreCompleter != null) return _restoreCompleter!.future;
    final completer = Completer<bool>();
    _restoreCompleter = completer;
    try {
      await _store.restorePurchases();
    } catch (_) {
      _finishRestore(false);
      return false;
    }
    // The store answers through the purchase stream; give it a few seconds.
    Timer(const Duration(seconds: 8), () => _finishRestore(false));
    return completer.future;
  }

  void _finishRestore(bool found) {
    final completer = _restoreCompleter;
    _restoreCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(found);
    }
  }

  /// Picks which store entry to buy and which price to show.
  ///
  /// A subscription can come back as several entries — one per base plan
  /// and offer. Buying must use the entry whose first pricing phase is
  /// free ($0), so the user gets the 7-day trial; the price shown is the
  /// regular (non-free) price.
  void _pickProducts(List<ProductDetails> all) {
    ProductDetails? monthlyPaid;
    ProductDetails? monthlyTrial;
    ProductDetails? lifetime;
    for (final p in all) {
      if (p.id == PremiumRules.monthlyProductId) {
        if (_startsWithFreeTrial(p)) {
          monthlyTrial ??= p;
        } else {
          monthlyPaid ??= p;
        }
      } else if (p.id == PremiumRules.lifetimeProductId) {
        lifetime ??= p;
      }
    }
    final monthly = monthlyTrial ?? monthlyPaid;
    if (monthly != null) _details[PremiumRules.monthlyProductId] = monthly;
    if (lifetime != null) _details[PremiumRules.lifetimeProductId] = lifetime;
    monthlyPrice = (monthlyPaid ?? monthly)?.price;
    lifetimePrice = lifetime?.price;
  }

  /// True when this store entry's first pricing phase costs nothing — the
  /// 7-day free trial offer on Google Play.
  bool _startsWithFreeTrial(ProductDetails details) {
    if (details is! GooglePlayProductDetails) return false;
    final offers = details.productDetails.subscriptionOfferDetails;
    final index = details.subscriptionIndex;
    if (offers == null || index == null || index >= offers.length) {
      return false;
    }
    final phases = offers[index].pricingPhases;
    return phases.isNotEmpty && phases.first.priceAmountMicros == 0;
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    if (purchases.isEmpty) {
      _finishRestore(false);
      return;
    }
    for (final purchase in purchases) {
      if (!PremiumRules.productIds.contains(purchase.productID)) {
        continue;
      }
      switch (purchase.status) {
        case PurchaseStatus.pending:
          purchaseInProgress.value = true;
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _grantPremium(purchase.productID);
          purchaseInProgress.value = false;
          _finishRestore(true);
          break;
        case PurchaseStatus.error:
          purchaseInProgress.value = false;
          lastError.value = purchase.error?.message.isNotEmpty == true
              ? purchase.error!.message
              : 'The purchase did not go through. Please try again.';
          _finishRestore(false);
          break;
        case PurchaseStatus.canceled:
          purchaseInProgress.value = false;
          _finishRestore(false);
          break;
      }
      if (purchase.pendingCompletePurchase) {
        try {
          await _store.completePurchase(purchase);
        } catch (_) {
          // Acknowledgement can be retried by the store later.
        }
      }
    }
  }

  Future<void> _grantPremium(String productId) async {
    isPremium.value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _entitlementKey,
        jsonEncode(PremiumEntitlement(
          productId: productId,
          grantedAt: DateTime.now(),
        ).toJson()),
      );
    } catch (_) {
      // Staying Premium in memory is enough for this session.
    }
  }

  Future<void> _loadSavedEntitlement() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_entitlementKey);
      if (raw == null || raw.isEmpty) return;
      final entitlement = PremiumEntitlement.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      if (entitlement.isValid) {
        isPremium.value = true;
      }
    } catch (_) {
      // No saved purchase — free tier.
    }
  }

  void dispose() {
    _purchaseSubscription?.cancel();
    isPremium.dispose();
    productsReady.dispose();
    purchaseInProgress.dispose();
    lastError.dispose();
  }
}
