// import 'package:firebase_core/firebase_core.dart';
// import 'package:device_preview/device_preview.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:loanx/l10n/app_localizations.dart';
import 'package:loanx/screens/ask_backup_screen.dart';
import 'package:loanx/screens/error.dart';
import 'package:loanx/screens/unauthorized.dart';
// import 'package:loanx/service/database_helper.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/screens/auth_screen.dart';
import 'package:loanx/screens/dashboard.dart';
import 'package:loanx/service/backup_service.dart';
import 'package:loanx/theme/app_theme.dart';
import 'package:workmanager/workmanager.dart';
// import 'package:path/path.dart';
// import 'package:path_provider/path_provider.dart';

import 'db/fastdb.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
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

  const String iosClientId =
      '971184206112-he3jrlalluq0hd1dlv14deau3s3d52ug.apps.googleusercontent.com';
  const String androidServerClientId =
      '971184206112-suu0rjqkd51htgg0l1kf0f73h4pn6uc5.apps.googleusercontent.com';

  await GoogleSignIn.instance.initialize(
    clientId: Platform.isIOS ? iosClientId : null,
    serverClientId: Platform.isAndroid ? androidServerClientId : null,
  );
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
    ProviderScope(
      // overrides: [databaseProvider.overrideWithValue(database)],
      child: const MyApp(),
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      home: authenticate.when(
        data: (data) {
          return data
              ? FastDB.getIsTableCreated()
                    ? const DashBoard()
                    : const AskBackupScreen()
              : const AuthFailurePage();
        },
        error: (err, obj) {
          return ErrorPage();
        },
        loading: () {
          return AuthScreen();
        },
      ),
      locale: const Locale('en', 'IN'),
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: [
        const Locale('en', 'IN'),
        const Locale('hi', 'IN'),
        // const Locale('bn', 'IN'),
        // const Locale('mr', 'in'),
        // const Locale('ta', 'in'),
        // const Locale('te', 'in'),
      ],
    );
    // errorMessage: err.toString() + obj.toString(),
  }
}

// isAuthenticated ? DashBoard() : AuthScreen()
