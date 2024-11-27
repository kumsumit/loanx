// import 'package:firebase_core/firebase_core.dart';
// import 'package:device_preview/device_preview.dart';
// import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mortgage/screens/ask_backup_screen.dart';
import 'package:mortgage/screens/error.dart';
import 'package:mortgage/screens/unauthorized.dart';
// import 'package:mortgage/service/database_helper.dart';
import 'package:mortgage/provider/provider.dart';
import 'package:mortgage/screens/auth_screen.dart';
import 'package:mortgage/screens/dashboard.dart';
import 'package:mortgage/service/backup_service.dart';
import 'package:workmanager/workmanager.dart';
// import 'package:path/path.dart';
// import 'package:path_provider/path_provider.dart';

import 'db/fastdb.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await FastDB.init();
  // await Firebase.initializeApp();

  // final directory = await getApplicationSupportDirectory();
  FlutterNativeSplash.remove();
  runApp(ProviderScope(
      // overrides: [databaseProvider.overrideWithValue(database)],
      child: const MyApp()));
  // runApp(DevicePreview(
  //     storage: FileDevicePreviewStorage(
  //         filePath: join(directory.path, 'device_preview.json')),
  //     enabled: !kReleaseMode,
  //     builder: (context) => ProviderScope(
  //         overrides: [databaseProvider.overrideWithValue(database)],
  //         child: const MyApp())));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeManagerProvider);
    final appColor = ref.watch(appColorProvider);
    final authenticate = ref.watch(authenticateProvider);
    return MaterialApp(
        // useInheritedMediaQuery: true,
        // locale: DevicePreview.locale(context),
        // builder: DevicePreview.appBuilder,
        themeMode: themeMode,
        theme: ThemeData(
          colorSchemeSeed:
              Color(int.parse('FF${appColor.substring(1)}', radix: 16)),
        ),
        darkTheme: ThemeData(
          colorSchemeSeed:
              Color(int.parse('FF${appColor.substring(1)}', radix: 16)),
          brightness: Brightness.dark,
        ),
        debugShowCheckedModeBanner: false,
        home: authenticate.when(
            data: (data) {
              return data ? FastDB.getIsTableCreated() ?const DashBoard(): const AskBackupScreen() : const AuthFailurePage();
            },
            error: (err, obj) => ErrorPage(),
            loading: () => AuthScreen()));
    // errorMessage: err.toString() + obj.toString(),
  }
}
// isAuthenticated ? DashBoard() : AuthScreen()
