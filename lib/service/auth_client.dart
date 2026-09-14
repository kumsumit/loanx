import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:loanx/db/app_settings.dart';
import 'package:loanx/domain/country_catalog.dart';
import 'package:loanx/src/rust/api/network.dart' as network;

class AuthClient {
  AuthClient([this._storage = const FlutterSecureStorage()]);
  static const _address = String.fromEnvironment('LOANX_SERVER_ADDRESS');
  static const _name = String.fromEnvironment('LOANX_SERVER_NAME');
  static const _certificate64 = String.fromEnvironment(
    'LOANX_SERVER_CERTIFICATE_BASE64',
  );
  final FlutterSecureStorage _storage;
  static const _sessionKey = 'loanx.auth-session.v1';
  String? _challenge;
  String get _certificate {
    if (_address.isEmpty || _name.isEmpty || _certificate64.isEmpty) {
      throw StateError('LoanX server configuration is missing');
    }
    return utf8.decode(base64Decode(_certificate64));
  }

  Future<void> requestOtp(PhoneNumber phone) async {
    final result = await network.requestOtp(
      serverAddress: _address,
      serverName: _name,
      trustedCertificatePem: _certificate,
      deviceId: _deviceId(),
      phoneE164: _e164(phone),
    );
    if (!result.success) {
      throw StateError(result.errorMessage ?? 'OTP request failed');
    }
    _challenge = result.challengeId;
  }

  Future<bool> verifyOtp(PhoneNumber phone, String otp, String language) async {
    if (_challenge == null) throw StateError('OTP challenge is missing');
    final result = await network.verifyOtp(
      serverAddress: _address,
      serverName: _name,
      trustedCertificatePem: _certificate,
      deviceId: _deviceId(),
      challengeId: _challenge!,
      phoneE164: _e164(phone),
      otp: otp,
      preferredLanguage: language,
    );
    if (!result.success) return false;
    await _storeTokens(result.accessToken, result.refreshToken);
    _challenge = null;
    return true;
  }

  Future<void> updateLanguage(String language) async {
    final token = (await _readTokens())?.accessToken;
    if (token == null || token.isEmpty) return;
    final result = await network.updateLanguage(
      serverAddress: _address,
      serverName: _name,
      trustedCertificatePem: _certificate,
      deviceId: _deviceId(),
      accessToken: token,
      preferredLanguage: language,
    );
    if (!result.success) {
      throw StateError(result.errorMessage ?? 'Language update failed');
    }
  }

  Future<bool> restoreSession() async {
    final refreshToken = (await _readTokens())?.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final result = await network
          .refreshSession(
            serverAddress: _address,
            serverName: _name,
            trustedCertificatePem: _certificate,
            deviceId: _deviceId(),
            refreshToken: refreshToken,
          )
          .timeout(const Duration(seconds: 10));
      if (!result.success) {
        await clearLocalSession();
        return false;
      }
      await _storeTokens(result.accessToken, result.refreshToken);
      final pendingLanguage = AppSettings.getPendingPreferredLanguage();
      if (pendingLanguage.isNotEmpty) {
        try {
          await updateLanguage(pendingLanguage);
          AppSettings.putPendingPreferredLanguage('');
          await AppSettings.flush();
        } catch (_) {
          // Authentication is valid; preference sync can retry later.
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    final token = (await _readTokens())?.accessToken;
    if (token == null || token.isEmpty) {
      await clearLocalSession();
      return;
    }
    final result = await network.logoutSession(
      serverAddress: _address,
      serverName: _name,
      trustedCertificatePem: _certificate,
      deviceId: _deviceId(),
      accessToken: token,
    );
    if (!result.success) {
      throw StateError(result.errorMessage ?? 'Unable to revoke session');
    }
    await clearLocalSession();
  }

  Future<void> clearLocalSession() async {
    await _storage.delete(key: _sessionKey);
    // Remove pre-upgrade token records after migration or logout.
    await _storage.delete(key: 'loanx.access-token');
    await _storage.delete(key: 'loanx.refresh-token');
  }

  Future<void> _storeTokens(String accessToken, String refreshToken) async {
    final encoded = jsonEncode({
      'access_token': accessToken,
      'refresh_token': refreshToken,
    });
    await _storage.write(key: _sessionKey, value: encoded);
    await _storage.delete(key: 'loanx.access-token');
    await _storage.delete(key: 'loanx.refresh-token');
  }

  Future<_StoredTokens?> _readTokens() async {
    final encoded = await _storage.read(key: _sessionKey);
    if (encoded != null && encoded.isNotEmpty) {
      try {
        final value = jsonDecode(encoded) as Map<String, dynamic>;
        final access = value['access_token'] as String?;
        final refresh = value['refresh_token'] as String?;
        if (access != null && refresh != null) {
          return _StoredTokens(access, refresh);
        }
      } catch (_) {
        await clearLocalSession();
        return null;
      }
    }
    // One-time migration from the two-record implementation.
    final access = await _storage.read(key: 'loanx.access-token');
    final refresh = await _storage.read(key: 'loanx.refresh-token');
    if (access == null ||
        refresh == null ||
        access.isEmpty ||
        refresh.isEmpty) {
      return null;
    }
    await _storeTokens(access, refresh);
    return _StoredTokens(access, refresh);
  }

  String _deviceId() {
    var value = AppSettings.getDeviceId();
    if (value.isNotEmpty) return value;
    final random = Random.secure();
    value = base64UrlEncode(List.generate(24, (_) => random.nextInt(256)));
    AppSettings.putDeviceId(value);
    return value;
  }

  String _e164(PhoneNumber p) => CountryCatalog.e164(p.isoCode, p.nsn);
}

class _StoredTokens {
  const _StoredTokens(this.accessToken, this.refreshToken);
  final String accessToken;
  final String refreshToken;
}

AuthClient? activeAuthClient;
