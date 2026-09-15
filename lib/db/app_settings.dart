import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:loanx/model/loan.dart';
import '../service/database_helper.dart';
import 'settings_snapshot.dart';
import 'settings_store.dart';
import 'tostore_database.dart';

/// Stable application settings facade backed exclusively by ToStore KV.
class AppSettings {
  static SettingsStore? _store;
  static final Map<String, dynamic> _values = {};
  static const _key = 'loanx.settings.v1';

  static Future<void> init() async {
    _store = await DatabaseHelper.instance.settingsStore;
    await _load();
  }

  static Future<void> initForTesting(
    dynamic directory, {
    int keyOffset = 0,
  }) async {
    final db = await DatabaseHelper.instance.openMemory(
      name: 'settings-test-${DateTime.now().microsecondsSinceEpoch}',
    );
    _store = ToStoreSettingsStore((db as LoanxDatabase).store);
    await _load();
  }

  static Future<void> _load() async {
    final raw = await _store?.read(_key);
    if (raw == null) return;
    try {
      _values.addAll(
        SettingsSnapshot.decode(
          raw is List<int>
              ? raw
              : Uint8List.fromList((raw as List).cast<int>()),
        ).values,
      );
    } catch (_) {
      _values.clear();
    }
  }

  static Future<void> reloadForTesting() => _load();
  static dynamic _get(String key, dynamic fallback) => _values[key] ?? fallback;
  static void _put(String key, dynamic value) => _values[key] = value;

  static List<int> exportBackupSettings() => SettingsSnapshot(
    Map<String, dynamic>.from(_values)..removeWhere(
      (k, _) => {
        'driveAccessToken',
        'driveAccessTokenExpires',
        'driveFileId',
        'driveUser',
        'isBackUpRegistered',
        'backupTaskId',
      }.contains(k),
    ),
  ).encode();
  static void validateBackupSettings(List<int> bytes) {
    final v = SettingsSnapshot.decode(bytes).values;
    final h = (v['scheduledBackUpTimeHour'] as num?)?.toInt() ?? 0;
    final m = (v['scheduledBackUpTimeMinute'] as num?)?.toInt() ?? 0;
    final t = (v['themeMode'] as num?)?.toInt() ?? 0;
    if (h < 0 ||
        h > 23 ||
        m < 0 ||
        m > 59 ||
        t < 0 ||
        t >= ThemeMode.values.length) {
      throw const FormatException('Invalid backup settings values.');
    }
  }

  static Future<void> restoreBackupSettings(List<int> bytes) async {
    validateBackupSettings(bytes);
    _values.addAll(SettingsSnapshot.decode(bytes).values);
    await flush();
  }

  static String getAppColor() => _get('appColor', 'fea0d1a0');
  static bool getIsTableCreated() => _get('isTableCreated', false);
  static int getThemeMode() => _get('themeMode', ThemeMode.system.index);
  static int getOnboardingInterest() => _get('onboardingInterest', -1);

  /// A borrower-only onboarding preference. This controls the initial local
  /// workspace experience; it is not an authorization role.
  static bool getUsesBorrowerExperience() => getOnboardingInterest() == 1;

