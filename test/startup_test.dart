import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loanx/db/app_settings.dart';
import 'package:loanx/l10n/codegen_loader.g.dart';
import 'package:loanx/main.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/screens/ask_backup_screen.dart';
import 'package:loanx/screens/error.dart';
import 'package:loanx/screens/unauthorized.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'locale': 'en'});
    await EasyLocalization.ensureInitialized();
    directory = await Directory.systemTemp.createTemp('loanx_startup_');
    await AppSettings.initForTesting(directory);
    AppSettings.putOnboardingInterest(2);
    AppSettings.putPhoneAuthVerified(true);
    await AppSettings.flush();
  });

  tearDown(() async {
    await AppSettings.flush();
    await directory.delete(recursive: true);
  });

  Widget app({bool storageReady = true, bool authenticated = true}) {
    return EasyLocalization(
      supportedLocales: const [Locale('en')],
      path: 'lib/l10n',
      assetLoader: const CodegenLoader(),
      fallbackLocale: const Locale('en'),
      child: ProviderScope(
        overrides: [
          authenticateProvider.overrideWith((ref) async => authenticated),
        ],
        child: MyApp(storageReady: storageReady),
      ),
    );
  }

  test('optional service failures are isolated from each other', () async {
    var backgroundStarted = false;
    await initializeOptionalServices(
      googleSignIn: () async => throw StateError('provider unavailable'),
      backgroundJobs: () async {
        backgroundStarted = true;
      },
    );
    expect(backgroundStarted, isTrue);
  });

  test('phone metadata is initialized before the UI starts', () async {
    var started = false;
    final ready = await initializePhoneMetadata(
      loader: () async => started = true,
    );
    expect(started, isTrue);
    expect(ready, isTrue);
  });

  test('phone metadata failure is reported as not ready', () async {
    final ready = await initializePhoneMetadata(
      loader: () async => throw StateError('metadata unavailable'),
    );
    expect(ready, isFalse);
  });

  testWidgets('new local workspace needs no phone or account role', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byType(AskBackupScreen), findsOneWidget);
    expect(find.textContaining('quickstart'), findsNothing);
  });

  testWidgets('local authentication gates workspace onboarding', (
    tester,
  ) async {
    await tester.pumpWidget(app(authenticated: false));
    await tester.pumpAndSettle();
    expect(find.byType(AuthFailurePage), findsOneWidget);
    expect(find.byType(AskBackupScreen), findsNothing);
  });

  testWidgets('storage failure never opens a fresh workspace', (tester) async {
    await tester.pumpWidget(app(storageReady: false));
    await tester.pumpAndSettle();
    expect(find.byType(ErrorPage), findsOneWidget);
    expect(find.byType(AskBackupScreen), findsNothing);
  });

  testWidgets('phone metadata failure never builds the login screen', (
    tester,
  ) async {
    AppSettings.putPhoneAuthVerified(false);
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'lib/l10n',
        assetLoader: const CodegenLoader(),
        fallbackLocale: const Locale('en'),
        child: const ProviderScope(child: MyApp(phoneMetadataReady: false)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ErrorPage), findsOneWidget);
  });
}
