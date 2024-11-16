// import 'package:firebase_core/firebase_core.dart';
import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mortgage/service/backup_service.dart';
import 'package:mortgage/service/database_helper.dart';
import 'package:mortgage/provider/provider.dart';
import 'package:mortgage/screens/auth_screen.dart';
import 'package:mortgage/screens/dashboard.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

import 'db/fastdb.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await FastDB.init();
  final database = await DatabaseHelper.instance.database;
  if (!FastDB.getIsTableCreated()) {
    await DatabaseHelper.instance.onCreate(database, 1);
  }
  // await Firebase.initializeApp();
  Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
  Workmanager().registerPeriodicTask(
    "MortgageBackupTaskgfcgfdfgdfgcscdfs65",
    "dailyBackup",
    initialDelay: Duration(
        hours: FastDB.getScheduledBackUpTimeHour(),
        minutes: FastDB.getScheduledBackUpTimeMinute()),
    frequency: Duration(days: 1),
  );
  final directory = await getApplicationSupportDirectory();
  FlutterNativeSplash.remove();
  runApp(DevicePreview(
      storage: FileDevicePreviewStorage(
          filePath: join(directory.path, 'device_preview.json')),
      enabled: !kReleaseMode,
      builder: (context) => ProviderScope(
          overrides: [databaseProvider.overrideWithValue(database)],
          child: const MyApp())));
}

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == "dailyBackup") {
      await BackupService().performBackup();
    }
    return Future.value(true);
  });
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeManagerProvider);
    final fontSize = ref.watch(fontSizeProvider);
    final appColor = ref.watch(appColorProvider);
    final isAuthenticated = ref.watch(authProvider);
    return MaterialApp(
        useInheritedMediaQuery: true,
        locale: DevicePreview.locale(context),
        builder: DevicePreview.appBuilder,
        themeMode: themeMode,
        theme: ThemeData(
          colorSchemeSeed:
              Color(int.parse('FF${appColor.substring(1)}', radix: 16)),
          textTheme: TextTheme(bodyMedium: TextStyle(fontSize: fontSize)),
        ),
        darkTheme: ThemeData(
          colorSchemeSeed:
              Color(int.parse('FF${appColor.substring(1)}', radix: 16)),
          brightness: Brightness.dark,
          textTheme: TextTheme(bodyMedium: TextStyle(fontSize: fontSize)),
        ),
        debugShowCheckedModeBanner: false,
        home: isAuthenticated ? DashBoard() : AuthScreen());
  }
}
