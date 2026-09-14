import 'package:flutter_test/flutter_test.dart';
import 'package:loanx/domain/country_catalog.dart';
import 'package:loanx/service/plan_pricing.dart';

void main() {
  group('PlanPricingService', () {
    test(
      'keeps the INR catalogue price in INR and rounds it for display',
      () async {
        final price = await PlanPricingService().proPriceFor(
          CountryCatalog.byCode('IN'),
        );

        expect(price.currency, 'INR');
        expect(price.current, 400);
        expect(price.previous, 700);
        expect(price.isEstimate, isFalse);
      },
    );

    test('uses the native currency symbol and ISO code in labels', () async {
      final price = await PlanPricingService().proPriceFor(
        CountryCatalog.byCode('IN'),
      );

      expect(price.currentLabel, '₹400 (INR)');
    });
  });
}
