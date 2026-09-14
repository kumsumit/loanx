import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:loanx/domain/country_catalog.dart';

/// A display-only estimate for the plan-selection screen.
///
/// The amount is deliberately not used to grant an entitlement or charge a
/// customer. A billing provider must supply the final purchasable price.
class PlanPrice {
  const PlanPrice({
    required this.currency,
    required this.symbol,
    required this.current,
    required this.previous,
    required this.isEstimate,
  });

  final String currency;
  final String symbol;
  final int current;
  final int previous;
  final bool isEstimate;

  String get currentLabel => _format(current);
  String get previousLabel => _format(previous);

  String _format(int amount) {
    final grouped = amount.toString().replaceAllMapped(
      RegExp(r'(?<!^)(?=(\d{3})+$)'),
      (_) => ',',
    );
    return '$symbol$grouped ($currency)';
  }
}

/// Converts the INR catalogue display price into the user's country currency.
///
/// Rates are fetched only to make the onboarding estimate relevant today. They
/// are not a pricing authority and are never persisted as a billing amount.
class PlanPricingService {
  PlanPricingService({http.Client? client}) : _client = client ?? http.Client();

  static const _catalogueCurrency = 'INR';
  static const _proCurrentInr = 399;
  static const _proPreviousInr = 699;

  final http.Client _client;

  Future<PlanPrice> proPriceFor(CountryConfig country) async {
    if (country.currency == _catalogueCurrency) {
      return _priceFor(country, 1, isEstimate: false);
    }

    try {
      final response = await _client
          .get(Uri.https('open.er-api.com', '/v6/latest/$_catalogueCurrency'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode != 200) throw const FormatException();
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) throw const FormatException();
      final rates = body['rates'];
      final rate = rates is Map ? rates[country.currency] : null;
      if (rate is! num || !rate.isFinite || rate <= 0) {
        throw const FormatException();
      }
      return _priceFor(country, rate.toDouble(), isEstimate: true);
    } catch (_) {
      throw const PlanPricingUnavailable();
    }
  }

  PlanPrice _priceFor(
    CountryConfig country,
    double rate, {
    required bool isEstimate,
  }) => PlanPrice(
    currency: country.currency,
    symbol: country.symbol,
    current: _roundForDisplay(_proCurrentInr * rate),
    previous: _roundForDisplay(_proPreviousInr * rate),
    isEstimate: isEstimate,
  );

  /// Marketing estimates should be easy to read, rather than exposing a
  /// volatile exchange-rate fraction (for example, 4.6372 USD).
  static int _roundForDisplay(double amount) {
    final increment = switch (amount) {
      >= 10000 => 100,
      >= 1000 => 100,
      >= 100 => 10,
      >= 10 => 5,
      _ => 1,
    };
    return (amount / increment).round() * increment;
  }
}

class PlanPricingUnavailable implements Exception {
  const PlanPricingUnavailable();
}
