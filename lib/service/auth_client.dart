import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:loanx/db/app_settings.dart';
import 'package:loanx/db/tostore_database.dart';
import 'package:loanx/domain/country_catalog.dart';
import 'package:loanx/domain/money.dart';
import 'package:loanx/service/database_helper.dart';
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
    final bootstrap = await network.accountBootstrap(
      serverAddress: _address,
      serverName: _name,
      trustedCertificatePem: _certificate,
      deviceId: _deviceId(),
      accessToken: result.accessToken,
    );
    if (!bootstrap.success) {
      throw StateError(bootstrap.errorMessage ?? 'Account bootstrap failed');
    }
    final identity = CloudIdentity(
      userId: bootstrap.userId,
      workspaceId: bootstrap.workspaceId,
      selfPartyId: bootstrap.selfPartyId,
      phoneE164: bootstrap.phoneE164,
    );
    await linkLocalOwner(identity);
    await _storeTokens(
      result.accessToken,
      result.refreshToken,
      identity: identity,
    );
    _challenge = null;
    return true;
  }

  /// Returns true only when the authenticated server profile was updated.
  ///
  /// A language selected before sign-in remains queued locally and is sent
  /// during OTP verification or the next restored session.
  Future<bool> updateLanguage(String language) async {
    final token = (await _readTokens())?.accessToken;
    if (token == null || token.isEmpty) return false;
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
    return true;
  }

  Future<network.LenderSearchResult> searchPublicLenders({
    required int area,
    required String query,
    int limit = 25,
    String afterId = '',
  }) async {
    final token = (await _readTokens())?.accessToken;
    if (token == null || token.isEmpty) {
      throw StateError('Sign in is required to search public lenders');
    }
    final result = await network.searchPublicLenders(
      serverAddress: _address,
      serverName: _name,
      trustedCertificatePem: _certificate,
      deviceId: _deviceId(),
      accessToken: token,
      area: area,
      query: query,
      limit: limit,
      afterId: afterId,
    );
    if (!result.success) {
      throw StateError(result.errorMessage ?? 'Lender search failed');
    }
    return result;
  }

  Future<void> reportPublicLender(String profileId, String reason) async {
    final token = await _requiredAccessToken();
    final result = await network.reportPublicLender(
      serverAddress: _address,
      serverName: _name,
      trustedCertificatePem: _certificate,
      deviceId: _deviceId(),
      accessToken: token,
      profileId: profileId,
      reason: reason,
    );
    if (!result.success) {
      throw StateError(result.errorMessage ?? 'Unable to report lender');
    }
  }

  Future<void> blockPublicLender(String profileId) async {
    final token = await _requiredAccessToken();
    final result = await network.blockPublicLender(
      serverAddress: _address,
      serverName: _name,
      trustedCertificatePem: _certificate,
      deviceId: _deviceId(),
      accessToken: token,
      profileId: profileId,
    );
    if (!result.success) {
      throw StateError(result.errorMessage ?? 'Unable to block lender');
    }
  }

  Future<void> publishPublicLender({
    required String displayName,
    required String locality,
    required String city,
    required String postalCode,
    required String countryCode,
    required String minimumLoan,
    required String maximumLoan,
    required String currency,
    required int currencyScale,
    required List<String> categories,
    required String description,
    required bool available,
    required bool published,
  }) async {
    final min = Money.parse(
      minimumLoan,
      currency: currency,
      scale: currencyScale,
    );
    final max = Money.parse(
      maximumLoan,
      currency: currency,
      scale: currencyScale,
    );
    if (min.minorUnits < BigInt.zero ||
        max.minorUnits < min.minorUnits ||
        max.minorUnits > BigInt.from(9223372036854775807)) {
      throw ArgumentError('Invalid public loan range');
    }
    final result = await network.publishPublicLender(
      serverAddress: _address,
      serverName: _name,
      trustedCertificatePem: _certificate,
      deviceId: _deviceId(),
      accessToken: await _requiredAccessToken(),
      displayName: displayName,
      locality: locality,
      city: city,
      postalCode: postalCode,
      countryCode: countryCode,
      minimumLoanMinor: min.minorUnits.toString(),
      maximumLoanMinor: max.minorUnits.toString(),
      currency: currency,
      currencyScale: currencyScale,
      categories: categories,
      available: available,
      published: published,
      publicDescription: description,
    );
    if (!result.success) {
      throw StateError(
        result.errorMessage ?? 'Unable to update public profile',
      );
    }
  }

  Future<network.MyLenderProfile> myLenderProfile() async {
    final result = await network.myLenderProfile(
      serverAddress: _address,
      serverName: _name,
      trustedCertificatePem: _certificate,
      deviceId: _deviceId(),
      accessToken: await _requiredAccessToken(),
    );
    if (!result.success) {
      throw StateError(result.errorMessage ?? 'Unable to load public profile');
    }
    return result;
  }

  Future<String> _requiredAccessToken() async {
    final token = (await _readTokens())?.accessToken;
    if (token == null || token.isEmpty) {
      throw StateError('Sign in is required');
    }
    return token;
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
        if (!result.transportUnavailable) await clearLocalSession();
        return false;
      }
      final bootstrap = await network.accountBootstrap(
        serverAddress: _address,
        serverName: _name,
        trustedCertificatePem: _certificate,
        deviceId: _deviceId(),
        accessToken: result.accessToken,
      );
      if (!bootstrap.success) {
        // The refresh succeeded, but bootstrap may be temporarily offline.
        // Keep the rotated credentials so they can be retried later.
        await _storeTokens(result.accessToken, result.refreshToken);
        return false;
      }
      final identity = CloudIdentity(
        userId: bootstrap.userId,
        workspaceId: bootstrap.workspaceId,
        selfPartyId: bootstrap.selfPartyId,
        phoneE164: bootstrap.phoneE164,
      );
      await linkLocalOwner(identity);
      await _storeTokens(
        result.accessToken,
        result.refreshToken,
        identity: identity,
      );
      final pendingLanguage = AppSettings.getPendingPreferredLanguage();
      if (pendingLanguage.isNotEmpty) {
        try {
          if (await updateLanguage(pendingLanguage)) {
            AppSettings.putPendingPreferredLanguage('');
            await AppSettings.flush();
          }
        } catch (_) {
          // Authentication is valid; preference sync can retry later.
        }
      }
      return true;
    } catch (_) {
      // A network/configuration error must not erase the local identity or
      // credentials. The caller controls local access independently.
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

  Future<void> _storeTokens(
    String accessToken,
    String refreshToken, {
    CloudIdentity? identity,
  }) async {
    final previous = await _readSessionJson();
    final encoded = jsonEncode({
      'access_token': accessToken,
      'refresh_token': refreshToken,
      if (identity != null)
        ...identity.toJson()
      else ...{
        if (previous['user_id'] != null) 'user_id': previous['user_id'],
        if (previous['workspace_id'] != null)
          'workspace_id': previous['workspace_id'],
        if (previous['self_party_id'] != null)
          'self_party_id': previous['self_party_id'],
        if (previous['phone_e164'] != null)
          'phone_e164': previous['phone_e164'],
      },
    });
    await _storage.write(key: _sessionKey, value: encoded);
    await _storage.delete(key: 'loanx.access-token');
    await _storage.delete(key: 'loanx.refresh-token');
  }

  Future<_StoredTokens?> _readTokens() async {
    final value = await _readSessionJson();
    if (value.isNotEmpty) {
      try {
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

  Future<Map<String, dynamic>> _readSessionJson() async {
    final encoded = await _storage.read(key: _sessionKey);
    if (encoded == null || encoded.isEmpty) return <String, dynamic>{};
    try {
      return Map<String, dynamic>.from(jsonDecode(encoded) as Map);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> linkLocalOwner(
    CloudIdentity identity, {
    LoanxDatabasePort? database,
  }) async {
    final db = database ?? await DatabaseHelper.instance.database;
    final owners = await db.query('localOwners');
    if (owners.length != 1) {
      throw StateError('A single local owner is required');
    }
    final owner = owners.single;
    final currentRemoteUser = owner['remoteUserId'] as String?;
    if (currentRemoteUser != null &&
        currentRemoteUser.isNotEmpty &&
        currentRemoteUser != identity.userId) {
      throw StateError(
        'This local workspace is linked to a different LoanX account',
      );
    }
    final localOwnerId = owner['id'] as String;
    final localPartyId = owner['selfPartyId'] as String;
    await db.transaction((tx) async {
      await tx.update(
        'localOwners',
        {
          'remoteUserId': identity.userId,
          'remoteWorkspaceId': identity.workspaceId,
          'remotePartyId': identity.selfPartyId,
        },
        where: 'id = ?',
        whereArgs: [localOwnerId],
      );
      await tx.update(
        'parties',
        {
          'userId': identity.userId,
          'phone': identity.phoneE164,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ? AND ownerId = ?',
        whereArgs: [localPartyId, localOwnerId],
      );
    });
    await db.flush();
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

class CloudIdentity {
  const CloudIdentity({
    required this.userId,
    required this.workspaceId,
    required this.selfPartyId,
    required this.phoneE164,
  });

  final String userId;
  final String workspaceId;
  final String selfPartyId;
  final String phoneE164;

  Map<String, String> toJson() => {
    'user_id': userId,
    'workspace_id': workspaceId,
    'self_party_id': selfPartyId,
    'phone_e164': phoneE164,
  };
}
