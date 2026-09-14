import 'package:flutter_test/flutter_test.dart';
import 'package:loanx/service/country_resolver.dart';

void main() {
  group('CountryResolver.resolveSignals', () {
    test('uses India only when every signal is unavailable', () {
      final result = CountryResolver.resolveSignals();
      expect(result.countryCode, 'IN');
      expect(result.score, 0);
    });

    test('IP has the strongest single vote', () {
      final result = CountryResolver.resolveSignals(
        ipCountry: 'GB',
        deviceCountry: 'IN',
        timezone: 'Asia/Kolkata',
      );
      expect(result.countryCode, 'GB');
      expect(result.score, 60);
    });

    test('independent device votes beat a conflicting IP vote', () {
      final result = CountryResolver.resolveSignals(
        ipCountry: 'US',
        networkCountry: 'in',
        simCountry: 'IN',
        deviceCountry: 'IN',
      );
      expect(result.countryCode, 'IN');
      expect(result.score, 125);
    });

    test('rejects malformed and unsupported country codes', () {
      final result = CountryResolver.resolveSignals(
        ipCountry: 'not-a-country',
        deviceCountry: 'ZZ',
      );
      expect(result.countryCode, 'IN');
      expect(result.votes, isEmpty);
    });

    test(
      'uses the surviving IP provider when others are unavailable',
      () async {
        final resolver = CountryResolver(
          platformSignals: () async => const {},
          ipCountries: () async => ['not-a-country', 'BD'],
        );
        expect((await resolver.resolve()).countryCode, 'BD');
      },
    );

    test('uses the majority country when IP providers disagree', () async {
      final resolver = CountryResolver(
        platformSignals: () async => const {},
        ipCountries: () async => ['US', 'IN', 'IN'],
      );
      expect((await resolver.resolve()).countryCode, 'IN');
    });
  });
}
