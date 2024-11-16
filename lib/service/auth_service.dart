import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
class AuthService {
  final LocalAuthentication _localAuthentication = LocalAuthentication();
  bool isAuthenticated = false;

  Future<bool> authenticate() async {
    try {
      final bool canAuthenticateWithBiometrics =
          await _localAuthentication.canCheckBiometrics;
      if (canAuthenticateWithBiometrics) {
        isAuthenticated = await _localAuthentication.authenticate(
          localizedReason: 'Please authenticate to access the app',
          options: const AuthenticationOptions(
            useErrorDialogs: true,
            stickyAuth: true,
            // biometricOnly: true,
          ),
        );
      } else if (await _localAuthentication.isDeviceSupported()) {
        isAuthenticated = await _localAuthentication.authenticate(
          localizedReason: 'Please authenticate to access the app',
          options: const AuthenticationOptions(
            useErrorDialogs: true,
            stickyAuth: false,
          ),
        );
      }
      return isAuthenticated;
    } on PlatformException catch (e) {
      debugPrint(e.toString());
      return false;
    }
  }
}
