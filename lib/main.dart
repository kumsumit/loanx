import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:loanx/screens/ask_backup_screen.dart';
import 'package:loanx/screens/account_type_screen.dart';
import 'package:loanx/screens/error.dart';
import 'package:loanx/screens/unauthorized.dart';
import 'package:loanx/l10n/codegen_loader.g.dart';
import 'package:loanx/l10n/app_languages.dart';
import 'package:loanx/l10n/locale_keys.g.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/screens/auth_screen.dart';
import 'package:loanx/screens/dashboard.dart';
import 'package:loanx/domain/country_catalog.dart';
import 'package:loanx/screens/plan_selection_screen.dart';
import 'package:loanx/screens/phone_login_screen.dart';
import 'package:loanx/screens/otp_verification_screen.dart';
import 'package:loanx/service/backup_service.dart';
import 'package:loanx/service/auth_client.dart';
import 'package:loanx/service/device_performance.dart';
import 'package:loanx/src/rust/frb_generated.dart';
import 'package:loanx/theme/app_theme.dart';
import 'package:loanx/widget/language_picker.dart';
import 'package:workmanager/workmanager.dart';

import 'db/app_settings.dart';

typedef OtpSender = Future<void> Function(PhoneNumber phoneNumber);
typedef OtpVerifier =
    Future<bool> Function(
      PhoneNumber phoneNumber,
      String code,
      String preferredLanguage,
    );

class _FallbackMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _FallbackMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    final materialLocale =
        GlobalMaterialLocalizations.delegate.isSupported(locale)
        ? locale
        : appDefaultLocale;
    return GlobalMaterialLocalizations.delegate.load(materialLocale);
  }

  @override
  bool shouldReload(_FallbackMaterialLocalizationsDelegate old) => false;
}

class _FallbackCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _FallbackCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    final cupertinoLocale =
        GlobalCupertinoLocalizations.delegate.isSupported(locale)
        ? locale
        : appDefaultLocale;
    return GlobalCupertinoLocalizations.delegate.load(cupertinoLocale);
  }

  @override
  bool shouldReload(_FallbackCupertinoLocalizationsDelegate old) => false;
}

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  final phoneMetadataReady = await initializePhoneMetadata();
  await DevicePerformance.initialize();
  await RustLib.init();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      debugPrint('FlutterError: ${details.exception}\n${details.stack}');
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      debugPrint('PlatformDispatcher error: $error\n$stack');
    }
    return true;
  };

  ErrorWidget.builder = (details) {
    if (kReleaseMode) {
      return Material(
        child: Center(
          child: Text(LocaleKeys.somethingWentWrongPleaseTryAgain.tr()),
        ),
      );
    }
    return ErrorWidget(details.exception);
  };

  var storageReady = false;
  try {
    await AppSettings.init();
    if (!AppSettings.getIsTableCreated()) {
      AppSettings.putHoldingPeriod(5);
      AppSettings.putInterestRate(3.0);
      AppSettings.putScheduledBackUpTimeHour(2);
      await AppSettings.flush();
    }
    storageReady = true;
  } catch (error, stackTrace) {
    debugPrint('LoanX local storage initialization failed: $error');
    if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
  }
  activeAuthClient = AuthClient();
  if (AppSettings.getPhoneAuthVerified() &&
      !await activeAuthClient!.restoreSession()) {
    AppSettings.putPhoneAuthVerified(false);
    await AppSettings.flush();
  }
  FlutterNativeSplash.remove();
  runApp(
    EasyLocalization(
      supportedLocales: appSupportedLocales,
      path: 'lib/l10n',
      assetLoader: const CodegenLoader(),
      fallbackLocale: appDefaultLocale,
      useFallbackTranslations: true,
      useOnlyLangCode: true,
      child: ProviderScope(
        child: MyApp(
          storageReady: storageReady,
          phoneMetadataReady: phoneMetadataReady,
          sendOtp: activeAuthClient!.requestOtp,
          verifyOtp: activeAuthClient!.verifyOtp,
        ),
      ),
    ),
  );
  unawaited(initializeOptionalServices());
}

/// Optional providers initialize independently after the local UI starts.
/// Their errors are reported without exposing provider credentials.
Future<void> initializeOptionalServices({
  Future<void> Function()? googleSignIn,
  Future<void> Function()? backgroundJobs,
}) async {
  Future<void> initialize(String name, Future<void> Function() action) async {
    try {
      await action().timeout(const Duration(seconds: 15));
    } catch (_) {
      debugPrint('LoanX $name initialization unavailable.');
    }
  }

  await Future.wait([
    initialize('Google Drive', googleSignIn ?? initializeGoogleSignIn),
    initialize(
      'background jobs',
      backgroundJobs ?? () => Workmanager().initialize(callbackDispatcher),
    ),
  ]);
}

