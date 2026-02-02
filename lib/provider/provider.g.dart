// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(authenticate)
final authenticateProvider = AuthenticateProvider._();

final class AuthenticateProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  AuthenticateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authenticateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authenticateHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return authenticate(ref);
  }
}

String _$authenticateHash() => r'f98a0ad121a1d7c3ea0fabc99d8e6afe4df3964e';

@ProviderFor(Secure)
final secureProvider = SecureProvider._();

final class SecureProvider extends $NotifierProvider<Secure, bool> {
  SecureProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'secureProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$secureHash();

  @$internal
  @override
  Secure create() => Secure();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$secureHash() => r'394ab5929b38a134c2450733ad4d5dc77d51acd8';

abstract class _$Secure extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(DriveAccessToken)
final driveAccessTokenProvider = DriveAccessTokenProvider._();

final class DriveAccessTokenProvider
    extends $NotifierProvider<DriveAccessToken, String> {
  DriveAccessTokenProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'driveAccessTokenProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$driveAccessTokenHash();

  @$internal
  @override
  DriveAccessToken create() => DriveAccessToken();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$driveAccessTokenHash() => r'ce313e39a994ebbe7a38e8e8a8350157d667eb6e';

abstract class _$DriveAccessToken extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(BackUpRegistered)
final backUpRegisteredProvider = BackUpRegisteredProvider._();

final class BackUpRegisteredProvider
    extends $NotifierProvider<BackUpRegistered, bool> {
  BackUpRegisteredProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backUpRegisteredProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backUpRegisteredHash();

  @$internal
  @override
  BackUpRegistered create() => BackUpRegistered();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$backUpRegisteredHash() => r'c6daac1f514d030f363cfea190b306d6b745562b';

abstract class _$BackUpRegistered extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(DisplayName)
final displayNameProvider = DisplayNameProvider._();

final class DisplayNameProvider extends $NotifierProvider<DisplayName, String> {
  DisplayNameProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'displayNameProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$displayNameHash();

  @$internal
  @override
  DisplayName create() => DisplayName();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$displayNameHash() => r'f36776e6dee59fe44d8d6ee8cb7672915f20bf51';

abstract class _$DisplayName extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(PhotoUrl)
final photoUrlProvider = PhotoUrlProvider._();

final class PhotoUrlProvider extends $NotifierProvider<PhotoUrl, String> {
  PhotoUrlProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'photoUrlProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$photoUrlHash();

  @$internal
  @override
  PhotoUrl create() => PhotoUrl();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$photoUrlHash() => r'0e0a3e6c4c5f3edbb602db2c2985ae6782dedf43';

abstract class _$PhotoUrl extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(Email)
final emailProvider = EmailProvider._();

final class EmailProvider extends $NotifierProvider<Email, String> {
  EmailProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'emailProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$emailHash();

  @$internal
  @override
  Email create() => Email();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$emailHash() => r'02b8f0c9b0441abda29058ca5eda10282f3f8b67';

abstract class _$Email extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(ThemeModeManager)
final themeModeManagerProvider = ThemeModeManagerProvider._();

final class ThemeModeManagerProvider
    extends $NotifierProvider<ThemeModeManager, ThemeMode> {
  ThemeModeManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeModeManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeModeManagerHash();

  @$internal
  @override
  ThemeModeManager create() => ThemeModeManager();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemeMode>(value),
    );
  }
}

String _$themeModeManagerHash() => r'ddd2afdcc60d59e17e4ea51fbc3332bd3758a187';

abstract class _$ThemeModeManager extends $Notifier<ThemeMode> {
  ThemeMode build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ThemeMode, ThemeMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ThemeMode, ThemeMode>,
              ThemeMode,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(HoldingPeriod)
final holdingPeriodProvider = HoldingPeriodProvider._();

final class HoldingPeriodProvider
    extends $NotifierProvider<HoldingPeriod, int> {
  HoldingPeriodProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'holdingPeriodProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$holdingPeriodHash();

  @$internal
  @override
  HoldingPeriod create() => HoldingPeriod();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$holdingPeriodHash() => r'39e133da62b8fee70920cec543129ce4949d2dca';

abstract class _$HoldingPeriod extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(ScheduledBackUpTimeHour)
final scheduledBackUpTimeHourProvider = ScheduledBackUpTimeHourProvider._();

final class ScheduledBackUpTimeHourProvider
    extends $NotifierProvider<ScheduledBackUpTimeHour, int> {
  ScheduledBackUpTimeHourProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'scheduledBackUpTimeHourProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$scheduledBackUpTimeHourHash();

  @$internal
  @override
  ScheduledBackUpTimeHour create() => ScheduledBackUpTimeHour();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$scheduledBackUpTimeHourHash() =>
    r'e16b22c6f0c6bfe4f58ef7328f6b9d6abe0f2f3e';

abstract class _$ScheduledBackUpTimeHour extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(ScheduledBackUpTimeMinute)
final scheduledBackUpTimeMinuteProvider = ScheduledBackUpTimeMinuteProvider._();

final class ScheduledBackUpTimeMinuteProvider
    extends $NotifierProvider<ScheduledBackUpTimeMinute, int> {
  ScheduledBackUpTimeMinuteProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'scheduledBackUpTimeMinuteProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$scheduledBackUpTimeMinuteHash();

  @$internal
  @override
  ScheduledBackUpTimeMinute create() => ScheduledBackUpTimeMinute();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$scheduledBackUpTimeMinuteHash() =>
    r'c9e83dc4a3cf1700eeae20c741192f7db1345e5c';

abstract class _$ScheduledBackUpTimeMinute extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(InterestTypeStatus)
final interestTypeStatusProvider = InterestTypeStatusProvider._();

final class InterestTypeStatusProvider
    extends $NotifierProvider<InterestTypeStatus, InterestType> {
  InterestTypeStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'interestTypeStatusProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$interestTypeStatusHash();

  @$internal
  @override
  InterestTypeStatus create() => InterestTypeStatus();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InterestType value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InterestType>(value),
    );
  }
}

String _$interestTypeStatusHash() =>
    r'a7259b867f13985012eee64a5356936fdcb719da';

abstract class _$InterestTypeStatus extends $Notifier<InterestType> {
  InterestType build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<InterestType, InterestType>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<InterestType, InterestType>,
              InterestType,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(InterestRate)
final interestRateProvider = InterestRateProvider._();

final class InterestRateProvider
    extends $NotifierProvider<InterestRate, double> {
  InterestRateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'interestRateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$interestRateHash();

  @$internal
  @override
  InterestRate create() => InterestRate();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<double>(value),
    );
  }
}

String _$interestRateHash() => r'43877bba667fbf31c28743a6e9f42fde4995d69d';

abstract class _$InterestRate extends $Notifier<double> {
  double build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<double, double>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<double, double>,
              double,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(InterestFrequencyStatus)
final interestFrequencyStatusProvider = InterestFrequencyStatusProvider._();

final class InterestFrequencyStatusProvider
    extends $NotifierProvider<InterestFrequencyStatus, InterestFrequency> {
  InterestFrequencyStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'interestFrequencyStatusProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$interestFrequencyStatusHash();

  @$internal
  @override
  InterestFrequencyStatus create() => InterestFrequencyStatus();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InterestFrequency value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InterestFrequency>(value),
    );
  }
}

String _$interestFrequencyStatusHash() =>
    r'9e92c86199e1dbf1b8b7f9537d2287584851ffc1';

abstract class _$InterestFrequencyStatus extends $Notifier<InterestFrequency> {
  InterestFrequency build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<InterestFrequency, InterestFrequency>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<InterestFrequency, InterestFrequency>,
              InterestFrequency,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(BackupStatus)
final backupStatusProvider = BackupStatusProvider._();

final class BackupStatusProvider extends $NotifierProvider<BackupStatus, bool> {
  BackupStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backupStatusProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backupStatusHash();

  @$internal
  @override
  BackupStatus create() => BackupStatus();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$backupStatusHash() => r'990dc476961e6789301b13e5a9737f80627a70e5';

abstract class _$BackupStatus extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(BackupDownloadStatus)
final backupDownloadStatusProvider = BackupDownloadStatusProvider._();

final class BackupDownloadStatusProvider
    extends $NotifierProvider<BackupDownloadStatus, bool> {
  BackupDownloadStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backupDownloadStatusProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backupDownloadStatusHash();

  @$internal
  @override
  BackupDownloadStatus create() => BackupDownloadStatus();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$backupDownloadStatusHash() =>
    r'bee60c23b5f51f1fbc7360209659cd9fa64b2e13';

abstract class _$BackupDownloadStatus extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(LoanSelectionList)
final loanSelectionListProvider = LoanSelectionListProvider._();

final class LoanSelectionListProvider
    extends $NotifierProvider<LoanSelectionList, List<int>> {
  LoanSelectionListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'loanSelectionListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$loanSelectionListHash();

  @$internal
  @override
  LoanSelectionList create() => LoanSelectionList();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<int> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<int>>(value),
    );
  }
}

String _$loanSelectionListHash() => r'd51feb05f5571703a3d330258c5bb37982578ea4';

abstract class _$LoanSelectionList extends $Notifier<List<int>> {
  List<int> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<List<int>, List<int>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<int>, List<int>>,
              List<int>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(SearchBarStatus)
final searchBarStatusProvider = SearchBarStatusProvider._();

final class SearchBarStatusProvider
    extends $NotifierProvider<SearchBarStatus, bool> {
  SearchBarStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchBarStatusProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchBarStatusHash();

  @$internal
  @override
  SearchBarStatus create() => SearchBarStatus();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$searchBarStatusHash() => r'b411bf702dd87c78326863b709abeb0eb4c08eed';

abstract class _$SearchBarStatus extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(AppColor)
final appColorProvider = AppColorProvider._();

final class AppColorProvider extends $NotifierProvider<AppColor, String> {
  AppColorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appColorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appColorHash();

  @$internal
  @override
  AppColor create() => AppColor();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$appColorHash() => r'd4700d09e29acd3afa015c2c0efe92d4d3c5dd1b';

abstract class _$AppColor extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(PickerColor)
final pickerColorProvider = PickerColorProvider._();

final class PickerColorProvider extends $NotifierProvider<PickerColor, String> {
  PickerColorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pickerColorProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pickerColorHash();

  @$internal
  @override
  PickerColor create() => PickerColor();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$pickerColorHash() => r'feab1f97652797594d879a5a15715aab4b9bed1b';

abstract class _$PickerColor extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(appVersion)
final appVersionProvider = AppVersionProvider._();

final class AppVersionProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  AppVersionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appVersionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appVersionHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return appVersion(ref);
  }
}

String _$appVersionHash() => r'1047063a2265b00afdccc963cd6588405254dff8';

@ProviderFor(DB)
final dBProvider = DBProvider._();

final class DBProvider extends $AsyncNotifierProvider<DB, Database> {
  DBProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dBProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dBHash();

  @$internal
  @override
  DB create() => DB();
}

String _$dBHash() => r'adfa869646a32c85911e48e66cd9ac3bbbf6126b';

abstract class _$DB extends $AsyncNotifier<Database> {
  FutureOr<Database> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Database>, Database>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Database>, Database>,
              AsyncValue<Database>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(FamilyRelationList)
final familyRelationListProvider = FamilyRelationListProvider._();

final class FamilyRelationListProvider
    extends $AsyncNotifierProvider<FamilyRelationList, List<FamilyRelation>> {
  FamilyRelationListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'familyRelationListProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$familyRelationListHash();

  @$internal
  @override
  FamilyRelationList create() => FamilyRelationList();
}

String _$familyRelationListHash() =>
    r'dd5b64185af2a9db4eac3987beed027b757a07dd';

abstract class _$FamilyRelationList
    extends $AsyncNotifier<List<FamilyRelation>> {
  FutureOr<List<FamilyRelation>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<FamilyRelation>>, List<FamilyRelation>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<FamilyRelation>>,
                List<FamilyRelation>
              >,
              AsyncValue<List<FamilyRelation>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(MortgageMaterialList)
final mortgageMaterialListProvider = MortgageMaterialListProvider._();

final class MortgageMaterialListProvider
    extends
        $AsyncNotifierProvider<MortgageMaterialList, List<MortgageMaterial>> {
  MortgageMaterialListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mortgageMaterialListProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mortgageMaterialListHash();

  @$internal
  @override
  MortgageMaterialList create() => MortgageMaterialList();
}

String _$mortgageMaterialListHash() =>
    r'd86ddc78a3ce9331efe0785052195c0a4902d884';

abstract class _$MortgageMaterialList
    extends $AsyncNotifier<List<MortgageMaterial>> {
  FutureOr<List<MortgageMaterial>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<MortgageMaterial>>, List<MortgageMaterial>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<MortgageMaterial>>,
                List<MortgageMaterial>
              >,
              AsyncValue<List<MortgageMaterial>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(LoanList)
final loanListProvider = LoanListProvider._();

final class LoanListProvider
    extends $AsyncNotifierProvider<LoanList, List<Loan>> {
  LoanListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'loanListProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$loanListHash();

  @$internal
  @override
  LoanList create() => LoanList();
}

String _$loanListHash() => r'e0a1035f3eede4b2f9d27b63538c998a96558081';

abstract class _$LoanList extends $AsyncNotifier<List<Loan>> {
  FutureOr<List<Loan>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Loan>>, List<Loan>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Loan>>, List<Loan>>,
              AsyncValue<List<Loan>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
