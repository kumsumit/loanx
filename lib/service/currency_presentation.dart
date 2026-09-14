import 'package:intl/intl.dart';
import 'package:loanx/db/app_settings.dart';
import 'package:loanx/domain/country_catalog.dart';

/// Country-aware presentation only. A loan retains its own ISO currency, so
/// changing a phone country or app language never reinterprets saved money.
abstract final class CurrencyPresentation {
  static CountryConfig get defaultCountry =>
      CountryCatalog.byCode(AppSettings.getVerifiedPhoneCountryCode());

  static String get defaultCurrency => defaultCountry.currency;

  static CountryConfig countryForCurrency(String currency) =>
      CountryCatalog.all.firstWhere(
        (country) => country.currency == currency,
        orElse: () => defaultCountry,
      );

  static int fractionDigits(String currency) => switch (currency) {
    'BHD' || 'IQD' || 'JOD' || 'KWD' || 'LYD' || 'OMR' || 'TND' => 3,
    'BIF' ||
    'CLP' ||
    'DJF' ||
    'GNF' ||
    'JPY' ||
    'KMF' ||
    'KRW' ||
    'PYG' ||
    'RWF' ||
    'UGX' ||
    'VND' ||
    'VUV' ||
    'XAF' ||
    'XOF' ||
    'XPF' => 0,
    _ => 2,
  };

  /// Uses the region customary for the currency, including Indian digit
  /// grouping for INR. ISO code is included for ambiguous symbols such as `$`.
  static NumberFormat formatter(String currency, {int? decimalDigits}) {
    final country = countryForCurrency(currency);
    final symbol = _ambiguousSymbols.contains(country.symbol)
        ? '$currency ${country.symbol}'
        : country.symbol;
    return NumberFormat.currency(
      locale: _localeByCurrency[currency] ?? 'en_US',
      symbol: symbol,
      decimalDigits: decimalDigits ?? fractionDigits(currency),
    );
  }

  static String format(num amount, String currency, {int? decimalDigits}) =>
      formatter(currency, decimalDigits: decimalDigits).format(amount);

  static const _ambiguousSymbols = <String>{r'$', '£', 'kr', 'Fr', 'Rs'};

  static const _localeByCurrency = <String, String>{
    'INR': 'en_IN',
    'USD': 'en_US',
    'EUR': 'de_DE',
    'GBP': 'en_GB',
    'BDT': 'bn_BD',
    'NPR': 'ne_NP',
    'PKR': 'ur_PK',
    'LKR': 'si_LK',
    'AED': 'ar_AE',
    'SAR': 'ar_SA',
    'JPY': 'ja_JP',
    'CNY': 'zh_CN',
    'KRW': 'ko_KR',
    'THB': 'th_TH',
    'IDR': 'id_ID',
    'MYR': 'ms_MY',
    'SGD': 'en_SG',
    'AUD': 'en_AU',
    'NZD': 'en_NZ',
    'CAD': 'en_CA',
    'CHF': 'de_CH',
    'BRL': 'pt_BR',
    'MXN': 'es_MX',
    'ZAR': 'en_ZA',
    'NGN': 'en_NG',
    'TRY': 'tr_TR',
    'RUB': 'ru_RU',
    'PLN': 'pl_PL',
    'SEK': 'sv_SE',
    'NOK': 'nb_NO',
    'DKK': 'da_DK',
  };
}
