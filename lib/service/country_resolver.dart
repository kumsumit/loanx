import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:loanx/domain/country_catalog.dart';

/// Country is only a convenience default for the phone field. It is never an
/// identity, residency, eligibility, or currency decision.
enum CountrySignal { ip, network, sim, deviceLocale, timezone }

class CountryResolution {
  const CountryResolution({
    required this.countryCode,
    required this.votes,
    required this.score,
  });

  final String countryCode;
  final Map<CountrySignal, String> votes;
  final int score;

  CountryConfig get country => CountryCatalog.byCode(countryCode);
}

/// Resolves a likely country from independent, non-sensitive country codes.
///
/// The IP lookup receives the request's IP at the lookup provider as any web
/// request does, but LoanX never obtains, persists, or sends the raw IP itself.
/// A failed lookup has no effect; the app remains fully usable offline.
class CountryResolver {
  CountryResolver({
    http.Client? client,
    Future<Map<Object?, Object?>?> Function()? platformSignals,
    this.ipCountries,
  }) : _client = client ?? http.Client(),
       _platformSignals =
           platformSignals ??
           (() => _channel.invokeMapMethod<Object?, Object?>('countrySignals'));

  static const _channel = MethodChannel('loanx');
  final http.Client _client;
  final Future<Map<Object?, Object?>?> Function() _platformSignals;

  /// Test seam and optional host override for IP-country providers.
  final Future<List<String>> Function()? ipCountries;

  Future<CountryResolution> resolve() async {
    final native = await _nativeSignals();
    final ipCountry = _chooseIpCountry(
      await (ipCountries ?? _lookupIpCountries)(),
    );
    return resolveSignals(
      ipCountry: ipCountry,
      networkCountry: native['networkCountry'] as String?,
      simCountry: native['simCountry'] as String?,
      deviceCountry:
          native['deviceCountry'] as String? ??
          PlatformDispatcher.instance.locale.countryCode,
      timezone: native['timezone'] as String? ?? DateTime.now().timeZoneName,
    );
  }

  Future<Map<Object?, Object?>> _nativeSignals() async {
    try {
      return await _platformSignals() ?? const {};
    } on PlatformException {
      return const {};
    } catch (_) {
      return const {};
    }
  }

  Future<List<String>> _lookupIpCountries() async {
    // Browsers commonly restrict cross-origin country lookup requests.
    if (kIsWeb) return const [];

    // These services use distinct operators and response formats. Requests are
    // parallel and short-lived so one unavailable provider cannot delay login.
    final results = await Future.wait([
      _plainCountry(Uri.https('ipapi.co', '/country/')),
      _jsonCountry(Uri.https('ipwho.is', '/'), 'country_code'),
      _jsonCountry(Uri.https('ipinfo.io', '/json'), 'country'),
      _cloudflareCountry(),
    ]);
    return results.whereType<String>().toList(growable: false);
  }

  Future<String?> _plainCountry(Uri uri) async {
    try {
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200 ? response.body.trim() : null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _jsonCountry(Uri uri, String field) async {
    try {
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 2));
      if (response.statusCode != 200) return null;
      final value = response.body;
      // The endpoints return small JSON documents. Avoid making their schema a
      // runtime dependency; only accept the exact country-code field.
      final match = RegExp(
        '"$field"\\s*:\\s*"([A-Za-z]{2})"',
      ).firstMatch(value);
      return match?.group(1);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _cloudflareCountry() async {
    try {
      final response = await _client
          .get(Uri.https('www.cloudflare.com', '/cdn-cgi/trace'))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode != 200) return null;
      return RegExp(
        r'^loc=([A-Za-z]{2})$',
        multiLine: true,
      ).firstMatch(response.body)?.group(1);
    } catch (_) {
      return null;
    }
  }

  static String? _chooseIpCountry(Iterable<String> countries) {
    final scores = <String, int>{};
    for (final candidate in countries) {
      final code = candidate.trim().toUpperCase();
      if (CountryCatalog.contains(code)) {
        scores.update(code, (score) => score + 1, ifAbsent: () => 1);
      }
    }
    if (scores.isEmpty) return null;
    final ordered = scores.entries.toList()
      ..sort((a, b) {
        final score = b.value.compareTo(a.value);
        return score != 0 ? score : a.key.compareTo(b.key);
      });
    return ordered.first.key;
  }

  /// Pure voting logic, deliberately public for deterministic unit tests.
  static CountryResolution resolveSignals({
    String? ipCountry,
    String? networkCountry,
    String? simCountry,
    String? deviceCountry,
    String? timezone,
  }) {
    final votes = <CountrySignal, String>{};
    void add(CountrySignal source, String? code) {
      final normalized = code?.trim().toUpperCase();
      if (normalized != null && CountryCatalog.contains(normalized)) {
        votes[source] = normalized;
      }
    }

    add(CountrySignal.ip, ipCountry);
    add(CountrySignal.network, networkCountry);
    add(CountrySignal.sim, simCountry);
    add(CountrySignal.deviceLocale, deviceCountry);
    add(CountrySignal.timezone, _singleCountryTimezone(timezone));

    const weights = {
      CountrySignal.ip: 60,
      CountrySignal.network: 50,
      CountrySignal.sim: 45,
      CountrySignal.deviceLocale: 30,
      CountrySignal.timezone: 10,
    };
    final scores = <String, int>{};
    for (final vote in votes.entries) {
      scores.update(
        vote.value,
        (score) => score + weights[vote.key]!,
        ifAbsent: () => weights[vote.key]!,
      );
    }
    if (scores.isEmpty) {
      return const CountryResolution(countryCode: 'IN', votes: {}, score: 0);
    }
    final ordered = scores.entries.toList()
      ..sort((a, b) {
        final score = b.value.compareTo(a.value);
        return score != 0 ? score : a.key.compareTo(b.key);
      });
    return CountryResolution(
      countryCode: ordered.first.key,
      votes: Map.unmodifiable(votes),
      score: ordered.first.value,
    );
  }

  static String? _singleCountryTimezone(String? timezone) => switch (timezone) {
    'Asia/Kolkata' => 'IN',
    'Asia/Dhaka' => 'BD',
    'Asia/Kathmandu' => 'NP',
    'Asia/Colombo' => 'LK',
    'Asia/Karachi' => 'PK',
    _ => null,
  };
}
