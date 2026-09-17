import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:loanx/domain/country_catalog.dart';
import 'package:loanx/features/auth/account_type_screen.dart';
import 'package:loanx/features/auth/otp_verification_screen.dart';
import 'package:loanx/features/auth/phone_login_screen.dart';
import 'package:loanx/features/auth/plan_selection_screen.dart';
import 'package:loanx/features/lender/ask_backup_screen.dart';
import 'package:loanx/features/lender/auth_screen.dart';
import 'package:loanx/features/lender/dashboard.dart';
import 'package:loanx/features/lender/error.dart';
import 'package:loanx/features/auth/unauthorized.dart';
import 'package:loanx/l10n/app_languages.dart';
import 'package:loanx/l10n/codegen_loader.g.dart';
import 'package:loanx/l10n/locale_keys.g.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/service/auth_client.dart';
import 'package:loanx/service/backup_service.dart';
import 'package:loanx/service/device_performance.dart';
import 'package:loanx/service/rust_bridge.dart';
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

/// ---------------------------------------------------------------------------
/// Localization fallbacks
/// ---------------------------------------------------------------------------

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

/// ---------------------------------------------------------------------------
/// Global authentication client
/// ---------------------------------------------------------------------------

AuthClient? activeAuthClient;

/// ---------------------------------------------------------------------------
/// Bootstrap state
/// ---------------------------------------------------------------------------

/// ---------------------------------------------------------------------------
/// Main
/// ---------------------------------------------------------------------------

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Keep the native splash visible until Flutter has rendered its first frame.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // -------------------------------------------------------------------------
  // Global error handling
  // -------------------------------------------------------------------------

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

  // -------------------------------------------------------------------------
  // Critical startup
  //
  // These operations are independent, so don't execute them serially.
  // -------------------------------------------------------------------------

  final startupResults = await Future.wait<dynamic>([
    EasyLocalization.ensureInitialized(),
    initializePhoneMetadata(),
    DevicePerformance.initialize(),
    _initializeLocalStorage(),
  ]);

  final phoneMetadataReady = startupResults[1] as bool;
  final storageReady = startupResults[3] as bool;

  // -------------------------------------------------------------------------
  // Authentication client itself is cheap to construct.
  //
  // Session restoration is intentionally NOT performed here.
  // -------------------------------------------------------------------------

  activeAuthClient = AuthClient();

  // -------------------------------------------------------------------------
  // Start Flutter immediately after critical local initialization.
  // -------------------------------------------------------------------------

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

  // -------------------------------------------------------------------------
  // Wait until Flutter has produced the first frame.
  //
  // Native splash remains visible until that point, preventing any blank
  // transition while the first Flutter frame is being composed.
  // -------------------------------------------------------------------------

  WidgetsBinding.instance.addPostFrameCallback((_) {
    FlutterNativeSplash.remove();

    unawaited(_initializeBackgroundServices());
  });
}

/// ---------------------------------------------------------------------------
/// Local storage initialization
/// ---------------------------------------------------------------------------

Future<bool> _initializeLocalStorage() async {
  try {
    await AppSettings.init();

    if (!AppSettings.getIsTableCreated()) {
      AppSettings.putHoldingPeriod(5);
      AppSettings.putInterestRate(3.0);
      AppSettings.putScheduledBackUpTimeHour(2);

      await AppSettings.flush();
    }

    return true;
  } catch (error, stackTrace) {
    debugPrint('LoanX local storage initialization failed: $error');

    if (kDebugMode) {
      debugPrintStack(stackTrace: stackTrace);
    }

    return false;
  }
}

/// ---------------------------------------------------------------------------
/// Background bootstrap
///
/// Anything that isn't required for the first rendered frame belongs here.
/// ---------------------------------------------------------------------------

Future<void> _initializeBackgroundServices() async {
  // Rust and session restoration are owned by MyApp._watchBackgroundBootstrap.
  // Keeping them there gives the app one initialization path and prevents
  // flutter_rust_bridge from trying to install its global Rust logger twice.
  // These services do not participate in the first screen.
  await initializeOptionalServices();
}

