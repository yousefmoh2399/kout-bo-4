import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_build_game/data/apple_iap_service.dart';

void main() {
  group('AppleIapProducts', () {
    test('verifies product identifiers and point mapping', () {
      expect(AppleIapProducts.allIds, contains('com.faisal.koutbo4.coins_1000'));
      expect(AppleIapProducts.allIds, contains('com.faisal.koutbo4.coins_5000'));
      expect(AppleIapProducts.allIds, contains('com.faisal.koutbo4.coins_15000'));
      expect(AppleIapProducts.allIds, contains('com.faisal.koutbo4.coins_50000'));

      expect(AppleIapProducts.coinsForProduct('com.faisal.koutbo4.coins_1000'), 1000);
      expect(AppleIapProducts.coinsForProduct('com.faisal.koutbo4.coins_5000'), 5500);
      expect(AppleIapProducts.coinsForProduct('com.faisal.koutbo4.coins_15000'), 17500);
      expect(AppleIapProducts.coinsForProduct('com.faisal.koutbo4.coins_50000'), 65000);
      expect(AppleIapProducts.coinsForProduct('com.koutbo4.coins_1000'), 1000);
      expect(AppleIapProducts.coinsForProduct('unknown'), 0);
    });

    test('validates Products.storekit configuration file', () {
      final file = File('ios/Runner/Products.storekit');
      expect(file.existsSync(), isTrue);

      final content = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final products = content['products'] as List;
      expect(products.length, 4);

      final ids = products.map((p) => p['productID']).toSet();
      expect(ids, contains('com.faisal.koutbo4.coins_1000'));
      expect(ids, contains('com.faisal.koutbo4.coins_5000'));
      expect(ids, contains('com.faisal.koutbo4.coins_15000'));
      expect(ids, contains('com.faisal.koutbo4.coins_50000'));

      for (final p in products) {
        expect(p['type'], equals('Consumable'));
        expect(p['displayPrice'], isNotNull);
        expect((p['localizations'] as List).isNotEmpty, isTrue);
      }
    });

    test('ApplePurchaseResult model captures data accurately', () {
      const res = ApplePurchaseResult(
        isSuccess: true,
        message: 'تم الشحن بنجاح',
        productId: 'com.faisal.koutbo4.coins_5000',
        transactionId: 'TX_12345',
        newBalance: 6500,
      );

      expect(res.isSuccess, isTrue);
      expect(res.productId, 'com.faisal.koutbo4.coins_5000');
      expect(res.transactionId, 'TX_12345');
      expect(res.newBalance, 6500);
    });
  });
}
