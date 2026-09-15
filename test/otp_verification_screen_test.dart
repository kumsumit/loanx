import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:loanx/l10n/codegen_loader.g.dart';
import 'package:loanx/features/auth/otp_verification_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'locale': 'en'});
    await EasyLocalization.ensureInitialized();
  });

  Widget app({required Future<String?> Function(String) verify}) {
    return EasyLocalization(
      supportedLocales: const [Locale('en')],
      path: 'lib/l10n',
      assetLoader: const CodegenLoader(),
      fallbackLocale: const Locale('en'),
      child: MaterialApp(
        home: OtpVerificationScreen(
          phoneNumber: PhoneNumber(isoCode: 'IN', nsn: '9876543210'),
          onVerify: verify,
          onResend: () async => null,
          onChangeNumber: () {},
        ),
      ),
    );
  }

  testWidgets(
    'submits a complete six-digit OTP without logging or storing it',
    (tester) async {
      String? submittedCode;
      await tester.pumpWidget(
        app(
          verify: (code) async {
            submittedCode = code;
            return null;
          },
        ),
      );
      await tester.pump();

      await tester.enterText(find.byKey(const Key('otp-input')), '123456');
      await tester.pump();

      expect(submittedCode, '123456');
    },
  );

  testWidgets('shows verifier failures and remains on OTP screen', (
    tester,
  ) async {
    await tester.pumpWidget(app(verify: (_) async => 'Invalid code'));
    await tester.pump();

    await tester.enterText(find.byKey(const Key('otp-input')), '000000');
    await tester.pump();

    expect(find.text('Invalid code'), findsOneWidget);
    expect(find.byType(OtpVerificationScreen), findsOneWidget);
  });

  testWidgets('fits the six-digit input on a compact phone viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app(verify: (_) async => null));
    await tester.pump();

    await tester.enterText(find.byKey(const Key('otp-input')), '123');
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('otp-input')), findsOneWidget);
  });
}
