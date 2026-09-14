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
import 'package:loanx/screens/error.dart';
import 'package:loanx/screens/unauthorized.dart';
import 'package:loanx/l10n/codegen_loader.g.dart';
import 'package:loanx/l10n/locale_keys.g.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/screens/auth_screen.dart';
import 'package:loanx/screens/dashboard.dart';
import 'package:loanx/service/backup_service.dart';
import 'package:loanx/src/rust/frb_generated.dart';
import 'package:loanx/theme/app_theme.dart';
import 'package:loanx/widget/language_picker.dart';
import 'package:workmanager/workmanager.dart';

import 'db/app_settings.dart';

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
        : const Locale('en');
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
        : const Locale('en');
    return GlobalCupertinoLocalizations.delegate.load(cupertinoLocale);
  }

  @override
  bool shouldReload(_FallbackCupertinoLocalizationsDelegate old) => false;
}

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await RustLib.init();
  await PhoneMetadataBootstrap.ensureInitialized();
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
  } catch (_) {
    debugPrint('LoanX local storage initialization failed.');
  }
  FlutterNativeSplash.remove();
  runApp(
    EasyLocalization(
      supportedLocales: appLanguages
          .map((language) => language.locale)
          .toList(),
      path: 'lib/l10n',
      assetLoader: const CodegenLoader(),
      fallbackLocale: const Locale('en'),
      useOnlyLangCode: true,
      child: ProviderScope(child: MyApp(storageReady: storageReady)),
    ),
  );
  unawaited(initializeOptionalServices());
}

/// Optional providers initialize independently after the local UI starts.
/// Their errors are reported without exposing provider credentials.
Future<void> initializeOptionalServices({
  Future<void> Function()? googleSignIn,
  Future<void> Function()? backgroundJobs,
  Future<void> Function()? phoneMetadata,
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
    // initialize(
    //   'phone metadata',
    //   phoneMetadata ?? () => PhoneMetadataBootstrap.ensureInitialized(),
    // ),
  ]);
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key, this.storageReady = true});

  final bool storageReady;

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  bool? _hasSelectedLanguage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _hasSelectedLanguage ??= context.savedLocale != null;
  }

  void _languageSelected() {
    if (_hasSelectedLanguage == true) return;
    setState(() => _hasSelectedLanguage = true);
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
      home: !widget.storageReady
          ? ErrorPage()
          : _hasSelectedLanguage != true
          ? StartupLanguageScreen(onLanguageSelected: _languageSelected)
          : ref
                .watch(authenticateProvider)
                .when(
                  data: (authenticated) => !authenticated
                      ? const AuthFailurePage()
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
    );
  }
}
