import 'package:flutter_test/flutter_test.dart';

import 'package:weather_app/services/purchase_service.dart';

void main() {
  group('PurchaseService debug unlock', () {
    testWidgets('test builds have Premium unlocked', (tester) async {
      // Flutter tests run with kDebugMode true, same as the CI debug
      // APKs — so constructing the service must leave Premium on. This
      // guards the unlock line; it says nothing about release builds,
      // where kDebugMode is false and Premium comes from a real purchase.
      // initialize() is deliberately NOT called here: it talks to the
      // store, and the store never answers in a test.
      final service = PurchaseService();
      expect(service.isPremium.value, isTrue);
    });
  });
}
