import 'package:material_ui/material_ui.dart';

import '../services/purchase_service.dart';

/// Go Premium: the two ways to unlock Premium, in plain words.
///
/// - Monthly: $0.99 a month, first 7 days free. (The free trial is set up
///   on the subscription in Google Play Console, not in this code.)
/// - Lifetime: $10 once, yours forever.
///
/// Until the products exist in Play Console, the screen says "Premium is
/// coming soon" and shows no buy buttons — the free app keeps working.
class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key, required this.purchaseService});

  final PurchaseService purchaseService;

  static void open(BuildContext context, PurchaseService service) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaywallScreen(purchaseService: service),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = purchaseService;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Go Premium',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: ValueListenableBuilder<bool>(
          valueListenable: service.isPremium,
          builder: (context, isPremium, _) {
            if (isPremium) return _buildPremiumState(context);
            return _buildOffer(context, service);
          },
        ),
      ),
    );
  }

  Widget _buildPremiumState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              color: Color(0xFF2B5FA8),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.star, color: Colors.white, size: 44),
          ),
          const SizedBox(height: 20),
          const Text(
            "You're Premium!",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Thank you! You have unlimited cities, the full 10-day forecast, '
            'the live radar, snarky weather dialogue, and the home-screen '
            'widget.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Color(0xFF555555)),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text('Done', style: TextStyle(fontSize: 17)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOffer(BuildContext context, PurchaseService service) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Get the most out of your weather.',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Premium unlocks unlimited saved cities, the full 10-day forecast, '
            'the live radar, snarky weather dialogue, and the home-screen '
            'widget. '
            'Current weather and the hourly forecast stay free.',
            style: TextStyle(fontSize: 15, color: Color(0xFF555555)),
          ),
          const SizedBox(height: 20),
          ValueListenableBuilder<bool>(
            valueListenable: service.productsReady,
            builder: (context, productsReady, _) {
              if (!productsReady) return _buildComingSoon();
              return Column(
                children: [
                  _buildOptionCard(
                    context: context,
                    service: service,
                    title: 'Monthly',
                    price: service.monthlyPrice ?? '\$0.99',
                    priceSuffix: '/month',
                    points: const [
                      'First 7 days free',
                      'Then \$0.99 a month',
                      'Cancel anytime',
                    ],
                    buttonLabel: 'Start free trial',
                    onBuy: () => _buy(context, service, true),
                  ),
                  const SizedBox(height: 14),
                  _buildOptionCard(
                    context: context,
                    service: service,
                    title: 'Lifetime',
                    price: service.lifetimePrice ?? '\$10',
                    priceSuffix: 'once',
                    points: const [
                      'Pay once, yours forever',
                      'No monthly payments',
                      'Same Premium as monthly',
                    ],
                    buttonLabel: 'Buy lifetime',
                    onBuy: () => _buy(context, service, false),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<bool>(
            valueListenable: service.purchaseInProgress,
            builder: (context, inProgress, _) {
              if (!inProgress) return const SizedBox.shrink();
              return const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Text('Working with the store…'),
                  ],
                ),
              );
            },
          ),
          ValueListenableBuilder<String?>(
            valueListenable: service.lastError,
            builder: (context, error, _) {
              if (error == null || error.isEmpty) {
                return const SizedBox.shrink();
              }
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(error, style: const TextStyle(fontSize: 14)),
              );
            },
          ),
          Center(
            child: TextButton(
              onPressed: () => _restore(context, service),
              child: const Text('Restore purchases'),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Payments go through Google Play. No ads in this app, ever.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
          ),
        ],
      ),
    );
  }

  Widget _buildComingSoon() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [
          Icon(Icons.hourglass_top, size: 36, color: Color(0xFF2B5FA8)),
          SizedBox(height: 10),
          Text(
            'Premium is coming soon',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Premium is not in the store yet. Everything free keeps working — '
            'check back soon.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF555555)),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required PurchaseService service,
    required String title,
    required String price,
    required String priceSuffix,
    required List<String> points,
    required String buttonLabel,
    required VoidCallback onBuy,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF2B5FA8), width: 1.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                price,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                priceSuffix,
                style: const TextStyle(fontSize: 15, color: Color(0xFF555555)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final point in points)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.check,
                      size: 18, color: Color(0xFF2B5FA8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(point, style: const TextStyle(fontSize: 15)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          ValueListenableBuilder<bool>(
            valueListenable: service.purchaseInProgress,
            builder: (context, inProgress, _) {
              return SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: inProgress ? null : onBuy,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(buttonLabel,
                        style: const TextStyle(fontSize: 16)),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _buy(
      BuildContext context, PurchaseService service, bool monthly) async {
    final ok =
        monthly ? await service.buyMonthly() : await service.buyLifetime();
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Premium isn't available right now. Try again later."),
        ),
      );
    }
  }

  Future<void> _restore(
      BuildContext context, PurchaseService service) async {
    final found = await service.restorePurchases();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(found
            ? "Welcome back — you're Premium!"
            : 'Nothing to restore on this account.'),
      ),
    );
  }
}
