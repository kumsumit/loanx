import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loanx/service/backup_service.dart';

void main() {
  test('canceled Google sign-in maps to a friendly no-account message', () {
    final error = PlatformException(
      code: 'sign_in_canceled',
      message: 'Sign in canceled',
    );

    expect(BackupService.isUserCancelledGoogleSignIn(error), isTrue);
    final message = BackupService.userFacingGoogleSignInError(error);
    expect(
      message,
      contains(
        'No Google account was selected. Please choose an account to continue.',
      ),
    );
  });

  test('non-cancel errors stay detailed only in debug mode', () {
    final error = PlatformException(
      code: 'unknown',
      message: 'something unexpected happened',
    );

    final message = BackupService.userFacingGoogleSignInError(error);
    expect(
      message,
      contains('Google account connection failed. Please try again.'),
    );
  });
}
