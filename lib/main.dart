// import 'package:firebase_core/firebase_core.dart';
// import 'package:device_preview/device_preview.dart';
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
// import 'package:loanx/service/database_helper.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/screens/auth_screen.dart';
import 'package:loanx/screens/dashboard.dart';
import 'package:loanx/service/backup_service.dart';
import 'package:loanx/theme/app_theme.dart';
import 'package:loanx/widget/language_picker.dart';
import 'package:workmanager/workmanager.dart';
// import 'package:path/path.dart';
// import 'package:path_provider/path_provider.dart';

import 'db/fastdb.dart';

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

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
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
      return const Material(
        child: Center(child: Text('Something went wrong. Please try again.')),
      );
    }
    return ErrorWidget(details.exception);
  };

  await initializeGoogleSignIn();
  await Workmanager().initialize(callbackDispatcher);
  await FastDB.init();
  if (!FastDB.getIsTableCreated()) {
    FastDB.putHoldingPeriod(5);
    FastDB.putInterestRate(2.5);
    FastDB.putScheduledBackUpTimeHour(2);
    await FastDB.flush();
  }
  try {
    await PhoneMetadataBootstrap.ensureInitialized();
  } catch (e) {
    debugPrint('Phone metadata initialization failed: $e');
  }
  // await Firebase.initializeApp();

  // final directory = await getApplicationSupportDirectory();
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
      child: const ProviderScope(
        // overrides: [databaseProvider.overrideWithValue(database)],
        child: MyApp(),
      ),
    ),
  );
  // runApp(DevicePreview(
  //     storage: FileDevicePreviewStorage(
  //         filePath: join(directory.path, 'device_preview.json')),
  //     enabled: !kReleaseMode,
  //     builder: (context) => ProviderScope(
  //         overrides: [databaseProvider.overrideWithValue(database)],
  //         child: const MyApp())));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

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
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(
        FastDB.flush().catchError((Object _, StackTrace _) {
          // FastDB logs the error and retains the previous valid file.
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
    final themeMode = ref.watch(themeModeManagerProvider);
    final appColor = ref.watch(appColorProvider);
    final authenticate = ref.watch(authenticateProvider);
    return MaterialApp(
      // useInheritedMediaQuery: true,
      // locale: DevicePreview.locale(context),
      // builder: DevicePreview.appBuilder,
      themeMode: themeMode,
      theme: AppTheme.light(AppTheme.parseSeed(appColor)),
      darkTheme: AppTheme.dark(AppTheme.parseSeed(appColor)),
      debugShowCheckedModeBanner: false,
      home: _hasSelectedLanguage != true
          ? StartupLanguageScreen(onLanguageSelected: _languageSelected)
          : !FastDB.getIsTableCreated()
          ? const AskBackupScreen()
          : authenticate.when(
              data: (data) {
                return data ? const DashBoard() : const AuthFailurePage();
              },
              error: (err, obj) {
                return ErrorPage();
              },
              loading: () {
                return AuthScreen();
              },
            ),
      locale: context.locale,
      localizationsDelegates: [
        const _FallbackMaterialLocalizationsDelegate(),
        const _FallbackCupertinoLocalizationsDelegate(),
        ...context.localizationDelegates,
      ],
      supportedLocales: context.supportedLocales,
    );
    // errorMessage: err.toString() + obj.toString(),
  }
}

// isAuthenticated ? DashBoard() : AuthScreen()