/// ---------------------------------------------------------------------------
/// Optional services
/// ---------------------------------------------------------------------------

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

/// ---------------------------------------------------------------------------
/// Phone metadata
/// ---------------------------------------------------------------------------

Future<bool> initializePhoneMetadata({Future<void> Function()? loader}) async {
  final initialize = loader ?? PhoneMetadataBootstrap.ensureInitialized;

  // The package downloads and parses the metadata on first use, then falls
  // back to its bundled snapshot when the download is unavailable. A short
  // timeout can interrupt that fallback on a slow device/network and leave
  // borrower onboarding on the generic workspace error page.
  Object? lastError;
  StackTrace? lastStackTrace;
  for (var attempt = 1; attempt <= 2; attempt++) {
    try {
      await initialize().timeout(const Duration(seconds: 30));
      return true;
    } catch (error, stackTrace) {
      lastError = error;
      lastStackTrace = stackTrace;
      debugPrint(
        'LoanX phone metadata initialization attempt $attempt failed: '
        '$error',
      );
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  debugPrint('LoanX phone metadata initialization unavailable: $lastError');
  if (kDebugMode && lastStackTrace != null) {
    debugPrintStack(stackTrace: lastStackTrace);
  }
  return false;
}

/// ---------------------------------------------------------------------------
/// Application
/// ---------------------------------------------------------------------------

class MyApp extends ConsumerStatefulWidget {
  const MyApp({
    super.key,
    this.storageReady = true,
    this.phoneMetadataReady = true,
    this.sendOtp,
    this.verifyOtp,
    this.initializeBridge,
    this.startOptionalServices,
  });

  final bool storageReady;
  final bool phoneMetadataReady;

  final OtpSender? sendOtp;
  final OtpVerifier? verifyOtp;
  final Future<void> Function()? initializeBridge;
  final Future<void> Function()? startOptionalServices;

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

/// ---------------------------------------------------------------------------
/// Application state
/// ---------------------------------------------------------------------------

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  bool? _hasSelectedLanguage;
  bool? _hasSelectedInterest;
  bool? _hasVerifiedPhone;

  PhoneNumber? _pendingPhoneNumber;

  bool _backgroundBootstrapStarted = false;
  bool _cloudSyncInFlight = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    ref.listenManual<AsyncValue<bool>>(networkCheckerProvider, (
      previous,
      next,
    ) {
      if (next.asData?.value == true && previous?.asData?.value != true) {
        unawaited(_syncWhenOnline());
      }
    });
  }

  Future<void> _syncWhenOnline() async {
    if (_cloudSyncInFlight || !AuthClient.hasServerConfiguration) return;
    final client = activeAuthClient;
    if (client == null) return;
    _cloudSyncInFlight = true;
    try {
      // Refresh first: an expired access token must not strand mutations until
      // the next full app launch. restoreSession also validates owner/workspace
      // binding before it flushes any private records.
      final restored = await client.restoreSession();
      if (restored && mounted) ref.invalidate(loanListProvider);
    } finally {
      _cloudSyncInFlight = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // These values are only calculated once.
    //
    // They are intentionally not queried repeatedly during build().
    _hasSelectedLanguage ??=
        AppSettings.getLanguageSelectionCompleted() ||
        context.savedLocale != null;

    _hasSelectedInterest ??= AppSettings.getOnboardingInterest() >= 0;

    _hasVerifiedPhone ??= AppSettings.getPhoneAuthVerified();

    if (!_backgroundBootstrapStarted) {
      _backgroundBootstrapStarted = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_watchBackgroundBootstrap());
      });
    }
  }

  /// -------------------------------------------------------------------------
  /// Bootstrap watcher
  /// -------------------------------------------------------------------------

  Future<void> _watchBackgroundBootstrap() async {
    try {
      // Connected services are optional for a device-local workspace. Never
      // gate local authentication or loan access on a network bridge.
      await (widget.initializeBridge?.call() ?? RustBridge.ensureInitialized());

      if (AppSettings.getPhoneAuthVerified()) {
        // An expired or unavailable cloud session only disables connected
        // actions. Existing local data remains accessible on this device.
        final restored = await activeAuthClient?.restoreSession() ?? false;
        if (restored && mounted) {
          // The initial frame may have built the local provider before the
          // background cloud pull finished.
          ref.invalidate(loanListProvider);
        }
      }
    } catch (error, stackTrace) {
      debugPrint('LoanX bootstrap initialization failed: $error');

      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    // These services also have no bearing on local authentication or routing.
    unawaited(
      widget.startOptionalServices?.call() ?? initializeOptionalServices(),
    );
  }

  /// -------------------------------------------------------------------------
  /// Language
  /// -------------------------------------------------------------------------

  Future<void> _languageSelected(Locale locale) async {
    if (_hasSelectedLanguage == true) {
      return;
    }

    AppSettings.putLanguageSelectionCompleted(true);

    // Store this locally before attempting server synchronization.
    AppSettings.putPendingPreferredLanguage(locale.languageCode);

    await AppSettings.flush();

    try {
      if (await activeAuthClient?.updateLanguage(locale.languageCode) == true) {
        AppSettings.putPendingPreferredLanguage('');

        await AppSettings.flush();
      }
    } catch (_) {
      // The locally queued language preference will be retried later.
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _hasSelectedLanguage = true;
    });
  }

  /// -------------------------------------------------------------------------
  /// Account type
  /// -------------------------------------------------------------------------

  Future<void> _interestSelected(AccountType type) async {
    AppSettings.putOnboardingInterest(type.index);

    await AppSettings.flush();

    if (!mounted) {
      return;
    }

    setState(() {
      _hasSelectedInterest = true;
    });
  }

  /// -------------------------------------------------------------------------
  /// OTP
  /// -------------------------------------------------------------------------

  Future<String?> _sendOtp(PhoneNumber phoneNumber) async {
    if (widget.sendOtp == null) {
      return LocaleKeys.phoneVerificationUnavailable.tr();
    }

    try {
      await widget.sendOtp!(phoneNumber);

      if (!mounted) {
        return null;
      }

      setState(() {
        _pendingPhoneNumber = phoneNumber;
      });

      return null;
    } catch (_) {
      return LocaleKeys.couldNotSendCode.tr();
    }
  }

  /// -------------------------------------------------------------------------
  /// OTP verification
  /// -------------------------------------------------------------------------

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

      if (!verified) {
        return LocaleKeys.invalidVerificationCode.tr();
      }

      // OTP verification also restores the cloud workspace. Rebuild any
      // provider that may have read the freshly-created local database before
      // the pull completed (especially after an uninstall/reinstall).
      ref.invalidate(loanListProvider);

      AppSettings.putPhoneAuthVerified(true);

      AppSettings.putVerifiedPhoneNumber(_e164Phone(phoneNumber));

      AppSettings.putVerifiedPhoneCountryCode(phoneNumber.isoCode);

      AppSettings.putPendingPreferredLanguage('');

      await AppSettings.flush();

      if (!mounted) {
        return null;
      }

      setState(() {
        _hasVerifiedPhone = true;
        _pendingPhoneNumber = null;
      });

      return null;
    } catch (_) {
      return LocaleKeys.couldNotVerifyCode.tr();
    }
  }

  /// -------------------------------------------------------------------------
  /// E.164
  /// -------------------------------------------------------------------------

  String _e164Phone(PhoneNumber phoneNumber) {
    return CountryCatalog.e164(phoneNumber.isoCode, phoneNumber.nsn);
  }

  /// -------------------------------------------------------------------------
  /// Resend OTP
  /// -------------------------------------------------------------------------

  Future<String?> _resendOtp() async {
    final phoneNumber = _pendingPhoneNumber;

    if (phoneNumber == null) {
      return LocaleKeys.couldNotSendCode.tr();
    }

    return _sendOtp(phoneNumber);
  }

  /// -------------------------------------------------------------------------
  /// Lifecycle
  /// -------------------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_syncWhenOnline());
    if (!widget.storageReady) {
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(
        AppSettings.flush().catchError((Object _, StackTrace _) {
          debugPrint(
            'LoanX settings could not be saved; '
            'previous file retained.',
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

  /// -------------------------------------------------------------------------
  /// Build
  /// -------------------------------------------------------------------------

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

      home: _buildHome(context),

      locale: context.locale,

      localizationsDelegates: [
        ...context.localizationDelegates,
        const _FallbackMaterialLocalizationsDelegate(),
        const _FallbackCupertinoLocalizationsDelegate(),
      ],

      supportedLocales: context.supportedLocales,

      builder: (context, child) {
        return DevicePerformanceScope(
          tier: DevicePerformance.tier,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  /// -------------------------------------------------------------------------
  /// Home / startup routing
  /// -------------------------------------------------------------------------

  Widget _buildHome(BuildContext context) {
    // -----------------------------------------------------------------------
    // Critical local initialization failure
    // -----------------------------------------------------------------------

    if (!widget.storageReady) {
      return ErrorPage();
    }

    // -----------------------------------------------------------------------
    // Language onboarding
    // -----------------------------------------------------------------------

    if (_hasSelectedLanguage != true) {
      return StartupLanguageScreen(onLanguageSelected: _languageSelected);
    }

    // -----------------------------------------------------------------------
    // Choose the experience before cloud sign-in. A free local lender must be
    // able to open an offline workspace without an OTP or phone metadata.
    // -----------------------------------------------------------------------

    if (_hasSelectedInterest != true) {
      return AccountTypeScreen(onContinue: _interestSelected);
    }

    // Connected borrower records require an authenticated account. Lenders
    // can link an account later from the dashboard when using cloud features.
    if (AppSettings.getUsesBorrowerExperience() && _hasVerifiedPhone != true) {
      if (!widget.phoneMetadataReady) return ErrorPage();
      if (_pendingPhoneNumber == null) {
        return PhoneLoginScreen(onContinue: _sendOtp);
      }

      return OtpVerificationScreen(
        phoneNumber: _pendingPhoneNumber!,
        onVerify: _verifyOtp,
        onResend: _resendOtp,
        onChangeNumber: () {
          setState(() {
            _pendingPhoneNumber = null;
          });
        },
      );
    }

    // -----------------------------------------------------------------------
    // Authentication
    // -----------------------------------------------------------------------

    return ref
        .watch(authenticateProvider)
        .when(
          data: (authenticated) {
            if (!authenticated) {
              return const AuthFailurePage();
            }

            // -------------------------------------------------------------------
            // Borrower path
            //
            // Borrowers do not require lender subscription or Google Drive
            // backup setup.
            // -------------------------------------------------------------------

            final usesBorrower = AppSettings.getUsesBorrowerExperience();

            if (!usesBorrower && !AppSettings.getPlanSelectionCompleted()) {
              return PlanSelectionScreen(
                onContinue: () {
                  setState(() {});
                },
              );
            }

            // A lender who chooses Pro must verify their mobile number before
            // entering the connected workspace. This is deliberately after
            // plan selection so the phone flow is only shown for the chosen
            // paid path, while free local lenders remain offline-first.
            if (!usesBorrower &&
                AppSettings.getIsProPlanSelected() &&
                _hasVerifiedPhone != true) {
              if (!widget.phoneMetadataReady) return ErrorPage();
              if (_pendingPhoneNumber == null) {
                return PhoneLoginScreen(onContinue: _sendOtp);
              }

              return OtpVerificationScreen(
                phoneNumber: _pendingPhoneNumber!,
                onVerify: _verifyOtp,
                onResend: _resendOtp,
                onChangeNumber: () {
                  setState(() {
                    _pendingPhoneNumber = null;
                  });
                },
              );
            }

            // -------------------------------------------------------------------
            // Lender local storage / backup setup
            // -------------------------------------------------------------------

            if (!usesBorrower && !AppSettings.getIsTableCreated()) {
              return const AskBackupScreen();
            }

            // -------------------------------------------------------------------
            // Main dashboard
            // -------------------------------------------------------------------

            return const DashBoard();
          },

          error: (_, _) {
            return ErrorPage();
          },

          loading: () {
            return const AuthScreen();
          },
        );
  }
}
