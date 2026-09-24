import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loanx/db/app_settings.dart';
import 'package:loanx/l10n/codegen_loader.g.dart';
import 'package:loanx/main.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/features/lender/ask_backup_screen.dart';
import 'package:loanx/features/lender/dashboard.dart';
import 'package:loanx/features/borrower/home.dart';
import 'package:loanx/features/lender/home.dart';
import 'package:loanx/features/lender/error.dart';
import 'package:loanx/features/auth/unauthorized.dart';
import 'package:loanx/features/auth/phone_login_screen.dart';
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
    AppSettings.putPlanSelectionCompleted(true);
    AppSettings.putPhoneAuthVerified(true);
    await AppSettings.flush();
  });

  tearDown(() async {
    await AppSettings.flush();
    await directory.delete(recursive: true);
  });

  Widget app({
    bool storageReady = true,
    bool authenticated = true,
    Future<void> Function()? initializeBridge,
  }) {
    return EasyLocalization(
      supportedLocales: const [Locale('en')],
      path: 'lib/l10n',
      assetLoader: const CodegenLoader(),
      fallbackLocale: const Locale('en'),
      child: ProviderScope(
        overrides: [
          authenticateProvider.overrideWith((ref) async => authenticated),
          borrowerDashboardProvider.overrideWith(
            (ref) async =>
                const BorrowerDashboardData(loans: [], notifications: []),
          ),
          networkCheckerProvider.overrideWith((ref) => Stream.value(false)),
        ],
        child: MyApp(
          storageReady: storageReady,
          phoneMetadataFuture: Future.value(true),
          initializeBridge: initializeBridge ?? () async {},
          startOptionalServices: () async {},
        ),
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

  test('phone metadata initialization retries once', () async {
    var attempts = 0;
    final ready = await initializePhoneMetadata(
      loader: () async {
        attempts++;
        if (attempts == 1) throw StateError('temporary metadata failure');
      },
    );
    expect(ready, isTrue);
    expect(attempts, 2);
  });

  testWidgets('new local workspace needs no phone or account role', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byType(AskBackupScreen), findsOneWidget);
    expect(find.textContaining('quickstart'), findsNothing);
  });

  testWidgets('borrower onboarding bypasses lender plan selection', (
    tester,
  ) async {
    AppSettings.putOnboardingInterest(1); // AccountType.borrower.index
    AppSettings.putPlanSelectionCompleted(false);

    // Pumping the app must never wait for the optional cloud bootstrap.
    await tester.pumpWidget(app());
    await tester.pump();

    expect(find.byType(DashBoard), findsOneWidget);
    expect(find.byType(BorrowerHome), findsOneWidget);
    expect(find.byType(Home), findsNothing);
    expect(find.byType(AskBackupScreen), findsNothing);
  });

  testWidgets('an unavailable cloud bridge cannot lock local loan access', (
    tester,
  ) async {
    final unavailable = Completer<void>();
    await tester.pumpWidget(app(initializeBridge: () => unavailable.future));
    await tester.pumpAndSettle();
    expect(find.byType(AskBackupScreen), findsOneWidget);
    unavailable.complete();
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

  testWidgets(
    'phone metadata failure offers a retry instead of blocking app startup',
    (tester) async {
      AppSettings.putOnboardingInterest(
        1,
      ); // Borrower access needs account link.
      AppSettings.putPhoneAuthVerified(false);
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en')],
          path: 'lib/l10n',
          assetLoader: const CodegenLoader(),
          fallbackLocale: const Locale('en'),
          child: ProviderScope(
            child: MyApp(
              phoneMetadataFuture: Future.value(false),
              phoneMetadataLoader: () async => false,
              initializeBridge: () async {},
              startOptionalServices: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PhoneLoginScreen), findsNothing);
      expect(find.byType(FilledButton), findsOneWidget);
    },
  );

  testWidgets('a local lender workspace does not require phone metadata', (
    tester,
  ) async {
    AppSettings.putOnboardingInterest(0);
    AppSettings.putPhoneAuthVerified(false);
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'lib/l10n',
        assetLoader: const CodegenLoader(),
        fallbackLocale: const Locale('en'),
        child: ProviderScope(
          overrides: [authenticateProvider.overrideWith((ref) async => true)],
          child: MyApp(
            phoneMetadataFuture: Future.value(false),
            initializeBridge: () async {},
            startOptionalServices: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AskBackupScreen), findsOneWidget);
  });
}