/// Phone parsing metadata is required before any phone input widget is built.
/// Loading it after [runApp] races the login screen and causes a StateError.
Future<bool> initializePhoneMetadata({Future<void> Function()? loader}) async {
  try {
    await (loader ?? PhoneMetadataBootstrap.ensureInitialized).call().timeout(
      const Duration(seconds: 15),
    );
    return true;
  } catch (_) {
    debugPrint('LoanX phone metadata initialization unavailable.');
    return false;
  }
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({
    super.key,
    this.storageReady = true,
    this.phoneMetadataReady = true,
    this.sendOtp,
    this.verifyOtp,
  });

  final bool storageReady;
  final bool phoneMetadataReady;
  final OtpSender? sendOtp;
  final OtpVerifier? verifyOtp;

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  bool? _hasSelectedLanguage;
  bool? _hasSelectedInterest;
  bool? _hasVerifiedPhone;
  PhoneNumber? _pendingPhoneNumber;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Keep an app-owned onboarding marker. The locale package may not expose a
    // saved locale on every platform/startup path, even after `setLocale`.
    _hasSelectedLanguage ??=
        AppSettings.getLanguageSelectionCompleted() ||
        context.savedLocale != null;
    _hasSelectedInterest ??= AppSettings.getOnboardingInterest() >= 0;
    _hasVerifiedPhone ??= AppSettings.getPhoneAuthVerified();
  }

  Future<void> _languageSelected(Locale locale) async {
    if (_hasSelectedLanguage == true) return;
    AppSettings.putLanguageSelectionCompleted(true);
    // Queue this before sign-in. OTP verification persists it on the server;
    // an existing authenticated session can persist it immediately below.
    AppSettings.putPendingPreferredLanguage(locale.languageCode);
    await AppSettings.flush();
    try {
      if (await activeAuthClient?.updateLanguage(locale.languageCode) == true) {
        AppSettings.putPendingPreferredLanguage('');
        await AppSettings.flush();
      }
    } catch (_) {
      // The queued local preference is retried after the next session restore.
    }
    if (!mounted) return;
    setState(() => _hasSelectedLanguage = true);
  }

  Future<void> _interestSelected(AccountType type) async {
    AppSettings.putOnboardingInterest(type.index);
    await AppSettings.flush();
    if (!mounted) return;
    setState(() => _hasSelectedInterest = true);
  }

  Future<String?> _sendOtp(PhoneNumber phoneNumber) async {
    if (widget.sendOtp == null) {
      return LocaleKeys.phoneVerificationUnavailable.tr();
    }
    try {
      await widget.sendOtp!(phoneNumber);
      if (!mounted) return null;
      setState(() => _pendingPhoneNumber = phoneNumber);
      return null;
    } catch (_) {
      return LocaleKeys.couldNotSendCode.tr();
    }
  }

  Future<String?> _verifyOtp(String code) async {
    final phoneNumber = _pendingPhoneNumber;
    if (phoneNumber == null || widget.verifyOtp == null) {
      return LocaleKeys.phoneVerificationUnavailable.tr();
    }
    try {
      final verified = await widget.verifyOtp!(
        phoneNumber,
        code,
        context.locale.languageCode,
      );
      if (!verified) return LocaleKeys.invalidVerificationCode.tr();
      AppSettings.putPhoneAuthVerified(true);
      AppSettings.putVerifiedPhoneNumber(_e164Phone(phoneNumber));
      AppSettings.putVerifiedPhoneCountryCode(phoneNumber.isoCode);
      AppSettings.putPendingPreferredLanguage('');
      await AppSettings.flush();
      if (!mounted) return null;
      setState(() {
        _hasVerifiedPhone = true;
        _pendingPhoneNumber = null;
      });
      return null;
    } catch (_) {
      return LocaleKeys.couldNotVerifyCode.tr();
    }
  }

  String _e164Phone(PhoneNumber phoneNumber) =>
      CountryCatalog.e164(phoneNumber.isoCode, phoneNumber.nsn);

  Future<String?> _resendOtp() async {
    final phoneNumber = _pendingPhoneNumber;
    if (phoneNumber == null) return LocaleKeys.couldNotSendCode.tr();
    return _sendOtp(phoneNumber);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.storageReady &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached)) {
      unawaited(
        AppSettings.flush().catchError((Object _, StackTrace _) {
          debugPrint(
            'LoanX settings could not be saved; previous file retained.',
          );
        }),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = widget.storageReady
        ? ref.watch(themeModeManagerProvider)
        : ThemeMode.system;
    final appColor = widget.storageReady ? ref.watch(appColorProvider) : '';

    return MaterialApp(
      themeMode: themeMode,
      theme: AppTheme.light(AppTheme.parseSeed(appColor)),
      darkTheme: AppTheme.dark(AppTheme.parseSeed(appColor)),
      debugShowCheckedModeBanner: false,
      home: !widget.storageReady || !widget.phoneMetadataReady
          ? ErrorPage()
          : _hasSelectedLanguage != true
          ? StartupLanguageScreen(onLanguageSelected: _languageSelected)
          : _hasVerifiedPhone != true
          ? _pendingPhoneNumber == null
                ? PhoneLoginScreen(onContinue: _sendOtp)
                : OtpVerificationScreen(
                    phoneNumber: _pendingPhoneNumber!,
                    onVerify: _verifyOtp,
                    onResend: _resendOtp,
                    onChangeNumber: () =>
                        setState(() => _pendingPhoneNumber = null),
                  )
          : _hasSelectedInterest != true
          ? AccountTypeScreen(onContinue: _interestSelected)
          : ref
                .watch(authenticateProvider)
                .when(
                  data: (authenticated) => !authenticated
                      ? const AuthFailurePage()
                      : !AppSettings.getPlanSelectionCompleted()
                      ? PlanSelectionScreen(onContinue: () => setState(() {}))
                      : !AppSettings.getIsTableCreated()
                      ? const AskBackupScreen()
                      : const DashBoard(),
                  error: (_, _) => ErrorPage(),
                  loading: () => AuthScreen(),
                ),
      locale: context.locale,
      localizationsDelegates: [
        const _FallbackMaterialLocalizationsDelegate(),
        const _FallbackCupertinoLocalizationsDelegate(),
        ...context.localizationDelegates,
      ],
      supportedLocales: context.supportedLocales,
      builder: (context, child) => child ?? const SizedBox.shrink(),
    );
  }
}