  /// A combined workspace is available only to the paid lending experience.
  /// This remains a presentation preference; server-side entitlements must
  /// still protect paid network features when they are introduced.
  static bool getUsesBothExperience() => getOnboardingInterest() == 2;
  static bool getPlanSelectionCompleted() =>
      _get('planSelectionCompleted', false);
  static String getSelectedPlan() => _get('selectedPlan', 'free');
  static bool getPhoneAuthVerified() => _get('phoneAuthVerified', false);
  static bool getLanguageSelectionCompleted() =>
      _get('languageSelectionCompleted', false);
  static String getVerifiedPhoneNumber() => _get('verifiedPhoneNumber', '');
  static String getVerifiedPhoneCountryCode() =>
      _get('verifiedPhoneCountryCode', 'IN');
  static String getDeviceId() => _get('deviceId', '');
  static String getPendingPreferredLanguage() =>
      _get('pendingPreferredLanguage', '');
  static int getHoldingPeriod() => _get('holdingPeriod', 5);
  static double getInterestRate() =>
      ((_get('interestRate', 3.0) as num).toDouble());
  static int getInterestType() =>
      _get('interestType', InterestType.simple.index);
  static int getInterestFrequency() =>
      _get('interestFrequency', InterestFrequency.monthly.index);
  static int getDefaultLockInDays() => _get('defaultLockInDays', 0);
  static double getDefaultEarlyRedemptionCharge() =>
      ((_get('defaultEarlyRedemptionCharge', 0.0) as num).toDouble());
  static String getDefaultTermsAndConditions() =>
      _get('defaultTermsAndConditions', '');
  static String getDefaultUpiId() => _get('defaultUpiId', '');
  static int getScheduledBackUpTimeHour() => _get('scheduledBackUpTimeHour', 2);
  static int getScheduledBackUpTimeMinute() =>
      _get('scheduledBackUpTimeMinute', 0);
  static String getDriveAccessToken() => _get('driveAccessToken', '');
  static int getDriveAccessTokenExpires() => _get('driveAccessTokenExpires', 0);
  static String getDriveFileId() => _get('driveFileId', '');
  static int getDriveUser() => _get('driveUser', 0);
  static bool getIsBackUpRegistered() => _get('isBackUpRegistered', false);
  static int getDbUpdateTime() => _get('dbUpdateTime', 0);
  static String getDisplayName() => _get('displayName', '');
  static String getEmail() => _get('email', '');
  static String getPhotourl() => _get('photourl', '');
  static String getBackupTaskId() => _get('backupTaskId', '');
  static bool getSecure() => _get('secure', false);
  static List<int> getPhoto() => List<int>.from(_get('photo', const <int>[]));
  static void putThemeMode(int v) => _put('themeMode', v);
  static void putOnboardingInterest(int v) => _put('onboardingInterest', v);
  static void putPlanSelectionCompleted(bool v) =>
      _put('planSelectionCompleted', v);

  /// This is a local onboarding preference, never proof of a paid entitlement.
  static void putSelectedPlan(String v) => _put('selectedPlan', v);
  static void putPhoneAuthVerified(bool v) => _put('phoneAuthVerified', v);
  static void putLanguageSelectionCompleted(bool v) =>
      _put('languageSelectionCompleted', v);
  static void putVerifiedPhoneNumber(String v) =>
      _put('verifiedPhoneNumber', v);
  static void putVerifiedPhoneCountryCode(String v) =>
      _put('verifiedPhoneCountryCode', v);
  static void putDeviceId(String v) => _put('deviceId', v);
  static void putPendingPreferredLanguage(String v) =>
      _put('pendingPreferredLanguage', v);
  static void putIsTableCreated(bool v) => _put('isTableCreated', v);
  static void putAppColor(String v) => _put('appColor', v);
  static void putHoldingPeriod(int v) => _put('holdingPeriod', v);
  static void putInterestRate(double v) => _put('interestRate', v);
  static void putInterestType(int v) => _put('interestType', v);
  static void putInterestFrequency(int v) => _put('interestFrequency', v);
  static void putDefaultLockInDays(int v) => _put('defaultLockInDays', v);
  static void putDefaultEarlyRedemptionCharge(double v) =>
      _put('defaultEarlyRedemptionCharge', v);
  static void putDefaultTermsAndConditions(String v) =>
      _put('defaultTermsAndConditions', v);
  static void putDefaultUpiId(String v) => _put('defaultUpiId', v);
  static void putScheduledBackUpTimeHour(int v) =>
      _put('scheduledBackUpTimeHour', v);
  static void putScheduledBackUpTimeMinute(int v) =>
      _put('scheduledBackUpTimeMinute', v);
  static void putDriveAccessToken(String v) => _put('driveAccessToken', v);
  static void putDriveAccessTokenExpires(int v) =>
      _put('driveAccessTokenExpires', v);
  static void putDriveFileId(String v) => _put('driveFileId', v);
  static void putDriveUser(int v) => _put('driveUser', v);
  static void putIsBackUpRegistered(bool v) => _put('isBackUpRegistered', v);
  static void putDbUpdateTime(int v) => _put('dbUpdateTime', v);
  static void putDisplayName(String v) => _put('displayName', v);
  static void putEmail(String v) => _put('email', v);
  static void putPhotourl(String v) => _put('photourl', v);
  static void putBackupTaskId(String v) => _put('backupTaskId', v);
  static Future<void> putSecure(bool v) async => _put('secure', v);
  static Future<void> putPhoto(List<int> v) async => _put('photo', v);
  static Future<void> flush() async {
    if (_store == null) return;
    await _store!.write(
      _key,
      SettingsSnapshot(Map<String, dynamic>.from(_values)).encode(),
    );
    await _store!.flush();
  }

  static Future<void> clearAll() async {
    _values.clear();
    await _store?.remove(_key);
  }
}
