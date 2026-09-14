import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

    test(
      'uses the fallback API when the primary conversion API fails',
      () async {
        final requestedHosts = <String>[];
        final client = MockClient((request) async {
          requestedHosts.add(request.url.host);
          if (request.url.host == 'open.er-api.com') {
            return http.Response('service unavailable', 503);
          }
          if (request.url.host == 'cdn.jsdelivr.net') {
            return http.Response('{"inr":{"usd":0.012}}', 200);
          }
          return http.Response('not found', 404);
        });

        final price = await PlanPricingService(
          client: client,
        ).proPriceFor(CountryCatalog.byCode('US'));

        expect(requestedHosts, ['open.er-api.com', 'cdn.jsdelivr.net']);
        expect(price.currency, 'USD');
        expect(price.current, 5);
        expect(price.previous, 8);
        expect(price.isEstimate, isTrue);
      },
    );

    test('reports unavailable only after both conversion APIs fail', () async {
      final client = MockClient((_) async => http.Response('unavailable', 503));

      expect(
        PlanPricingService(
          client: client,
        ).proPriceFor(CountryCatalog.byCode('US')),
        throwsA(isA<PlanPricingUnavailable>()),
      );
    });
  });
}
